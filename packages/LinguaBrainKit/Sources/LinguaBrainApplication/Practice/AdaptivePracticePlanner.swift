import Foundation
import LinguaBrainDomain

public enum AdaptivePracticeReason: String, Codable, Sendable, Equatable {
    case overdue
    case unknownObjective
    case weakMastery
    case linkedError
    case freshContext
}

public struct AdaptivePracticeCandidate: Codable, Sendable, Equatable {
    public let reviewUnit: ReviewUnit
    public let projection: PracticeMasteryProjection
    public let ruleIDs: [String]
    public let capabilityAvailable: Bool
    public let recentlyAttempted: Bool
    public let sentence: Sentence?

    public init(reviewUnit: ReviewUnit, projection: PracticeMasteryProjection = PracticeMasteryProjection(), ruleIDs: [String] = [], capabilityAvailable: Bool = true, recentlyAttempted: Bool = false, sentence: Sentence? = nil) {
        self.reviewUnit = reviewUnit; self.projection = projection; self.ruleIDs = ruleIDs; self.capabilityAvailable = capabilityAvailable; self.recentlyAttempted = recentlyAttempted; self.sentence = sentence
    }
}

public struct AdaptivePracticePlanItem: Codable, Sendable, Equatable {
    public let candidate: AdaptivePracticeCandidate
    public let reason: AdaptivePracticeReason
    public let score: Int

    public init(candidate: AdaptivePracticeCandidate, reason: AdaptivePracticeReason, score: Int) { self.candidate = candidate; self.reason = reason; self.score = score }
}

public struct AdaptivePracticePlan: Codable, Sendable, Equatable {
    public let items: [AdaptivePracticePlanItem]
    public let seed: Int

    public init(items: [AdaptivePracticePlanItem], seed: Int) { self.items = items; self.seed = seed }
    public var isEmpty: Bool { items.isEmpty }
}

/// Pure deterministic selection for future practice. It consumes projections
/// and accepted sentence revisions but never changes mastery or schedules.
public enum AdaptivePracticePlanner {
    public static let allowedRuleIDs: Set<String> = ["de.word_order.verb_final", "de.verb.separable", "de.verb.inflection", "de.lexical.target_missing", "de.lexical.unrelated", "meaning.intent_uncertain", "style.naturalness"]

    public static func makePlan(candidates: [AdaptivePracticeCandidate], now: Date, seed: Int, limit: Int) -> AdaptivePracticePlan {
        let eligible = candidates.filter { $0.capabilityAvailable && !$0.recentlyAttempted }
        let ranked = eligible.map { candidate -> AdaptivePracticePlanItem in
            let validRules = candidate.ruleIDs.filter { allowedRuleIDs.contains($0) }
            let overdue = candidate.projection.dueAt.map { $0 <= now } ?? false
            let reason: AdaptivePracticeReason = overdue ? .overdue : candidate.projection.state == .unknown ? .unknownObjective : !validRules.isEmpty ? .linkedError : candidate.sentence != nil ? .freshContext : .weakMastery
            let score = (overdue ? 1_000 : 0) + (candidate.projection.state == .unknown ? 500 : 0) + Int(((1 - (candidate.projection.score ?? 0)) * 100).rounded()) + (validRules.isEmpty ? 0 : 50)
            return AdaptivePracticePlanItem(candidate: candidate, reason: reason, score: score)
        }.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            let lhs = stableHash($0.candidate.reviewUnit.stableKey) ^ UInt64(bitPattern: Int64(seed))
            let rhs = stableHash($1.candidate.reviewUnit.stableKey) ^ UInt64(bitPattern: Int64(seed))
            if lhs != rhs { return lhs < rhs }
            return $0.candidate.reviewUnit.id.uuidString < $1.candidate.reviewUnit.id.uuidString
        }
        return AdaptivePracticePlan(items: Array(ranked.prefix(max(0, limit))), seed: seed)
    }

    private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(0xcbf29ce484222325) { ($0 ^ UInt64($1)) &* 0x100000001b3 }
    }
}
