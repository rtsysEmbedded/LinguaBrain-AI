import XCTest
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainMedia
@testable import LinguaBrainAI

final class ListeningAndSentenceAudioTests: XCTestCase {
    actor Cache: SentenceAudioCache {
        var values: [SentenceAudioKey: MediaAsset] = [:]
        func audio(for key: SentenceAudioKey) -> MediaAsset? { values[key] }
        func save(_ asset: MediaAsset, for key: SentenceAudioKey) { values[key] = asset }
    }
    actor Generator: SentenceAudioGenerator {
        var count = 0
        func generate(sentence: Sentence, language: String, voice: String, model: String, rate: Double) -> MediaAsset { count += 1; return MediaAsset(kind: .audio, locale: language, checksum: "\(sentence.revision)-\(sentence.text)", provider: "fake", model: model, generatedAt: Date(timeIntervalSince1970: 0)) }
        func calls() -> Int { count }
    }
    struct ListeningTransport: ListeningEvaluationTransport { let result: EvaluationResult; func evaluate(_ request: ListeningEvaluationRequest) async throws -> EvaluationResult { result } }
    struct ContextResolver: ListeningEvaluationContextResolving {
        let context: ListeningEvaluationContext
        func context(for exercise: ExerciseInstance) async throws -> ListeningEvaluationContext { context }
    }

    func testCacheIsRevisionAndTextSensitiveAndNeverFallsBackToWordAudio() async throws {
        let cache = Cache(), generator = Generator(), service = SentenceAudioService(cache: cache, generator: generator)
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000002401")!
        let first = Sentence(id: id, revision: 1, text: "Er kommt nicht.", translation: "او نمی‌آید.")
        _ = try await service.play(sentence: first, language: "de-DE", voice: "system", model: "local")
        _ = try await service.play(sentence: first, language: "de-DE", voice: "system", model: "local")
        _ = try await service.play(sentence: Sentence(id: id, revision: 2, text: "Er kam nicht.", translation: "او نیامد."), language: "de-DE", voice: "system", model: "local", rate: 0.75)
        let callCount = await generator.calls()
        XCTAssertEqual(callCount, 2)
        do { _ = try await service.play(sentence: nil, language: "de-DE", voice: "system", model: "local"); XCTFail() } catch { XCTAssertEqual(error as? SentenceAudioError, .missingSentence) }
    }
    func testListeningPreservesPartialAndNormalizesLowConfidence() async throws {
        let sentence = Sentence(id: UUID(uuidString: "00000000-0000-0000-0000-000000002402")!, revision: 1, text: "Er kommt nicht.", translation: "او نمی‌آید.")
        let exercise = ExerciseInstance(reviewUnit: ReviewUnit(skill: .listening, objectiveKey: "negation", sentenceID: sentence.id, sentenceRevision: sentence.revision), prompt: "Listen and explain the meaning.", sourceLanguage: "de", targetLanguage: "fa")
        let attempt = Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: "او نمی‌آید", submittedAt: Date(timeIntervalSince1970: 0))
        let resolver = ContextResolver(context: ListeningEvaluationContext(sentence: sentence, audioChecksum: "audio-1"))
        let partial = EvaluationResult(outcome: .partial, score: 0.6, confidence: 0.9, evaluatorVersion: "listening-v1", meaningStatus: .partiallyPreserved)
        let partialResult = try await ListeningEvaluationProvider(transport: ListeningTransport(result: partial), contextResolver: resolver).evaluate(attempt, exercise: exercise)
        XCTAssertEqual(partialResult.outcome, .partial)
        let low = EvaluationResult(outcome: .incorrect, score: 0, confidence: 0.1, evaluatorVersion: "listening-v1")
        let lowResult = try await ListeningEvaluationProvider(transport: ListeningTransport(result: low), contextResolver: resolver).evaluate(attempt, exercise: exercise)
        XCTAssertEqual(lowResult.outcome, .unavailable)
    }

    func testListeningRejectsSentenceRevisionOrAudioMismatch() async {
        let sentence = Sentence(id: UUID(uuidString: "00000000-0000-0000-0000-000000002403")!, revision: 2, text: "Sie kommt heute.", translation: "او امروز می‌آید.")
        let exercise = ExerciseInstance(reviewUnit: ReviewUnit(skill: .listening, objectiveKey: "time", sentenceID: sentence.id, sentenceRevision: 1), prompt: "Listen", sourceLanguage: "de", targetLanguage: "fa")
        let attempt = Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: "او امروز می‌آید", submittedAt: Date(timeIntervalSince1970: 0))
        let result = EvaluationResult(outcome: .correct, score: 1, confidence: 1, evaluatorVersion: "listening-v1")
        let provider = ListeningEvaluationProvider(transport: ListeningTransport(result: result), contextResolver: ContextResolver(context: ListeningEvaluationContext(sentence: sentence, audioChecksum: "")))
        do { _ = try await provider.evaluate(attempt, exercise: exercise); XCTFail("Mismatch must be rejected") }
        catch { XCTAssertEqual(error as? PracticeEvaluationError, .malformedOutput) }
    }
}
