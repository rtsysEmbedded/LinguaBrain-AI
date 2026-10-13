import SwiftUI
import LinguaBrainApplication
import LinguaBrainDomain

struct SentenceLearningHistoryItem: Identifiable, Sendable {
    let id: UUID
    let sentence: Sentence
    let sourceAttemptID: UUID
    let nextExerciseDescription: String?
    let selectionReason: AdaptivePracticeReason?
    let mastery: PracticeMasteryProjection
    let canEdit: Bool

    init(id: UUID? = nil, sentence: Sentence, sourceAttemptID: UUID, nextExerciseDescription: String? = nil, selectionReason: AdaptivePracticeReason? = nil, mastery: PracticeMasteryProjection = PracticeMasteryProjection(), canEdit: Bool = true) {
        self.id = id ?? sentence.id
        self.sentence = sentence; self.sourceAttemptID = sourceAttemptID; self.nextExerciseDescription = nextExerciseDescription; self.selectionReason = selectionReason; self.mastery = mastery; self.canEdit = canEdit
    }
}

protocol SentenceLearningHistoryUseCases: Sendable {
    func accept(_ item: SentenceLearningHistoryItem) async throws
    func decline(_ item: SentenceLearningHistoryItem) async throws
    func edit(_ item: SentenceLearningHistoryItem, text: String) async throws
}

struct SentenceLearningHistoryView: View {
    @Environment(PrototypeLocalization.self) private var localization
    let items: [SentenceLearningHistoryItem]
    let actions: any SentenceLearningHistoryUseCases
    @State private var editingID: UUID?
    @State private var editingText = ""
    @State private var errorMessage: String?

    init(items: [SentenceLearningHistoryItem], actions: any SentenceLearningHistoryUseCases) {
        self.items = items; self.actions = actions
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(localization.localized("practice.history.empty"), systemImage: "text.book.closed", description: Text(localization.localized("practice.history.emptyDetail")))
            } else {
                List(items) { item in
                    historyCard(item)
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #else
                .listStyle(.inset)
                #endif
            }
        }
        .navigationTitle(localization.localized("practice.history.title"))
        .alert(localization.localized("practice.history.error"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button(localization.localized("practice.history.dismiss"), role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder private func historyCard(_ item: SentenceLearningHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.sentence.text).font(.headline).textSelection(.enabled)
            labeledValue("practice.history.original", item.sentence.originalLearnerResponse ?? localization.localized("practice.history.noOriginal"))
            labeledValue("practice.history.correction", item.sentence.minimalCorrection ?? item.sentence.text)
            if let natural = item.sentence.naturalVariant { labeledValue("practice.history.natural", natural) }
            if !item.sentence.ruleReferences.isEmpty {
                labeledValue("practice.history.rules", item.sentence.ruleReferences.map(\.code).joined(separator: ", "))
            }
            if let reason = item.selectionReason {
                labeledValue("practice.history.reason", localization.localized("practice.history.reason.(reason.rawValue)"))
            }
            labeledValue("practice.history.mastery", masteryText(item.mastery))
            if let next = item.nextExerciseDescription { labeledValue("practice.history.next", next) }
            HStack {
                Button(localization.localized("practice.history.accept")) { run { try await actions.accept(item) } }
                Button(localization.localized("practice.history.decline"), role: .destructive) { run { try await actions.decline(item) } }
                if item.canEdit {
                    Button(localization.localized("practice.history.edit")) { editingID = item.id; editingText = item.sentence.text }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: Binding(get: { editingID == item.id }, set: { if !$0 { editingID = nil } })) {
            NavigationStack {
                Form { TextField(localization.localized("practice.history.editPrompt"), text: $editingText, axis: .vertical).lineLimit(3...8) }
                    .navigationTitle(localization.localized("practice.history.edit"))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(localization.localized("practice.history.cancel")) { editingID = nil } }
                        ToolbarItem(placement: .confirmationAction) { Button(localization.localized("practice.history.save")) { run { try await actions.edit(item, text: editingText); editingID = nil } } }
                    }
            }
        }
    }

    private func labeledValue(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(localization.localized(key)).font(.caption).foregroundStyle(.secondary); Text(value).textSelection(.enabled) }
    }

    private func masteryText(_ projection: PracticeMasteryProjection) -> String {
        if projection.state == .unknown { return localization.localized("practice.history.unknown") }
        guard let score = projection.score else { return localization.localized("practice.history.observed") }
        let stateLabel = localization.localized("practice.history.\(projection.state.rawValue)")
        return "\(stateLabel) · \(Int((score * 100).rounded()))%"
    }

    private func run(_ operation: @escaping () async throws -> Void) {
        Task { do { try await operation() } catch { errorMessage = localization.localized("practice.history.operationFailed") } }
    }
}
