import Foundation
import SQLite3
import zlib

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct SanitizedLegacyFixture: Decodable {
    struct Payload: Codable {
        struct Example: Codable {
            let de: String
            let fa: String
            let en: String
        }

        let word: String
        let headword: String
        let partOfSpeechFA: String
        let level: String
        let meaningFA: [String]
        let examples: [Example]

        enum CodingKeys: String, CodingKey {
            case word, headword, level, examples
            case partOfSpeechFA = "part_of_speech_fa"
            case meaningFA = "meaning_fa"
        }
    }

    let packageName: String
    let modelID: Int64
    let cardID: Int64
    let noteID: Int64
    let fields: [String]
    let payload: Payload
}

enum APKGFixtureFactory {
    static func loadFixture() throws -> SanitizedLegacyFixture {
        let url = try XCTUnwrapResource(named: "legacy-linguabrain", extension: "json")
        return try JSONDecoder().decode(SanitizedLegacyFixture.self, from: Data(contentsOf: url))
    }

    static func makeLegacyPackage(from fixture: SanitizedLegacyFixture) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinguaBrainTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("collection.anki21")
        try makeCollection(at: databaseURL, fixture: fixture)
        let packageURL = directory.appendingPathComponent(fixture.packageName)
        let database = try Data(contentsOf: databaseURL)
        let media = try JSONSerialization.data(withJSONObject: [String: String](), options: [.sortedKeys])
        try makeStoredZIP(entries: [("collection.anki21", database), ("media", media)], at: packageURL)
        return packageURL
    }

    private static func makeCollection(at url: URL, fixture: SanitizedLegacyFixture) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw FixtureError.sqlite("open")
        }
        defer { sqlite3_close(database) }

        try execute("CREATE TABLE col (models TEXT NOT NULL)", database: database)
        try execute("CREATE TABLE notes (id INTEGER PRIMARY KEY, mid INTEGER NOT NULL, flds TEXT NOT NULL)", database: database)
        try execute("CREATE TABLE cards (id INTEGER PRIMARY KEY, nid INTEGER NOT NULL)", database: database)

        let modelFields = fixture.fields.enumerated().map { ["name": $0.element, "ord": $0.offset] as [String: Any] }
        let models = [String(fixture.modelID): ["flds": modelFields]]
        let modelsData = try JSONSerialization.data(withJSONObject: models, options: [.sortedKeys])
        let modelsJSON = try XCTString(modelsData)
        try insert("INSERT INTO col(models) VALUES (?)", values: [.text(modelsJSON)], database: database)

        let payloadData = try JSONEncoder().encode(fixture.payload)
        let payloadJSON = try XCTString(payloadData)
        let fieldValues = [payloadJSON, "کار کردن", "arbeiten"].joined(separator: "\u{001F}")
        try insert(
            "INSERT INTO notes(id, mid, flds) VALUES (?, ?, ?)",
            values: [.integer(fixture.noteID), .integer(fixture.modelID), .text(fieldValues)],
            database: database
        )
        try insert(
            "INSERT INTO cards(id, nid) VALUES (?, ?)",
            values: [.integer(fixture.cardID), .integer(fixture.noteID)],
            database: database
        )
    }

    private enum SQLiteValue {
        case integer(Int64)
        case text(String)
    }

    private static func execute(_ sql: String, database: OpaquePointer) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw FixtureError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func insert(_ sql: String, values: [SQLiteValue], database: OpaquePointer) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw FixtureError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() {
            switch value {
            case .integer(let integer): sqlite3_bind_int64(statement, Int32(offset + 1), integer)
            case .text(let text): sqlite3_bind_text(statement, Int32(offset + 1), text, -1, sqliteTransient)
            }
        }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw FixtureError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
    }

    private static func makeStoredZIP(entries: [(String, Data)], at url: URL) throws {
        var archive = Data()
        var central = Data()
        for (name, contents) in entries {
            let nameData = Data(name.utf8)
            let offset = UInt32(archive.count)
            let checksum = contents.withUnsafeBytes { buffer in
                crc32(0, buffer.bindMemory(to: Bytef.self).baseAddress, uInt(contents.count))
            }
            archive.appendLE(UInt32(0x04034B50))
            archive.appendLE(UInt16(20)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0))
            archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0)); archive.appendLE(UInt32(checksum))
            archive.appendLE(UInt32(contents.count)); archive.appendLE(UInt32(contents.count))
            archive.appendLE(UInt16(nameData.count)); archive.appendLE(UInt16(0))
            archive.append(nameData); archive.append(contents)

            central.appendLE(UInt32(0x02014B50))
            central.appendLE(UInt16(20)); central.appendLE(UInt16(20)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt32(checksum))
            central.appendLE(UInt32(contents.count)); central.appendLE(UInt32(contents.count))
            central.appendLE(UInt16(nameData.count)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt32(0)); central.appendLE(offset)
            central.append(nameData)
        }
        let centralOffset = UInt32(archive.count)
        archive.append(central)
        archive.appendLE(UInt32(0x06054B50)); archive.appendLE(UInt16(0)); archive.appendLE(UInt16(0))
        archive.appendLE(UInt16(entries.count)); archive.appendLE(UInt16(entries.count))
        archive.appendLE(UInt32(central.count)); archive.appendLE(centralOffset); archive.appendLE(UInt16(0))
        try archive.write(to: url, options: .atomic)
    }

    enum FixtureError: Error { case sqlite(String), invalidUTF8 }

    private static func XCTString(_ data: Data) throws -> String {
        guard let value = String(data: data, encoding: .utf8) else { throw FixtureError.invalidUTF8 }
        return value
    }

    private static func XCTUnwrapResource(named name: String, extension ext: String) throws -> URL {
        guard let url = Bundle(for: FixtureBundleMarker.self).url(forResource: name, withExtension: ext) else {
            throw FixtureError.sqlite("missing fixture \(name).\(ext)")
        }
        return url
    }
}

private final class FixtureBundleMarker {}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
