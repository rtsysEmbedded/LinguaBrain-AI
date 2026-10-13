import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

public protocol GrammarEvaluationTransport: Sendable { func evaluate(_ request: GrammarEvaluationRequest) async throws -> GrammarEvaluationProposal }
public struct GrammarEvaluationRequest: Sendable, Equatable { public let prompt: String; public let explanation: String; public let rule: GrammarRule; public init(prompt: String, explanation: String, rule: GrammarRule) { self.prompt=prompt; self.explanation=explanation; self.rule=rule } }
public struct GrammarEvaluationProposal: Sendable, Equatable { public let outcome: AttemptOutcome; public let score: Double; public let confidence: Double; public let explanationFeedback: String; public let applicationFeedback: String; public let rule: RuleReference; public init(outcome: AttemptOutcome, score: Double, confidence: Double, explanationFeedback: String, applicationFeedback: String, rule: RuleReference) { self.outcome=outcome; self.score=score; self.confidence=confidence; self.explanationFeedback=explanationFeedback; self.applicationFeedback=applicationFeedback; self.rule=rule } }

public struct GrammarEvaluationProvider: PracticeEvaluator, Sendable {
    private let transport: any GrammarEvaluationTransport
    public init(transport: any GrammarEvaluationTransport) { self.transport=transport }
    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard let rule = GrammarExerciseFactory.rules[exercise.reviewUnit.objectiveKey] else {
            throw PracticeEvaluationError.malformedOutput
        }
        return try await evaluate(
            GrammarEvaluationRequest(prompt: exercise.prompt, explanation: attempt.response, rule: rule),
            attempt: attempt,
            exercise: exercise
        )
    }
    public func evaluate(_ request: GrammarEvaluationRequest, attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        do {
            let proposal = try await transport.evaluate(request)
            guard proposal.rule.code == request.rule.code, (0...1).contains(proposal.score), (0...1).contains(proposal.confidence), proposal.confidence >= 0.6 else { throw PracticeEvaluationError.malformedOutput }
            return EvaluationResult(outcome: proposal.outcome, score: proposal.score, confidence: proposal.confidence,
                feedback: [TypedFeedback(message: proposal.explanationFeedback), TypedFeedback(message: proposal.applicationFeedback)],
                rules: [proposal.rule], evaluatorVersion: "grammar-evaluator-v1",
                provenance: Provenance(provider: "injected", model: "grammar", promptVersion: "grammar-practice-v1", schemaVersion: "grammar-practice-v1", validatorVersion: "grammar-evaluator-v1", generatedAt: Date(timeIntervalSince1970: 0)), attemptID: attempt.id, exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id)
        } catch is CancellationError { throw PracticeEvaluationError.cancelled }
          catch let error as PracticeEvaluationError { throw error }
          catch { throw PracticeEvaluationError.transportFailure }
    }
}
