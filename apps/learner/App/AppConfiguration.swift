import Foundation
import LinguaBrainApplication

/// Loads editable configuration files bundled from `Resources/Configuration`.
///
/// Values in these files must not be duplicated in source code. A missing or
/// malformed file is a packaging error, so loading stops with a diagnostic
/// instead of silently falling back to a second, hardcoded copy.
enum AppConfigurationResource {
    static func load<Value: Decodable>(_ type: Value.Type, named name: String, bundle: Bundle = .main) -> Value {
        // Xcode copies grouped resources to the bundle root; keep the
        // subdirectory lookup as a compatibility path for other packaging.
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Configuration")
        guard let url else {
            preconditionFailure("Missing bundled configuration \(name).json")
        }
        do {
            return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
        } catch {
            preconditionFailure("Invalid bundled configuration \(name).json: \(error)")
        }
    }
}

/// Provider endpoints, model identifiers, voices, and request parameters.
/// Source: `Resources/Configuration/provider-catalog.json`.
struct ProviderCatalog: Decodable, Sendable {
    struct Endpoints: Decodable, Sendable {
        let text: String
        let image: String
        let realtimeTranscription: String
    }

    struct Models: Decodable, Sendable {
        let text: String
        let image: String
        let speech: String
        let transcript: String
        let stream: String
    }

    struct ModelLists: Decodable, Sendable {
        let speech: [String]
        let transcript: [String]
        let stream: [String]
    }

    struct OpenAICompatibleAudio: Decodable, Sendable {
        let voice: String
        let responseFormat: String
    }

    struct GoogleNativeAudio: Decodable, Sendable {
        let voice: String
        let speechModel: String
        let ssmlGender: String
        let audioEncoding: String
        let speakingRate: Double
    }

    struct HostMarkers: Decodable, Sendable {
        let openAI: String
        let googleTextToSpeech: String
        let legacyGoogleVoice: String
        let replacedTextEndpoints: [String]
    }

    struct RequestProfile: Decodable, Sendable {
        let timeoutSeconds: Double
        let temperature: Double
        let maxTokens: Int?
    }

    struct Requests: Decodable, Sendable {
        let translateText: RequestProfile
        let extractImportantWords: RequestProfile
        let normalizeVocabularyItem: RequestProfile
        let representativeSenses: RequestProfile
        let generateCard: RequestProfile
        let translate: RequestProfile
        let streamTranslate: RequestProfile
    }

    struct VocabularyExtraction: Decodable, Sendable {
        let minimumConfidence: Double
    }

    struct CardGeneration: Decodable, Sendable {
        let maximumPassageCharacters: Int
        /// A passage word whose dictionary form the model normalized with a
        /// lower confidence is not turned into a card.
        let minimumNormalizationConfidence: Double
    }

    struct ImageGeneration: Decodable, Sendable {
        let size: String
        let count: Int
        let responseFormat: String
    }

    struct RealtimeTranscription: Decodable, Sendable {
        enum LanguageField: String, Decodable, Sendable {
            /// A single ISO 639-1 hint: `"language": "de"`.
            case language
            /// A list of hints: `"languages": ["de"]`.
            case languages
        }

        struct Profile: Decodable, Sendable {
            let languageField: LanguageField?
            let delay: String?
        }

        let connectionTimeoutSeconds: Int
        let noiseReduction: String
        let supportedModels: [String]
        let profiles: [String: Profile]
        let defaultProfile: Profile

        /// Builds the `transcription` object of a Realtime session update for `model`.
        func configuration(model: String, languageTag: String) -> [String: Any] {
            let profile = profiles[model] ?? defaultProfile
            var configuration: [String: Any] = ["model": model]
            switch profile.languageField {
            case .language: configuration["language"] = languageTag
            case .languages: configuration["languages"] = [languageTag]
            case nil: break
            }
            if let delay = profile.delay { configuration["delay"] = delay }
            return configuration
        }
    }

    let schemaVersion: Int
    let defaultMode: String
    let defaultProtocol: String
    let endpoints: Endpoints
    let models: Models
    let defaultModelOptions: ModelLists
    let preferredModelOrder: ModelLists
    let openAICompatibleAudio: OpenAICompatibleAudio
    let googleNativeAudio: GoogleNativeAudio
    let hostMarkers: HostMarkers
    let requests: Requests
    let vocabularyExtraction: VocabularyExtraction
    let cardGeneration: CardGeneration
    let imageGeneration: ImageGeneration
    let realtimeTranscription: RealtimeTranscription

    static let bundled = AppConfigurationResource.load(ProviderCatalog.self, named: "provider-catalog")
}

