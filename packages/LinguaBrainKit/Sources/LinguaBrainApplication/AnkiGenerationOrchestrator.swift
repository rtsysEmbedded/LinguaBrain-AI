import Foundation
import LinguaBrainDomain

// MARK: - Generation Use Case (T012)

public protocol GenerationUseCase: Sendable {
    func startGeneration(from command: GenerationRequestCommand) async throws -> GenerationJob
    func stage(of jobId: String) async throws -> GenerationStage
    func cancel(jobId: String) async throws
}

// MARK: - Approval Use Case (T016 actions)

public enum CardAction: Sendable, Equatable {
    case approve
    case reject(reason: String?)
    case edit(LexicalSense)
    case regenerate
}

public protocol ApprovalUseCase: Sendable {
    /// Applies an action to a specific proposal card (sense + direction), returning the updated bundle state.
    func apply(_ action: CardAction, proposal: CardProposal, direction: ReviewDirection) async throws -> GeneratedCardBundle
    func approveAll(_ proposal: CardProposal) async throws -> [GeneratedCardBundle]
}

// MARK: - Orchestrator (T013)

/// Durable request/stage state with cancellation, bounded retry, and idempotency (FR-014).
public actor AnkiGenerationOrchestrator: GenerationUseCase, ApprovalUseCase {

    public let maxRetries: Int
    public let retryDelayNanos: UInt64
    private let repository: PersistencePort
    private let textProvider: TextProviderPort
    private let audioProvider: AudioProviderPort?
    private let imageProvider: ImageProviderPort?
    private let validator: ProposalValidator
    private let duplicateDetector: DuplicateDetector
    private let usageReporter: UsageReporter

    public init(
        repository: PersistencePort,
        textProvider: TextProviderPort,
        audioProvider: AudioProviderPort? = nil,
        imageProvider: ImageProviderPort? = nil,
        validator: ProposalValidator,
        duplicateDetector: DuplicateDetector = DuplicateDetector(),
        usageReporter: UsageReporter = NoopUsageReporter(),
        maxRetries: Int = 3,
        retryDelayNanos: UInt64 = 10_000_000
    ) {
        self.repository = repository
        self.textProvider = textProvider
        self.audioProvider = audioProvider
        self.imageProvider = imageProvider
        self.validator = validator
        self.duplicateDetector = duplicateDetector
        self.usageReporter = usageReporter
        self.maxRetries = maxRetries
        self.retryDelayNanos = retryDelayNanos
    }

    // MARK: GenerationUseCase

    public func startGeneration(from command: GenerationRequestCommand) async throws -> GenerationJob {
        let request = GenerationRequest(
            sourceLanguage: command.sourceLanguage,
            targetLanguage: command.targetLanguage,
            level: command.level,
            topic: command.topic,
            items: command.items,
            count: command.count,
            directions: command.directions,
            mediaPreferences: MediaPreferences(audioEnabled: command.audioEnabled, imageEnabled: command.imageEnabled),
            idempotencyKey: command.idempotencyKey
        )

        var job = GenerationJob(id: UUID().uuidString, request: request)
        job.status = .running
        job.stage = .requestingProvider
        job.timestamps["started"] = Date()
        try await repository.save(job)

        do {
            let proposal = try await requestProposalWithRetry(for: request, jobId: job.id)
            try await usageReporter.record(UsageEvent(provider: proposal.provenance.provider, model: proposal.provenance.model, kind: "generation"))

            let issues = try validator.validate(proposal)
            var updatedProposal = proposal
            updatedProposal.validationIssues = issues
            // Stamp the real language pair from the learner request onto the proposal so
            // downstream identity/deduplication (FR-004/005) uses actual languages, not placeholders.
            updatedProposal.sourceLanguage = command.sourceLanguage
            updatedProposal.targetLanguage = command.targetLanguage

            job.provider = proposal.provenance.provider
            job.model = proposal.provenance.model
            job.schemaVersions = [proposal.provenance.schemaVersion ?? "unversioned"]

            job.status = .waitingForApproval
            job.stage = .awaitingApproval
            job.proposal = updatedProposal
            job.timestamps["previewReady"] = Date()
            try await repository.save(job)
            return job
        } catch {
            job.status = .rejected
            job.stage = .failed
            job.errors.append(String(describing: error))
            job.timestamps["failed"] = Date()
            try await repository.save(job)
            throw error
        }
    }

    public func stage(of jobId: String) async throws -> GenerationStage {
        guard let job = try await repository.loadJob(id: jobId) else {
            throw OrchestratorError.jobNotFound
        }
        return job.stage
    }

    public func cancel(jobId: String) async throws {
        guard var job = try await repository.loadJob(id: jobId) else {
            throw OrchestratorError.jobNotFound
        }
        job.cancellationRequested = true
        job.status = .cancelled
        job.stage = .cancelled
        job.timestamps["cancelled"] = Date()
        try await repository.save(job)
    }

    // MARK: ApprovalUseCase

    public func apply(_ action: CardAction, proposal: CardProposal, direction: ReviewDirection) async throws -> GeneratedCardBundle {
        switch action {
        case .approve:
            return try await approve(proposal: proposal, direction: direction)
        case .reject:
            return GeneratedCardBundle(
                identity: identity(for: proposal, direction: direction),
                senses: proposal.senses,
                directions: [direction],
                approvalState: .rejected,
                provenance: proposal.provenance
            )
        case .edit(let editedSense):
            var updated = proposal
            updated.senses = proposal.senses.map { $0.senseKey == editedSense.senseKey ? editedSense : $0 }
            return try await approve(proposal: updated, direction: direction, replaceSenses: [editedSense])
        case .regenerate:
            // FR-006 regenerate: re-request through the text provider for the same request shape.
            let request = GenerationRequest(
                sourceLanguage: proposal.sourceLanguage, targetLanguage: proposal.targetLanguage, level: "?",
                count: 1, directions: [direction], mediaPreferences: MediaPreferences(audioEnabled: false, imageEnabled: false),
                idempotencyKey: .random()
            )
            _ = try await textProvider.generateProposal(for: request)
            return GeneratedCardBundle(
                identity: identity(for: proposal, direction: direction),
                senses: proposal.senses,
                directions: [direction],
                approvalState: .pending,
                provenance: proposal.provenance
            )
        }
    }

    public func approveAll(_ proposal: CardProposal) async throws -> [GeneratedCardBundle] {
        var bundles: [GeneratedCardBundle] = []
        for direction in ReviewDirection.allCases {
            bundles.append(try await approve(proposal: proposal, direction: direction))
        }
        return bundles
    }

    // MARK: Private

    private func identity(for proposal: CardProposal, direction: ReviewDirection) -> CardIdentity {
        let firstSense = proposal.senses.first ?? LexicalSense(
            sourceLanguage: proposal.sourceLanguage,
            targetLanguage: proposal.targetLanguage,
            lemma: proposal.lemma,
            senseKey: "s0",
            partOfSpeech: "unknown",
            meaning: "",
            translation: ""
        )
        return duplicateDetector.identity(
            sourceLanguage: proposal.sourceLanguage, targetLanguage: proposal.targetLanguage,
            lemma: proposal.lemma, sense: firstSense, direction: direction
        )
    }

    private func approve(proposal: CardProposal, direction: ReviewDirection, replaceSenses: [LexicalSense] = []) async throws -> GeneratedCardBundle {
        let issues = try validator.validate(proposal)
        guard issues.isEmpty else {
            throw ValidationError.invalidValue(issues.joined(separator: "; "))
        }

        let senses = replaceSenses.isEmpty ? proposal.senses : replaceSenses
        // Use one stable bundle identity for both the duplicate guard and the stored record (FR-004/005).
        let bundleIdentity = self.identity(for: proposal, direction: direction)
        if try await repository.isApproved(identity: bundleIdentity) {
            throw OrchestratorError.duplicateApproval
        }

        var mediaAssets: [MediaAsset] = []
        if let audioProvider {
            for sense in senses {
                if let asset = try? await audioProvider.generateAudio(for: proposalRequest(for: proposal), sense: sense) {
                    mediaAssets.append(asset)
                }
            }
        }

        let bundle = GeneratedCardBundle(
            identity: bundleIdentity,
            senses: senses,
            directions: [direction],
            mediaAssets: mediaAssets,
            approvalState: .approved,
            provenance: proposal.provenance
        )
        try await repository.saveApprovedBundle(bundle)
        return bundle
    }

    private func proposalRequest(for proposal: CardProposal) -> GenerationRequest {
        GenerationRequest(
            sourceLanguage: proposal.sourceLanguage,
            targetLanguage: proposal.targetLanguage,
            level: proposal.senses.first?.level ?? "?",
            count: proposal.senses.count,
            directions: ReviewDirection.allCases,
            mediaPreferences: MediaPreferences(audioEnabled: true, imageEnabled: false),
            idempotencyKey: .random()
        )
    }

    private func requestProposalWithRetry(for request: GenerationRequest, jobId: String) async throws -> CardProposal {
        _ = jobId
        var lastError: Error = ProviderError.unavailable(reason: "unknown")
        for attempt in 0...maxRetries {
            do {
                return try await textProvider.generateProposal(for: request)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: retryDelayNanos)
                }
            }
        }
        throw lastError
    }
}

public enum OrchestratorError: Error, Equatable, Sendable {
    case jobNotFound
    case duplicateApproval
}

public struct NoopUsageReporter: UsageReporter {
    public init() {}
    public func record(_ usage: UsageEvent) async throws {}
}
