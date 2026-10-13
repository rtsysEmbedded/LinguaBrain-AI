import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

public protocol WritingEvaluationTransport: Sendable {
    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionWritingEvaluationTransport: WritingEvaluationTransport {
    public init() {}

    public func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        return (data, http)
    }
}

public struct WritingEvaluationProvider: PracticeEvaluator, Sendable {
    public static let evaluatorVersion = "writing-evaluator-v1"
    public static let schemaName = "writing_evaluation"

    private let configuration: ProviderConfiguration
    private let credentialLoader: any CredentialLoader
    private let transport: any WritingEvaluationTransport
    private let decoder: PracticeEvaluationDecoder
    private let options: PracticeChatOptions
    private let contextResolver: (any WritingExerciseContextResolving)?

    /// - Parameters:
    ///   - options: System instructions (from the app's prompt configuration)
    ///     and sampling options.
    ///   - contextResolver: Supplies the target word, part of speech, level,
    ///     and allowed context of the exercise. Without it, only the exercise
    ///     prompt is sent as the target word.
    public init(
        configuration: ProviderConfiguration,
        credentialLoader: any CredentialLoader,
        transport: any WritingEvaluationTransport = URLSessionWritingEvaluationTransport(),
        decoder: PracticeEvaluationDecoder = PracticeEvaluationDecoder(),
        options: PracticeChatOptions = PracticeChatOptions(instructions: ""),
        contextResolver: (any WritingExerciseContextResolving)? = nil
    ) {
        self.configuration = configuration
        self.credentialLoader = credentialLoader
        self.transport = transport
        self.decoder = decoder
        self.options = options
        self.contextResolver = contextResolver
    }

    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard configuration.mode != .off else { throw PracticeEvaluationError.providerUnavailable }
        let context = try await contextResolver?.context(for: exercise)
            ?? WritingExerciseContext(targetWord: exercise.prompt, partOfSpeech: "", cefrLevel: "", allowedContext: "")
        let request = WritingEvaluationRequest(
            learnerID: exercise.reviewUnit.learnerID,
            sourceLanguage: exercise.sourceLanguage,
            targetLanguage: exercise.targetLanguage,
            cefrLevel: context.cefrLevel,
            targetWord: context.targetWord,
            partOfSpeech: context.partOfSpeech,
            sentenceRevision: exercise.reviewUnit.sentenceRevision ?? 1,
            allowedContext: context.allowedContext,
            learnerSentence: attempt.response
        )
        let client = PracticeChatClient(configuration: configuration, credentialLoader: credentialLoader, transport: transport, options: options)
        let schema = PracticeEvaluationDecoder.responseSchema(
            sourceLanguage: exercise.sourceLanguage,
            provider: configuration.providerName,
            model: configuration.modelID,
            evaluatorVersion: Self.evaluatorVersion
        )
        let content = try await client.send(userContent: try PracticeChatClient.encode(request), schemaName: Self.schemaName, schema: schema)
        do {
            return try decoder.decode(data: content, request: request, attemptID: attempt.id, exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id)
        } catch PracticeEvaluationDecoderError.lowConfidence {
            throw PracticeEvaluationError.lowConfidence
        } catch PracticeEvaluationDecoderError.unsupportedLanguage {
            throw PracticeEvaluationError.unsupported
        } catch {
            throw PracticeEvaluationError.malformedOutput
        }
    }
}
