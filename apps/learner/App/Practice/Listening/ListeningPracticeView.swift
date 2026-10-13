import SwiftUI
import LinguaBrainDomain

/// Listening story surface. The exact transcript and translation are supplied
/// only after feedback or an explicit reveal; they never enter the answering
/// accessibility tree.
struct ListeningPracticeView: View {
    @Environment(PrototypeLocalization.self) private var localization
    @State private var model: PracticeSessionModel
    let exercise: ExerciseInstance
    let sentence: Sentence
    let replay: @Sendable (_ slow: Bool) async -> Void
    let stopPlayback: @Sendable () async -> Void

    init(model: PracticeSessionModel, exercise: ExerciseInstance, sentence: Sentence, replay: @escaping @Sendable (_ slow: Bool) async -> Void = { _ in }, stopPlayback: @escaping @Sendable () async -> Void = {}) {
        _model = State(initialValue: model); self.exercise = exercise; self.sentence = sentence; self.replay = replay; self.stopPlayback = stopPlayback
    }

    var body: some View {
        PracticeScaffold(model: model, titleKey: "practice.listening.title", instructionKey: "practice.listening.instruction", descriptionKey: "practice.listening.description", answerLanguageTag: exercise.targetLanguage, referenceAnswer: revealedText, promptContent: {
            HStack {
                Button(localization.localized("practice.listening.replay")) { Task { await replay(false) } }
                Button(localization.localized("practice.listening.slowReplay")) { Task { await replay(true) } }
            }
                .accessibilityElement(children: .contain)
        }, answerEntry: { binding in
            TextEditor(text: binding).frame(minHeight: 130).padding(8).overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.35))).accessibilityLabel("Meaning in your own words")
        }, revealedContent: {
            VStack(alignment: .leading, spacing: 8) { Text(sentence.text).textSelection(.enabled); Text(sentence.translation).foregroundStyle(.secondary).textSelection(.enabled) }
        })
        .task(id: exercise.id) { await model.prepare(exercise: exercise) }
        .onDisappear { model.cancel(); Task { await stopPlayback() } }
    }

    private var revealedText: String? {
        PracticeReferenceAnswerVisibility.isVisible(phase: model.state.phase, evaluationAvailable: model.state.attempts.last?.evaluatorResult != nil, hasExplicitReveal: model.state.phase == .revealed) ? sentence.text : nil
    }
}
