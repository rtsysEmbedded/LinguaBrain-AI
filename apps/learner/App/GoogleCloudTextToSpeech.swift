import Foundation

enum GoogleCloudTTSVoice: String, Sendable {
    case standard = "STANDARD"
}

struct GoogleCloudTTSRequest: Encodable, Sendable {
    struct Input: Encodable, Sendable { let text: String }
    struct Voice: Encodable, Sendable {
        let languageCode: String
        let name: String?
        let ssmlGender: String
    }
    struct AudioConfig: Encodable, Sendable {
        let audioEncoding: String
        let speakingRate: Double
    }

    let input: Input
    let voice: Voice
    let audioConfig: AudioConfig
}

enum GoogleCloudTTSError: LocalizedError, Equatable {
    case missingAPIKey
    case emptyText
    case quotaExceeded
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: PrototypeLocalization.current("tts.error.missingAPIKey")
        case .emptyText: PrototypeLocalization.current("tts.error.emptyText")
        case .quotaExceeded: PrototypeLocalization.current("tts.error.quotaExceeded")
        case .invalidResponse: PrototypeLocalization.current("tts.error.invalidResponse")
        case .requestFailed(let status): PrototypeLocalization.current("tts.error.requestFailed", "\(status)")
        }
    }
}

struct GoogleCloudTextToSpeechClient: Sendable {
    let apiKey: String
    let baseURL: String
    let session: URLSession

    init(apiKey: String, baseURL: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.session = session
    }

    func synthesize(text: String, languageCode: String, voiceName: String? = nil, speakingRate: Double = ProviderCatalog.bundled.googleNativeAudio.speakingRate) async throws -> Data {
        guard !apiKey.isEmpty else { throw GoogleCloudTTSError.missingAPIKey }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw GoogleCloudTTSError.emptyText }
        var components = URLComponents(string: "\(baseURL)/text:synthesize")!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(GoogleCloudTTSRequest(
            input: .init(text: text),
            voice: .init(languageCode: languageCode, name: voiceName, ssmlGender: ProviderCatalog.bundled.googleNativeAudio.ssmlGender),
            audioConfig: .init(audioEncoding: ProviderCatalog.bundled.googleNativeAudio.audioEncoding, speakingRate: speakingRate)
        ))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCloudTTSError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        struct Payload: Decodable { let audioContent: String }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let audio = Data(base64Encoded: payload.audioContent), !audio.isEmpty else {
            throw GoogleCloudTTSError.invalidResponse
        }
        return audio
    }
}

actor PrototypeAudioCache {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LinguaBrain/Audio", isDirectory: true)
    }

    func audio(for key: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(Self.safeFileName(key)))
    }

    func store(_ data: Data, for key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(Self.safeFileName(key)), options: .atomic)
    }

    private static func safeFileName(_ key: String) -> String {
        key.unicodeScalars.map { scalar in
            let allowed = scalar.value == 46 || scalar.value == 45 || scalar.value == 95
                || (48...57).contains(scalar.value) || (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
            return allowed ? String(scalar) : "_"
        }.joined() + ".mp3"
    }
}

struct OpenAIMediaClient: Sendable {
    let baseURL: String
    let apiKey: String
    let session: URLSession

    init(baseURL: String, apiKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
        self.session = session
    }

