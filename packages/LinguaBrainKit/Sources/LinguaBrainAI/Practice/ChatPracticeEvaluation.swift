import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

/// Request options for practice evaluation through an OpenAI-compatible
/// `/chat/completions` endpoint. The instruction text is supplied by the app
/// (from its prompt configuration); this module only builds the request and
/// enforces the response contract.
public struct PracticeChatOptions: Sendable, Equatable {
    /// System message, fully rendered.
    public let instructions: String
    /// Sampling temperature; `nil` omits the field for models that reject it.
    public let temperature: Double?

    public init(instructions: String, temperature: Double? = nil) {
        self.instructions = instructions
        self.temperature = temperature
    }
}

extension ProviderConfiguration {
    /// Provider name recorded in evaluation provenance: the endpoint host, or
    /// the protocol name when the endpoint has no host.
    public var providerName: String {
        URL(string: endpoint)?.host ?? protocolName
    }
}

/// Builds and sends one structured-output chat request and returns the
/// message content. Errors are mapped to `PracticeEvaluationError`; response
/// bodies are never logged.
struct PracticeChatClient: Sendable {
    let configuration: ProviderConfiguration
    let credentialLoader: any CredentialLoader
    let transport: any WritingEvaluationTransport
    let options: PracticeChatOptions

    func send(userContent: String, schemaName: String, schema: [String: Any]) async throws -> Data {
        guard configuration.mode != .off else { throw PracticeEvaluationError.providerUnavailable }
        let endpoint = configuration.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(endpoint)/chat/completions") else { throw PracticeEvaluationError.transportFailure }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = try credentialLoader.loadCredential(for: configuration.apiKeyScope), !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        var body: [String: Any] = [
            "model": configuration.modelID,
            "messages": [
                ["role": "system", "content": options.instructions],
                ["role": "user", "content": userContent]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": schemaName, "strict": true, "schema": schema]
            ]
        ]
        if let temperature = options.temperature { body["temperature"] = temperature }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await transport.send(request: request)
            guard (200..<300).contains(response.statusCode) else { throw PracticeEvaluationError.providerUnavailable }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else { throw PracticeEvaluationError.malformedOutput }
            return Data(content.utf8)
        } catch is CancellationError {
            throw PracticeEvaluationError.cancelled
        } catch let error as PracticeEvaluationError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw PracticeEvaluationError.cancelled
        } catch is DecodingError {
            throw PracticeEvaluationError.malformedOutput
        } catch {
            throw PracticeEvaluationError.transportFailure
        }
    }

    static func encode<Value: Encodable>(_ value: Value) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func nullable(_ type: String) -> [String: Any] { ["type": [type, "null"]] }

    static func object(_ properties: [String: Any]) -> [String: Any] {
        ["type": "object", "additionalProperties": false, "required": properties.keys.sorted(), "properties": properties]
    }
}

// MARK: - Writing

/// What a writing exercise asks for, resolved from the exercise's card.
public struct WritingExerciseContext: Sendable, Equatable {
    public let targetWord: String
    public let partOfSpeech: String
    public let cefrLevel: String
    /// Support-language meaning given as context.
    public let allowedContext: String

    public init(targetWord: String, partOfSpeech: String, cefrLevel: String, allowedContext: String) {
        self.targetWord = targetWord; self.partOfSpeech = partOfSpeech
        self.cefrLevel = cefrLevel; self.allowedContext = allowedContext
    }
}

public protocol WritingExerciseContextResolving: Sendable {
    func context(for exercise: ExerciseInstance) async throws -> WritingExerciseContext?
}

/// Resolves the writing context from the card named in the review unit's
/// objective key (`CardBackedWritingRetrieval.objectiveKey(cardID:)`).
public struct CardWritingContextResolver: WritingExerciseContextResolving {
    private let cards: any PracticeCardSource

    public init(cards: any PracticeCardSource) {
        self.cards = cards
    }

    public func context(for exercise: ExerciseInstance) async throws -> WritingExerciseContext? {
        let candidates = try await cards.practiceCards(sourceLanguage: exercise.sourceLanguage, targetLanguage: exercise.targetLanguage)
        guard let card = candidates.first(where: { CardBackedWritingRetrieval.objectiveKey(cardID: $0.cardID) == exercise.reviewUnit.objectiveKey }) else {
            return nil
        }
        return WritingExerciseContext(targetWord: card.targetText, partOfSpeech: card.partOfSpeech, cefrLevel: card.cefrLevel, allowedContext: card.sourceMeaning)
    }
}

