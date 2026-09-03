import Foundation
import Observation
import SwiftData
import SwiftUI

struct PrototypeExample: Codable, Hashable, Sendable {
    let target: String
    let source: String
}

/// Provider-produced meaning data that must survive beyond the generation
/// preview.  It is deliberately independent of a particular AI provider.
struct PrototypeSense: Codable, Hashable, Sendable {
    let meaning: String
    let usage: String
    let example: PrototypeExample
    let collocations: [String]
}

enum PrototypeExamplePairing {
    static func pair(target: String, source: String) -> [PrototypeExample] {
        let targets = split(target)
        let sources = split(source)
        return zip(targets, sources).map { PrototypeExample(target: $0.0, source: $0.1) }
    }

    private static func split(_ value: String) -> [String] {
        value.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

@Model
final class PrototypeDeckRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

/// A single generated pronunciation or illustration may be used by several
/// cards when one headword has genuinely independent meanings.  Keeping it in
/// its own record makes that ownership explicit instead of duplicating a blob
/// per card.
@Model
final class PrototypeMediaAssetRecord {
    @Attribute(.unique) var id: UUID
    var kind: String
    @Attribute(.externalStorage) var data: Data
    var filename: String

    init(id: UUID = UUID(), kind: String, data: Data, filename: String) {
        self.id = id
        self.kind = kind
        self.data = data
        self.filename = filename
    }
}

@Model
final class PrototypeCardRecord {
    @Attribute(.unique) var id: UUID
    var deckID: UUID
    var position: Int
    var german: String
    var persian: String
    var article: String?
    var level: String
    var partOfSpeech: String
    var example: String
    var exampleTranslation: String
    var examplesJSON: String = "[]"
    var sensesJSON: String = "[]"
    var domain: String = "عمومی"
    var createdAt: Date
    var sourceIdentifier: String?
    var sourcePackage: String?
    var sourceLanguageTag: String = "fa"
    var targetLanguageTag: String = "de"
    @Attribute(.externalStorage) var pronunciationAudio: Data?
    var pronunciationAudioFilename: String?
    var pronunciationAudioAssetID: UUID?
    @Attribute(.externalStorage) var illustrationImage: Data?
    var illustrationImageFilename: String?
    var illustrationImageAssetID: UUID?

    init(
        word: PrototypeWord,
        deckID: UUID,
        position: Int,
        createdAt: Date = .now,
        sourceIdentifier: String? = nil,
        sourcePackage: String? = nil,
        pronunciationAudio: Data? = nil,
        pronunciationAudioFilename: String? = nil,
        pronunciationAudioAssetID: UUID? = nil,
        illustrationImage: Data? = nil,
        illustrationImageFilename: String? = nil,
        illustrationImageAssetID: UUID? = nil
    ) {
        id = word.id
        self.deckID = deckID
        self.position = position
        german = word.german
        persian = word.persian
        article = word.article
        level = word.level
        partOfSpeech = word.partOfSpeech
        example = word.example
        exampleTranslation = word.exampleTranslation
        examplesJSON = (try? String(data: JSONEncoder().encode(word.examples), encoding: .utf8)) ?? "[]"
        sensesJSON = (try? String(data: JSONEncoder().encode(word.senses), encoding: .utf8)) ?? "[]"
        domain = word.domain
        self.createdAt = createdAt
        self.sourceIdentifier = sourceIdentifier
        self.sourcePackage = sourcePackage
        sourceLanguageTag = word.sourceLanguageTag
        targetLanguageTag = word.targetLanguageTag
        self.pronunciationAudio = pronunciationAudio
        self.pronunciationAudioFilename = pronunciationAudioFilename
        self.pronunciationAudioAssetID = pronunciationAudioAssetID
        self.illustrationImage = illustrationImage
        self.illustrationImageFilename = illustrationImageFilename
        self.illustrationImageAssetID = illustrationImageAssetID
    }

    var word: PrototypeWord {
        PrototypeWord(
            id: id,
            german: german,
            persian: persian,
            article: article,
            level: level,
            partOfSpeech: partOfSpeech,
            example: example,
            exampleTranslation: exampleTranslation,
            examples: (try? JSONDecoder().decode([PrototypeExample].self, from: Data(examplesJSON.utf8))) ?? [],
            senses: (try? JSONDecoder().decode([PrototypeSense].self, from: Data(sensesJSON.utf8))) ?? [],
            domain: domain,
            sourceLanguageTag: sourceLanguageTag,
            targetLanguageTag: targetLanguageTag
        )
    }
}

@Model
final class PrototypeReviewRecord {
    @Attribute(.unique) var id: UUID
    var wordKey: String
    var gradeRawValue: String
    var reviewedAt: Date
    var dueAt: Date
    var stability: Double = 0
    var difficulty: Double = 0
    var phaseRawValue: String = "new"
    var learningStep: Int = 0
    var scheduledDays: Double = 0
    var elapsedDays: Double = 0
    var algorithmVersion: String = "fixed-v0"

    init(
        id: UUID = UUID(),
        wordKey: String,
        gradeRawValue: String,
        reviewedAt: Date,
        dueAt: Date,
        stability: Double,
        difficulty: Double,
        phaseRawValue: String,
        learningStep: Int,
        scheduledDays: Double,
        elapsedDays: Double,
        algorithmVersion: String
    ) {
        self.id = id
        self.wordKey = wordKey
        self.gradeRawValue = gradeRawValue
        self.reviewedAt = reviewedAt
        self.dueAt = dueAt
        self.stability = stability
        self.difficulty = difficulty
        self.phaseRawValue = phaseRawValue
        self.learningStep = learningStep
        self.scheduledDays = scheduledDays
        self.elapsedDays = elapsedDays
        self.algorithmVersion = algorithmVersion
    }
}

@Model
final class PrototypeSkillMasteryRecord {
    @Attribute(.unique) var id: String
    var cardID: UUID
    var skillRawValue: String
    var score: Double
    var attempts: Int
    var correct: Int
    var lastUpdated: Date?

    init(cardID: UUID, skillRawValue: String, score: Double = 0, attempts: Int = 0, correct: Int = 0, lastUpdated: Date? = nil) {
        self.id = "(cardID.uuidString)::(skillRawValue)"
        self.cardID = cardID
        self.skillRawValue = skillRawValue
        self.score = score
        self.attempts = attempts
        self.correct = correct
        self.lastUpdated = lastUpdated
    }
}

@Model
final class PrototypeLearningEventRecord {
    @Attribute(.unique) var id: UUID
    var cardID: UUID
    var skillRawValue: String
    var correct: Bool
    var occurredAt: Date
    var responseTimeMilliseconds: Int?

    init(cardID: UUID, skillRawValue: String, correct: Bool, occurredAt: Date, responseTimeMilliseconds: Int? = nil) {
        self.id = UUID()
        self.cardID = cardID
        self.skillRawValue = skillRawValue
        self.correct = correct
        self.occurredAt = occurredAt
        self.responseTimeMilliseconds = responseTimeMilliseconds
    }
}

@Model
final class PrototypeLearningMissionRecord {
    @Attribute(.unique) var id: String
    var title: String
    var domain: String?
    var targetLevel: String?
    var weight: Double
    var isActive: Bool
    var updatedAt: Date

    init(id: String = "active", title: String, domain: String? = nil, targetLevel: String? = nil, weight: Double = 1, isActive: Bool = true, updatedAt: Date = .now) {
        self.id = id; self.title = title; self.domain = domain; self.targetLevel = targetLevel
        self.weight = min(max(weight, 0), 1); self.isActive = isActive; self.updatedAt = updatedAt
    }
}

enum PrototypeFSRSPhase: String, Codable {
    case new, learning, review, relearning
}

struct PrototypeFSRSMemoryState: Equatable {
    var stability: Double
    var difficulty: Double
    var phase: PrototypeFSRSPhase
    var learningStep: Int
    var lastReview: Date
}

struct PrototypeFSRSSchedule: Equatable {
    let state: PrototypeFSRSMemoryState
    let dueAt: Date
    let scheduledDays: Double
    let elapsedDays: Double
    let isShortTerm: Bool

    var intervalLabel: String {
        let seconds = max(0, dueAt.timeIntervalSince(state.lastReview))
        if seconds < 60 { return "کمتر از ۱ دقیقه" }
        if seconds < 3_600 { return "\(Int((seconds / 60).rounded())) دقیقه" }
        if seconds < 86_400 { return "\(Int((seconds / 3_600).rounded())) ساعت" }
        return "\(Int((seconds / 86_400).rounded())) روز"
    }
}

/// Deterministic FSRS-6 scheduler using the canonical 21 default parameters.
/// Formulas and defaults follow open-spaced-repetition/swift-fsrs FSRS-6.0.
struct PrototypeFSRS6Scheduler {
    static let version = "FSRS-6.0/default-21"
    static let desiredRetention = 0.9

    private let w: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133,
        0.8334, 3.0194, 0.001, 1.8722, 0.1666,
        0.796, 1.4835, 0.0614, 0.2629, 1.6483,
        0.6014, 1.8729, 0.5425, 0.0912, 0.0658,
        0.1542
    ]

    static func passesReferenceVectors() -> Bool {
        let scheduler = Self()
        let now = Date(timeIntervalSince1970: 1_672_315_800)
        let expectedStability = [0.212, 1.2931, 2.3065, 8.2956]
        let expectedDifficulty = [6.4133, 5.11217071, 2.11810397, 1.0]

        let firstReviewMatches = zip(PrototypeReviewGrade.allCases.indices, PrototypeReviewGrade.allCases).allSatisfy { index, grade in
            let result = scheduler.schedule(previous: nil, grade: grade, now: now)
            return abs(result.state.stability - expectedStability[index]) < 0.0000001
                && abs(result.state.difficulty - expectedDifficulty[index]) < 0.0000001
        }

        let ratings: [PrototypeReviewGrade] = [
            .good, .good, .good, .good, .good, .good,
            .again, .again, .good, .good, .good, .good, .good
        ]
        var state: PrototypeFSRSMemoryState?
        var reviewDate = now
        var intervals: [Int] = []
        for rating in ratings {
            let result = scheduler.schedule(previous: state, grade: rating, now: reviewDate)
            intervals.append(Int(result.scheduledDays))
            state = result.state
            reviewDate = result.dueAt
        }

        return firstReviewMatches
            && intervals == [0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21]
    }

    func schedule(
        previous: PrototypeFSRSMemoryState?,
        grade: PrototypeReviewGrade,
        now: Date
    ) -> PrototypeFSRSSchedule {
        let elapsedDays = previous.map {
            calendarDayDifference(from: $0.lastReview, to: now)
        } ?? 0
        let nextMemory = nextMemoryState(previous: previous, elapsedDays: elapsedDays, grade: grade)
        let timing = nextTiming(previousPhase: previous?.phase ?? .new, previousStep: previous?.learningStep ?? 0, grade: grade, stability: nextMemory.stability)
        let dueAt = now.addingTimeInterval(timing.seconds)
        let state = PrototypeFSRSMemoryState(
            stability: nextMemory.stability,
            difficulty: nextMemory.difficulty,
            phase: timing.phase,
            learningStep: timing.learningStep,
            lastReview: now
        )
        return PrototypeFSRSSchedule(
            state: state,
            dueAt: dueAt,
            scheduledDays: timing.seconds / 86_400,
            elapsedDays: elapsedDays,
            isShortTerm: timing.seconds < 86_400
        )
    }

    func retrievability(state: PrototypeFSRSMemoryState, at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(state.lastReview) / 86_400)
        return forgettingCurve(elapsedDays: elapsed, stability: state.stability)
    }

