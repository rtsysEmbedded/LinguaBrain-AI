import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import LinguaBrainDomain
import LinguaBrainAnkiExport
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum ExportFormat: String, CaseIterable {
    case tsv, apkg
}

struct LibraryPrototypeView: View {
    /// Rows rendered at once; review sessions still use the full collection.
    private static let displayLimit = 250

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var searchText = ""
    @State private var filter = "all"
    @State private var customDomains = PrototypeDomainCatalog.customDomains
    @State private var packagePendingDeletion: PrototypeImportedPackage?
    @State private var selectedCardIDs: Set<UUID> = []
    @State private var isSelectingCards = false
    @State private var isConfirmingCardDeletion = false
    @State private var deletionError: String?
    @State private var exportGroup: PrototypeCardProvenance?
    @State private var isExporting = false
    @State private var exportTSVDocument = AnkiTSVDocument(text: "")
    @State private var exportAPKGDocument = AnkiAPKGDocument()
    @State private var isSelectingExportCards = false
    @State private var exportCandidates: [PrototypeWord] = []
    @State private var selectedExportIDs: Set<UUID> = []
    @State private var exportFormat: ExportFormat = .tsv
    @State private var exportProgress: Double = 0.0
    @State private var exportStatus: ExportStatus = .notStarted

    fileprivate struct ExportStatusView: View {
        let progress: Double
        let status: ExportStatus

        var body: some View {
            VStack(spacing: 8) {
                if status == .inProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(LinearProgressViewStyle())
                }
                Text(status.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(progress > 0 && progress < 1 ? .orange : .primary)
            }
        }
    }

    private var activeWords: [PrototypeWord] {
        store.words(
            sourceLanguageTag: languageSettings.sourceLanguageTag,
            targetLanguageTag: languageSettings.targetLanguageTag
        )
    }

    private var filteredWords: [PrototypeWord] {
        let needle = normalizedSearchText
        var seenIDs = Set<UUID>()
        return activeWords.filter { word in
            // SwiftUI's ForEach requires stable, unique identity. De-duplicate
            // defensively before applying a live search to imported data.
            guard seenIDs.insert(word.id).inserted else { return false }
            let matchesSearch = needle.isEmpty || normalizedSearchText(for: word.german).contains(needle) || normalizedSearchText(for: word.persian).contains(needle)
            let matchesFilter = filter == "all" || (filter == "weak" && store.reviewCount(for: word) > 0 && store.strength(for: word) < 0.5) || filter == word.level || filter == word.domain
            return matchesSearch && matchesFilter
        }
    }

    private var normalizedSearchText: String { normalizedSearchText(for: searchText) }

