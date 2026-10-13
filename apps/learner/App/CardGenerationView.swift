import Observation
import SwiftUI
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainAI
import LinguaBrainPersistence
import LinguaBrainTestSupport

@MainActor
@Observable
final class GenerationPrototypeModel {
    struct RenderableCard: Identifiable {
        let id: String
        var lemma: String
        var senseKey: String
        var senseText: String
        var translation: String
        var example: String
        var level: String
        let direction: ReviewDirection
        var state: CardState
        var audioAvailable: Bool = false
        var audioPlaybackState: AudioPlaybackState = .notAvailable
        var imageAvailable: Bool = false
        var fallbackReason: String?
    }
    
    enum CardState: String, Equatable {
        case reviewable
        case approved
        case rejected
    }
    
    enum AudioPlaybackState {
        case notAvailable
        case loading
        case loaded
        case playing
        case error
    }
    
    struct MediaStatus {
        let audioAvailable: Bool
        let audioPlaybackState: AudioPlaybackState
        let imageAvailable: Bool
        let fallbackReason: String?
    }
    
    var topic: String = ""
    var count: Int = 20
    var level: String = "A1"
    // In this generation prototype "source" is the learning language and
    // "target" is the translation language.
    var sourceLanguage: String = LearningContentRules.bundled.defaults.targetLanguageTag
    var targetLanguage: String = LearningContentRules.bundled.defaults.sourceLanguageTag
    var isGenerating = false
    var editorBeingEdited: String?
    var pendingEditText = ""
    var cards: [RenderableCard] = []
    var errorMessage: String?
    var currentProposal: CardProposal?
    
    private let useCase: ApprovalUseCase & GenerationUseCase
    private let persistence: PersistencePort
    
    /// Flag to enable audio generation during preview (T040)
    var includeAudioInPreview: Bool = false
    
