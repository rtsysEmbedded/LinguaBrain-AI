import XCTest
import LinguaBrainApplication
import LinguaBrainDomain
@testable import LinguaBrainAI

final class ListeningEvaluationTests: XCTestCase {
    private struct Transport: ListeningEvaluationTransport {
        let result: Result<EvaluationResult, Error>
        func evaluate(_ request: ListeningEvaluationRequest) async throws -> EvaluationResult { try result.get() }
    }
    private struct Resolver: ListeningEvaluationContextResolving {
        let value: ListeningEvaluationContext
        func context(for exercise: ExerciseInstance) async throws -> ListeningEvaluationContext { value }
    }

    func testParaphraseAndPartialMeaningRemainDistinct() async throws {
        let fixture = makeFixture()
        let result = EvaluationResult(outcome: .partial, score: 0.55, confidence: 0.92, evaluatorVersion: "listening-v1", meaningStatus: .partiallyPreserved)
        let provider = ListeningEvaluationProvider(transport: Transport(result: .success(result)), contextResolver: Resolver(value: fixture.context))
        let evaluated = try await provider.evaluate(fixture.attempt, exercise: fixture.exercise)
        XCTAssertEqual(evaluated.outcome, .partial)
        XCTAssertEqual(evaluated.meaningStatus, .partiallyPreserved)
    }

    func testCancellationAndLowConfidenceNeverBecomeIncorrect() async throws {
        let fixture = makeFixture()
        let cancelled = ListeningEvaluationProvider(transport: Transport(result: .failure(CancellationError())), contextResolver: Resolver(value: fixture.context))
        do { _ = try await cancelled.evaluate(fixture.attempt, exercise: fixture.exercise); XCTFail() }
        catch { XCTAssertEqual(error as? PracticeEvaluationError, .cancelled) }

        let low = EvaluationResult(outcome: .incorrect, score: 0, confidence: 0.1, evaluatorVersion: "listening-v1")
        let lowProvider = ListeningEvaluationProvider(transport: Transport(result: .success(low)), contextResolver: Resolver(value: fixture.context))
        let lowResult = try await lowProvider.evaluate(fixture.attempt, exercise: fixture.exercise)
        XCTAssertEqual(lowResult.outcome, .unavailable)
    }

    private func makeFixture() -> (exercise: ExerciseInstance, attempt: Attempt, context: ListeningEvaluationContext) {
        let sentence = Sentence(id: UUID(uuidString: "00000000-0000-0000-0000-000000002701")!, revision: 3, text: "Mara kommt heute nicht.", translation: "مارا امروز نمی‌آید.")
        let unit = ReviewUnit(skill: .listening, objectiveKey: "semantic-negation", sentenceID: sentence.id, sentenceRevision: sentence.revision)
        let exercise = ExerciseInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000002702")!, reviewUnit: unit, prompt: "Listen and explain.", sourceLanguage: "de", targetLanguage: "fa")
        let attempt = Attempt(id: UUID(uuidString: "00000000-0000-0000-0000-000000002703")!, exerciseID: exercise.id, reviewUnitID: unit.id, response: "مارا امروز نمی‌آید", submittedAt: Date(timeIntervalSince1970: 1))
        return (exercise, attempt, ListeningEvaluationContext(sentence: sentence, audioChecksum: "fixture-audio-3"))
    }
}
