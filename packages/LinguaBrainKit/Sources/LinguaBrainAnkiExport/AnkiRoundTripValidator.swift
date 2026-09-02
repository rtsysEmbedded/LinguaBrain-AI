import Foundation
import LinguaBrainDomain

public struct RoundTripComparison: Sendable, Equatable {
    public let areEqual: Bool
    public let textMatches: Bool
    public let senseMatches: Bool
    public let exampleMatches: Bool
    public let directionMatches: Bool
    public let mediaMatches: Bool
    public let tagsMatch: Bool
    public let provenanceMatches: Bool
    public let discrepancies: [Discrepancy]
    public let comparedAt: Date
    
    public init(
        areEqual: Bool = true,
        textMatches: Bool = true,
        senseMatches: Bool = true,
        exampleMatches: Bool = true,
        directionMatches: Bool = true,
        mediaMatches: Bool = true,
        tagsMatch: Bool = true,
        provenanceMatches: Bool = true,
        discrepancies: [Discrepancy] = [],
        comparedAt: Date = Date()
    ) {
        self.areEqual = areEqual
        self.textMatches = textMatches
        self.senseMatches = senseMatches
        self.exampleMatches = exampleMatches
        self.directionMatches = directionMatches
        self.mediaMatches = mediaMatches
        self.tagsMatch = tagsMatch
        self.provenanceMatches = provenanceMatches
        self.discrepancies = discrepancies
        self.comparedAt = comparedAt
    }
}

public struct Discrepancy: Sendable, Equatable, Identifiable {
    public let id = UUID()
    public let field: String
    public let expected: String
    public let actual: String?
    public let severity: DiscrepancySeverity
    
    public enum DiscrepancySeverity: String, Sendable, Equatable {
        case critical
        case error
        case warning
        case info
    }
    
    public init(
        field: String,
        expected: String,
        actual: String? = nil,
        severity: DiscrepancySeverity = .error
    ) {
        self.field = field
        self.expected = expected
        self.actual = actual
        self.severity = severity
    }
}

public final class AnkiRoundTripValidator: Sendable {
    public static let shared = AnkiRoundTripValidator()
    
    public init() {}
    
    public func compare(
        original: AnkiRoundTripData,
        imported: AnkiRoundTripData
    ) -> RoundTripComparison {
        var discrepancies: [Discrepancy] = []
        
        let textMatches = compareTexts(original: original, imported: imported)
        if !textMatches {
            discrepancies.append(Discrepancy(
                field: "text",
                expected: "text match",
                actual: "text mismatch"
            ))
        }
        
        let senseMatches = compareSenses(original: original, imported: imported)
        if !senseMatches {
            discrepancies.append(Discrepancy(
                field: "sense",
                expected: "sense match",
                actual: "sense mismatch",
                severity: .warning
            ))
        }
        
        let exampleMatches = compareExamples(original: original, imported: imported)
        if !exampleMatches {
            discrepancies.append(Discrepancy(
                field: "example",
                expected: "example match",
                actual: "example mismatch",
                severity: .warning
            ))
        }
        
        let directionMatches = compareDirections(original: original, imported: imported)
        if !directionMatches {
            discrepancies.append(Discrepancy(
                field: "direction",
                expected: "direction match",
                actual: "direction mismatch",
                severity: .warning
            ))
        }
        
        let mediaMatches = compareMedia(original: original, imported: imported)
        if !mediaMatches {
            discrepancies.append(Discrepancy(
                field: "media",
                expected: "media match",
                actual: "media mismatch",
                severity: .warning
            ))
        }
        
        let tagsMatch = compareTags(original: original, imported: imported)
        if !tagsMatch {
            discrepancies.append(Discrepancy(
                field: "tags",
                expected: "tags match",
                actual: "tags mismatch",
                severity: .warning
            ))
        }
        
        let provenanceMatches = compareProvenance(original: original, imported: imported)
        if !provenanceMatches {
            discrepancies.append(Discrepancy(
                field: "provenance",
                expected: "provenance match",
                actual: "provenance mismatch",
                severity: .info
            ))
        }
        
        let areEqual = discrepancies.isEmpty
        
        return RoundTripComparison(
            areEqual: areEqual,
            textMatches: textMatches,
            senseMatches: senseMatches,
            exampleMatches: exampleMatches,
            directionMatches: directionMatches,
            mediaMatches: mediaMatches,
            tagsMatch: tagsMatch,
            provenanceMatches: provenanceMatches,
            discrepancies: discrepancies
        )
    }
    
