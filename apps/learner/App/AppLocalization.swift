import Foundation
import Observation
import SwiftUI

enum PrototypeAppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case german = "de"
    case persian = "fa"

    var id: Self { self }
    var locale: Locale { Locale(identifier: rawValue) }
    var layoutDirection: LayoutDirection { self == .persian ? .rightToLeft : .leftToRight }

    var nativeName: String {
        switch self {
        case .english: "English"
        case .german: "Deutsch"
        case .persian: "فارسی"
        }
    }
}

enum PrototypeTextKey: String, CaseIterable, Sendable {
    case today, library, add, progress, settings
    case settingsTitle, learningAndLanguage, learningAndLanguageSubtitle
    case languagesAndLevel, goalsAndDailyPlan, reviewAndPractice, audioAndPronunciation
    case interfaceLanguage, explanationLanguage, learningLanguage, currentLevel, targetLevel
    case languageSettings, learnerSubtitle, deviceOnlySync, edit
}

@Observable
final class PrototypeLocalization {
    private enum Key { static let language = "prototype.interfaceLanguage" }
    private let defaults: UserDefaults

    var language: PrototypeAppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = defaults.string(forKey: Key.language)
            .flatMap(PrototypeAppLanguage.init(rawValue:)) ?? .persian
    }

    func text(_ key: PrototypeTextKey) -> String {
        Self.text(key, language: language)
    }

    static func text(_ key: PrototypeTextKey, language: PrototypeAppLanguage) -> String {
        translations[language]?[key] ?? translations[.english]![key]!
    }

    private static let translations: [PrototypeAppLanguage: [PrototypeTextKey: String]] = [
        .english: [
            .today: "Today", .library: "Library", .add: "Add", .progress: "Progress", .settings: "Settings",
            .settingsTitle: "Settings", .learningAndLanguage: "Learning and language",
            .learningAndLanguageSubtitle: "Learning path and practice preferences",
            .languagesAndLevel: "Languages and level", .goalsAndDailyPlan: "Goals and daily plan",
            .reviewAndPractice: "Review and practice", .audioAndPronunciation: "Audio and pronunciation",
            .interfaceLanguage: "Interface language", .explanationLanguage: "Explanation language",
            .learningLanguage: "Learning language", .currentLevel: "Current level", .targetLevel: "Target level",
            .languageSettings: "Language settings", .learnerSubtitle: "German learner · B1",
            .deviceOnlySync: "On-device sync only", .edit: "Edit"
        ],
        .german: [
            .today: "Heute", .library: "Bibliothek", .add: "Hinzufügen", .progress: "Fortschritt", .settings: "Einstellungen",
            .settingsTitle: "Einstellungen", .learningAndLanguage: "Lernen und Sprachen",
            .learningAndLanguageSubtitle: "Lernweg und Übungseinstellungen",
            .languagesAndLevel: "Sprachen und Niveau", .goalsAndDailyPlan: "Ziele und Tagesplan",
            .reviewAndPractice: "Wiederholen und Üben", .audioAndPronunciation: "Audio und Aussprache",
            .interfaceLanguage: "Sprache der Oberfläche", .explanationLanguage: "Erklärungssprache",
            .learningLanguage: "Lernsprache", .currentLevel: "Aktuelles Niveau", .targetLevel: "Zielniveau",
            .languageSettings: "Spracheinstellungen", .learnerSubtitle: "Deutschlernender · B1",
            .deviceOnlySync: "Nur auf diesem Gerät", .edit: "Bearbeiten"
        ],
        .persian: [
            .today: "امروز", .library: "کتابخانه", .add: "افزودن", .progress: "پیشرفت", .settings: "تنظیمات",
            .settingsTitle: "تنظیمات", .learningAndLanguage: "یادگیری و زبان",
            .learningAndLanguageSubtitle: "مسیر آموزشی و شیوهٔ تمرین",
            .languagesAndLevel: "زبان‌ها و سطح", .goalsAndDailyPlan: "هدف‌ها و برنامهٔ روزانه",
            .reviewAndPractice: "مرور و تمرین", .audioAndPronunciation: "صدا و تلفظ",
            .interfaceLanguage: "زبان رابط", .explanationLanguage: "زبان توضیحات",
            .learningLanguage: "زبان یادگیری", .currentLevel: "سطح فعلی", .targetLevel: "سطح هدف",
            .languageSettings: "تنظیمات زبان", .learnerSubtitle: "یادگیرندهٔ آلمانی · سطح B1",
            .deviceOnlySync: "همگام‌سازی فقط روی دستگاه", .edit: "ویرایش"
        ]
    ]
}

@Observable
final class PrototypeLanguageSettings {
    private enum Key {
        static let source = "prototype.sourceLanguageTag"
        static let target = "prototype.targetLanguageTag"
    }

    private let defaults: UserDefaults

    var sourceLanguageTag: String {
        didSet { defaults.set(sourceLanguageTag, forKey: Key.source) }
    }

    var targetLanguageTag: String {
        didSet { defaults.set(targetLanguageTag, forKey: Key.target) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sourceLanguageTag = defaults.string(forKey: Key.source) ?? "fa"
        targetLanguageTag = defaults.string(forKey: Key.target) ?? "de"
    }

    var isValidPair: Bool { sourceLanguageTag != targetLanguageTag }
}
