import SwiftUI
import LinguaBrainDomain

enum PracticeReferenceAnswerVisibility {
    static func isVisible(
        phase: PracticePresentationPhase,
        evaluationAvailable: Bool,
        hasExplicitReveal: Bool
    ) -> Bool {
        switch phase {
        case .revealed:
            true
        case .feedback:
            evaluationAvailable
        case .unavailable:
            hasExplicitReveal
        default:
            false
        }
    }
}

/// Resolves the direction of learner-authored and answer-language text without
/// changing the direction of the surrounding interface. Language tags may be
/// either BCP-47 (`fa-IR`) or underscore-separated (`fa_IR`).
enum PracticeLanguageDirection {
    static func layoutDirection(for languageTag: String) -> LayoutDirection {
        let primaryTag = languageTag
            .split(whereSeparator: { $0 == "-" || $0 == "_" })
            .first
            .map(String.init)
            .map { $0.lowercased() }

        switch primaryTag {
        case "ar", "dv", "fa", "he", "ku", "ps", "ur", "yi":
            return .rightToLeft
        default:
            return .leftToRight
        }
    }
}

/// A reusable, mode-neutral practice shell.  Story views provide prompt,
/// answer-entry, and revealed-answer content; all persistence and learning
/// effects remain behind `PracticeSessionModel` intents.
struct PracticeScaffold<PromptContent: View, AnswerContent: View, RevealedContent: View>: View {
    @Environment(PrototypeLocalization.self) private var localization
    @Bindable private var model: PracticeSessionModel

    let titleKey: String
    let instructionKey: String
    let descriptionKey: String
    let currentPosition: Int?
    let totalCount: Int?
    let answerLanguageTag: String?
    let referenceAnswer: String?
    private let promptContent: () -> PromptContent
    private let answerEntry: (Binding<String>) -> AnswerContent
    private let revealedContent: () -> RevealedContent

    init(
        model: PracticeSessionModel,
        titleKey: String,
        instructionKey: String,
        descriptionKey: String,
        currentPosition: Int? = nil,
        totalCount: Int? = nil,
        answerLanguageTag: String? = nil,
        referenceAnswer: String? = nil,
        @ViewBuilder promptContent: @escaping () -> PromptContent,
        @ViewBuilder answerEntry: @escaping (Binding<String>) -> AnswerContent,
        @ViewBuilder revealedContent: @escaping () -> RevealedContent
    ) {
        _model = Bindable(wrappedValue: model)
        self.titleKey = titleKey
        self.instructionKey = instructionKey
        self.descriptionKey = descriptionKey
        self.currentPosition = currentPosition
        self.totalCount = totalCount
        self.answerLanguageTag = answerLanguageTag
        self.referenceAnswer = referenceAnswer
        self.promptContent = promptContent
        self.answerEntry = answerEntry
        self.revealedContent = revealedContent
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                switch model.state.phase {
                case .loading:
                    statePanel(
                        titleKey: "practice.shared.loading",
                        detailKey: "practice.shared.loadingDetail",
                        symbol: "arrow.triangle.2.circlepath",
                        progress: true
                    )
                case .empty:
                    statePanel(
                        titleKey: "practice.shared.empty",
                        detailKey: "practice.shared.emptyDetail",
                        symbol: "checkmark.circle",
                        progress: false
                    )
                case .answering:
                    answeringContent
                case .evaluating:
                    evaluatingContent
                case .feedback:
                    feedbackContent
                case .revealed:
                    revealedState
                case .unavailable:
                    unavailableContent
                case .finished:
                    completionSummary
                case .recoverableFailure:
                    recoverableFailure
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized(titleKey))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practice.shared.scaffold")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(localization.localized(titleKey), systemImage: "sparkles")
                    .font(.title2.weight(.bold))
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let currentPosition, let totalCount, totalCount > 0 {
                    Text("\(currentPosition) / \(totalCount)")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(localization.localized("practice.shared.progress"))
                        .accessibilityValue("\(currentPosition) / \(totalCount)")
                }
            }

