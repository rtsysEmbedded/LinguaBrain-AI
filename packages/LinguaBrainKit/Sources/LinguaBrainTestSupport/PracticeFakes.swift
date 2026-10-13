import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

/// A clock whose value never advances unless a test replaces the instance.
public struct FixedPracticeClock: PracticeClock, Sendable {
    public let date: Date
    public init(date: Date) { self.date = date }
    public func now() -> Date { date }
}

/// Fixed identities keep fixtures readable and make replay assertions stable.
public struct FixedPracticeIDs: Sendable, Equatable {
    public let exerciseID: UUID
    public let reviewUnitID: UUID
    public let sentenceID: UUID
    public let firstAttemptID: UUID
    public let retryAttemptID: UUID

    public init(
        exerciseID: UUID,
        reviewUnitID: UUID,
        sentenceID: UUID,
        firstAttemptID: UUID,
        retryAttemptID: UUID
    ) {
        self.exerciseID = exerciseID
        self.reviewUnitID = reviewUnitID
        self.sentenceID = sentenceID
        self.firstAttemptID = firstAttemptID
        self.retryAttemptID = retryAttemptID
    }

    public static let fixture = FixedPracticeIDs(
        exerciseID: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        reviewUnitID: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
        sentenceID: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
        firstAttemptID: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
        retryAttemptID: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
    )
}

public enum PracticeFakeError: Error, Equatable, Sendable {
    case injectedTransactionFailure
    case missingAttempt
    case missingReviewUnit
    case immutableRevision
    case immutableLearningEvent
}

/// Script steps are explicit so tests can choose provider success, typed
/// failure, cancellation, or a result that is released after a retry.
public enum ScriptedPracticeEvaluationStep: Sendable, Equatable {
    case result(EvaluationResult)
    case failure(PracticeEvaluationError)
    case cancellation
    case delayed(EvaluationResult)
}

public actor ScriptedPracticeEvaluator: PracticeEvaluator {
    private var steps: [ScriptedPracticeEvaluationStep]
    private var cursor = 0
    private var waiting: [UUID: CheckedContinuation<EvaluationResult, Error>] = [:]
    private var startedIDs: [UUID] = []

    public init(steps: [ScriptedPracticeEvaluationStep]) { self.steps = steps }

    public init(result: Result<EvaluationResult, ProviderError>) {
        switch result {
        case let .success(value): self.init(steps: [.result(value)])
        case let .failure(error): self.init(steps: [.failure(Self.map(error))])
        }
    }

    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        startedIDs.append(attempt.id)
        let step = steps.isEmpty ? .result(EvaluationResult(outcome: .correct)) : steps[min(cursor, steps.count - 1)]
        cursor += 1
        switch step {
        case let .result(value): return value
        case let .failure(error): throw error
        case .cancellation: throw CancellationError()
        case .delayed:
            return try await withCheckedThrowingContinuation { continuation in waiting[attempt.id] = continuation }
        }
    }

    public func startedAttemptIDs() -> [UUID] { startedIDs }
    public func pendingAttemptIDs() -> [UUID] { waiting.keys.sorted { $0.uuidString < $1.uuidString } }

    public func release(attemptID: UUID, with result: EvaluationResult? = nil) {
        guard let continuation = waiting.removeValue(forKey: attemptID) else { return }
        continuation.resume(returning: result ?? EvaluationResult(outcome: .correct))
    }

    public func releaseNext(with result: EvaluationResult? = nil) {
        guard let id = waiting.keys.sorted(by: { $0.uuidString < $1.uuidString }).first else { return }
        release(attemptID: id, with: result)
    }

    public func cancel(attemptID: UUID) {
        guard let continuation = waiting.removeValue(forKey: attemptID) else { return }
        continuation.resume(throwing: CancellationError())
    }

    private static func map(_ error: ProviderError) -> PracticeEvaluationError {
        switch error {
        case .cancelled: return .cancelled
        case .invalidResponse: return .malformedOutput
        case .timeout, .network: return .transportFailure
        case .unsupportedProtocol: return .unsupported
        case .providerDisabled, .unavailable, .healthCheckFailed: return .providerUnavailable
        default: return .transportFailure
        }
    }
}

public actor ScriptedPracticeMedia: PracticeMedia {
    private let audio: Result<MediaAsset, PracticeMediaError>
    private let recording: Result<Data, PracticeMediaError>
    private let pronunciation: Result<EvaluationResult, PracticeMediaError>

    public init(
        audio: Result<MediaAsset, PracticeMediaError>,
        recording: Result<Data, PracticeMediaError>,
        pronunciation: Result<EvaluationResult, PracticeMediaError>
    ) {
        self.audio = audio
        self.recording = recording
        self.pronunciation = pronunciation
    }

    public func sentenceAudio(for sentence: Sentence) async throws -> MediaAsset { try audio.get() }
    public func record() async throws -> Data { try recording.get() }
    public func assessPronunciation(_ audio: Data, sentence: Sentence) async throws -> EvaluationResult { try pronunciation.get() }
}

/// A pure deterministic scheduler fake with inspectable calls and fixed
/// intervals matching the contract examples.
public final class RecordingPracticeScheduler: PracticeFSRSScheduler, @unchecked Sendable {
    public let algorithmVersion: String
    private let lock = NSLock()
    private var recordedRatings: [PracticeScheduleRating] = []
    private let intervals: [PracticeScheduleRating: TimeInterval]

