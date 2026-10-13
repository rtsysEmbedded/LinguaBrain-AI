import Foundation
import LinguaBrainDomain

public enum PracticeEvaluationError: Error, Codable, Sendable, Equatable {
    case transportFailure
    case cancelled
    case malformedOutput
    case lowConfidence
    case unsupported
    case providerUnavailable

    public var unavailableReason: PracticeUnavailableReason {
        switch self {
        case .transportFailure: .transportFailure
        case .cancelled: .cancelled
        case .malformedOutput: .malformedOutput
        case .lowConfidence: .lowConfidence
        case .unsupported: .unsupported
        case .providerUnavailable: .providerUnavailable
        }
    }
}

public enum EvaluationResultValidationError: Error, Codable, Sendable, Equatable {
    case pendingOutcome
    case invalidScore
    case invalidConfidence
    case lowConfidence
    case invalidUnavailableResult
}

public enum PracticeMediaError: Error, Codable, Sendable, Equatable {
    case unavailable
    case cancelled
    case captureFailure
    case transportFailure
    case unsupported
}

/// A provider proposal. It is normalized before it can become learning
/// evidence; constructing it never writes attempts, mastery, or schedules.
public struct EvaluationResult: Codable, Sendable, Equatable {
    public let outcome: AttemptOutcome
    public let score: Double?
    public let confidence: Double?
    public let feedback: [TypedFeedback]
    public let rules: [RuleReference]
    public let evaluatorVersion: String
    public let provenance: Provenance?
    public let unavailableReason: PracticeUnavailableReason?
    public let attemptID: UUID?
    public let exerciseID: UUID?
    public let reviewUnitID: UUID?
    public let sentenceRevision: Int?
    public let meaningStatus: PracticeMeaningStatus?
    public let originalLearnerSentence: String?
    public let minimalCorrection: String?
    public let naturalVariant: String?
    public let affectedSpans: [PracticeAffectedSpan]

    public init(
        outcome: AttemptOutcome,
        score: Double? = nil,
        confidence: Double? = nil,
        feedback: [TypedFeedback] = [],
        rules: [RuleReference] = [],
        evaluatorVersion: String = "unspecified",
        provenance: Provenance? = nil,
        unavailableReason: PracticeUnavailableReason? = nil,
        attemptID: UUID? = nil,
        exerciseID: UUID? = nil,
        reviewUnitID: UUID? = nil,
        sentenceRevision: Int? = nil,
        meaningStatus: PracticeMeaningStatus? = nil,
        originalLearnerSentence: String? = nil,
        minimalCorrection: String? = nil,
        naturalVariant: String? = nil,
        affectedSpans: [PracticeAffectedSpan] = []
    ) {
        self.outcome = outcome
        self.score = score
        self.confidence = confidence
        self.feedback = feedback
        self.rules = rules
        self.evaluatorVersion = evaluatorVersion
        self.provenance = provenance
        self.unavailableReason = unavailableReason
        self.attemptID = attemptID
        self.exerciseID = exerciseID
        self.reviewUnitID = reviewUnitID
        self.sentenceRevision = sentenceRevision
        self.meaningStatus = meaningStatus
        self.originalLearnerSentence = originalLearnerSentence
        self.minimalCorrection = minimalCorrection
        self.naturalVariant = naturalVariant
        self.affectedSpans = affectedSpans
    }

    public static func unavailable(
        reason: PracticeUnavailableReason,
        evaluatorVersion: String = "unspecified",
        provenance: Provenance? = nil,
        attemptID: UUID? = nil,
        exerciseID: UUID? = nil,
        reviewUnitID: UUID? = nil,
        sentenceRevision: Int? = nil
    ) -> EvaluationResult {
        EvaluationResult(outcome: .unavailable, evaluatorVersion: evaluatorVersion, provenance: provenance, unavailableReason: reason, attemptID: attemptID, exerciseID: exerciseID, reviewUnitID: reviewUnitID, sentenceRevision: sentenceRevision)
    }

