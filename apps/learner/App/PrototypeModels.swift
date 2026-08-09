import Foundation
import Observation
import SwiftData
import SwiftUI

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
    case today, library, add, progress, settings

    var id: Self { self }

    var title: String {
        switch self {
        case .today: "امروز"
        case .library: "کتابخانه"
        case .add: "افزودن"
        case .progress: "پیشرفت"
        case .settings: "تنظیمات"
        }
    }

    var symbol: String {
        switch self {
        case .today: "sparkles"
        case .library: "books.vertical.fill"
        case .add: "plus.circle.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape.fill"
        }
    }
}

struct PrototypeWord: Identifiable, Hashable {
    let id: UUID
    let german: String
    let persian: String
    let article: String?
    let level: String
    let partOfSpeech: String
    let example: String
    let exampleTranslation: String

    init(
        id: UUID = UUID(),
        german: String,
        persian: String,
        article: String? = nil,
        level: String,
        partOfSpeech: String,
        example: String,
        exampleTranslation: String
    ) {
        self.id = id
        self.german = german
        self.persian = persian
        self.article = article
        self.level = level
        self.partOfSpeech = partOfSpeech
        self.example = example
        self.exampleTranslation = exampleTranslation
    }
}

enum PrototypeReviewGrade: String, CaseIterable, Identifiable, Hashable {
    case again, hard, good, easy

    var id: Self { self }

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

@MainActor
@Observable
final class PrototypeStore {
    private(set) var grades: [String: [PrototypeReviewGrade]] = [:]
    private(set) var dueDates: [String: Date] = [:]
    private(set) var memoryStates: [String: PrototypeFSRSMemoryState] = [:]
    private(set) var lastPersistenceError: String?

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let scheduler = PrototypeFSRS6Scheduler()

    let words = PrototypeData.words

    init(inMemory: Bool = false) {
        assert(
            PrototypeFSRS6Scheduler.passesReferenceVectors(),
            "FSRS-6 reference vectors do not match the pinned implementation."
        )
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
            modelContainer = try ModelContainer(
                for: PrototypeReviewRecord.self,
                configurations: configuration
            )
            modelContext = ModelContext(modelContainer)
            restorePersistedReviews()
        } catch {
            fatalError("Unable to initialize the review store: \(error.localizedDescription)")
        }
    }

    var reviewedCount: Int { grades.values.filter { !$0.isEmpty }.count }
    var unreviewedCount: Int { words.count - reviewedCount }
    var dueCount: Int {
        words.filter { isReviewable($0) }.count
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

    func strength(for word: PrototypeWord) -> Double {
        guard let state = memoryStates[word.storageKey] else {
            return grades[word.storageKey]?.last?.strength ?? 0
        }
        return scheduler.retrievability(state: state, at: .now)
    }

    func reviewCount(for word: PrototypeWord) -> Int {
        grades[word.storageKey]?.count ?? 0
    }

    func lastGrade(for word: PrototypeWord) -> PrototypeReviewGrade? {
        grades[word.storageKey]?.last
    }

    func dueDate(for word: PrototypeWord) -> Date? {
        dueDates[word.storageKey]
    }

    func previewSchedule(
        for grade: PrototypeReviewGrade,
        word: PrototypeWord,
        at date: Date = .now
    ) -> PrototypeFSRSSchedule {
        scheduler.schedule(previous: memoryStates[word.storageKey], grade: grade, now: date)
    }

    func shouldRepeatInCurrentSession(_ word: PrototypeWord) -> Bool {
        guard let state = memoryStates[word.storageKey], let dueDate = dueDates[word.storageKey] else {
            return false
        }
        return (state.phase == .learning || state.phase == .relearning)
            && dueDate.timeIntervalSince(state.lastReview) < 86_400
    }

    func isReviewable(_ word: PrototypeWord, at date: Date = .now) -> Bool {
        guard reviewCount(for: word) > 0 else { return true }
        guard let dueDate = dueDates[word.storageKey] else { return true }
        return dueDate <= date
    }

    @discardableResult
    func record(
        _ grade: PrototypeReviewGrade,
        for word: PrototypeWord,
        at date: Date = .now
    ) -> PrototypeFSRSSchedule? {
        let schedule = previewSchedule(for: grade, word: word, at: date)
        let record = PrototypeReviewRecord(
            wordKey: word.storageKey,
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

        do {
            try modelContext.save()
            grades[word.storageKey, default: []].append(grade)
            dueDates[word.storageKey] = schedule.dueAt
            memoryStates[word.storageKey] = schedule.state
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

    private func restorePersistedReviews() {
        do {
            let descriptor = FetchDescriptor<PrototypeReviewRecord>(
                sortBy: [SortDescriptor(\.reviewedAt)]
            )
            let records = try modelContext.fetch(descriptor)

            for record in records {
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
            lastPersistenceError = nil
        } catch {
            lastPersistenceError = "بازیابی اطلاعات مرور انجام نشد: \(error.localizedDescription)"
        }
    }
}

private extension PrototypeWord {
    var storageKey: String {
        german.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
