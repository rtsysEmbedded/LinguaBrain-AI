import Foundation
import XCTest
import LinguaBrainDomain
import LinguaBrainPersistence
import LinguaBrainTestSupport
@testable import LinguaBrainApplication

final class SentenceLearningAndPlannerTests: XCTestCase {
    func testAcceptIsScopedIdempotentAndPreservesOriginalResponse() async throws {
        let repository = DeterministicPracticeRepository()
        let service = SentenceLearningService(repository: repository)
        let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000701")!
        let request = SentenceLearningRequest(learnerID: "learner-a", sourceLanguage: "fa", targetLanguage: "de", meaningKey: "I rise early", attemptID: attemptID, originalResponse: "Ich stehen früh auf", minimalCorrection: "Ich stehe früh auf", naturalVariant: "Morgens stehe ich früh auf")
        let first = try await service.accept(request)
        let second = try await service.accept(request)
        XCTAssertEqual(first.decision, .accepted)
        XCTAssertEqual(second.decision, .duplicate)
        XCTAssertEqual(first.sentence?.originalLearnerResponse, "Ich stehen früh auf")
        let otherLearner = try await service.accept(SentenceLearningRequest(learnerID: "learner-b", sourceLanguage: "fa", targetLanguage: "de", meaningKey: "I rise early", attemptID: attemptID, originalResponse: request.originalResponse, minimalCorrection: request.minimalCorrection))
        XCTAssertNotEqual(first.sentence?.id, otherLearner.sentence?.id)
    }

    func testEditRequiresRevalidationAndCreatesImmutableRevision() async throws {
        let repository = DeterministicPracticeRepository()
        let service = SentenceLearningService(repository: repository)
        let request = SentenceLearningRequest(learnerID: "learner-a", sourceLanguage: "fa", targetLanguage: "de", meaningKey: "meaning", attemptID: UUID(), originalResponse: "raw", minimalCorrection: "Validated sentence")
        let accepted = try await service.accept(request)
        let sentence = try XCTUnwrap(accepted.sentence)
        do {
            _ = try await service.editAcceptedSentence(sentence, text: "Edited", revalidated: false, sourceAttemptID: request.attemptID)
            XCTFail("expected revalidation")
        } catch let error as SentenceLearningError { XCTAssertEqual(error, .revalidationRequired) }
        let edited = try await service.editAcceptedSentence(sentence, text: "Edited", revalidated: true, sourceAttemptID: request.attemptID)
        XCTAssertEqual(edited.sentence?.revision, 2)
        XCTAssertEqual(edited.sentence?.originalLearnerResponse, "raw")
        let original = try await repository.sentence(id: sentence.id, revision: 1)
        XCTAssertEqual(original?.text, "Validated sentence")
    }

    func testPlannerIsDeterministicFiltersUnavailableAndRecentCandidates() {
        let now = Date(timeIntervalSince1970: 1_000)
        let overdue = AdaptivePracticeCandidate(reviewUnit: ReviewUnit(skill: .writing, objectiveKey: "overdue"), projection: PracticeMasteryProjection(state: .learning, score: 0.2, dueAt: now.addingTimeInterval(-10)), ruleIDs: ["de.verb.inflection"])
        let unknown = AdaptivePracticeCandidate(reviewUnit: ReviewUnit(skill: .grammar, objectiveKey: "unknown"))
        let unavailable = AdaptivePracticeCandidate(reviewUnit: ReviewUnit(skill: .speaking, objectiveKey: "off"), capabilityAvailable: false)
        let recent = AdaptivePracticeCandidate(reviewUnit: ReviewUnit(skill: .listening, objectiveKey: "recent"), recentlyAttempted: true)
        let candidates = [unknown, recent, unavailable, overdue]
        let first = AdaptivePracticePlanner.makePlan(candidates: candidates, now: now, seed: 42, limit: 4)
        let second = AdaptivePracticePlanner.makePlan(candidates: candidates, now: now, seed: 42, limit: 4)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.items.map { $0.candidate.reviewUnit.objectiveKey }, ["overdue", "unknown"])
        XCTAssertEqual(first.items.first?.reason, .overdue)
    }
}
