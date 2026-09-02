import Foundation
import LinguaBrainDomain

public class AnkiPackageWriter {
    private let config: AnkiExportConfiguration

    public init(config: AnkiExportConfiguration = AnkiExportConfiguration()) {
        self.config = config
    }

    public func createAPKG(
        collectionURL: URL,
        mediaDirectory: URL?,
        manifest: ExportManifest,
        destination: URL,
        cancellation: ExportCancellation? = nil
    ) async throws -> URL {
        try await cancellation?.checkCancellation()

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apkg-staging.\(UUID().uuidString.prefix(8))")

        do {
            try await writeAPKG(
                collectionURL: collectionURL,
                mediaDirectory: mediaDirectory,
                manifest: manifest,
                to: tempURL
            )

            try await atomicWrite(to: destination, from: tempURL)

            return destination
        } catch {
            try FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    private func writeAPKG(
        collectionURL: URL,
        mediaDirectory: URL?,
        manifest: ExportManifest,
        to url: URL
    ) async throws {
        var archive = ZIPArchiveBuilder()

        let collectionData = try Data(contentsOf: collectionURL)
        archive.append(name: "collection.anki21", data: collectionData)

        if let mediaDir = mediaDirectory, FileManager.default.fileExists(atPath: mediaDir.path) {
            try await writeMediaEntries(to: &archive, manifest: manifest, mediaDir: mediaDir)
        }

        let manifestData = try JSONEncoder().encode(manifest)
        archive.append(name: "manifest.json", data: manifestData)

        try archive.finalize().write(to: url)
    }

    private func writeMediaEntries(
        to archive: inout ZIPArchiveBuilder,
        manifest: ExportManifest,
        mediaDir: URL
    ) async throws {
        for (index, entry) in manifest.mediaEntries.enumerated() {
            let mediaFile = mediaDir.appendingPathComponent("\(index).media")
            
            guard FileManager.default.fileExists(atPath: mediaFile.path) else {
                continue
            }

            let data = try Data(contentsOf: mediaFile)
            archive.append(name: "\(index).media", data: data)
        }
    }

    private func atomicWrite(to destination: URL, from temporary: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }

        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

private struct ZIPArchiveBuilder {
    private struct Entry {
        let name: Data
        let data: Data
        let crc: UInt32
        let offset: UInt32
    }

    private var data = Data()
    private var entries: [Entry] = []

    mutating func append(name: String, data: Data) {
        let nameData = name.data(using: .utf8)!
        let crc = crc32(data)
        let offset = UInt32(self.data.count)

        self.data.appendLE(UInt32(0x04034b50))
        self.data.appendLE(UInt16(20))
        self.data.appendLE(UInt16(0))
        self.data.appendLE(UInt16(0))
        self.data.appendLE(UInt16(0))
        self.data.appendLE(crc)
        self.data.appendLE(UInt32(data.count))
        self.data.appendLE(UInt32(data.count))
        self.data.appendLE(UInt16(nameData.count))
        self.data.appendLE(UInt16(0))
        self.data.append(nameData)
        self.data.append(data)
        entries.append(Entry(name: nameData, data: data, crc: crc, offset: offset))
    }

    func finalize() -> Data {
        var result = data
        let centralOffset = UInt32(result.count)
        for entry in entries {
            result.appendLE(UInt32(0x02014b50))
            result.appendLE(UInt16(20))
            result.appendLE(UInt16(20))
            result.appendLE(UInt16(0))
            result.appendLE(UInt16(0))
            result.appendLE(UInt16(0))
            result.appendLE(entry.crc)
            result.appendLE(UInt32(entry.data.count))
            result.appendLE(UInt32(entry.data.count))
            result.appendLE(UInt16(entry.name.count))
            result.appendLE(UInt16(0))
            result.appendLE(UInt16(0))
            result.appendLE(UInt16(0))
            result.appendLE(UInt16(0))
            result.appendLE(UInt32(0))
            result.appendLE(entry.offset)
            result.append(entry.name)
        }

        let centralSize = UInt32(result.count) - centralOffset
        result.appendLE(UInt32(0x06054b50))
        result.appendLE(UInt16(0))
        result.appendLE(UInt16(0))
        result.appendLE(UInt16(entries.count))
        result.appendLE(UInt16(entries.count))
        result.appendLE(centralSize)
        result.appendLE(centralOffset)
        result.appendLE(UInt16(0))
        return result
    }
}

private extension Data {
    mutating func appendLE(_ value: UInt32) {
        var value = value.littleEndian
        append(Data(bytes: &value, count: 4))
    }

    mutating func appendLE(_ value: UInt16) {
        var value = value.littleEndian
        append(Data(bytes: &value, count: 2))
    }
}

private func crc32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xffffffff
    for byte in data {
        crc ^= UInt32(byte)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
        }
    }
    return crc ^ 0xffffffff
}
