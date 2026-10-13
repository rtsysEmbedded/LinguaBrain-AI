import Foundation
import LinguaBrainDomain

public enum PracticeReviewServiceError: Error, Equatable, Sendable {
    case reviewUnitNotFound
    case evaluatorIdentityMismatch
    case invalidAttempt
}

public struct PracticeReviewApplicationResult: Sendable, Equatable {
    public let attempt: Attempt
    public let decision: PracticeEvidenceDecision
    public let projection: PracticeMasteryProjection
    public let learningEvent: PracticeLearningEvent
    public let wasDuplicate: Bool

    public init(attempt: Attempt, decision: PracticeEvidenceDecision, projection: PracticeMasteryProjection, learningEvent: PracticeLearningEvent, wasDuplicate: Bool = false) {
        self.attempt=attempt; self.decision=decision; self.projection=projection; self.learningEvent=learningEvent; self.wasDuplicate=wasDuplicate
    }
}

/// Owns the only application boundary that can turn evaluator proposals into
/// mastery and scheduling evidence. The scheduler is a pure calculation and
/// the repository commits all learner-visible effects in one transaction.
public struct PracticeReviewService: Sendable {
    private let repository: any PracticeRepository
    private let scheduler: any PracticeFSRSScheduler
    private let clock: any PracticeClock

    public init(repository: any PracticeRepository, scheduler: any PracticeFSRSScheduler = PracticeFSRS6Scheduler(), clock: any PracticeClock) {
        self.repository=repository; self.scheduler=scheduler; self.clock=clock
    }

    /// Applies one completed attempt. Replaying the same attempt ID returns
    /// the already committed event and never invokes the scheduler again.
    public func apply(attempt: Attempt, evaluation: EvaluationResult? = nil) async throws -> PracticeReviewApplicationResult {
        if let committed = try await repository.learningEvent(id: attempt.id) {
            let storedAttempt = try await repository.attempt(id: attempt.id) ?? attempt
            let projection = try await repository.projection(for: committed.reviewUnitID) ?? PracticeMasteryProjection()
            let decision = PracticeEvidencePolicy.decision(outcome: committed.outcome, score: committed.score, unavailableReason: committed.unavailableReason, help: storedAttempt.help, events: storedAttempt.events)
            return PracticeReviewApplicationResult(attempt: storedAttempt, decision: decision, projection: projection, learningEvent: committed, wasDuplicate: true)
        }

        if let key = attempt.idempotencyKey, let keyedAttempt = try await repository.attempt(idempotencyKey: key), keyedAttempt.id != attempt.id {
            guard let committed = try await repository.learningEvent(id: keyedAttempt.id) else { throw PracticeReviewServiceError.invalidAttempt }
            let projection = try await repository.projection(for: committed.reviewUnitID) ?? PracticeMasteryProjection()
            let decision = PracticeEvidencePolicy.decision(outcome: committed.outcome, score: committed.score, unavailableReason: committed.unavailableReason, help: keyedAttempt.help, events: keyedAttempt.events)
            return PracticeReviewApplicationResult(attempt: keyedAttempt, decision: decision, projection: projection, learningEvent: committed, wasDuplicate: true)
        }
        let storedAttempt = try await repository.attempt(id: attempt.id)
        let source = storedAttempt ?? attempt
        guard let unit = try await repository.reviewUnit(id: source.reviewUnitID) else { throw PracticeReviewServiceError.reviewUnitNotFound }

        let proposal: EvaluationResult
        if let evaluation {
            guard (evaluation.attemptID == nil || evaluation.attemptID == source.id),
                  (evaluation.exerciseID == nil || evaluation.exerciseID == source.exerciseID),
                  (evaluation.reviewUnitID == nil || evaluation.reviewUnitID == source.reviewUnitID) else {
                throw PracticeReviewServiceError.evaluatorIdentityMismatch
            }
            proposal=evaluation
        } else if let existing = source.evaluatorResult {
            proposal=EvaluationResult(outcome: existing.outcome, score: existing.score, confidence: existing.confidence, feedback: existing.feedback, rules: existing.rules, evaluatorVersion: existing.evaluatorVersion, provenance: existing.provenance, unavailableReason: existing.unavailableReason, attemptID: source.id, exerciseID: source.exerciseID, reviewUnitID: source.reviewUnitID, meaningStatus: existing.meaningStatus, originalLearnerSentence: existing.originalLearnerSentence, minimalCorrection: existing.minimalCorrection, naturalVariant: existing.naturalVariant, affectedSpans: existing.affectedSpans)
        } else {
            proposal=EvaluationResult(outcome: source.outcome, attemptID: source.id, exerciseID: source.exerciseID, reviewUnitID: source.reviewUnitID)
        }
        let normalized = proposal.normalized()
        let decision = PracticeEvidencePolicy.decision(outcome: normalized.outcome, score: normalized.score, confidence: normalized.confidence, unavailableReason: normalized.unavailableReason, help: source.help, events: source.events)
        let finalEvaluation = PracticeEvaluation(outcome: decision.outcome, score: decision.score, confidence: normalized.confidence, provenance: normalized.provenance, policyVersion: decision.policyVersion, evaluatorVersion: normalized.evaluatorVersion, unavailableReason: decision.unavailableReason, feedback: normalized.feedback, rules: normalized.rules, meaningStatus: normalized.meaningStatus, originalLearnerSentence: normalized.originalLearnerSentence, minimalCorrection: normalized.minimalCorrection, naturalVariant: normalized.naturalVariant, affectedSpans: normalized.affectedSpans)
        let finalAttempt = Attempt(id: source.id, sessionID: source.sessionID, exerciseID: source.exerciseID, reviewUnitID: source.reviewUnitID, response: source.response, submittedAt: source.submittedAt, attemptIndex: source.attemptIndex, idempotencyKey: source.idempotencyKey, outcome: decision.outcome, evaluatorResult: finalEvaluation, feedback: decision.feedback == .show ? normalized.feedback : [], help: source.help, events: source.events, rules: normalized.rules)
        let oldProjection = try await repository.projection(for: unit.id) ?? PracticeMasteryProjection()
        let nextProjection = scheduledProjection(old: oldProjection, unit: unit, decision: decision)
        let event = PracticeLearningEvent(attemptID: source.id, reviewUnitID: unit.id, skill: unit.skill, outcome: decision.outcome, score: decision.score, masteryDelta: decision.masteryDelta, independentRecallEligible: decision.independentRecallEligible, schedulingEligible: decision.schedulingEligible, scheduleRating: decision.scheduleRating, unavailableReason: decision.unavailableReason, occurredAt: clock.now(), policyVersion: decision.policyVersion)

        try await repository.transaction {
            try await repository.saveAttempt(finalAttempt)
            try await repository.saveLearningEvent(event)
            if decision.schedulingEligible { try await repository.saveReviewUnit(unit, projection: nextProjection) }
        }
        return PracticeReviewApplicationResult(attempt: finalAttempt, decision: decision, projection: nextProjection, learningEvent: event)
    }

