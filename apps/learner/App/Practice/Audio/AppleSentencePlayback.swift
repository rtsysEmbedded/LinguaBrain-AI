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
    /// The learner's playback rate (Settings); 1 is the system default.
    private let rateMultiplier: Float

    init(locale: String, voiceIdentifier: String? = nil, rateMultiplier: Double = 1) {
        self.locale = locale
        self.voiceIdentifier = voiceIdentifier
        self.rateMultiplier = Float(rateMultiplier)
    }

    func sentenceAudio(for sentence: Sentence) async throws -> MediaAsset {
        try Task.checkCancellation()
        guard !sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleSentencePlaybackError.missingSentence
        }
        guard Locale(identifier: locale).language.languageCode != nil else {
            throw AppleSentencePlaybackError.invalidLocale
        }
        try speak(sentence, rate: scaled(AVSpeechUtteranceDefaultSpeechRate))
        return asset(for: sentence)
    }

    func replay(_ sentence: Sentence, slowly: Bool) throws {
        let slowFactor = Float(LearningContentRules.bundled.speech.slowReplayFactor)
        let rate = slowly ? AVSpeechUtteranceDefaultSpeechRate * slowFactor : AVSpeechUtteranceDefaultSpeechRate
        try speak(sentence, rate: scaled(rate))
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func scaled(_ rate: Float) -> Float {
        min(max(rate * rateMultiplier, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
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

    /// Identifies the audio of one sentence revision for a locale and voice.
    /// The listening evaluator recomputes it to bind feedback to the exact
    /// audio the learner heard.
    static func checksum(for sentence: Sentence, locale: String, voiceIdentifier: String?) -> String {
        var checksum: UInt64 = 0xcbf29ce484222325
        for byte in "\(sentence.id.uuidString)|\(sentence.revision)|\(sentence.text)|\(locale)|\(voiceIdentifier ?? "system")".utf8 {
            checksum = (checksum ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(checksum, radix: 16)
    }

    private func asset(for sentence: Sentence) -> MediaAsset {
        MediaAsset(
            kind: .audio,
            locale: locale,
            checksum: Self.checksum(for: sentence, locale: locale, voiceIdentifier: voiceIdentifier),
            provider: "apple-system",
            model: voiceIdentifier ?? "system-voice",
            cacheReference: nil,
            availability: .available
        )
    }
}
