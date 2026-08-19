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
