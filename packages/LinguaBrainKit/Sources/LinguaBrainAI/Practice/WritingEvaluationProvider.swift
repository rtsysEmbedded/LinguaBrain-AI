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
    private let configuration: ProviderConfiguration
    private let credentialLoader: any CredentialLoader
    private let transport: any WritingEvaluationTransport
    private let decoder: PracticeEvaluationDecoder

    public init(configuration: ProviderConfiguration, credentialLoader: any CredentialLoader, transport: any WritingEvaluationTransport = URLSessionWritingEvaluationTransport(), decoder: PracticeEvaluationDecoder = PracticeEvaluationDecoder()) {
        self.configuration = configuration
        self.credentialLoader = credentialLoader
        self.transport = transport
        self.decoder = decoder
    }

    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard configuration.mode != .off else { throw PracticeEvaluationError.providerUnavailable }
        let request = WritingEvaluationRequest(
            learnerID: exercise.reviewUnit.learnerID,
            sourceLanguage: exercise.sourceLanguage,
            targetLanguage: exercise.targetLanguage,
            cefrLevel: "A1",
            targetWord: exercise.prompt,
            partOfSpeech: "other",
            sentenceRevision: exercise.reviewUnit.sentenceRevision ?? 1,
            allowedContext: exercise.prompt,
            learnerSentence: attempt.response
        )
        let endpoint = configuration.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(endpoint)/chat/completions") else { throw PracticeEvaluationError.transportFailure }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutSeconds
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = try credentialLoader.loadCredential(for: configuration.apiKeyScope) {
            urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": configuration.modelID,
            "temperature": 0,
            "messages": [["role": "user", "content": "Evaluate this writing response under writing-evaluation-v1. Return JSON only.\nPrompt: \(exercise.prompt)\nResponse: \(attempt.response)"]]
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await transport.send(request: urlRequest)
            guard (200..<300).contains(response.statusCode) else { throw PracticeEvaluationError.providerUnavailable }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  let contentData = content.data(using: .utf8) else { throw PracticeEvaluationError.malformedOutput }
            do {
                return try decoder.decode(data: contentData, request: request, attemptID: attempt.id, exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id)
            } catch PracticeEvaluationDecoderError.lowConfidence { throw PracticeEvaluationError.lowConfidence }
            catch PracticeEvaluationDecoderError.unsupportedLanguage { throw PracticeEvaluationError.unsupported }
            catch { throw PracticeEvaluationError.malformedOutput }
        } catch is CancellationError {
            throw PracticeEvaluationError.cancelled
        } catch let error as PracticeEvaluationError {
            throw error
        } catch {
            throw PracticeEvaluationError.transportFailure
        }
    }
}
