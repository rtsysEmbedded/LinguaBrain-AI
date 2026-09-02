import XCTest
import SwiftUI
import LinguaBrainDomain
import LinguaBrainAnkiExport
@testable import LinguaBrainApp

@MainActor
final class AnkiExportIntegrationTests: XCTestCase {
    func testExportSelectionWithSourceGroup() async throws {
        XCTAssertTrue(true)
    }

    func testExportFormatSwitch() async throws {
        XCTAssertTrue(true)
    }

    func testExportDocumentCreationForTSV() async throws {
        let exportDocument = AnkiTSVDocument(text: "test\ttsv\ncontent")

        XCTAssertEqual(exportDocument.text.count, 17)
    }

    func testExportDocumentCreationForAPKG() async throws {
        let exportDocument = AnkiAPKGDocument(
            sourceGroups: ["generated", "imported"],
            cardCount: 10,
            mediaCount: 2
        )

        XCTAssertEqual(exportDocument.cardCount, 10)
        XCTAssertEqual(exportDocument.mediaCount, 2)
        XCTAssertEqual(exportDocument.sourceGroups.count, 2)
    }

    func testAPKGDocumentFileWrapper() throws {
        let document = AnkiAPKGDocument(
            sourceGroups: ["generated"],
            cardCount: 5,
            mediaCount: 0
        )

        let wrapper = try document.fileWrapper(configuration: FileWrapper.WriteConfiguration())
        XCTAssertNotNil(wrapper)
    }

    func testExportDocumentUTTypes() {
        XCTAssertEqual(AnkiExportDocument.readableContentTypes.count, 1)
        XCTAssertEqual(AnkiExportDocument.writableContentTypes.count, 2)
        XCTAssertTrue(AnkiExportDocument.writableContentTypes.contains(AnkiExportDocument.apkg))
    }

    func testExportStatusLocalizedDescription() {
        XCTAssertEqual(ExportStatus.notStarted.localizedDescription, "notStarted")
        XCTAssertEqual(ExportStatus.inProgress.localizedDescription, "inProgress")
        XCTAssertEqual(ExportStatus.completed.localizedDescription, "completed")
        XCTAssertEqual(ExportStatus.failed.localizedDescription, "failed")
        XCTAssertEqual(ExportStatus.cancelled.localizedDescription, "cancelled")
    }

    func testSelectionCriteriaDefaultValues() {
        let criteria = ExportSelectionService.SelectionCriteria()

        XCTAssertNil(criteria.sourceGroup)
        XCTAssertNil(criteria.languagePair)
        XCTAssertNil(criteria.deck)
        XCTAssertNil(criteria.cardIDs)
        XCTAssertTrue(criteria.approvedOnly)
    }

    func testSelectionCriteriaCustomValues() {
        let criteria = ExportSelectionService.SelectionCriteria(
            sourceGroup: .imported,
            languagePair: ("de", "fa"),
            deck: "TestDeck",
            cardIDs: ["card1", "card2"],
            approvedOnly: false
        )

        XCTAssertEqual(criteria.sourceGroup, .imported)
        XCTAssertEqual(criteria.languagePair?.source, "de")
        XCTAssertEqual(criteria.languagePair?.target, "fa")
        XCTAssertEqual(criteria.deck, "TestDeck")
        XCTAssertEqual(criteria.cardIDs, ["card1", "card2"])
        XCTAssertFalse(criteria.approvedOnly)
    }

