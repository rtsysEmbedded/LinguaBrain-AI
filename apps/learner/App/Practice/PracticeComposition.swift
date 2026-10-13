import Foundation
import LinguaBrainApplication
import LinguaBrainDomain
import SwiftUI

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

    init(session: any PracticeSessionUseCases) {
        self.session = session
    }

    init(
        repository: any PracticeRepository,
        evaluator: any PracticeEvaluator,
        clock: any PracticeClock,
        scheduler: any PracticeFSRSScheduler,
        maximumAttempts: Int = 4
    ) {
        self.session = PracticeSessionService(
            repository: repository,
            evaluator: evaluator,
            clock: clock,
            scheduler: scheduler,
            maximumAttempts: maximumAttempts
        )
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

/// The shared boundary can be placed in a route before a story-specific
/// exercise factory exists. It only presents the Feature 004 session when a
/// real exercise was supplied. Otherwise it retains the route's established
/// practice surface, rather than presenting an empty queue that the learner
/// has no way to populate.
struct PracticeSessionBoundaryView<LegacyContent: View>: View {
    let composition: PracticeComposition?
    let exercise: ExerciseInstance?
    private let legacyContent: LegacyContent

    init(
        composition: PracticeComposition?,
        exercise: ExerciseInstance?,
        @ViewBuilder legacyContent: () -> LegacyContent
    ) {
        self.composition = composition
        self.exercise = exercise
        self.legacyContent = legacyContent()
    }

    var body: some View {
        if let composition, let exercise {
            PracticeSessionStateBoundaryView(
                model: composition.makeSessionModel(),
                exercise: exercise
            )
        } else {
            legacyContent
        }
    }
}

private struct PracticeSessionStateBoundaryView: View {
    @State private var model: PracticeSessionModel
    @Environment(PrototypeLocalization.self) private var localization
    let exercise: ExerciseInstance?

    var body: some View {
        PracticeScaffold(
            model: model,
            titleKey: "practice.shared.title",
            instructionKey: "practice.shared.instruction",
            descriptionKey: "practice.shared.description",
            answerLanguageTag: exercise?.targetLanguage,
            promptContent: {
                Text(exercise?.prompt ?? "")
            },
            answerEntry: { binding in
                TextField(localization.localized("practice.shared.answerPlaceholder"), text: binding, axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.roundedBorder)
            },
            revealedContent: {
                if let exercise {
                    Text(exercise.prompt)
                } else {
                    Text("")
                }
            }
        )
        .task(id: exercise?.id) { await model.load(exercise: exercise) }
        .onDisappear { model.cancel() }
    }

    init(model: PracticeSessionModel, exercise: ExerciseInstance?) {
        _model = State(initialValue: model)
        self.exercise = exercise
    }
}