    /// Returns a safe, complete result or a typed unavailable result. Invalid
    /// provider data can therefore never fall through as an incorrect answer.
    public func normalized(minimumConfidence: Double = PracticeEvidencePolicy.minimumConfidence) -> EvaluationResult {
        do { return try validated(minimumConfidence: minimumConfidence) }
        catch let error as EvaluationResultValidationError {
            let reason: PracticeUnavailableReason
            switch error {
            case .lowConfidence: reason = .lowConfidence
            case .pendingOutcome, .invalidScore, .invalidConfidence, .invalidUnavailableResult: reason = .malformedOutput
            }
            return .unavailable(reason: reason, evaluatorVersion: evaluatorVersion, provenance: provenance, attemptID: attemptID, exerciseID: exerciseID, reviewUnitID: reviewUnitID, sentenceRevision: sentenceRevision)
        } catch {
            return .unavailable(reason: .malformedOutput, evaluatorVersion: evaluatorVersion, provenance: provenance, attemptID: attemptID, exerciseID: exerciseID, reviewUnitID: reviewUnitID, sentenceRevision: sentenceRevision)
        }
    }

    public func validated(minimumConfidence: Double = PracticeEvidencePolicy.minimumConfidence) throws -> EvaluationResult {
        guard evaluatorVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { throw EvaluationResultValidationError.invalidUnavailableResult }
        switch outcome {
        case .correct, .partial, .incorrect:
            guard unavailableReason == nil else { throw EvaluationResultValidationError.invalidUnavailableResult }
            if let score, !score.isFinite || !(0...1).contains(score) { throw EvaluationResultValidationError.invalidScore }
            if let confidence, !confidence.isFinite || !(0...1).contains(confidence) { throw EvaluationResultValidationError.invalidConfidence }
            if let confidence, confidence < minimumConfidence { throw EvaluationResultValidationError.lowConfidence }
            let defaultScore: Double = outcome == .correct ? 1 : (outcome == .partial ? 0.5 : 0)
            return EvaluationResult(outcome: outcome, score: score ?? defaultScore, confidence: confidence, feedback: feedback, rules: rules, evaluatorVersion: evaluatorVersion, provenance: provenance, attemptID: attemptID, exerciseID: exerciseID, reviewUnitID: reviewUnitID, sentenceRevision: sentenceRevision, meaningStatus: meaningStatus, originalLearnerSentence: originalLearnerSentence, minimalCorrection: minimalCorrection, naturalVariant: naturalVariant, affectedSpans: affectedSpans)
        case .skipped:
            if let score, score != 0 { throw EvaluationResultValidationError.invalidScore }
            return EvaluationResult(outcome: .skipped, score: 0, confidence: nil, feedback: feedback, rules: rules, evaluatorVersion: evaluatorVersion, provenance: provenance, attemptID: attemptID, exerciseID: exerciseID, reviewUnitID: reviewUnitID, sentenceRevision: sentenceRevision, meaningStatus: meaningStatus, originalLearnerSentence: originalLearnerSentence, minimalCorrection: minimalCorrection, naturalVariant: naturalVariant, affectedSpans: affectedSpans)
        case .unavailable:
            guard score == nil, confidence == nil else { throw EvaluationResultValidationError.invalidUnavailableResult }
            return EvaluationResult(outcome: .unavailable, evaluatorVersion: evaluatorVersion, provenance: provenance, unavailableReason: unavailableReason ?? .providerUnavailable, attemptID: attemptID, exerciseID: exerciseID, reviewUnitID: reviewUnitID, sentenceRevision: sentenceRevision, meaningStatus: meaningStatus, originalLearnerSentence: originalLearnerSentence, minimalCorrection: minimalCorrection, naturalVariant: naturalVariant, affectedSpans: affectedSpans)
        case .pending:
            throw EvaluationResultValidationError.pendingOutcome
        }
    }
}

public struct PracticeExerciseRequest: Codable, Sendable, Equatable {
    public let reviewUnit: ReviewUnit
    public init(reviewUnit: ReviewUnit) { self.reviewUnit = reviewUnit }
}

public struct WritingExerciseDescriptor: Codable, Sendable, Equatable {
    public let exercise: ExerciseInstance
    public let targetWord: String
    public let partOfSpeech: String
    public let cefrLevel: String
    public let allowedContext: String

