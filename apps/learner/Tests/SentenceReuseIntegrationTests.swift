import Foundation
import XCTest
import LinguaBrainApplication
import LinguaBrainDomain
import LinguaBrainPersistence

@MainActor
final class SentenceReuseIntegrationTests: XCTestCase {
    func testSyntheticWritingAcceptSurvivesRestartAndFeedsOnlySelectedSkill() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("app-sentence-loop-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = try FileBackedPracticeRepository(url: url)
        let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000804")!
        let request = SentenceLearningRequest(learnerID: "app-learner", sourceLanguage: "fa", targetLanguage: "de", meaningKey: "meaning", attemptID: attemptID, originalResponse: "raw", minimalCorrection: "valid sentence")
        let result = try await SentenceLearningService(repository: repository).accept(request)
        let sentence = try XCTUnwrap(result.sentence)
        let reopened = try FileBackedPracticeRepository(url: url)
        let restored = try await reopened.sentence(id: sentence.id, revision: 1)
        XCTAssertEqual(restored?.text, "valid sentence")
        let grammarUnit = ReviewUnit(learnerID: "app-learner", skill: .grammar, objectiveKey: "grammar", sentenceID: sentence.id, sentenceRevision: 1)
        let writingUnit = ReviewUnit(learnerID: "app-learner", skill: .writing, objectiveKey: "writing")
        let plan = AdaptivePracticePlanner.makePlan(candidates: [AdaptivePracticeCandidate(reviewUnit: grammarUnit, sentence: sentence), AdaptivePracticeCandidate(reviewUnit: writingUnit, capabilityAvailable: false)], now: Date(timeIntervalSince1970: 10), seed: 9, limit: 3)
        XCTAssertEqual(plan.items.map { $0.candidate.reviewUnit.skill }, [.grammar])
    }
}
