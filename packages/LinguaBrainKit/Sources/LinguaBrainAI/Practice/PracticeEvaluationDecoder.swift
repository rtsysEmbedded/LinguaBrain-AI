import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

public struct WritingEvaluationRequest: Codable, Sendable, Equatable {
    public let learnerID: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let cefrLevel: String
    public let targetWord: String
    public let partOfSpeech: String
    public let exerciseObjective: String
    public let sentenceRevision: Int
    public let allowedContext: String
    public let learnerSentence: String

    public init(learnerID: String, sourceLanguage: String, targetLanguage: String, cefrLevel: String, targetWord: String, partOfSpeech: String, exerciseObjective: String = "write_sentence_with_target_word", sentenceRevision: Int, allowedContext: String, learnerSentence: String) {
        self.learnerID = learnerID
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.cefrLevel = cefrLevel
        self.targetWord = targetWord
        self.partOfSpeech = partOfSpeech
        self.exerciseObjective = exerciseObjective
        self.sentenceRevision = sentenceRevision
        self.allowedContext = allowedContext
        self.learnerSentence = learnerSentence
    }
}

public enum PracticeEvaluationDecoderError: Error, Equatable, Sendable {
    case unsupportedSchema(String)
    case malformed(String)
    case unsupportedLanguage(String)
    case invalidSpan
    case unknownRule(String)
    case lowConfidence
    case meaningChangeRequiresReview
}

public struct PracticeEvaluationDecoder: Sendable {
    public static let schemaVersion = "writing-evaluation-v1"
    public static let rubricVersion = "writing-rubric-v1"
    public static let validatorVersion = "writing-validator-1"
    public static let supportedLanguages: Set<String> = ["fa", "de", "en"]
    public static let ruleIDs: Set<String> = [
        "de.word_order.verb_final", "de.verb.separable", "de.verb.inflection",
        "de.lexical.target_missing", "de.lexical.unrelated", "meaning.intent_uncertain",
        "style.naturalness"
    ]
    public static let minimumConfidence = 0.70

    public init() {}