/// Prompt templates and topic scopes sent to text and image providers.
/// Source: `Resources/Configuration/ai-prompts.json`.
struct AIPromptCatalog: Decodable, Sendable {
    struct Templates: Decodable, Sendable {
        let translateText: String
        let extractImportantWords: String
        let normalizeVocabularyItem: String
        let representativeSenses: String
        let generateCardCategoryScope: String
        let generateCardLanguageContract: String
        let generateCardPassageContext: String
        let generateCardNoPassageContext: String
        let generateCardMinimumLevel: String
        let generateCardSystem: String
        let generateCardUser: String
        let translate: String
        let streamTranslate: String
        let a1ImageIllustration: String
        let cardImageIllustration: String
        let generateCardSchemaRetry: String
        let generateCardSourceLanguageRetry: String
    }

    /// A topic scope applies when the folded domain equals one of `equals`
    /// or contains one of `contains`. The first matching entry wins.
    struct CategoryScope: Decodable, Sendable {
        let equals: [String]
        let contains: [String]
        let scope: String
    }

    let schemaVersion: Int
    let templates: Templates
    let categoryScopes: [CategoryScope]
    let defaultCategoryScope: String

    static let bundled = AppConfigurationResource.load(AIPromptCatalog.self, named: "ai-prompts")

    /// Resolves the topic scope for a learner category.
    func categoryScope(for domain: String) -> String {
        let normalized = domain.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let match = categoryScopes.first { entry in
            entry.equals.contains(normalized) || entry.contains.contains { normalized.contains($0) }
        }
        return match?.scope ?? PromptTemplate.render(defaultCategoryScope, ["domain": domain])
    }
}

/// Defaults, stored identifiers, and classification terms for learner content.
/// Source: `Resources/Configuration/content-rules.json`.
///
/// `deckNames`, `defaults.domain`, and `genericDomainNames` are compared with
/// values already persisted on learners' devices. Changing them after release
/// orphans existing records, so treat them as stable identifiers.
struct LearningContentRules: Decodable, Sendable {
    struct Defaults: Decodable, Sendable {
        let sourceLanguageTag: String
        let targetLanguageTag: String
        let domain: String
    }

    struct DeckNames: Decodable, Sendable {
        let core: String
        let generated: String
        let multilingual: String
        /// Deck for restored iCloud cards whose deck no longer exists.
        let cloudFallback: String
    }

    struct DomainKeywords: Decodable, Sendable {
        let domain: String
        let terms: [String]
    }

    struct Levels: Decodable, Sendable {
        /// Ordered CEFR scale used for level comparisons and model output.
        let cefr: [String]
        /// Minimum levels offered for card generation from words or a passage.
        let cardGeneration: [String]
        let cardGenerationDefault: String

        /// Whether `actual` is at or above `minimum` on the CEFR scale.
        /// Unknown levels never qualify.
        func meets(_ actual: String, minimum: String) -> Bool {
            guard let actualIndex = cefr.firstIndex(of: actual.uppercased()),
                  let minimumIndex = cefr.firstIndex(of: minimum.uppercased()) else { return false }
            return actualIndex >= minimumIndex
        }
    }

    /// Inputs and coefficients of Today's daily plan. The input scales
    /// (energy 1–10, motivation 1–5) are part of the stored daily state and
    /// stay in code.
    struct DailyPlan: Decodable, Sendable {
        struct ModeFactors: Decodable, Sendable {
            let lightReview: Double
            let balanced: Double
            let challenge: Double
        }

        let defaultEnergy: Double
        let defaultAvailableMinutes: Int
        let defaultMotivation: Int
        let availableMinuteOptions: [Int]
        let minutesPerNewCard: Double
        let energyFactorBase: Double
        let energyFactorDivisor: Double
        let motivationFactorBase: Double
        let motivationFactorStep: Double
        let modeFactors: ModeFactors
        let maximumNewCards: Int
        /// Energy at or below this value selects the recovery mode label.
        let recoveryEnergyAtMost: Double
        /// Energy at or above this value selects the challenge mode label.
        let challengeEnergyAtLeast: Double

        /// Today's time choice derived from the learner's daily goal: the
        /// largest option that does not exceed the goal.
        func availableMinutes(forDailyGoal goal: Int) -> Int {
            availableMinuteOptions.filter { $0 <= goal }.max() ?? availableMinuteOptions.min() ?? defaultAvailableMinutes
        }