    func speech(text: String, model: String, voice: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "\(baseURL)/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "input": text, "voice": voice,
            "response_format": ProviderCatalog.bundled.openAICompatibleAudio.responseFormat
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
            throw GoogleCloudTTSError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    func image(prompt: String, model: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "\(baseURL)/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let generation = ProviderCatalog.bundled.imageGeneration
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "prompt": prompt, "size": generation.size, "n": generation.count, "response_format": generation.responseFormat
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleCloudTTSError.requestFailed((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        struct ImageResponse: Decodable { struct Item: Decodable { let b64_json: String? }; let data: [Item] }
        guard let encoded = try? JSONDecoder().decode(ImageResponse.self, from: data).data.first?.b64_json,
              let image = Data(base64Encoded: encoded), !image.isEmpty else {
            throw GoogleCloudTTSError.invalidResponse
        }
        return image
    }
}

/// Single provider boundary for all generated Anki assets.
/// The caller supplies the already-resolved settings and credential; this type
/// contains no provider-name routing or credential storage.
struct AIProviderGateway: Sendable {
    let endpoint: String
    let protocolName: String
    let apiKey: String
    let session: URLSession

    init(endpoint: String, protocolName: String, apiKey: String, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.protocolName = protocolName
        self.apiKey = apiKey
        self.session = session
    }

    func generateCard(word: String, domain: String, model: String, sourceLanguageTag: String, targetLanguageTag: String, context: String? = nil, level: String? = nil) async throws -> ConfiguredProviderCard {
        guard protocolName == "openai-compatible" else { throw ProviderError.unsupportedProtocol }
        return try await ConfiguredProviderClient(baseURL: endpoint, protocolName: protocolName)
            .generateCard(word: word, domain: domain, model: model, apiKey: apiKey,
                          sourceLanguageTag: sourceLanguageTag, targetLanguageTag: targetLanguageTag, context: context, level: level)
    }

    func translateText(_ text: String, model: String, sourceLanguageTag: String, targetLanguageTag: String) async throws -> String {
        guard protocolName == "openai-compatible" else { throw ProviderError.unsupportedProtocol }
        return try await ConfiguredProviderClient(baseURL: endpoint, protocolName: protocolName)
            .translateText(text, model: model, apiKey: apiKey, sourceLanguageTag: sourceLanguageTag, targetLanguageTag: targetLanguageTag)
    }

    func extractImportantWords(from text: String, topic: String, languageTag: String, minimumLevel: String, model: String) async throws -> [String] {
        guard protocolName == "openai-compatible" else { throw ProviderError.unsupportedProtocol }
        return try await ConfiguredProviderClient(baseURL: endpoint, protocolName: protocolName)
            .extractImportantWords(from: text, topic: topic, languageTag: languageTag, minimumLevel: minimumLevel, model: model, apiKey: apiKey)
    }

    func normalizeVocabularyItem(_ surfaceForm: String, passage: String, languageTag: String, model: String) async throws -> NormalizedVocabularyItem {
        guard protocolName == "openai-compatible" else { throw ProviderError.unsupportedProtocol }
        return try await ConfiguredProviderClient(baseURL: endpoint, protocolName: protocolName)
            .normalizeVocabularyItem(surfaceForm, passage: passage, languageTag: languageTag, model: model, apiKey: apiKey)
    }

    func representativeSenseIndexes(for card: ConfiguredProviderCard, model: String) async throws -> [Int] {
        guard protocolName == "openai-compatible" else { throw ProviderError.unsupportedProtocol }
        return try await ConfiguredProviderClient(baseURL: endpoint, protocolName: protocolName)
            .representativeSenseIndexes(for: card, model: model, apiKey: apiKey)
    }

    func synthesizeSpeech(text: String, model: String, voice: String) async throws -> Data {
        switch protocolName {
        case "google-native":
            let languageCode = voice.split(separator: "-").prefix(2).joined(separator: "-")
            return try await GoogleCloudTextToSpeechClient(
                apiKey: apiKey,
                baseURL: endpoint,
                session: session
            ).synthesize(text: text, languageCode: languageCode, voiceName: voice)
        case "openai-compatible":
            return try await OpenAIMediaClient(baseURL: endpoint, apiKey: apiKey, session: session)
                .speech(text: text, model: model, voice: voice)
        default:
            throw ProviderError.unsupportedProtocol
        }
    }

    func generateImage(prompt: String, model: String) async throws -> Data {
        try await OpenAIMediaClient(baseURL: endpoint, apiKey: apiKey, session: session)
            .image(prompt: prompt, model: model)
    }
}
