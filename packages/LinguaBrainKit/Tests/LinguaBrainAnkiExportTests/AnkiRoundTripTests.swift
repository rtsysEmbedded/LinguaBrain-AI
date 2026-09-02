import XCTest
import Foundation
import LinguaBrainDomain
import LinguaBrainAnkiExport
@testable import LinguaBrainAnkiExport

final class AnkiRoundTripTests: XCTestCase {
    private var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("roundtrip-tests-\(UUID().uuidString.prefix(8))")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    func testTextEquivalence() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.textMatches, "Text should match for identical data")
    }
    
    func testSenseEquivalence() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.senseMatches, "Senses should match for identical data")
    }
    
    func testExampleEquivalence() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.exampleMatches, "Examples should match for identical data")
    }
    
    func testDirectionEquivalence() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.directionMatches, "Directions should match for identical data")
    }
    
    func testMediaEquivalence() throws {
        let validator = AnkiRoundTripValidator()
        
        let mediaManifests = AnkiMediaManifest(
            entries: [
                MediaManifestEntry(
                    sourceAssetID: "test-audio.mp3",
                    ankiIndex: 0,
                    sha256: "checksum1",
                    byteSize: 102400,
                    mimeType: "audio/mpeg"
                )
            ]
        )
        
        let original = createTestRoundTripDataWithMedia(mediaManifest: mediaManifests)
        let imported = createTestRoundTripDataWithMedia(mediaManifest: mediaManifests)
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.mediaMatches, "Media should match for identical manifests")
    }
    
    func testTagEquivalence() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.tagsMatch, "Tags should match for identical data")
    }
    
    func testProvenanceTracking() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.provenanceMatches, "Provenance should be tracked correctly")
    }
    
    func testDiscrepancyDetection() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let modifiedData = AnkiRoundTripData(
            notes: [
                AnkiNoteData(
                    noteID: 1,
                    modelID: 1,
                    deckID: 1,
                    fields: ["Modified Content", "بانک"],
                    tags: ["en-de", "recognition", "approved"]
                )
            ],
            cards: [
                AnkiCardData(
                    cardID: 1,
                    noteID: 1,
                    deckID: 1,
                    due: 0,
                    queue: 1,
                    reps: 5,
                    lapses: 1,
                    ease: 2500
                )
            ],
            models: [
                AnkiModelData(
                    modelID: 1,
                    name: "HermesCard",
                    fieldNames: ["Front", "Back"]
                )
            ],
            decks: [
                AnkiDeckData(
                    deckID: 1,
                    name: "Hermes Export"
                )
            ],
            tags: [
                AnkiTagData(tag: "recognition"),
                AnkiTagData(tag: "approved"),
                AnkiTagData(tag: "hermes-export")
            ],
            exportManifest: original.exportManifest
        )
        
        let comparison = validator.compare(original: original, imported: modifiedData)
        
        XCTAssertFalse(comparison.textMatches, "Text mismatch should be detected")
        XCTAssertGreaterThan(comparison.discrepancies.count, 0, "Discrepancies should be reported")
    }
    
    func testUnicodeLrtlPreservation() throws {
        let validator = AnkiRoundTripValidator()
        
        let rtlContent = "بانک به معنی مال است"
        
        let result = validator.compareRtlLtr(text: rtlContent)
        XCTAssertTrue(result, "RTL content should be recognizable")
    }
    
    func testUnicodeNormalization() throws {
        let validator = AnkiRoundTripValidator()
        
        let composed = "ü"
        let decomposed = "u\u{0308}"
        
        let normalized1 = validator.normalizeUnicode(composed)
        let normalized2 = validator.normalizeUnicode(decomposed)
        
        XCTAssertEqual(normalized1, normalized2, "Unicode normalization should produce consistent results")
    }
    
    func testReportGeneration() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createTestRoundTripData()
        let imported = createTestRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        let report = validator.generateReport(for: comparison)
        
        XCTAssertTrue(report.contains("PASSED"), "Report should show passed status for matching data")
    }
    
    func testSchedulingCompatibilityWarning() throws {
        let compat = AnkiSchedulingCompatibility.shared
        
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "de",
                lemma: "test",
                senseKey: "test-1",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [],
            approvalState: .approved,
            provenance: Provenance(provider: "hermes", model: "claude-fsrs")
        )
        
        let report = compat.analyze(hermesCard: bundle)
        
        XCTAssertNotEqual(report.status, .preserved, "FSRS should trigger fresh Anki status")
        XCTAssertGreaterThan(report.warnings.count, 0, "FSRS should generate warnings")
    }
    
    func testSchedulingPreservedFields() throws {
        let compat = AnkiSchedulingCompatibility.shared
        
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "de",
                lemma: "house",
                senseKey: "house-n",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [],
            approvalState: .approved,
            provenance: Provenance(provider: "hermes", model: "claude")
        )
        
        let report = compat.analyze(hermesCard: bundle)
        
        XCTAssertFalse(report.preservedFields.isEmpty, "Standard scheduling should preserve fields")
    }
    
    func testFullRoundTripComparison() throws {
        let validator = AnkiRoundTripValidator()
        
        let original = createFullRoundTripData()
        let imported = createFullRoundTripData()
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.areEqual, "Full round-trip should show all data equivalent")
    }
    
    private func createTestRoundTripData(provenance: Provenance? = nil) -> AnkiRoundTripData {
        return AnkiRoundTripData(
            notes: [
                AnkiNoteData(
                    noteID: 1,
                    modelID: 1,
                    deckID: 1,
                    fields: ["Bank", "بانک"],
                    tags: ["en-de", "recognition", "approved"]
                )
            ],
            cards: [
                AnkiCardData(
                    cardID: 1,
                    noteID: 1,
                    deckID: 1,
                    due: 0,
                    queue: 1,
                    reps: 5,
                    lapses: 1,
                    ease: 2500
                )
            ],
            models: [
                AnkiModelData(
                    modelID: 1,
                    name: "HermesCard",
                    fieldNames: ["Front", "Back"]
                )
            ],
            decks: [
                AnkiDeckData(
                    deckID: 1,
                    name: "Hermes Export"
                )
            ],
            tags: [
                AnkiTagData(tag: "recognition"),
                AnkiTagData(tag: "approved"),
                AnkiTagData(tag: "hermes-export")
            ],
            exportManifest: ExportManifest(
                exportID: "test-export-uuid",
                provenance: provenance ?? Provenance(provider: "hermes", model: "claude")
            )
        )
    }
    
    private func createFullRoundTripData() -> AnkiRoundTripData {
        return AnkiRoundTripData(
            notes: [
                AnkiNoteData(
                    noteID: 1,
                    modelID: 1,
                    deckID: 1,
                    fields: ["Bank", "بانک"],
                    tags: ["en-de", "recognition"]
                ),
                AnkiNoteData(
                    noteID: 2,
                    modelID: 1,
                    deckID: 1,
                    fields: ["Haus", "خانه"],
                    tags: ["de-fa", "recognition"]
                )
            ],
            cards: [
                AnkiCardData(cardID: 1, noteID: 1, deckID: 1),
                AnkiCardData(cardID: 2, noteID: 2, deckID: 1)
            ],
            models: [
                AnkiModelData(modelID: 1, name: "HermesCard", fieldNames: ["Front", "Back"])
            ],
            decks: [
                AnkiDeckData(deckID: 1, name: "Hermes Export")
            ],
            tags: [
                AnkiTagData(tag: "recognition"),
                AnkiTagData(tag: "approved")
            ],
            mediaManifest: AnkiMediaManifest(
                entries: [
                    MediaManifestEntry(
                        sourceAssetID: "audio-1",
                        ankiIndex: 0,
                        sha256: "abc123",
                        byteSize: 102400
                    )
                ]
            )
        )
    }
    
    private func createTestRoundTripDataWithMedia(mediaManifest: AnkiMediaManifest? = nil) -> AnkiRoundTripData {
        return AnkiRoundTripData(
            notes: [
                AnkiNoteData(
                    noteID: 1,
                    modelID: 1,
                    deckID: 1,
                    fields: ["Test", "Test"],
                    tags: ["test"]
                )
            ],
            cards: [],
            models: [],
            decks: [],
            tags: [],
            mediaManifest: mediaManifest
        )
    }
}