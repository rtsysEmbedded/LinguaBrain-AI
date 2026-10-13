import SwiftUI
import LinguaBrainDomain

/// Shared, mode-neutral feedback.  The reference answer is passed separately
/// and is rendered only when the scaffold has explicitly made it visible.
/// This keeps unrevealed content out of the view and accessibility tree.
struct PracticeFeedbackView: View {
    @Environment(PrototypeLocalization.self) private var localization

    let attempt: Attempt?
    let referenceAnswer: String?
    let answerLanguageTag: String?
    let isReferenceVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            outcomeBanner
            originalResponse

            if isReferenceVisible, let referenceAnswer, !referenceAnswer.isEmpty {
                labeledText(
                    title: localization.localized("practice.shared.feedback.modelAnswer"),
                    text: referenceAnswer,
                    symbol: "checkmark.seal",
                    languageTag: answerLanguageTag
                )
            }

            if !feedback.isEmpty {
                labeledMessages(
                    title: localization.localized("practice.shared.feedback.explanation"),
                    messages: feedback,
                    symbol: "text.bubble"
                )
            }

            if !rules.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        localization.localized("practice.shared.feedback.rules"),
                        systemImage: "book.closed"
                    )
                    .font(.headline)

                    ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "link")
                                .accessibilityHidden(true)
                            Text(rule.code)
                                .font(.callout.weight(.medium))
                            if let span = rule.span, !span.isEmpty {
                                Text(span)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localization.localized("practice.shared.feedback.accessibility"))
        .accessibilitySortPriority(60)
    }

    private var outcome: AttemptOutcome {
        attempt?.evaluatorResult?.outcome ?? attempt?.outcome ?? .pending
    }

    private var feedback: [TypedFeedback] {
        attempt?.feedback ?? attempt?.evaluatorResult?.feedback ?? []
    }

    private var rules: [RuleReference] {
        attempt?.rules ?? attempt?.evaluatorResult?.rules ?? []
    }

    @ViewBuilder
    private var outcomeBanner: some View {
        let presentation = OutcomePresentation(outcome: outcome, reason: attempt?.evaluatorResult?.unavailableReason)
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: presentation.symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(localization.localized(presentation.titleKey))
                    .font(.headline)
                Text(localization.localized(presentation.detailKey))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var originalResponse: some View {
        if let attempt {
            labeledText(
                title: localization.localized("practice.shared.feedback.originalResponse"),
                text: attempt.response.isEmpty
                    ? localization.localized("practice.shared.feedback.noResponse")
                    : attempt.response,
                symbol: "person.crop.circle",
                languageTag: answerLanguageTag
            )
        }
    }

    private func labeledText(title: String, text: String, symbol: String, languageTag: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
            answerText(text, languageTag: languageTag)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func answerText(_ text: String, languageTag: String?) -> some View {
        if let languageTag {
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .environment(\.layoutDirection, PracticeLanguageDirection.layoutDirection(for: languageTag))
        } else {
            Text(text)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func labeledMessages(title: String, messages: [TypedFeedback], symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
            ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: message.isError ? "exclamationmark.circle" : "info.circle")
                        .accessibilityHidden(true)
                    Text(message.message)
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct OutcomePresentation {
    let titleKey: String
    let detailKey: String
    let symbol: String

    init(outcome: AttemptOutcome, reason: PracticeUnavailableReason?) {
        switch outcome {
        case .correct:
            titleKey = "practice.shared.feedback.correct"
            detailKey = "practice.shared.feedback.correctDetail"
            symbol = "checkmark.circle"
        case .partial:
            titleKey = "practice.shared.feedback.partial"
            detailKey = "practice.shared.feedback.partialDetail"
            symbol = "circle.lefthalf.filled"
        case .incorrect:
            titleKey = "practice.shared.feedback.incorrect"
            detailKey = "practice.shared.feedback.incorrectDetail"
            symbol = "xmark.circle"
        case .skipped:
            titleKey = "practice.shared.feedback.skipped"
            detailKey = "practice.shared.feedback.skippedDetail"
            symbol = "forward.end"
        case .unavailable:
            titleKey = "practice.shared.feedback.unavailable"
            detailKey = reason == .cancelled
                ? "practice.shared.feedback.cancelledDetail"
                : "practice.shared.feedback.unavailableDetail"
            symbol = "exclamationmark.triangle"
        case .pending:
            titleKey = "practice.shared.feedback.ungraded"
            detailKey = "practice.shared.feedback.pendingDetail"
            symbol = "clock"
        }
    }
}
