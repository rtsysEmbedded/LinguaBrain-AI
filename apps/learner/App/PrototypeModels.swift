import Foundation
import SwiftUI

enum PrototypeSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case library
    case add
    case progress
    case settings

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
    let id = UUID()
    let german: String
    let persian: String
    let article: String?
    let level: String
    let partOfSpeech: String
    let example: String
    let exampleTranslation: String
    let strength: Double
    let isDue: Bool
}

enum PrototypeData {
    static let words: [PrototypeWord] = [
        .init(
            german: "arbeiten",
            persian: "کار کردن",
            article: nil,
            level: "A1",
            partOfSpeech: "Verb",
            example: "Ich arbeite heute von zu Hause.",
            exampleTranslation: "من امروز از خانه کار می‌کنم.",
            strength: 0.72,
            isDue: true
        ),
        .init(
            german: "die Entscheidung",
            persian: "تصمیم",
            article: "die",
            level: "B1",
            partOfSpeech: "Nomen",
            example: "Wir treffen morgen eine Entscheidung.",
            exampleTranslation: "ما فردا تصمیم می‌گیریم.",
            strength: 0.44,
            isDue: true
        ),
        .init(
            german: "zuverlässig",
            persian: "قابل اعتماد",
            article: nil,
            level: "B1",
            partOfSpeech: "Adjektiv",
            example: "Sie ist eine sehr zuverlässige Kollegin.",
            exampleTranslation: "او همکار بسیار قابل اعتمادی است.",
            strength: 0.87,
            isDue: false
        ),
        .init(
            german: "der Arbeitsvertrag",
            persian: "قرارداد کاری",
            article: "der",
            level: "B2",
            partOfSpeech: "Nomen",
            example: "Bitte lesen Sie den Arbeitsvertrag sorgfältig.",
            exampleTranslation: "لطفاً قرارداد کاری را با دقت بخوانید.",
            strength: 0.31,
            isDue: true
        )
    ]
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
