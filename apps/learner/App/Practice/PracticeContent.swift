import AVFAudio
import Foundation
import LinguaBrainApplication
import LinguaBrainDomain

/// Practice data on this device belongs to one local learner. The identifier
/// is stored in every review unit, so it must never change.
enum PracticeLearner {
    static let localID = "local"
}

/// Snapshot of the learner's cards for the practice catalog, taken on the
/// main actor from `PrototypeStore`. Only cards whose content a person
/// reviewed offer their example as listening material.
struct PrototypeStorePracticeCards: PracticeCardSource {
    let candidates: [PracticeCardCandidate]

    @MainActor
    init(store: PrototypeStore) {
        candidates = store.words.map { word in
            PracticeCardCandidate(
                cardID: word.id,
                targetText: word.german,
                sourceMeaning: word.persian,
                partOfSpeech: word.partOfSpeech,
                cefrLevel: word.level,
                exampleTarget: word.example,
                exampleSource: word.exampleTranslation,
                exampleReview: store.isContentReviewed(word) ? .reviewed : .unreviewed,
                sourceLanguage: word.sourceLanguageTag,
                targetLanguage: word.targetLanguageTag
            )
        }
    }

    func practiceCards(sourceLanguage: String, targetLanguage: String) async throws -> [PracticeCardCandidate] {
        cards(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
    }

    func cards(sourceLanguage: String, targetLanguage: String) -> [PracticeCardCandidate] {
        candidates.filter { $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage }
    }
}

/// Gathers the facts `PracticeCapabilityGate` needs for one language pair.
@MainActor
struct PracticeCapabilityProbe {
    let composition: PracticeComposition
    let cards: PrototypeStorePracticeCards
    let aiSettings: PrototypeAISettings
    let sourceLanguage: String
    let targetLanguage: String
    let hasReviewedGrammarContent: Bool

    var pairCards: [PracticeCardCandidate] {
        cards.cards(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
    }

    func facts(for skill: PracticeSkill) -> PracticeCapabilityFacts {
        PracticeCapabilityFacts(
            cards: pairCards,
            hasReviewedGrammarContent: hasReviewedGrammarContent,
            sentenceAudioAvailable: AVSpeechSynthesisVoice(language: targetLanguage) != nil,
            // T028 recorded a negative pronunciation-provider decision; no
            // validated speaking evaluator exists (T030–T032).
            pronunciationValidated: false,
            evaluator: evaluatorState(for: skill)
        )
    }

    func availability(for skill: PracticeSkill) -> PracticeAvailability {
        PracticeCapabilityGate.availability(for: skill, facts: facts(for: skill))
    }

    /// Answers are graded only when the composition routes the skill to an
    /// evaluator and the Text provider may receive the answer.
    func evaluatorState(for skill: PracticeSkill) -> PracticeCapabilityFacts.EvaluatorState {
        guard composition.gradedSkills.contains(skill) else { return .notConfigured }
        return PracticeEvaluationEnvironment.state(settings: aiSettings)
    }

    /// Evidence-based progress for the active pair, one entry per skill.
    func progress(skills: [PracticeSkill] = PracticeSkill.allCases) async throws -> [PracticeSkillProgress] {
        guard let reader = composition.content else { return [] }
        let keys = Dictionary(uniqueKeysWithValues: skills.compactMap { skill -> (PracticeSkill, Set<String>)? in
            switch skill {
            case .writing, .listening: (skill, PracticeCatalogKeys.objectiveKeys(skill: skill, cards: pairCards))
            case .grammar, .speaking: nil
            }
        })
        return try await PracticeProgressCalculator.summaries(
            skills: skills,
            learnerID: PracticeLearner.localID,
            objectiveKeys: keys,
            reader: reader
        )
    }
}
