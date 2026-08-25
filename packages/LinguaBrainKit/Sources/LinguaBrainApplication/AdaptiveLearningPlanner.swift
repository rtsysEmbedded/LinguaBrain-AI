import Foundation
import LinguaBrainDomain

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
    public let explanation: String
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
        let safeMinutes = max(1, availableMinutes)
        let safeEnergy = min(max(energy, 1), 10)
        let capacity = max(1, min(candidates.count, safeMinutes / (safeEnergy <= 3 ? 2 : 1)))
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
        let explanation = safeEnergy <= 3
            ? "Low-energy plan prioritizes the highest-risk objectives with a reduced session size."
            : "Plan prioritizes low mastery, overdue review, and mission relevance."
        return AdaptiveLearningPlan(candidates: selected, availableMinutes: safeMinutes, energy: safeEnergy, explanation: explanation)
    }
}
