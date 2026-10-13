import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

/// The narrow application boundary consumed by the Feature 004 presentation
/// model.  The app composition supplies the concrete implementation; views
/// never construct persistence, scheduling, evaluator, or media objects.
protocol PracticeSessionUseCases: Sendable {
    func prepare(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot
    func resume(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot
    func requestHint(exerciseID: UUID) async throws -> PracticeSessionSnapshot
    func reveal(exerciseID: UUID, answerCopied: Bool) async throws -> PracticeSessionSnapshot
    func skip(exerciseID: UUID) async throws -> PracticeSessionSnapshot
    func retry(exerciseID: UUID) async throws -> PracticeSessionSnapshot
    func `continue`(exerciseID: UUID) async throws -> PracticeSessionSnapshot
    func finish(exerciseID: UUID) async throws -> PracticeSessionSnapshot
    func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent]) async throws -> Attempt
}

extension PracticeSessionService: PracticeSessionUseCases {}

/// App-owned dependency composition for the shared practice feature.
/// Instances are values containing injected ports, not a service locator or a
/// process-global singleton.  The generic initializer is deliberately useful
/// for production adapters and deterministic test compositions alike.
struct PracticeComposition: Sendable {
    let session: any PracticeSessionUseCases
    /// Repository the exercise catalog and Progress read from. `nil` in
    /// compositions that only drive a session (for example, view tests).
    let content: (any PracticeRepository & PracticeProgressReading)?
    let clock: any PracticeClock
    /// Skills for which `session` routes answers to a real evaluator.
    let gradedSkills: Set<PracticeSkill>

    init(session: any PracticeSessionUseCases, clock: any PracticeClock = SystemPracticeClock()) {
        self.session = session
        self.content = nil
        self.clock = clock
        self.gradedSkills = []
    }

    init(
        repository: any PracticeRepository & PracticeProgressReading,
        evaluator: any PracticeEvaluator,
        clock: any PracticeClock,
        scheduler: any PracticeFSRSScheduler,
        gradedSkills: Set<PracticeSkill> = [],
        maximumAttempts: Int = 4
    ) {
        self.session = PracticeSessionService(
            repository: repository,
            evaluator: evaluator,
            clock: clock,
            scheduler: scheduler,
            maximumAttempts: maximumAttempts
        )
        self.content = repository
        self.clock = clock
        self.gradedSkills = gradedSkills
    }

    @MainActor
    func makeSessionModel() -> PracticeSessionModel {
        PracticeSessionModel(session: session)
    }
}

/// A clock adapter kept at the composition edge.  It is intentionally not
/// used by the feature model or by views.
struct SystemPracticeClock: PracticeClock, Sendable {
    func now() -> Date { Date() }
}

/// Explicit capability boundary used by the app until a provider story wires
/// a real evaluator.  It is not a test fake and it cannot grade an answer;
/// every request remains ungraded and is surfaced as unavailable.
struct UnavailablePracticeEvaluator: PracticeEvaluator, Sendable {
    func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        .unavailable(
            reason: .providerUnavailable,
            evaluatorVersion: "no-provider-configured",
            attemptID: attempt.id,
            exerciseID: exercise.id,
            reviewUnitID: exercise.reviewUnit.id,
            sentenceRevision: exercise.reviewUnit.sentenceRevision
        )
    }
}
