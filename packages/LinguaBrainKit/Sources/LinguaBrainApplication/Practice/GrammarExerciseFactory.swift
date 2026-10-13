import Foundation
import LinguaBrainDomain

public enum GrammarExerciseMode: String, Codable, Sendable { case explainError, explainUsage }

public struct GrammarRule: Codable, Equatable, Sendable {
    public let code: String
    public let category: String
    public let targetLanguage: String
    public let grammaticalRole: String
    public init(code: String, category: String, targetLanguage: String, grammaticalRole: String) {
        self.code = code; self.category = category; self.targetLanguage = targetLanguage; self.grammaticalRole = grammaticalRole
    }
}

public struct GrammarExerciseTemplate: Sendable, Equatable {
    public var learnerID: String; public var objectiveKey: String; public var sourceLanguage: String; public var targetLanguage: String
    public var cefrLevel: String; public var mode: GrammarExerciseMode; public var ruleCode: String; public var grammaticalRole: String
    public var prompt: String; public var referenceAnswer: String; public var referenceExplanation: String
    public var demonstration: String?; public var clozeScaffold: String?; public var hints: [String]
    public var cleanSource: String; public var issueCount: Int; public var isAmbiguous: Bool; public var errorSpan: String?
    public init(learnerID: String = "local", objectiveKey: String, sourceLanguage: String, targetLanguage: String, cefrLevel: String,
                mode: GrammarExerciseMode, ruleCode: String, grammaticalRole: String, prompt: String, referenceAnswer: String,
                referenceExplanation: String, demonstration: String? = nil, clozeScaffold: String? = nil, hints: [String] = [],
                cleanSource: String = "curated", issueCount: Int = 1, isAmbiguous: Bool = false, errorSpan: String? = nil) {
        self.learnerID=learnerID; self.objectiveKey=objectiveKey; self.sourceLanguage=sourceLanguage; self.targetLanguage=targetLanguage
        self.cefrLevel=cefrLevel; self.mode=mode; self.ruleCode=ruleCode; self.grammaticalRole=grammaticalRole; self.prompt=prompt
        self.referenceAnswer=referenceAnswer; self.referenceExplanation=referenceExplanation; self.demonstration=demonstration
        self.clozeScaffold=clozeScaffold; self.hints=hints; self.cleanSource=cleanSource; self.issueCount=issueCount
        self.isAmbiguous=isAmbiguous; self.errorSpan=errorSpan
    }
}

public struct GrammarExerciseDescriptor: Codable, Equatable, Sendable {
    public let exercise: ExerciseInstance; public let rule: GrammarRule; public let mode: GrammarExerciseMode
    public let referenceAnswer: String; public let referenceExplanation: String; public let demonstration: String?
    public let clozeScaffold: String?; public let hints: [String]; public let cefrLevel: String; public let cleanSource: String
    public let provenance: Provenance; public let requiresLearnerExplanation: Bool
}

public enum GrammarExerciseFactoryError: Error, Equatable { case unknownRule, invalidLanguage, invalidRole, ambiguous, multipleIssues, emptyContent, dirtySource, duplicateHints, tooManyHints }

public enum GrammarExerciseFactory {
    public static let contractVersion = "grammar-practice-v1"
    /// - Parameter rules: The rule bank by code (from the app's grammar
    ///   content file); a template naming another rule is rejected.
    public static func make(_ input: GrammarExerciseTemplate, rules: [String: GrammarRule]) throws -> GrammarExerciseDescriptor {
        guard let rule = rules[input.ruleCode] else { throw GrammarExerciseFactoryError.unknownRule }
        guard input.targetLanguage == rule.targetLanguage else { throw GrammarExerciseFactoryError.invalidLanguage }
        guard input.grammaticalRole == rule.grammaticalRole else { throw GrammarExerciseFactoryError.invalidRole }
        guard input.cleanSource == "curated" || input.cleanSource == "reviewed_fixture" else { throw GrammarExerciseFactoryError.dirtySource }
        guard !input.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !input.referenceAnswer.isEmpty, !input.referenceExplanation.isEmpty else { throw GrammarExerciseFactoryError.emptyContent }
        guard !input.isAmbiguous else { throw GrammarExerciseFactoryError.ambiguous }
        guard input.issueCount == 1 else { throw GrammarExerciseFactoryError.multipleIssues }
        guard input.hints.count <= 3, Set(input.hints).count == input.hints.count else { throw input.hints.count > 3 ? GrammarExerciseFactoryError.tooManyHints : .duplicateHints }
        let key = [input.learnerID, input.objectiveKey, input.ruleCode, input.mode.rawValue, input.prompt].joined(separator: "|")
        let unit = ReviewUnit(learnerID: input.learnerID, skill: .grammar, objectiveKey: input.objectiveKey)
        let exercise = ExerciseInstance(id: stableUUID(key), reviewUnit: unit, prompt: input.prompt, sourceLanguage: input.sourceLanguage, targetLanguage: input.targetLanguage)
        let provenance = Provenance(provider: "curated", model: "human-reviewed", promptVersion: contractVersion, schemaVersion: contractVersion, validatorVersion: "grammar-factory-v1", generatedAt: Date(timeIntervalSince1970: 0))
        return GrammarExerciseDescriptor(exercise: exercise, rule: rule, mode: input.mode, referenceAnswer: input.referenceAnswer,
            referenceExplanation: input.referenceExplanation, demonstration: input.demonstration, clozeScaffold: input.clozeScaffold,
            hints: input.hints, cefrLevel: input.cefrLevel, cleanSource: input.cleanSource, provenance: provenance, requiresLearnerExplanation: true)
    }

    private static func stableUUID(_ value: String) -> UUID {
        var h: UInt64 = 0xcbf29ce484222325
        for b in value.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        var bytes = [UInt8](repeating: 0, count: 16); withUnsafeBytes(of: h.bigEndian) { raw in for (index, byte) in raw.enumerated() { bytes[index] = byte } }; bytes[6] = (bytes[6] & 15) | 80; bytes[8] = (bytes[8] & 63) | 128
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
}