    /// Injects the real application/persistence boundary. Defaults wire the
    /// deterministic providers used by the MVP harness.
    init(
        useCase: (ApprovalUseCase & GenerationUseCase)? = nil,
        persistence: PersistencePort? = nil
    ) {
        let repo = persistence ?? InMemoryPersistence()
        self.persistence = repo
        let orchestrator = useCase ?? AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: DeterministicTextProvider(),
            validator: StrictProposalValidator()
        )
        self.useCase = orchestrator
    }
    
    var approvedCount: Int { cards.filter { $0.state == .approved }.count }
    
    func generate() {
        errorMessage = nil
        guard !topic.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "generation.placeholder"
            return
        }
        Task { await runGeneration() }
    }
    
    private func runGeneration() async {
        let command = GenerationRequestCommand(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            level: level,
            topic: topic,
            count: count,
            directions: ReviewDirection.allCases,
            audioEnabled: includeAudioInPreview,
            imageEnabled: false
        )
        isGenerating = true
        defer { isGenerating = false }
        do {
            let job = try await useCase.startGeneration(from: command)
            guard let proposal = job.proposal else {
                errorMessage = "generation.error.noPreview"
                return
            }
            currentProposal = proposal
            render(proposal)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func render(_ proposal: CardProposal) {
        // Sense mapping: LexicalSense mapping + ordered Sentence mapping (T019)
        var senseMap: [String: LexicalSense] = [:]
        for sense in proposal.senses {
            senseMap[sense.senseKey] = sense
        }
        
        // Render cards with sense-aware rendering (T023)
        var rendered: [RenderableCard] = []
        for senseKey in senseMap.keys {
            guard let sense = senseMap[senseKey] else { continue }
            for direction in [ReviewDirection.recognition, .recall] {
                // Determine media availability based on whether audio was requested (T040)
                let mediaAvailable = includeAudioInPreview
                let fallbackReason = includeAudioInPreview ? nil : "generation.media.audioNotRequested"
                
                let mediaStatus = MediaStatus(
                    audioAvailable: mediaAvailable,
                    audioPlaybackState: mediaAvailable ? .notAvailable : .notAvailable,
                    imageAvailable: false,
                    fallbackReason: fallbackReason
                )
                let renderedCard = RenderableCard(
                    id: "\(senseKey)-\(direction.rawValue)",
                    lemma: proposal.lemma,
                    senseKey: senseKey,
                    senseText: sense.meaning,
                    translation: sense.translation,
                    example: sense.examples.first?.text ?? "",
                    level: sense.level ?? proposal.provenance.schemaVersion ?? "A1",
                    direction: direction,
                    state: .reviewable,
                    audioAvailable: mediaStatus.audioAvailable,
                    audioPlaybackState: mediaStatus.audioPlaybackState,
                    imageAvailable: mediaStatus.imageAvailable,
                    fallbackReason: mediaStatus.fallbackReason
                )
                rendered.append(renderedCard)
            }
        }
        
        cards = rendered
    }

    // MARK: Actions routed through the orchestrator.

    func edit(_ card: RenderableCard) {
        editorBeingEdited = card.id
        pendingEditText = card.senseText
    }

    func saveEdit() {
        guard let editorBeingEdited, let i = cards.firstIndex(where: { $0.id == editorBeingEdited }) else {
            self.editorBeingEdited = nil
            return
        }
        let original = cards[i]
        guard var proposal = currentProposal,
              let idx = proposal.senses.firstIndex(where: { $0.senseKey == original.senseKey }) else {
            self.editorBeingEdited = nil
            return
        }
        var edited = proposal.senses[idx]
        edited = LexicalSense(
            sourceLanguage: edited.sourceLanguage,
            targetLanguage: edited.targetLanguage,
            lemma: edited.lemma,
            senseKey: edited.senseKey,
            partOfSpeech: edited.partOfSpeech,
            meaning: pendingEditText,
            examples: edited.examples,
            translation: edited.translation,
            level: edited.level,
            qualifier: edited.qualifier,
            direction: edited.direction
        )
        proposal.senses[idx] = edited
        currentProposal = proposal
        Task {
            do {
                _ = try await useCase.apply(.edit(edited), proposal: proposal, direction: original.direction)
                cards[i].senseText = pendingEditText
                cards[i].state = .approved
            } catch {
                errorMessage = String(describing: error)
            }
        }
        self.editorBeingEdited = nil
    }

    func cancelEdit() {
        editorBeingEdited = nil
    }

    func approve(_ id: String) {
        guard let card = cards.first(where: { $0.id == id }) else { return }
        Task { await approveCard(card) }
    }

    private func approveCard(_ card: RenderableCard) async {
        guard let proposal = currentProposal else { return }
        do {
            _ = try await useCase.apply(.approve, proposal: proposal, direction: card.direction)
            if let i = cards.firstIndex(where: { $0.id == card.id }) {
                cards[i].state = .approved
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func reject(_ id: String) {
        guard let card = cards.first(where: { $0.id == id }) else { return }
        Task { await rejectCard(card) }
    }

    private func rejectCard(_ card: RenderableCard) async {
        guard let proposal = currentProposal else { return }
        do {
            _ = try await useCase.apply(.reject(reason: nil), proposal: proposal, direction: card.direction)
            if let i = cards.firstIndex(where: { $0.id == card.id }) {
                cards[i].state = .rejected
            }
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Reads persisted approved bundles back through the application/persistence boundary (restart proof).
    func reloadPersisted() async -> Int {
        (try? await persistence.approvedBundles().count) ?? 0
    }
}

struct CardGenerationView: View {
    @Bindable var model: GenerationPrototypeModel
    let localization: PrototypeLocalization

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                requestSection
                if !model.cards.isEmpty { previewSection }
            }
            .padding()
        }
        .navigationTitle(localization.localized("generation.title"))
    }

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(localization.localized("generation.placeholder"), text: $model.topic)
                .textFieldStyle(.roundedBorder)
            Toggle(localization.localized("provider.audio"), isOn: $model.includeAudioInPreview)
                .toggleStyle(.switch)
            HStack {
                Picker(localization.localized("generation.count"), selection: $model.count) {
                    ForEach(1...50, id: \.self) { Text("\($0)") }
                }
                Picker("→", selection: $model.sourceLanguage) {
                    Text("de").tag("de")
                    Text("en").tag("en")
                }
                Picker("←", selection: $model.targetLanguage) {
                    Text("fa").tag("fa")
                    Text("de").tag("de")
                }
            }
            Button(action: model.generate) {
                Label(localization.localized("generation.generate"),
                      systemImage: "wand.and.stars")
            }
            .disabled(model.isGenerating)
            if model.isGenerating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(localization.localized("generation.processing"))
                }
            }
            if let errorMessage = model.errorMessage {
                // Model errors are catalog keys or provider-supplied text; unknown keys fall back to the text itself.
                Text(localization.localized(errorMessage)).foregroundStyle(.red)
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localization.localized("generation.preview"))
                    .font(.headline)
                Spacer()
                Text("\(model.approvedCount) / \(model.cards.count) \(localization.localized("generation.approved"))")
                    .font(.caption)
            }
            Text(localization.localized("generation.offlineAvailable"))
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(model.cards) { card in
                cardRow(card)
            }
        }
    }

    private func cardRow(_ card: GenerationPrototypeModel.RenderableCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.lemma).font(.headline)
                Text("· \(card.level) / \(card.direction.rawValue)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                stateBadge(card.state)
            }
            if model.editorBeingEdited == card.id {
                TextField(localization.localized("generation.edit"), text: $model.pendingEditText)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(localization.localized("generation.approve"), action: { model.saveEdit() })
                    Button(localization.localized("generation.reject"), action: model.cancelEdit)
                }
            } else {
                Text(card.senseText)
                Text(card.translation).foregroundStyle(.secondary)
                Text(card.example).italic().font(.caption)
                HStack(spacing: 12) {
                    Button(localization.localized("generation.edit"), action: { model.edit(card) })
                    Button(localization.localized("generation.approve"), action: { model.approve(card.id) })
                        .disabled(card.state == .approved)
                    Button(localization.localized("generation.reject"), action: { model.reject(card.id) })
                        .disabled(card.state == .rejected)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
#if os(iOS)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
#elseif os(macOS)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
#endif
    }

    @ViewBuilder
    private func stateBadge(_ state: GenerationPrototypeModel.CardState) -> some View {
        switch state {
        case .reviewable:
            Text(localization.localized("generation.preview"))
                .font(.caption2).padding(6)
                .background(Capsule().fill(Color.gray.opacity(0.2)))
        case .approved:
            Text(localization.localized("generation.approved"))
                .font(.caption2).padding(6)
                .background(Capsule().fill(Color.green.opacity(0.2)))
        case .rejected:
            Text(localization.localized("generation.rejected"))
                .font(.caption2).padding(6)
                .background(Capsule().fill(Color.red.opacity(0.2)))
        }
    }
}
