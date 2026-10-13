import Foundation
import LinguaBrainDomain

/// Coordinates one bounded practice session. It owns session state and
/// evaluator request generations, while `PracticeReviewService` remains the
/// only application boundary allowed to apply mastery or FSRS effects.
public actor PracticeSessionService {
    private struct Record {
        var exercise: ExerciseInstance
        var state: PracticeState
        var attempts: [Attempt]
        var help: [HelpEvent]
        var events: [PracticeEvent]
        var generation: Int
        var evaluatingAttempt: UUID?
    }

    private let repository: any PracticeRepository
    private let evaluator: any PracticeEvaluator
    private let reviewService: PracticeReviewService
    private let clock: any PracticeClock
    private let maximumAttempts: Int
    private var records: [UUID: Record] = [:]

    public init(
        repository: any PracticeRepository,
        evaluator: any PracticeEvaluator,
        clock: any PracticeClock,
        reviewService: PracticeReviewService? = nil,
        scheduler: any PracticeFSRSScheduler = PracticeFSRS6Scheduler(),
        maximumAttempts: Int = 4
    ) {
        self.repository = repository
        self.evaluator = evaluator
        self.clock = clock
        self.reviewService = reviewService ?? PracticeReviewService(repository: repository, scheduler: scheduler, clock: clock)
        self.maximumAttempts = max(1, maximumAttempts)
    }

    public func prepare(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot {
        if let record = records[exercise.id] { return snapshot(record) }
        try await ensureReviewUnit(exercise.reviewUnit)
        // A review unit is practised repeatedly over time; each exercise is
        // one occurrence. Session state therefore comes only from this
        // exercise's attempts, while mastery and schedules keep using the
        // unit's full evidence through the review service.
        let saved = ordered(try await repository.attempts(for: exercise.reviewUnit).filter { $0.exerciseID == exercise.id })
        let record = Record(
            exercise: exercise,
            state: state(for: saved),
            attempts: saved,
            help: saved.flatMap(\.help),
            events: saved.flatMap(\.events),
            generation: 0,
            evaluatingAttempt: nil
        )
        records[exercise.id] = record
        return snapshot(record)
    }

    /// Rebuilds the session from durable attempts after process termination.
    /// A non-empty pending attempt means evaluator work was interrupted; it is
    /// exposed as unavailable so the session cannot spin forever and the
    /// response remains available for an explicit retry.
    public func resume(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot {
        records[exercise.id] = nil
        return try await prepare(exercise: exercise)
    }

    public func requestHint(exerciseID: UUID) async throws -> PracticeSessionSnapshot {
        try await addHelp(exerciseID: exerciseID, kind: .hint, state: nil)
    }

    public func reveal(exerciseID: UUID, answerCopied: Bool = false) async throws -> PracticeSessionSnapshot {
        var result = try await addHelp(exerciseID: exerciseID, kind: .reveal, state: .revealed)
        if answerCopied { result = try await addHelp(exerciseID: exerciseID, kind: .copiedAnswer, state: .revealed) }
        return result
    }

    /// Persists an explicit skip through the review boundary. Skip produces a
    /// learning event for auditability, but the evidence policy gives it no
    /// mastery or scheduling effect.
    public func skip(exerciseID: UUID) async throws -> PracticeSessionSnapshot {
        guard var record = records[exerciseID] else { throw PracticeSessionError.notPrepared }
        if record.state == .finished { return snapshot(record) }
        guard [.answering, .revealed].contains(record.state) else { throw PracticeSessionError.invalidTransition }

        let (draft, updated) = try await draftWithEvent(record: record, helpKind: nil, eventKind: .skip)
        record = updated
        records[exerciseID] = record
        let evaluation = EvaluationResult(outcome: .skipped, score: 0, evaluatorVersion: "session-skip", attemptID: draft.id, exerciseID: draft.exerciseID, reviewUnitID: draft.reviewUnitID)
        let applied = try await reviewService.apply(attempt: draft, evaluation: evaluation)
        guard var current = records[exerciseID], current.attempts.contains(where: { $0.id == draft.id }) else { return snapshot(record) }
        replaceAttempt(applied.attempt, in: &current)
        current.state = .finished
        current.generation += 1
        current.evaluatingAttempt = nil
        records[exerciseID] = current
        return snapshot(current)
    }

    /// Starts a new bounded attempt while retaining every earlier attempt and
    /// its help history. Calling retry repeatedly before answering is a no-op.
    public func retry(exerciseID: UUID) async throws -> PracticeSessionSnapshot {
        guard var record = records[exerciseID] else { throw PracticeSessionError.notPrepared }
        if record.state == .finished { return snapshot(record) }
        if record.state == .answering,
           let current = record.attempts.last,
           current.outcome == .pending,
           current.events.contains(where: { $0.kind == .retry }) { return snapshot(record) }
        guard record.attempts.count < maximumAttempts else {
            record.state = .finished
            record.generation += 1
            record.evaluatingAttempt = nil
            records[exerciseID] = record
            return snapshot(record)
        }

        record.generation += 1
        record.evaluatingAttempt = nil
        let (_, updated) = try await draftWithEvent(record: record, helpKind: .retry, eventKind: .retry)
        var next = updated
        next.state = .answering
        records[exerciseID] = next
        return snapshot(next)
    }

    public func `continue`(exerciseID: UUID) async throws -> PracticeSessionSnapshot {
        guard var record = records[exerciseID] else { throw PracticeSessionError.notPrepared }
        if record.state == .finished { return snapshot(record) }
        guard [.feedback, .revealed, .unavailable].contains(record.state) else { throw PracticeSessionError.invalidTransition }
        record.state = .finished
        record.generation += 1
        record.evaluatingAttempt = nil
        records[exerciseID] = record
        return snapshot(record)
    }

    /// Explicit finish is local to the session. It never fabricates a result;
    /// any in-flight evaluator result is invalidated by the generation bump.
    public func finish(exerciseID: UUID) async throws -> PracticeSessionSnapshot {
        guard var record = records[exerciseID] else { throw PracticeSessionError.notPrepared }
        if record.state == .finished { return snapshot(record) }
        record.state = .finished
        record.generation += 1
        record.evaluatingAttempt = nil
        records[exerciseID] = record
        return snapshot(record)
    }

    /// Saves the original response and a pending attempt before evaluator work
    /// starts. Every evaluator proposal, including unavailable/cancelled ones,
    /// is normalized and committed by `PracticeReviewService`.
    public func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent] = []) async throws -> Attempt {
        try await submit(exercise: exercise, response: response, help: help, using: evaluator)
    }

    public func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent] = [], using overrideEvaluator: any PracticeEvaluator) async throws -> Attempt {
        if records[exercise.id] == nil { _ = try await prepare(exercise: exercise) }
        guard var record = records[exercise.id] else { throw PracticeSessionError.notPrepared }
        if let evaluatingID = record.evaluatingAttempt,
           let existing = record.attempts.first(where: { $0.id == evaluatingID }) { return existing }
        if let existing = record.attempts.last,
           [.feedback, .revealed, .unavailable, .finished].contains(record.state),
           existing.outcome != .pending || record.state == .finished { return existing }
        guard record.state == .answering || record.state == .revealed else { throw PracticeSessionError.invalidTransition }

        let priorRecord = record
        let attempt: Attempt
        if let draft = record.attempts.last, draft.outcome == .pending, draft.response.isEmpty {
            attempt = Attempt(
                id: draft.id, sessionID: draft.sessionID, exerciseID: draft.exerciseID,
                reviewUnitID: draft.reviewUnitID, response: response,
                submittedAt: draft.submittedAt, attemptIndex: draft.attemptIndex,
                idempotencyKey: draft.idempotencyKey, outcome: .pending,
                evaluatorResult: nil, feedback: [], help: uniqueHelp(draft.help + help),
                events: uniqueEvents(draft.events), rules: []
            )
            replaceAttempt(attempt, in: &record)
        } else {
            let index = nextAttemptIndex(record.attempts)
            attempt = Attempt(
                sessionID: exercise.id, exerciseID: exercise.id,
                reviewUnitID: exercise.reviewUnit.id, response: response,
                submittedAt: clock.now(), attemptIndex: index,
                idempotencyKey: IdempotencyKey(rawValue: "\(exercise.id.uuidString):\(index)"),
                help: uniqueHelp(record.help + help), events: uniqueEvents(record.events)
            )
            record.attempts.append(attempt)
            record.help = uniqueHelp(record.help + help)
            record.events = uniqueEvents(record.events)
        }
        record.state = .evaluating
        record.evaluatingAttempt = attempt.id
        let generation = record.generation
        records[exercise.id] = record

        do {
            try await repository.transaction { try await repository.saveAttempt(attempt) }
        } catch {
            records[exercise.id] = priorRecord
            throw error
        }

        do {
            let proposal = try await overrideEvaluator.evaluate(attempt, exercise: exercise)
            guard let current = records[exercise.id], current.generation == generation, current.evaluatingAttempt == attempt.id else {
                return try await repository.attempt(id: attempt.id) ?? attempt
            }
            return try await apply(proposal: proposal, to: attempt, exerciseID: exercise.id, generation: generation)
        } catch is CancellationError {
            return try await applyUnavailable(.cancelled, to: attempt, exerciseID: exercise.id, generation: generation)
        } catch let error as PracticeEvaluationError {
            return try await applyUnavailable(error.unavailableReason, to: attempt, exerciseID: exercise.id, generation: generation)
        } catch {
            return try await applyUnavailable(.transportFailure, to: attempt, exerciseID: exercise.id, generation: generation)
        }
    }

    private func apply(proposal: EvaluationResult, to attempt: Attempt, exerciseID: UUID, generation: Int) async throws -> Attempt {
        guard let current = records[exerciseID], current.generation == generation, current.evaluatingAttempt == attempt.id else {
            return try await repository.attempt(id: attempt.id) ?? attempt
        }
        do {
            let applied = try await reviewService.apply(attempt: attempt, evaluation: proposal)
            guard var updated = records[exerciseID], updated.generation == generation, updated.evaluatingAttempt == attempt.id else { return applied.attempt }
            replaceAttempt(applied.attempt, in: &updated)
            updated.help = uniqueHelp(updated.attempts.flatMap(\.help))
            updated.events = uniqueEvents(updated.attempts.flatMap(\.events))
            updated.state = applied.decision.outcome == .unavailable ? .unavailable : (applied.decision.outcome == .skipped ? .finished : .feedback)
            updated.evaluatingAttempt = nil
            records[exerciseID] = updated
            return applied.attempt
        } catch {
            // The pending response is durable, but no result is exposed as a
            // success. Resume/retry can recover without a false grade.
            if var failed = records[exerciseID], failed.generation == generation, failed.evaluatingAttempt == attempt.id {
                failed.state = .unavailable
                failed.evaluatingAttempt = nil
                records[exerciseID] = failed
            }
            throw error
        }
    }

    private func applyUnavailable(_ reason: PracticeUnavailableReason, to attempt: Attempt, exerciseID: UUID, generation: Int) async throws -> Attempt {
        try await apply(proposal: .unavailable(reason: reason, attemptID: attempt.id, exerciseID: attempt.exerciseID, reviewUnitID: attempt.reviewUnitID), to: attempt, exerciseID: exerciseID, generation: generation)
    }

    private func addHelp(exerciseID: UUID, kind: HelpKind, state: PracticeState?) async throws -> PracticeSessionSnapshot {
        guard var record = records[exerciseID] else { throw PracticeSessionError.notPrepared }
        guard [.answering, .revealed].contains(record.state) else {
            if record.state == .finished { return snapshot(record) }
            throw PracticeSessionError.invalidTransition
        }
        let (_, updated) = try await draftWithEvent(record: record, helpKind: kind, eventKind: PracticeEventKind(kind))
        record = updated
        if let state { record.state = state }
        records[exerciseID] = record
        return snapshot(record)
    }

    private func draftWithEvent(record: Record, helpKind: HelpKind?, eventKind: PracticeEventKind) async throws -> (Attempt, Record) {
        var updated = record
        let now = clock.now()
        let help = helpKind.map { HelpEvent(kind: $0, at: now) }
        let event = PracticeEvent(kind: eventKind, at: now)
        if var existing = updated.attempts.last, existing.outcome == .pending, existing.response.isEmpty {
            if let help { existing.help = uniqueHelp(existing.help + [help]) }
            existing.events = uniqueEvents(existing.events + [event])
            try await persistDraft(existing)
            replaceAttempt(existing, in: &updated)
            updated.help = uniqueHelp(updated.attempts.flatMap(\.help))
            updated.events = uniqueEvents(updated.attempts.flatMap(\.events))
            return (existing, updated)
        }

        let index = nextAttemptIndex(updated.attempts)
        let draft = Attempt(
            sessionID: updated.exercise.id, exerciseID: updated.exercise.id,
            reviewUnitID: updated.exercise.reviewUnit.id, response: "", submittedAt: now,
            attemptIndex: index, idempotencyKey: IdempotencyKey(rawValue: "\(updated.exercise.id.uuidString):\(index)"),
            help: help.map { [$0] } ?? [], events: [event]
        )
        try await persistDraft(draft)
        updated.attempts.append(draft)
        updated.help = uniqueHelp(updated.attempts.flatMap(\.help))
        updated.events = uniqueEvents(updated.attempts.flatMap(\.events))
        return (draft, updated)
    }

    private func persistDraft(_ attempt: Attempt) async throws {
        try await repository.transaction { try await repository.saveAttempt(attempt) }
    }

    private func ensureReviewUnit(_ unit: ReviewUnit) async throws {
        if try await repository.reviewUnit(id: unit.id) == nil { try await repository.saveReviewUnit(unit, projection: PracticeMasteryProjection()) }
    }

    private func state(for attempts: [Attempt]) -> PracticeState {
        guard let last = attempts.last else { return .answering }
        switch last.outcome {
        case .pending: return last.response.isEmpty && last.events.contains(where: { $0.kind == .reveal }) ? .revealed : (last.response.isEmpty ? .answering : .unavailable)
        case .unavailable: return .unavailable
        case .skipped: return .finished
        case .correct, .partial, .incorrect: return .feedback
        }
    }

    private func nextAttemptIndex(_ attempts: [Attempt]) -> Int { (attempts.map(\.attemptIndex).max() ?? -1) + 1 }
    private func ordered(_ attempts: [Attempt]) -> [Attempt] { attempts.sorted { ($0.attemptIndex, $0.submittedAt, $0.id.uuidString) < ($1.attemptIndex, $1.submittedAt, $1.id.uuidString) } }
    private func replaceAttempt(_ attempt: Attempt, in record: inout Record) {
        if let index = record.attempts.firstIndex(where: { $0.id == attempt.id }) { record.attempts[index] = attempt } else { record.attempts.append(attempt) }
    }
    private func uniqueHelp(_ values: [HelpEvent]) -> [HelpEvent] { Dictionary(grouping: values, by: \.id).compactMap(\.value.first).sorted { ($0.at, $0.id.uuidString) < ($1.at, $1.id.uuidString) } }
    private func uniqueEvents(_ values: [PracticeEvent]) -> [PracticeEvent] { Dictionary(grouping: values, by: \.id).compactMap(\.value.first).sorted { ($0.at, $0.id.uuidString) < ($1.at, $1.id.uuidString) } }
    private func snapshot(_ record: Record) -> PracticeSessionSnapshot { PracticeSessionSnapshot(exercise: record.exercise, state: record.state, attempts: ordered(record.attempts), help: uniqueHelp(record.help), events: uniqueEvents(record.events)) }
}

private extension PracticeEventKind {
    init(_ kind: HelpKind) {
        switch kind {
        case .hint: self = .hint
        case .reveal: self = .reveal
        case .copiedAnswer: self = .copiedAnswer
        case .retry: self = .retry
        }
    }
}
