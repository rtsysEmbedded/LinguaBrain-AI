import Foundation
import LinguaBrainDomain

// MARK: - Provider Ports (T006, FR-010, FR-008)

public protocol TextProviderPort: Sendable {
    func generateProposal(for request: GenerationRequest) async throws -> CardProposal
}

public protocol AudioProviderPort: Sendable {
    func generateAudio(for request: GenerationRequest, sense: LexicalSense) async throws -> MediaAsset
}

public protocol ImageProviderPort: Sendable {
    func generateImage(for request: GenerationRequest, sense: LexicalSense) async throws -> MediaAsset
}

// MARK: - Normalized Errors (T006, plan Phase 1)

public enum ProviderError: Error, Equatable, Sendable {
    case unavailable(reason: String)
    case authenticationFailed
    case quotaExceeded
    case invalidResponse
    case timeout
    case cancelled
    case network(reason: String)
    case missingAPIKey
    case consentRequired
    case providerDisabled
    case unsupportedProtocol
    case healthCheckFailed(reason: String)
    case keychain(OSStatus)

    public var localizedDescription: String {
        switch self {
        case .unavailable(let reason) where reason.contains("disabled"): return "Provider disabled"
        case .unavailable: return "Provider unavailable"
        case .authenticationFailed: return "Authentication failed"
        case .quotaExceeded: return "Quota exceeded"
        case .invalidResponse: return "Invalid response"
        case .timeout: return "Request timed out"
        case .cancelled: return "Request cancelled"
        case .network(let reason): return "Network error: \(reason)"
        case .missingAPIKey: return "Missing API key"
        case .consentRequired: return "Consent required"
        case .providerDisabled: return "Provider disabled"
        case .unsupportedProtocol: return "Unsupported protocol"
        case .healthCheckFailed(let reason): return "Health check failed: \(reason)"
        case .keychain(let status): return "Keychain error (\(status))"
        }
    }
}

// MARK: - Validation (T014 outside-model validation, FR-003)

public protocol ProposalValidator {
    func validate(_ proposal: CardProposal) throws -> [String]
    func isValid(_ proposal: CardProposal) -> Bool
}

public enum ValidationError: Error, Equatable, Sendable {
    case missingField(String)
    case invalidValue(String)
    case unsafeText
}

// MARK: - Credential, Consent, Usage (T009, FR-009, FR-015)

public protocol SecureCredentialStore: Sendable {
    func loadCredential(for scope: String) throws -> String?
    func saveCredential(_ secret: String, for scope: String) throws
    func deleteCredential(for scope: String) throws
}

public protocol ConsentGate: Sendable {
    func hasConsent(to scope: String) -> Bool
    func requestConsent(to scope: String) async throws
}

public protocol CredentialLoader: Sendable {
    func loadCredential(for scope: String) throws -> String?
}

public protocol UsageReporter: Sendable {
    func record(_ usage: UsageEvent) async throws
}

public struct UsageEvent: Sendable, Equatable {
    public var provider: String
    public var model: String
    public var kind: String
    public var tokensRequest: Int?
    public var tokensResponse: Int?
    public var cost: Decimal?
    public var timestamp: Date

    public init(
        provider: String,
        model: String,
        kind: String,
        tokensRequest: Int? = nil,
        tokensResponse: Int? = nil,
        cost: Decimal? = nil,
        timestamp: Date = Date()
    ) {
        self.provider = provider
        self.model = model
        self.kind = kind
        self.tokensRequest = tokensRequest
        self.tokensResponse = tokensResponse
        self.cost = cost
        self.timestamp = timestamp
    }
}

// MARK: - Persistence Boundary (T015)

public protocol PersistencePort: Sendable {
    func save(_ job: GenerationJob) async throws
    func loadJob(id: String) async throws -> GenerationJob?
    func saveApprovedBundle(_ bundle: GeneratedCardBundle) async throws
    func approvedBundles() async throws -> [GeneratedCardBundle]
    func bundle(by identity: CardIdentity) async throws -> GeneratedCardBundle?
    func isApproved(identity: CardIdentity) async throws -> Bool
}

