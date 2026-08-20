import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

// MARK: - Versioned Contracts (T002, T007)

public struct ContractVersion: Equatable, Sendable {
    public static let generationV1 = ContractVersion("generation", 1)
    public static let exportV1 = ContractVersion("export", 1)

    public let name: String
    public let number: Int

    public init(_ name: String, _ number: Int) {
        self.name = name
        self.number = number
    }

    public var identifier: String { "\(name)-v\(number)" }
}

public enum ContractError: Error, Equatable, Sendable {
    case unsupportedVersion(String)
    case malformedProposal(String)
}

// MARK: - Proposal Decoding (T007, FR-002)

public struct ProposalJSONWireModel: Codable, Sendable {
    public var version: String
    public var lemma: String
    public var senses: [SenseWireModel]
    public var provenance: ProvenanceWireModel

    public init(version: String, lemma: String, senses: [SenseWireModel], provenance: ProvenanceWireModel) {
        self.version = version
        self.lemma = lemma
        self.senses = senses
        self.provenance = provenance
    }
}

public struct SenseWireModel: Codable, Sendable {
    public var senseKey: String
    public var partOfSpeech: String
    public var meaning: String
    public var translation: String
    public var level: String?
    public var qualifier: String?
    public var examples: [SentenceWireModel]

    public init(
        senseKey: String, partOfSpeech: String, meaning: String, translation: String,
        level: String? = nil, qualifier: String? = nil, examples: [SentenceWireModel] = []
    ) {
        self.senseKey = senseKey
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.translation = translation
        self.level = level
        self.qualifier = qualifier
        self.examples = examples
    }
}

public struct SentenceWireModel: Codable, Sendable {
    public var text: String
    public var translation: String

    public init(text: String, translation: String) {
        self.text = text
        self.translation = translation
    }
}

public struct ProvenanceWireModel: Codable, Sendable {
    public var provider: String
    public var model: String
    public var schemaVersion: String?
    public var validatorVersion: String?

    public init(provider: String, model: String, schemaVersion: String? = nil, validatorVersion: String? = nil) {
        self.provider = provider
        self.model = model
        self.schemaVersion = schemaVersion
        self.validatorVersion = validatorVersion
    }
}

public struct ProposalDecoder {
    public init() {}

    /// Decodes a versioned proposal and rejects unsupported versions (T007).
    public func decode(from data: Data) throws -> CardProposal {
        let wire = try JSONDecoder().decode(ProposalJSONWireModel.self, from: data)
        let fallback = ContractVersion.generationV1
        guard wire.version == fallback.identifier else {
            throw ContractError.unsupportedVersion(wire.version)
        }

        let senses = wire.senses.map { s in
            LexicalSense(
                sourceLanguage: "",
                targetLanguage: "",
                lemma: wire.lemma,
                senseKey: s.senseKey,
                partOfSpeech: s.partOfSpeech,
                meaning: s.meaning,
                examples: s.examples.map { Sentence(text: $0.text, translation: $0.translation) },
                translation: s.translation,
                level: s.level,
                qualifier: s.qualifier
            )
        }

        return CardProposal(
            lemma: wire.lemma,
            senses: senses,
            provenance: Provenance(
                provider: wire.provenance.provider,
                model: wire.provenance.model,
                schemaVersion: wire.provenance.schemaVersion,
                validatorVersion: wire.provenance.validatorVersion
            )
        )
    }
}

// MARK: - Schema Validation (T007, T010, FR-003)

/// Applies structural and safety validation outside the model boundary (FR-003).
public struct StrictProposalValidator: ProposalValidator {
    public init() {}

    public func validate(_ proposal: CardProposal) throws -> [String] {
        var issues: [String] = []

        // Safety check: reject script/HTML injection in text fields.
        if unsafe(proposal.lemma) {
            issues.append("lemma contains unsafe text")
        }
        if proposal.senses.isEmpty {
            issues.append("proposal has no senses")
        }
        for sense in proposal.senses {
            if sense.senseKey.isEmpty {
                issues.append("sense lacks sense_key")
            }
            if sense.partOfSpeech.isEmpty {
                issues.append("sense \(sense.senseKey) lacks part_of_speech")
            }
            if sense.translation.isEmpty {
                issues.append("sense \(sense.senseKey) lacks translation")
            }
            if unsafe(sense.meaning) {
                issues.append("sense \(sense.senseKey) contains unsafe text")
            }
            for example in sense.examples {
                if example.text.isEmpty || example.translation.isEmpty {
                    issues.append("sense \(sense.senseKey) has incomplete example")
                }
            }
        }
        return issues
    }

    public func isValid(_ proposal: CardProposal) -> Bool {
        (try? validate(proposal).isEmpty) ?? false
    }

