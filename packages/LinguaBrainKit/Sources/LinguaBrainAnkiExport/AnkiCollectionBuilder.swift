import Foundation
import SQLite3
import CryptoKit
import LinguaBrainDomain

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public class AnkiCollectionBuilder {
    private let dbURL: URL
    private var db: OpaquePointer?
    private let config: AnkiExportConfiguration

    public init(dbURL: URL, config: AnkiExportConfiguration = AnkiExportConfiguration()) throws {
        self.dbURL = dbURL
        self.config = config
        try self.openDatabase()
        try self.createSchema()
    }

    private func openDatabase() throws {
        if sqlite3_open(dbURL.path, &db) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_close(db)
            throw AnkiExportError.sqliteError(code: -1, message: "Failed to open database: \(errorMessage)")
        }
    }

    private func createSchema() throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS notes (
                id INTEGER PRIMARY KEY,
                mid INTEGER NOT NULL,
                guid TEXT NOT NULL,
                fields TEXT NOT NULL,
                tags TEXT,
                cst INTEGER,
                usn INTEGER
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS cards (
                id INTEGER PRIMARY KEY,
                nid INTEGER NOT NULL,
                did INTEGER NOT NULL,
                cid INTEGER NOT NULL,
                ost INTEGER,
                due INTEGER,
                ord INTEGER,
                type INTEGER,
                queue INTEGER,
                reps INTEGER,
                lapses INTEGER,
                ease INTEGER
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS revlog (
                id INTEGER PRIMARY KEY,
                nid INTEGER,
                cid INTEGER,
                "order" INTEGER,
                ease INTEGER,
                ivl INTEGER,
                nextIvl INTEGER,
                lastReview INTEGER,
                usn INTEGER
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS models (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                fields TEXT,
                templates TEXT,
                css TEXT,
                format INTEGER,
                sortFieldType INTEGER
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS decks (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL,
                desc TEXT,
                cmdr INTEGER,
                usn INTEGER
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS tags (
                name TEXT PRIMARY KEY,
                usn INTEGER
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS col (
                id INTEGER PRIMARY KEY,
                format INTEGER,
                deckCount INTEGER,
                noteCount INTEGER,
                mod INTEGER,
                usn INTEGER,
                schemaVersion INTEGER,
                deckTemplateNames TEXT,
                nextRawGUID INTEGER,
                wipeTime INTEGER
            )
            """
        ]

        for statement in statements {
            try execute(statement)
        }
    }

    public func execute(_ sql: String) throws {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 30, message: errorMessage)
        }

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 31, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func insertNote(_ note: AnkiNoteRecord) throws {
        let fieldsData = try JSONEncoder().encode(note.fieldStrings)
        guard let fieldsJSON = String(data: fieldsData, encoding: .utf8) else {
            throw AnkiExportError.sqliteError(code: 32, message: "Failed to encode note fields")
        }

        let sql = """
        INSERT INTO notes (id, mid, guid, fields, tags, cst, usn)
        VALUES (?, ?, ?, ?, ?, ?, 0)
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 32, message: errorMessage)
        }

        sqlite3_bind_int64(statement, 1, note.noteID)
        sqlite3_bind_int64(statement, 2, note.modelID)
        sqlite3_bind_text(statement, 3, note.guid(), -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 4, fieldsJSON, -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 5, note.tags.joined(separator: ","), -1, sqliteTransientDestructor)
        sqlite3_bind_int64(statement, 6, note.sortIDX)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 33, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func insertCard(_ card: AnkiCardRecord) throws {
        let sql = """
        INSERT INTO cards (id, nid, did, cid, ost, due, ord, type, queue, reps, lapses, ease)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 34, message: errorMessage)
        }

        sqlite3_bind_int64(statement, 1, card.cardID)
        sqlite3_bind_int64(statement, 2, card.noteID)
        sqlite3_bind_int64(statement, 3, card.deckID)
        sqlite3_bind_int64(statement, 4, card.cardID)
        sqlite3_bind_int(statement, 5, 0)
        sqlite3_bind_int64(statement, 6, card.due)
        sqlite3_bind_int(statement, 7, card.ordinal)
        sqlite3_bind_int(statement, 8, card.type)
        sqlite3_bind_int(statement, 9, card.queue)
        sqlite3_bind_int(statement, 10, card.reps)
        sqlite3_bind_int(statement, 11, card.lapses)
        sqlite3_bind_int(statement, 12, card.ease)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 35, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func insertModel(_ model: AnkiModelRecord) throws {
        let sql = """
        INSERT INTO models (id, name, fields, templates, css, format, sortFieldType)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 36, message: errorMessage)
        }

        let fieldsJSON = model.fieldNames.map { escapeJSON($0) }.joined(separator: ",")
        let templatesData = try JSONEncoder().encode(model.templates)
        let templatesJSON = String(data: templatesData, encoding: .utf8) ?? "{}"

        sqlite3_bind_int64(statement, 1, model.modelID)
        sqlite3_bind_text(statement, 2, model.name, -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 3, fieldsJSON, -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 4, templatesJSON, -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 5, model.css, -1, sqliteTransientDestructor)
        sqlite3_bind_int(statement, 6, Int32(model.formatVersion))
        sqlite3_bind_int(statement, 7, Int32(model.sortFieldType))

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 37, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func insertDeck(_ deck: AnkiDeckRecord) throws {
        let sql = """
        INSERT INTO decks (id, name, desc, cmdr, usn)
        VALUES (?, ?, '', 0, 0)
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 38, message: errorMessage)
        }

        sqlite3_bind_int64(statement, 1, deck.deckID)
        sqlite3_bind_text(statement, 2, deck.name, -1, sqliteTransientDestructor)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 39, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func insertTag(_ tag: AnkiTagRecord) throws {
        let sql = "INSERT OR IGNORE INTO tags (name, usn) VALUES (?, 0)"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 40, message: errorMessage)
        }

        sqlite3_bind_text(statement, 1, tag.tag, -1, sqliteTransientDestructor)

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 41, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func finalizeCollection() throws {
        let now = Int(Date().timeIntervalSince1970)

        let sql = """
        INSERT OR REPLACE INTO col (id, format, deckCount, noteCount, mod, usn, schemaVersion, nextRawGUID, wipeTime)
        VALUES (1, 1, 0, 0, ?, 0, 18, 0, 0)
        """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw AnkiExportError.sqliteError(code: 42, message: errorMessage)
        }

        sqlite3_bind_int(statement, 1, Int32(now))

        if sqlite3_step(statement) != SQLITE_DONE {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            sqlite3_finalize(statement)
            throw AnkiExportError.sqliteError(code: 43, message: errorMessage)
        }

        sqlite3_finalize(statement)
    }

    public func close() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    deinit {
        close()
    }

    private func escapeJSON(_ string: String) -> String {
        var escaped = ""
        for char in string {
            switch char {
            case "\"": escaped += "\\\""
            case "\\": escaped += "\\\\"
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            default: escaped.append(char)
            }
        }
        return escaped
    }
}

extension AnkiNoteRecord {
    func guid() -> String {
        let data = Data(String(noteID).utf8)
        let hash = SHA256.hash(data: data)
        return String(hash.compactMap { String(format: "%02x", $0) }.joined().prefix(24))
    }
}
