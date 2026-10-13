import XCTest
@testable import LinguaBrainDomain

final class PracticeIdentityTests: XCTestCase {
    func testReviewUnitIdentityIsStableForSameLogicalTarget() {
        let sentenceID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let a = ReviewUnit(learnerID: "learner", skill: .grammar, objectiveKey: "weil-verb", sentenceID: sentenceID, sentenceRevision: 3)
        let b = ReviewUnit(learnerID: "learner", skill: .grammar, objectiveKey: "weil-verb", sentenceID: sentenceID, sentenceRevision: 3)
        let c = ReviewUnit(learnerID: "learner", skill: .listening, objectiveKey: "weil-verb", sentenceID: sentenceID, sentenceRevision: 3)
        XCTAssertEqual(a.id, b.id); XCTAssertNotEqual(a.id, c.id); XCTAssertEqual(a.stableKey, b.stableKey)
    }
    func testSentenceKeepsOriginalCorrectionVariantAndEvidenceSeparate() {
        let sentence = Sentence(text: "Ich gehe weil ich müde bin.", translation: "من می‌روم چون خسته‌ام", originalLearnerResponse: "Ich gehe weil ich müde bin.", minimalCorrection: "Ich gehe, weil ich müde bin.", naturalVariant: "Ich gehe, weil ich müde bin.", validation: .validated, ruleReferences: [RuleReference(code: "weil-verb")], lexicalReferences: [LexicalReference(senseKey: "gehen.v1")])
        XCTAssertEqual(sentence.originalLearnerResponse, "Ich gehe weil ich müde bin."); XCTAssertNotEqual(sentence.minimalCorrection, sentence.originalLearnerResponse); XCTAssertNotEqual(sentence.naturalVariant, sentence.originalLearnerResponse); XCTAssertEqual(sentence.ruleReferences.count, 1); XCTAssertEqual(sentence.lexicalReferences.count, 1)
    }

    func testSentenceCorrectionCreatesSeparateImmutableRevision() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let original = Sentence(id: id, revision: 1, text: "Ich gehe weil ich müde bin.", translation: "من می‌روم چون خسته‌ام", originalLearnerResponse: "Ich gehe weil ich müde bin.", validation: .unvalidated)
        let corrected = Sentence(id: id, revision: 2, text: "Ich gehe, weil ich müde bin.", translation: original.translation, originalLearnerResponse: original.originalLearnerResponse, minimalCorrection: "Ich gehe, weil ich müde bin.", validation: .validated)

        XCTAssertEqual(original.id, corrected.id)
        XCTAssertEqual(original.revision, 1)
        XCTAssertEqual(corrected.revision, 2)
        XCTAssertEqual(original.text, "Ich gehe weil ich müde bin.")
        XCTAssertEqual(corrected.originalLearnerResponse, original.originalLearnerResponse)
        XCTAssertNotEqual(original.text, corrected.text)
    }

    func testLegacySentencePayloadDecodesWithRevisionDefaults() throws {
        let payload = #"{"text":"A sentence","translation":"یک جمله"}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Sentence.self, from: payload)
        let expected = Sentence(text: "A sentence", translation: "یک جمله")

        XCTAssertEqual(decoded.id, expected.id)
        XCTAssertEqual(decoded.revision, 1)
        XCTAssertNil(decoded.originalLearnerResponse)
        XCTAssertEqual(decoded.ruleReferences, [])
        XCTAssertEqual(decoded.lexicalReferences, [])
    }

    func testAttemptSupportsAllOutcomesAndFirstAttemptSemantics() {
        let exerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let unitID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let date = Date(timeIntervalSince1970: 1_000)

        for outcome in AttemptOutcome.allCases {
            let attempt = Attempt(id: UUID(), exerciseID: exerciseID, reviewUnitID: unitID, response: "response", submittedAt: date, attemptIndex: outcome == .pending ? 0 : 1, outcome: outcome)
            XCTAssertEqual(attempt.outcome, outcome)
            XCTAssertEqual(attempt.isFirstAttempt, outcome == .pending)
        }
    }

    func testEvaluationClampsScoreAndConfidenceAndPreservesPolicyIdentity() {
        let evaluation = PracticeEvaluation(outcome: .partial, score: 1.5, confidence: -0.25, policyVersion: "practice-evidence-v1")
        let attempt = Attempt(exerciseID: UUID(), reviewUnitID: UUID(), response: "x", submittedAt: Date(timeIntervalSince1970: 1_000), evaluatorResult: evaluation)

        XCTAssertEqual(attempt.evaluatorResult?.outcome, .partial)
        XCTAssertEqual(attempt.evaluatorResult?.score, 1)
        XCTAssertEqual(attempt.confidence, 0)
        XCTAssertEqual(attempt.evaluatorResult?.policyVersion, "practice-evidence-v1")
        XCTAssertTrue(attempt.evaluatorResult?.isGradable == true)
    }

    func testPracticeEventsIncludeAssistanceAndSkip() {
        let date = Date(timeIntervalSince1970: 1_000)
        let events = PracticeEventKind.allCases.enumerated().map { index, kind in
            PracticeEvent(id: UUID(), kind: kind, at: date.addingTimeInterval(TimeInterval(index)))
        }
        let attempt = Attempt(exerciseID: UUID(), reviewUnitID: UUID(), response: "x", submittedAt: date, events: events)

        XCTAssertEqual(attempt.events.map(\.kind), PracticeEventKind.allCases)
        XCTAssertEqual(attempt.events.last?.kind, .skip)
    }

    func testIdempotencyKeyUsesValueSemantics() {
        let first = IdempotencyKey(rawValue: "exercise-20:generation-1")
        let same = IdempotencyKey(rawValue: "exercise-20:generation-1")
        let different = IdempotencyKey(rawValue: "exercise-20:generation-2")

        XCTAssertEqual(first, same)
        XCTAssertNotEqual(first, different)
        XCTAssertEqual(Set([first, same, different]).count, 2)
    }

    func testUnknownMasteryIsDistinctFromObservedZeroScore() {
        let unknown = PracticeMasteryProjection(state: .unknown)
        let observedZero = PracticeMasteryProjection(state: .new, score: 0)

        XCTAssertFalse(unknown.hasObservedEvidence)
        XCTAssertTrue(observedZero.hasObservedEvidence)
        XCTAssertEqual(unknown.score, nil)
        XCTAssertEqual(observedZero.score, 0)
    }

    func testPracticeStateTransitionsAcceptOnlyLegalActions() {
        XCTAssertEqual(PracticeState.answering.transition(for: .prepare), .answering)
        XCTAssertEqual(PracticeState.answering.transition(for: .requestHint), .answering)
        XCTAssertEqual(PracticeState.answering.transition(for: .submit), .evaluating)
        XCTAssertEqual(PracticeState.evaluating.transition(for: .evaluationCompleted), .feedback)
        XCTAssertEqual(PracticeState.evaluating.transition(for: .unavailable), .unavailable)
        XCTAssertEqual(PracticeState.feedback.transition(for: .retry), .answering)
        XCTAssertEqual(PracticeState.revealed.transition(for: .continue), .finished)
        XCTAssertEqual(PracticeState.finished.transition(for: .continue), .finished)
        XCTAssertEqual(PracticeState.answering.transition(for: .skip), .finished)

        XCTAssertFalse(PracticeState.answering.canApply(.evaluationCompleted))
        XCTAssertFalse(PracticeState.finished.canApply(.submit))
        XCTAssertFalse(PracticeState.feedback.canApply(.evaluationCompleted))
    }
}
