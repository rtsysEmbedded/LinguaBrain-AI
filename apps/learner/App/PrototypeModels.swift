import Foundation
import Observation
import SwiftUI

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

    var previewInterval: String {
        switch self {
        case .again: "کمتر از ۱ دقیقه"
        case .hard: "۶ دقیقه"
        case .good: "۱ روز"
        case .easy: "۴ روز"
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
    private(set) var grades: [UUID: [PrototypeReviewGrade]] = [:]

    let words = PrototypeData.words

    var reviewedCount: Int { grades.values.filter { !$0.isEmpty }.count }
    var unreviewedCount: Int { words.count - reviewedCount }
    var dueCount: Int {
        words.filter { word in
            guard let last = grades[word.id]?.last else { return true }
            return last == .again || last == .hard
        }.count
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
        grades[word.id]?.last?.strength ?? 0
    }

    func reviewCount(for word: PrototypeWord) -> Int {
        grades[word.id]?.count ?? 0
    }

    func lastGrade(for word: PrototypeWord) -> PrototypeReviewGrade? {
        grades[word.id]?.last
    }

    func record(_ grade: PrototypeReviewGrade, for word: PrototypeWord) {
        grades[word.id, default: []].append(grade)
    }

    func reset() {
        grades.removeAll()
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
