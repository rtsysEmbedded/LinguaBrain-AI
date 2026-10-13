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

    private enum SelectionCopy { case selectCards, cancel, selectAll, export, delete }

    private func selectionCopy(_ key: SelectionCopy) -> String {
        switch (localization.language, key) {
        case (.english, .selectCards): "Select cards"
        case (.english, .cancel): "Cancel selection"
        case (.english, .selectAll): "Select all"
        case (.english, .export): "Export selected"
        case (.english, .delete): "Delete selected"
        case (.german, .selectCards): "Karten auswählen"
        case (.german, .cancel): "Auswahl aufheben"
        case (.german, .selectAll): "Alle auswählen"
        case (.german, .export): "Auswahl exportieren"
        case (.german, .delete): "Auswahl löschen"
        case (.persian, .selectCards): "انتخاب کارت‌ها"
        case (.persian, .cancel): "لغو انتخاب"
        case (.persian, .selectAll): "انتخاب همه"
        case (.persian, .export): "خروجی انتخاب‌شده‌ها"
        case (.persian, .delete): "حذف انتخاب‌شده‌ها"
        }
    }

    private func selectionCountCopy(_ count: Int) -> String {
        switch localization.language {
        case .english: "\(count) cards selected"
        case .german: "\(count) Karten ausgewählt"
        case .persian: "\(count) کارت انتخاب شده"
        }
    }

    var body: some View {
        AnyView(ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    MetricPill(value: "\(activeWords.count)", label: "واژه", symbol: "textformat.abc", color: PrototypeTheme.accent)
                    MetricPill(value: "\(store.weakCount(in: activeWords))", label: "ضعیف", symbol: "exclamationmark.triangle.fill", color: .orange)
                    MetricPill(value: "\(store.reviewedCount(in: activeWords))", label: "مرور شده", symbol: "bolt.fill", color: PrototypeTheme.mint)
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
                                Text("گالری کارت‌های MVP")
                                    .font(.headline)
                                Text("۱۰ کارت پایه را پیش از نهایی‌کردن گرافیک بررسی کن")
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
                TextField("جست‌وجوی فارسی یا آلمانی", text: $searchText)
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
                    ForEach(Array(filteredWords.prefix(250))) { word in
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
                            .accessibilityLabel("انتخاب \(word.german)")
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
                if filteredWords.count > 250 {
                    Text("نمایش ۲۵۰ کارت اول از \(filteredWords.count) کارت؛ برای مرور از جلسهٔ امروز استفاده کن.")
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
        .navigationTitle("کتابخانه")
        #if os(macOS)
        .searchable(text: $searchText, prompt: "جست‌وجوی فارسی یا آلمانی")
        #endif
        .confirmationDialog(
            "حذف فایل Anki؟",
            isPresented: deletionConfirmationBinding,
            titleVisibility: .visible,
            presenting: packagePendingDeletion
        ) { package in
            Button("حذف \(package.fileName) و \(package.cardCount) کارت", role: .destructive) {
                deletePackage(package)
            }
            Button("انصراف", role: .cancel) {
                packagePendingDeletion = nil
            }
        } message: { package in
            Text("کارت‌های واردشده از این فایل و تاریخچهٔ مرور وابسته به آن‌ها از دیتابیس LinguaBrain حذف می‌شوند. این کار فایل اصلی روی دستگاه را پاک نمی‌کند.")
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
        .alert("حذف انجام نشد", isPresented: deletionErrorBinding) {
            Button("باشه", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "خطای ناشناخته")
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
        switch localization.language { case .english: "Delete \(selectedCardIDs.count) cards?"; case .german: "\(selectedCardIDs.count) Karten löschen?"; case .persian: "حذف \(selectedCardIDs.count) کارت؟" }
    }
    private var deleteAction: String {
        switch localization.language { case .english: "Delete cards and related data"; case .german: "Karten und zugehörige Daten löschen"; case .persian: "حذف کارت‌ها و همهٔ داده‌های وابسته" }
    }
    private var cancelAction: String { localization.language == .english ? "Cancel" : localization.language == .german ? "Abbrechen" : "انصراف" }
    private var deleteMessage: String {
        switch localization.language { case .english: "Cards, saved audio and images, review history, learning state, and related events will be permanently deleted."; case .german: "Karten, Medien, Lernverlauf und zugehörige Ereignisse werden dauerhaft gelöscht."; case .persian: "کارت‌ها، صدای تلفظ و تصویر ذخیره‌شده، تاریخچهٔ مرور و داده‌های وابسته حذف می‌شوند. این کار قابل بازگردانی نیست." }
    }

    private enum FilterCopy { case title, all, weak }
    private func filterLabel(_ key: FilterCopy) -> String {
        switch (localization.language, key) {
        case (.english, .title): "Filter"; case (.english, .all): "All"; case (.english, .weak): "Weak"
        case (.german, .title): "Filter"; case (.german, .all): "Alle"; case (.german, .weak): "Schwach"
        case (.persian, .title): "فیلتر"; case (.persian, .all): "همه"; case (.persian, .weak): "ضعیف"
        }
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

                Picker("Export Format", selection: $exportFormat) {
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
            SectionHeader(title: "فایل‌های Anki واردشده", subtitle: "مدیریت داده‌های اضافه‌شده به LinguaBrain")
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
                                Text("\(package.cardCount) کارت")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                packagePendingDeletion = package
                            } label: {
                                Label("حذف", systemImage: "trash")
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

    var title: String {
        switch self {
        case .word: "کارت واژه"
        case .noun: "کارت اسم"
        case .verb: "کارت فعل"
        case .recognition: "مرور تشخیصی"
        case .reverseTranslation: "ترجمهٔ معکوس"
        case .cloze: "جای‌خالی"
        case .listening: "شنیداری"
        case .feedback: "نتیجه و بازخورد"
        case .dailyPlan: "برنامهٔ امروز"
        case .mastery: "وضعیت یادگیری"
        }
    }

    var purpose: String {
        switch self {
        case .word: "معنی، تلفظ، مثال و زمینه"
        case .noun: "Artikel، جمع و کاربرد اسمی"
        case .verb: "صرف‌ها، Perfekt و الگوی کاربرد"
        case .recognition: "تشخیص معنی آلمانی به فارسی"
        case .reverseTranslation: "یادآوری فعال فارسی به آلمانی"
        case .cloze: "انتخاب واژه در بافت جمله"
        case .listening: "تشخیص واژه یا جمله از صدا"
        case .feedback: "خطای مشخص و فرصت اصلاح"
        case .dailyPlan: "ترکیب مرور، واژهٔ جدید و مهارت"
        case .mastery: "نمایش تسلط مستقل هر مهارت"
        }
    }

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
                    title: "حداقل کارت‌های نسخهٔ اول",
                    subtitle: "این گالری برای بررسی محتوا و تعامل است؛ رنگ و گرافیک هنوز نهایی نیست."
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
                                    Text(localization.localized(kind.title)).font(.headline)
                                    Text(localization.localized(kind.purpose)).font(.subheadline).foregroundStyle(.secondary)
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
        .navigationTitle("گالری کارت‌ها")
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
                    Label(kind.title, systemImage: kind.symbol)
                        .font(.headline)
                        .foregroundStyle(kind.color)
                    Spacer()
                    Text("نمونهٔ محتوایی")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }

                preview

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("هدف این کارت").font(.headline)
                        Text(localization.localized(kind.purpose)).foregroundStyle(.secondary)
                        Text("در بازبینی، وضوح سؤال، اطلاعات ضروری، پاسخ مورد انتظار و بازخورد را بررسی می‌کنیم؛ تزئینات بصری بعداً نهایی می‌شوند.")
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
        .navigationTitle(kind.title)
    }

    @ViewBuilder
    private var preview: some View {
        switch kind {
        case .word:
            learningCard {
                cardHeader(level: "B1", type: "Adjektiv")
                GermanText(text: "zuverlässig", font: .largeTitle.weight(.bold))
                Text("قابل اعتماد").font(.title3)
                Divider()
                GermanText(text: "Sie ist eine sehr zuverlässige Kollegin.", font: .headline)
                Text("او همکار بسیار قابل اعتمادی است.").foregroundStyle(.secondary)
            }
        case .noun:
            learningCard {
                cardHeader(level: "B1", type: "Nomen")
                GermanText(text: "die Entscheidung", font: .largeTitle.weight(.bold))
                Text("تصمیم").font(.title3)
                Divider()
                factRow("Artikel", "die")
                factRow("Plural", "die Entscheidungen")
                factRow("ترکیب رایج", "eine Entscheidung treffen")
            }
        case .verb:
            learningCard {
                cardHeader(level: "A1", type: "Verb")
                GermanText(text: "arbeiten", font: .largeTitle.weight(.bold))
                Text("کار کردن").font(.title3)
                Divider()
                factRow("Präsens", "er arbeitet")
                factRow("Präteritum", "arbeitete")
                factRow("Perfekt", "hat gearbeitet")
            }
        case .recognition:
            questionCard(prompt: "arbeiten", instruction: "معنی این واژه چیست؟", answers: ["کار کردن", "خرید کردن", "منتظر ماندن"])
        case .reverseTranslation:
            learningCard {
                Text("واژهٔ آلمانی را به یاد بیاور").font(.subheadline).foregroundStyle(.secondary)
                Text("تصمیم گرفتن").font(.largeTitle.weight(.bold))
                Divider()
                Button(isRevealed ? "entscheiden" : "نمایش پاسخ") { isRevealed = true }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        case .cloze:
            questionCard(prompt: "Ich ___ heute von zu Hause.", instruction: "جای خالی را کامل کن", answers: ["arbeite", "arbeitest", "arbeitet"])
        case .listening:
            learningCard {
                Text("گوش بده و پاسخ مناسب را انتخاب کن").font(.headline)
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 74, height: 74)
                        .background(PrototypeTheme.blue.gradient, in: Circle())
                }
                .frame(maxWidth: .infinity)
                Text("پخش با سرعت عادی · امکان تکرار").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        case .feedback:
            learningCard {
                Label("تقریباً درست بود", systemImage: "exclamationmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.orange)
                GermanText(text: "Ich arbeite heute.", font: .title2.weight(.semibold))
                Text("فعل درست بود؛ فقط صرف فعل باید با فاعل «ich» هماهنگ شود.").foregroundStyle(.secondary)
                Button("یک‌بار دیگر امتحان کن") { }.buttonStyle(.borderedProminent)
            }
        case .dailyPlan:
            learningCard {
                Text("برنامهٔ امروز · ۲۰ دقیقه").font(.title2.weight(.bold))
                planRow("مرور نزدیک فراموشی", "۸ دقیقه", "arrow.clockwise", PrototypeTheme.accent)
                planRow("۵ واژهٔ جدید", "۵ دقیقه", "plus.circle.fill", PrototypeTheme.pink)
                planRow("شنیداری محیط کار", "۷ دقیقه", "ear.fill", PrototypeTheme.blue)
                Button("شروع جلسه") { }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        case .mastery:
            learningCard {
                GermanText(text: "arbeiten", font: .title.weight(.bold))
                SkillProgressRow(label: "تشخیص", value: 0.92, color: PrototypeTheme.mint)
                SkillProgressRow(label: "یادآوری", value: 0.68, color: PrototypeTheme.accent)
                SkillProgressRow(label: "شنیداری", value: 0.54, color: PrototypeTheme.blue)
                SkillProgressRow(label: "تولید", value: 0.36, color: .orange)
            }
        }
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
                        Text("مثال").font(.headline)
                        LanguageText(text: word.example, languageTag: word.targetLanguageTag, font: .title3)
                        LanguageText(text: word.exampleTranslation, languageTag: word.sourceLanguageTag, color: .secondary)
                    }
                }

                if !word.senses.isEmpty {
                    PrototypeCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Independent meanings and usage").font(.headline)
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
                        Text("شبکه واژگان").font(.headline)
                        if relatedWords.isEmpty {
                            Text("هنوز واژهٔ مرتبطی در کتابخانه پیدا نشد.")
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
