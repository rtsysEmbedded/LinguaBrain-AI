import Foundation
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainAI

// MARK: - Deterministic Fake Providers (T003, T011, plan Phase 2)

/// Deterministic text provider for application tests (T003/T011).
public final class DeterministicTextProvider: TextProviderPort, @unchecked Sendable {
    public struct ScriptedResponse {
        public let proposal: CardProposal?
        public let error: ProviderError?
        public init(proposal: CardProposal? = nil, error: ProviderError? = nil) {
            self.proposal = proposal
            self.error = error
        }
    }

    private var responses: [ScriptedResponse]
    public let recordedRequests: LockedArray<GenerationRequest> = LockedArray()
    public init(responses: [ScriptedResponse] = []) {
        self.responses = responses
    }

    public func generateProposal(for request: GenerationRequest) async throws -> CardProposal {
        recordedRequests.append(request)
        if responses.isEmpty {
            return makeProposal(lemma: deterministic(title: request))
        }
        let next = responses.removeFirst()
        if let error = next.error { throw error }
        return next.proposal ?? makeProposal(lemma: deterministic(title: request))
    }

    private func makeProposal(lemma: String) -> CardProposal {
        let sense = LexicalSense(
            sourceLanguage: "",
            targetLanguage: "",
            lemma: lemma,
            senseKey: "\(lemma)-n",
            partOfSpeech: "noun",
            meaning: "Meaning of \(lemma)",
            examples: [Sentence(text: "Example with \(lemma).", translation: "例子：\(lemma)")],
            translation: "ترجمه \(lemma)",
            level: "A1"
        )
        return CardProposal(
            lemma: lemma,
            senses: [sense],
            provenance: Provenance(provider: "deterministic", model: "model-x", schemaVersion: "generation-v1")
        )
    }

    private func deterministic(title request: GenerationRequest) -> String {
        request.topic ?? "word-\(recordedRequests.count)"
    }
}

public final class DeterministicAudioProvider: AudioProviderPort, @unchecked Sendable {
    public init() {}

    public func generateAudio(for request: GenerationRequest, sense: LexicalSense) async throws -> MediaAsset {
        MediaAsset(
            kind: .audio,
            locale: request.targetLanguage,
            checksum: "audio-\(sense.senseKey)",
            provider: "deterministic-audio",
            model: "tts-channel",
            availability: .available
        )
    }
}

// MARK: - In-Memory Persistence (T015 application tests)

public actor InMemoryPersistence: PersistencePort {
    private var jobs: [String: GenerationJob] = [:]
    private var approvedBundles: [GeneratedCardBundle] = []

    public init() {}

    public func save(_ job: GenerationJob) async throws {
        jobs[job.id] = job
    }

    public func loadJob(id: String) async throws -> GenerationJob? {
        jobs[id]
    }

    public func saveApprovedBundle(_ bundle: GeneratedCardBundle) async throws {
        approvedBundles.append(bundle)
    }

    public func approvedBundles() async throws -> [GeneratedCardBundle] {
        approvedBundles
    }

    public func bundle(by identity: CardIdentity) async throws -> GeneratedCardBundle? {
        approvedBundles.first { $0.identity == identity }
    }

    public func isApproved(identity: CardIdentity) async throws -> Bool {
        approvedBundles.contains { $0.identity == identity }
    }
}

public final class NoopCredentialStore: SecureCredentialStore {
    public init() {}
    public func loadCredential(for scope: String) throws -> String? { nil }
    public func saveCredential(_ secret: String, for scope: String) throws {}
    public func deleteCredential(for scope: String) throws {}
}

public final class AlwaysConsent: ConsentGate {
    public init() {}
    public func hasConsent(to scope: String) -> Bool { true }
    public func requestConsent(to scope: String) async throws {}
}

// MARK: - Test Credential Loaders (T031)

public final class TestCredentialLoader: CredentialLoader {
    private let storage: LockedStorage<[String: String]>

    public init(credentials: [String: String] = [:]) {
        self.storage = LockedStorage(credentials)
    }

    public func loadCredential(for scope: String) throws -> String? {
        storage.withValue { $0[scope] }
    }

    public func setCredential(_ value: String, for scope: String) {
        storage.withValue { $0[scope] = value }
    }
}

public final class LockedStorage<Element>: @unchecked Sendable {
    private var value: Element
    private let lock = NSLock()

    public init(_ value: Element) {
        self.value = value
    }

    public func withValue<T>(_ block: (inout Element) throws -> T) rethrows -> T {
        lock.lock(); defer { lock.unlock() }
        return try block(&value)
    }
}

public final class NoOpCredentialLoader: CredentialLoader {
    public init() {}
    public func loadCredential(for scope: String) throws -> String? { nil }
}

public final class FailingCredentialLoader: CredentialLoader {
    public init() {}
    public func loadCredential(for scope: String) throws -> String? {
        throw ProviderError.missingAPIKey
    }
}

// MARK: - Failing Fake Providers (T033)

public final class FailingTextProvider: TextProviderPort, @unchecked Sendable {
    public let error: ProviderError

    public init(error: ProviderError = .unavailable(reason: "Simulated failure")) {
        self.error = error
    }

    public func generateProposal(for request: GenerationRequest) async throws -> CardProposal {
        throw error
    }
}

public final class SlowTextProvider: TextProviderPort, @unchecked Sendable {
    public let delay: TimeInterval

    public init(delay: TimeInterval = 5.0) {
        self.delay = delay
    }

    public func generateProposal(for request: GenerationRequest) async throws -> CardProposal {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return CardProposal(
            lemma: "timeout-test",
            senses: [],
            provenance: Provenance(provider: "slow", model: "test")
        )
    }
}

public final class NetworkErrorTextProvider: TextProviderPort, @unchecked Sendable {
    public func generateProposal(for request: GenerationRequest) async throws -> CardProposal {
        throw ProviderError.network(reason: "Simulated network failure")
    }
}

// MARK: - Helpers

/// Thread-safe append-only array used by the deterministic provider.
public final class LockedArray<Element>: @unchecked Sendable {
    private var storage: [Element] = []
    private let lock = NSLock()
    public init() {}

    public func append(_ element: Element) {
        lock.lock(); defer { lock.unlock() }
        storage.append(element)
    }

    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return storage.count
    }
}