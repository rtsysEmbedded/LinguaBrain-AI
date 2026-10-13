import XCTest
@testable import LinguaBrainDomain

final class PracticeEvidencePolicyTests: XCTestCase {
    func testRevealAndCopyAreNotIndependentRecall() {
        XCTAssertTrue(PracticeEvidencePolicy.countsAsIndependentRecall(outcome: .correct, help: []))
        XCTAssertFalse(PracticeEvidencePolicy.countsAsIndependentRecall(outcome: .correct, help: [HelpEvent(kind: .reveal, at: Date())]))
        XCTAssertFalse(PracticeEvidencePolicy.countsAsIndependentRecall(outcome: .correct, help: [HelpEvent(kind: .copiedAnswer, at: Date())]))
        XCTAssertFalse(PracticeEvidencePolicy.countsAsIndependentRecall(outcome: .skipped, help: []))
    }

    func testPolicyMapsEveryOutcomeToDeterministicLearningEffects() {
        let cases: [(AttemptOutcome, Double?, PracticeScheduleRating?, PracticeFeedbackDisposition, PracticeRetryDisposition)] = [
            (.correct, 1, .good, .show, .notNeeded),
            (.partial, 0.5, .hard, .show, .allowed),
            (.incorrect, 0, .again, .show, .allowed),
            (.skipped, 0, nil, .none, .notApplicable),
            (.unavailable, nil, nil, .showUnavailable, .allowed),
            (.pending, nil, nil, .showUnavailable, .allowed)
        ]

        for (outcome, expectedScore, expectedRating, expectedFeedback, expectedRetry) in cases {
            let decision = PracticeEvidencePolicy.decision(outcome: outcome, confidence: 0.9)
            let repeated = PracticeEvidencePolicy.decision(outcome: outcome, confidence: 0.9)
            XCTAssertEqual(decision, repeated)
            XCTAssertEqual(decision.score, expectedScore)
            XCTAssertEqual(decision.scheduleRating, expectedRating)
            XCTAssertEqual(decision.feedback, expectedFeedback)
            XCTAssertEqual(decision.retry, expectedRetry)

            if outcome == .correct || outcome == .partial || outcome == .incorrect {
                XCTAssertTrue(decision.independentRecallEligible)
                XCTAssertTrue(decision.schedulingEligible)
            } else {
                XCTAssertFalse(decision.independentRecallEligible)
                XCTAssertFalse(decision.schedulingEligible)
            }
        }
    }

    func testHintAndRetryDoNotSuppressButRevealAndCopyDoSuppress() {
        let date = Date(timeIntervalSince1970: 2_000)
        let hint = HelpEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, kind: .hint, at: date)
        let retry = HelpEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, kind: .retry, at: date)
        let reveal = HelpEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, kind: .reveal, at: date)
        let copied = HelpEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, kind: .copiedAnswer, at: date)

        for help in [[hint], [retry]] {
            let decision = PracticeEvidencePolicy.decision(outcome: .correct, help: help)
            XCTAssertTrue(decision.independentRecallEligible)
            XCTAssertTrue(decision.schedulingEligible)
            XCTAssertEqual(decision.masteryDelta, 1)
        }
        for help in [[reveal], [copied], [hint, reveal], [retry, copied]] {
            let decision = PracticeEvidencePolicy.decision(outcome: .correct, help: help)
            XCTAssertFalse(decision.independentRecallEligible)
            XCTAssertFalse(decision.schedulingEligible)
            XCTAssertEqual(decision.masteryDelta, 0)
            XCTAssertEqual(decision.retry, .allowed)
        }
    }

    func testSkipEventOverridesAnyProposedGradableOutcome() {
        let event = PracticeEvent(id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!, kind: .skip, at: Date(timeIntervalSince1970: 2_000))
        let decision = PracticeEvidencePolicy.decision(outcome: .correct, score: 1, events: [event])

        XCTAssertEqual(decision.outcome, .skipped)
        XCTAssertEqual(decision.score, 0)
        XCTAssertFalse(decision.schedulingEligible)
        XCTAssertEqual(decision.feedback, .none)
    }

    func testLowConfidenceAndMalformedNumbersBecomeUnavailable() {
        let low = PracticeEvidencePolicy.decision(outcome: .correct, score: 1, confidence: 0.49)
        let malformedScore = PracticeEvidencePolicy.decision(outcome: .partial, score: 1.01)
        let malformedConfidence = PracticeEvidencePolicy.decision(outcome: .incorrect, confidence: .nan)
        let transportFailure = PracticeEvidencePolicy.decision(outcome: .correct, unavailableReason: .transportFailure)

        XCTAssertEqual(low.outcome, .unavailable)
        XCTAssertEqual(low.unavailableReason, .lowConfidence)
        XCTAssertEqual(malformedScore.outcome, .unavailable)
        XCTAssertEqual(malformedScore.unavailableReason, .malformedOutput)
        XCTAssertEqual(malformedConfidence.outcome, .unavailable)
        XCTAssertEqual(malformedConfidence.unavailableReason, .malformedOutput)
        XCTAssertEqual(transportFailure.outcome, .unavailable)
        XCTAssertEqual(transportFailure.unavailableReason, .transportFailure)
        XCTAssertFalse(low.schedulingEligible)
        XCTAssertFalse(malformedScore.schedulingEligible)
    }
}