extension PracticeEvaluationDecoder {
    /// JSON Schema for `writing-evaluation-v1` structured output. Contract
    /// constants (versions, rule IDs, provider, model) are fixed by `enum`,
    /// so the model cannot return values the decoder would reject.
    public static func responseSchema(sourceLanguage: String, provider: String, model: String, evaluatorVersion: String) -> [String: Any] {
        let ruleIDs = ruleIDs.sorted()
        let feedback = PracticeChatClient.object([
            "type": ["type": "string"],
            "message": ["type": "string"],
            "severity": ["type": "string", "enum": ["info", "warning", "error"]]
        ])
        let rule = PracticeChatClient.object([
            "id": ["type": "string", "enum": ruleIDs],
            "category": ["type": "string", "enum": ["grammar", "vocabulary", "meaning", "style"]]
        ])
        let span = PracticeChatClient.object([
            "start": ["type": "integer"],
            "end": ["type": "integer"],
            "text": ["type": "string"],
            "category": ["type": "string"],
            "ruleID": ["type": "string", "enum": ruleIDs]
        ])
        let output = PracticeChatClient.object([
            "outcome": ["type": "string", "enum": ["correct", "partial", "incorrect", "unavailable"]],
            "meaningAssessment": PracticeChatClient.object([
                "status": ["type": "string", "enum": ["preserved", "partiallyPreserved", "changed", "uncertain"]],
                "confidence": PracticeChatClient.nullable("number")
            ]),
            "originalLearnerSentence": ["type": "string"],
            "minimalCorrection": PracticeChatClient.nullable("string"),
            "naturalVariant": PracticeChatClient.nullable("string"),
            "explanation": PracticeChatClient.object([
                "language": ["type": "string", "enum": [sourceLanguage]],
                "text": ["type": "string"]
            ]),
            "feedback": ["type": "array", "maxItems": 8, "items": feedback],
            "ruleReferences": ["type": "array", "maxItems": 8, "items": rule],
            "affectedSpans": ["type": "array", "maxItems": 8, "items": span],
            "score": PracticeChatClient.nullable("number"),
            "confidence": PracticeChatClient.nullable("number"),
            "unavailableReason": ["type": ["string", "null"], "enum": ["unsupportedLanguage", "lowConfidence", "providerUnavailable", "cancelled", "uncertainIntent", "malformedOutput", NSNull()]],
            "provenance": PracticeChatClient.object([
                "provider": ["type": "string", "enum": [provider]],
                "model": ["type": "string", "enum": [model]],
                "evaluatorVersion": ["type": "string", "enum": [evaluatorVersion]],
                "schemaVersion": ["type": "string", "enum": [schemaVersion]],
                "promptVersion": ["type": "string", "enum": [rubricVersion]],
                "validatorVersion": ["type": "string", "enum": [validatorVersion]]
            ]),
            "approvalPolicy": ["type": "string", "enum": ["humanReviewRequired", "autoApproveAllowed"]],
            "canonicalContentAction": ["type": "string", "enum": ["none"]],
            "masterySchedulingMutation": ["type": "boolean", "enum": [false]]
        ])
        return PracticeChatClient.object([
            "schemaVersion": ["type": "string", "enum": [schemaVersion]],
            "output": output
        ])
    }
}

// MARK: - Grammar

/// What a grammar answer is compared with.
public struct GrammarEvaluationContext: Sendable, Equatable {
    public let rule: GrammarRule
    public let referenceAnswer: String?
    public let referenceExplanation: String?

    public init(rule: GrammarRule, referenceAnswer: String? = nil, referenceExplanation: String? = nil) {
        self.rule = rule; self.referenceAnswer = referenceAnswer; self.referenceExplanation = referenceExplanation
    }
}

public protocol GrammarEvaluationContextResolving: Sendable {
    func context(for exercise: ExerciseInstance) async throws -> GrammarEvaluationContext?
}