    public init(exercise: ExerciseInstance, targetWord: String, partOfSpeech: String, cefrLevel: String, allowedContext: String) {
        self.exercise = exercise
        self.targetWord = targetWord
        self.partOfSpeech = partOfSpeech
        self.cefrLevel = cefrLevel
        self.allowedContext = allowedContext
    }
}

public protocol WritingExerciseRetrieval: Sendable {
    func nextWritingExercise(learnerID: String, cefrLevel: String, seed: Int) async throws -> WritingExerciseDescriptor?
}

public protocol PracticeExerciseRetrieval: Sendable {
    func retrieveExercise(for request: PracticeExerciseRequest) async throws -> ExerciseInstance?
}

public protocol PracticeAttemptPersistence: Sendable {
    func saveAttempt(_ attempt: Attempt) async throws
    func attempt(id: UUID) async throws -> Attempt?
    func attempt(idempotencyKey: IdempotencyKey) async throws -> Attempt?
    func attempts(for unit: ReviewUnit) async throws -> [Attempt]
}

public protocol PracticeLearningEventPersistence: Sendable {
    func saveLearningEvent(_ event: PracticeLearningEvent) async throws
    func learningEvent(id: UUID) async throws -> PracticeLearningEvent?
    func learningEvents(for unit: ReviewUnit) async throws -> [PracticeLearningEvent]
}

public protocol PracticeHelpEventPersistence: Sendable {
    func saveEvent(_ event: PracticeEvent, for attemptID: UUID) async throws
    func events(for attemptID: UUID) async throws -> [PracticeEvent]
}

public protocol PracticeSentencePlayback: Sendable {
    func sentenceAudio(for sentence: Sentence) async throws -> MediaAsset
}

public protocol PracticeRecording: Sendable {
    func record() async throws -> Data
}

public protocol PracticePronunciationAssessment: Sendable {
    func assessPronunciation(_ audio: Data, sentence: Sentence) async throws -> EvaluationResult
}

public protocol PracticeMedia: PracticeSentencePlayback, PracticeRecording, PracticePronunciationAssessment {}

public struct PracticeLearningHandoff: Codable, Sendable, Equatable {
    public let attemptID: UUID
    public let reviewUnitID: UUID
    public let outcome: AttemptOutcome
    public let score: Double?
    public let masteryDelta: Double
    public let scheduleRating: PracticeScheduleRating?
    public let scheduledAt: Date
    public let policyVersion: String

    public init(attemptID: UUID, reviewUnitID: UUID, outcome: AttemptOutcome, score: Double?, masteryDelta: Double, scheduleRating: PracticeScheduleRating?, scheduledAt: Date, policyVersion: String = PracticeEvidencePolicy.version) {
        self.attemptID = attemptID; self.reviewUnitID = reviewUnitID; self.outcome = outcome; self.score = score; self.masteryDelta = masteryDelta; self.scheduleRating = scheduleRating; self.scheduledAt = scheduledAt; self.policyVersion = policyVersion
    }
}

public protocol PracticeReviewMasteryScheduling: Sendable {
    func handoff(_ effect: PracticeLearningHandoff) async throws
}

/// A pure scheduler calculation. It returns a projection; it does not write
/// persistence, mastery, or history. The review service commits its result in
/// the same repository transaction as the attempt and learning event.
public protocol PracticeFSRSScheduler: Sendable {
    var algorithmVersion: String { get }
    func schedule(previous: PracticeMasteryProjection?, rating: PracticeScheduleRating, at: Date) -> PracticeMasteryProjection
}

public protocol PracticeClock: Sendable { func now() -> Date }
public protocol PracticeEvaluator: Sendable { func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult }
public protocol PracticeRepository: PracticeAttemptPersistence, PracticeLearningEventPersistence, Sendable {
    func saveReviewUnit(_ unit: ReviewUnit, projection: PracticeMasteryProjection?) async throws
    func reviewUnit(id: UUID) async throws -> ReviewUnit?
    func projection(for unitID: UUID) async throws -> PracticeMasteryProjection?
    func saveSentence(_ sentence: Sentence) async throws
    func sentence(id: UUID, revision: Int) async throws -> Sentence?
    func transaction(_ operation: @Sendable () async throws -> Void) async throws
}
