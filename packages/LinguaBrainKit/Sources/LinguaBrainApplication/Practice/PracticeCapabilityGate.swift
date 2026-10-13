import Foundation
import LinguaBrainDomain

/// Why a practice mode cannot be offered right now. Each reason maps to an
/// explicit, localized explanation; an unavailable mode never falls back to a
/// different exercise silently.
public enum PracticeAvailabilityReason: String, Sendable, Equatable, CaseIterable {
    /// The active language pair has no cards to practise.
    case noCards
    /// No reviewed example sentence exists for listening.
    case noReviewedSentences
    /// No human-reviewed grammar template exists for the target language.
    case noReviewedGrammarContent
    /// Sentence audio cannot be produced for the target language.
    case sentenceAudioUnavailable
    /// Pronunciation scoring has not passed its provider/device validation.
    case pronunciationNotValidated
}

/// Whether answers in an available mode will be graded.
public enum PracticeGrading: String, Sendable, Equatable {
    /// An evaluator is configured and allowed to receive the answer.
    case graded
    /// Text mode is off or not configured.
    case ungradedNoProvider
    /// A cloud provider is configured but the learner has not consented.
    case ungradedConsentRequired
}

public enum PracticeAvailability: Sendable, Equatable {
    case available(PracticeGrading)
    case unavailable(PracticeAvailabilityReason)

    public var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }
}

/// Facts the app gathers before deciding which practice modes to show.
public struct PracticeCapabilityFacts: Sendable, Equatable {
    public enum EvaluatorState: Sendable, Equatable {
        case ready
        case notConfigured
        case consentRequired
    }

    public let hasCards: Bool
    public let hasReviewedSentences: Bool
    public let hasReviewedGrammarContent: Bool
    public let sentenceAudioAvailable: Bool
    public let pronunciationValidated: Bool
    public let evaluator: EvaluatorState

    public init(
        hasCards: Bool, hasReviewedSentences: Bool, hasReviewedGrammarContent: Bool,
        sentenceAudioAvailable: Bool, pronunciationValidated: Bool, evaluator: EvaluatorState
    ) {
        self.hasCards = hasCards; self.hasReviewedSentences = hasReviewedSentences
        self.hasReviewedGrammarContent = hasReviewedGrammarContent; self.sentenceAudioAvailable = sentenceAudioAvailable
        self.pronunciationValidated = pronunciationValidated; self.evaluator = evaluator
    }

    /// Facts for one language pair, derived from its cards.
    public init(
        cards: [PracticeCardCandidate], hasReviewedGrammarContent: Bool,
        sentenceAudioAvailable: Bool, pronunciationValidated: Bool, evaluator: EvaluatorState
    ) {
        self.init(
            hasCards: cards.contains { !$0.targetText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            hasReviewedSentences: cards.contains(where: \.hasReviewedExample),
            hasReviewedGrammarContent: hasReviewedGrammarContent,
            sentenceAudioAvailable: sentenceAudioAvailable,
            pronunciationValidated: pronunciationValidated,
            evaluator: evaluator
        )
    }
}

/// Pure capability decision per skill (T033 acceptance: unavailable modes
/// are explicitly gated).
public enum PracticeCapabilityGate {
    public static func availability(for skill: PracticeSkill, facts: PracticeCapabilityFacts) -> PracticeAvailability {
        switch skill {
        case .writing:
            guard facts.hasCards else { return .unavailable(.noCards) }
        case .grammar:
            guard facts.hasReviewedGrammarContent else { return .unavailable(.noReviewedGrammarContent) }
        case .listening:
            guard facts.hasReviewedSentences else { return .unavailable(.noReviewedSentences) }
            guard facts.sentenceAudioAvailable else { return .unavailable(.sentenceAudioUnavailable) }
        case .speaking:
            guard facts.pronunciationValidated else { return .unavailable(.pronunciationNotValidated) }
        }
        switch facts.evaluator {
        case .ready: return .available(.graded)
        case .notConfigured: return .available(.ungradedNoProvider)
        case .consentRequired: return .available(.ungradedConsentRequired)
        }
    }
}