    private func unsafe(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains("<script")
            || text.localizedCaseInsensitiveContains("javascript:")
            || text.contains("&lt;")
    }
}

// MARK: - Provider Capabilities (T030, FR-010)

public struct ProviderCapabilities: Sendable, Equatable {
    public var supportsTextGeneration: Bool
    public var supportsAudioGeneration: Bool
    public var supportsImageGeneration: Bool
    public var maxTokens: Int
    public var supportedProtocols: [String]

    public init(
        supportsTextGeneration: Bool = true,
        supportsAudioGeneration: Bool = false,
        supportsImageGeneration: Bool = false,
        maxTokens: Int = 4096,
        supportedProtocols: [String] = ["openai-compatible"]
    ) {
        self.supportsTextGeneration = supportsTextGeneration
        self.supportsAudioGeneration = supportsAudioGeneration
        self.supportsImageGeneration = supportsImageGeneration
        self.maxTokens = maxTokens
        self.supportedProtocols = supportedProtocols
    }
}

public protocol ProviderInspector: Sendable {
    var currentConfiguration: ProviderConfiguration { get }
    var capabilities: ProviderCapabilities { get }
    func healthStatus() async -> ProviderHealthStatus
    func isAvailable() async -> Bool
}

// MARK: - OpenAI-Compatible Provider Adapter (T030, FR-010)

public final class OpenAICompatibleProviderAdapter: TextProviderPort, ProviderHealthCheck, @unchecked Sendable {
    private let configuration: ProviderConfiguration
    private let credentialLoader: CredentialLoader
    private let validator: ProposalValidator
    private let decoder: ProposalDecoder

    public init(
        configuration: ProviderConfiguration,
        credentialLoader: CredentialLoader,
        validator: ProposalValidator = StrictProposalValidator(),
        decoder: ProposalDecoder = ProposalDecoder()
    ) {
        self.configuration = configuration
        self.credentialLoader = credentialLoader
        self.validator = validator
        self.decoder = decoder
    }

    public var currentConfiguration: ProviderConfiguration { configuration }

    public var capabilities: ProviderCapabilities {
        ProviderCapabilities(
            supportsTextGeneration: configuration.mode != .off,
            supportsAudioGeneration: false,
            supportsImageGeneration: false,
            maxTokens: 16384,
            supportedProtocols: [configuration.protocolName]
        )
    }

    public func generateProposal(for request: GenerationRequest) async throws -> CardProposal {
        guard configuration.mode != .off else {
            throw ProviderError.unavailable(reason: "Provider disabled")
        }

        let endpoint = configuration.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "\(endpoint)/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutSeconds

        let apiKey = try credentialLoader.loadCredential(for: configuration.apiKeyScope)
        guard let apiKey else {
            throw ProviderError.missingAPIKey
        }
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = try makeRequestBody(for: request)
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw ProviderError.quotaExceeded
            } else if httpResponse.statusCode >= 500 {
                throw ProviderError.unavailable(reason: "Server error \(httpResponse.statusCode)")
            } else if httpResponse.statusCode == 401 {
                throw ProviderError.authenticationFailed
            } else {
                throw ProviderError.invalidResponse
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw ProviderError.invalidResponse
        }

        let proposal = try decoder.decode(from: contentData)
        return proposal
    }

    public func checkHealth(configuration: ProviderConfiguration) async -> ProviderHealthStatus {
        guard configuration.mode != .off else {
            return .unavailable(reason: "Provider mode disabled")
        }

        let endpoint = configuration.endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "\(endpoint)/models")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let apiKey = try? credentialLoader.loadCredential(for: configuration.apiKeyScope)
        if let apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .unavailable(reason: "No HTTP response")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    return .unavailable(reason: "Authentication failed")
                }
                return .degraded(reason: "HTTP \(httpResponse.statusCode)")
            }
            return .healthy
        } catch {
            return .unavailable(reason: error.localizedDescription)
        }
    }

    public func healthStatus() async -> ProviderHealthStatus {
        await checkHealth(configuration: configuration)
    }

    public func isAvailable() async -> Bool {
        await checkHealth(configuration: configuration) == .healthy
    }

    private func makeRequestBody(for request: GenerationRequest) throws -> [String: Any] {
        let prompts = [
            "You generate language-learning cards following a strict JSON schema. Return valid JSON only.",
            "Include lemma, sense key, part of speech, meaning, examples, translation, and level for each sense."
        ].joined(separator: " ")

        return [
            "model": configuration.modelID,
            "messages": [
                ["role": "system", "content": prompts],
                ["role": "user", "content": "Generate cards for: \(request.items.joined(separator: ", "))"]
            ],
            "temperature": 0.2,
            "max_tokens": 8000
        ]
    }
}