        /// New cards suggested for one session, before the unreviewed-card cap.
        func newCardCount(energy: Double, availableMinutes: Int, motivation: Int, modeRawValue: String) -> Int {
            let energyFactor = energyFactorBase + (energy / energyFactorDivisor)
            let timeCapacity = Double(availableMinutes) / minutesPerNewCard
            let motivationFactor = motivationFactorBase + (Double(motivation - 1) * motivationFactorStep)
            let modeFactor = switch LearningSessionMode(rawValue: modeRawValue) {
            case .lightReview: modeFactors.lightReview
            case .challenge: modeFactors.challenge
            case .balanced, nil: modeFactors.balanced
            }
            return max(0, min(maximumNewCards, Int((timeCapacity * energyFactor * motivationFactor * modeFactor).rounded())))
        }
    }

    struct Onboarding: Decodable, Sendable {
        /// Current-level choices. Values outside `levels.cefr` are shown with
        /// the localization key `onboarding.level.<value>`.
        let levels: [String]
        let defaultLevel: String
        /// Localization keys of the learning goals.
        let missionKeys: [String]
        let defaultMissionKey: String
    }

    struct AddWord: Decodable, Sendable {
        /// Word prefilled in the single-word field.
        let initialWord: String
        /// Topic preselected for single-word and batch generation.
        let defaultTopic: String
        /// Package name used when the export name field is empty (without `.apkg`).
        let defaultExportFileName: String
    }

    struct LearnerProfile: Decodable, Sendable {
        struct PlaybackRate: Decodable, Sendable {
            let minimum: Double
            let maximum: Double
            let step: Double
            let defaultValue: Double
        }

        /// Target level shown until the learner chooses one.
        let defaultTargetLevel: String
        let dailyGoalMinuteOptions: [Int]
        let defaultDailyGoalMinutes: Int
        /// Multiplier applied to card audio and speech synthesis.
        let playbackRate: PlaybackRate
    }

    struct Speech: Decodable, Sendable {
        /// Factor applied to the default speech rate for "play slowly".
        let slowReplayFactor: Double
    }


    let schemaVersion: Int
    let defaults: Defaults
    let deckNames: DeckNames
    let classifierFallbackDomain: String
    let genericDomainNames: [String]
    let nounPartOfSpeechMarkers: [String]
    let verbPartOfSpeechMarkers: [String]
    let domainKeywords: [DomainKeywords]
    let levels: Levels
    let onboarding: Onboarding
    let addWord: AddWord
    /// A reviewed card whose memory strength is below this value is weak.
    let weakStrengthThreshold: Double
    let dailyPlan: DailyPlan
    let learnerProfile: LearnerProfile
    let speech: Speech

    static let bundled = AppConfigurationResource.load(LearningContentRules.self, named: "content-rules")
}

/// Built-in sample cards seeded into an empty installation.
/// Source: `Resources/Configuration/seed-cards.json`.
struct SeedCardCatalog: Decodable, Sendable {
    struct Word: Decodable, Sendable {
        let german: String
        let persian: String
        let level: String
        let partOfSpeech: String
        let example: String
        let exampleTranslation: String
        let article: String?
    }

    struct MultilingualSampleDefaults: Decodable, Sendable {
        /// Sample `number` is appended as 12 zero-padded digits to form a stable UUID.
        let idPrefix: String
        let level: String
        let partOfSpeech: String
        let domain: String
    }

    struct MultilingualSample: Decodable, Sendable {
        let number: Int
        let sourceLanguageTag: String
        let targetLanguageTag: String
        let source: String
        let target: String
        let sourceExample: String
        let targetExample: String
    }

    let schemaVersion: Int
    let words: [Word]
    let multilingualSampleDefaults: MultilingualSampleDefaults
    let multilingualSamples: [MultilingualSample]

    static let bundled = AppConfigurationResource.load(SeedCardCatalog.self, named: "seed-cards")
}

enum PromptTemplate {
    /// Replaces `{name}` placeholders in a single pass. Substituted values are
    /// never scanned again, so learner text that contains braces is preserved.
    /// Unknown placeholders are left unchanged.
    static func render(_ template: String, _ values: [String: String]) -> String {
        var result = ""
        var remainder = template[...]
        while let open = remainder.firstIndex(of: "{") {
            result += remainder[..<open]
            let afterOpen = remainder.index(after: open)
            guard let close = remainder[afterOpen...].firstIndex(of: "}") else {
                result += remainder[open...]
                return result
            }
            let name = String(remainder[afterOpen..<close])
            if let value = values[name] {
                result += value
            } else {
                result += remainder[open...close]
            }
            remainder = remainder[remainder.index(after: close)...]
        }
        result += remainder
        return result
    }
}
