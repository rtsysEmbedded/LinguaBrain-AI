import Foundation
import LinguaBrainDomain

/// Dispatches evaluation by skill. A skill without a registered evaluator is
/// answered with an explicit unavailable result, so an attempt can never be
/// graded by an evaluator built for another skill.
public struct PracticeEvaluatorRouter: PracticeEvaluator {
    public static let unroutedEvaluatorVersion = "no-evaluator-for-skill"

    private let evaluators: [PracticeSkill: any PracticeEvaluator]

    public init(evaluators: [PracticeSkill: any PracticeEvaluator]) {
        self.evaluators = evaluators
    }

    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard let evaluator = evaluators[exercise.reviewUnit.skill] else {
            return .unavailable(
                reason: .providerUnavailable,
                evaluatorVersion: Self.unroutedEvaluatorVersion,
                attemptID: attempt.id,
                exerciseID: exercise.id,
                reviewUnitID: exercise.reviewUnit.id,
                sentenceRevision: exercise.reviewUnit.sentenceRevision
            )
        }
        return try await evaluator.evaluate(attempt, exercise: exercise)
    }

    public func handles(_ skill: PracticeSkill) -> Bool { evaluators[skill] != nil }
}
