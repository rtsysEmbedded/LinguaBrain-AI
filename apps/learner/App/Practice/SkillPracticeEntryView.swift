import SwiftUI
import LinguaBrainApplication
import LinguaBrainDomain

/// Route for one practice skill (T033). It asks `PracticeCapabilityGate`
/// whether the skill is available for the active language pair, loads the
/// next exercise from the learner's own cards, and presents the story view.
/// An unavailable skill is explained; it never falls back to another
/// exercise type.
struct SkillPracticeEntryView: View {
    let skill: PracticeSkill
    let composition: PracticeComposition?

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @Environment(PrototypeLearnerProfile.self) private var learnerProfile
    @Environment(PrototypeAISettings.self) private var aiSettings
    @State private var content: EntryContent = .loading
    @State private var occurrence = 0

    private enum EntryContent {
        case loading
        case unavailable(PracticeAvailabilityReason)
        case storageNotReady
        case loadFailed
        case writing(WritingExerciseDescriptor, PracticeGrading, PracticeSessionModel)
        case listening(ListeningExerciseDescriptor, PracticeGrading, PracticeSessionModel, AppleSentencePlayback)
        case grammar(GrammarExerciseDescriptor, PracticeGrading, PracticeSessionModel)
    }

    private struct LoadKey: Equatable {
        let occurrence: Int
        let sourceLanguage: String
        let targetLanguage: String
    }

    var body: some View {
        Group {
            switch content {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unavailable(let reason):
                PracticeUnavailableView(reasonKey: "practice.unavailable.\(reason.rawValue)")
            case .storageNotReady:
                PracticeUnavailableView(reasonKey: "practice.unavailable.storageNotReady")
            case .loadFailed:
                PracticeUnavailableView(reasonKey: "practice.unavailable.loadFailed")
            case .writing(let descriptor, let grading, let model):
                WritingPracticeView(model: model, descriptor: descriptor)
                    .id(descriptor.exercise.id)
                    .safeAreaInset(edge: .top) { GradingNotice(grading: grading) }
            case .listening(let descriptor, let grading, let model, let playback):
                ListeningPracticeView(
                    model: model,
                    exercise: descriptor.exercise,
                    sentence: descriptor.sentence,
                    replay: { slow in _ = try? await playback.replay(descriptor.sentence, slowly: slow) },
                    stopPlayback: { await playback.stop() }
                )
                .id(descriptor.exercise.id)
                .safeAreaInset(edge: .top) { GradingNotice(grading: grading) }
            case .grammar(let descriptor, let grading, let model):
                GrammarPracticeView(model: model, descriptor: descriptor)
                    .id(descriptor.exercise.id)
                    .safeAreaInset(edge: .top) { GradingNotice(grading: grading) }
            }
        }
        .navigationTitle(localization.localized(PrototypeSkillPracticeMode(practiceSkill: skill).titleKey))
        .toolbar {
            if hasExercise {
                ToolbarItem(placement: .primaryAction) {
                    Button(localization.localized("practice.entry.next"), systemImage: "arrow.forward.circle") {
                        occurrence += 1
                    }
                }
            }
        }
        .task(id: LoadKey(occurrence: occurrence, sourceLanguage: languageSettings.sourceLanguageTag, targetLanguage: languageSettings.targetLanguageTag)) {
            await load()
        }
    }

    private var hasExercise: Bool {
        switch content {
        case .writing, .listening, .grammar: true
        default: false
        }
    }

    private func load() async {
        guard let composition, let repository = composition.content else {
            content = .storageNotReady
            return
        }
        content = .loading
        let cards = PrototypeStorePracticeCards(store: store)
        let probe = PracticeCapabilityProbe(
            composition: composition,
            cards: cards,
            aiSettings: aiSettings,
            sourceLanguage: languageSettings.sourceLanguageTag,
            targetLanguage: languageSettings.targetLanguageTag
        )
        let grading: PracticeGrading
        switch probe.availability(for: skill) {
        case .unavailable(let reason):
            content = .unavailable(reason)
            return
        case .available(let value):
            grading = value
        }
        do {
            switch skill {
            case .writing:
                let retrieval = CardBackedWritingRetrieval(
                    cards: cards, repository: repository, clock: composition.clock,
                    sourceLanguage: probe.sourceLanguage, targetLanguage: probe.targetLanguage
                )
                guard let descriptor = try await retrieval.nextWritingExercise(
                    learnerID: PracticeLearner.localID, cefrLevel: learnerProfile.currentLevel, seed: occurrence
                ) else {
                    content = .unavailable(.noCards)
                    return
                }
                content = .writing(descriptor, grading, composition.makeSessionModel())
            case .listening:
                let retrieval = CardSentenceListeningRetrieval(
                    cards: cards, repository: repository, clock: composition.clock,
                    sourceLanguage: probe.sourceLanguage, targetLanguage: probe.targetLanguage
                )
                guard let descriptor = try await retrieval.nextListeningExercise(learnerID: PracticeLearner.localID, seed: occurrence) else {
                    content = .unavailable(.noReviewedSentences)
                    return
                }
                let playback = AppleSentencePlayback(locale: probe.targetLanguage, rateMultiplier: learnerProfile.playbackRate)
                content = .listening(descriptor, grading, composition.makeSessionModel(), playback)
                _ = try? await playback.sentenceAudio(for: descriptor.sentence)
            case .grammar:
                let retrieval = CuratedGrammarRetrieval(
                    catalog: probe.grammar, repository: repository, clock: composition.clock,
                    sourceLanguage: probe.sourceLanguage, targetLanguage: probe.targetLanguage
                )
                guard let descriptor = try await retrieval.nextGrammarExercise(learnerID: PracticeLearner.localID, seed: occurrence) else {
                    content = .unavailable(.noReviewedGrammarContent)
                    return
                }
                content = .grammar(descriptor, grading, composition.makeSessionModel())
            case .speaking:
                content = .unavailable(.pronunciationNotValidated)
            }
        } catch is CancellationError {
            return
        } catch {
            content = .loadFailed
        }
    }
}

/// Explains why a practice mode cannot be offered.
struct PracticeUnavailableView: View {
    @Environment(PrototypeLocalization.self) private var localization
    /// Prefix of `<reasonKey>.title` and `<reasonKey>.detail`.
    let reasonKey: String

    var body: some View {
        ContentUnavailableView {
            Label(localization.localized("\(reasonKey).title"), systemImage: "lock.circle")
        } description: {
            Text(localization.localized("\(reasonKey).detail"))
        }
    }
}

/// States whether the answer will be graded, before the learner answers.
private struct GradingNotice: View {
    @Environment(PrototypeLocalization.self) private var localization
    let grading: PracticeGrading

    var body: some View {
        if grading != .graded {
            Label(localization.localized("practice.grading.\(grading.rawValue)"), systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }
}
