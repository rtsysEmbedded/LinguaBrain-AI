import Foundation
import LinguaBrainDomain

/// A learner card offered to skill practice, independent of how the app
/// stores cards.
public struct PracticeCardCandidate: Sendable, Equatable {
    public enum ExampleReview: String, Sendable, Equatable {
        /// The example translation was reviewed (built-in content or a card
        /// the learner approved), so it may be used as listening material.
        case reviewed
        /// For example, an imported deck whose examples nobody reviewed.
        case unreviewed
    }

    public let cardID: UUID
    /// Learning-language headword.
    public let targetText: String
    /// Support-language meaning; shown as context, never as a model sentence.
    public let sourceMeaning: String
    public let partOfSpeech: String
    public let cefrLevel: String
    public let exampleTarget: String
    public let exampleSource: String
    public let exampleReview: ExampleReview
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(
        cardID: UUID, targetText: String, sourceMeaning: String, partOfSpeech: String, cefrLevel: String,
        exampleTarget: String, exampleSource: String, exampleReview: ExampleReview,
        sourceLanguage: String, targetLanguage: String
    ) {
        self.cardID = cardID; self.targetText = targetText; self.sourceMeaning = sourceMeaning
        self.partOfSpeech = partOfSpeech; self.cefrLevel = cefrLevel
        self.exampleTarget = exampleTarget; self.exampleSource = exampleSource; self.exampleReview = exampleReview
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
    }

