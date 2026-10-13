import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

public struct SentenceAudioKey: Hashable, Sendable { public let sentenceID: UUID; public let revision: Int; public let textHash: String; public let language: String; public let voice: String; public let model: String; public init(sentenceID: UUID, revision: Int, textHash: String, language: String, voice: String, model: String) { self.sentenceID=sentenceID; self.revision=revision; self.textHash=textHash; self.language=language; self.voice=voice; self.model=model } }
public protocol SentenceAudioCache: Sendable { func audio(for key: SentenceAudioKey) async throws -> MediaAsset?; func save(_ asset: MediaAsset, for key: SentenceAudioKey) async throws }
public protocol SentenceAudioGenerator: Sendable { func generate(sentence: Sentence, language: String, voice: String, model: String, rate: Double) async throws -> MediaAsset }
public enum SentenceAudioError: Error, Equatable { case missingSentence, invalidLocale, invalidRate, unavailable, cancelled }
public actor SentenceAudioService {
    private let cache: any SentenceAudioCache; private let generator: any SentenceAudioGenerator
    public init(cache: any SentenceAudioCache, generator: any SentenceAudioGenerator) { self.cache=cache; self.generator=generator }
    public func play(sentence: Sentence?, language: String, voice: String, model: String, rate: Double = 1) async throws -> MediaAsset {
        guard let sentence, !sentence.text.isEmpty else { throw SentenceAudioError.missingSentence }
        guard !language.isEmpty, (0.5...2).contains(rate) else { throw language.isEmpty ? SentenceAudioError.invalidLocale : SentenceAudioError.invalidRate }
        let key = SentenceAudioKey(sentenceID: sentence.id, revision: sentence.revision, textHash: stableTextHash(sentence.text), language: language, voice: voice, model: model)
        if let cached = try await cache.audio(for: key) { return cached }
        let asset = try await generator.generate(sentence: sentence, language: language, voice: voice, model: model, rate: rate)
        try await cache.save(asset, for: key); return asset
    }
    public func stop() {}
    private func stableTextHash(_ text: String) -> String { var value: UInt64 = 14695981039346656037; for byte in text.utf8 { value = (value ^ UInt64(byte)) &* 1099511628211 }; return String(value, radix: 16) }
}
