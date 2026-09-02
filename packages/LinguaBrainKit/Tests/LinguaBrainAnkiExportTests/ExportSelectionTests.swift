import XCTest
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainMedia
import LinguaBrainAnkiExport
@testable import LinguaBrainApplication

final class ExportSelectionTests: XCTestCase {
    let testProvenance = Provenance(
        provider: "hermes",
        model: "claude-3-opus"
    )

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
        XCTAssertTrue(result.sourceGroups.contains(.generated))
    }

    func testSelectionByLanguagePair() async throws {
        let bundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: testProvenance),
            createTestBundle(lemma: "Casa", languagePair: ("es", "it"), provenance: testProvenance),
            createTestBundle(lemma: "Haus", languagePair: ("de", "fa"), provenance: testProvenance)
        ]

        let criteria = ExportSelectionService.SelectionCriteria(
            languagePair: ("de", "fa"),
            approvedOnly: true
        )

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: bundles)
        ).select(criteria: criteria)

        XCTAssertEqual(result.selectedBundles.count, 2)
        XCTAssertTrue(result.selectedBundles.allSatisfy {
            $0.identity.sourceLanguage == "de" && $0.identity.targetLanguage == "fa"
        })
    }

    func testSelectionByExplicitCardIDs() async throws {
        let bundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: testProvenance, senseKey: "bank-001"),
            createTestBundle(lemma: "Haus", languagePair: ("de", "fa"), provenance: testProvenance, senseKey: "haus-002"),
            createTestBundle(lemma: "Auto", languagePair: ("de", "fa"), provenance: testProvenance, senseKey: "auto-003")
        ]

        let criteria = ExportSelectionService.SelectionCriteria(
            cardIDs: ["bank-001", "auto-003"],
            approvedOnly: true
        )

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: bundles)
        ).select(criteria: criteria)

        XCTAssertEqual(result.selectedBundles.count, 2)
        XCTAssertTrue(result.selectedBundles.contains { $0.identity.senseKey == "bank-001" })
        XCTAssertTrue(result.selectedBundles.contains { $0.identity.senseKey == "auto-003" })
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

    func testCombinedFilters() async throws {
        let bundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: testProvenance),
            createTestBundle(lemma: "Casa", languagePair: ("es", "it"), provenance: testProvenance),
            createTestBundle(lemma: "Haus", languagePair: ("de", "fa"), provenance: testProvenance)
        ]

        let criteria = ExportSelectionService.SelectionCriteria(
            sourceGroup: .generated,
            languagePair: ("de", "fa"),
            approvedOnly: true
        )

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: bundles)
        ).select(criteria: criteria)

        XCTAssertEqual(result.selectedBundles.count, 2)
    }

    func testProvenanceTagMapping() async throws {
        let hermesProvenance = Provenance(provider: "hermes", model: "claude")
        let importedProvenance = Provenance(provider: "imported", model: "anki")

        let bundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: hermesProvenance),
            createTestBundle(lemma: "Haus", languagePair: ("de", "fa"), provenance: importedProvenance)
        ]

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: bundles)
        ).selectAllApproved()

        XCTAssertEqual(result.provenanceTags.count, 2)
        XCTAssertTrue(result.provenanceTags.contains { $0.sourceGroup == .generated })
        XCTAssertTrue(result.provenanceTags.contains { $0.sourceGroup == .imported })
    }

    func testSelectionResultSourceGroups() async throws {
        let bundles = [
            createTestBundle(lemma: "Bank", languagePair: ("de", "fa"), provenance: testProvenance),
            createTestBundle(lemma: "Haus", languagePair: ("es", "it"), provenance: Provenance(provider: "imported", model: "user"))
        ]

        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: bundles)
        ).selectAllApproved()

        XCTAssertEqual(result.totalCards, 2)
        XCTAssertEqual(result.sourceGroups.count, 2)
        XCTAssertTrue(result.sourceGroups.contains(.generated))
        XCTAssertTrue(result.sourceGroups.contains(.imported))
    }

    func testMediaOwnershipInProvenanceTag() {
        let tag = ExportProvenance(
            sourceGroup: .generated,
            cardsSelected: 10,
            mediaAssets: 5
        )

        XCTAssertEqual(tag.cardsSelected, 10)
        XCTAssertEqual(tag.mediaAssets, 5)
    }

    func testSelectionResultWithEmptyBundles() async throws {
        let result = try await ExportSelectionService(
            persistencePort: MockPersistencePort(bundles: [])
        ).selectAllApproved()

        XCTAssertEqual(result.selectedBundles.count, 0)
        XCTAssertEqual(result.totalCards, 0)
        XCTAssertEqual(result.sourceGroups.count, 0)
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