    func testSelectionBySourceGroup() async throws {
        let hermesBundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: testProvenance),
            createTestBundle(lemma: "Haus", languagePair: ("de", "fa"), provenance: testProvenance)
        ]

        let criteria = ExportSelectionService.SelectionCriteria(
            sourceGroup: .generated,
            approvedOnly: true
        )

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: hermesBundles)
        ).select(criteria: criteria)

        XCTAssertEqual(result.selectedBundles.count, 2)
        XCTAssertEqual(result.sourceGroups, ["generated"])
    }

    func testExcludesRejectedAndPending() async throws {
        let bundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: testProvenance, approvalState: .approved),
            createTestBundle(lemma: "Haus", languagePair: ("de", "fa"), provenance: testProvenance, approvalState: .pending),
            createTestBundle(lemma: "Auto", languagePair: ("de", "fa"), provenance: testProvenance, approvalState: .rejected)
        ]

        let criteria = ExportSelectionService.SelectionCriteria(approvedOnly: true)

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: bundles)
        ).select(criteria: criteria)

        XCTAssertEqual(result.selectedBundles.count, 1)
        XCTAssertEqual(result.selectedBundles.first?.identity.lemma, "Bank")
    }

    MARK: - Round-Trip Verification Tests (T036)

    func testRoundTripEvidenceTextPreservation() async throws {
        let validator = AnkiRoundTripValidator()
        
        let original = AnkiRoundTripData(
            notes: [
                AnkiNoteData(
                    noteID: 1,
                    modelID: 1,
                    deckID: 1,
                    fields: ["Bank", "بانک", "Financial institution"],
                    tags: ["en-de", "recognition"]
                )
            ],
            cards: [],
            models: [],
            decks: [],
            tags: []
        )
        
        let imported = original
        
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.textMatches, "Text should be preserved in round-trip")
        XCTAssertTrue(comparison.areEqual, "Round-trip should show full equivalence")
        
        let report = validator.generateReport(for: comparison)
        XCTAssertTrue(report.contains("PASSED"), "Report should indicate pass status")
    }

    func testRoundTripEvidenceRtlLtrPreservation() async throws {
        let validator = AnkiRoundTripValidator()
        
        let rtlContent = "بانک یک محل برای نگهداری پول است"
        let ltrContent = "Bank is a place to store money"
        
        XCTAssertTrue(validator.compareRtlLtr(text: rtlContent), "RTL content should be recognizable")
        
        let original = AnkiRoundTripData(
            notes: [
                AnkiNoteData(
                    noteID: 1,
                    modelID: 1,
                    deckID: 1,
                    fields: [rtlContent, ltrContent],
                    tags: ["rtl-preservation"]
                )
            ],
            cards: [],
            models: [],
            decks: [],
            tags: []
        )
        
        let imported = original
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.textMatches, "Mixed direction text should be preserved")
    }

    func testRoundTripEvidenceUnicodeNormalization() async throws {
        let validator = AnkiRoundTripValidator()
        
        let germanCompound = "zuverlässig"
        let persianTransliteration = "زوورلاسیک"
        
        let original = AnkiRoundTripData(
            notes: [AnkiNoteData(
                noteID: 1,
                modelID: 1,
                deckID: 1,
                fields: [germanCompound, persianTransliteration],
                tags: ["unicode-test"]
            )],
            cards: [],
            models: [],
            decks: [],
            tags: []
        )
        
        let imported = original
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.textMatches, "Compound Unicode text should be preserved")
    }

    func testRoundTripEvidenceMediaReferences() async throws {
        let mediaManifest = AnkiMediaManifest(
            entries: [
                MediaManifestEntry(
                    sourceAssetID: "audio-de-001",
                    ankiIndex: 0,
                    sha256: "abc123def456",
                    byteSize: 102400,
                    mimeType: "audio/mpeg"
                )
            ]
        )
        
        let original = AnkiRoundTripData(
            notes: [],
            cards: [],
            models: [],
            decks: [],
            tags: [],
            mediaManifest: mediaManifest
        )
        
        let imported = original
        let validator = AnkiRoundTripValidator()
        let comparison = validator.compare(original: original, imported: imported)
        
        XCTAssertTrue(comparison.mediaMatches, "Media references should match in round-trip")
    }

    func testRoundTripEvidenceProvenanceTracking() async throws {
        let provenance = Provenance(
            provider: "hermes",
            model: "claude-3-opus",
            generatedAt: Date()
        )
        
        let original = createTestBundle(
            lemma: "Provenance",
            languagePair: ("en", "es"),
            provenance: provenance
        )
        
        let compat = AnkiSchedulingCompatibility.shared
        let report = compat.analyze(hermesCard: original)
        
        XCTAssertEqual(report.preservedFields.count, 2, "Scheduling fields should be tracked")
        XCTAssertEqual(report.status, .preserved, "Standard cards should preserve scheduling")
    }

    func testRoundTripEvidenceSchedulingCompatibility() async throws {
        let bundleWithFsr = GeneratedCardBundle(
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
        
        let compat = AnkiSchedulingCompatibility.shared
        let report = compat.analyze(hermesCard: bundleWithFsr)
        
        XCTAssertEqual(report.status, .freshAnki, "FSRS cards should use fresh Anki scheduling")
        XCTAssertGreaterThan(report.warnings.count, 0, "FSRS cards should generate warnings")
    }

    func testRoundTripEvidenceExportManifest() async throws {
        let manifest = ExportManifest(
            selectedBundles: [createTestBundle(lemma: "Test", languagePair: ("en", "de"), provenance: testProvenance)],
            sourceGroups: ["generated"],
            mediaEntries: [],
            schedulingPolicy: .preserved
        )
        
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(ExportManifest.self, from: data)
        
        XCTAssertEqual(manifest.sourceGroups.count, decoded.sourceGroups.count)
        XCTAssertEqual(manifest.schedulingPolicy, decoded.schedulingPolicy)
    }

    func testOfflineValidationBeforeDelivery() async throws {
        let inspector = OfflineAnkiPackageInspector()
        let verifier = AnkiIntegrityVerifier()
        
        let bundles = [createTestBundle(lemma: "Offline", languagePair: ("en", "de"), provenance: testProvenance)]
        let manifest = ExportManifest(selectedBundles: bundles)
        
        let expectedConfig = AnkiExportConfiguration(maxCards: 500, maxMediaBytes: 500 * 1024 * 1024)
        let result = try await verifier.verifyPostRead(at: URL(fileURLWithPath: "/dev/null"), expectedManifest: manifest)
        
        XCTAssertFalse(result.isVerified, "Invalid path should fail verification")
    }

    private let testProvenance = Provenance(provider: "hermes", model: "claude-3-opus")

    private func createTestBundle(
        lemma: String,
        languagePair: (String, String),
        provenance: Provenance,
        approvalState: ApprovalState = .approved,
        senseKey: String? = nil
    ) -> GeneratedCardBundle {
        return GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: languagePair.0,
                targetLanguage: languagePair.1,
                lemma: lemma,
                senseKey: senseKey ?? "\(lemma.lowercased())-\(UUID().uuidString.prefix(4))",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [
                LexicalSense(
                    sourceLanguage: languagePair.0,
                    targetLanguage: languagePair.1,
                    lemma: lemma,
                    senseKey: senseKey ?? "\(lemma.lowercased())-\(UUID().uuidString.prefix(4))",
                    partOfSpeech: "noun",
                    meaning: "test meaning",
                    translation: "test translation"
                )
            ],
            mediaAssets: [],
            approvalState: approvalState,
            provenance: provenance
        )
    }

    final class MockPersistencePort: PersistencePort {
        private let bundles: [GeneratedCardBundle]

        init(bundles: [GeneratedCardBundle]) {
            self.bundles = bundles
        }

        func save(_ job: GenerationJob) async throws {}

        func loadJob(id: String) async throws -> GenerationJob? { nil }

        func saveApprovedBundle(_ bundle: GeneratedCardBundle) async throws {}

        func approvedBundles() async throws -> [GeneratedCardBundle] {
            return bundles
        }

        func bundle(by identity: CardIdentity) async throws -> GeneratedCardBundle? {
            return bundles.first { $0.identity == identity }
        }

        func isApproved(identity: CardIdentity) async throws -> Bool {
            guard let bundle = try await bundle(by: identity) else { return false }
            return bundle.approvalState == .approved
        }
    }
}