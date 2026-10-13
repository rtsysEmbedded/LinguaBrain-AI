import Foundation

public enum PracticeSkill: String, Codable, CaseIterable, Sendable { case writing, grammar, listening, speaking }
public enum PracticeState: String, Codable, CaseIterable, Sendable { case answering, evaluating, feedback, revealed, unavailable, finished }
public enum AttemptOutcome: String, Codable, CaseIterable, Sendable { case correct, partial, incorrect, skipped, unavailable, pending }
public enum HelpKind: String, Codable, CaseIterable, Sendable { case hint, reveal, copiedAnswer, retry }

public enum PracticeUnavailableReason: String, Codable, CaseIterable, Sendable, Equatable {
    case transportFailure
    case cancelled
    case lowConfidence
    case malformedOutput
    case unsupported
    case providerUnavailable
}

public enum PracticeMeaningStatus: String, Codable, Sendable, Equatable {
    case preserved
    case partiallyPreserved
    case changed
    case uncertain
}

public struct PracticeAffectedSpan: Codable, Sendable, Equatable {
    public let start: Int
    public let end: Int
    public let text: String
    public let category: String
    public let ruleID: String

    public init(start: Int, end: Int, text: String, category: String, ruleID: String) {
        self.start = start
        self.end = end
        self.text = text
        self.category = category
        self.ruleID = ruleID
    }
}

public enum PracticeScheduleRating: String, Codable, CaseIterable, Sendable, Equatable {
    case again, hard, good
}

/// Events that describe how a practice interaction progressed. Help events are
/// kept as a separate compatibility value because they are assistance; skip is
/// a session event, not assistance.
public enum PracticeEventKind: String, Codable, CaseIterable, Sendable, Equatable { case hint, reveal, copiedAnswer, retry, skip }
public struct PracticeEvent: Codable, Sendable, Equatable {
    public let id: UUID
    public let kind: PracticeEventKind
    public let at: Date

    public init(id: UUID = UUID(), kind: PracticeEventKind, at: Date) {
        self.id = id; self.kind = kind; self.at = at
    }
}

private enum StablePracticeIdentity {
    static func uuid(_ value: String) -> UUID {
        let bytes = Array(value.utf8)
        let first = fnv(bytes, seed: 0xcbf29ce484222325)
        let second = fnv(bytes, seed: 0x84222325cbf29ce4)
        var raw = withUnsafeBytes(of: first.bigEndian, Array.init) + withUnsafeBytes(of: second.bigEndian, Array.init)
        raw[6] = (raw[6] & 0x0f) | 0x50; raw[8] = (raw[8] & 0x3f) | 0x80
        return UUID(uuid: (raw[0], raw[1], raw[2], raw[3], raw[4], raw[5], raw[6], raw[7], raw[8], raw[9], raw[10], raw[11], raw[12], raw[13], raw[14], raw[15]))
    }
    private static func fnv(_ bytes: [UInt8], seed: UInt64) -> UInt64 { bytes.reduce(seed) { ($0 ^ UInt64($1)) &* 0x100000001b3 } }
}

public struct ReviewUnit: Codable, Hashable, Sendable, Equatable {
    public let id: UUID; public let learnerID: String; public let skill: PracticeSkill; public let objectiveKey: String
    public let sentenceID: UUID?; public let sentenceRevision: Int?
    public init(id: UUID? = nil, learnerID: String = "local", skill: PracticeSkill, objectiveKey: String, sentenceID: UUID? = nil, sentenceRevision: Int? = nil) {
        self.learnerID=learnerID; self.skill=skill; self.objectiveKey=objectiveKey; self.sentenceID=sentenceID; self.sentenceRevision=sentenceRevision
        self.id = id ?? StablePracticeIdentity.uuid([learnerID, objectiveKey, skill.rawValue, sentenceID?.uuidString ?? "none", String(sentenceRevision ?? 0)].joined(separator: "|"))
    }
    public var stableKey: String { [learnerID, objectiveKey, skill.rawValue, sentenceID?.uuidString ?? "none", String(sentenceRevision ?? 0)].joined(separator: "|") }
}

public struct ExerciseInstance: Codable, Sendable, Equatable {
    public let id: UUID; public let reviewUnit: ReviewUnit; public let prompt: String; public let sourceLanguage: String; public let targetLanguage: String
    public init(id: UUID = UUID(), reviewUnit: ReviewUnit, prompt: String, sourceLanguage: String, targetLanguage: String) { self.id=id; self.reviewUnit=reviewUnit; self.prompt=prompt; self.sourceLanguage=sourceLanguage; self.targetLanguage=targetLanguage }
}

