import Foundation
import XCTest
import LinguaBrainDomain
import LinguaBrainPersistence
import LinguaBrainTestSupport
@testable import LinguaBrainApplication

final class AdaptivePracticeLoopTests: XCTestCase {
    func testWritingAcceptRestartAndPlannerReuseAcceptedRevision() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("adaptive-loop-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000801")!
        let request = SentenceLearningRequest(learnerID: "learner", sourceLanguage: "fa", targetLanguage: "de", meaningKey: "I wake early", attemptID: attemptID, originalResponse: "Ich stehen früh auf", minimalCorrection: "Ich stehe früh auf", ruleReferences: [RuleReference(code: "de.verb.inflection")])
        let firstRepository = try FileBackedPracticeRepository(url: url)
        let first = try await SentenceLearningService(repository: firstRepository).accept(request)
        let sentence = try XCTUnwrap(first.sentence)
        let reopened = try FileBackedPracticeRepository(url: url)
        let restored = try await reopened.sentence(id: sentence.id, revision: sentence.revision)
        let unit = ReviewUnit(learnerID: "learner", skill: .grammar, objectiveKey: "de.verb.inflection", sentenceID: restored?.id, sentenceRevision: restored?.revision)
        let plan = AdaptivePracticePlanner.makePlan(candidates: [AdaptivePracticeCandidate(reviewUnit: unit, sentence: restored)], now: Date(timeIntervalSince1970: 100), seed: 7, limit: 1)
        XCTAssertEqual(plan.items.first?.candidate.sentence?.text, "Ich stehe früh auf")
        XCTAssertEqual(plan.items.first?.reason, .unknownObjective)
        XCTAssertEqual(restored?.originalLearnerResponse, request.originalResponse)
    }

    func testDeclineAndCapabilityOffDoNotCreateReusableEvidence() async throws {
        let repository = DeterministicPracticeRepository()
        let service = SentenceLearningService(repository: repository)
        let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000802")!
        let declined = await service.decline(attemptID: attemptID)
        XCTAssertEqual(declined.decision, .declined)
        let unit = ReviewUnit(skill: .listening, objectiveKey: "off")
        let plan = AdaptivePracticePlanner.makePlan(candidates: [AdaptivePracticeCandidate(reviewUnit: unit, capabilityAvailable: false)], now: Date(timeIntervalSince1970: 100), seed: 1, limit: 1)
        XCTAssertTrue(plan.isEmpty)
    }

    func testRevisionReplayCreatesNewRevisionWithoutRegradingPriorEvent() async throws {
        let repository = DeterministicPracticeRepository()
        let service = SentenceLearningService(repository: repository)
        let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000803")!
        let request = SentenceLearningRequest(learnerID: "learner", sourceLanguage: "fa", targetLanguage: "de", meaningKey: "meaning", attemptID: attemptID, originalResponse: "raw", minimalCorrection: "first")
        let accepted = try await service.accept(request)
        let sentence = try XCTUnwrap(accepted.sentence)
        let revised = try await service.editAcceptedSentence(sentence, text: "second", revalidated: true, sourceAttemptID: attemptID)
        XCTAssertEqual(revised.sentence?.revision, 2)
        let original = try await repository.sentence(id: sentence.id, revision: 1)
        let updated = try await repository.sentence(id: sentence.id, revision: 2)
        XCTAssertEqual(original?.text, "first")
        XCTAssertEqual(updated?.text, "second")
    }
}
