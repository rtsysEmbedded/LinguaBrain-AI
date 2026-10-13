import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

public protocol GrammarEvaluationTransport: Sendable { func evaluate(_ request: GrammarEvaluationRequest) async throws -> GrammarEvaluationProposal }

public struct GrammarEvaluationRequest: Sendable, Equatable {
    public let prompt: String
    public let explanation: String
    public let rule: GrammarRule
    /// Human-reviewed answer and explanation the learner's answer is compared with.
    public let referenceAnswer: String?
    public let referenceExplanation: String?

    public init(prompt: String, explanation: String, rule: GrammarRule, referenceAnswer: String? = nil, referenceExplanation: String? = nil) {
        self.prompt = prompt; self.explanation = explanation; self.rule = rule
        self.referenceAnswer = referenceAnswer; self.referenceExplanation = referenceExplanation
    }
}

public struct GrammarEvaluationProposal: Sendable, Equatable {
    public let outcome: AttemptOutcome
    public let score: Double
    public let confidence: Double
    public let explanationFeedback: String
    public let applicationFeedback: String
    public let rule: RuleReference
    /// Provider and model that produced the proposal (provenance).
    public let provider: String
    public let model: String

    public init(outcome: AttemptOutcome, score: Double, confidence: Double, explanationFeedback: String, applicationFeedback: String, rule: RuleReference, provider: String = "injected", model: String = "grammar") {
        self.outcome = outcome; self.score = score; self.confidence = confidence
        self.explanationFeedback = explanationFeedback; self.applicationFeedback = applicationFeedback; self.rule = rule
        self.provider = provider; self.model = model
    }
}

/// Resolves the rule and the reviewed reference from curated grammar
/// content by the review unit's objective key. Draft content never resolves.
public struct CatalogGrammarContextResolver: GrammarEvaluationContextResolving {
    private let catalog: GrammarContentCatalog

    public init(catalog: GrammarContentCatalog) {
        self.catalog = catalog
    }

    public func context(for exercise: ExerciseInstance) async throws -> GrammarEvaluationContext? {
        guard let entry = catalog.curatedEntry(objectiveKey: exercise.reviewUnit.objectiveKey),
              let rule = catalog.ruleIndex[entry.ruleCode] else { return nil }
        return GrammarEvaluationContext(rule: rule, referenceAnswer: entry.referenceAnswer, referenceExplanation: entry.referenceExplanation)
    }
}

/// Resolves nothing; evaluation by exercise then reports malformed input.
public struct NoGrammarContextResolver: GrammarEvaluationContextResolving {
    public init() {}
    public func context(for exercise: ExerciseInstance) async throws -> GrammarEvaluationContext? { nil }
}

public struct GrammarEvaluationProvider: PracticeEvaluator, Sendable {
    public static let evaluatorVersion = "grammar-evaluator-v1"
    public static let minimumConfidence = 0.6

    private let transport: any GrammarEvaluationTransport
    private let contextResolver: any GrammarEvaluationContextResolving

    public init(transport: any GrammarEvaluationTransport, contextResolver: any GrammarEvaluationContextResolving = NoGrammarContextResolver()) {
        self.transport = transport
        self.contextResolver = contextResolver
    }

    public func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard let context = try await contextResolver.context(for: exercise) else {
            throw PracticeEvaluationError.malformedOutput
        }
        return try await evaluate(
            GrammarEvaluationRequest(prompt: exercise.prompt, explanation: attempt.response, rule: context.rule, referenceAnswer: context.referenceAnswer, referenceExplanation: context.referenceExplanation),
            attempt: attempt,
            exercise: exercise
        )
    }

    public func evaluate(_ request: GrammarEvaluationRequest, attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        do {
            let proposal = try await transport.evaluate(request)
            guard proposal.rule.code == request.rule.code, (0...1).contains(proposal.score), (0...1).contains(proposal.confidence), proposal.confidence >= Self.minimumConfidence else { throw PracticeEvaluationError.malformedOutput }
            return EvaluationResult(outcome: proposal.outcome, score: proposal.score, confidence: proposal.confidence,
                feedback: [TypedFeedback(message: proposal.explanationFeedback), TypedFeedback(message: proposal.applicationFeedback)],
                rules: [proposal.rule], evaluatorVersion: Self.evaluatorVersion,
                provenance: Provenance(provider: proposal.provider, model: proposal.model, promptVersion: GrammarExerciseFactory.contractVersion, schemaVersion: GrammarExerciseFactory.contractVersion, validatorVersion: Self.evaluatorVersion, generatedAt: Date(timeIntervalSince1970: 0)), attemptID: attempt.id, exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id)
        } catch is CancellationError { throw PracticeEvaluationError.cancelled }
          catch let error as PracticeEvaluationError { throw error }
          catch { throw PracticeEvaluationError.transportFailure }
    }
}
