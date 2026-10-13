import Foundation

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