public struct HelpEvent: Codable, Sendable, Equatable { public let id: UUID; public let kind: HelpKind; public let at: Date; public init(id: UUID = UUID(), kind: HelpKind, at: Date) { self.id=id; self.kind=kind; self.at=at } }
public struct TypedFeedback: Codable, Sendable, Equatable { public let message: String; public let isError: Bool; public let confidence: Double?; public init(message: String, isError: Bool = false, confidence: Double? = nil) { self.message=message; self.isError=isError; self.confidence=confidence } }
public struct RuleReference: Codable, Hashable, Sendable, Equatable { public let code: String; public let span: String?; public init(code: String, span: String? = nil) { self.code=code; self.span=span } }

/// The immutable evaluator evidence attached to an attempt. The application
/// layer validates this proposal before it changes any learning projection.
public struct PracticeEvaluation: Codable, Sendable, Equatable {
    public let outcome: AttemptOutcome
    public let score: Double?
    public let confidence: Double?
    public let provenance: Provenance?
    public let policyVersion: String
    public let evaluatorVersion: String
    public let unavailableReason: PracticeUnavailableReason?
    public let feedback: [TypedFeedback]
    public let rules: [RuleReference]
    public let meaningStatus: PracticeMeaningStatus?
    public let originalLearnerSentence: String?
    public let minimalCorrection: String?
    public let naturalVariant: String?
    public let affectedSpans: [PracticeAffectedSpan]

    public init(
        outcome: AttemptOutcome,
        score: Double? = nil,
        confidence: Double? = nil,
        provenance: Provenance? = nil,
        policyVersion: String = "practice-evidence-v1",
        evaluatorVersion: String = "unspecified",
        unavailableReason: PracticeUnavailableReason? = nil,
        feedback: [TypedFeedback] = [],
        rules: [RuleReference] = [],
        meaningStatus: PracticeMeaningStatus? = nil,
        originalLearnerSentence: String? = nil,
        minimalCorrection: String? = nil,
        naturalVariant: String? = nil,
        affectedSpans: [PracticeAffectedSpan] = []
    ) {
        self.outcome = outcome
        self.score = score.map { min(max($0, 0), 1) }
        self.confidence = confidence.map { min(max($0, 0), 1) }
        self.provenance = provenance
        self.policyVersion = policyVersion
        self.evaluatorVersion = evaluatorVersion
        self.unavailableReason = unavailableReason
        self.feedback = feedback
        self.rules = rules
        self.meaningStatus = meaningStatus
        self.originalLearnerSentence = originalLearnerSentence
        self.minimalCorrection = minimalCorrection
        self.naturalVariant = naturalVariant
        self.affectedSpans = affectedSpans
    }

    public var isGradable: Bool { [.correct, .partial, .incorrect].contains(outcome) }

    private enum CodingKeys: String, CodingKey { case outcome, score, confidence, provenance, policyVersion, evaluatorVersion, unavailableReason, feedback, rules, meaningStatus, originalLearnerSentence, minimalCorrection, naturalVariant, affectedSpans }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.outcome = try values.decode(AttemptOutcome.self, forKey: .outcome)
        self.score = try values.decodeIfPresent(Double.self, forKey: .score)
        self.confidence = try values.decodeIfPresent(Double.self, forKey: .confidence)
        self.provenance = try values.decodeIfPresent(Provenance.self, forKey: .provenance)
        self.policyVersion = try values.decodeIfPresent(String.self, forKey: .policyVersion) ?? "practice-evidence-v1"
        self.evaluatorVersion = try values.decodeIfPresent(String.self, forKey: .evaluatorVersion) ?? "unspecified"
        self.unavailableReason = try values.decodeIfPresent(PracticeUnavailableReason.self, forKey: .unavailableReason)
        self.feedback = try values.decodeIfPresent([TypedFeedback].self, forKey: .feedback) ?? []
        self.rules = try values.decodeIfPresent([RuleReference].self, forKey: .rules) ?? []
        self.meaningStatus = try values.decodeIfPresent(PracticeMeaningStatus.self, forKey: .meaningStatus)
        self.originalLearnerSentence = try values.decodeIfPresent(String.self, forKey: .originalLearnerSentence)
        self.minimalCorrection = try values.decodeIfPresent(String.self, forKey: .minimalCorrection)
        self.naturalVariant = try values.decodeIfPresent(String.self, forKey: .naturalVariant)
        self.affectedSpans = try values.decodeIfPresent([PracticeAffectedSpan].self, forKey: .affectedSpans) ?? []
    }
}