    private func scheduledProjection(old: PracticeMasteryProjection, unit: ReviewUnit, decision: PracticeEvidenceDecision) -> PracticeMasteryProjection {
        guard decision.independentRecallEligible, decision.schedulingEligible, let rating = decision.scheduleRating else { return old }
        let count = old.independentEvidenceCount + 1
        let total = old.independentScoreTotal + decision.masteryDelta
        let score = total / Double(count)
        let scheduled = scheduler.schedule(previous: old, rating: rating, at: clock.now())
        let state: PracticeMasteryState = score >= 0.8 && count >= 3 ? .mastered : (score == 0 && count == 1 ? .new : .learning)
        return PracticeMasteryProjection(state: state, score: score, dueAt: scheduled.dueAt, algorithmVersion: scheduler.algorithmVersion, schedulerState: scheduled.schedulerState, independentEvidenceCount: count, independentScoreTotal: total)
    }
}

/// The package-owned pinned implementation mirrors the prototype's FSRS-6
/// version and stores only portable memory state in the projection.
public struct PracticeFSRS6Scheduler: PracticeFSRSScheduler, Sendable {
    public static let version = "FSRS-6.0/default-21"
    public let algorithmVersion = PracticeFSRS6Scheduler.version
    private let weights = [0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542]

    public init() {}

    public func schedule(previous: PracticeMasteryProjection?, rating: PracticeScheduleRating, at now: Date) -> PracticeMasteryProjection {
        let old = previous.flatMap { state(from: $0) }
        let elapsed = old.map { calendarDayDifference(from: $0.lastReview, to: now) } ?? 0
        let grade = rating.fsrsValue
        let memory = nextMemory(previous: old, elapsedDays: elapsed, grade: grade)
        let timing = nextTiming(phase: old?.phase ?? .new, step: old?.learningStep ?? 0, grade: grade, stability: memory.stability)
        let next = PracticeFSRSState(stability: memory.stability, difficulty: memory.difficulty, phase: timing.phase, learningStep: timing.step, lastReview: now)
        let encoded = (try? String(data: JSONEncoder().encode(next), encoding: .utf8))
        return PracticeMasteryProjection(state: previous?.state ?? .new, score: previous?.score, dueAt: now.addingTimeInterval(timing.seconds), algorithmVersion: algorithmVersion, schedulerState: encoded, independentEvidenceCount: previous?.independentEvidenceCount ?? 0, independentScoreTotal: previous?.independentScoreTotal ?? 0)
    }

