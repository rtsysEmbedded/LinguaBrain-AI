import Foundation
import LinguaBrainDomain

public enum SchedulingCompatibilityStatus: String, Sendable, Equatable, Codable {
    case preserved
    case mappedLossily
    case freshAnki
    case unsupported
    
    public var description: String {
        switch self {
        case .preserved:
            return "Preserved"
        case .mappedLossily:
            return "Mapped Lossily"
        case .freshAnki:
            return "Fresh Anki Default"
        case .unsupported:
            return "Unsupported"
        }
    }
}

public struct SchedulingCompatibilityWarning: Sendable, Equatable {
    public let field: String
    public let reason: String
    public let recommendation: String
    
    public init(field: String, reason: String, recommendation: String) {
        self.field = field
        self.reason = reason
        self.recommendation = recommendation
    }
}

public struct SchedulingCompatibilityReport: Sendable, Equatable {
    public let status: SchedulingCompatibilityStatus
    public let warnings: [SchedulingCompatibilityWarning]
    public let preservedFields: [String]
    public let lostFields: [String]
    
    public init(
        status: SchedulingCompatibilityStatus,
        warnings: [SchedulingCompatibilityWarning] = [],
        preservedFields: [String] = [],
        lostFields: [String] = []
    ) {
        self.status = status
        self.warnings = warnings
        self.preservedFields = preservedFields
        self.lostFields = lostFields
    }
}

public final class AnkiSchedulingCompatibility: Sendable {
    public static let shared = AnkiSchedulingCompatibility()
    
    private init() {}
    
    public func analyze(hermesCard: GeneratedCardBundle) -> SchedulingCompatibilityReport {
        var warnings: [SchedulingCompatibilityWarning] = []
        var preservedFields: [String] = []
        var lostFields: [String] = []
        
        _ = [
            "queue", "reps", "lapses", "ease", "due", "ivl", "factor", "rtime", "time"
        ]
        
        _ = ["fsrs", "mastery_level", "review_count", "last_reviewed"]
        
        if hermesCard.identity.direction == .recall {
            preservedFields.append(contentsOf: ["queue", "reps", "due"])
        } else {
            preservedFields.append(contentsOf: ["queue", "reps"])
        }
        
        if hermesCard.senses.contains(where: { $0.examples.isEmpty }) {
            warnings.append(SchedulingCompatibilityWarning(
                field: "examples",
                reason: "Few or no examples may indicate limited scheduling data",
                recommendation: "Export with fresh Anki scheduling"
            ))
        }
        
        let hasFsrTags = hermesCard.provenance.model.contains("fsrs") || hermesCard.provenance.model.contains("FSRS")
        if hasFsrTags {
            lostFields.append(contentsOf: ["fsrs_state", "stable_scheduling"])
            warnings.append(SchedulingCompatibilityWarning(
                field: "FSRS",
                reason: "FSRS scheduling is not directly representable in Anki schema 18/anki21",
                recommendation: "Using fresh Anki scheduling with documented limitation"
            ))
        }
        
        if !hermesCard.mediaAssets.isEmpty {
            preservedFields.append("media_scheduled")
        }
        
        let status: SchedulingCompatibilityStatus
        if lostFields.isEmpty && !hasFsrTags {
            status = .preserved
        } else if hasFsrTags {
            status = .freshAnki
        } else {
            status = .mappedLossily
        }
        
        return SchedulingCompatibilityReport(
            status: status,
            warnings: warnings,
            preservedFields: preservedFields,
            lostFields: lostFields
        )
    }
    
    public func analyzeMultiple(cards: [GeneratedCardBundle]) -> SchedulingCompatibilityReport {
        let allReports = cards.map { analyze(hermesCard: $0) }
        
        let hasAnyFsr = allReports.contains { !$0.lostFields.isEmpty }
        let allWarnings = allReports.flatMap { $0.warnings }
        let allPreserved = allReports.flatMap { $0.preservedFields }.removingDuplicates()
        let allLost = allReports.flatMap { $0.lostFields }.removingDuplicates()
        
        let status: SchedulingCompatibilityStatus
        if hasAnyFsr {
            status = .freshAnki
        } else if allLost.isEmpty {
            status = .preserved
        } else {
            status = .mappedLossily
        }
        
        return SchedulingCompatibilityReport(
            status: status,
            warnings: allWarnings,
            preservedFields: allPreserved,
            lostFields: allLost
        )
    }
    
    public func generateManifestEntry(for card: GeneratedCardBundle) -> [String: String] {
        let report = analyze(hermesCard: card)
        
        var entry: [String: String] = [:]
        
        if report.status == .freshAnki {
            entry["scheduling_compatibility"] = "fresh_anki"
            entry["warning"] = "Hermes FSRS/mastery not preserved; using fresh Anki scheduling"
        } else {
            entry["scheduling_compatibility"] = report.status.rawValue
        }
        
        if !report.preservedFields.isEmpty {
            entry["preserved_fields"] = report.preservedFields.joined(separator: ",")
        }
        
        if !report.lostFields.isEmpty {
            entry["lost_fields"] = report.lostFields.joined(separator: ",")
        }
        
        return entry
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}