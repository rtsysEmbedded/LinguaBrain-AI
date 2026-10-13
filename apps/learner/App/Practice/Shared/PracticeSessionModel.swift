import Foundation
import LinguaBrainApplication
import LinguaBrainDomain
import Observation

enum PracticePresentationPhase: Equatable, Sendable {
    case loading
    case empty
    case answering
    case evaluating
    case feedback
    case revealed
    case unavailable(PracticeUnavailableReason)
    case finished
    case recoverableFailure(PracticePresentationFailure)
}

enum PracticePresentationFailure: Equatable, Sendable {
    case persistence
    case invalidTransition
    case unexpected
}

/// Immutable data rendered by the future shared scaffold.  The model owns the
/// mutable answer draft; every value copied from the application snapshot is
/// immutable and remains available across redraws and resume.
struct PracticePresentationState: Equatable, Sendable {
    let phase: PracticePresentationPhase
    let exercise: ExerciseInstance?
    let answerText: String
    let attempts: [Attempt]
    let help: [HelpEvent]
    let events: [PracticeEvent]
    let feedback: [TypedFeedback]
    let currentAttemptID: UUID?

    static let initial = PracticePresentationState(
        phase: .empty,
        exercise: nil,
        answerText: "",
        attempts: [],
        help: [],
        events: [],
        feedback: [],
        currentAttemptID: nil
    )

    func replacingAnswer(_ answerText: String) -> PracticePresentationState {
        PracticePresentationState(
            phase: phase,
            exercise: exercise,
            answerText: answerText,
            attempts: attempts,
            help: help,
            events: events,
            feedback: feedback,
            currentAttemptID: currentAttemptID
        )
    }
}

/// Main-actor feature model for the shared practice boundary.  It owns only
/// presentation state and cancellable intent tasks; the injected application
/// service remains the owner of persistence, evidence policy, mastery, and
/// scheduling.
@MainActor
@Observable
final class PracticeSessionModel {
    private let session: any PracticeSessionUseCases
    private var generation = 0
    private var activeTask: Task<Void, Never>?
    private var currentExercise: ExerciseInstance?

    private(set) var state: PracticePresentationState = .initial
    var answerText = "" {
        didSet {
            guard answerText != oldValue else { return }
            state = state.replacingAnswer(answerText)
        }
    }

    init(session: any PracticeSessionUseCases) {
        self.session = session
    }

    convenience init(composition: PracticeComposition) {
        self.init(session: composition.session)
    }

    /// Loads an explicit exercise. A missing exercise is an honest empty
    /// state, rather than an endless loading phase or a synthetic objective.
    func load(exercise: ExerciseInstance?) async {
        guard let exercise else {
            cancel()
            currentExercise = nil
            answerText = ""
            state = .initial
            return
        }
        await run(exercise: exercise, phase: .loading) { session, _ in
            try await session.prepare(exercise: exercise)
        }
    }

    func prepare(exercise: ExerciseInstance) async {
        await load(exercise: exercise)
    }

    func resume() async {
        guard let exercise = currentExercise else {
            state = .initial
            return
        }
        await run(exercise: exercise, phase: .loading) { session, _ in
            try await session.resume(exercise: exercise)
        }
    }

    func requestHint() async {
        await runCurrent(phase: .evaluating) { session, exercise in
            try await session.requestHint(exerciseID: exercise.id)
        }
    }

    func reveal() async {
        await runCurrent { session, exercise in
            try await session.reveal(exerciseID: exercise.id, answerCopied: false)
        }
    }

    func copyAnswer() async {
        await runCurrent { session, exercise in
            try await session.reveal(exerciseID: exercise.id, answerCopied: true)
        }
    }

    func submit() async {
        let response = answerText
        await runCurrent { session, exercise in
            _ = try await session.submit(exercise: exercise, response: response, help: [])
            return try await session.resume(exercise: exercise)
        }
    }

    func skip() async {
        await runCurrent { session, exercise in
            try await session.skip(exerciseID: exercise.id)
        }
    }

