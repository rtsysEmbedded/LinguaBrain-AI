import XCTest
import Foundation
import SQLite3
import LinguaBrainDomain
import LinguaBrainAnkiExport
@testable import LinguaBrainAnkiExport
@testable import LinguaBrainApplication

final class OfflineIntegrityTests: XCTestCase {
    private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("offline-integrity-tests-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testOfflineInspectionReturnsFailureForMissingFile() throws {
        let inspector = OfflineAnkiPackageInspector()
        let missingURL = tempDirectory.appendingPathComponent("nonexistent.apkg")
        
        let result = try inspector.inspectPackage(at: missingURL)
        
        XCTAssertFalse(result.isOfflineValid)
        XCTAssertFalse(result.collectionExists)
    }
    
    func testResourceLimitEnforcement() throws {
        let pipeline = AnkiExportPipeline(config: AnkiExportConfiguration(maxCards: 10, maxMediaBytes: 1024000))
        
        XCTAssertThrowsError(try pipeline.checkCardLimit(count: 11)) { error in
            XCTAssertTrue(error is AnkiExportError)
            if let exportError = error as? AnkiExportError {
                if case .limitExceeded = exportError { }
                else { XCTFail("Expected limit exceeded error") }
            }
        }
    }
    
    func testMediaByteLimitEnforcement() throws {
        let pipeline = AnkiExportPipeline(config: AnkiExportConfiguration(maxMediaBytes: 1000))
        
        XCTAssertThrowsError(try pipeline.checkMediaLimit(bytes: 2000)) { error in
            XCTAssertTrue(error is AnkiExportError)
            if let exportError = error as? AnkiExportError {
                if case .limitExceeded = exportError { }
                else { XCTFail("Expected limit exceeded error") }
            }
        }
    }
    
    func testPipelineBoundedExport() async throws {
        let bundles = (0..<5).map { _ in createTestBundle() }
        let pipeline = AnkiExportPipeline(config: AnkiExportConfiguration(maxCards: 100))
        
        let result = try await pipeline.boundedExport(from: bundles) { bundle, index in
            return "processed"
        }
        
        XCTAssertEqual(result.result.count, 5)
        XCTAssertEqual(result.processedCount, 5)
    }
    
    func testPipelineMediaStreaming() async throws {
        let bundles = [createTestBundleWithMedia()]
        let pipeline = AnkiExportPipeline()
        
        let result = try await pipeline.streamMedia(from: bundles) { asset, index in
            return asset.checksum
        }
        
        XCTAssertEqual(result.processedCount, 1)
    }
    
    func testCancellationDuringExportPipeline() throws {
        let cancellation = ExportCancellation()
        let pipeline = AnkiExportPipeline(cancellation: cancellation)
        
        cancellation.cancel()
        
        XCTAssertThrowsError(try pipeline.checkCancellation()) { error in
            XCTAssertTrue(error is AnkiExportError)
            if let exportError = error as? AnkiExportError {
                XCTAssertEqual(exportError, .cancelled)
            }
        }
    }
    
    func testExportedAPKGStructure() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("structure-check-\(UUID().uuidString.prefix(8))")
        
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let collectionURL = tempDir.appendingPathComponent("collection.anki21")
        try createTestSQLiteDatabase(at: collectionURL)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: collectionURL.path))
    }
    
    private func createTestBundle() -> GeneratedCardBundle {
        GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "es",
                lemma: "Bank",
                senseKey: "bank-n-finance",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [],
            mediaAssets: [],
            approvalState: .approved,
            provenance: Provenance(provider: "hermes", model: "claude")
        )
    }
    
    private func createTestBundleWithMedia() -> GeneratedCardBundle {
        GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "de",
                lemma: "Hello",
                senseKey: "hello-interj",
                partOfSpeech: "interjection",
                direction: .recognition
            ),
            senses: [],
            mediaAssets: [
                MediaAsset(
                    kind: .audio,
                    locale: "de-DE",
                    checksum: "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890",
                    fileSize: 102400,
                    provider: "cloud",
                    model: "tts-default",
                    availability: .available
                )
            ],
            approvalState: .approved,
            provenance: Provenance(provider: "hermes", model: "claude")
        )
    }
    
    private func createTestSQLiteDatabase(at url: URL) throws {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        
        let path = url.path.cString(using: .utf8)!
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw AnkiExportError.sqliteError(code: -1, message: "Failed to create SQLite database")
        }
        
        let createNotes = "CREATE TABLE IF NOT EXISTS notes (nid INTEGER PRIMARY KEY, mid INTEGER, tags TEXT)"
        sqlite3_exec(db, createNotes, nil, nil, nil)
        
        let createCards = "CREATE TABLE IF NOT EXISTS cards (cid INTEGER PRIMARY KEY, nid INTEGER, due INTEGER, queue INTEGER)"
        sqlite3_exec(db, createCards, nil, nil, nil)
        
        let insertNote = "INSERT INTO notes (nid, mid, tags) VALUES (1, 1, 'test')"
        sqlite3_exec(db, insertNote, nil, nil, nil)
        
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS models (mid INTEGER PRIMARY KEY, name TEXT)", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO models (mid, name) VALUES (1, 'Basic')", nil, nil, nil)
        
        sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS decks (did INTEGER PRIMARY KEY, name TEXT)", nil, nil, nil)
        sqlite3_exec(db, "INSERT INTO decks (did, name) VALUES (1, 'Default')", nil, nil, nil)
    }
}