    private func nextMemoryState(
        previous: PrototypeFSRSMemoryState?,
        elapsedDays: Double,
        grade: PrototypeReviewGrade
    ) -> (stability: Double, difficulty: Double) {
        guard let previous, previous.stability >= 0.001, previous.difficulty >= 1 else {
            return (initialStability(grade), initialDifficulty(grade))
        }

        let rating = Double(grade.fsrsRating)
        let retrievability = forgettingCurve(elapsedDays: elapsedDays, stability: previous.stability)
        let difficulty = nextDifficulty(previous.difficulty, grade: grade)
        // FSRS-6 treats all reviews in the same UTC calendar day as t = 0.
        let shortTerm = elapsedDays == 0
        let stability: Double

        if shortTerm {
            let increase = pow(previous.stability, -w[19]) * exp(w[17] * (rating - 3 + w[18]))
            let bounded = grade == .again ? increase : max(increase, 1)
            stability = clamp(previous.stability * bounded, 0.001, 36_500)
        } else if grade == .again {
            let failed = w[11]
                * pow(previous.difficulty, -w[12])
                * (pow(previous.stability + 1, w[13]) - 1)
                * exp(w[14] * (1 - retrievability))
            let minimum = previous.stability / exp(w[17] * w[18])
            stability = clamp(minimum, 0.001, failed)
        } else {
            let hardPenalty = grade == .hard ? w[15] : 1
            let easyBonus = grade == .easy ? w[16] : 1
            let recalled = previous.stability * (
                1 + exp(w[8])
                    * (11 - previous.difficulty)
                    * pow(previous.stability, -w[9])
                    * (exp((1 - retrievability) * w[10]) - 1)
                    * hardPenalty
                    * easyBonus
            )
            stability = clamp(recalled, 0.001, 36_500)
        }

        return (stability, difficulty)
    }

    private func nextTiming(
        previousPhase: PrototypeFSRSPhase,
        previousStep: Int,
        grade: PrototypeReviewGrade,
        stability: Double
    ) -> (seconds: TimeInterval, phase: PrototypeFSRSPhase, learningStep: Int) {
        switch previousPhase {
        case .new:
            switch grade {
            case .again: return (60, .learning, 0)
            case .hard: return (6 * 60, .learning, 0)
            case .good: return (10 * 60, .learning, 1)
            case .easy: return (daysInterval(stability), .review, 0)
            }
        case .learning:
            switch grade {
            case .again: return (60, .learning, 0)
            case .hard: return (6 * 60, .learning, previousStep)
            case .good where previousStep == 0: return (10 * 60, .learning, 1)
            case .good, .easy: return (daysInterval(stability), .review, 0)
            }
        case .review:
            if grade == .again { return (10 * 60, .relearning, 0) }
            return (daysInterval(stability), .review, 0)
        case .relearning:
            switch grade {
            case .again: return (10 * 60, .relearning, 0)
            case .hard: return (15 * 60, .relearning, 0)
            case .good, .easy: return (daysInterval(stability), .review, 0)
            }
        }
    }

    private func initialStability(_ grade: PrototypeReviewGrade) -> Double {
        max(w[grade.fsrsRating - 1], 0.1)
    }

    private func initialDifficulty(_ grade: PrototypeReviewGrade) -> Double {
        clamp(w[4] - exp(Double(grade.fsrsRating - 1) * w[5]) + 1, 1, 10)
    }

    private func nextDifficulty(_ difficulty: Double, grade: PrototypeReviewGrade) -> Double {
        let delta = -w[6] * Double(grade.fsrsRating - 3)
        let damped = delta * (10 - difficulty) / 9
        let initialEasy = w[4] - exp(3 * w[5]) + 1
        return clamp(w[7] * initialEasy + (1 - w[7]) * (difficulty + damped), 1, 10)
    }

    private func forgettingCurve(elapsedDays: Double, stability: Double) -> Double {
        let decay = -w[20]
        let factor = exp(log(0.9) / decay) - 1
        return pow(1 + factor * elapsedDays / stability, decay)
    }

    private func daysInterval(_ stability: Double) -> TimeInterval {
        let decay = -w[20]
        let factor = exp(log(0.9) / decay) - 1
        let modifier = (pow(Self.desiredRetention, 1 / decay) - 1) / factor
        let days = min(max(1, (stability * modifier).rounded()), 36_500)
        return days * 86_400
    }

    private func calendarDayDifference(from start: Date, to end: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return max(0, floor(endDay.timeIntervalSince(startDay) / 86_400))
    }

    private func clamp(_ value: Double, _ minimum: Double, _ maximum: Double) -> Double {
        min(max(value, minimum), maximum)
    }
}

enum PrototypeSection: String, CaseIterable, Identifiable, Hashable {
    case today, library, add, progress, utilities, settings

    var id: Self { self }

    func title(for language: PrototypeAppLanguage) -> String {
        if self == .utilities {
            return switch language {
            case .persian: "ابزارها"
            case .german: "Werkzeuge"
            case .english: "Utilities"
        }
        }
        let key: PrototypeTextKey = switch self {
        case .today: .today
        case .library: .library
        case .add: .add
        case .progress: .progress
        case .utilities: .today
        case .settings: .settings
        }
        return PrototypeLocalization.text(key, language: language)
    }