    public var hasReviewedExample: Bool {
        exampleReview == .reviewed
            && !exampleTarget.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !exampleSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Supplies the learner's cards for one directed language pair.
public protocol PracticeCardSource: Sendable {
    func practiceCards(sourceLanguage: String, targetLanguage: String) async throws -> [PracticeCardCandidate]
}

/// A listening exercise and the exact sentence revision it plays.
public struct ListeningExerciseDescriptor: Sendable, Equatable {
    public let exercise: ExerciseInstance
    public let sentence: Sentence

    public init(exercise: ExerciseInstance, sentence: Sentence) {
        self.exercise = exercise
        self.sentence = sentence
    }
}

/// Chooses the exercise ID for the next occurrence of a review unit.
public enum PracticeOccurrence {
    /// An occurrence whose last attempt is still pending (for example, the
    /// app stopped during evaluation or after a reveal) is resumed. Otherwise
    /// the next occurrence receives a new, deterministic ID, so a unit that
    /// comes due again starts with a fresh question.
    public static func exerciseID(for unit: ReviewUnit, attempts: [Attempt]) -> UUID {
        let ordered = attempts.sorted { ($0.submittedAt, $0.attemptIndex, $0.id.uuidString) < ($1.submittedAt, $1.attemptIndex, $1.id.uuidString) }
        if let last = ordered.last, last.outcome == .pending { return last.exerciseID }
        let occurrence = Set(attempts.map(\.exerciseID)).count
        return stableUUID("\(unit.stableKey)|occurrence|\(occurrence)")
    }

    private static func stableUUID(_ value: String) -> UUID {
        var first: UInt64 = 0xcbf29ce484222325
        var second: UInt64 = 0x84222325cbf29ce4
        for byte in value.utf8 {
            first = (first ^ UInt64(byte)) &* 0x100000001b3
            second = (second ^ UInt64(byte)) &* 0x100000001b3
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: first.bigEndian) { for (index, byte) in $0.enumerated() { bytes[index] = byte } }
        withUnsafeBytes(of: second.bigEndian) { for (index, byte) in $0.enumerated() { bytes[8 + index] = byte } }
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

/// Writing exercises built from the learner's own cards (spec US2): the
/// target word, its part of speech, and level, with the support-language
/// meaning as context. Selection is deterministic for a given seed and clock.
public struct CardBackedWritingRetrieval: WritingExerciseRetrieval {
    private let cards: any PracticeCardSource
    private let repository: any PracticeRepository & PracticeProgressReading
    private let clock: any PracticeClock
    private let sourceLanguage: String
    private let targetLanguage: String

    public init(
        cards: any PracticeCardSource,
        repository: any PracticeRepository & PracticeProgressReading,
        clock: any PracticeClock,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        self.cards = cards; self.repository = repository; self.clock = clock
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
    }

    public static func objectiveKey(cardID: UUID) -> String { "writing.card.\(cardID.uuidString.lowercased())" }

    public func nextWritingExercise(learnerID: String, cefrLevel: String, seed: Int) async throws -> WritingExerciseDescriptor? {
        let candidates = try await cards.practiceCards(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            .filter { !$0.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !candidates.isEmpty else { return nil }
        let units = candidates.map { ($0, ReviewUnit(learnerID: learnerID, skill: .writing, objectiveKey: Self.objectiveKey(cardID: $0.cardID))) }
        guard let (card, unit) = try await PracticeCatalogSelection.select(units, skill: .writing, learnerID: learnerID, repository: repository, clock: clock, seed: seed) else { return nil }
        let exercise = ExerciseInstance(
            id: PracticeOccurrence.exerciseID(for: unit, attempts: try await repository.attempts(for: unit)),
            reviewUnit: unit,
            prompt: card.targetText,
            sourceLanguage: card.sourceLanguage,
            targetLanguage: card.targetLanguage
        )
        return WritingExerciseDescriptor(
            exercise: exercise,
            targetWord: card.targetText,
            partOfSpeech: card.partOfSpeech,
            cefrLevel: card.cefrLevel.isEmpty ? cefrLevel : card.cefrLevel,
            allowedContext: card.sourceMeaning
        )
    }
}

/// Listening exercises built from reviewed example sentences of the learner's
/// cards. The sentence revision is stored before the exercise is returned so
/// the review unit can reference it.
public struct CardSentenceListeningRetrieval: Sendable {
    public static let provenanceProvider = "learner-card"

    private let cards: any PracticeCardSource
    private let repository: any PracticeRepository & PracticeProgressReading
    private let clock: any PracticeClock
    private let sourceLanguage: String
    private let targetLanguage: String

    public init(
        cards: any PracticeCardSource,
        repository: any PracticeRepository & PracticeProgressReading,
        clock: any PracticeClock,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        self.cards = cards; self.repository = repository; self.clock = clock
        self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage
    }

    public static func objectiveKey(sentenceID: UUID) -> String { "listening.sentence.\(sentenceID.uuidString.lowercased())" }

    /// The validated sentence revision built from a card's reviewed example.
    public static func sentence(for card: PracticeCardCandidate) -> Sentence {
        Sentence(
            text: card.exampleTarget,
            translation: card.exampleSource,
            validation: .validated,
            provenance: Provenance(provider: provenanceProvider, model: card.cardID.uuidString.lowercased(), generatedAt: Date(timeIntervalSince1970: 0))
        )
    }

    public func hasMaterial() async throws -> Bool {
        try await cards.practiceCards(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage).contains { $0.hasReviewedExample }
    }

    public func nextListeningExercise(learnerID: String, seed: Int) async throws -> ListeningExerciseDescriptor? {
        let candidates = try await cards.practiceCards(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            .filter(\.hasReviewedExample)
        guard !candidates.isEmpty else { return nil }
        let sentences = candidates.map { card in (card, Self.sentence(for: card)) }
        let units = sentences.map { entry in
            (entry, ReviewUnit(
                learnerID: learnerID,
                skill: .listening,
                objectiveKey: Self.objectiveKey(sentenceID: entry.1.id),
                sentenceID: entry.1.id,
                sentenceRevision: entry.1.revision
            ))
        }
        guard let ((card, sentence), unit) = try await PracticeCatalogSelection.select(units, skill: .listening, learnerID: learnerID, repository: repository, clock: clock, seed: seed) else { return nil }
        try await repository.saveSentence(sentence)
        let exercise = ExerciseInstance(
            id: PracticeOccurrence.exerciseID(for: unit, attempts: try await repository.attempts(for: unit)),
            reviewUnit: unit,
            prompt: sentence.text,
            sourceLanguage: card.sourceLanguage,
            targetLanguage: card.targetLanguage
        )
        return ListeningExerciseDescriptor(exercise: exercise, sentence: sentence)
    }
}

enum PracticeCatalogSelection {
    /// Ranks candidate units with `AdaptivePracticePlanner` using their
    /// persisted projections and returns the first one.
    static func select<Item>(
        _ items: [(Item, ReviewUnit)],
        skill: PracticeSkill,
        learnerID: String,
        repository: any PracticeProgressReading,
        clock: any PracticeClock,
        seed: Int
    ) async throws -> (Item, ReviewUnit)? {
        let projections = Dictionary(
            try await repository.unitProgress(skill: skill, learnerID: learnerID).map { ($0.unit.id, $0.projection) },
            uniquingKeysWith: { first, _ in first }
        )
        let plan = AdaptivePracticePlanner.makePlan(
            candidates: items.map { AdaptivePracticeCandidate(reviewUnit: $0.1, projection: (projections[$0.1.id] ?? nil) ?? PracticeMasteryProjection()) },
            now: clock.now(),
            seed: seed,
            limit: 1
        )
        guard let chosen = plan.items.first?.candidate.reviewUnit else { return nil }
        return items.first { $0.1.id == chosen.id }
    }
}

/// The review-unit objective keys the card catalog creates for a set of
/// cards, so progress can be limited to one language pair.
public enum PracticeCatalogKeys {
    public static func objectiveKeys(skill: PracticeSkill, cards: [PracticeCardCandidate]) -> Set<String> {
        switch skill {
        case .writing:
            Set(cards.map { CardBackedWritingRetrieval.objectiveKey(cardID: $0.cardID) })
        case .listening:
            Set(cards.filter(\.hasReviewedExample).map {
                CardSentenceListeningRetrieval.objectiveKey(sentenceID: CardSentenceListeningRetrieval.sentence(for: $0).id)
            })
        case .grammar, .speaking:
            []
        }
    }
}