// MARK: - Use Case Candidate Model (T012)

public struct GenerationRequestCommand: Sendable, Equatable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var level: String
    public var topic: String?
    public var items: [String]
    public var count: Int
    public var directions: [ReviewDirection]
    public var audioEnabled: Bool
    public var imageEnabled: Bool
    public var idempotencyKey: IdempotencyKey

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        level: String,
        topic: String? = nil,
        items: [String] = [],
        count: Int,
        directions: [ReviewDirection] = ReviewDirection.allCases,
        audioEnabled: Bool = false,
        imageEnabled: Bool = false,
        idempotencyKey: IdempotencyKey = .random()
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.level = level
        self.topic = topic
        self.items = items
        self.count = count
        self.directions = directions
        self.audioEnabled = audioEnabled
        self.imageEnabled = imageEnabled
        self.idempotencyKey = idempotencyKey
    }
}

// MARK: - TSV Export (T026, FR-012)

/// Exports approved card bundles to TSV format with provenance tracking.
public struct TSVExporter {
    public init() {}

    /// Generates TSV content from selected bundles with stable fields.
    /// Preserves Unicode and RTL/LTR content.
    public func export(_ manifest: ExportManifest) throws -> String {
        var lines: [String] = []

        // Header row
        lines.append([
            "source_text", "target_text", "sense_key", "part_of_speech",
            "examples", "example_translations", "source_language", "target_language",
            "direction", "level", "meaning", "tags", "card_source", "provenance"
        ].joined(separator: "\t"))

        // Data rows
        for bundle in manifest.selectedBundles {
            for sense in bundle.senses {
                let examples = sense.examples.map { $0.text }.joined(separator: " | ")
                let exampleTranslations = sense.examples.map { $0.translation }.joined(separator: " | ")
                let tags = [
                    sense.level ?? "",
                    bundle.provenance.provider
                ].filter { !$0.isEmpty }.joined(separator: ",")

                let line = [
                    sense.lemma,
                    sense.translation,
                    sense.senseKey,
                    sense.partOfSpeech,
                    examples,
                    exampleTranslations,
                    bundle.identity.sourceLanguage,
                    bundle.identity.targetLanguage,
                    bundle.identity.direction.rawValue,
                    sense.level ?? "",
                    sense.meaning,
                    tags,
                    CardSource.generated.rawValue,
                    bundle.provenance.provider
                ].joined(separator: "\t")
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Provider Configuration (T030, FR-010)

public enum ProviderMode: String, CaseIterable, Sendable, Equatable {
    case builtIn = "built-in"
    case local = "local"
    case cloud = "cloud"
    case off = "off"
}

public struct ProviderConfiguration: Sendable, Equatable {
    public var mode: ProviderMode
    public var endpoint: String
    public var protocolName: String
    public var modelID: String
    public var apiKeyScope: String
    public var consentRequired: Bool
    public var timeoutSeconds: TimeInterval
    public var healthCheckInterval: TimeInterval

    public init(
        mode: ProviderMode = .cloud,
        endpoint: String = "https://api.openai.com/v1",
        protocolName: String = "openai-compatible",
        modelID: String = "gpt-4o-mini",
        apiKeyScope: String = "text",
        consentRequired: Bool = true,
        timeoutSeconds: TimeInterval = 30.0,
        healthCheckInterval: TimeInterval = 60.0
    ) {
        self.mode = mode
        self.endpoint = endpoint
        self.protocolName = protocolName
        self.modelID = modelID
        self.apiKeyScope = apiKeyScope
        self.consentRequired = consentRequired
        self.timeoutSeconds = timeoutSeconds
        self.healthCheckInterval = healthCheckInterval
    }
}

public enum ProviderHealthStatus: Sendable, Equatable {
    case healthy
    case degraded(reason: String)
    case unavailable(reason: String)
}

public protocol ProviderHealthCheck: Sendable {
    func checkHealth(configuration: ProviderConfiguration) async -> ProviderHealthStatus
}