    var symbol: String {
        switch self {
        case .today: "sparkles"
        case .library: "books.vertical.fill"
        case .add: "plus.circle.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        case .utilities: "wrench.and.screwdriver.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct PrototypeWord: Identifiable, Hashable, Sendable {
    let id: UUID
    let german: String
    let persian: String
    let article: String?
    let level: String
    let partOfSpeech: String
    let example: String
    let exampleTranslation: String
    let examples: [PrototypeExample]
    let senses: [PrototypeSense]
    let domain: String
    let sourceLanguageTag: String
    let targetLanguageTag: String

    init(
        id: UUID = UUID(),
        german: String,
        persian: String,
        article: String? = nil,
        level: String,
        partOfSpeech: String,
        example: String,
        exampleTranslation: String,
        examples: [PrototypeExample] = [],
        senses: [PrototypeSense] = [],
        domain: String = "عمومی",
        sourceLanguageTag: String = "fa",
        targetLanguageTag: String = "de"
    ) {
        self.id = id
        self.german = german
        self.persian = persian
        self.article = article
        self.level = level
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.exampleTranslation = exampleTranslation
        self.examples = examples.isEmpty ? [PrototypeExample(target: example, source: exampleTranslation)] : examples
        self.senses = senses
        self.domain = domain
        self.sourceLanguageTag = sourceLanguageTag
        self.targetLanguageTag = targetLanguageTag
    }
}

/// Stable, provider-independent topic inference for imported decks that do not
/// carry a topic field. Explicit APKG topics always win; this fallback only
/// uses card text and therefore works offline and remains deterministic.
enum PrototypeDomainClassifier {
    static let general = "general"

    private static let keywords: [(domain: String, terms: [String])] = [
        ("work", ["arbeit", "beruf", "job", "büro", "firma", "geschäft", "chef", "kolleg", "mitarbeiter", "arbeitgeber", "work", "career", "office", "company", "business", "employee", "employer", "meeting"]),
        ("software", ["computer", "internet", "software", "datei", "daten", "digital", "programm", "webseite", "telefon", "handy", "data", "technology", "website", "phone"]),
        ("medical", ["arzt", "ärzt", "medizin", "gesund", "krank", "körper", "schmerz", "apotheke", "health", "doctor", "medical", "sick", "body", "pain", "hospital", "pharmacy"]),
        ("travel", ["reise", "reisen", "flug", "flughafen", "bahnhof", "zug", "hotel", "urlaub", "bus", "straße", "travel", "flight", "airport", "station", "train", "hotel", "holiday", "road"]),
        ("food", ["essen", "trinken", "küche", "restaurant", "brot", "fleisch", "gemüse", "obst", "kaffee", "food", "drink", "kitchen", "restaurant", "bread", "meat", "vegetable", "fruit", "coffee"]),
        ("family", ["familie", "mutter", "vater", "eltern", "kind", "sohn", "tochter", "bruder", "schwester", "family", "mother", "father", "parent", "child", "son", "daughter", "brother", "sister"]),
        ("education", ["schule", "universität", "lehrer", "student", "lernen", "unterricht", "prüfung", "buch", "school", "university", "teacher", "student", "learn", "lesson", "exam", "book"]),
        ("home", ["haus", "wohnung", "zimmer", "tür", "fenster", "tisch", "stuhl", "bett", "home", "house", "apartment", "room", "door", "window", "table", "chair", "bed"]),
        ("nature", ["natur", "tier", "pflanze", "baum", "blume", "wasser", "berg", "wald", "wetter", "nature", "animal", "plant", "tree", "flower", "water", "mountain", "forest", "weather"]),
        ("time", ["zeit", "tag", "woche", "monat", "jahr", "uhr", "morgen", "gestern", "heute", "time", "day", "week", "month", "year", "clock", "tomorrow", "yesterday", "today"])
    ]

    static func classify(german: String, source: String, example: String = "", explicitDomain: String? = nil) -> String {
        if let explicitDomain = normalizedExplicitDomain(explicitDomain) { return explicitDomain }
        let haystack = "\(german) \(source) \(example)".lowercased()
        var best: (domain: String, score: Int)?
        for entry in keywords {
            let score = entry.terms.reduce(into: 0) { result, term in
                if haystack.contains(term) { result += 1 }
            }
            if score > (best?.score ?? 0) { best = (entry.domain, score) }
        }
        return best?.domain ?? general
    }

    static func isGeneric(_ domain: String) -> Bool {
        let value = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty || ["general", "imported", "عمومی", "allgemein"].contains(value)
    }

    private static func normalizedExplicitDomain(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isGeneric(normalized) else { return nil }
        return normalized
    }
}

enum PrototypeDomainCatalog {
    private static let key = "linguabrain.custom.domains"
    static var customDomains: [String] {
        (UserDefaults.standard.array(forKey: key) as? [String] ?? []).sorted()
    }
    @discardableResult static func add(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        var values = customDomains
        if !values.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            values.append(value); UserDefaults.standard.set(values, forKey: key)
        }
        return value
    }
    static func remove(_ value: String) {
        UserDefaults.standard.set(customDomains.filter { $0 != value }, forKey: key)
    }
}

enum PrototypeMediaKind: String, Codable, Sendable {
    case pronunciationAudio
    case illustration
}

struct PrototypeA1MediaPlan: Hashable, Sendable {
    let isEligible: Bool
    let audioCacheKey: String?
    let imageCacheKey: String?
    let imagePrompt: String?
}

/// Deterministic media boundary for A1 cards. Providers can generate assets later;
/// card creation remains safe and text-only when either provider is unavailable.
enum PrototypeA1MediaPlanner {
    static func plan(for word: PrototypeWord, includeAudio: Bool, includeImage: Bool) -> PrototypeA1MediaPlan {
        guard word.level.uppercased() == "A1" else {
            return PrototypeA1MediaPlan(isEligible: false, audioCacheKey: nil, imageCacheKey: nil, imagePrompt: nil)
        }
        let identity = "\(word.targetLanguageTag)|\(word.german.lowercased())|A1"
        let safeIdentity = identity.replacingOccurrences(of: " ", with: "_")
        return PrototypeA1MediaPlan(
            isEligible: true,
            audioCacheKey: includeAudio ? "audio.v1.\(safeIdentity)" : nil,
            imageCacheKey: includeImage ? "image.v1.\(safeIdentity)" : nil,
            imagePrompt: includeImage ? "A clear, literal educational illustration of \(word.german), suitable for an A1 language-learning card, no text" : nil
        )
    }
}

struct PrototypeImportedCard: Sendable {
    let sourceIdentifier: String
    let word: PrototypeWord
    let sourceLanguageTag: String
    let targetLanguageTag: String
    let pronunciationAudio: Data?
    let illustrationImage: Data?

    init(
        sourceIdentifier: String,
        word: PrototypeWord,
        sourceLanguageTag: String = "fa",
        targetLanguageTag: String = "de",
        pronunciationAudio: Data? = nil,
        illustrationImage: Data? = nil
    ) {
        self.sourceIdentifier = sourceIdentifier
        self.word = word
        self.sourceLanguageTag = sourceLanguageTag
        self.targetLanguageTag = targetLanguageTag
        self.pronunciationAudio = pronunciationAudio
        self.illustrationImage = illustrationImage
    }
}

enum PrototypeCardProvenance: String, CaseIterable, Identifiable, Sendable {
    case generated
    case imported
    var id: Self { self }
}

struct PrototypeImportResult: Sendable {
    let deckName: String
    let addedCount: Int
    let updatedCount: Int
    let skippedCount: Int
}

struct PrototypeImportedPackage: Identifiable, Hashable, Sendable {
    var id: String { fileName }
    let fileName: String
    let cardCount: Int
}

enum PrototypeReviewGrade: String, CaseIterable, Identifiable, Hashable {
    case again, hard, good, easy

    var id: Self { self }

    var localizationKey: String {
        switch self {
        case .again: "ratingAgain"
        case .hard: "ratingHard"
        case .good: "ratingGood"
        case .easy: "ratingEasy"
        }
    }

    var title: String {
        switch self {
        case .again: "دوباره"
        case .hard: "سخت"
        case .good: "خوب"
        case .easy: "آسان"
        }
    }

    var symbol: String {
        switch self {
        case .again: "arrow.counterclockwise"
        case .hard: "flame.fill"
        case .good: "checkmark"
        case .easy: "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .again: .red
        case .hard: .orange
        case .good: PrototypeTheme.blue
        case .easy: PrototypeTheme.mint
        }
    }

    var fsrsRating: Int {
        switch self {
        case .again: 1
        case .hard: 2
        case .good: 3
        case .easy: 4
        }
    }

    var strength: Double {
        switch self {
        case .again: 0.15
        case .hard: 0.38
        case .good: 0.68
        case .easy: 0.92
        }
    }
}

enum PrototypeReviewMode: String, Sendable {
    case recognition
    case reverseTranslation
    case mixedGame

    var title: String {
        switch self {
        case .recognition: "مرور آلمانی به فارسی"
        case .reverseTranslation: "ترجمهٔ معکوس"
        case .mixedGame: "بازی ترکیبی"
        }
    }
}

private struct PrototypeRelatedWordScore {
    let word: PrototypeWord
    let relevance: Int
    let score: Int
}

@MainActor
@Observable
final class PrototypeStore {
    private(set) var grades: [String: [PrototypeReviewGrade]] = [:]
    private(set) var dueDates: [String: Date] = [:]
    private(set) var memoryStates: [String: PrototypeFSRSMemoryState] = [:]
    private(set) var lastPersistenceError: String?
    private(set) var importedPackages: [PrototypeImportedPackage] = []
    private(set) var activeMission: LearningMission?

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let scheduler = PrototypeFSRS6Scheduler()

    private(set) var words: [PrototypeWord] = []

    init(inMemory: Bool = false) {
        assert(
            PrototypeFSRS6Scheduler.passesReferenceVectors(),
            "FSRS-6 reference vectors do not match the pinned implementation."
        )
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            modelContainer = try ModelContainer(
                for: PrototypeDeckRecord.self,
                PrototypeMediaAssetRecord.self,
                PrototypeCardRecord.self,
                PrototypeReviewRecord.self,
                PrototypeSkillMasteryRecord.self,
                PrototypeLearningEventRecord.self,
                PrototypeLearningMissionRecord.self,
                configurations: configuration
            )
            modelContext = ModelContext(modelContainer)
            try seedCardsIfNeeded()
            try ensureMultilingualSampleCards()
            try restoreCards()
            restoreMission()
            restorePersistedReviews()
        } catch {
            fatalError("Unable to initialize the review store: \(error.localizedDescription)")
        }
    }

    func setActiveMission(_ mission: LearningMission?) {
        do {
            let records = try modelContext.fetch(FetchDescriptor<PrototypeLearningMissionRecord>())
            records.forEach { modelContext.delete($0) }
            if let mission {
                modelContext.insert(PrototypeLearningMissionRecord(id: mission.id, title: mission.title, domain: mission.domain, targetLevel: mission.targetLevel, weight: mission.weight))
            }
            try modelContext.save(); activeMission = mission
        } catch { lastPersistenceError = "Mission save failed: \(error.localizedDescription)" }
    }

    private func restoreMission() {
        guard let result = try? modelContext.fetch(FetchDescriptor<PrototypeLearningMissionRecord>()), let record = result.first else { return }
        activeMission = LearningMission(id: record.id, title: record.title, domain: record.domain, targetLevel: record.targetLevel, weight: record.weight)
    }

    var reviewedCount: Int { words.filter { reviewCount(for: $0) > 0 }.count }
    var unreviewedCount: Int { words.count - reviewedCount }
    var dueCount: Int {
        words.filter { reviewCount(for: $0) > 0 && isReviewable($0) }.count
    }
    var weakCount: Int {
        words.filter { reviewCount(for: $0) > 0 && strength(for: $0) < 0.5 }.count
    }
    var totalReviews: Int { grades.values.reduce(0) { $0 + $1.count } }
    var averageStrength: Double {
        guard reviewedCount > 0 else { return 0 }
        let total = words.reduce(0.0) { $0 + strength(for: $1) }
        return total / Double(reviewedCount)
    }

    func words(sourceLanguageTag: String, targetLanguageTag: String) -> [PrototypeWord] {
        words.filter {
            $0.sourceLanguageTag == sourceLanguageTag && $0.targetLanguageTag == targetLanguageTag
        }
    }

    func relatedWords(to word: PrototypeWord, limit: Int = 8) -> [PrototypeWord] {
        let sourceTokens = meaningfulTokens(in: word.persian)
        let germanRoot = word.german.lowercased().prefix(4)
        let candidates = words(sourceLanguageTag: word.sourceLanguageTag, targetLanguageTag: word.targetLanguageTag)
        var scored: [PrototypeRelatedWordScore] = []
        for candidate in candidates where candidate.id != word.id {
            var relevance = 0
            if !PrototypeDomainClassifier.isGeneric(word.domain), candidate.domain == word.domain { relevance += 8 }
            if germanRoot.count == 4, candidate.german.lowercased().hasPrefix(germanRoot) { relevance += 5 }
            relevance += sourceTokens.intersection(meaningfulTokens(in: candidate.persian)).count * 3
            guard relevance > 0 else { continue }
            var score = relevance
            if candidate.partOfSpeech == word.partOfSpeech { score += 2 }
            if candidate.level == word.level { score += 1 }
            scored.append(PrototypeRelatedWordScore(word: candidate, relevance: relevance, score: score))
        }
        scored.sort {
            $0.score == $1.score
                ? $0.word.german.localizedCaseInsensitiveCompare($1.word.german) == .orderedAscending
                : $0.score > $1.score
        }
        return scored.prefix(limit).map(\.word)
    }

    private func meaningfulTokens(in value: String) -> Set<String> {
        Set(value.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count >= 4 })
    }

