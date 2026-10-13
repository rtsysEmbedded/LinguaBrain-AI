import SwiftUI
import LinguaBrainApplication
import LinguaBrainDomain

/// App-facing boundary for accepting a reviewed correction. The view never
/// reaches persistence directly; composition supplies an adapter to
/// `SentenceLearningService`.
protocol WritingCorrectionAcceptance: Sendable {
    func accept(_ request: SentenceLearningRequest) async throws -> SentenceLearningResult
}

/// Writing story surface. The shared scaffold owns session intents; this view
/// only supplies writing-specific prompt and multiline answer content.
struct WritingPracticeView: View {
    @Environment(PrototypeLocalization.self) private var localization
    @State private var model: PracticeSessionModel
    @State private var acceptanceMessage: String?
    let descriptor: WritingExerciseDescriptor
    let correctionAcceptance: (any WritingCorrectionAcceptance)?

    init(model: PracticeSessionModel, descriptor: WritingExerciseDescriptor, correctionAcceptance: (any WritingCorrectionAcceptance)? = nil) {
        _model = State(initialValue: model)
        self.descriptor = descriptor
        self.correctionAcceptance = correctionAcceptance
    }

    var body: some View {
        PracticeScaffold(
            model: model,
            titleKey: "practice.writing.title",
            instructionKey: "practice.writing.instruction",
            descriptionKey: "practice.writing.description",
            answerLanguageTag: descriptor.exercise.targetLanguage,
            referenceAnswer: model.state.attempts.last?.evaluatorResult?.minimalCorrection,
            promptContent: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localization.localized("practice.writing.targetWord"))
                        .font(.headline)
                    Text(descriptor.targetWord)
                        .font(.title3.weight(.semibold))
                    Text("\(descriptor.partOfSpeech) · \(descriptor.cefrLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(descriptor.allowedContext)
                        .font(.body)
                        .lineSpacing(4)
                }
            },
            answerEntry: { binding in
                TextEditor(text: binding)
                    .frame(minHeight: 120)
                    .padding(8)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.35)))
                    .accessibilityLabel(localization.localized("practice.writing.answerLabel"))
            },
            revealedContent: {
                if let correction = model.state.attempts.last?.evaluatorResult?.minimalCorrection {
                    Text(correction)
                } else if let natural = model.state.attempts.last?.evaluatorResult?.naturalVariant {
                    Text(natural)
                } else {
                    Text(descriptor.exercise.prompt)
                }
            }
        )
        .task(id: descriptor.exercise.id) {
            await model.prepare(exercise: descriptor.exercise)
        }
        .onDisappear { model.cancel() }
        .safeAreaInset(edge: .bottom) {
            if let evaluation = model.state.attempts.last?.evaluatorResult,
               let correction = evaluation.minimalCorrection,
               let acceptance = correctionAcceptance,
               let attempt = model.state.attempts.last {
                Button(localization.localized("practice.writing.acceptCorrection")) {
                    Task {
                        let request = SentenceLearningRequest(
                            learnerID: descriptor.exercise.reviewUnit.learnerID,
                            sourceLanguage: descriptor.exercise.sourceLanguage,
                            targetLanguage: descriptor.exercise.targetLanguage,
                            meaningKey: descriptor.allowedContext,
                            attemptID: attempt.id,
                            originalResponse: attempt.response,
                            minimalCorrection: correction,
                            naturalVariant: evaluation.naturalVariant,
                            validation: .validated,
                            provenance: evaluation.provenance,
                            ruleReferences: evaluation.rules
                        )
                        do { acceptanceMessage = try await acceptance.accept(request).decision.rawValue }
                        catch { acceptanceMessage = localization.localized("practice.writing.acceptFailed") }
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(localization.localized("practice.writing.acceptCorrectionHint"))
                if let acceptanceMessage { Text(acceptanceMessage).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}