    public init(
        algorithmVersion: String = "FSRS-6.0/test",
        intervals: [PracticeScheduleRating: TimeInterval] = [.again: 600, .hard: 43_200, .good: 86_400]
    ) {
        self.algorithmVersion = algorithmVersion
        self.intervals = intervals
    }

    public func schedule(previous: PracticeMasteryProjection?, rating: PracticeScheduleRating, at now: Date) -> PracticeMasteryProjection {
        lock.lock(); recordedRatings.append(rating); lock.unlock()
        return PracticeMasteryProjection(
            state: .learning,
            score: previous?.score,
            dueAt: now.addingTimeInterval(intervals[rating] ?? 0),
            algorithmVersion: algorithmVersion,
            schedulerState: rating.rawValue,
            independentEvidenceCount: previous?.independentEvidenceCount ?? 0,
            independentScoreTotal: previous?.independentScoreTotal ?? 0
        )
    }

    public var ratings: [PracticeScheduleRating] { lock.lock(); defer { lock.unlock() }; return recordedRatings }
    public var callCount: Int { lock.lock(); defer { lock.unlock() }; return recordedRatings.count }
}

/// A small repository fake for tests that should not depend on GRDB. It uses
/// the same commit/rollback and immutable-event rules as the application
/// contract, while exposing failure injection and operation counts.
public actor DeterministicPracticeRepository: PracticeRepository, PracticeHelpEventPersistence {
    private var attempts: [UUID: Attempt] = [:]
    private var units: [UUID: (ReviewUnit, PracticeMasteryProjection)] = [:]
    private var sentences: [String: Sentence] = [:]
    private var events: [UUID: PracticeLearningEvent] = [:]
    private var failNext = false
    private var transactionCountValue = 0

    public init() {}

    public func failNextTransaction() { failNext = true }
    public func transactionCount() -> Int { transactionCountValue }

    public func saveReviewUnit(_ unit: ReviewUnit, projection: PracticeMasteryProjection? = nil) async throws {
        units[unit.id] = (unit, projection ?? PracticeMasteryProjection())
    }

    public func reviewUnit(id: UUID) async throws -> ReviewUnit? { units[id]?.0 }
    public func projection(for unitID: UUID) async throws -> PracticeMasteryProjection? { units[unitID]?.1 }

    public func saveSentence(_ sentence: Sentence) async throws {
        let key = "\(sentence.id):\(sentence.revision)"
        if let old = sentences[key], old != sentence { throw PracticeFakeError.immutableRevision }
        sentences[key] = sentence
    }

    public func sentence(id: UUID, revision: Int) async throws -> Sentence? { sentences["\(id):\(revision)"] }

    public func saveAttempt(_ attempt: Attempt) async throws {
        guard units[attempt.reviewUnitID] != nil else { throw PracticeFakeError.missingReviewUnit }
        if let old = attempts[attempt.id], old.outcome != .pending { return }
        if let key = attempt.idempotencyKey, let old = attempts.values.first(where: { $0.idempotencyKey == key }), old.id != attempt.id { return }
        attempts[attempt.id] = attempt
    }

    public func attempt(id: UUID) async throws -> Attempt? { attempts[id] }
    public func attempt(idempotencyKey: IdempotencyKey) async throws -> Attempt? { attempts.values.first { $0.idempotencyKey == idempotencyKey } }
    public func attempts(for unit: ReviewUnit) async throws -> [Attempt] { ordered(attempts.values.filter { $0.reviewUnitID == unit.id }) }

    public func saveLearningEvent(_ event: PracticeLearningEvent) async throws {
        guard attempts[event.attemptID] != nil else { throw PracticeFakeError.missingAttempt }
        if let old = events[event.id], old != event { throw PracticeFakeError.immutableLearningEvent }
        events[event.id] = event
    }

    public func learningEvent(id: UUID) async throws -> PracticeLearningEvent? { events[id] }
    public func learningEvents(for unit: ReviewUnit) async throws -> [PracticeLearningEvent] { events.values.filter { $0.reviewUnitID == unit.id }.sorted { ($0.occurredAt, $0.id.uuidString) < ($1.occurredAt, $1.id.uuidString) } }

    public func saveEvent(_ event: PracticeEvent, for attemptID: UUID) async throws {
        guard var attempt = attempts[attemptID] else { throw PracticeFakeError.missingAttempt }
        if !attempt.events.contains(where: { $0.id == event.id }) { attempt.events.append(event); attempts[attemptID] = attempt }
    }

    public func events(for attemptID: UUID) async throws -> [PracticeEvent] { attempts[attemptID]?.events ?? [] }

    public func transaction(_ operation: @Sendable () async throws -> Void) async throws {
        transactionCountValue += 1
        if failNext { failNext = false; throw PracticeFakeError.injectedTransactionFailure }
        let oldAttempts = attempts
        let oldUnits = units
        let oldSentences = sentences
        let oldEvents = events
        do { try await operation() }
        catch {
            attempts = oldAttempts
            units = oldUnits
            sentences = oldSentences
            events = oldEvents
            throw error
        }
    }

    private func ordered(_ values: some Collection<Attempt>) -> [Attempt] {
        values.sorted { ($0.attemptIndex, $0.submittedAt, $0.id.uuidString) < ($1.attemptIndex, $1.submittedAt, $1.id.uuidString) }
    }
}
