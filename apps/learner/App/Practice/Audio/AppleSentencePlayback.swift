import AVFAudio
import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

enum AppleSentencePlaybackError: Error, Equatable {
    case missingSentence
    case invalidLocale
}

/// System speech adapter at the app boundary. The sentence text and revision
/// are the only synthesis source; word pronunciation media is never used as a
/// fallback for a missing sentence.
actor AppleSentencePlayback: PracticeSentencePlayback {
    private let synthesizer = AVSpeechSynthesizer()
    private let locale: String
    private let voiceIdentifier: String?

    init(locale: String, voiceIdentifier: String? = nil) {
        self.locale = locale
        self.voiceIdentifier = voiceIdentifier
    }

    func sentenceAudio(for sentence: Sentence) async throws -> MediaAsset {
        try Task.checkCancellation()
        guard !sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleSentencePlaybackError.missingSentence
        }
        guard Locale(identifier: locale).language.languageCode != nil else {
            throw AppleSentencePlaybackError.invalidLocale
        }
        try speak(sentence, rate: AVSpeechUtteranceDefaultSpeechRate)
        return asset(for: sentence)
    }

    func replay(_ sentence: Sentence, slowly: Bool) throws {
        let rate = slowly ? max(AVSpeechUtteranceMinimumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * 0.72) : AVSpeechUtteranceDefaultSpeechRate
        try speak(sentence, rate: rate)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speak(_ sentence: Sentence, rate: Float) throws {
        guard !sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleSentencePlaybackError.missingSentence
        }
        let utterance = AVSpeechUtterance(string: sentence.text)
        if let voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: locale)
        }
        guard utterance.voice != nil else { throw AppleSentencePlaybackError.invalidLocale }
        utterance.rate = rate
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }

    private func asset(for sentence: Sentence) -> MediaAsset {
        var checksum: UInt64 = 0xcbf29ce484222325
        for byte in "\(sentence.id.uuidString)|\(sentence.revision)|\(sentence.text)|\(locale)|\(voiceIdentifier ?? "system")".utf8 {
            checksum = (checksum ^ UInt64(byte)) &* 0x100000001b3
        }
        return MediaAsset(
            kind: .audio,
            locale: locale,
            checksum: String(checksum, radix: 16),
            provider: "apple-system",
            model: voiceIdentifier ?? "system-voice",
            cacheReference: nil,
            availability: .available
        )
    }
}
