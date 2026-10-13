import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication
@testable import LinguaBrainAI
@testable import LinguaBrainTestSupport

final class LinguaBrainApplicationTests: XCTestCase {
    func testSkillMasteryTracksIndependentObjectiveEvidence() {
        let objective = LearningObjective(id: "entlassen.work.recall", senseKey: "entlassen.work", skill: .recall, targetLevel: "B1")
        var mastery = SkillMastery(objective: objective)
        mastery.record(correct: true, at: Date(timeIntervalSince1970: 100))
        mastery.record(correct: false, at: Date(timeIntervalSince1970: 200))
        XCTAssertEqual(mastery.attempts, 2)
        XCTAssertEqual(mastery.correct, 1)
        XCTAssertEqual(mastery.score, 0.5, accuracy: 0.0001)
        XCTAssertEqual(mastery.objective.skill, .recall)
    }

    func testAdaptivePlannerIsDeterministicAndRespectsLowEnergyCapacity() {
        let now = Date(timeIntervalSince1970: 10_000)
        let weak = LearningObjective(id: "weak", senseKey: "haus", skill: .recall)
        let strong = LearningObjective(id: "strong", senseKey: "arbeit", skill: .recognition)
        let candidates = [
            AdaptiveLearningCandidate(objective: strong, dueAt: now, mastery: 0.9),
            AdaptiveLearningCandidate(objective: weak, dueAt: now.addingTimeInterval(-86_400), mastery: 0.1)
        ]
        let plan = AdaptiveLearningPlanner.makePlan(candidates: candidates, availableMinutes: 10, energy: 2, now: now)
        XCTAssertEqual(plan.candidates.map { $0.objective.id }, ["weak", "strong"])
        XCTAssertEqual(plan.energy, 2)
        XCTAssertTrue(plan.explanation.contains("Low-energy"))
    }

    func testAdaptivePlannerAppliesDailyStateAndFallsBackWhenStale() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let candidates = (0..<20).map { index in
            AdaptiveLearningCandidate(
                objective: LearningObjective(id: "item-\(index)", senseKey: "item-\(index)", skill: .recognition),
                mastery: 0.2
            )
        }
        let light = AdaptiveLearningPlanner.makePlan(
            candidates: candidates,
            dailyState: DailyLearningState(energy: 3, availableMinutes: 20, motivation: 1, mode: .lightReview, capturedAt: now),
            now: now
        )
        let challenge = AdaptiveLearningPlanner.makePlan(
            candidates: candidates,
            dailyState: DailyLearningState(energy: 9, availableMinutes: 20, motivation: 5, mode: .challenge, capturedAt: now),
            now: now
        )
        XCTAssertLessThan(light.candidates.count, challenge.candidates.count)
        XCTAssertEqual(challenge.mode, .challenge)
        XCTAssertFalse(challenge.usedDefaultDailyState)