    private func normalizedSearchText(for value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum SelectionCopy: String { case selectCards, cancel, selectAll, export, delete }

    private func selectionCopy(_ key: SelectionCopy) -> String {
        localization.localized("library.selection.\(key.rawValue)")
    }

    private func selectionCountCopy(_ count: Int) -> String {
        localization.formatted("library.selection.count", "\(count)")
    }

    var body: some View {
        AnyView(ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    MetricPill(value: "\(activeWords.count)", label: "library.metric.words", symbol: "textformat.abc", color: PrototypeTheme.accent)
                    MetricPill(value: "\(store.weakCount(in: activeWords))", label: "library.metric.weak", symbol: "exclamationmark.triangle.fill", color: .orange)
                    MetricPill(value: "\(store.reviewedCount(in: activeWords))", label: "library.metric.reviewed", symbol: "bolt.fill", color: PrototypeTheme.mint)
                }


                if !store.importedPackages.isEmpty {
                    importedPackagesSection
                }

                NavigationLink {
                    CardGalleryPrototypeView()
                } label: {
                    PrototypeCard {
                        HStack(spacing: 14) {
                            Image(systemName: "rectangle.on.rectangle.angled")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(PrototypeTheme.heroGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(localization.localized("library.gallery.title"))
                                    .font(.headline)
                                Text(localization.localized("library.gallery.subtitle"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.left")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)

                #if os(iOS)
                // On the current iOS 27 beta, attaching `searchable` to this
                // TabView-hosted, dynamically filtered navigation hierarchy can
                // terminate the app while the search controller updates. Keep
                // the same filtering behaviour with a regular field until that
                // beta issue is resolved.
                TextField(localization.localized("library.search.prompt"), text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("library-search-field")
                #endif

                Picker(filterLabel(.title), selection: $filter) {
                    Text(filterLabel(.all)).tag("all")
                    Text(filterLabel(.weak)).tag("weak")
                    ForEach(["A1", "B1", "B2"], id: \.self) { Text($0).tag($0) }
                    ForEach(customDomains, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        isSelectingCards.toggle()
                        if !isSelectingCards { selectedCardIDs.removeAll() }
                    } label: {
                        Label(selectionCopy(isSelectingCards ? .cancel : .selectCards), systemImage: isSelectingCards ? "xmark.circle" : "checkmark.circle")
                    }
                    .buttonStyle(.bordered)

                    if isSelectingCards {
                        Text(selectionCountCopy(selectedCardIDs.count))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            selectAllFilteredCards()
                        } label: {
                            Label(selectionCopy(.selectAll), systemImage: "checkmark.circle.badge.checkmark")
                        }
                        .buttonStyle(.bordered)
                        .disabled(filteredWords.isEmpty)
                        Button {
                            exportSelectedCards()
                        } label: {
                            Label(selectionCopy(.export), systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedCardIDs.isEmpty)
                        Spacer()
                        Button(role: .destructive) {
                            isConfirmingCardDeletion = true
                        } label: {
                            Label(selectionCopy(.delete), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedCardIDs.isEmpty)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                }

                LazyVStack(spacing: 12) {
                    // Keep the prototype library responsive for large imports;
                    // review sessions still use the full persisted collection.
                    ForEach(Array(filteredWords.prefix(Self.displayLimit))) { word in
                        if isSelectingCards {
                            Button {
                                toggleSelection(for: word)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedCardIDs.contains(word.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedCardIDs.contains(word.id) ? PrototypeTheme.accent : .secondary)
                                    wordRow(word)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(localization.formatted("library.selection.selectWordAccessibility", word.german))
                        } else {
                            NavigationLink {
                                WordDetailPrototypeView(word: word)
                            } label: {
                                wordRow(word)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if filteredWords.count > Self.displayLimit {
                    Text(localization.formatted(
                        "library.listLimited",
                        Self.displayLimit.formatted(.number.locale(localization.language.locale)),
                        "\(filteredWords.count)"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        })
        .onAppear { customDomains = PrototypeDomainCatalog.customDomains }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized("library.title"))
        #if os(macOS)
        .searchable(text: $searchText, prompt: localization.localized("library.search.prompt"))
        #endif
        .confirmationDialog(
            localization.localized("library.package.deleteTitle"),
            isPresented: deletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: packagePendingDeletion
        ) { package in
            Button(localization.formatted("library.package.deleteAction", package.fileName, "\(package.cardCount)"), role: .destructive) {
                deletePackage(package)
            }
            Button(localization.localized("common.cancel"), role: .cancel) {
                packagePendingDeletion = nil
            }
        } message: { package in
            Text(localization.localized("library.package.deleteMessage"))
        }
        .confirmationDialog(
            deleteTitle,
            isPresented: $isConfirmingCardDeletion,
            titleVisibility: .visible
        ) {
            Button(deleteAction, role: .destructive) {
                deleteSelectedCards()
            }
            Button(cancelAction, role: .cancel) { }
        } message: {
            Text(deleteMessage)
        }
        .alert(localization.localized("library.deleteFailed"), isPresented: deletionErrorBinding) {
            Button(localization.localized("common.ok"), role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? localization.localized("common.unknownError"))
        }
        .fileExporter(isPresented: apkgExportBinding, document: exportAPKGDocument, contentType: AnkiExportDocument.apkg, defaultFilename: "linguabrain-export.apkg") { result in
                switch result {
                case .success:
                    exportStatus = .completed
                    exportProgress = 1.0
                case .failure(let error):
                    exportStatus = .failed
                    deletionError = error.localizedDescription
                }
            }
        .fileExporter(isPresented: tsvExportBinding, document: exportTSVDocument, contentType: .plainText, defaultFilename: "linguabrain-cards.tsv") { result in
            switch result {
            case .success:
                exportStatus = .completed
                exportProgress = 1.0
            case .failure(let error):
                exportStatus = .failed
                deletionError = error.localizedDescription
            }
        }
        .sheet(isPresented: $isSelectingExportCards) {
            ExportCardSelectionView(
                cards: exportCandidates,
                selectedIDs: $selectedExportIDs,
                exportFormat: $exportFormat,
                onCancel: {
                    isSelectingExportCards = false
                },
                onExport: {
                    if exportFormat == .apkg {
                        let selected = exportCandidates.filter { selectedExportIDs.contains($0.id) }
                        isSelectingExportCards = false
                        Task {
                            do {
                                exportStatus = .inProgress
                                exportAPKGDocument = try await PrototypeAPKGExporter.makeDocument(from: selected, store: store)
                                exportStatus = .completed
                                isExporting = true
                            } catch {
                                exportStatus = .failed
                                deletionError = error.localizedDescription
                            }
                        }
                        return
                    } else {
                        let selected = exportCandidates.filter { selectedExportIDs.contains($0.id) }
                        exportTSVDocument = AnkiTSVDocument(text: AnkiTSVExporter.makeTSV(selected))
                    }
                    isSelectingExportCards = false
                    isExporting = true
                }
            )
        }
    }

    private var deleteTitle: String {
        localization.formatted("library.cards.deleteTitle", "\(selectedCardIDs.count)")
    }
    private var deleteAction: String {
        localization.localized("library.cards.deleteAction")
    }
    private var cancelAction: String { localization.localized("common.cancel") }
    private var deleteMessage: String {
        localization.localized("library.cards.deleteMessage")
    }

    private enum FilterCopy: String { case title, all, weak }
    private func filterLabel(_ key: FilterCopy) -> String {
        localization.localized("library.filter.\(key.rawValue)")
    }

    private var apkgExportBinding: Binding<Bool> {
        Binding(
            get: { isExporting && exportFormat == .apkg },
            set: { if !$0 { isExporting = false } }
        )
    }

    private var tsvExportBinding: Binding<Bool> {
        Binding(
            get: { isExporting && exportFormat == .tsv },
            set: { if !$0 { isExporting = false } }
        )
    }

    private var exportSection: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(localization.localized("export.title")).font(.headline)
                Text(localization.localized("export.subtitle")).font(.caption).foregroundStyle(.secondary)

                Picker(localization.localized("export.formatPicker"), selection: $exportFormat) {
                    Text(localization.localized("export.format.tsv")).tag(ExportFormat.tsv)
                    Text(localization.localized("export.format.apkg")).tag(ExportFormat.apkg)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                ForEach(PrototypeCardProvenance.allCases) { provenance in
                    let cards = store.words(sourceLanguageTag: languageSettings.sourceLanguageTag, targetLanguageTag: languageSettings.targetLanguageTag, provenance: provenance)
                    Button {
                        exportGroup = provenance
                        exportCandidates = cards
                        selectedExportIDs = Set(cards.map(\.id))
                        isSelectingExportCards = true
                    } label: {
                        HStack {
                            Label(localization.localized(provenance == .generated ? "export.generated" : "export.imported"), systemImage: provenance == .generated ? "wand.and.stars" : "square.and.arrow.down")
                            Spacer()
                            Text("\(cards.count)")
                        }
                    }
                    .disabled(cards.isEmpty)
                }
            }
            .padding()
        }
    }

    private var importedPackagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "library.packages.title", subtitle: "library.packages.subtitle")
            PrototypeCard {
                VStack(spacing: 0) {
                    ForEach(Array(store.importedPackages.enumerated()), id: \.element.id) { index, package in
                        if index > 0 { Divider().padding(.vertical, 10) }
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.stack.fill")
                                .foregroundStyle(PrototypeTheme.accent)
                                .frame(width: 38, height: 38)
                                .background(PrototypeTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(package.fileName).font(.headline)
                                Text(localization.formatted("library.packages.cardCount", "\(package.cardCount)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                packagePendingDeletion = package
                            } label: {
                                Label(localization.localized("common.delete"), systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: { packagePendingDeletion != nil },
            set: { if !$0 { packagePendingDeletion = nil } }
        )
    }

    private var deletionErrorBinding: Binding<Bool> {
        Binding(
            get: { deletionError != nil },
            set: { if !$0 { deletionError = nil } }
        )
    }

    private func deletePackage(_ package: PrototypeImportedPackage) {
        guard store.deleteImportedPackage(named: package.fileName) else {
            deletionError = store.lastPersistenceError
            return
        }
        packagePendingDeletion = nil
    }

    private func toggleSelection(for word: PrototypeWord) {
        if selectedCardIDs.contains(word.id) {
            selectedCardIDs.remove(word.id)
        } else {
            selectedCardIDs.insert(word.id)
        }
    }

    private func deleteSelectedCards() {
        let ids = selectedCardIDs
        guard !ids.isEmpty else { return }
        guard store.deleteCards(ids: ids) else {
            deletionError = store.lastPersistenceError
            return
        }
        selectedCardIDs.removeAll()
        isSelectingCards = false
    }

    /// Select every result currently narrowed by search/filter, including
    /// results beyond the 250-card rendering cap.
    private func selectAllFilteredCards() {
        selectedCardIDs.formUnion(filteredWords.map(\.id))
    }

    private func exportSelectedCards() {
        let cards = activeWords.filter { selectedCardIDs.contains($0.id) }
        guard !cards.isEmpty else { return }
        exportCandidates = cards
        selectedExportIDs = Set(cards.map(\.id))
        isSelectingExportCards = true
    }

    private func wordRow(_ word: PrototypeWord) -> some View {
        PrototypeCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(PrototypeTheme.accent.opacity(0.11))
                    Text(word.level).font(.caption.bold()).foregroundStyle(PrototypeTheme.accent)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    LanguageText(text: word.german, languageTag: word.targetLanguageTag, font: .headline)
                    LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .subheadline, color: .secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("\(word.partOfSpeech) · \(word.domain)").font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        if store.illustrationImage(for: word) != nil { Image(systemName: "photo.fill") }
                        if store.pronunciationAudio(for: word) != nil { Image(systemName: "speaker.wave.2.fill") }
                    }
                    .font(.caption2).foregroundStyle(PrototypeTheme.accent)
                    ProgressView(value: store.strength(for: word))
                        .frame(width: 72)
                        .tint(store.strength(for: word) < 0.5 ? .orange : PrototypeTheme.mint)
                }
                Image(systemName: "chevron.left").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

struct AnkiTSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct AnkiAPKGDocument: FileDocument {
    static var readableContentTypes: [UTType] { [AnkiExportDocument.apkg] }
    static var writableContentTypes: [UTType] { [AnkiExportDocument.apkg] }

    let sourceGroups: [String]
    let cardCount: Int
    let mediaCount: Int
    let data: Data

    init(
        sourceGroups: [String] = [],
        cardCount: Int = 0,
        mediaCount: Int = 0
        , data: Data = Data()
    ) {
        self.sourceGroups = sourceGroups
        self.cardCount = cardCount
        self.mediaCount = mediaCount
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        sourceGroups = []
        cardCount = 0
        mediaCount = 0
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

enum PrototypeAPKGExporter {
    @MainActor
    static func makeDocument(from words: [PrototypeWord], store: PrototypeStore) async throws -> AnkiAPKGDocument {
        guard !words.isEmpty else { throw AnkiExportError.noApprovedCards }
        let workspace = AppOwnedExportWorkspace()
        guard let directory = workspace.workspaceDirectory else {
            throw AnkiExportError.invalidPath(path: "export workspace unavailable")
        }
        let databaseURL = directory.appendingPathComponent("collection.anki21")
        let mediaDirectory = directory.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let model = AnkiCollectionMapper.mapBundleToModel(
            name: "HermesCard",
            fieldNames: [
                "Front", "Back", "Example", "ExampleTranslation", "Level", "PartOfSpeech", "Domain",
                "SourceLanguageTag", "TargetLanguageTag", "Direction", "Provider", "GeneratedAt", "Audio", "Image"
            ]
        )
        let deck = AnkiCollectionMapper.mapBundleToDeck(sourceGroup: "hermes", languagePair: (words[0].sourceLanguageTag, words[0].targetLanguageTag))
        var builder = try AnkiCollectionBuilder(dbURL: databaseURL)
        try builder.insertModel(model)
        try builder.insertDeck(deck)
        var bundles: [GeneratedCardBundle] = []
        var allMediaAssets: [MediaAsset] = []
        for word in words {
            let sense = LexicalSense(sourceLanguage: word.sourceLanguageTag, targetLanguage: word.targetLanguageTag, lemma: word.german, senseKey: word.id.uuidString, partOfSpeech: word.partOfSpeech, meaning: word.persian, translation: word.persian, level: word.level, direction: .recognition)
            let identity = CardIdentity(sourceLanguage: word.sourceLanguageTag, targetLanguage: word.targetLanguageTag, lemma: word.german, senseKey: sense.senseKey, partOfSpeech: word.partOfSpeech, direction: .recognition)
            var mediaAssets: [MediaAsset] = []
            var audioFilename: String?
            var imageFilename: String?
            if let audio = store.pronunciationAudio(for: word) {
                let filename = "audio-\(word.id.uuidString).\(audioFileExtension(for: audio))"
                audioFilename = filename
                let url = mediaDirectory.appendingPathComponent(filename)
                try audio.write(to: url, options: .atomic)
                let asset = MediaAsset(kind: .audio, locale: word.targetLanguageTag, checksum: "", fileSize: audio.count, provider: "local", model: "prototype", cacheReference: url.path)
                mediaAssets.append(asset)
                allMediaAssets.append(asset)
            }
            if let image = store.illustrationImage(for: word) {
                let filename = "image-\(word.id.uuidString).\(imageFileExtension(for: image))"
                imageFilename = filename
                let url = mediaDirectory.appendingPathComponent(filename)
                try image.write(to: url, options: .atomic)
                let asset = MediaAsset(kind: .image, locale: word.targetLanguageTag, checksum: "", fileSize: image.count, provider: "local", model: "prototype", cacheReference: url.path)
                mediaAssets.append(asset)
                allMediaAssets.append(asset)
            }
            let bundle = GeneratedCardBundle(identity: identity, senses: [sense], directions: [.recognition], mediaAssets: mediaAssets, approvalState: .approved, provenance: Provenance(provider: "hermes", model: "prototype"))
            bundles.append(bundle)
            let mappedNote = AnkiCollectionMapper.mapBundleToNote(bundle, modelID: model.modelID, deckID: deck.deckID)
            let note = AnkiNoteRecord(
                noteID: mappedNote.noteID,
                modelID: mappedNote.modelID,
                deckID: mappedNote.deckID,
                fieldStrings: [
                    word.german,
                    word.persian,
                    word.example,
                    word.exampleTranslation,
                    word.level,
                    word.partOfSpeech,
                    word.domain,
                    word.sourceLanguageTag,
                    word.targetLanguageTag,
                    "recognition",
                    "hermes",
                    mappedNote.creationTime.description,
                    audioFilename.map { "[sound:\($0)]" } ?? "",
                    imageFilename.map { "<img src=\"\($0)\">" } ?? ""
                ],
                tags: mappedNote.tags,
                sortIDX: mappedNote.sortIDX,
                creationTime: mappedNote.creationTime,
                modificationTime: mappedNote.modificationTime
            )
            try builder.insertNote(note)
            try builder.insertCard(AnkiCollectionMapper.mapBundleToCard(bundle: bundle, noteID: note.noteID, deckID: deck.deckID))
            for tag in AnkiCollectionMapper.mapBundleToTags(bundle: bundle) { try builder.insertTag(tag) }
        }
        try builder.finalizeCollection()
        builder.close()
        let mediaEntries = try await AnkiMediaPackager().packageMedia(
            from: allMediaAssets,
            to: mediaDirectory,
            config: AnkiExportConfiguration()
        )
        let manifest = ExportManifest(
            sourceGroups: ["hermes"],
            cardIdentities: bundles.map { $0.identity.compositeKey },
            mediaEntries: mediaEntries
        )
        let destination = directory.appendingPathComponent("prototype.apkg")
        _ = try await AnkiPackageWriter().createAPKG(collectionURL: databaseURL, mediaDirectory: mediaDirectory, manifest: manifest, destination: destination)
        let data = try Data(contentsOf: destination)
        return AnkiAPKGDocument(sourceGroups: ["hermes"], cardCount: words.count, data: data)
    }

    private static func audioFileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 12,
           bytes[0...3].elementsEqual([0x52, 0x49, 0x46, 0x46]),
           bytes[8...11].elementsEqual([0x57, 0x41, 0x56, 0x45]) {
            return "wav"
        }
        if bytes.count >= 4, bytes[0...3].elementsEqual([0x4F, 0x67, 0x67, 0x53]) {
            return "ogg"
        }
        if bytes.count >= 8, bytes[4...7].elementsEqual([0x66, 0x74, 0x79, 0x70]) {
            return "m4a"
        }
        return "mp3"
    }

    private static func imageFileExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(12))
        if bytes.count >= 8,
           bytes[0...7].elementsEqual([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
            return "png"
        }
        if bytes.count >= 3, bytes[0...2].elementsEqual([0xFF, 0xD8, 0xFF]) {
            return "jpg"
        }
        if bytes.count >= 6,
           bytes[0...5].elementsEqual([0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
           bytes[0...5].elementsEqual([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]) {
            return "gif"
        }
        if bytes.count >= 12,
           bytes[0...3].elementsEqual([0x52, 0x49, 0x46, 0x46]),
           bytes[8...11].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
            return "webp"
        }
        return "png"
    }
}

enum AnkiTSVExporter {
    static func makeTSV(_ cards: [PrototypeWord]) -> String {
        let header = ["Front", "Back", "Example", "Example translation", "Level", "Part of speech", "Tags"].joined(separator: "\t")
        let rows = cards.map { card in
            let targetExamples = card.examples.map(\.target).joined(separator: "<br>")
            let sourceExamples = card.examples.map(\.source).joined(separator: "<br>")
            return [card.german, card.persian, targetExamples, sourceExamples, card.level, card.partOfSpeech, card.domain]
                .map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
                .joined(separator: "\t")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }
}

private struct ExportCardSelectionView: View {
    @Environment(PrototypeLocalization.self) private var localization
    let cards: [PrototypeWord]
    @Binding var selectedIDs: Set<UUID>
    @Binding var exportFormat: ExportFormat
    let onCancel: () -> Void
    let onExport: () -> Void

    var body: some View {
        NavigationStack {
            List(cards) { card in
                Button {
                    if selectedIDs.contains(card.id) { selectedIDs.remove(card.id) }
                    else { selectedIDs.insert(card.id) }
                } label: {
                    HStack {
                        Image(systemName: selectedIDs.contains(card.id) ? "checkmark.circle.fill" : "circle")
                        VStack(alignment: .leading) {
                            Text(card.german)
                            Text(card.persian).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle(localization.localized("export.selectTitle"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(localization.localized("common.cancel"), action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localization.localized("export.exportSelected")) {
                        if exportFormat == .apkg {
                            onExport()
                        } else {
                            onExport()
                        }
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }
}

private enum MVPCardKind: String, CaseIterable, Identifiable {
    case word, noun, verb, recognition, reverseTranslation, cloze, listening, feedback, dailyPlan, mastery

    var id: Self { self }

    var titleKey: String { "gallery.kind.\(rawValue).title" }
    var purposeKey: String { "gallery.kind.\(rawValue).purpose" }

    var symbol: String {
        switch self {
        case .word: "textformat.abc"
        case .noun: "character.book.closed.fill"
        case .verb: "arrow.triangle.branch"
        case .recognition: "eye.fill"
        case .reverseTranslation: "arrow.left.arrow.right"
        case .cloze: "rectangle.and.pencil.and.ellipsis"
        case .listening: "ear.fill"
        case .feedback: "checkmark.bubble.fill"
        case .dailyPlan: "calendar.badge.clock"
        case .mastery: "chart.bar.fill"
        }
    }

    var color: Color {
        switch self {
        case .word, .recognition: PrototypeTheme.accent
        case .noun, .listening: PrototypeTheme.blue
        case .verb, .cloze: .orange
        case .reverseTranslation, .dailyPlan: PrototypeTheme.pink
        case .feedback, .mastery: PrototypeTheme.mint
        }
    }
}

struct CardGalleryPrototypeView: View {
    @Environment(PrototypeLocalization.self) private var localization

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "gallery.header.title",
                    subtitle: "gallery.header.subtitle"
                )

                ForEach(MVPCardKind.allCases) { kind in
                    NavigationLink {
                        CardSpecPrototypeView(kind: kind)
                    } label: {
                        PrototypeCard {
                            HStack(spacing: 14) {
                                Image(systemName: kind.symbol)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(kind.color)
                                    .frame(width: 44, height: 44)
                                    .background(kind.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(localization.localized(kind.titleKey)).font(.headline)
                                    Text(localization.localized(kind.purposeKey)).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.left").font(.caption.bold()).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized("gallery.title"))
    }
}

private struct CardSpecPrototypeView: View {
    let kind: MVPCardKind
    @Environment(PrototypeLocalization.self) private var localization
    @State private var isRevealed = false
    @State private var selectedAnswer: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Label(localization.localized(kind.titleKey), systemImage: kind.symbol)
                        .font(.headline)
                        .foregroundStyle(kind.color)
                    Spacer()
                    Text(localization.localized("gallery.contentSample"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }

                preview

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localization.localized("gallery.cardPurpose")).font(.headline)
                        Text(localization.localized(kind.purposeKey)).foregroundStyle(.secondary)
                        Text(localization.localized("gallery.reviewNote"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized(kind.titleKey))
    }

    @ViewBuilder
    private var preview: some View {
        switch kind {
        case .word:
            learningCard {
                cardHeader(level: text("gallery.target.level.b1"), type: text("gallery.target.partOfSpeech.adjective"))
                GermanText(text: text("gallery.target.word"), font: .largeTitle.weight(.bold))
                Text(text("gallery.sample.word.meaning")).font(.title3)
                Divider()
                GermanText(text: text("gallery.target.wordExample"), font: .headline)
                Text(text("gallery.sample.word.exampleTranslation")).foregroundStyle(.secondary)
            }
        case .noun:
            learningCard {
                cardHeader(level: text("gallery.target.level.b1"), type: text("gallery.target.partOfSpeech.noun"))
                GermanText(text: text("gallery.target.noun"), font: .largeTitle.weight(.bold))
                Text(text("gallery.sample.noun.meaning")).font(.title3)
                Divider()
                factRow(text("gallery.target.label.article"), text("gallery.target.article"))
                factRow(text("gallery.target.label.plural"), text("gallery.target.plural"))
                factRow(text("gallery.sample.commonCollocation"), text("gallery.target.collocation"))
            }
        case .verb:
            learningCard {
                cardHeader(level: text("gallery.target.level.a1"), type: text("gallery.target.partOfSpeech.verb"))
                GermanText(text: text("gallery.target.verb"), font: .largeTitle.weight(.bold))
                Text(text("gallery.sample.verb.meaning")).font(.title3)
                Divider()
                factRow(text("gallery.target.label.present"), text("gallery.target.present"))
                factRow(text("gallery.target.label.preterite"), text("gallery.target.preterite"))
                factRow(text("gallery.target.label.perfect"), text("gallery.target.perfect"))
            }
        case .recognition:
            questionCard(
                prompt: text("gallery.target.verb"),
                instruction: text("gallery.sample.recognition.instruction"),
                answers: [
                    text("gallery.sample.recognition.answer1"),
                    text("gallery.sample.recognition.answer2"),
                    text("gallery.sample.recognition.answer3")
                ]
            )
        case .reverseTranslation:
            learningCard {
                Text(text("gallery.sample.reverse.instruction")).font(.subheadline).foregroundStyle(.secondary)
                Text(text("gallery.sample.reverse.prompt")).font(.largeTitle.weight(.bold))
                Divider()
                Button(isRevealed ? text("gallery.target.reverseAnswer") : text("gallery.sample.revealAnswer")) { isRevealed = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        case .cloze:
            questionCard(
                prompt: text("gallery.target.cloze"),
                instruction: text("gallery.sample.cloze.instruction"),
                answers: [
                    text("gallery.target.cloze.answer1"),
                    text("gallery.target.cloze.answer2"),
                    text("gallery.target.cloze.answer3")
                ]
            )
        case .listening:
            learningCard {
                Text(text("gallery.sample.listening.instruction")).font(.headline)
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(PrototypeTheme.blue.gradient, in: Circle())
                }
                .frame(maxWidth: .infinity)
                Text(text("gallery.sample.listening.hint")).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        case .feedback:
            learningCard {
                Label(text("gallery.sample.feedback.title"), systemImage: "exclamationmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.orange)
                GermanText(text: text("gallery.target.feedbackSentence"), font: .title2.weight(.semibold))
                Text(text("gallery.sample.feedback.explanation")).foregroundStyle(.secondary)
                Button(text("gallery.sample.feedback.retry")) { }.buttonStyle(.borderedProminent)
            }
        case .dailyPlan:
            learningCard {
                Text(localization.formatted("gallery.sample.plan.title", minutes(20))).font(.title2.weight(.bold))
                planRow(text("gallery.sample.plan.review"), minutes(8), "arrow.clockwise", PrototypeTheme.accent)
                planRow(localization.formatted("gallery.sample.plan.new", number(5)), minutes(5), "plus.circle.fill", PrototypeTheme.pink)
                planRow(text("gallery.sample.plan.listening"), minutes(7), "ear.fill", PrototypeTheme.blue)
                Button(text("gallery.sample.plan.start")) { }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        case .mastery:
            learningCard {
                GermanText(text: text("gallery.target.verb"), font: .title.weight(.bold))
                SkillProgressRow(label: "gallery.sample.mastery.recognition", value: 0.92, color: PrototypeTheme.mint)
                SkillProgressRow(label: "gallery.sample.mastery.recall", value: 0.68, color: PrototypeTheme.accent)
                SkillProgressRow(label: "progress.skill.listening", value: 0.54, color: PrototypeTheme.blue)
                SkillProgressRow(label: "gallery.sample.mastery.production", value: 0.36, color: .orange)
            }
        }
    }

    private func text(_ key: String) -> String {
        localization.localized(key)
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(localization.language.locale))
    }

    private func minutes(_ value: Int) -> String {
        localization.minutesLong(value)
    }

    private func learningCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14, content: content)
        }
    }

    private func cardHeader(level: String, type: String) -> some View {
        HStack {
            Text(level).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 5).background(kind.color.opacity(0.12), in: Capsule())
            Text(type).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(action: {}) { Image(systemName: "speaker.wave.2.fill") }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).environment(\.layoutDirection, .leftToRight)
        }
    }

    private func questionCard(prompt: String, instruction: String, answers: [String]) -> some View {
        learningCard {
            Text(instruction).font(.subheadline).foregroundStyle(.secondary)
            GermanText(text: prompt, font: .title.weight(.bold))
            Divider()
            ForEach(answers, id: \.self) { answer in
                Button {
                    selectedAnswer = answer
                } label: {
                    HStack {
                        Text(answer)
                        Spacer()
                        Image(systemName: selectedAnswer == answer ? "checkmark.circle.fill" : "circle")
                    }
                    .padding(12)
                    .background(selectedAnswer == answer ? kind.color.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func planRow(_ title: String, _ duration: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 30)
            Text(title)
            Spacer()
            Text(duration).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct WordDetailPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    let word: PrototypeWord
    @State private var audioPlayer: AVAudioPlayer?

    private var relatedWords: [PrototypeWord] {
        store.relatedWords(to: word)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PrototypeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(word.level)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(PrototypeTheme.accent.opacity(0.12), in: Capsule())
                            Text(word.partOfSpeech).font(.caption).foregroundStyle(.secondary)
                            Text(word.domain)
                                .font(.caption)
                                .foregroundStyle(PrototypeTheme.accent)
                            Spacer()
                            if let audio = store.pronunciationAudio(for: word) {
                                Button {
                                    audioPlayer = try? AVAudioPlayer(data: audio)
                                    audioPlayer?.play()
                                } label: { Image(systemName: "speaker.wave.2.fill") }
                            }
                        }
                        LanguageText(text: word.german, languageTag: word.targetLanguageTag, font: .largeTitle.weight(.bold))
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title3)
                    }
                }

                #if os(macOS)
                if let image = store.illustrationImage(for: word), let nsImage = NSImage(data: image) {
                    PrototypeCard {
                        Image(nsImage: nsImage)
                            .resizable().scaledToFit().frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                }
                #else
                if let image = store.illustrationImage(for: word), let uiImage = UIImage(data: image) {
                    PrototypeCard {
                        Image(uiImage: uiImage)
                            .resizable().scaledToFit().frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                    }
                }
                #endif

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(localization.localized("wordDetail.example")).font(.headline)
                        LanguageText(text: word.example, languageTag: word.targetLanguageTag, font: .title3)
                        LanguageText(text: word.exampleTranslation, languageTag: word.sourceLanguageTag, color: .secondary)
                    }
                }

                if !word.senses.isEmpty {
                    PrototypeCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(localization.localized("wordDetail.independentSenses")).font(.headline)
                            ForEach(Array(word.senses.enumerated()), id: \.offset) { index, sense in
                                VStack(alignment: .leading, spacing: 5) {
                                    LanguageText(text: "\(index + 1). \(sense.meaning)", languageTag: word.sourceLanguageTag, font: .headline)
                                    if !sense.usage.isEmpty {
                                        Text(sense.usage).font(.caption).foregroundStyle(.secondary)
                                    }
                                    LanguageText(text: sense.example.target, languageTag: word.targetLanguageTag, font: .body)
                                    LanguageText(text: sense.example.source, languageTag: word.sourceLanguageTag, font: .subheadline, color: .secondary)
                                    if !sense.collocations.isEmpty {
                                        Text(sense.collocations.joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(PrototypeTheme.accent)
                                    }
                                }
                                if index < word.senses.count - 1 { Divider() }
                            }
                        }
                    }
                }

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(localization.localized("wordDetail.wordNetwork")).font(.headline)
                        if relatedWords.isEmpty {
                            Text(localization.localized("wordDetail.noRelated"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: 10) {
                                ForEach(relatedWords) { related in
                                    NavigationLink {
                                        WordDetailPrototypeView(word: related)
                                    } label: {
                                        Text(related.german)
                                            .font(.subheadline)
                                            .environment(\.layoutDirection, .leftToRight)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(PrototypeTheme.accent.opacity(0.1), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(word.german)
    }
}

public enum ExportStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
    case failed
    case cancelled

    public var localizedDescription: String {
        switch self {
        case .notStarted: return "notStarted"
        case .inProgress: return "inProgress"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        }
    }
}

public struct AnkiExportDocument {
    public static let apkg: UTType = {
        UTType("com.anki.apkg") ?? UTType("public.data")!
    }()
}
