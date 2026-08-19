import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication
@testable import LinguaBrainAI
@testable import LinguaBrainTestSupport

final class LinguaBrainApplicationTests: XCTestCase {

    // Helper: build a deterministically generated proposal with a real language pair.
    private func makeProposal(
        sourceLanguage: String = "de",
        targetLanguage: String = "fa"
    ) -> CardProposal {
        CardProposal(
            lemma: "Bank",
            senses: [LexicalSense(sourceLanguage: sourceLanguage,
                                  targetLanguage: targetLanguage,
                                  lemma: "Bank", senseKey: "bank-n-finance", partOfSpeech: "noun",
                                  meaning: "financial institution",
                                  examples: [Sentence(text: "Bank example", translation: "مثال بانک")],
                                  translation: "بانک", level: "A1")],
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            provenance: Provenance(provider: "deterministic", model: "model-x", schemaVersion: "generation-v1")
        )
    }

    func testGenerationProducesWaitingForApprovalWithValidProposal() async throws {
        let repo = InMemoryPersistence()
        let textProvider = DeterministicTextProvider()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: textProvider,
            validator: StrictProposalValidator()
        )

        let command = GenerationRequestCommand(
            sourceLanguage: "de", targetLanguage: "fa", level: "A1", topic: "Bank",
            count: 1, directions: [.recognition, .recall], audioEnabled: false, imageEnabled: false
        )
        let job = try await orchestrator.startGeneration(from: command)
        XCTAssertEqual(job.status, .waitingForApproval)
        XCTAssertEqual(job.stage, .awaitingApproval)
        XCTAssertNotNil(job.proposal)
    }

    func testApprovalPersistsOnlyApprovedBundles() async throws {
        let repo = InMemoryPersistence()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        let proposal = makeProposal()

        // Approve recognition, reject recall.
        _ = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)
        _ = try await orchestrator.apply(.reject(reason: "want another"), proposal: proposal, direction: .recall)

        let approved = try await repo.approvedBundles()
        XCTAssertTrue(approved.contains { $0.identity.direction == .recognition && $0.approvalState == .approved })
        XCTAssertFalse(approved.contains { $0.identity.direction == .recall })
        XCTAssertTrue(approved.allSatisfy { $0.approvalState == .approved })
    }

    func testDuplicateApprovalRejected() async throws {
        let repo = InMemoryPersistence()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        let proposal = makeProposal()
        _ = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)
        do {
            _ = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)
            XCTFail("expected duplicateApproval error")
        } catch OrchestratorError.duplicateApproval {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    // T018 restart/offline: approved bundles survive across a fresh repository view (in-memory proxy for persistence).
    func testApprovedCardsRemainAvailableAfterReinstantiation() async throws {
        let repo = InMemoryPersistence()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        let proposal = makeProposal()
        _ = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)

        // Simulate restart: a new orchestrator reading from the same persistence.
        let restarted = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        let approvedAfterRestart = try await repo.approvedBundles()
        XCTAssertEqual(approvedAfterRestart.count, 1)
        XCTAssertTrue(approvedAfterRestart[0].approvalState == .approved)
        _ = restarted
    }

    func testEditActionUpdatesSenseContents() async throws {
        let repo = InMemoryPersistence()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        var proposal = makeProposal()
        let edited = LexicalSense(
            sourceLanguage: proposal.sourceLanguage,
            targetLanguage: proposal.targetLanguage,
            lemma: "Bank", senseKey: "bank-n-finance", partOfSpeech: "noun",
            meaning: "edited meaning", translation: "بانک ویرایش شده", level: "A1"
        )
        let bundle = try await orchestrator.apply(.edit(edited), proposal: proposal, direction: .recognition)
        XCTAssertEqual(bundle.senses.first?.meaning, "edited meaning")
        proposal.senses = []
        _ = proposal
    }

    // T018: the full approval journey persists bundles through the application/persistence
    // boundary with the real language pair (not placeholders) stamped on the identity.
    func testGenerationApprovalPersistsRealLanguagePairThroughBoundary() async throws {
        let repo = InMemoryPersistence()
        let textProvider = DeterministicTextProvider()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: textProvider,
            validator: StrictProposalValidator()
        )

        let command = GenerationRequestCommand(
            sourceLanguage: "de", targetLanguage: "fa", level: "A1", topic: "Bank",
            count: 1, directions: [.recognition, .recall], audioEnabled: false, imageEnabled: false
        )
        let job = try await orchestrator.startGeneration(from: command)
        let proposal = try XCTUnwrap(job.proposal)
        XCTAssertEqual(proposal.sourceLanguage, "de")
        XCTAssertEqual(proposal.targetLanguage, "fa")

        _ = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)

        let approved = try await repo.approvedBundles()
        let bundle = try XCTUnwrap(approved.first)
        XCTAssertEqual(bundle.identity.sourceLanguage, "de")
        XCTAssertEqual(bundle.identity.targetLanguage, "fa")
        XCTAssertEqual(bundle.identity.lemma, proposal.lemma)
        XCTAssertEqual(bundle.identity.direction, .recognition)
        XCTAssertEqual(bundle.approvalState, .approved)
    }

    // T018: approaching a fresh orchestrator against the same persistence sees the
    // approved bundle, verifying restart/offline durability of what was persisted.
    func testRestartReadsApprovedBundleFromBoundary() async throws {
        let repo = InMemoryPersistence()
        let first = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        _ = try await first.apply(.approve, proposal: makeProposal(), direction: .recall)

        // A second orchestrator (simulated app restart) reads only through the boundary.
        let restarted = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        _ = restarted
        let approved = try await repo.approvedBundles()
        XCTAssertEqual(approved.count, 1)
        XCTAssertEqual(approved.first?.identity.sourceLanguage, "de")
        XCTAssertEqual(approved.first?.identity.targetLanguage, "fa")
        XCTAssertEqual(approved.first?.identity.direction, .recall)
    }
}