        let stale = AdaptiveLearningPlanner.makePlan(
            candidates: candidates,
            dailyState: DailyLearningState(energy: 10, availableMinutes: 60, motivation: 5, mode: .challenge, capturedAt: now.addingTimeInterval(-19 * 60 * 60)),
            now: now
        )
        XCTAssertTrue(stale.usedDefaultDailyState)
        XCTAssertEqual(stale.energy, 6)
        XCTAssertEqual(stale.availableMinutes, 20)
    }

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

    // MARK: - T024: Polysemy, Media Failure, Cache, and Offline Playback Tests

    // T024a: Verify independent identities for different senses
    func testPolysemyCreatesDistinctSenseIdentities() {
        // Create two different senses of "Bank"
        let financeSense = LexicalSense(
            sourceLanguage: "de",
            targetLanguage: "fa",
            lemma: "Bank",
            senseKey: "bank-n-finance",
            partOfSpeech: "noun",
            meaning: "financial institution",
            translation: "بانک"
        )

        let riverSense = LexicalSense(
            sourceLanguage: "de",
            targetLanguage: "fa",
            lemma: "Bank",
            senseKey: "bank-n-river",
            partOfSpeech: "noun",
            meaning: "river edge",
            translation: "کناره"
        )

        // Verify senseKeys are different (independent identities)
        XCTAssertNotEqual(financeSense.senseKey, riverSense.senseKey)
        XCTAssertNotEqual(financeSense, riverSense)

        // Verify they can be distinguished by senseKey
        XCTAssertTrue(financeSense.senseKey.hasPrefix("bank-n-finance"))
        XCTAssertTrue(riverSense.senseKey.hasPrefix("bank-n-river"))
    }

    // T024b: Media failure fallback - text-only when audio unavailable
    func testMediaFailureFallsBackToTextOnly() async throws {
        let repo = InMemoryPersistence()

        // Text provider generates proposal
        let textProvider = DeterministicTextProvider()

        // Audio provider is nil (simulating unavailable/quota exceeded)
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: textProvider,
            audioProvider: nil, // No audio provider
            validator: StrictProposalValidator()
        )

        let proposal = makeProposal()
        let bundle = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)

        // Bundle should still be approved even without audio
        XCTAssertEqual(bundle.approvalState, .approved)
        XCTAssertEqual(bundle.senses.count, 1)

        // Verify the bundle was persisted
        let persisted = try await repo.approvedBundles()
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].provenance.provider, "deterministic")
    }

    // T024c: Cache lifecycle simulation
    func testMediaAssetCacheLifecycle() async throws {
        // Create a media asset with all required lifecycle fields
        let media = MediaAsset(
            kind: .audio,
            locale: "fa",
            checksum: "abc123sha256",
            fileSize: 1024,
            provider: "test-audio-provider",
            model: "tts-model",
            generatedAt: Date(),
            consentContext: "learning",
            cacheReference: "/tmp/cache/audio_bank_001.mp3",
            availability: .available,
            fallbackReason: nil
        )

        // Verify all required fields are present
        XCTAssertEqual(media.kind, .audio)
        XCTAssertEqual(media.locale, "fa")
        XCTAssertEqual(media.checksum, "abc123sha256")
        XCTAssertEqual(media.fileSize, 1024)
        XCTAssertEqual(media.provider, "test-audio-provider")
        XCTAssertEqual(media.model, "tts-model")
        XCTAssertEqual(media.cacheReference, "/tmp/cache/audio_bank_001.mp3")
        XCTAssertEqual(media.availability, .available)
        XCTAssertNil(media.fallbackReason)

        // Test missing availability with fallback reason
        let missingMedia = MediaAsset(
            kind: .audio,
            locale: "fa",
            checksum: "missing123",
            provider: "quota-exceeded",
            model: "model",
            availability: .missing,
            fallbackReason: "Provider quota exceeded - text-only fallback"
        )

        XCTAssertEqual(missingMedia.availability, .missing)
        XCTAssertEqual(missingMedia.fallbackReason, "Provider quota exceeded - text-only fallback")
    }

    // T024d: Offline playback bundle persistence
    func testApprovedBundlePersistsForOfflineStudy() async throws {
        let repo = InMemoryPersistence()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )

        // Generate and approve a bundle
        let proposal = makeProposal()
        let bundle = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)

        // Verify bundle was approved
        XCTAssertEqual(bundle.approvalState, .approved)

        // Save is done automatically by the orchestrator

        // Create a new orchestrator to simulate app restart (offline mode)
        let _ = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )

        // Reload persisted bundles
        let persistedBundles = try await repo.approvedBundles()

        // Verify the bundle is still available offline
        XCTAssertEqual(persistedBundles.count, 1)
        XCTAssertEqual(persistedBundles[0].senses.count, 1)
        XCTAssertEqual(persistedBundles[0].identity.sourceLanguage, "de")
        XCTAssertEqual(persistedBundles[0].identity.targetLanguage, "fa")
    }

    // T024e: Verify generation request includes media preferences
    func testMediaPreferencesInGenerationRequest() async throws {
        let repo = InMemoryPersistence()
        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )

        // Request with audio enabled
        let command = GenerationRequestCommand(
            sourceLanguage: "en",
            targetLanguage: "es",
            level: "A1",
            count: 1,
            directions: [.recognition],
            audioEnabled: true,
            imageEnabled: true
        )

        let job = try await orchestrator.startGeneration(from: command)

        // Verify the request has media preferences
        XCTAssertEqual(job.request.mediaPreferences.audioEnabled, true)
        XCTAssertEqual(job.request.mediaPreferences.imageEnabled, true)
    }
}
