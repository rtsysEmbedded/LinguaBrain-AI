import XCTest
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainMedia
import LinguaBrainAnkiExport
@testable import LinguaBrainApplication

final class ExportFoundationTests: XCTestCase {
    lazy var testBundles: [GeneratedCardBundle] = {
        [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa")),
            createTestBundle(lemma: "Hello", languagePair: ("en", "de")),
            createTestBundle(lemma: "World", languagePair: ("en", "es"))
        ]
    }()

    private func createTestBundle(lemma: String, languagePair: (String, String)) -> GeneratedCardBundle {
        return GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: languagePair.0,
                targetLanguage: languagePair.1,
                lemma: lemma,
                senseKey: "\(lemma.lowercased())-\(UUID().uuidString.prefix(4))",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [
                LexicalSense(
                    sourceLanguage: languagePair.0,
                    targetLanguage: languagePair.1,
                    lemma: lemma,
                    senseKey: "\(lemma.lowercased())-\(UUID().uuidString.prefix(4))",
                    partOfSpeech: "noun",
                    meaning: "test meaning",
                    translation: "test translation"
                )
            ],
            mediaAssets: [],
            approvalState: .approved,
            provenance: Provenance(
                provider: "hermes",
                model: "claude-3-opus"
            )
        )
    }

    func testExportConfigurationDefaultLimits() throws {
        let config = AnkiExportConfiguration()
        
        XCTAssertEqual(config.maxCards, 500)
        XCTAssertEqual(config.maxMediaBytes, 500 * 1024 * 1024)
        XCTAssertEqual(config.collectionSchemaVersion, "anki21")
    }

    func testExportConfigurationCustomLimits() throws {
        let config = AnkiExportConfiguration(
            maxCards: 100,
            maxMediaBytes: 100 * 1024 * 1024
        )
        
        XCTAssertEqual(config.maxCards, 100)
        XCTAssertEqual(config.maxMediaBytes, 100 * 1024 * 1024)
    }

    func testExportCancellationNotCancelled() throws {
        let cancellation = ExportCancellation()
        
        XCTAssertFalse(cancellation.isCancelled)
        
        try cancellation.checkCancellation()
    }

    func testExportCancellationAfterCancel() throws {
        let cancellation = ExportCancellation()
        cancellation.cancel()
        
        XCTAssertTrue(cancellation.isCancelled)
        
        XCTAssertThrowsError(try cancellation.checkCancellation()) { error in
            XCTAssertTrue(error is AnkiExportError)
            if let exportError = error as? AnkiExportError {
                XCTAssertEqual(exportError, .cancelled)
            }
        }
    }

    func testAnkiExportErrorLocalizedDescription() throws {
        XCTAssertEqual(AnkiExportError.noApprovedCards.localizedDescription, "No approved cards available for export")
        XCTAssertEqual(AnkiExportError.cancelled.localizedDescription, "Export was cancelled")
        
        let missingMediaError = AnkiExportError.missingMedia(assetID: "test-asset")
        XCTAssertTrue(missingMediaError.localizedDescription.contains("test-asset"))
        
        let limitExceededError = AnkiExportError.limitExceeded(
            type: .cardCount,
            current: 600,
            maximum: 500
        )
        XCTAssertTrue(limitExceededError.localizedDescription.contains("limit exceeded"))
    }

    func testChecksumDeterminism() async throws {
        let resolver = DefaultOwnedMediaResolver()
        
        let testContent = "test file content for checksum verification"
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let testFile = tempDir.appendingPathComponent("checksum-test.txt")
        
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        let checksum1 = try await resolver.computeChecksum(for: testFile)
        let checksum2 = try await resolver.computeChecksum(for: testFile)
        
        XCTAssertEqual(checksum1, checksum2, "Checksums should be deterministic")
        XCTAssertEqual(checksum1.count, 64, "SHA-256 should produce 64 character hex string")
        
        try FileManager.default.removeItem(at: testFile)
    }

    func testCancellationDuringExport() {
        let cancellation = ExportCancellation()
        
        XCTAssertEqual(cancellation.isCancelled, false)
        
        cancellation.cancel()
        
        XCTAssertEqual(cancellation.isCancelled, true)
        
        XCTAssertThrowsError(try cancellation.checkCancellation()) { error in
            guard let exportError = error as? AnkiExportError else {
                XCTFail("Wrong error type")
                return
            }
            XCTAssertEqual(exportError, .cancelled)
        }
    }

    func testLimitExceededDetection() throws {
        let config = AnkiExportConfiguration(maxCards: 10)
        
        let exportCount = 10
        let exceededError = AnkiExportError.limitExceeded(
            type: .cardCount,
            current: exportCount + 1,
            maximum: config.maxCards
        )
        
        XCTAssertEqual(exceededError, .limitExceeded(type: .cardCount, current: 11, maximum: 10))
    }

    func testProgressTracking() throws {
        let progress = ExportProgress(
            cardsExported: 250,
            mediaBytesExported: 100_000,
            totalCards: 500,
            totalBytes: 200_000
        )
        
        XCTAssertEqual(progress.cardsExported, 250)
        XCTAssertEqual(progress.totalCards, 500)
        XCTAssertEqual(progress.progressFraction, 0.5)
        XCTAssertFalse(progress.isComplete)
    }

    func testProgressComplete() throws {
        let progress = ExportProgress(
            cardsExported: 500,
            mediaBytesExported: 200_000,
            totalCards: 500,
            totalBytes: 200_000
        )
        
        XCTAssertTrue(progress.isComplete)
        XCTAssertEqual(progress.progressFraction, 1.0)
    }

    func testMediaAssetChecksumsUniqueness() async throws {
        let resolver = DefaultOwnedMediaResolver()
        
        let content1 = "first file content"
        let content2 = "second file content"
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        
        let file1 = tempDir.appendingPathComponent("unique-test-1.txt")
        let file2 = tempDir.appendingPathComponent("unique-test-2.txt")
        
        try content1.write(to: file1, atomically: true, encoding: .utf8)
        try content2.write(to: file2, atomically: true, encoding: .utf8)
        
        let checksum1 = try await resolver.computeChecksum(for: file1)
        let checksum2 = try await resolver.computeChecksum(for: file2)
        
        XCTAssertNotEqual(checksum1, checksum2, "Different content should produce different checksums")
        
        try FileManager.default.removeItem(at: file1)
        try FileManager.default.removeItem(at: file2)
    }
}