            Text(localization.localized(instructionKey))
                .font(.headline)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(localization.localized(descriptionKey))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(100)
    }

    private var answeringContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            promptCard
            answerCard
            hintCard

            actionRow {
                intentButton(
                    titleKey: "practice.shared.hint",
                    symbol: "lightbulb",
                    hintKey: "practice.shared.hintHint",
                    action: model.requestHint
                )
                intentButton(
                    titleKey: "practice.shared.reveal",
                    symbol: "eye",
                    hintKey: "practice.shared.revealHint",
                    action: model.reveal
                )
                intentButton(
                    titleKey: "practice.shared.skip",
                    symbol: "forward.end",
                    hintKey: "practice.shared.skipHint",
                    action: model.skip
                )
                Button {
                    Task { await model.submit() }
                } label: {
                    Label(localization.localized("practice.shared.submit"), systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
                .disabled(isBusy || model.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint(localization.localized("practice.shared.submitHint"))
            }
        }
    }

    private var evaluatingContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            promptCard
            answerCard.disabled(true)
            statePanel(
                titleKey: "practice.shared.evaluating",
                detailKey: "practice.shared.evaluatingDetail",
                symbol: "hourglass",
                progress: true
            )
        }
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            promptCard
            PracticeFeedbackView(
                attempt: model.state.attempts.last,
                referenceAnswer: referenceAnswer,
                answerLanguageTag: answerLanguageTag,
                isReferenceVisible: PracticeReferenceAnswerVisibility.isVisible(
                    phase: model.state.phase,
                    evaluationAvailable: model.state.attempts.last?.evaluatorResult != nil,
                    hasExplicitReveal: hasExplicitReveal
                )
            )
            actionRow {
                intentButton(titleKey: "practice.shared.retry", symbol: "arrow.counterclockwise", hintKey: "practice.shared.retryHint", action: model.retry)
                intentButton(titleKey: "practice.shared.continue", symbol: "arrow.right", hintKey: "practice.shared.continueHint", action: model.continue)
            }
        }
    }

    private var revealedState: some View {
        VStack(alignment: .leading, spacing: 18) {
            promptCard
            revealedAnswerCard
            PracticeFeedbackView(
                attempt: model.state.attempts.last,
                referenceAnswer: referenceAnswer,
                answerLanguageTag: answerLanguageTag,
                isReferenceVisible: true
            )
            actionRow {
                Button {
                    Task { await model.copyAnswer() }
                } label: {
                    Label(localization.localized("practice.shared.copyAnswer"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(isBusy)
                .accessibilityHint(localization.localized("practice.shared.copyAnswerHint"))
                intentButton(titleKey: "practice.shared.retry", symbol: "arrow.counterclockwise", hintKey: "practice.shared.retryHint", action: model.retry)
                intentButton(titleKey: "practice.shared.nextQuestion", symbol: "arrow.right", hintKey: "practice.shared.continueHint", action: model.continue)
            }
        }
    }

    private var unavailableContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            promptCard
            PracticeFeedbackView(
                attempt: model.state.attempts.last,
                referenceAnswer: referenceAnswer,
                answerLanguageTag: answerLanguageTag,
                isReferenceVisible: PracticeReferenceAnswerVisibility.isVisible(
                    phase: model.state.phase,
                    evaluationAvailable: model.state.attempts.last?.evaluatorResult != nil,
                    hasExplicitReveal: hasExplicitReveal
                )
            )
            actionRow {
                intentButton(titleKey: "practice.shared.retry", symbol: "arrow.counterclockwise", hintKey: "practice.shared.retryHint", action: model.retry)
                intentButton(titleKey: "practice.shared.continue", symbol: "arrow.right", hintKey: "practice.shared.continueHint", action: model.continue)
            }
        }
    }

    private var completionSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            statePanel(
                titleKey: "practice.shared.finished",
                detailKey: "practice.shared.finishedDetail",
                symbol: "checkmark.seal",
                progress: false
            )

            VStack(alignment: .leading, spacing: 8) {
                Label(localization.localized("practice.shared.summary"), systemImage: "list.bullet.clipboard")
                    .font(.headline)
                Text(localization.localized("practice.shared.summaryAttempts").replacingOccurrences(of: "%d", with: "\(model.state.attempts.count)"))
                    .font(.body)
                Text(localization.localized("practice.shared.summaryHelp").replacingOccurrences(of: "%d", with: "\(model.state.help.count)"))
                    .font(.body)
            }
            .lineSpacing(4)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    private var recoverableFailure: some View {
        VStack(alignment: .leading, spacing: 16) {
            statePanel(
                titleKey: "practice.shared.recoverableFailure",
                detailKey: "practice.shared.recoverableFailureDetail",
                symbol: "arrow.triangle.2.circlepath",
                progress: false
            )
            Button {
                Task { await model.resume() }
            } label: {
                Label(localization.localized("practice.shared.resume"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
            .accessibilityHint(localization.localized("practice.shared.resumeHint"))
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localization.localized("practice.shared.prompt"), systemImage: "text.quote")
                .font(.headline)
            promptContent()
                .font(.title3)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilitySortPriority(80)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localization.localized("practice.shared.answer"), systemImage: "pencil.line")
                .font(.headline)
            answerEntryContent
                .accessibilitySortPriority(70)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var hintCard: some View {
        if model.state.help.contains(where: { $0.kind == .hint }) {
            Label(localization.localized("practice.shared.hintRecorded"), systemImage: "lightbulb.fill")
                .font(.callout.weight(.medium))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.yellow.opacity(0.45), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(localization.localized("practice.shared.hintRecordedAccessibility"))
        }
    }

    private var revealedAnswerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(localization.localized("practice.shared.revealedAnswer"), systemImage: "eye")
                .font(.headline)
            revealedAnswerContent
            Label(localization.localized("practice.shared.revealWarning"), systemImage: "info.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.orange.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var answerEntryContent: some View {
        if let answerLanguageTag {
            answerEntry($model.answerText)
                .environment(
                    \.layoutDirection,
                    PracticeLanguageDirection.layoutDirection(for: answerLanguageTag)
                )
                .accessibilityLabel(localization.localized("practice.shared.answer"))
                .accessibilityValue(model.answerText.isEmpty
                    ? localization.localized("practice.shared.answerPlaceholder")
                    : model.answerText)
        } else {
            answerEntry($model.answerText)
                .accessibilityLabel(localization.localized("practice.shared.answer"))
                .accessibilityValue(model.answerText.isEmpty
                    ? localization.localized("practice.shared.answerPlaceholder")
                    : model.answerText)
        }
    }

    @ViewBuilder
    private var revealedAnswerContent: some View {
        if let answerLanguageTag {
            revealedContent()
                .font(.title3)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.layoutDirection, PracticeLanguageDirection.layoutDirection(for: answerLanguageTag))
        } else {
            revealedContent()
                .font(.title3)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statePanel(titleKey: String, detailKey: String, symbol: String, progress: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title2)
                    .frame(width: 30)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(localization.localized(titleKey))
                        .font(.headline)
                    Text(localization.localized(detailKey))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if progress {
                ProgressView()
                    .accessibilityLabel(localization.localized(titleKey))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func actionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { content() }
            VStack(alignment: .leading, spacing: 10) { content() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlSize(.large)
        .accessibilitySortPriority(40)
    }

    private func intentButton(
        titleKey: String,
        symbol: String,
        hintKey: String,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(localization.localized(titleKey), systemImage: symbol)
        }
        .buttonStyle(.bordered)
        .disabled(isBusy)
        .accessibilityHint(localization.localized(hintKey))
    }

    private var isBusy: Bool {
        switch model.state.phase {
        case .loading, .evaluating: true
        default: false
        }
    }

    private var hasExplicitReveal: Bool {
        model.state.help.contains { $0.kind == .reveal || $0.kind == .copiedAnswer }
    }
}
