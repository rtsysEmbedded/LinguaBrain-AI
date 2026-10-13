import Foundation
import LinguaBrainDomain

public enum LearningSessionMode: String, CaseIterable, Codable, Sendable, Equatable {
    case lightReview
    case balanced
    case challenge
}

/// Momentary learner input used to build a plan. It is deliberately separate
/// from long-term mastery and is safe to replace at the next check-in.
public struct DailyLearningState: Codable, Sendable, Equatable {
    public let energy: Int
    public let availableMinutes: Int
    public let motivation: Int
    public let mode: LearningSessionMode
    public let capturedAt: Date?

    public init(
        energy: Int,
        availableMinutes: Int,
        motivation: Int = 3,
        mode: LearningSessionMode = .balanced,
        capturedAt: Date? = nil
    ) {
        self.energy = min(max(energy, 1), 10)
        self.availableMinutes = max(1, availableMinutes)
        self.motivation = min(max(motivation, 1), 5)
        self.mode = mode
        self.capturedAt = capturedAt
    }

    public static func defaults(now: Date? = nil) -> Self {
        Self(energy: 6, availableMinutes: 20, motivation: 3, mode: .balanced, capturedAt: now)
    }

    public func isStale(at now: Date = .now, staleAfter: TimeInterval = 18 * 60 * 60) -> Bool {
        guard let capturedAt else { return false }
        return now.timeIntervalSince(capturedAt) > staleAfter
    }
}

public struct AdaptiveLearningCandidate: Sendable, Equatable {
    public let objective: LearningObjective
    public let dueAt: Date?
    public let mastery: Double
    public let missionWeight: Double

    public init(objective: LearningObjective, dueAt: Date? = nil, mastery: Double, missionWeight: Double = 0) {
        self.objective = objective
        self.dueAt = dueAt
        self.mastery = min(max(mastery, 0), 1)
        self.missionWeight = missionWeight
    }

    public func priority(at now: Date) -> Double {
        let overdueBoost: Double
        if let dueAt {
            overdueBoost = max(0, min(now.timeIntervalSince(dueAt) / 86_400, 7)) / 7
        } else {
            overdueBoost = 0.5
        }
        return (1 - mastery) * 0.65 + overdueBoost * 0.25 + missionWeight * 0.10
    }
}

public struct AdaptiveLearningPlan: Sendable, Equatable {
    public let candidates: [AdaptiveLearningCandidate]
    public let availableMinutes: Int
    public let energy: Int
    public let motivation: Int
    public let mode: LearningSessionMode
    public let usedDefaultDailyState: Bool
    public let explanation: String

    public init(
        candidates: [AdaptiveLearningCandidate],
        availableMinutes: Int,
        energy: Int,
        motivation: Int = 3,
        mode: LearningSessionMode = .balanced,
        usedDefaultDailyState: Bool = false,
        explanation: String
    ) {
        self.candidates = candidates
        self.availableMinutes = availableMinutes
        self.energy = energy
        self.motivation = motivation
        self.mode = mode
        self.usedDefaultDailyState = usedDefaultDailyState
        self.explanation = explanation
    }
}

/// Deterministic, AI-independent candidate selection. AI may enrich the
/// selected items later, but it cannot change ordering or mastery state.
public enum AdaptiveLearningPlanner {
    public static func makePlan(
        candidates: [AdaptiveLearningCandidate],
        availableMinutes: Int,
        energy: Int,
        now: Date
    ) -> AdaptiveLearningPlan {
        makePlan(
            candidates: candidates,
            dailyState: DailyLearningState(energy: energy, availableMinutes: availableMinutes),
            now: now
        )
    }

    public static func makePlan(
        candidates: [AdaptiveLearningCandidate],
        dailyState: DailyLearningState?,
        now: Date
    ) -> AdaptiveLearningPlan {
        let usedDefault = dailyState == nil || dailyState?.isStale(at: now) == true
        let state = usedDefault ? .defaults(now: now) : dailyState!
        let safeMinutes = state.availableMinutes
        let safeEnergy = state.energy
        let motivationFactor = 0.82 + (Double(state.motivation - 1) * 0.10)
        let modeFactor: Double = switch state.mode {
        case .lightReview: 0.70
        case .balanced: 1.0
        case .challenge: 1.25
        }
        let cognitiveLoadFactor = safeEnergy <= 3 ? 2.0 : 1.0
        let capacity = max(1, min(
            candidates.count,
            Int((Double(safeMinutes) / cognitiveLoadFactor * motivationFactor * modeFactor).rounded())
        ))
        let ordered = candidates.sorted {
            let lhs = $0.priority(at: now)
            let rhs = $1.priority(at: now)
            if lhs != rhs { return lhs > rhs }
            if $0.objective.senseKey != $1.objective.senseKey {
                return $0.objective.senseKey < $1.objective.senseKey
            }
            return $0.objective.id < $1.objective.id
        }
        let selected = Array(ordered.prefix(capacity))
        let explanation: String
        if usedDefault {
            explanation = "A fresh default check-in is used; due and weak objectives remain prioritized."
        } else if safeEnergy <= 3 || state.mode == .lightReview {
            explanation = "Low-energy plan prioritizes the highest-risk objectives with a reduced session size."
        } else if state.mode == .challenge {
            explanation = "Challenge plan adds capacity while preserving low mastery, overdue review, and mission relevance."
        } else {
            explanation = "Plan prioritizes low mastery, overdue review, mission relevance, and today's check-in."
        }
        return AdaptiveLearningPlan(
            candidates: selected,
            availableMinutes: safeMinutes,
            energy: safeEnergy,
            motivation: state.motivation,
            mode: state.mode,
            usedDefaultDailyState: usedDefault,
            explanation: explanation
        )
    }
}
