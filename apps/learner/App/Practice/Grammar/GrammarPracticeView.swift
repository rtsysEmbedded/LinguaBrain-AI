import SwiftUI
import LinguaBrainApplication
import LinguaBrainDomain

struct GrammarPracticeView: View {
    @Environment(PrototypeLocalization.self) private var localization
    @State private var model: PracticeSessionModel
    let descriptor: GrammarExerciseDescriptor
    init(model: PracticeSessionModel, descriptor: GrammarExerciseDescriptor) { _model = State(initialValue: model); self.descriptor = descriptor }
    var body: some View {
        PracticeScaffold(model: model, titleKey: "practice.grammar.title", instructionKey: descriptor.mode == .explainError ? "practice.grammar.explainError" : "practice.grammar.explainUsage", descriptionKey: "practice.grammar.description", answerLanguageTag: descriptor.exercise.targetLanguage, referenceAnswer: model.state.attempts.last?.evaluatorResult?.minimalCorrection, promptContent: {
            VStack(alignment: .leading, spacing: 12) {
                Text(descriptor.exercise.prompt).font(.title3).textSelection(.enabled)
                if let demonstration = descriptor.demonstration {
                    Text(demonstration).font(.body).foregroundStyle(.secondary).accessibilityLabel(localization.localized("practice.grammar.exampleAccessibility"))
                }
                Text(descriptor.rule.code).font(.caption).foregroundStyle(.secondary).accessibilityLabel(localization.localized("practice.grammar.ruleAccessibility"))
            }
        }, answerEntry: { binding in
            TextEditor(text: binding).frame(minHeight: 130).padding(8).overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.35))).accessibilityLabel(localization.localized("practice.grammar.answerAccessibility"))
        }, revealedContent: { Text(descriptor.referenceAnswer).textSelection(.enabled) })
        .task(id: descriptor.exercise.id) { await model.prepare(exercise: descriptor.exercise) }
        .onDisappear { model.cancel() }
    }
}