    func provenance(of word: PrototypeWord) -> PrototypeCardProvenance {
        let wordID = word.id
        var descriptor = FetchDescriptor<PrototypeCardRecord>(
            predicate: #Predicate { $0.id == wordID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first)?.sourcePackage == nil ? .generated : .imported
    }

    func words(sourceLanguageTag: String, targetLanguageTag: String, provenance: PrototypeCardProvenance) -> [PrototypeWord] {
        words(sourceLanguageTag: sourceLanguageTag, targetLanguageTag: targetLanguageTag)
            .filter { self.provenance(of: $0) == provenance }
    }

    func pronunciationAudio(for word: PrototypeWord) -> Data? {
        guard let record = mediaRecord(for: word.id) else { return nil }
        return record.pronunciationAudioAssetID.flatMap(mediaData(for:)) ?? record.pronunciationAudio
    }

    func illustrationImage(for word: PrototypeWord) -> Data? {
        guard let record = mediaRecord(for: word.id) else { return nil }
        return record.illustrationImageAssetID.flatMap(mediaData(for:)) ?? record.illustrationImage
    }

    private func mediaRecord(for id: UUID) -> PrototypeCardRecord? {
        let requestedID = id
        var descriptor = FetchDescriptor<PrototypeCardRecord>(
            predicate: #Predicate { $0.id == requestedID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func mediaData(for assetID: UUID) -> Data? {
        let requestedID = assetID
        var descriptor = FetchDescriptor<PrototypeMediaAssetRecord>(
            predicate: #Predicate { $0.id == requestedID }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first?.data
    }

    func reviewedCount(in words: [PrototypeWord]) -> Int {
        words.filter { reviewCount(for: $0) > 0 }.count
    }

    func unreviewedCount(in words: [PrototypeWord]) -> Int {
        words.count - reviewedCount(in: words)
    }

    func dueCount(in words: [PrototypeWord]) -> Int {
        words.filter { reviewCount(for: $0) > 0 && isReviewable($0) }.count
    }

    func weakCount(in words: [PrototypeWord]) -> Int {
        words.filter { reviewCount(for: $0) > 0 && strength(for: $0) < 0.5 }.count
    }

    func averageStrength(in words: [PrototypeWord]) -> Double {
        let reviewed = reviewedCount(in: words)
        guard reviewed > 0 else { return 0 }
        return words.reduce(0.0) { $0 + strength(for: $1) } / Double(reviewed)
    }

    func totalReviews(in words: [PrototypeWord]) -> Int {
        words.reduce(0) { $0 + reviewCount(for: $1) }
    }

    func strength(for word: PrototypeWord, mode: PrototypeReviewMode = .recognition) -> Double {
        let key = reviewKey(for: word, mode: mode)
        guard let state = memoryStates[key] else {
            return grades[key]?.last?.strength ?? 0
        }
        return scheduler.retrievability(state: state, at: .now)
    }

    func reviewCount(for word: PrototypeWord, mode: PrototypeReviewMode = .recognition) -> Int {
        grades[reviewKey(for: word, mode: mode)]?.count ?? 0
    }

    func mastery(for word: PrototypeWord, mode: PrototypeReviewMode = .recognition) -> Double {
        let skill = mode == .reverseTranslation ? "recall" : "recognition"
        let id = "\(word.id.uuidString)::\(skill)"
        return (try? modelContext.fetch(FetchDescriptor<PrototypeSkillMasteryRecord>()))?
            .first(where: { $0.id == id })?.score ?? 0
    }

    func lastGrade(for word: PrototypeWord, mode: PrototypeReviewMode = .recognition) -> PrototypeReviewGrade? {
        grades[reviewKey(for: word, mode: mode)]?.last
    }

    func dueDate(for word: PrototypeWord, mode: PrototypeReviewMode = .recognition) -> Date? {
        dueDates[reviewKey(for: word, mode: mode)]
    }

    func previewSchedule(
        for grade: PrototypeReviewGrade,
        word: PrototypeWord,
        mode: PrototypeReviewMode = .recognition,
        at date: Date = .now
    ) -> PrototypeFSRSSchedule {
        scheduler.schedule(previous: memoryStates[reviewKey(for: word, mode: mode)], grade: grade, now: date)
    }

    func shouldRepeatInCurrentSession(_ word: PrototypeWord, mode: PrototypeReviewMode = .recognition) -> Bool {
        let key = reviewKey(for: word, mode: mode)
        guard let state = memoryStates[key], let dueDate = dueDates[key] else {
            return false
        }
        return (state.phase == .learning || state.phase == .relearning)
            && dueDate.timeIntervalSince(state.lastReview) < 86_400
    }

    func isReviewable(_ word: PrototypeWord, mode: PrototypeReviewMode = .recognition, at date: Date = .now) -> Bool {
        guard reviewCount(for: word, mode: mode) > 0 else { return true }
        guard let dueDate = dueDates[reviewKey(for: word, mode: mode)] else { return true }
        return dueDate <= date
    }

    @discardableResult
    func record(
        _ grade: PrototypeReviewGrade,
        for word: PrototypeWord,
        mode: PrototypeReviewMode = .recognition,
        at date: Date = .now
    ) -> PrototypeFSRSSchedule? {
        let key = reviewKey(for: word, mode: mode)
        let schedule = previewSchedule(for: grade, word: word, mode: mode, at: date)
        let record = PrototypeReviewRecord(
            wordKey: key,
            gradeRawValue: grade.rawValue,
            reviewedAt: date,
            dueAt: schedule.dueAt,
            stability: schedule.state.stability,
            difficulty: schedule.state.difficulty,
            phaseRawValue: schedule.state.phase.rawValue,
            learningStep: schedule.state.learningStep,
            scheduledDays: schedule.scheduledDays,
            elapsedDays: schedule.elapsedDays,
            algorithmVersion: PrototypeFSRS6Scheduler.version
        )
            modelContext.insert(record)
            let skill = mode == .reverseTranslation ? "recall" : "recognition"
            let masteryID = "\(word.id.uuidString)::\(skill)"
            let mastery = (try? modelContext.fetch(FetchDescriptor<PrototypeSkillMasteryRecord>()))?
                .first(where: { $0.id == masteryID }) ?? {
                    let value = PrototypeSkillMasteryRecord(cardID: word.id, skillRawValue: skill)
                    modelContext.insert(value)
                    return value
                }()
            mastery.attempts += 1
            if grade != .again { mastery.correct += 1 }
            mastery.score = Double(mastery.correct) / Double(max(mastery.attempts, 1))
            mastery.lastUpdated = date
            modelContext.insert(PrototypeLearningEventRecord(cardID: word.id, skillRawValue: skill, correct: grade != .again, occurredAt: date))

        do {
            try modelContext.save()
            grades[key, default: []].append(grade)
            dueDates[key] = schedule.dueAt
            memoryStates[key] = schedule.state
            lastPersistenceError = nil
            return schedule
        } catch {
            modelContext.rollback()
            lastPersistenceError = "ذخیره پاسخ انجام نشد: \(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func reset() -> Bool {
        do {
            try modelContext.delete(model: PrototypeReviewRecord.self)
            try modelContext.delete(model: PrototypeSkillMasteryRecord.self)
            try modelContext.delete(model: PrototypeLearningEventRecord.self)
            try modelContext.save()
            grades.removeAll()
            dueDates.removeAll()
            memoryStates.removeAll()
            lastPersistenceError = nil
            return true
        } catch {
            modelContext.rollback()
            lastPersistenceError = "بازنشانی اطلاعات انجام نشد: \(error.localizedDescription)"
            return false
        }
    }

    func clearPersistenceError() {
        lastPersistenceError = nil
    }

    func cloudBackupCards() throws -> [PrototypeCloudCard] {
        let records = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
        let decks = try modelContext.fetch(FetchDescriptor<PrototypeDeckRecord>())
        let deckNames = Dictionary(uniqueKeysWithValues: decks.map { ($0.id, $0.name) })
        return records.compactMap { record in
            guard record.sourcePackage != nil || deckNames[record.deckID] == "کارت‌های هوشمند" else { return nil }
            return PrototypeCloudCard(
                id: record.id,
                deckName: deckNames[record.deckID] ?? "Cloud Cards",
                position: record.position,
                german: record.german,
                persian: record.persian,
                article: record.article,
                level: record.level,
                partOfSpeech: record.partOfSpeech,
                example: record.example,
                exampleTranslation: record.exampleTranslation,
                examplesJSON: record.examplesJSON,
                domain: record.domain,
                createdAt: record.createdAt,
                sourceIdentifier: record.sourceIdentifier,
                sourcePackage: record.sourcePackage,
                sourceLanguageTag: record.sourceLanguageTag,
                targetLanguageTag: record.targetLanguageTag,
                pronunciationAudio: pronunciationAudio(for: record.word),
                pronunciationAudioFilename: record.pronunciationAudioFilename
            )
        }
    }

    func mergeCloudCards(_ cloudCards: [PrototypeCloudCard]) throws {
        let records = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
        var ids = Set(records.map(\.id))
        var semanticKeys = Set(records.map { $0.word.semanticKey })
        let decks = try modelContext.fetch(FetchDescriptor<PrototypeDeckRecord>())
        var deckByName = Dictionary(uniqueKeysWithValues: decks.map { ($0.name, $0) })

        for card in cloudCards where !ids.contains(card.id) {
            let word = PrototypeWord(
                id: card.id,
                german: card.german,
                persian: card.persian,
                article: card.article,
                level: card.level,
                partOfSpeech: card.partOfSpeech,
                example: card.example,
                exampleTranslation: card.exampleTranslation,
                examples: (try? JSONDecoder().decode([PrototypeExample].self, from: Data(card.examplesJSON.utf8))) ?? [],
                domain: card.domain,
                sourceLanguageTag: card.sourceLanguageTag,
                targetLanguageTag: card.targetLanguageTag
            )
            guard !semanticKeys.contains(word.semanticKey) else { continue }
            let deck = deckByName[card.deckName] ?? {
                let deck = PrototypeDeckRecord(name: card.deckName)
                modelContext.insert(deck)
                deckByName[card.deckName] = deck
                return deck
            }()
            modelContext.insert(PrototypeCardRecord(
                word: word,
                deckID: deck.id,
                position: card.position,
                createdAt: card.createdAt,
                sourceIdentifier: card.sourceIdentifier,
                sourcePackage: card.sourcePackage,
                pronunciationAudio: card.pronunciationAudio,
                pronunciationAudioFilename: card.pronunciationAudioFilename
            ))
            ids.insert(card.id)
            semanticKeys.insert(word.semanticKey)
        }
        try modelContext.save()
        try restoreCards()
    }

    func importCards(
        _ candidates: [PrototypeImportedCard],
        deckName: String,
        sourcePackage: String
    ) -> PrototypeImportResult? {
        do {
            let existingRecords = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
            var recordsBySource: [String: PrototypeCardRecord] = [:]
            for record in existingRecords {
                if let sourceIdentifier = record.sourceIdentifier {
                    recordsBySource[sourceIdentifier] = recordsBySource[sourceIdentifier] ?? record
                }
            }
            var existingKeys = Set(existingRecords.map { $0.word.semanticKey })
            let deck = PrototypeDeckRecord(name: deckName)
            modelContext.insert(deck)

            var added = 0
            var updated = 0
            var skipped = 0
            for candidate in candidates {
                if let record = recordsBySource[candidate.sourceIdentifier] {
                    existingKeys.remove(record.word.semanticKey)
                    guard !existingKeys.contains(candidate.word.semanticKey) else {
                        skipped += 1
                        continue
                    }
                    record.german = candidate.word.german
                    record.persian = candidate.word.persian
                    record.article = candidate.word.article
                    record.level = candidate.word.level
                    record.partOfSpeech = candidate.word.partOfSpeech
                    record.example = candidate.word.example
                    record.exampleTranslation = candidate.word.exampleTranslation
                    record.examplesJSON = (try? String(data: JSONEncoder().encode(candidate.word.examples), encoding: .utf8)) ?? "[]"
                    record.sensesJSON = (try? String(data: JSONEncoder().encode(candidate.word.senses), encoding: .utf8)) ?? "[]"
                    record.domain = candidate.word.domain
                    record.sourceLanguageTag = candidate.sourceLanguageTag
                    record.targetLanguageTag = candidate.targetLanguageTag
                    record.sourcePackage = sourcePackage
                    if candidate.pronunciationAudio != nil { record.pronunciationAudio = candidate.pronunciationAudio }
                    if candidate.illustrationImage != nil { record.illustrationImage = candidate.illustrationImage }
                    existingKeys.insert(candidate.word.semanticKey)
                    updated += 1
                    continue
                }
                guard !existingKeys.contains(candidate.word.semanticKey) else {
                    skipped += 1
                    continue
                }
                let record = PrototypeCardRecord(
                    word: candidate.word.withLanguagePair(
                        source: candidate.sourceLanguageTag,
                        target: candidate.targetLanguageTag
                    ),
                    deckID: deck.id,
                    position: existingRecords.count + added,
                    sourceIdentifier: candidate.sourceIdentifier,
                    sourcePackage: sourcePackage,
                    pronunciationAudio: candidate.pronunciationAudio,
                    pronunciationAudioFilename: candidate.pronunciationAudio == nil ? nil : "imported-audio-\(candidate.sourceIdentifier.hashValue).audio",
                    illustrationImage: candidate.illustrationImage,
                    illustrationImageFilename: candidate.illustrationImage == nil ? nil : "imported-image-\(candidate.sourceIdentifier.hashValue).image"
                )
                modelContext.insert(record)
                recordsBySource[candidate.sourceIdentifier] = record
                existingKeys.insert(candidate.word.semanticKey)
                added += 1

                // Keep large APKG imports in bounded SwiftData transactions.
                // This prevents a several-thousand-card deck from retaining
                // the complete pending object graph until the final save.
                if added.isMultiple(of: 250) {
                    try modelContext.save()
                }
            }

            if added == 0 {
                modelContext.delete(deck)
            }
            try modelContext.save()
            try restoreCards()
            lastPersistenceError = nil
            return PrototypeImportResult(deckName: deckName, addedCount: added, updatedCount: updated, skippedCount: skipped)
        } catch {
            modelContext.rollback()
            lastPersistenceError = "ورود کارت‌ها انجام نشد: \(error.localizedDescription)"
            return nil
        }
    }

    @discardableResult
    func addGeneratedCard(
        _ word: PrototypeWord,
        pronunciationAudio: Data? = nil,
        illustrationImage: Data? = nil
    ) -> Bool {
        addGeneratedCards(
            [word],
            sharedPronunciationAudio: pronunciationAudio,
            sharedIllustrationImage: illustrationImage
        )
    }

    /// Persists each independent meaning as a card while creating at most one
    /// audio asset and one image asset for the submitted headword.
    @discardableResult
    func addGeneratedCards(
        _ words: [PrototypeWord],
        sharedPronunciationAudio: Data? = nil,
        sharedIllustrationImage: Data? = nil
    ) -> Bool {
        guard !words.isEmpty else { return true }
        do {
            let cards = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
            func generatedLemmaKey(_ word: PrototypeWord) -> String {
                [word.sourceLanguageTag, word.targetLanguageTag, word.normalizedGerman, word.domain]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .joined(separator: "::generated-lemma::")
            }
            var generatedLemmaKeys = Set(cards.map { generatedLemmaKey($0.word) })
            guard words.allSatisfy({ generatedLemmaKeys.insert(generatedLemmaKey($0)).inserted }) else {
                lastPersistenceError = "این واژه در همین حوزه از قبل وجود دارد."
                return false
            }
            let decks = try modelContext.fetch(FetchDescriptor<PrototypeDeckRecord>())
            let deck = decks.first(where: { $0.name == "کارت‌های هوشمند" }) ?? {
                let deck = PrototypeDeckRecord(name: "کارت‌های هوشمند")
                modelContext.insert(deck)
                return deck
            }()
            let audioAsset = sharedPronunciationAudio.map {
                PrototypeMediaAssetRecord(kind: "audio", data: $0, filename: "audio-\(UUID().uuidString).mp3")
            }
            let imageAsset = sharedIllustrationImage.map {
                PrototypeMediaAssetRecord(kind: "image", data: $0, filename: "image-\(UUID().uuidString).png")
            }
            if let audioAsset { modelContext.insert(audioAsset) }
            if let imageAsset { modelContext.insert(imageAsset) }
            for (offset, word) in words.enumerated() {
                modelContext.insert(PrototypeCardRecord(
                    word: word,
                    deckID: deck.id,
                    position: cards.count + offset,
                    pronunciationAudioAssetID: audioAsset?.id,
                    illustrationImageAssetID: imageAsset?.id
                ))
            }
            try modelContext.save()
            try restoreCards()
            lastPersistenceError = nil
            return true
        } catch {
            modelContext.rollback()
            lastPersistenceError = "ذخیرهٔ کارت انجام نشد: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func deleteImportedPackage(named fileName: String) -> Bool {
        do {
            let allCards = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
            let cardsToDelete = allCards.filter { $0.sourcePackage == fileName }
            guard !cardsToDelete.isEmpty else {
                lastPersistenceError = "بستهٔ واردشده پیدا نشد."
                return false
            }
            return try deleteCards(cardsToDelete, allCards: allCards)
        } catch {
            modelContext.rollback()
            lastPersistenceError = "حذف بسته انجام نشد: \(error.localizedDescription)"
            return false
        }
    }

    /// Removes selected cards as one transaction. Shared media is removed only
    /// after the last card that references it has also been removed.
    @discardableResult
    func deleteCards(ids: Set<UUID>) -> Bool {
        guard !ids.isEmpty else { return true }
        do {
            let allCards = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
            let cardsToDelete = allCards.filter { ids.contains($0.id) }
            guard cardsToDelete.count == ids.count else {
                lastPersistenceError = "برخی از کارت‌های انتخاب‌شده دیگر وجود ندارند. فهرست را تازه کنید."
                return false
            }
            return try deleteCards(cardsToDelete, allCards: allCards)
        } catch {
            modelContext.rollback()
            lastPersistenceError = "حذف کارت انجام نشد: \(error.localizedDescription)"
            return false
        }
    }

    private func deleteCards(_ cardsToDelete: [PrototypeCardRecord], allCards: [PrototypeCardRecord]) throws -> Bool {
        let deletedWordKeys = Set(cardsToDelete.map { $0.word.reviewIdentityKey })
        let deletedCardIDs = Set(cardsToDelete.map(\.id))
        let affectedDeckIDs = Set(cardsToDelete.map(\.deckID))
        let candidateMediaAssetIDs = Set(cardsToDelete.flatMap { [$0.pronunciationAudioAssetID, $0.illustrationImageAssetID].compactMap { $0 } })
        let remainingMediaAssetIDs = Set(allCards
            .filter { !deletedCardIDs.contains($0.id) }
            .flatMap { [$0.pronunciationAudioAssetID, $0.illustrationImageAssetID].compactMap { $0 } })

        for card in cardsToDelete {
            modelContext.delete(card)
        }

        let allReviews = try modelContext.fetch(FetchDescriptor<PrototypeReviewRecord>())
        for review in allReviews where deletedWordKeys.contains(where: {
            review.wordKey == $0 || review.wordKey.hasPrefix("\($0)::")
        }) {
            modelContext.delete(review)
        }

        let allSkillMasteries = try modelContext.fetch(FetchDescriptor<PrototypeSkillMasteryRecord>())
        for mastery in allSkillMasteries where deletedCardIDs.contains(mastery.cardID) {
            modelContext.delete(mastery)
        }

        let allLearningEvents = try modelContext.fetch(FetchDescriptor<PrototypeLearningEventRecord>())
        for event in allLearningEvents where deletedCardIDs.contains(event.cardID) {
            modelContext.delete(event)
        }

        if !candidateMediaAssetIDs.isEmpty {
            let assets = try modelContext.fetch(FetchDescriptor<PrototypeMediaAssetRecord>())
            for asset in assets where candidateMediaAssetIDs.contains(asset.id) && !remainingMediaAssetIDs.contains(asset.id) {
                modelContext.delete(asset)
            }
        }

        let remainingDeckIDs = Set(allCards.lazy.filter { !deletedCardIDs.contains($0.id) }.map(\.deckID))
        let allDecks = try modelContext.fetch(FetchDescriptor<PrototypeDeckRecord>())
        for deck in allDecks where affectedDeckIDs.contains(deck.id) && !remainingDeckIDs.contains(deck.id) {
            modelContext.delete(deck)
        }

        try modelContext.save()
        try restoreCards()
        restorePersistedReviews()
        lastPersistenceError = nil
        return true
    }

    private func seedCardsIfNeeded() throws {
        var cardDescriptor = FetchDescriptor<PrototypeCardRecord>()
        cardDescriptor.fetchLimit = 1
        guard try modelContext.fetch(cardDescriptor).isEmpty else { return }

        let deck = PrototypeDeckRecord(name: "واژگان پایه آلمانی–فارسی")
        modelContext.insert(deck)
        for (position, word) in PrototypeData.words.enumerated() {
            modelContext.insert(
                PrototypeCardRecord(word: word, deckID: deck.id, position: position)
            )
        }
        try modelContext.save()
    }

    private func ensureMultilingualSampleCards() throws {
        let existingRecords = try modelContext.fetch(FetchDescriptor<PrototypeCardRecord>())
        let existingIDs = Set(existingRecords.map(\.id))
        let missing = PrototypeData.multilingualSamples.filter { !existingIDs.contains($0.id) }
        guard !missing.isEmpty else { return }

        let deck = PrototypeDeckRecord(name: "Multilingual Test Cards")
        modelContext.insert(deck)
        let offset = existingRecords.count
        for (index, word) in missing.enumerated() {
            modelContext.insert(
                PrototypeCardRecord(word: word, deckID: deck.id, position: offset + index)
            )
        }
        try modelContext.save()
    }

    private func restoreCards() throws {
        let descriptor = FetchDescriptor<PrototypeCardRecord>(
            sortBy: [SortDescriptor(\.position), SortDescriptor(\.createdAt)]
        )
        let records = try modelContext.fetch(descriptor)
        var requiresSave = false
        for record in records where record.sourcePackage != nil && PrototypeDomainClassifier.isGeneric(record.domain) {
            let inferred = PrototypeDomainClassifier.classify(
                german: record.german,
                source: record.persian,
                example: record.example
            )
            guard inferred != PrototypeDomainClassifier.general else { continue }
            record.domain = inferred
            requiresSave = true
        }
        if try removeDanglingLearningReferences(liveCards: records) {
            requiresSave = true
        }
        if requiresSave { try modelContext.save() }
        words = records.map(\.word)
        let grouped = Dictionary(grouping: records.compactMap { record in
            record.sourcePackage.map { ($0, record.id) }
        }, by: \.0)
        importedPackages = grouped.map { fileName, records in
            PrototypeImportedPackage(fileName: fileName, cardCount: records.count)
        }
        .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    /// Older builds removed imported cards without removing every record keyed
    /// by their UUID. Repair those dangling references whenever the store is
    /// restored, so a past incomplete deletion cannot affect later reviews.
    private func removeDanglingLearningReferences(liveCards: [PrototypeCardRecord]) throws -> Bool {
        let liveCardIDs = Set(liveCards.map(\.id))
        var changed = false

        let masteries = try modelContext.fetch(FetchDescriptor<PrototypeSkillMasteryRecord>())
        for mastery in masteries where !liveCardIDs.contains(mastery.cardID) {
            modelContext.delete(mastery)
            changed = true
        }

        let events = try modelContext.fetch(FetchDescriptor<PrototypeLearningEventRecord>())
        for event in events where !liveCardIDs.contains(event.cardID) {
            modelContext.delete(event)
            changed = true
        }

        let reviews = try modelContext.fetch(FetchDescriptor<PrototypeReviewRecord>())
        for review in reviews {
            guard let cardID = Self.cardID(in: review.wordKey), !liveCardIDs.contains(cardID) else { continue }
            modelContext.delete(review)
            changed = true
        }
        return changed
    }

    private static func cardID(in reviewKey: String) -> UUID? {
        guard reviewKey.hasPrefix("card:") else { return nil }
        let value = reviewKey
            .dropFirst("card:".count)
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init)
        return value.flatMap(UUID.init(uuidString:))
    }

    private func restorePersistedReviews() {
        do {
            grades.removeAll()
            dueDates.removeAll()
            memoryStates.removeAll()
            let descriptor = FetchDescriptor<PrototypeReviewRecord>(
                sortBy: [SortDescriptor(\.reviewedAt)]
            )
            let records = try modelContext.fetch(descriptor)

            var migratedLegacyKeys = false
            for record in records {
                if !record.wordKey.hasPrefix("card:") {
                    let isReverse = record.wordKey.hasSuffix("::reverse")
                    let legacyGerman = isReverse
                        ? String(record.wordKey.dropLast("::reverse".count))
                        : record.wordKey
                    if let word = words.first(where: { $0.normalizedGerman == legacyGerman }) {
                        record.wordKey = isReverse
                            ? "\(word.reviewIdentityKey)::reverse"
                            : word.reviewIdentityKey
                        migratedLegacyKeys = true
                    }
                }
                guard let grade = PrototypeReviewGrade(rawValue: record.gradeRawValue) else {
                    continue
                }
                grades[record.wordKey, default: []].append(grade)
                dueDates[record.wordKey] = record.dueAt
                if record.algorithmVersion == PrototypeFSRS6Scheduler.version,
                   let phase = PrototypeFSRSPhase(rawValue: record.phaseRawValue),
                   record.stability >= 0.001,
                   record.difficulty >= 1 {
                    memoryStates[record.wordKey] = PrototypeFSRSMemoryState(
                        stability: record.stability,
                        difficulty: record.difficulty,
                        phase: phase,
                        learningStep: record.learningStep,
                        lastReview: record.reviewedAt
                    )
                }
            }
            if migratedLegacyKeys { try modelContext.save() }
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "بازیابی اطلاعات مرور انجام نشد: \(error.localizedDescription)"
        }
    }

    private func reviewKey(for word: PrototypeWord, mode: PrototypeReviewMode) -> String {
        switch mode {
        case .recognition: word.reviewIdentityKey
        case .reverseTranslation: "\(word.reviewIdentityKey)::reverse"
        case .mixedGame: "\(word.reviewIdentityKey)::mixed"
        }
    }
}

extension PrototypeWord {
    func withLanguagePair(source: String, target: String) -> PrototypeWord {
        PrototypeWord(
            id: id,
            german: german,
            persian: persian,
            article: article,
            level: level,
            partOfSpeech: partOfSpeech,
            example: example,
            exampleTranslation: exampleTranslation,
            domain: domain,
            sourceLanguageTag: source,
            targetLanguageTag: target
        )
    }

    var normalizedGerman: String {
        german.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var semanticKey: String {
        [sourceLanguageTag, targetLanguageTag, normalizedGerman, persian, domain]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .joined(separator: "::sense::")
    }

    var reviewIdentityKey: String {
        "card:\(id.uuidString.lowercased())"
    }
}

enum PrototypeData {
    static let words: [PrototypeWord] = [
        word("arbeiten", "کار کردن", "A1", "Verb", "Ich arbeite heute von zu Hause.", "من امروز از خانه کار می‌کنم."),
        word("die Entscheidung", "تصمیم", "B1", "Nomen", "Wir treffen morgen eine Entscheidung.", "ما فردا تصمیم می‌گیریم.", article: "die"),
        word("zuverlässig", "قابل اعتماد", "B1", "Adjektiv", "Sie ist eine zuverlässige Kollegin.", "او همکار قابل اعتمادی است."),
        word("der Arbeitsvertrag", "قرارداد کاری", "B2", "Nomen", "Bitte lesen Sie den Arbeitsvertrag sorgfältig.", "لطفاً قرارداد کاری را با دقت بخوانید.", article: "der"),
        word("das Haus", "خانه", "A1", "Nomen", "Das Haus ist sehr alt.", "خانه بسیار قدیمی است.", article: "das"),
        word("die Familie", "خانواده", "A1", "Nomen", "Meine Familie lebt in Berlin.", "خانوادهٔ من در برلین زندگی می‌کند.", article: "die"),
        word("lernen", "یاد گرفتن", "A1", "Verb", "Ich lerne jeden Tag Deutsch.", "من هر روز آلمانی یاد می‌گیرم."),
        word("sprechen", "صحبت کردن", "A1", "Verb", "Wir sprechen über die Arbeit.", "ما دربارهٔ کار صحبت می‌کنیم."),
        word("verstehen", "فهمیدن", "A1", "Verb", "Ich verstehe die Frage.", "من سؤال را می‌فهمم."),
        word("brauchen", "نیاز داشتن", "A1", "Verb", "Ich brauche mehr Zeit.", "من به زمان بیشتری نیاز دارم."),
        word("kaufen", "خریدن", "A1", "Verb", "Sie kauft frisches Brot.", "او نان تازه می‌خرد."),
        word("bezahlen", "پرداخت کردن", "A1", "Verb", "Kann ich mit Karte bezahlen?", "می‌توانم با کارت پرداخت کنم؟"),
        word("die Wohnung", "آپارتمان", "A1", "Nomen", "Die Wohnung hat drei Zimmer.", "آپارتمان سه اتاق دارد.", article: "die"),
        word("der Bahnhof", "ایستگاه قطار", "A1", "Nomen", "Der Bahnhof ist in der Nähe.", "ایستگاه قطار نزدیک است.", article: "der"),
        word("die Gesundheit", "سلامتی", "A2", "Nomen", "Gesundheit ist sehr wichtig.", "سلامتی بسیار مهم است.", article: "die"),
        word("der Termin", "قرار", "A2", "Nomen", "Ich habe morgen einen Termin.", "من فردا یک قرار دارم.", article: "der"),
        word("die Erfahrung", "تجربه", "A2", "Nomen", "Er hat viel Erfahrung.", "او تجربهٔ زیادی دارد.", article: "die"),
        word("die Bewerbung", "درخواست استخدام", "B1", "Nomen", "Meine Bewerbung ist fertig.", "درخواست استخدام من آماده است.", article: "die"),
        word("das Gespräch", "گفت‌وگو", "A2", "Nomen", "Das Gespräch war hilfreich.", "گفت‌وگو مفید بود.", article: "das"),
        word("der Mitarbeiter", "کارمند", "A2", "Nomen", "Der Mitarbeiter beantwortet die E-Mail.", "کارمند به ایمیل پاسخ می‌دهد.", article: "der"),
        word("die Aufgabe", "وظیفه", "A2", "Nomen", "Diese Aufgabe ist einfach.", "این وظیفه ساده است.", article: "die"),
        word("die Besprechung", "جلسه", "B1", "Nomen", "Die Besprechung beginnt um neun Uhr.", "جلسه ساعت نه شروع می‌شود.", article: "die"),
        word("erklären", "توضیح دادن", "A2", "Verb", "Können Sie das bitte erklären?", "می‌توانید لطفاً آن را توضیح دهید؟"),
        word("vereinbaren", "هماهنگ کردن", "B1", "Verb", "Wir vereinbaren einen neuen Termin.", "ما یک قرار جدید هماهنگ می‌کنیم."),
        word("teilnehmen", "شرکت کردن", "B1", "Verb", "Ich nehme an der Besprechung teil.", "من در جلسه شرکت می‌کنم."),
        word("sich bewerben", "درخواست استخدام دادن", "B1", "Verb", "Sie bewirbt sich um eine Stelle.", "او برای یک شغل درخواست می‌دهد."),
        word("entscheiden", "تصمیم گرفتن", "B1", "Verb", "Wir müssen heute entscheiden.", "ما باید امروز تصمیم بگیریم."),
        word("verbessern", "بهبود دادن", "B1", "Verb", "Ich möchte mein Deutsch verbessern.", "می‌خواهم زبان آلمانی‌ام را بهتر کنم."),
        word("unterstützen", "حمایت کردن", "B1", "Verb", "Das Team unterstützt mich.", "تیم از من حمایت می‌کند."),
        word("verantwortlich", "مسئول", "B1", "Adjektiv", "Wer ist dafür verantwortlich?", "چه کسی مسئول آن است؟"),
        word("pünktlich", "سروقت", "A2", "Adjektiv", "Der Zug kommt pünktlich an.", "قطار سروقت می‌رسد."),
        word("freundlich", "دوستانه", "A1", "Adjektiv", "Die Ärztin ist sehr freundlich.", "پزشک بسیار خوش‌برخورد است."),
        word("wichtig", "مهم", "A1", "Adjektiv", "Diese Information ist wichtig.", "این اطلاعات مهم است."),
        word("möglich", "ممکن", "A2", "Adjektiv", "Ist das morgen möglich?", "آیا فردا ممکن است؟"),
        word("gemeinsam", "با هم", "A2", "Adverb", "Wir lösen das Problem gemeinsam.", "ما مشکل را با هم حل می‌کنیم."),
        word("wahrscheinlich", "احتمالاً", "B1", "Adverb", "Er kommt wahrscheinlich später.", "او احتمالاً دیرتر می‌آید."),
        word("die Rechnung", "صورتحساب", "A2", "Nomen", "Bitte bringen Sie die Rechnung.", "لطفاً صورتحساب را بیاورید.", article: "die"),
        word("die Versicherung", "بیمه", "B1", "Nomen", "Die Versicherung bezahlt die Kosten.", "بیمه هزینه‌ها را پرداخت می‌کند.", article: "die"),
        word("die Nachricht", "پیام", "A1", "Nomen", "Ich habe deine Nachricht gelesen.", "من پیام تو را خواندم.", article: "die"),
        word("die Frage", "سؤال", "A1", "Nomen", "Ich habe eine Frage.", "من یک سؤال دارم.", article: "die"),
        word("die Antwort", "پاسخ", "A1", "Nomen", "Seine Antwort ist richtig.", "پاسخ او درست است.", article: "die"),
        word("der Unterschied", "تفاوت", "B1", "Nomen", "Was ist der Unterschied?", "تفاوت چیست؟", article: "der"),
        word("die Möglichkeit", "امکان", "B1", "Nomen", "Es gibt eine andere Möglichkeit.", "امکان دیگری وجود دارد.", article: "die"),
        word("die Verantwortung", "مسئولیت", "B1", "Nomen", "Sie übernimmt die Verantwortung.", "او مسئولیت را بر عهده می‌گیرد.", article: "die"),
        word("der Erfolg", "موفقیت", "B1", "Nomen", "Der Kurs war ein großer Erfolg.", "دوره موفقیت بزرگی بود.", article: "der"),
        word("die Herausforderung", "چالش", "B2", "Nomen", "Das Projekt ist eine Herausforderung.", "این پروژه یک چالش است.", article: "die"),
        word("die Weiterbildung", "آموزش تکمیلی", "B2", "Nomen", "Die Firma bezahlt meine Weiterbildung.", "شرکت هزینهٔ آموزش تکمیلی من را می‌دهد.", article: "die"),
        word("die Voraussetzung", "پیش‌شرط", "B2", "Nomen", "Deutsch B2 ist eine Voraussetzung.", "آلمانی B2 یک پیش‌شرط است.", article: "die"),
        word("die Zusammenarbeit", "همکاری", "B2", "Nomen", "Danke für die gute Zusammenarbeit.", "از همکاری خوبتان متشکرم.", article: "die"),
        word("die Rückmeldung", "بازخورد", "B2", "Nomen", "Ich warte auf Ihre Rückmeldung.", "منتظر بازخورد شما هستم.", article: "die")
    ]

    /// Five owned test cards for every directed pair among Persian, German,
    /// and English. `german` temporarily stores target-side text and `persian`
    /// stores source-side text until the neutral field-name migration in M1.
    static let multilingualSamples: [PrototypeWord] = [
        sample(1, "fa", "de", "کتاب", "das Buch", "این یک کتاب است.", "Das ist ein Buch."),
        sample(2, "fa", "de", "آب", "das Wasser", "من آب می‌نوشم.", "Ich trinke Wasser."),
        sample(3, "fa", "de", "دوست", "der Freund", "او دوست من است.", "Er ist mein Freund."),
        sample(4, "fa", "de", "یاد گرفتن", "lernen", "من هر روز یاد می‌گیرم.", "Ich lerne jeden Tag."),
        sample(5, "fa", "de", "سریع", "schnell", "قطار سریع است.", "Der Zug ist schnell."),

        sample(6, "fa", "en", "خانه", "house", "این خانه بزرگ است.", "This house is large."),
        sample(7, "fa", "en", "کتاب", "book", "کتاب روی میز است.", "The book is on the table."),
        sample(8, "fa", "en", "کار کردن", "work", "من امروز کار می‌کنم.", "I work today."),
        sample(9, "fa", "en", "پرسش", "question", "من یک پرسش دارم.", "I have a question."),
        sample(10, "fa", "en", "مهم", "important", "این موضوع مهم است.", "This topic is important."),

        sample(11, "de", "fa", "das Haus", "خانه", "Das Haus ist alt.", "خانه قدیمی است."),
        sample(12, "de", "fa", "das Buch", "کتاب", "Ich lese ein Buch.", "من یک کتاب می‌خوانم."),
        sample(13, "de", "fa", "arbeiten", "کار کردن", "Wir arbeiten zusammen.", "ما با هم کار می‌کنیم."),
        sample(14, "de", "fa", "die Frage", "پرسش", "Das ist eine gute Frage.", "این پرسش خوبی است."),
        sample(15, "de", "fa", "wichtig", "مهم", "Deutsch ist für mich wichtig.", "آلمانی برای من مهم است."),

        sample(16, "de", "en", "das Haus", "house", "Das Haus ist neu.", "The house is new."),
        sample(17, "de", "en", "das Buch", "book", "Das Buch liegt hier.", "The book is here."),
        sample(18, "de", "en", "arbeiten", "work", "Ich arbeite in Berlin.", "I work in Berlin."),
        sample(19, "de", "en", "die Antwort", "answer", "Die Antwort ist richtig.", "The answer is correct."),
        sample(20, "de", "en", "freundlich", "friendly", "Sie ist sehr freundlich.", "She is very friendly."),

        sample(21, "en", "fa", "home", "خانه", "My home is nearby.", "خانهٔ من نزدیک است."),
        sample(22, "en", "fa", "water", "آب", "I need some water.", "من کمی آب نیاز دارم."),
        sample(23, "en", "fa", "learn", "یاد گرفتن", "We learn together.", "ما با هم یاد می‌گیریم."),
        sample(24, "en", "fa", "friend", "دوست", "She is my friend.", "او دوست من است."),
        sample(25, "en", "fa", "important", "مهم", "This meeting is important.", "این جلسه مهم است."),

        sample(26, "en", "de", "house", "das Haus", "The house is old.", "Das Haus ist alt."),
        sample(27, "en", "de", "book", "das Buch", "I am reading a book.", "Ich lese ein Buch."),
        sample(28, "en", "de", "work", "arbeiten", "We work together.", "Wir arbeiten zusammen."),
        sample(29, "en", "de", "question", "die Frage", "I have a question.", "Ich habe eine Frage."),
        sample(30, "en", "de", "friendly", "freundlich", "The doctor is friendly.", "Die Ärztin ist freundlich.")
    ]

    private static func sample(
        _ number: Int,
        _ source: String,
        _ target: String,
        _ sourceText: String,
        _ targetText: String,
        _ sourceExample: String,
        _ targetExample: String
    ) -> PrototypeWord {
        PrototypeWord(
            id: UUID(uuidString: String(format: "71000000-0000-4000-8000-%012d", number))!,
            german: targetText,
            persian: sourceText,
            level: "A1",
            partOfSpeech: "Test",
            example: targetExample,
            exampleTranslation: sourceExample,
            domain: "Multilingual Test",
            sourceLanguageTag: source,
            targetLanguageTag: target
        )
    }

    private static func word(
        _ german: String,
        _ persian: String,
        _ level: String,
        _ partOfSpeech: String,
        _ example: String,
        _ exampleTranslation: String,
        article: String? = nil
    ) -> PrototypeWord {
        PrototypeWord(
            german: german,
            persian: persian,
            article: article,
            level: level,
            partOfSpeech: partOfSpeech,
            example: example,
            exampleTranslation: exampleTranslation
        )
    }
}

enum PrototypeTheme {
    static let accent = Color(red: 0.48, green: 0.24, blue: 0.82)
    static let pink = Color(red: 0.90, green: 0.28, blue: 0.62)
    static let blue = Color(red: 0.18, green: 0.48, blue: 0.92)
    static let mint = Color(red: 0.12, green: 0.68, blue: 0.56)

    static let heroGradient = LinearGradient(
        colors: [accent, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
