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

    /// The language's own name (endonym), read from the localization catalog.
    var nativeName: String {
        PrototypeLocalization.localized("language.nativeName.\(rawValue)", language: self)
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
    /// Interface language used before the learner selects one.
    private static let defaultLanguage = PrototypeAppLanguage.english
    private let defaults: UserDefaults

    var language: PrototypeAppLanguage {
        didSet { defaults.set(language.rawValue, forKey: Key.language) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = Self.storedLanguage(in: defaults)
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

    /// Resolves a catalog entry and substitutes `%1$@`, `%2$@`, … or, when the
    /// entry has no positional markers, each `%@` in order.
    func formatted(_ key: String, _ arguments: String...) -> String {
        Self.substitute(localized(key), arguments)
    }

    func minutes(_ count: Int) -> String {
        formatted("time.minutesShort", "\(count)")
    }

    /// "20 minutes" with digits in the interface language's numbering system.
    func minutesLong(_ count: Int) -> String {
        formatted("time.minutesLong", count.formatted(.number.locale(language.locale)))
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
        formatted("today.reviewSummary", "\(due)", "\(new)")
    }

    func coachMessage(reviewed: Int, weak: Int) -> String {
        if reviewed == 0 { return localized("coach.reset") }
        return localized("coach.progress").replacingOccurrences(of: "%1$d", with: "\(reviewed)").replacingOccurrences(of: "%2$d", with: "\(weak)")
    }

    static func text(_ key: PrototypeTextKey, language: PrototypeAppLanguage) -> String {
        localized(key.rawValue, language: language)
    }

    static func localized(_ key: String, language: PrototypeAppLanguage) -> String {
        jsonTranslations[language]?[key] ?? jsonTranslations[.english]?[key] ?? key
    }

    /// Catalog lookup for code outside the SwiftUI environment, such as models
    /// and error descriptions. Views use the injected instance so that a
    /// language change re-renders them.
    static func current(_ key: String, _ arguments: String...) -> String {
        substitute(localized(key, language: currentLanguage), arguments)
    }

    /// The persisted interface language, for formatting outside the SwiftUI environment.
    static var currentLanguage: PrototypeAppLanguage {
        storedLanguage(in: .standard)
    }

    /// Replaces `%@` (in order) and `%n$@` (by position) with `arguments`.
    /// Matching works on Unicode scalars, so a placeholder followed by a
    /// combining character such as ZWNJ is still recognised; substituted
    /// text is never scanned again.
    static func substitute(_ template: String, _ arguments: [String]) -> String {
        guard !arguments.isEmpty else { return template }
        let asciiDigits: ClosedRange<Unicode.Scalar> = "0"..."9"
        let scalars = Array(template.unicodeScalars)
        var output = String.UnicodeScalarView()
        var nextSequential = 0
        var index = 0
        while index < scalars.count {
            guard scalars[index] == "%" else {
                output.append(scalars[index])
                index += 1
                continue
            }
            var cursor = index + 1
            var position = 0
            while cursor < scalars.count, asciiDigits.contains(scalars[cursor]) {
                position = position * 10 + Int(scalars[cursor].value - asciiDigits.lowerBound.value)
                cursor += 1
            }
            if cursor > index + 1, cursor + 1 < scalars.count, scalars[cursor] == "$", scalars[cursor + 1] == "@",
               position >= 1, position <= arguments.count {
                output.append(contentsOf: arguments[position - 1].unicodeScalars)
                index = cursor + 2
            } else if cursor == index + 1, cursor < scalars.count, scalars[cursor] == "@",
                      nextSequential < arguments.count {
                output.append(contentsOf: arguments[nextSequential].unicodeScalars)
                nextSequential += 1
                index = cursor + 1
            } else {
                output.append(scalars[index])
                index += 1
            }
        }
        return String(output)
    }

    private static func storedLanguage(in defaults: UserDefaults) -> PrototypeAppLanguage {
        defaults.string(forKey: Key.language).flatMap(PrototypeAppLanguage.init(rawValue:)) ?? defaultLanguage
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
        sourceLanguageTag = defaults.string(forKey: Key.source) ?? LearningContentRules.bundled.defaults.sourceLanguageTag
        targetLanguageTag = defaults.string(forKey: Key.target) ?? LearningContentRules.bundled.defaults.targetLanguageTag
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