/// Grammar evaluation through an OpenAI-compatible endpoint with a
/// structured-output schema that fixes the rule code.
public struct ChatGrammarEvaluationTransport: GrammarEvaluationTransport {
    public static let schemaName = "grammar_evaluation"
    private let client: PracticeChatClient

    public init(configuration: ProviderConfiguration, credentialLoader: any CredentialLoader, options: PracticeChatOptions, transport: any WritingEvaluationTransport = URLSessionWritingEvaluationTransport()) {
        client = PracticeChatClient(configuration: configuration, credentialLoader: credentialLoader, transport: transport, options: options)
    }

    private struct UserContent: Encodable {
        let prompt: String
        let learnerExplanation: String
        let ruleCode: String
        let ruleCategory: String
        let grammaticalRole: String
        let targetLanguage: String
        let referenceAnswer: String?
        let referenceExplanation: String?
    }

    private struct Response: Decodable {
        let outcome: String
        let score: Double
        let confidence: Double
        let explanationFeedback: String
        let applicationFeedback: String
        let ruleCode: String
    }

    public func evaluate(_ request: GrammarEvaluationRequest) async throws -> GrammarEvaluationProposal {
        let content = try PracticeChatClient.encode(UserContent(
            prompt: request.prompt, learnerExplanation: request.explanation,
            ruleCode: request.rule.code, ruleCategory: request.rule.category, grammaticalRole: request.rule.grammaticalRole,
            targetLanguage: request.rule.targetLanguage,
            referenceAnswer: request.referenceAnswer, referenceExplanation: request.referenceExplanation
        ))
        let schema = PracticeChatClient.object([
            "outcome": ["type": "string", "enum": ["correct", "partial", "incorrect"]],
            "score": ["type": "number"],
            "confidence": ["type": "number"],
            "explanationFeedback": ["type": "string"],
            "applicationFeedback": ["type": "string"],
            "ruleCode": ["type": "string", "enum": [request.rule.code]]
        ])
        let data = try await client.send(userContent: content, schemaName: Self.schemaName, schema: schema)
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let outcome = AttemptOutcome(rawValue: response.outcome) else { throw PracticeEvaluationError.malformedOutput }
        return GrammarEvaluationProposal(
            outcome: outcome, score: response.score, confidence: response.confidence,
            explanationFeedback: response.explanationFeedback, applicationFeedback: response.applicationFeedback,
            rule: RuleReference(code: response.ruleCode),
            provider: client.configuration.providerName, model: client.configuration.modelID
        )
    }
}

// MARK: - Listening

/// Semantic slots of `listening-evidence-v1`, scored independently.
public enum ListeningSemanticSlot: String, CaseIterable, Sendable {
    case agent, patient, action, negation, number, tense, modality

    /// Slots whose change makes the answer incorrect (contract: reversing
    /// negation, replacing the agent or action, changing number or time).
    public var isCritical: Bool {
        switch self {
        case .agent, .action, .negation, .number, .tense: true
        case .patient, .modality: false
        }
    }
}

public enum ListeningSlotStatus: String, CaseIterable, Sendable {
    case preserved, missing, changed
}

/// Listening evaluation through an OpenAI-compatible endpoint: the learner's
/// response is compared with the exact sentence revision and its reviewed
/// translation, slot by slot. The outcome is derived from the slot results
/// as the contract defines, not taken from the model.
public struct ChatListeningEvaluationTransport: ListeningEvaluationTransport {
    public static let schemaName = "listening_evaluation"
    public static let evaluatorVersion = "listening-evaluator-v1"
    public static let contractVersion = "listening-evidence-v1"
    public static let slotRulePrefix = "listening.slot."
    private let client: PracticeChatClient

    public init(configuration: ProviderConfiguration, credentialLoader: any CredentialLoader, options: PracticeChatOptions, transport: any WritingEvaluationTransport = URLSessionWritingEvaluationTransport()) {
        client = PracticeChatClient(configuration: configuration, credentialLoader: credentialLoader, transport: transport, options: options)
    }

    private struct UserContent: Encodable {
        let sentence: String
        let reviewedTranslation: String
        let learnerResponse: String
    }

    private struct SlotResult: Decodable {
        let slot: String
        let status: String
    }

