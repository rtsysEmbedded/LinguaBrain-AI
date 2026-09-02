import SwiftUI
import UniformTypeIdentifiers
import LinguaBrainDomain
import LinguaBrainAnkiExport

enum ExportFormat: String, CaseIterable {
    case tsv, apkg
}

struct LibraryPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var searchText = ""
    @State private var filter = "همه"
    @State private var customDomains = PrototypeDomainCatalog.customDomains
    @State private var packagePendingDeletion: PrototypeImportedPackage?
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
        activeWords.filter { word in
            let matchesSearch = searchText.isEmpty || word.german.localizedCaseInsensitiveContains(searchText) || word.persian.contains(searchText)
            let matchesFilter = filter == "همه" || (filter == "ضعیف" && store.reviewCount(for: word) > 0 && store.strength(for: word) < 0.5) || filter == word.level || filter == word.domain
            return matchesSearch && matchesFilter
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

                exportSection

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

                Picker("فیلتر", selection: $filter) {
                    ForEach(["همه", "ضعیف", "A1", "B1", "B2"], id: \.self) { Text($0) }
                    ForEach(customDomains, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)

                LazyVStack(spacing: 12) {
                    // Keep the prototype library responsive for large imports;
                    // review sessions still use the full persisted collection.
                    ForEach(Array(filteredWords.prefix(250))) { word in
                        NavigationLink {
                            WordDetailPrototypeView(word: word)
                        } label: {
                            wordRow(word)
                        }
                        .buttonStyle(.plain)
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
        .searchable(text: $searchText, prompt: "جست‌وجوی فارسی یا آلمانی")
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

private enum PrototypeAPKGExporter {
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
        let model = AnkiCollectionMapper.mapBundleToModel(name: "HermesCard", fieldNames: ["Front", "Back", "Direction", "Provider", "GeneratedAt"])
        let deck = AnkiCollectionMapper.mapBundleToDeck(sourceGroup: "hermes", languagePair: (words[0].sourceLanguageTag, words[0].targetLanguageTag))
        var builder = try AnkiCollectionBuilder(dbURL: databaseURL)
        try builder.insertModel(model)
        try builder.insertDeck(deck)
        var bundles: [GeneratedCardBundle] = []
        for word in words {
            let sense = LexicalSense(sourceLanguage: word.sourceLanguageTag, targetLanguage: word.targetLanguageTag, lemma: word.german, senseKey: word.id.uuidString, partOfSpeech: word.partOfSpeech, meaning: word.persian, translation: word.persian, level: word.level, direction: .recognition)
            let identity = CardIdentity(sourceLanguage: word.sourceLanguageTag, targetLanguage: word.targetLanguageTag, lemma: word.german, senseKey: sense.senseKey, partOfSpeech: word.partOfSpeech, direction: .recognition)
            var mediaAssets: [MediaAsset] = []
            if let audio = store.pronunciationAudio(for: word) {
                let url = mediaDirectory.appendingPathComponent("\(mediaAssets.count).media")
                try audio.write(to: url, options: .atomic)
                mediaAssets.append(MediaAsset(kind: .audio, locale: word.targetLanguageTag, checksum: "", fileSize: audio.count, provider: "local", model: "prototype", cacheReference: url.path))
            }
            if let image = store.illustrationImage(for: word) {
                let url = mediaDirectory.appendingPathComponent("\(mediaAssets.count).media")
                try image.write(to: url, options: .atomic)
                mediaAssets.append(MediaAsset(kind: .image, locale: word.targetLanguageTag, checksum: "", fileSize: image.count, provider: "local", model: "prototype", cacheReference: url.path))
            }
            let bundle = GeneratedCardBundle(identity: identity, senses: [sense], directions: [.recognition], mediaAssets: mediaAssets, approvalState: .approved, provenance: Provenance(provider: "hermes", model: "prototype"))
            bundles.append(bundle)
            let note = AnkiCollectionMapper.mapBundleToNote(bundle, modelID: model.modelID, deckID: deck.deckID)
            try builder.insertNote(note)
            try builder.insertCard(AnkiCollectionMapper.mapBundleToCard(bundle: bundle, noteID: note.noteID, deckID: deck.deckID))
            for tag in AnkiCollectionMapper.mapBundleToTags(bundle: bundle) { try builder.insertTag(tag) }
        }
        try builder.finalizeCollection()
        builder.close()
        let manifest = ExportManifest(sourceGroups: ["hermes"], cardIdentities: bundles.map { $0.identity.compositeKey })
        let destination = directory.appendingPathComponent("prototype.apkg")
        _ = try await AnkiPackageWriter().createAPKG(collectionURL: databaseURL, mediaDirectory: mediaDirectory, manifest: manifest, destination: destination)
        let data = try Data(contentsOf: destination)
        return AnkiAPKGDocument(sourceGroups: ["hermes"], cardCount: words.count, data: data)
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
                            Button(action: {}) { Image(systemName: "speaker.wave.2.fill") }
                        }
                        LanguageText(text: word.german, languageTag: word.targetLanguageTag, font: .largeTitle.weight(.bold))
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title3)
                    }
                }

                PrototypeCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("مثال").font(.headline)
                        LanguageText(text: word.example, languageTag: word.targetLanguageTag, font: .title3)
                        LanguageText(text: word.exampleTranslation, languageTag: word.sourceLanguageTag, color: .secondary)
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