    private func compareTexts(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        let originalFields = Set(original.notes.flatMap { $0.fields })
        let importedFields = Set(imported.notes.flatMap { $0.fields })
        
        for origField in originalFields {
            let normalizedOrig = normalizeText(origField)
            let found = importedFields.contains { normalizeText($0) == normalizedOrig }
            if !found {
                return false
            }
        }
        
        return true
    }
    
    private func compareSenses(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        guard original.notes.count == imported.notes.count,
              original.cards.count == imported.cards.count else { return false }
        let originalModels = Set(original.models.map { "\($0.modelID)|\($0.name)|\($0.fieldNames.joined(separator: "\u{1f}"))" })
        let importedModels = Set(imported.models.map { "\($0.modelID)|\($0.name)|\($0.fieldNames.joined(separator: "\u{1f}"))" })
        return originalModels == importedModels
    }
    
    private func compareExamples(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        let originalExamples = original.notes.map { $0.fields.map(normalizeText) }
        let importedExamples = imported.notes.map { $0.fields.map(normalizeText) }
        return originalExamples == importedExamples
    }
    
    private func compareDirections(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        let originalCards = original.cards.map { "\($0.cardID)|\($0.noteID)|\($0.deckID)|\($0.queue)" }
        let importedCards = imported.cards.map { "\($0.cardID)|\($0.noteID)|\($0.deckID)|\($0.queue)" }
        return originalCards == importedCards
    }
    
    private func compareMedia(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        let originalCount = original.mediaManifest?.entries.count ?? 0
        let importedCount = imported.mediaManifest?.entries.count ?? 0
        
        if originalCount != importedCount {
            return false
        }
        
        return true
    }
    
    private func compareTags(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        let originalTags = Set(original.tags.map { $0.tag })
        let importedTags = Set(imported.tags.map { $0.tag })
        
        for tag in originalTags where !importedTags.contains(tag) {
            return false
        }
        
        return true
    }
    
    private func compareProvenance(original: AnkiRoundTripData, imported: AnkiRoundTripData) -> Bool {
        let originalPolicy = original.exportManifest?.schedulingPolicy
        let importedPolicy = imported.exportManifest?.schedulingPolicy
        
        if originalPolicy == nil && importedPolicy == nil {
            return true
        }
        
        return originalPolicy == importedPolicy
    }
    
    public func compareRtlLtr(text: String) -> Bool {
        var rtlChars = CharacterSet()
        for i in 0x0600...0x06FF { if let scalar = UnicodeScalar(i) { rtlChars.insert(scalar) } }
        for i in 0x0750...0x077F { if let scalar = UnicodeScalar(i) { rtlChars.insert(scalar) } }
        for i in 0x08A0...0x08FF { if let scalar = UnicodeScalar(i) { rtlChars.insert(scalar) } }
        for i in 0xFB50...0xFDFF { if let scalar = UnicodeScalar(i) { rtlChars.insert(scalar) } }
        for i in 0xFE70...0xFEFF { if let scalar = UnicodeScalar(i) { rtlChars.insert(scalar) } }
        
        let hasRtl = text.rangeOfCharacter(from: rtlChars) != nil
        return hasRtl || text.isEmpty
    }
    
    public func normalizeUnicode(_ text: String) -> String {
        return text.precomposedStringWithCanonicalMapping
        .folding(options: .diacriticInsensitive, locale: .current)
    }
    
    private func normalizeText(_ text: String) -> String {
        return text
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public func generateReport(for comparison: RoundTripComparison) -> String {
        var report = "Round-Trip Validation Report\n"
        report += "============================\n"
        report += "Status: \(comparison.areEqual ? "PASSED" : "FAILED")\n\n"
        
        report += "Field Checks:\n"
        report += "- Text: \(comparison.textMatches ? "✓ PASS" : "✗ FAIL")\n"
        report += "- Sense: \(comparison.senseMatches ? "✓ PASS" : "✗ FAIL")\n"
        report += "- Examples: \(comparison.exampleMatches ? "✓ PASS" : "✗ FAIL")\n"
        report += "- Direction: \(comparison.directionMatches ? "✓ PASS" : "✗ FAIL")\n"
        report += "- Media: \(comparison.mediaMatches ? "✓ PASS" : "✗ FAIL")\n"
        report += "- Tags: \(comparison.tagsMatch ? "✓ PASS" : "✗ FAIL")\n"
        report += "- Provenance: \(comparison.provenanceMatches ? "✓ PASS" : "⚠ WARN")\n\n"
        
        if !comparison.discrepancies.isEmpty {
            report += "Discrepancies:\n"
            for disc in comparison.discrepancies {
                report += "- [\(disc.severity.rawValue.uppercased())] \(disc.field): expected '\(disc.expected)'"
                if let actual = disc.actual {
                    report += ", got '\(actual)'"
                }
                report += "\n"
            }
        }
        
        return report
    }
}