    func retry() async {
        await runCurrent { session, exercise in
            try await session.retry(exerciseID: exercise.id)
        }
    }

    func `continue`() async {
        await runCurrent { session, exercise in
            try await session.continue(exerciseID: exercise.id)
        }
    }

    /// Lifecycle cancellation is intentionally separate from learning
    /// intents. It invalidates the generation so a late result cannot repaint
    /// a new exercise or commit a stale presentation success.
    func cancel() {
        generation += 1
        activeTask?.cancel()
        activeTask = nil
    }

    private func runCurrent(
        phase: PracticePresentationPhase? = nil,
        _ operation: @escaping @Sendable (any PracticeSessionUseCases, ExerciseInstance) async throws -> PracticeSessionSnapshot
    ) async {
        guard let exercise = currentExercise else { return }
        await run(exercise: exercise, phase: phase ?? state.phase) { session, exercise in
            try await operation(session, exercise)
        }
    }

    private func run(
        exercise: ExerciseInstance,
        phase: PracticePresentationPhase,
        operation: @escaping @Sendable (any PracticeSessionUseCases, ExerciseInstance) async throws -> PracticeSessionSnapshot
    ) async {
        let previousExerciseID = currentExercise?.id
        cancel()
        currentExercise = exercise
        if previousExerciseID != exercise.id {
            answerText = ""
            state = .initial
        }
        state = PracticePresentationState(
            phase: phase,
            exercise: exercise,
            answerText: answerText,
            attempts: state.attempts,
            help: state.help,
            events: state.events,
            feedback: state.feedback,
            currentAttemptID: state.currentAttemptID
        )
        let token = generation
        let session = self.session
        activeTask = Task { [weak self] in
            do {
                let snapshot = try await operation(session, exercise)
                guard !Task.isCancelled else { return }
                self?.apply(snapshot, token: token)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.apply(error: error, token: token, exercise: exercise)
            }
        }
        await activeTask?.value
    }

    private func apply(_ snapshot: PracticeSessionSnapshot, token: Int) {
        guard token == generation, currentExercise?.id == snapshot.exercise.id else { return }
        if let response = snapshot.currentAttempt?.response, !response.isEmpty {
            answerText = response
        }
        state = map(snapshot)
        activeTask = nil
    }

    private func apply(error: Error, token: Int, exercise: ExerciseInstance) {
        guard token == generation, currentExercise?.id == exercise.id else { return }
        let failure: PracticePresentationFailure
        if error is PracticeSessionError {
            failure = .invalidTransition
        } else {
            // Persistence adapters expose their errors through the injected
            // application boundary.  The presentation layer intentionally
            // does not import a concrete persistence module; an unclassified
            // command failure is therefore actionable as a recoverable error.
            failure = .persistence
        }
        state = PracticePresentationState(
            phase: .recoverableFailure(failure),
            exercise: exercise,
            answerText: answerText,
            attempts: state.attempts,
            help: state.help,
            events: state.events,
            feedback: state.feedback,
            currentAttemptID: state.currentAttemptID
        )
        activeTask = nil
    }

    private func map(_ snapshot: PracticeSessionSnapshot) -> PracticePresentationState {
        let attempt = snapshot.currentAttempt
        let phase: PracticePresentationPhase
        switch snapshot.state {
        case .answering: phase = .answering
        case .evaluating: phase = .evaluating
        case .feedback: phase = .feedback
        case .revealed: phase = .revealed
        case .unavailable:
            phase = .unavailable(attempt?.evaluatorResult?.unavailableReason ?? .providerUnavailable)
        case .finished: phase = .finished
        }
        return PracticePresentationState(
            phase: phase,
            exercise: snapshot.exercise,
            answerText: attempt?.response.isEmpty == false ? attempt?.response ?? answerText : answerText,
            attempts: snapshot.attempts,
            help: snapshot.help,
            events: snapshot.events,
            feedback: attempt?.feedback ?? [],
            currentAttemptID: attempt?.id
        )
    }
}
