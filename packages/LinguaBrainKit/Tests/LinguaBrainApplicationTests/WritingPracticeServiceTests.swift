import XCTest
@testable import LinguaBrainApplication
@testable import LinguaBrainDomain
@testable import LinguaBrainTestSupport

final class WritingPracticeServiceTests: XCTestCase {
    func testPrepareUsesDescriptorAndSubmitPreservesResponseBeforeEvaluation() async throws {
        let unit = ReviewUnit(learnerID: "learner", skill: .writing, objectiveKey: "write:gehen", sentenceID: UUID(), sentenceRevision: 1)
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "gehen", sourceLanguage: "fa", targetLanguage: "de")
        let descriptor = WritingExerciseDescriptor(exercise: exercise, targetWord: "gehen", partOfSpeech: "verb", cefrLevel: "A1", allowedContext: "Going home")
        let repository = DeterministicPracticeRepository()
        let evaluator = ScriptedPracticeEvaluator(steps: [.result(EvaluationResult(outcome: .partial, score: 0.5, confidence: 0.9, evaluatorVersion: "fixture"))])
        let session = PracticeSessionService(repository: repository, evaluator: evaluator, clock: FixedPracticeClock(date: Date(timeIntervalSince1970: 1_700_000_000)))
        let service = WritingPracticeService(retrieval: FixedWritingRetrieval(descriptor: descriptor), session: session)
        let prepared = try await service.prepare(learnerID: "learner", cefrLevel: "A1", seed: 7)
        XCTAssertEqual(prepared, descriptor)
        let submission = try await service.submit(exerciseID: exercise.id, response: "Ich gestern nach Hause.")
        XCTAssertEqual(submission.attempt.response, "Ich gestern nach Hause.")
        XCTAssertEqual(submission.correctionProposal?.outcome, .partial)
        let saved = try await repository.attempt(id: submission.attempt.id)
        XCTAssertEqual(saved?.response, submission.attempt.response)
    }
}

private struct FixedWritingRetrieval: WritingExerciseRetrieval {
    let descriptor: WritingExerciseDescriptor
    func nextWritingExercise(learnerID: String, cefrLevel: String, seed: Int) async throws -> WritingExerciseDescriptor? { descriptor }
}
