import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

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