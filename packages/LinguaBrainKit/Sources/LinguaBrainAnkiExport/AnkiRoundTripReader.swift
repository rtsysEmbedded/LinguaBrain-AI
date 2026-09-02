import Foundation
import SQLite3
import LinguaBrainDomain

public struct AnkiNoteData: Sendable, Equatable {
    public let noteID: Int64
    public let modelID: Int64
    public let deckID: Int64
    public let fields: [String]
    public let tags: [String]
    
    public init(
        noteID: Int64,
        modelID: Int64,
        deckID: Int64,
        fields: [String],
        tags: [String] = []
    ) {
        self.noteID = noteID
        self.modelID = modelID
        self.deckID = deckID
        self.fields = fields
        self.tags = tags
    }
}

public struct AnkiCardData: Sendable, Equatable {
    public let cardID: Int64
    public let noteID: Int64
    public let deckID: Int64
    public let due: Int64
    public let queue: Int
    public let reps: Int
    public let lapses: Int
    public let ease: Int
    
    public init(
        cardID: Int64,
        noteID: Int64,
        deckID: Int64,
        due: Int64 = 0,
        queue: Int = 1,
        reps: Int = 0,
        lapses: Int = 0,
        ease: Int = 1
    ) {
        self.cardID = cardID
        self.noteID = noteID
        self.deckID = deckID
        self.due = due
        self.queue = queue
        self.reps = reps
        self.lapses = lapses
        self.ease = ease
    }
}

public struct AnkiModelData: Sendable, Equatable {
    public let modelID: Int64
    public let name: String
    public let fieldNames: [String]
    
    public init(modelID: Int64, name: String, fieldNames: [String]) {
        self.modelID = modelID
        self.name = name
        self.fieldNames = fieldNames
    }
}

public struct AnkiDeckData: Sendable, Equatable {
    public let deckID: Int64
    public let name: String
    
    public init(deckID: Int64, name: String) {
        self.deckID = deckID
        self.name = name
    }
}

public struct AnkiTagData: Sendable, Equatable {
    public let tag: String
    
    public init(tag: String) {
        self.tag = tag
    }
}

public struct AnkiMediaManifest: Sendable, Equatable {
    public let entries: [MediaManifestEntry]
    
    public init(entries: [MediaManifestEntry] = []) {
        self.entries = entries
    }
    
    public init(from manifest: ExportManifest) {
        self.entries = manifest.mediaEntries
    }
}

public struct AnkiRoundTripData: Sendable, Equatable {
    public let notes: [AnkiNoteData]
    public let cards: [AnkiCardData]
    public let models: [AnkiModelData]
    public let decks: [AnkiDeckData]
    public let tags: [AnkiTagData]
    public let mediaManifest: AnkiMediaManifest?
    public let exportManifest: ExportManifest?
    
    public init(
        notes: [AnkiNoteData] = [],
        cards: [AnkiCardData] = [],
        models: [AnkiModelData] = [],
        decks: [AnkiDeckData] = [],
        tags: [AnkiTagData] = [],
        mediaManifest: AnkiMediaManifest? = nil,
        exportManifest: ExportManifest? = nil
    ) {
        self.notes = notes
        self.cards = cards
        self.models = models
        self.decks = decks
        self.tags = tags
        self.mediaManifest = mediaManifest
        self.exportManifest = exportManifest
    }
}

@MainActor
public class AnkiRoundTripReader: Sendable {
    public init() {}
    
    public func readAPKG(at url: URL) throws -> AnkiRoundTripData {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apkg-read-\(UUID().uuidString.prefix(8))")
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try extractPackage(at: url, to: tempDir)
        
        let collectionURL = tempDir.appendingPathComponent("collection.anki21")
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        
        var manifest: ExportManifest? = nil
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            manifest = try? loadManifest(from: manifestURL)
        }
        
        let mediaManifest = manifest.map { AnkiMediaManifest(from: $0) }
        
        let data = try readCollection(at: collectionURL)
        
        return AnkiRoundTripData(
            notes: data.notes,
            cards: data.cards,
            models: data.models,
            decks: data.decks,
            tags: data.tags,
            mediaManifest: mediaManifest,
            exportManifest: manifest
        )
    }
    
    private func loadManifest(from url: URL) throws -> ExportManifest {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportManifest.self, from: data)
    }
    
    private func extractPackage(at url: URL, to destination: URL) throws {
#if os(macOS)
        let zipData = try Data(contentsOf: url)
        let stagingZip = destination.appendingPathComponent("staging.zip")
        try zipData.write(to: stagingZip)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-o", stagingZip.path, "-d", destination.path]
        
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            try FileManager.default.removeItem(at: stagingZip)
            throw AnkiExportError.zipError(message: "Failed to extract ZIP archive")
        }
        
        try FileManager.default.removeItem(at: stagingZip)
#else
        throw AnkiExportError.zipError(message: "Portable ZIP extraction is not available on this platform")
#endif
    }
    
    private func readCollection(at url: URL) throws -> AnkiRoundTripData {
        var db: OpaquePointer?
        let path = url.path.cString(using: .utf8)!
        
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            sqlite3_close(db)
            throw AnkiExportError.sqliteError(code: -1, message: "Failed to open database")
        }
        
        defer {
            sqlite3_close(db)
        }
        
        let notes = readNotes(db: db)
        let cards = readCards(db: db)
        let models = readModels(db: db)
        let decks = readDecks(db: db)
        let tags = readTags(db: db)
        
        return AnkiRoundTripData(
            notes: notes,
            cards: cards,
            models: models,
            decks: decks,
            tags: tags
        )
    }
    
    private func readNotes(db: OpaquePointer?) -> [AnkiNoteData] {
        var stmt: OpaquePointer?
        let query = "SELECT nid, mid, did, tags, fields FROM notes"
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        
        var notes: [AnkiNoteData] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let nid = sqlite3_column_int64(stmt, 0)
            let mid = sqlite3_column_int64(stmt, 1)
            let did = sqlite3_column_int64(stmt, 2)
            
            let fieldsText = sqlite3_column_text(stmt, 4)
            var fields: [String] = []
            if let textPtr = fieldsText {
                fields = String(cString: textPtr).split(separator: "\n").map(String.init)
            }
            
            let note = AnkiNoteData(
                noteID: nid,
                modelID: mid,
                deckID: did,
                fields: fields
            )
            notes.append(note)
        }
        
        sqlite3_finalize(stmt)
        return notes
    }
    
    private func readCards(db: OpaquePointer?) -> [AnkiCardData] {
        var stmt: OpaquePointer?
        let query = "SELECT cid, nid, did, due, queue, reps, lapses, ease FROM cards"
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        
        var cards: [AnkiCardData] = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let card = AnkiCardData(
                cardID: sqlite3_column_int64(stmt, 0),
                noteID: sqlite3_column_int64(stmt, 1),
                deckID: sqlite3_column_int64(stmt, 2),
                due: sqlite3_column_int64(stmt, 3),
                queue: Int(sqlite3_column_int(stmt, 4)),
                reps: Int(sqlite3_column_int(stmt, 5)),
                lapses: Int(sqlite3_column_int(stmt, 6)),
                ease: Int(sqlite3_column_int(stmt, 7))
            )
            cards.append(card)
        }
        
        sqlite3_finalize(stmt)
        return cards
    }
    
    private func readModels(db: OpaquePointer?) -> [AnkiModelData] {
        return []
    }
    
    private func readDecks(db: OpaquePointer?) -> [AnkiDeckData] {
        return []
    }
    
    private func readTags(db: OpaquePointer?) -> [AnkiTagData] {
        return []
    }
}