public struct Attempt: Codable, Sendable, Equatable {
    public let id: UUID
    public let sessionID: UUID?
    public let exerciseID: UUID
    public let reviewUnitID: UUID
    public let response: String
    public let submittedAt: Date
    public let attemptIndex: Int
    public let idempotencyKey: IdempotencyKey?
    public var outcome: AttemptOutcome
    public var evaluatorResult: PracticeEvaluation?
    public var feedback: [TypedFeedback]
    public var help: [HelpEvent]
    public var events: [PracticeEvent]
    public var rules: [RuleReference]

    public init(
        id: UUID = UUID(), sessionID: UUID? = nil, exerciseID: UUID,
        reviewUnitID: UUID, response: String, submittedAt: Date,
        attemptIndex: Int = 0, idempotencyKey: IdempotencyKey? = nil,
        outcome: AttemptOutcome = .pending, evaluatorResult: PracticeEvaluation? = nil,
        feedback: [TypedFeedback] = [], help: [HelpEvent] = [],
        events: [PracticeEvent] = [], rules: [RuleReference] = []
    ) {
        self.id = id; self.sessionID = sessionID; self.exerciseID = exerciseID; self.reviewUnitID = reviewUnitID
        self.response = response; self.submittedAt = submittedAt; self.attemptIndex = max(0, attemptIndex)
        self.idempotencyKey = idempotencyKey; self.outcome = outcome; self.evaluatorResult = evaluatorResult
        self.feedback = feedback; self.help = help; self.events = events; self.rules = rules
    }

    public var isFirstAttempt: Bool { attemptIndex == 0 }
    public var confidence: Double? { evaluatorResult?.confidence }

    private enum CodingKeys: String, CodingKey {
        case id, sessionID, exerciseID, reviewUnitID, response, submittedAt, attemptIndex,
             idempotencyKey, outcome, evaluatorResult, feedback, help, events, rules
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(UUID.self, forKey: .id)
        self.sessionID = try values.decodeIfPresent(UUID.self, forKey: .sessionID)
        self.exerciseID = try values.decode(UUID.self, forKey: .exerciseID)
        self.reviewUnitID = try values.decode(UUID.self, forKey: .reviewUnitID)
        self.response = try values.decode(String.self, forKey: .response)
        self.submittedAt = try values.decode(Date.self, forKey: .submittedAt)
        self.attemptIndex = max(0, try values.decodeIfPresent(Int.self, forKey: .attemptIndex) ?? 0)
        self.idempotencyKey = try values.decodeIfPresent(IdempotencyKey.self, forKey: .idempotencyKey)
        self.outcome = try values.decodeIfPresent(AttemptOutcome.self, forKey: .outcome) ?? .pending
        self.evaluatorResult = try values.decodeIfPresent(PracticeEvaluation.self, forKey: .evaluatorResult)
        self.feedback = try values.decodeIfPresent([TypedFeedback].self, forKey: .feedback) ?? []
        self.help = try values.decodeIfPresent([HelpEvent].self, forKey: .help) ?? []
        self.events = try values.decodeIfPresent([PracticeEvent].self, forKey: .events) ?? []
        self.rules = try values.decodeIfPresent([RuleReference].self, forKey: .rules) ?? []
    }
}

public struct PracticeSessionSnapshot: Codable, Sendable, Equatable {
    public let exercise: ExerciseInstance
    public let state: PracticeState
    public let attempts: [Attempt]
    public let help: [HelpEvent]
    public let events: [PracticeEvent]

    public init(exercise: ExerciseInstance, state: PracticeState, attempts: [Attempt] = [], help: [HelpEvent] = [], events: [PracticeEvent] = []) {
        self.exercise=exercise; self.state=state; self.attempts=attempts; self.help=help; self.events=events
    }
    public var currentAttempt: Attempt? { attempts.last }
}

public enum PracticeSessionAction: String, Codable, Sendable, Equatable {
    case prepare, requestHint, submit, evaluationCompleted, reveal, unavailable, retry, `continue`, skip
}