    private struct Response: Decodable {
        let meaningStatus: String
        let slots: [SlotResult]
        let score: Double
        let confidence: Double
        let feedback: [String]
    }

    /// Contract outcome for a set of slot results.
    public static func outcome(for slots: [ListeningSemanticSlot: ListeningSlotStatus]) -> AttemptOutcome {
        if slots.contains(where: { $0.key.isCritical && $0.value == .changed }) { return .incorrect }
        if slots.contains(where: { $0.value != .preserved }) { return .partial }
        return .correct
    }

    public func evaluate(_ request: ListeningEvaluationRequest) async throws -> EvaluationResult {
        let content = try PracticeChatClient.encode(UserContent(sentence: request.sentence.text, reviewedTranslation: request.sentence.translation, learnerResponse: request.response))
        let slot = PracticeChatClient.object([
            "slot": ["type": "string", "enum": ListeningSemanticSlot.allCases.map(\.rawValue)],
            "status": ["type": "string", "enum": ListeningSlotStatus.allCases.map(\.rawValue)]
        ])
        let schema = PracticeChatClient.object([
            "meaningStatus": ["type": "string", "enum": ["preserved", "partiallyPreserved", "changed", "uncertain"]],
            "slots": ["type": "array", "maxItems": ListeningSemanticSlot.allCases.count, "items": slot],
            "score": ["type": "number"],
            "confidence": ["type": "number"],
            "feedback": ["type": "array", "maxItems": 3, "items": ["type": "string"]]
        ])
        let data = try await client.send(userContent: content, schemaName: Self.schemaName, schema: schema)
        guard let response = try? JSONDecoder().decode(Response.self, from: data),
              let meaning = PracticeMeaningStatus(rawValue: response.meaningStatus) else { throw PracticeEvaluationError.malformedOutput }
        var slots: [ListeningSemanticSlot: ListeningSlotStatus] = [:]
        for entry in response.slots {
            guard let slot = ListeningSemanticSlot(rawValue: entry.slot), let status = ListeningSlotStatus(rawValue: entry.status),
                  slots.updateValue(status, forKey: slot) == nil else { throw PracticeEvaluationError.malformedOutput }
        }
        let provenance = Provenance(provider: client.configuration.providerName, model: client.configuration.modelID, promptVersion: Self.contractVersion, schemaVersion: Self.contractVersion, validatorVersion: Self.evaluatorVersion)
        guard meaning != .uncertain else {
            return .unavailable(reason: .lowConfidence, evaluatorVersion: Self.evaluatorVersion, provenance: provenance, sentenceRevision: request.sentence.revision)
        }
        let outcome = Self.outcome(for: slots)
        let affected = slots.filter { $0.value != .preserved }.sorted { $0.key.rawValue < $1.key.rawValue }
        return EvaluationResult(
            outcome: outcome,
            score: response.score,
            confidence: response.confidence,
            feedback: response.feedback.prefix(3).map { TypedFeedback(message: $0, isError: outcome != .correct, confidence: response.confidence) },
            rules: affected.map { RuleReference(code: Self.slotRulePrefix + $0.key.rawValue, span: $0.value.rawValue) },
            evaluatorVersion: Self.evaluatorVersion,
            provenance: provenance,
            sentenceRevision: request.sentence.revision,
            meaningStatus: meaning
        )
    }
}

/// Resolves the sentence revision a listening exercise played from the
/// practice repository, with the audio checksum the playback adapter uses.
public struct RepositoryListeningContextResolver: ListeningEvaluationContextResolving {
    private let repository: any PracticeRepository
    private let audioChecksum: @Sendable (Sentence) -> String

    public init(repository: any PracticeRepository, audioChecksum: @escaping @Sendable (Sentence) -> String) {
        self.repository = repository
        self.audioChecksum = audioChecksum
    }

    public func context(for exercise: ExerciseInstance) async throws -> ListeningEvaluationContext {
        guard let id = exercise.reviewUnit.sentenceID, let revision = exercise.reviewUnit.sentenceRevision,
              let sentence = try await repository.sentence(id: id, revision: revision) else {
            throw PracticeEvaluationError.malformedOutput
        }
        return ListeningEvaluationContext(sentence: sentence, audioChecksum: audioChecksum(sentence))
    }
}
