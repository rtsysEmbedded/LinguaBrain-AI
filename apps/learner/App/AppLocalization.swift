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
    case coachSuggestion, coachReset, coachProgress, reviewLabel, reverseTranslation, reversePractice
    case reviewPrompt, reversePrompt, revealAnswer, answerRating
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
            .flatMap(PrototypeAppLanguage.init(rawValue:)) ?? .english
    }

    func text(_ key: PrototypeTextKey) -> String {
        localized(key.rawValue)
    }

    /// Resolves view copy from the String Catalog using the language selected
    /// inside LinguaBrain, independently of the device language.
    func localized(_ key: String) -> String {
        if let value = Self.jsonTranslations[language]?[key] ?? Self.jsonTranslations[.english]?[key] {
            return value
        }
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    func minutes(_ count: Int) -> String {
        switch language {
        case .english: "\(count) min"
        case .german: "\(count) Min."
        case .persian: "\(count) دقیقه"
        }
    }

    func duration(_ seconds: Int) -> String {
        let value: Int
        let unit: String
        if seconds < 60 { value = seconds; unit = "second" }
        else if seconds < 3_600 { value = Int((Double(seconds) / 60).rounded()); unit = "minute" }
        else if seconds < 86_400 { value = Int((Double(seconds) / 3_600).rounded()); unit = "hour" }
        else if seconds < 31_536_000 { value = Int((Double(seconds) / 86_400).rounded()); unit = "day" }
        else { value = Int((Double(seconds) / 31_536_000).rounded()); unit = "year" }
        return localized("duration.\(unit)").replacingOccurrences(of: "%d", with: "\(value)")
    }

    func reviewSummary(due: Int, new: Int) -> String {
        switch language {
        case .english: "\(due) reviews + \(new) new cards"
        case .german: "\(due) Wiederholungen + \(new) neue Karten"
        case .persian: "\(due) مرور + \(new) کارت جدید"
        }
    }

    func coachMessage(reviewed: Int, weak: Int) -> String {
        if reviewed == 0 { return localized("coach.reset") }
        return localized("coach.progress").replacingOccurrences(of: "%1$d", with: "\(reviewed)").replacingOccurrences(of: "%2$d", with: "\(weak)")
    }

    static func text(_ key: PrototypeTextKey, language: PrototypeAppLanguage) -> String {
        jsonTranslations[language]?[key.rawValue] ?? jsonTranslations[.english]?[key.rawValue] ?? key.rawValue
    }

    /// All editable interface copy lives in Resources/Localization/*.json.
    /// Keeping the loader here makes submenu and screen copy use the same fallback rules.
    private static let jsonTranslations: [PrototypeAppLanguage: [String: String]] = {
        Dictionary(uniqueKeysWithValues: PrototypeAppLanguage.allCases.map { language in
            // Xcode copies grouped JSON resources to the bundle root; keep the
            // subdirectory lookup as a compatibility path for other packaging.
            let url = Bundle.main.url(forResource: language.rawValue, withExtension: "json")
                ?? Bundle.main.url(forResource: language.rawValue, withExtension: "json", subdirectory: "Localization")
            let values = url.flatMap { try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: $0)) } ?? [:]
            return (language, values)
        })
    }()

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

    func selectSource(_ tag: String) {
        if tag == targetLanguageTag { targetLanguageTag = sourceLanguageTag }
        sourceLanguageTag = tag
    }

    func selectTarget(_ tag: String) {
        if tag == sourceLanguageTag { sourceLanguageTag = targetLanguageTag }
        targetLanguageTag = tag
    }
}