public extension PracticeState {
    /// Returns the next state for a domain action, or nil for an illegal
    /// transition. Repeating `continue` after finishing is idempotent.
    func transition(for action: PracticeSessionAction) -> PracticeState? {
        switch (self, action) {
        case (.answering, .prepare), (.answering, .requestHint): .answering
        case (.answering, .submit): .evaluating
        case (.answering, .reveal): .revealed
        case (.answering, .skip): .finished
        case (.evaluating, .evaluationCompleted): .feedback
        case (.evaluating, .unavailable): .unavailable
        case (.feedback, .retry), (.revealed, .retry), (.unavailable, .retry): .answering
        case (.feedback, .continue), (.revealed, .continue), (.unavailable, .continue): .finished
        case (.finished, .continue): .finished
        default: nil
        }
    }

    func canApply(_ action: PracticeSessionAction) -> Bool { transition(for: action) != nil }
}

public enum PracticeSessionError: Error, Equatable, Sendable { case notPrepared; case finished; case invalidTransition }

public enum PracticeMasteryState: String, Codable, Sendable { case unknown, new, learning, mastered }
public struct PracticeMasteryProjection: Codable, Sendable, Equatable {
    public var state: PracticeMasteryState; public var score: Double?; public var dueAt: Date?; public var algorithmVersion: String?; public var schedulerState: String?
    /// These counters are part of the projection rather than a second history
    /// table. They make the mastery average deterministic after a restart.
    public var independentEvidenceCount: Int
    public var independentScoreTotal: Double
    public init(state: PracticeMasteryState = .unknown, score: Double? = nil, dueAt: Date? = nil, algorithmVersion: String? = nil, schedulerState: String? = nil, independentEvidenceCount: Int = 0, independentScoreTotal: Double = 0) {
        self.state=state
        self.score=score.map { min(max($0, 0), 1) }
        self.dueAt=dueAt
        self.algorithmVersion=algorithmVersion
        self.schedulerState=schedulerState
        self.independentEvidenceCount=max(0, independentEvidenceCount)
        self.independentScoreTotal=max(0, independentScoreTotal)
    }

    public var hasObservedEvidence: Bool {
        state != .unknown || score != nil || dueAt != nil || algorithmVersion != nil || schedulerState != nil || independentEvidenceCount > 0
    }
}

/// The opaque memory carried by the pinned FSRS adapter. Keeping it as a
/// portable value lets persistence store it without knowing the scheduler.
public enum PracticeFSRSPhase: String, Codable, Sendable, Equatable { case new, learning, review, relearning }
public struct PracticeFSRSState: Codable, Sendable, Equatable {
    public let stability: Double
    public let difficulty: Double
    public let phase: PracticeFSRSPhase
    public let learningStep: Int
    public let lastReview: Date

    public init(stability: Double, difficulty: Double, phase: PracticeFSRSPhase, learningStep: Int, lastReview: Date) {
        self.stability=stability; self.difficulty=difficulty; self.phase=phase; self.learningStep=max(0, learningStep); self.lastReview=lastReview
    }
}

/// One immutable application of evidence. Its ID is the completed attempt ID,
/// so replaying delivery cannot create a second mastery or scheduling effect.
public struct PracticeLearningEvent: Codable, Sendable, Equatable {
    public let id: UUID
    public let attemptID: UUID
    public let reviewUnitID: UUID
    public let skill: PracticeSkill
    public let outcome: AttemptOutcome
    public let score: Double?
    public let masteryDelta: Double
    public let independentRecallEligible: Bool
    public let schedulingEligible: Bool
    public let scheduleRating: PracticeScheduleRating?
    public let unavailableReason: PracticeUnavailableReason?
    public let occurredAt: Date
    public let policyVersion: String

    public init(id: UUID? = nil, attemptID: UUID, reviewUnitID: UUID, skill: PracticeSkill, outcome: AttemptOutcome, score: Double?, masteryDelta: Double, independentRecallEligible: Bool, schedulingEligible: Bool, scheduleRating: PracticeScheduleRating?, unavailableReason: PracticeUnavailableReason? = nil, occurredAt: Date, policyVersion: String = "practice-evidence-v1") {
        self.id=id ?? attemptID; self.attemptID=attemptID; self.reviewUnitID=reviewUnitID; self.skill=skill; self.outcome=outcome; self.score=score; self.masteryDelta=masteryDelta; self.independentRecallEligible=independentRecallEligible; self.schedulingEligible=schedulingEligible; self.scheduleRating=scheduleRating; self.unavailableReason=unavailableReason; self.occurredAt=occurredAt; self.policyVersion=policyVersion
    }
}
