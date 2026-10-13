import XCTest
@testable import LinguaBrainApplication
@testable import LinguaBrainDomain

private struct PracticePortsFixture: PracticeExerciseRetrieval, PracticeAttemptPersistence, PracticeHelpEventPersistence, PracticeSentencePlayback, PracticeRecording, PracticePronunciationAssessment, PracticeReviewMasteryScheduling {
    func retrieveExercise(for request: PracticeExerciseRequest) async throws -> ExerciseInstance? { nil }
    func saveAttempt(_ attempt: Attempt) async throws {}
    func attempt(id: UUID) async throws -> Attempt? { nil }
    func attempt(idempotencyKey: IdempotencyKey) async throws -> Attempt? { nil }
    func attempts(for unit: ReviewUnit) async throws -> [Attempt] { [] }
    func saveEvent(_ event: PracticeEvent, for attemptID: UUID) async throws {}
    func events(for attemptID: UUID) async throws -> [PracticeEvent] { [] }
    func sentenceAudio(for sentence: Sentence) async throws -> MediaAsset { throw PracticeEvaluationError.unsupported }
    func record() async throws -> Data { Data() }
    func assessPronunciation(_ audio: Data, sentence: Sentence) async throws -> EvaluationResult { .unavailable(reason: .unsupported) }
    func handoff(_ effect: PracticeLearningHandoff) async throws {}
}

final class PracticePortsTests: XCTestCase {
    func testEvaluationResultRetainsValidatedEvidenceAndProvenance() throws {
        let provenance = Provenance(provider: "fixture-provider", model: "fixture-model", promptVersion: "prompt-1", generatedAt: Date(timeIntervalSince1970: 3_000))
        let attemptID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let result = EvaluationResult(
            outcome: .partial,
            score: 0.5,
            confidence: 0.9,
            feedback: [TypedFeedback(message: "word order", isError: true, confidence: 0.9)],
            rules: [RuleReference(code: "weil-verb")],
            evaluatorVersion: "rubric-1",
            provenance: provenance,
            attemptID: attemptID,
            sentenceRevision: 2
        )
        let validated = try result.validated()

        XCTAssertEqual(validated.outcome, .partial)
        XCTAssertEqual(validated.score, 0.5)
        XCTAssertEqual(validated.confidence, 0.9)
        XCTAssertEqual(validated.feedback.first?.message, "word order")
        XCTAssertEqual(validated.rules.first?.code, "weil-verb")
        XCTAssertEqual(validated.evaluatorVersion, "rubric-1")
        XCTAssertEqual(validated.provenance, provenance)
        XCTAssertEqual(validated.attemptID, attemptID)
        XCTAssertEqual(validated.sentenceRevision, 2)
    }

    func testInvalidOrUncertainProviderResultsNormalizeToUnavailable() {
        let malformed = EvaluationResult(outcome: .correct, score: 1.1, evaluatorVersion: "rubric-1")
        let lowConfidence = EvaluationResult(outcome: .partial, score: 0.5, confidence: 0.49, evaluatorVersion: "rubric-1")
        let pending = EvaluationResult(outcome: .pending, evaluatorVersion: "rubric-1")
        let cancelled = EvaluationResult.unavailable(reason: .cancelled, evaluatorVersion: "rubric-1")

        XCTAssertEqual(malformed.normalized().outcome, .unavailable)
        XCTAssertEqual(malformed.normalized().unavailableReason, .malformedOutput)
        XCTAssertEqual(lowConfidence.normalized().outcome, .unavailable)
        XCTAssertEqual(lowConfidence.normalized().unavailableReason, .lowConfidence)
        XCTAssertEqual(pending.normalized().outcome, .unavailable)
        XCTAssertEqual(pending.normalized().unavailableReason, .malformedOutput)
        XCTAssertEqual(cancelled.normalized().unavailableReason, .cancelled)
    }

    func testProviderPortsAreFrameworkAndProviderIndependent() {
        let fixture = PracticePortsFixture()
        let _: any PracticeExerciseRetrieval = fixture
        let _: any PracticeAttemptPersistence = fixture
        let _: any PracticeHelpEventPersistence = fixture
        let _: any PracticeSentencePlayback = fixture
        let _: any PracticeRecording = fixture
        let _: any PracticePronunciationAssessment = fixture
        let _: any PracticeReviewMasteryScheduling = fixture
        XCTAssertEqual(PracticeEvidencePolicy.version, "practice-evidence-v1")
    }
}