    private func state(from projection: PracticeMasteryProjection) -> PracticeFSRSState? {
        guard projection.algorithmVersion == algorithmVersion, let raw = projection.schedulerState, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PracticeFSRSState.self, from: data)
    }
    private func nextMemory(previous: PracticeFSRSState?, elapsedDays: Double, grade: Int) -> (stability: Double, difficulty: Double) {
        guard let previous, previous.stability >= 0.001, previous.difficulty >= 1 else { return (max(weights[grade - 1], 0.1), clamp(weights[4] - exp(Double(grade - 1) * weights[5]) + 1, 1, 10)) }
        let retrievability = forgettingCurve(elapsedDays, previous.stability)
        let difficulty = nextDifficulty(previous.difficulty, grade)
        let stability: Double
        if elapsedDays == 0 {
            let increase = pow(previous.stability, -weights[19]) * exp(weights[17] * (Double(grade) - 3 + weights[18]))
            stability = clamp(previous.stability * (grade == 1 ? increase : max(increase, 1)), 0.001, 36_500)
        } else if grade == 1 {
            let failed = weights[11] * pow(previous.difficulty, -weights[12]) * (pow(previous.stability + 1, weights[13]) - 1) * exp(weights[14] * (1 - retrievability))
            stability = clamp(previous.stability / exp(weights[17] * weights[18]), 0.001, failed)
        } else {
            let hardPenalty = grade == 2 ? weights[15] : 1
            let recalled = previous.stability * (1 + exp(weights[8]) * (11 - previous.difficulty) * pow(previous.stability, -weights[9]) * (exp((1 - retrievability) * weights[10]) - 1) * hardPenalty)
            stability = clamp(recalled, 0.001, 36_500)
        }
        return (stability, difficulty)
    }
    private func nextDifficulty(_ difficulty: Double, _ grade: Int) -> Double {
        let delta = -weights[6] * Double(grade - 3); let damped = delta * (10 - difficulty) / 9; let initialEasy = weights[4] - exp(3 * weights[5]) + 1
        return clamp(weights[7] * initialEasy + (1 - weights[7]) * (difficulty + damped), 1, 10)
    }
    private func nextTiming(phase: PracticeFSRSPhase, step: Int, grade: Int, stability: Double) -> (seconds: TimeInterval, phase: PracticeFSRSPhase, step: Int) {
        switch phase {
        case .new: switch grade { case 1: return (60, .learning, 0); case 2: return (360, .learning, 0); default: return (600, .learning, 1) }
        case .learning: switch grade { case 1: return (60, .learning, 0); case 2: return (360, .learning, step); default: return (step == 0 ? 600 : daysInterval(stability), step == 0 ? .learning : .review, step == 0 ? 1 : 0) }
        case .review: return grade == 1 ? (600, .relearning, 0) : (daysInterval(stability), .review, 0)
        case .relearning:
            if grade == 1 { return (600, .relearning, 0) }
            if grade == 2 { return (900, .relearning, 0) }
            return (daysInterval(stability), .review, 0)
        }
    }
    private func forgettingCurve(_ elapsed: Double, _ stability: Double) -> Double { let decay = -weights[20]; let factor = exp(log(0.9) / decay) - 1; return pow(1 + factor * elapsed / stability, decay) }
    private func daysInterval(_ stability: Double) -> TimeInterval { let decay = -weights[20]; let factor = exp(log(0.9) / decay) - 1; let modifier = (pow(0.9, 1 / decay) - 1) / factor; return min(max(1, (stability * modifier).rounded()), 36_500) * 86_400 }
    private func calendarDayDifference(from start: Date, to end: Date) -> Double { var calendar=Calendar(identifier: .gregorian); calendar.timeZone=TimeZone(secondsFromGMT: 0)!; return max(0, floor(calendar.startOfDay(for: end).timeIntervalSince(calendar.startOfDay(for: start)) / 86_400)) }
    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double { min(max(value, minValue), maxValue) }
}

private extension PracticeScheduleRating { var fsrsValue: Int { switch self { case .again: 1; case .hard: 2; case .good: 3 } } }
