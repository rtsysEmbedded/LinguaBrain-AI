import Foundation

public enum PracticeFeedbackDisposition: String, Codable, CaseIterable, Sendable, Equatable {
    case show
    case showUnavailable
    case none
}

public enum PracticeRetryDisposition: String, Codable, CaseIterable, Sendable, Equatable {
    case allowed
    case notNeeded
    case notApplicable
}

public struct PracticeEvidenceDecision: Codable, Sendable, Equatable {
    public let outcome: AttemptOutcome
    public let score: Double?
    public let independentRecallEligible: Bool
    public let masteryDelta: Double
    public let schedulingEligible: Bool
    public let scheduleRating: PracticeScheduleRating?
    public let feedback: PracticeFeedbackDisposition
    public let retry: PracticeRetryDisposition
    public let unavailableReason: PracticeUnavailableReason?
    public let policyVersion: String

    public init(
        outcome: AttemptOutcome,
        score: Double?,
        independentRecallEligible: Bool,
        masteryDelta: Double,
        schedulingEligible: Bool,
        scheduleRating: PracticeScheduleRating?,
        feedback: PracticeFeedbackDisposition,
        retry: PracticeRetryDisposition,
        unavailableReason: PracticeUnavailableReason? = nil,
        policyVersion: String = PracticeEvidencePolicy.version
    ) {
        self.outcome = outcome
        self.score = score
        self.independentRecallEligible = independentRecallEligible
        self.masteryDelta = masteryDelta
        self.schedulingEligible = schedulingEligible
        self.scheduleRating = scheduleRating
        self.feedback = feedback
        self.retry = retry
        self.unavailableReason = unavailableReason
        self.policyVersion = policyVersion
    }
}

public enum PracticeEvidencePolicy {
    public static let version = "practice-evidence-v1"
    public static let minimumConfidence = 0.5

    public static func countsAsIndependentRecall(outcome: AttemptOutcome, help: [HelpEvent]) -> Bool {
        decision(outcome: outcome, help: help).independentRecallEligible && outcome == .correct
    }

    public static func masteryDelta(outcome: AttemptOutcome, help: [HelpEvent]) -> Double {
        decision(outcome: outcome, help: help).masteryDelta
    }

    public static func decision(
        outcome: AttemptOutcome,
        score: Double? = nil,
        confidence: Double? = nil,
        unavailableReason: PracticeUnavailableReason? = nil,
        help: [HelpEvent] = [],
        events: [PracticeEvent] = []
    ) -> PracticeEvidenceDecision {
        let hasSkip = events.contains { $0.kind == .skip }
        let effectiveOutcome = hasSkip ? AttemptOutcome.skipped : outcome
        let assisted = help.contains { [.reveal, .copiedAnswer].contains($0.kind) }
            || events.contains { [.reveal, .copiedAnswer].contains($0.kind) }

        if [.correct, .partial, .incorrect].contains(effectiveOutcome) {
            if let unavailableReason {
                return unavailableDecision(reason: unavailableReason)
            }
            if let score, !isBounded(score) {
                return unavailableDecision(reason: .malformedOutput)
            }
            if let confidence, !isBounded(confidence) {
                return unavailableDecision(reason: .malformedOutput)
            }
            if let confidence, confidence < minimumConfidence {
                return unavailableDecision(reason: .lowConfidence)
            }
        }

        switch effectiveOutcome {
        case .correct:
            let normalizedScore = score ?? 1
            let eligible = isBounded(normalizedScore) && (confidence == nil || isBounded(confidence!)) && !assisted
            return PracticeEvidenceDecision(
                outcome: .correct,
                score: isBounded(normalizedScore) ? normalizedScore : nil,
                independentRecallEligible: eligible,
                masteryDelta: eligible ? normalizedScore : 0,
                schedulingEligible: eligible,
                scheduleRating: eligible ? .good : nil,
                feedback: .show,
                retry: eligible ? .notNeeded : .allowed,
                unavailableReason: nil
            )
        case .partial:
            let normalizedScore = score ?? 0.5
            let eligible = isBounded(normalizedScore) && (confidence == nil || isBounded(confidence!)) && !assisted
            return PracticeEvidenceDecision(
                outcome: .partial,
                score: isBounded(normalizedScore) ? normalizedScore : nil,
                independentRecallEligible: eligible,
                masteryDelta: eligible ? normalizedScore : 0,
                schedulingEligible: eligible,
                scheduleRating: eligible ? .hard : nil,
                feedback: .show,
                retry: .allowed,
                unavailableReason: nil
            )
        case .incorrect:
            let normalizedScore = score ?? 0
            let eligible = isBounded(normalizedScore) && (confidence == nil || isBounded(confidence!)) && !assisted
            return PracticeEvidenceDecision(
                outcome: .incorrect,
                score: isBounded(normalizedScore) ? normalizedScore : nil,
                independentRecallEligible: eligible,
                masteryDelta: 0,
                schedulingEligible: eligible,
                scheduleRating: eligible ? .again : nil,
                feedback: .show,
                retry: .allowed,
                unavailableReason: nil
            )
        case .skipped:
            return PracticeEvidenceDecision(outcome: .skipped, score: 0, independentRecallEligible: false, masteryDelta: 0, schedulingEligible: false, scheduleRating: nil, feedback: .none, retry: .notApplicable)
        case .unavailable, .pending:
            let reason = unavailableReason ?? (effectiveOutcome == .pending ? .malformedOutput : .providerUnavailable)
            return PracticeEvidenceDecision(outcome: .unavailable, score: nil, independentRecallEligible: false, masteryDelta: 0, schedulingEligible: false, scheduleRating: nil, feedback: .showUnavailable, retry: .allowed, unavailableReason: reason)
        }
    }

    private static func unavailableDecision(reason: PracticeUnavailableReason) -> PracticeEvidenceDecision {
        PracticeEvidenceDecision(outcome: .unavailable, score: nil, independentRecallEligible: false, masteryDelta: 0, schedulingEligible: false, scheduleRating: nil, feedback: .showUnavailable, retry: .allowed, unavailableReason: reason)
    }

    private static func isBounded(_ value: Double) -> Bool {
        value.isFinite && (0...1).contains(value)
    }
}