    public func decode(data: Data, request: WritingEvaluationRequest, attemptID: UUID? = nil, exerciseID: UUID? = nil, reviewUnitID: UUID? = nil) throws -> EvaluationResult {
        let envelope: WireEnvelope
        do {
            envelope = try JSONDecoder().decode(WireEnvelope.self, from: data)
        } catch {
            throw PracticeEvaluationDecoderError.malformed("invalid JSON payload")
        }
        guard envelope.schemaVersion == Self.schemaVersion else {
            throw PracticeEvaluationDecoderError.unsupportedSchema(envelope.schemaVersion)
        }
        guard Self.supportedLanguages.contains(request.sourceLanguage), Self.supportedLanguages.contains(request.targetLanguage) else {
            throw PracticeEvaluationDecoderError.unsupportedLanguage(request.targetLanguage)
        }
        guard envelope.output.originalLearnerSentence == request.learnerSentence else {
            throw PracticeEvaluationDecoderError.malformed("original response mismatch")
        }
        guard envelope.output.provenance.schemaVersion == Self.schemaVersion,
              envelope.output.provenance.promptVersion == Self.rubricVersion,
              envelope.output.provenance.validatorVersion == Self.validatorVersion else {
            throw PracticeEvaluationDecoderError.malformed("invalid provenance")
        }
        guard envelope.output.canonicalContentAction == "none",
              envelope.output.masterySchedulingMutation == false else {
            throw PracticeEvaluationDecoderError.malformed("proposal cannot mutate canonical learning state")
        }
        guard envelope.output.feedback.count <= 8, envelope.output.ruleReferences.count <= 8, envelope.output.affectedSpans.count <= 8 else {
            throw PracticeEvaluationDecoderError.malformed("bounded collection exceeded")
        }

        let ruleIDs = Set(envelope.output.ruleReferences.map(\.id))
        guard ruleIDs.isSubset(of: Self.ruleIDs) else {
            throw PracticeEvaluationDecoderError.unknownRule(ruleIDs.subtracting(Self.ruleIDs).sorted().first ?? "unknown")
        }
        let scalars = Array(request.learnerSentence)
        for span in envelope.output.affectedSpans {
            guard span.start >= 0, span.end > span.start, span.end <= scalars.count,
                  String(scalars[span.start..<span.end]) == span.text,
                  ruleIDs.contains(span.ruleID) else { throw PracticeEvaluationDecoderError.invalidSpan }
        }
        let output = envelope.output
        let outcome = AttemptOutcome(rawValue: output.outcome) ?? .unavailable
        guard output.explanation.language == request.sourceLanguage,
              output.explanation.text.isEmpty == false,
              output.explanation.text.count <= 500,
              output.feedback.allSatisfy({ !$0.message.isEmpty && $0.message.count <= 240 }),
              output.feedback.allSatisfy({ ["info", "warning", "error"].contains($0.severity) }),
              output.ruleReferences.allSatisfy({ ["grammar", "vocabulary", "meaning", "style"].contains($0.category) }),
              output.meaningAssessment.confidence.map({ $0.isFinite && (0...1).contains($0) }) ?? true else {
            throw PracticeEvaluationDecoderError.malformed("invalid explanation or feedback")
        }
        if outcome == .correct, output.minimalCorrection != nil || output.naturalVariant != nil {
            throw PracticeEvaluationDecoderError.malformed("correct answer contains unnecessary correction")
        }
        let meaningStatus = PracticeMeaningStatus(rawValue: output.meaningAssessment.status) ?? .uncertain
        if meaningStatus == .changed && output.approvalPolicy != "humanReviewRequired" {
            throw PracticeEvaluationDecoderError.meaningChangeRequiresReview
        }
        if [.correct, .partial, .incorrect].contains(outcome) {
            guard let score = output.score, score.isFinite, (0...1).contains(score),
                  let confidence = output.confidence, confidence.isFinite, (0...1).contains(confidence) else {
                throw PracticeEvaluationDecoderError.malformed("invalid score or confidence")
            }
            guard confidence >= Self.minimumConfidence else { throw PracticeEvaluationDecoderError.lowConfidence }
        } else if outcome == .unavailable {
            guard output.score == nil, output.confidence == nil else { throw PracticeEvaluationDecoderError.malformed("unavailable result is graded") }
        } else {
            throw PracticeEvaluationDecoderError.malformed("unsupported writing outcome")
        }

        let provenance = Provenance(
            provider: output.provenance.provider,
            model: output.provenance.model,
            promptVersion: output.provenance.promptVersion,
            schemaVersion: output.provenance.schemaVersion,
            validatorVersion: output.provenance.validatorVersion
        )
        let feedback = output.feedback.map { TypedFeedback(message: $0.message, isError: $0.severity == "error", confidence: output.confidence) }
        let rules = output.ruleReferences.map { RuleReference(code: $0.id) }
        let spans = output.affectedSpans.map { PracticeAffectedSpan(start: $0.start, end: $0.end, text: $0.text, category: $0.category, ruleID: $0.ruleID) }
        let unavailableReason = output.unavailableReason.flatMap(Self.mapUnavailableReason)
        return EvaluationResult(
            outcome: outcome,
            score: output.score,
            confidence: output.confidence,
            feedback: feedback,
            rules: rules,
            evaluatorVersion: output.provenance.evaluatorVersion,
            provenance: provenance,
            unavailableReason: unavailableReason,
            attemptID: attemptID,
            exerciseID: exerciseID,
            reviewUnitID: reviewUnitID,
            sentenceRevision: request.sentenceRevision,
            meaningStatus: meaningStatus,
            originalLearnerSentence: output.originalLearnerSentence,
            minimalCorrection: output.minimalCorrection,
            naturalVariant: output.naturalVariant,
            affectedSpans: spans
        )
    }

    private static func mapUnavailableReason(_ reason: String) -> PracticeUnavailableReason {
        switch reason {
        case "unsupportedLanguage": return .unsupported
        case "lowConfidence": return .lowConfidence
        case "providerUnavailable": return .providerUnavailable
        case "cancelled": return .cancelled
        case "uncertainIntent", "malformedOutput": return .malformedOutput
        default: return .malformedOutput
        }
    }
}

private struct WireEnvelope: Decodable {
    let schemaVersion: String
    let output: WireOutput
}

private struct WireOutput: Decodable {
    let outcome: String
    let meaningAssessment: MeaningAssessment
    let originalLearnerSentence: String
    let minimalCorrection: String?
    let naturalVariant: String?
    let explanation: Explanation
    let feedback: [Feedback]
    let ruleReferences: [Rule]
    let affectedSpans: [Span]
    let score: Double?
    let confidence: Double?
    let unavailableReason: String?
    let provenance: OutputProvenance
    let approvalPolicy: String
    let canonicalContentAction: String
    let masterySchedulingMutation: Bool
}

private struct MeaningAssessment: Decodable { let status: String; let confidence: Double? }
private struct Explanation: Decodable { let language: String; let text: String }
private struct Feedback: Decodable { let type: String; let message: String; let severity: String }
private struct Rule: Decodable { let id: String; let category: String }
private struct Span: Decodable { let start: Int; let end: Int; let text: String; let category: String; let ruleID: String }
private struct OutputProvenance: Decodable { let provider: String; let model: String; let evaluatorVersion: String; let schemaVersion: String; let promptVersion: String; let validatorVersion: String }
