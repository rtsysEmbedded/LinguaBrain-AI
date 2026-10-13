import Foundation
import LinguaBrainDomain

/// Review state of a grammar exercise. Only `reviewed` content is curated;
/// drafts are rejected by `GrammarExerciseFactory` and never shown.
public enum GrammarReviewStatus: String, Codable, Sendable, Equatable {
    case pendingReview
    case reviewed
}

/// One grammar exercise as stored in the app's content file.
public struct GrammarTemplateEntry: Codable, Sendable, Equatable {
    public let id: String
    public let reviewStatus: GrammarReviewStatus
    /// Who drafted the entry (for example `assistant` or a teacher's name).
    public let draftedBy: String?
    /// Who reviewed it and when (ISO 8601 date); required for `reviewed`.
    public let reviewedBy: String?
    public let reviewedAt: String?
    public let sourceLanguage: String
    public let targetLanguage: String
    public let cefrLevel: String
    public let mode: GrammarExerciseMode
    public let ruleCode: String
    public let grammaticalRole: String
    public let prompt: String
    public let referenceAnswer: String
    public let referenceExplanation: String
    public let demonstration: String?
    public let clozeScaffold: String?
    public let hints: [String]
    public let errorSpan: String?
    public let issueCount: Int
    public let isAmbiguous: Bool

    public init(
        id: String, reviewStatus: GrammarReviewStatus, draftedBy: String? = nil, reviewedBy: String? = nil, reviewedAt: String? = nil,
        sourceLanguage: String, targetLanguage: String, cefrLevel: String, mode: GrammarExerciseMode, ruleCode: String,
        grammaticalRole: String, prompt: String, referenceAnswer: String, referenceExplanation: String,
        demonstration: String? = nil, clozeScaffold: String? = nil, hints: [String] = [], errorSpan: String? = nil,
        issueCount: Int = 1, isAmbiguous: Bool = false
    ) {
        self.id = id; self.reviewStatus = reviewStatus; self.draftedBy = draftedBy; self.reviewedBy = reviewedBy; self.reviewedAt = reviewedAt
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage; self.cefrLevel = cefrLevel; self.mode = mode
        self.ruleCode = ruleCode; self.grammaticalRole = grammaticalRole; self.prompt = prompt; self.referenceAnswer = referenceAnswer
        self.referenceExplanation = referenceExplanation; self.demonstration = demonstration; self.clozeScaffold = clozeScaffold
        self.hints = hints; self.errorSpan = errorSpan; self.issueCount = issueCount; self.isAmbiguous = isAmbiguous
    }

    /// Review-unit objective key; stable as long as `id` does not change.
    public var objectiveKey: String { "grammar.\(id)" }

    /// A reviewed entry with a named reviewer and date is curated; anything
    /// else is a draft.
    public var isCurated: Bool {
        reviewStatus == .reviewed
            && !(reviewedBy ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !(reviewedAt ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func template(learnerID: String) -> GrammarExerciseTemplate {
        GrammarExerciseTemplate(
            learnerID: learnerID, objectiveKey: objectiveKey, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage,
            cefrLevel: cefrLevel, mode: mode, ruleCode: ruleCode, grammaticalRole: grammaticalRole, prompt: prompt,
            referenceAnswer: referenceAnswer, referenceExplanation: referenceExplanation, demonstration: demonstration,
            clozeScaffold: clozeScaffold, hints: hints, cleanSource: isCurated ? "curated" : "draft",
            issueCount: issueCount, isAmbiguous: isAmbiguous, errorSpan: errorSpan
        )
    }
}

/// Grammar rules and exercises, decoded from the app's content file.
public struct GrammarContentCatalog: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let rules: [GrammarRule]
    public let templates: [GrammarTemplateEntry]

    public init(schemaVersion: Int = 1, rules: [GrammarRule], templates: [GrammarTemplateEntry]) {
        self.schemaVersion = schemaVersion; self.rules = rules; self.templates = templates
    }

    public var ruleIndex: [String: GrammarRule] {
        Dictionary(rules.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Curated exercises for one language pair that pass the factory checks.
    public func descriptors(learnerID: String, sourceLanguage: String, targetLanguage: String) -> [(entry: GrammarTemplateEntry, descriptor: GrammarExerciseDescriptor)] {
        let rules = ruleIndex
        return templates
            .filter { $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage && $0.isCurated }
            .compactMap { entry in
                (try? GrammarExerciseFactory.make(entry.template(learnerID: learnerID), rules: rules)).map { (entry, $0) }
            }
    }

    public func hasReviewedContent(learnerID: String, sourceLanguage: String, targetLanguage: String) -> Bool {
        !descriptors(learnerID: learnerID, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage).isEmpty
    }

    public func objectiveKeys(learnerID: String, sourceLanguage: String, targetLanguage: String) -> Set<String> {
        Set(descriptors(learnerID: learnerID, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage).map(\.entry.objectiveKey))
    }

    /// The curated entry for a review unit, if any.
    public func curatedEntry(objectiveKey: String) -> GrammarTemplateEntry? {
        templates.first { $0.objectiveKey == objectiveKey && $0.isCurated }
    }
}

/// Grammar exercises from reviewed content, ordered by
/// `AdaptivePracticePlanner`. Each new occurrence gets a new exercise ID.
public struct CuratedGrammarRetrieval: Sendable {
    private let catalog: GrammarContentCatalog
    private let repository: any PracticeRepository & PracticeProgressReading
    private let clock: any PracticeClock
    private let sourceLanguage: String
    private let targetLanguage: String

    public init(
        catalog: GrammarContentCatalog,
        repository: any PracticeRepository & PracticeProgressReading,
        clock: any PracticeClock,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        self.catalog = catalog; self.repository = repository; self.clock = clock
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
    }

    public func nextGrammarExercise(learnerID: String, seed: Int) async throws -> GrammarExerciseDescriptor? {
        let candidates = catalog.descriptors(learnerID: learnerID, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
        guard !candidates.isEmpty else { return nil }
        let items = candidates.map { ($0.descriptor, $0.descriptor.exercise.reviewUnit) }
        guard let (descriptor, unit) = try await PracticeCatalogSelection.select(items, skill: .grammar, learnerID: learnerID, repository: repository, clock: clock, seed: seed) else {
            return nil
        }
        let id = PracticeOccurrence.exerciseID(for: unit, attempts: try await repository.attempts(for: unit))
        return descriptor.replacingExerciseID(id)
    }
}

extension GrammarExerciseDescriptor {
    func replacingExerciseID(_ id: UUID) -> GrammarExerciseDescriptor {
        GrammarExerciseDescriptor(
            exercise: ExerciseInstance(id: id, reviewUnit: exercise.reviewUnit, prompt: exercise.prompt, sourceLanguage: exercise.sourceLanguage, targetLanguage: exercise.targetLanguage),
            rule: rule, mode: mode, referenceAnswer: referenceAnswer, referenceExplanation: referenceExplanation,
            demonstration: demonstration, clozeScaffold: clozeScaffold, hints: hints, cefrLevel: cefrLevel,
            cleanSource: cleanSource, provenance: provenance, requiresLearnerExplanation: requiresLearnerExplanation
        )
    }
}
