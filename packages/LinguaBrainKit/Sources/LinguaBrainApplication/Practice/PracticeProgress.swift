import Foundation
import LinguaBrainDomain

/// One review unit and its current mastery projection.
public struct PracticeUnitProgress: Sendable, Equatable {
    public let unit: ReviewUnit
    public let projection: PracticeMasteryProjection?

    public init(unit: ReviewUnit, projection: PracticeMasteryProjection?) {
        self.unit = unit
        self.projection = projection
    }
}

/// Read-only access to persisted practice projections. Implementations never
/// change mastery or schedules.
public protocol PracticeProgressReading: Sendable {
    func unitProgress(skill: PracticeSkill, learnerID: String) async throws -> [PracticeUnitProgress]
}

/// Evidence-based summary of one skill for the Progress screen.
public struct PracticeSkillProgress: Sendable, Equatable {
    public let skill: PracticeSkill
    /// Review units that have at least one independent graded attempt.
    public let evidencedUnitCount: Int
    /// Mean mastery score of evidenced units, or `nil` when there is no
    /// independent evidence yet. `nil` must not be presented as 0 %.
    public let averageMastery: Double?

    public init(skill: PracticeSkill, evidencedUnitCount: Int, averageMastery: Double?) {
        self.skill = skill
        self.evidencedUnitCount = evidencedUnitCount
        self.averageMastery = averageMastery
    }

    public var hasEvidence: Bool { averageMastery != nil }
}

public enum PracticeProgressCalculator {
    /// Averages only units with independent evidence; units that were merely
    /// prepared, skipped, revealed, or left ungraded do not lower the mean.
    public static func summarize(skill: PracticeSkill, units: [PracticeUnitProgress]) -> PracticeSkillProgress {
        let scores = units.compactMap { entry -> Double? in
            guard entry.unit.skill == skill,
                  let projection = entry.projection,
                  projection.independentEvidenceCount > 0,
                  let score = projection.score else { return nil }
            return score
        }
        guard !scores.isEmpty else {
            return PracticeSkillProgress(skill: skill, evidencedUnitCount: 0, averageMastery: nil)
        }
        return PracticeSkillProgress(
            skill: skill,
            evidencedUnitCount: scores.count,
            averageMastery: scores.reduce(0, +) / Double(scores.count)
        )
    }

    /// The available skill with the lowest evidenced mastery; skills without
    /// evidence are not treated as weak.
    public static func weakestSkill(_ summaries: [PracticeSkillProgress], available: Set<PracticeSkill>) -> PracticeSkill? {
        summaries
            .filter { available.contains($0.skill) && $0.averageMastery != nil }
            .min { lhs, rhs in
                let left = lhs.averageMastery ?? 1, right = rhs.averageMastery ?? 1
                return left == right ? lhs.skill.rawValue < rhs.skill.rawValue : left < right
            }?
            .skill
    }
}

extension PracticeProgressCalculator {
    /// Summaries for the given skills, limited to review units whose
    /// objective key is in `objectiveKeys[skill]`. A skill without an entry
    /// is not limited (for example, grammar units are not tied to cards).
    public static func summaries(
        skills: [PracticeSkill],
        learnerID: String,
        objectiveKeys: [PracticeSkill: Set<String>],
        reader: any PracticeProgressReading
    ) async throws -> [PracticeSkillProgress] {
        var result: [PracticeSkillProgress] = []
        for skill in skills {
            var units = try await reader.unitProgress(skill: skill, learnerID: learnerID)
            if let keys = objectiveKeys[skill] {
                units = units.filter { keys.contains($0.unit.objectiveKey) }
            }
            result.append(summarize(skill: skill, units: units))
        }
        return result
    }
}
