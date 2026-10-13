import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import SQLite3
import zlib

struct AddWordPrototypeView: View {
    private enum AddSection: String, CaseIterable, Identifiable {
        case singleCard, ankiFile, contextText, importPackage

        var id: Self { self }
        var symbol: String {
            switch self {
            case .singleCard: "wand.and.stars"
            case .ankiFile: "doc.text"
            case .contextText: "text.quote"
            case .importPackage: "square.and.arrow.down"
            }
        }
    }

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeAISettings.self) private var aiSettings
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var word = "arbeiten"
    @State private var domain = "general"
    @State private var showPreview = true
    @State private var isImporterPresented = false
    @State private var isInspectingPackage = false
    @State private var packagePreview: APKGImportPreview?
    @State private var packageError: String?
    @State private var isImportingPackage = false
    @State private var importResult: PrototypeImportResult?
    @State private var generatedCard: ConfiguredProviderCard?
    @State private var isGeneratingCard = false
    @State private var generatedCardSaved = false
    @State private var generatedAudio: Data?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isGeneratingAudio = false
    @State private var customDomainName = ""
    @State private var showingDomainEditor = false
    @State private var domainEditorAppliesToBatch = false
    @State private var batchWords = ""
    @State private var contextText = ""
    @State private var contextTranslation: String?
    @State private var contextCandidateText = ""
    @State private var isTranslatingContext = false
    @FocusState private var contextFieldFocused: Bool
    @State private var batchTopic = "general"
    @State private var availableDomains = PrototypeDomainCatalog.customDomains
    @State private var batchLevel = "B1"
    @State private var batchOutputName = "linguabrain-cards"
    // Batch input is normally the language being learned (for example German),
    // while the picker is the language the user wants as the translation.
    // Keeping those roles separate prevents a German input + Persian translation
    // from being rendered as a Persian-front card.
    @State private var batchInputLanguage = "de"
    @State private var batchTranslationLanguage = "fa"
    @State private var didInitializeBatchLanguages = false
    @State private var batchIncludeAudio = false
    @State private var batchIncludeImage = false
    @State private var isBatchTextImporterPresented = false
    @State private var isBuildingBatch = false
    @State private var batchStatus: String?
    @State private var batchExportDocument = AnkiAPKGDocument()
    @State private var isBatchExporterPresented = false
    @State private var addSection: AddSection = .singleCard

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(aiSettings.textMode == .local || (aiSettings.hasAPIKey && aiSettings.cloudConsent)
                         ? localization.localized("provider.cardReady")
                         : localization.localized("provider.configureText"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Picker(addSectionPickerTitle, selection: $addSection) {
                    ForEach(AddSection.allCases) { section in
                        Label(addSectionTitle(section), systemImage: section.symbol).tag(section)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)

                switch addSection {
                case .singleCard:
                    singleCardBuilder
                case .ankiFile:
                    batchBuilder
                case .contextText:
                    contextBuilder
                case .importPackage:
                    packageImporter
                }

                if addSection == .singleCard, showPreview {
                    cardPreview
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(localization.language == .persian ? "بستن" : "Done") { contextFieldFocused = false }
            }
        }
        .alert(localization.localized("domain.newTitle"), isPresented: $showingDomainEditor) {
            TextField(localization.localized("domain.placeholder"), text: $customDomainName)
            Button(localization.localized("common.save")) {
                if let saved = PrototypeDomainCatalog.add(customDomainName) {
                    availableDomains = PrototypeDomainCatalog.customDomains
                    if domainEditorAppliesToBatch { batchTopic = saved }
                    else { domain = saved }
                }
                customDomainName = ""
                domainEditorAppliesToBatch = false
            }
            Button(localization.localized("common.cancel"), role: .cancel) {
                customDomainName = ""
                domainEditorAppliesToBatch = false
            }
        } message: { Text(localization.localized("domain.newMessage")) }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized("card.addTitle"))
        .onAppear {
            availableDomains = PrototypeDomainCatalog.customDomains
            guard !didInitializeBatchLanguages else { return }
            batchInputLanguage = languageSettings.targetLanguageTag
            batchTranslationLanguage = languageSettings.sourceLanguageTag
            didInitializeBatchLanguages = true
        }
        .onChange(of: word) { _, _ in resetGeneratedPreview() }
        .onChange(of: domain) { _, _ in resetGeneratedPreview() }
        .onChange(of: addSection) { _, _ in availableDomains = PrototypeDomainCatalog.customDomains }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.ankiDeckPackage],
            allowsMultipleSelection: false
        ) { result in
            inspectSelectedPackage(result)
        }
        .fileImporter(
            isPresented: $isBatchTextImporterPresented,
            allowedContentTypes: [.plainText, .utf8PlainText],
            allowsMultipleSelection: false
        ) { result in
            loadBatchText(result)
        }
        .fileExporter(
            isPresented: $isBatchExporterPresented,
            document: batchExportDocument,
            contentType: AnkiExportDocument.apkg,
            defaultFilename: normalizedOutputName
        ) { result in
            switch result {
            case .success:
                batchStatus = batchStatusCopy(.saved)
            case .failure(let error):
                packageError = error.localizedDescription
            }
        }
        .alert(localization.localized("card.operationFailed"), isPresented: packageErrorBinding) {
            Button(localization.localized("common.ok"), role: .cancel) { packageError = nil }
        } message: {
            Text(packageError ?? localization.localized("common.unknownError"))
        }
    }

    private var singleCardBuilder: some View {
        PrototypeCard {
                    VStack(alignment: .leading, spacing: 16) {
                        TextField(localization.localized("card.wordPlaceholder"), text: $word)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                            .environment(\.layoutDirection, .leftToRight)

                        Picker(localization.localized("card.domain"), selection: $domain) {
                            Text(localization.localized("domain.general")).tag("general")
                            Text(localization.localized("domain.work")).tag("work")
                            Text(localization.localized("domain.software")).tag("software")
                            Text(localization.localized("domain.medical")).tag("medical")
                            ForEach(PrototypeDomainCatalog.customDomains, id: \.self) { value in
                                Text(value).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        Button(addCustomDomainLabel, systemImage: "plus") {
                            domainEditorAppliesToBatch = false
                            showingDomainEditor = true
                        }

                        Button {
                            generateCard()
                        } label: {
                            if isGeneratingCard {
                                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 10)
                            } else {
                                Label(localization.localized("provider.generateCard"), systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isGeneratingCard || word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
    }

    private func generateCard() {
        isGeneratingCard = true
        generatedCard = nil
        generatedCardSaved = false
        Task {
            do {
                guard aiSettings.textMode != .off else { throw ProviderError.providerDisabled }
                guard aiSettings.protocolName == "openai-compatible" else { throw ProviderError.unsupportedProtocol }
                if aiSettings.textMode == .cloud {
                    guard aiSettings.cloudConsent else { throw ProviderError.consentRequired }
                    guard aiSettings.hasAPIKey else { throw ProviderError.missingAPIKey }
                }
                let gateway = AIProviderGateway(
                    endpoint: aiSettings.endpoint,
                    protocolName: aiSettings.protocolName,
                    apiKey: try aiSettings.apiKey()
                )
                #if DEBUG
                ProviderCredentialDiagnostics.logRequest(endpoint: aiSettings.endpoint, model: aiSettings.modelID, account: "api-key.text", key: gateway.apiKey)
                #endif
                let draft = try await gateway.generateCard(
                    word: word.trimmingCharacters(in: .whitespacesAndNewlines),
                    domain: domain,
                    model: aiSettings.modelID,
                    sourceLanguageTag: languageSettings.sourceLanguageTag,
                    targetLanguageTag: languageSettings.targetLanguageTag
                )
                generatedCard = draft
                // Generate pronunciation as part of card creation. The explicit
                // preview button remains available for retry/regeneration.
                if aiSettings.audioMode != .off {
                    let audioGateway = AIProviderGateway(
                        endpoint: aiSettings.audioEndpoint,
                        protocolName: aiSettings.audioProtocolName,
                        apiKey: try aiSettings.apiKey(for: "audio")
                    )
                    // Audio is generated during creation, but a temporary audio
                    // provider/quota failure must not discard an otherwise valid
                    // text card; the preview button can retry it.
                    generatedAudio = try? await audioGateway.synthesizeSpeech(
                        text: draft.targetText,
                        model: aiSettings.audioModelID,
                        voice: aiSettings.audioVoice
                    )
                }
                withAnimation { showPreview = true }
            } catch {
                packageError = error.localizedDescription
            }
            isGeneratingCard = false
        }
    }

    private func resetGeneratedPreview() {
        generatedCard = nil
        generatedCardSaved = false
        generatedAudio = nil
        audioPlayer = nil
    }

    private var addSectionPickerTitle: String {
        switch localization.language {
        case .english: "Add method"
        case .german: "Hinzufügen mit"
        case .persian: "روش افزودن"
        }
    }

    private func addSectionTitle(_ section: AddSection) -> String {
        switch (localization.language, section) {
        case (.english, .singleCard): "Create one card"
        case (.english, .ankiFile): "Build Anki from file/list"
        case (.english, .contextText): "Build from passage"
        case (.english, .importPackage): "Import Anki package"
        case (.german, .singleCard): "Einzelne Karte erstellen"
        case (.german, .ankiFile): "Anki aus Datei/Liste erstellen"
        case (.german, .contextText): "Aus Text erstellen"
        case (.german, .importPackage): "Anki-Paket importieren"
        case (.persian, .singleCard): "ساخت یک کارت"
        case (.persian, .ankiFile): "ساخت Anki از فایل یا فهرست"
        case (.persian, .contextText): "ساخت از متن"
        case (.persian, .importPackage): "ورود بستهٔ Anki"
        }
    }

    private func batchStep(_ number: Int, _ title: String) -> some View {
        Text("\(number). \(title)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(PrototypeTheme.accent)
    }

    private var batchInputStepTitle: String {
        switch localization.language {
        case .english: "Words"
        case .german: "Wörter"
        case .persian: "کلمه‌ها"
        }
    }

    private var batchSettingsStepTitle: String {
        switch localization.language {
        case .english: "Card settings"
        case .german: "Karteneinstellungen"
        case .persian: "تنظیمات کارت"
        }
    }

    private var batchExportStepTitle: String {
        switch localization.language {
        case .english: "Media and output"
        case .german: "Medien und Ausgabe"
        case .persian: "رسانه و خروجی"
        }
    }

    private func generateAudio() {
        guard let preview = generatedCard else { return }
        isGeneratingAudio = true
        Task {
            do {
                guard aiSettings.audioMode != .off else { throw ProviderError.providerDisabled }
                let gateway = AIProviderGateway(endpoint: aiSettings.audioEndpoint, protocolName: aiSettings.audioProtocolName, apiKey: try aiSettings.apiKey(for: "audio"))
                generatedAudio = try await gateway.synthesizeSpeech(text: preview.targetText, model: aiSettings.audioModelID, voice: aiSettings.audioVoice)
            } catch { packageError = error.localizedDescription }
            isGeneratingAudio = false
        }
    }

    private var batchBuilder: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(batchCopy(.title), systemImage: "rectangle.stack.badge.plus")
                    .font(.headline)
                Text(batchCopy(.subtitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                batchStep(1, batchInputStepTitle)
                TextEditor(text: $batchWords)
                    .font(.body)
                    .frame(minHeight: 90)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)))
                    .accessibilityLabel("فهرست کلمات")

                HStack {
                    Button(batchCopy(.chooseTextFile), systemImage: "doc.badge.plus") {
                        isBatchTextImporterPresented = true
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Text(batchCopy(.wordCount).replacingOccurrences(of: "%d", with: "\(parsedBatchWords.count)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()
                batchStep(2, batchSettingsStepTitle)
                HStack {
                    Picker(batchCopy(.topicPlaceholder), selection: $batchTopic) {
                        Text(localization.localized("domain.general")).tag("general")
                        Text(localization.localized("domain.work")).tag("work")
                        Text(localization.localized("domain.software")).tag("software")
                        Text(localization.localized("domain.medical")).tag("medical")
                        ForEach(PrototypeDomainCatalog.customDomains, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    Button(addCustomDomainLabel, systemImage: "plus") {
                        domainEditorAppliesToBatch = true
                        showingDomainEditor = true
                    }
                    .buttonStyle(.bordered)
                }
                Picker(contextCopy(.level), selection: $batchLevel) {
                    ForEach(["A1", "A2", "B1", "B2", "C1"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                HStack {
                    Picker(batchCopy(.inputLanguage), selection: $batchInputLanguage) {
                        Text(localization.localized("language.german")).tag("de")
                        Text(localization.localized("language.english")).tag("en")
                        Text(localization.localized("language.persian")).tag("fa")
                    }
                    .pickerStyle(.menu)
                    Picker(batchCopy(.translationLanguage), selection: $batchTranslationLanguage) {
                        Text(localization.localized("language.persian")).tag("fa")
                        Text(localization.localized("language.german")).tag("de")
                        Text(localization.localized("language.english")).tag("en")
                    }
                    .pickerStyle(.menu)
                }
                Text(batchCopy(.cardDirection))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                batchStep(3, batchExportStepTitle)
                HStack {
                    TextField(batchCopy(.outputName), text: $batchOutputName)
                        .textFieldStyle(.roundedBorder)
                        .environment(\.layoutDirection, .leftToRight)
                    Text(".apkg")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Toggle(batchCopy(.includeAudio), isOn: $batchIncludeAudio)
                Toggle(batchCopy(.includeImage), isOn: $batchIncludeImage)

                Button {
                    buildBatchAPKG()
                } label: {
                    if isBuildingBatch {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label(batchCopy(.buildAndSave), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    isBuildingBatch ||
                    parsedBatchWords.isEmpty ||
                    batchTopic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    batchInputLanguage == batchTranslationLanguage
                )

                if let batchStatus {
                    Text(batchStatus)
                        .font(.caption)
                        .foregroundStyle(PrototypeTheme.mint)
                }
            }
        }
    }

    private var contextBuilder: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(contextCopy(.title), systemImage: "text.quote")
                    .font(.headline)
                Text(contextCopy(.subtitle)).font(.subheadline).foregroundStyle(.secondary)
                TextEditor(text: $contextText)
                    .focused($contextFieldFocused)
                    .frame(minHeight: 180)
                    .padding(6)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)))
                Button { translateContext() } label: {
                    Label(contextCopy(.translate), systemImage: "character.book.closed")
                }.disabled(isTranslatingContext || contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if let contextTranslation {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contextCopy(.translation)).font(.headline)
                        Text(contextTranslation).textSelection(.enabled)
                    }.padding(10).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                Picker(contextCopy(.topic), selection: $batchTopic) {
                    Text(localization.localized("domain.general")).tag("general")
                    Text(localization.localized("domain.work")).tag("work")
                    Text(localization.localized("domain.software")).tag("software")
                    Text(localization.localized("domain.medical")).tag("medical")
                    ForEach(availableDomains, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                Picker(contextCopy(.level), selection: $batchLevel) {
                    ForEach(["A1", "A2", "B1", "B2", "C1"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                HStack {
                    Picker(contextCopy(.inputLanguage), selection: $batchInputLanguage) {
                        Text(localization.localized("language.german")).tag("de")
                        Text(localization.localized("language.english")).tag("en")
                        Text(localization.localized("language.persian")).tag("fa")
                    }.pickerStyle(.menu)
                    Picker(contextCopy(.translationLanguage), selection: $batchTranslationLanguage) {
                        Text(localization.localized("language.persian")).tag("fa")
                        Text(localization.localized("language.german")).tag("de")
                        Text(localization.localized("language.english")).tag("en")
                    }.pickerStyle(.menu)
                }
                Toggle(batchCopy(.includeAudio), isOn: $batchIncludeAudio)
                Toggle(batchCopy(.includeImage), isOn: $batchIncludeImage)
                Button { buildFromContext() } label: {
                    Label(contextCopy(.select), systemImage: "wand.and.stars").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
                    .disabled(isBuildingBatch || contextText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || batchInputLanguage == batchTranslationLanguage)
                if !contextCandidateText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(contextCopy(.candidates)).font(.headline)
                        Text(contextCopy(.candidatesHint)).font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $contextCandidateText)
                            .frame(minHeight: 84)
                            .padding(6)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.35)))
                        Button { buildSelectedContextCards() } label: {
                            Label(contextCopy(.build), systemImage: "rectangle.stack.badge.plus").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent)
                            .disabled(isBuildingBatch || contextCandidateWords.isEmpty)
                    }
                }
                if let batchStatus { Text(batchStatus).font(.caption).foregroundStyle(PrototypeTheme.mint) }
            }
        }
    }

    private enum ContextCopy { case title, subtitle, topic, level, inputLanguage, translationLanguage, select, candidates, candidatesHint, build, translate, translation }
    private func contextCopy(_ key: ContextCopy) -> String {
        switch (localization.language, key) {
        case (.english, .title): "Build cards from a passage"; case (.english, .subtitle): "Paste a text. AI selects important content words in context."; case (.english, .topic): "Topic"; case (.english, .level): "Word level"; case (.english, .inputLanguage): "Text language"; case (.english, .translationLanguage): "Translation language"; case (.english, .select): "Select important words"; case (.english, .candidates): "Suggested words"; case (.english, .candidatesHint): "Edit, remove, or add words before creating cards."; case (.english, .build): "Create cards from selected words"; case (.english, .translate): "Translate passage"; case (.english, .translation): "Translation"
        case (.german, .title): "Karten aus einem Text erstellen"; case (.german, .subtitle): "Text einfügen. Die KI wählt wichtige Inhaltswörter im Kontext aus."; case (.german, .topic): "Thema"; case (.german, .level): "Wortniveau"; case (.german, .inputLanguage): "Textsprache"; case (.german, .translationLanguage): "Übersetzungssprache"; case (.german, .select): "Wichtige Wörter auswählen"; case (.german, .candidates): "Vorgeschlagene Wörter"; case (.german, .candidatesHint): "Wörter vor dem Erstellen bearbeiten, entfernen oder ergänzen."; case (.german, .build): "Karten aus ausgewählten Wörtern erstellen"; case (.german, .translate): "Text übersetzen"; case (.german, .translation): "Übersetzung"
        case (.persian, .title): "ساخت کارت از متن"; case (.persian, .subtitle): "یک متن وارد کنید؛ هوش مصنوعی واژه‌های محتوایی و مهم را با توجه به زمینه انتخاب می‌کند."; case (.persian, .topic): "موضوع"; case (.persian, .level): "حداقل سطح واژه"; case (.persian, .inputLanguage): "زبان متن"; case (.persian, .translationLanguage): "زبان ترجمه"; case (.persian, .select): "انتخاب واژه‌های مهم"; case (.persian, .candidates): "واژه‌های پیشنهادی"; case (.persian, .candidatesHint): "پیش از ساخت کارت، واژه‌ها را حذف، ویرایش یا اضافه کنید."; case (.persian, .build): "ساخت کارت از واژه‌های انتخاب‌شده"; case (.persian, .translate): "ترجمهٔ متن"; case (.persian, .translation): "ترجمه"
        }
    }

    private func translateContext() {
        isTranslatingContext = true
        Task {
            do {
                let gateway = AIProviderGateway(endpoint: aiSettings.endpoint, protocolName: aiSettings.protocolName, apiKey: try aiSettings.apiKey())
                contextTranslation = try await gateway.translateText(contextText, model: aiSettings.modelID, sourceLanguageTag: batchInputLanguage, targetLanguageTag: batchTranslationLanguage)
            } catch { packageError = error.localizedDescription }
            isTranslatingContext = false
        }
    }

    private func buildFromContext() {
        isBuildingBatch = true
        batchStatus = localization.language == .persian ? "در حال انتخاب واژه‌های مهم متن…" : "Selecting important words from the text…"
        Task {
            do {
                guard aiSettings.textMode != .off else { throw ProviderError.providerDisabled }
                if aiSettings.textMode == .cloud {
                    guard aiSettings.cloudConsent else { throw ProviderError.consentRequired }
                    guard aiSettings.hasAPIKey else { throw ProviderError.missingAPIKey }
                }
                let gateway = AIProviderGateway(endpoint: aiSettings.endpoint, protocolName: aiSettings.protocolName, apiKey: try aiSettings.apiKey())
                let words = try await gateway.extractImportantWords(from: contextText, topic: batchTopic, languageTag: batchInputLanguage, minimumLevel: batchLevel, model: aiSettings.modelID)
                contextCandidateText = words.joined(separator: ", ")
                isBuildingBatch = false
            } catch {
                packageError = error.localizedDescription
                isBuildingBatch = false
            }
        }
    }

    private var contextCandidateWords: [String] {
        var seen = Set<String>()
        return contextCandidateText.components(separatedBy: CharacterSet(charactersIn: ",،\n\r;"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted }
            .prefix(12).map { $0 }
    }

    private func buildSelectedContextCards() {
        let words = contextCandidateWords
        batchWords = words.joined(separator: ",")
        buildBatchAPKG(wordsOverride: words, exportsPackage: false)
    }

    private var parsedBatchWords: [String] {
        let separators = CharacterSet(charactersIn: ",،\n\r;")
        var seen = Set<String>()
        return batchWords
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted }
            .prefix(50)
            .map { $0 }
    }

    private var normalizedOutputName: String {
        let trimmed = batchOutputName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "linguabrain-cards" : trimmed
        return base.lowercased().hasSuffix(".apkg") ? base : "\(base).apkg"
    }

    private enum BatchStatusCopy {
        case saved, fileLoaded(Int), building(Int, Int, String), readyToSave(Int), partialSuccess(Int, Int, String)
    }

    private func batchStatusCopy(_ status: BatchStatusCopy) -> String {
        switch (localization.language, status) {
        case (.english, .saved): "Anki file is ready and saved."
        case (.german, .saved): "Die Anki-Datei ist fertig und gespeichert."
        case (.persian, .saved): "فایل Anki آماده و ذخیره شد."
        case (.english, .fileLoaded(let count)): "Text file loaded; \(count) words are ready."
        case (.german, .fileLoaded(let count)): "Textdatei geladen; \(count) Wörter sind bereit."
        case (.persian, .fileLoaded(let count)): "فایل خوانده شد؛ \(count) کلمه آماده است."
        case (.english, .building(let current, let total, let word)): "Building card \(current) of \(total): \(word)"
        case (.german, .building(let current, let total, let word)): "Karte \(current) von \(total) wird erstellt: \(word)"
        case (.persian, .building(let current, let total, let word)): "در حال ساخت کارت \(current) از \(total): \(word)"
        case (.english, .readyToSave(let count)): "\(count) cards are ready; choose where to save the file."
        case (.german, .readyToSave(let count)): "\(count) Karten sind bereit; Speicherort auswählen."
        case (.persian, .readyToSave(let count)): "\(count) کارت آماده است؛ محل ذخیرهٔ فایل را انتخاب کنید."
        case (.english, .partialSuccess(let cards, let failures, let details)): "\(cards) cards ready; \(failures) inputs failed: \(details)"
        case (.german, .partialSuccess(let cards, let failures, let details)): "\(cards) Karten bereit; \(failures) Eingaben fehlgeschlagen: \(details)"
        case (.persian, .partialSuccess(let cards, let failures, let details)): "\(cards) کارت آماده شد؛ \(failures) ورودی ناموفق بود: \(details)"
        }
    }

    private func loadBatchText(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            batchWords = try String(contentsOf: url, encoding: .utf8)
            batchStatus = batchStatusCopy(.fileLoaded(parsedBatchWords.count))
        } catch {
            packageError = error.localizedDescription
        }
    }

    private func buildBatchAPKG(wordsOverride: [String]? = nil, exportsPackage: Bool = true) {
        let words = wordsOverride ?? parsedBatchWords
        guard !words.isEmpty else { return }
        _ = PrototypeDomainCatalog.add(batchTopic)
        isBuildingBatch = true
        batchStatus = nil
        Task {
            do {
                guard aiSettings.textMode != .off else { throw ProviderError.providerDisabled }
                if aiSettings.textMode == .cloud {
                    guard aiSettings.cloudConsent else { throw ProviderError.consentRequired }
                    guard aiSettings.hasAPIKey else { throw ProviderError.missingAPIKey }
                }
                let textGateway = AIProviderGateway(
                    endpoint: aiSettings.endpoint,
                    protocolName: aiSettings.protocolName,
                    apiKey: try aiSettings.apiKey()
                )
                let audioGateway = batchIncludeAudio && aiSettings.audioMode != .off
                    ? try? AIProviderGateway(endpoint: aiSettings.audioEndpoint, protocolName: aiSettings.audioProtocolName, apiKey: aiSettings.apiKey(for: "audio"))
                    : nil
                let imageGateway = batchIncludeImage && aiSettings.imageMode != .off
                    ? try? AIProviderGateway(endpoint: aiSettings.imageEndpoint, protocolName: "openai-compatible", apiKey: aiSettings.apiKey(for: "image"))
                    : nil

                var savedWords: [PrototypeWord] = []
                var failures: [String] = []
                for (index, input) in words.enumerated() {
                    batchStatus = batchStatusCopy(.building(index + 1, words.count, input))
                    do {
                        let generationInput: String
                        if addSection == .contextText {
                            let normalized = try await textGateway.normalizeVocabularyItem(input, passage: contextText, languageTag: batchInputLanguage, model: aiSettings.modelID)
                            guard normalized.confidence >= 0.8 else { throw BatchGenerationError.normalizationUncertain }
                            guard meetsMinimumLevel(normalized.actualLevel, minimum: batchLevel) else {
                                throw BatchGenerationError.belowMinimum(actual: normalized.actualLevel, minimum: batchLevel)
                            }
                            generationInput = normalized.lemma
                        } else {
                            generationInput = input
                        }
                        var draft = try await generateBatchDraft(using: textGateway, word: generationInput)
                        if !draft.hasValidSourceLanguage(batchTranslationLanguage) {
                            draft = try await textGateway.generateCard(
                                word: generationInput,
                                domain: batchTopic,
                                model: aiSettings.modelID,
                                sourceLanguageTag: batchTranslationLanguage,
                                targetLanguageTag: batchInputLanguage,
                                context: "The previous response used the wrong language in meaning or usage fields. Rewrite every meaning, usage, and source example strictly in \(batchTranslationLanguage). Original passage: \(contextText)",
                                level: batchLevel
                            )
                        }
                        guard draft.hasValidSourceLanguage(batchTranslationLanguage) else { throw BatchGenerationError.wrongSourceLanguage }
                        guard addSection != .contextText || meetsMinimumLevel(draft.level, minimum: batchLevel) else {
                            throw BatchGenerationError.belowMinimum(actual: draft.level, minimum: batchLevel)
                        }
                        let cards = [draft.consolidatedPrototypeWord(
                            domain: batchTopic,
                            sourceLanguageTag: batchTranslationLanguage,
                            targetLanguageTag: batchInputLanguage
                        )]
                        let audio: Data?
                        if let audioGateway {
                            audio = try? await audioGateway.synthesizeSpeech(
                                text: draft.targetText,
                                model: aiSettings.audioModelID,
                                voice: aiSettings.audioVoice
                            )
                        } else {
                            audio = nil
                        }
                        let image: Data?
                        if let imageGateway {
                            image = try? await imageGateway.generateImage(
                                prompt: "A clear, literal educational illustration of \(draft.targetText), no text",
                                model: aiSettings.imageModelID
                            )
                        } else {
                            image = nil
                        }
                        // Each genuinely independent sense is its own review card.
                        // The generated media is shared by those cards, not duplicated.
                        if store.addGeneratedCards(
                            cards,
                            sharedPronunciationAudio: audio,
                            sharedIllustrationImage: image
                        ) {
                            savedWords.append(contentsOf: cards)
                        } else {
                            failures.append("\(input): \(store.lastPersistenceError ?? "کارت ذخیره نشد.")")
                        }
                    } catch {
                        failures.append("\(input): \(batchFailureMessage(error))")
                    }
                }
                guard !savedWords.isEmpty else {
                    throw NSError(
                        domain: "LinguaBrain",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: noCardsMessage(failures)]
                    )
                }
                if exportsPackage {
                    batchExportDocument = try await PrototypeAPKGExporter.makeDocument(from: savedWords, store: store)
                    batchStatus = failures.isEmpty
                        ? batchStatusCopy(.readyToSave(savedWords.count))
                        : batchStatusCopy(.partialSuccess(savedWords.count, failures.count, failures.joined(separator: " · ")))
                    isBatchExporterPresented = true
                } else {
                    batchStatus = contextCardsAddedCopy(savedWords.count, failures: failures.count)
                    // A completed contextual import starts a fresh passage while
                    // retaining the status message as confirmation for the user.
                    contextText = ""
                    contextTranslation = nil
                    contextCandidateText = ""
                }
            } catch {
                packageError = error.localizedDescription
            }
            isBuildingBatch = false
        }
    }

    private func generateBatchDraft(using gateway: AIProviderGateway, word: String) async throws -> ConfiguredProviderCard {
        let suppliedContext = addSection == .contextText ? contextText : nil
        do {
            return try await gateway.generateCard(word: word, domain: batchTopic, model: aiSettings.modelID, sourceLanguageTag: batchTranslationLanguage, targetLanguageTag: batchInputLanguage, context: suppliedContext, level: batchLevel)
        } catch ProviderError.invalidResponse {
            let retryContext = "Return a complete response matching the required JSON schema exactly. The dictionary headword is '\(word)'. " + (suppliedContext ?? "")
            return try await gateway.generateCard(word: word, domain: batchTopic, model: aiSettings.modelID, sourceLanguageTag: batchTranslationLanguage, targetLanguageTag: batchInputLanguage, context: retryContext, level: batchLevel)
        }
    }

    private func meetsMinimumLevel(_ actual: String, minimum: String) -> Bool {
        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        guard let actualIndex = levels.firstIndex(of: actual.uppercased()),
              let minimumIndex = levels.firstIndex(of: minimum.uppercased()) else { return false }
        return actualIndex >= minimumIndex
    }

    private enum BatchGenerationError: Error {
        case belowMinimum(actual: String, minimum: String)
        case wrongSourceLanguage
        case normalizationUncertain
    }

    private func batchFailureMessage(_ error: Error) -> String {
        if let batchError = error as? BatchGenerationError {
            switch batchError {
            case .belowMinimum(let actual, let minimum):
                return localization.localized("context.error.belowMinimum")
                    .replacingOccurrences(of: "%1$@", with: actual)
                    .replacingOccurrences(of: "%2$@", with: minimum)
            case .wrongSourceLanguage:
                return localization.localized("context.error.wrongLanguage")
            case .normalizationUncertain:
                return localization.localized("context.error.normalizationUncertain")
            }
        }
        if let providerError = error as? ProviderError {
            let key: String
            switch providerError {
            case .invalidResponse: key = "provider.error.invalidResponse"
            case .missingAPIKey: key = "provider.error.missingKey"
            case .consentRequired: key = "provider.error.consent"
            case .providerDisabled: key = "provider.error.disabled"
            case .unsupportedProtocol: key = "provider.error.protocol"
            case .service, .keychain: return providerError.localizedDescription
            }
            return localization.localized(key)
        }
        return error.localizedDescription
    }

    private func contextCardsAddedCopy(_ count: Int, failures: Int) -> String {
        let key = failures == 0 ? "context.cardsAdded" : "context.cardsAddedPartial"
        return localization.localized(key)
            .replacingOccurrences(of: "%1$d", with: "\(count)")
            .replacingOccurrences(of: "%2$d", with: "\(failures)")
    }

    private var addCustomDomainLabel: String {
        switch localization.language {
        case .english: "Add custom category"
        case .german: "Eigene Kategorie hinzufügen"
        case .persian: "افزودن دستهٔ جدید"
        }
    }

    private func noCardsMessage(_ failures: [String]) -> String {
        let details = failures.joined(separator: "\n")
        switch localization.language {
        case .english: return "No cards were created.\(details.isEmpty ? "" : "\n\(details)")"
        case .german: return "Es wurden keine Karten erstellt.\(details.isEmpty ? "" : "\n\(details)")"
        case .persian: return "هیچ کارتی ساخته نشد.\(details.isEmpty ? "" : "\n\(details)")"
        }
    }

    private enum BatchCopy {
        case title, subtitle, topicPlaceholder, chooseTextFile, wordCount, inputLanguage, translationLanguage, cardDirection, outputName, includeAudio, includeImage, buildAndSave, awaitingAI, independentSenses
    }

    private func batchCopy(_ key: BatchCopy) -> String {
        switch (localization.language, key) {
        case (.english, .title): "Build Anki deck"
        case (.english, .subtitle): "Enter comma- or line-separated words, or choose a text file. Independent meanings become separate cards."
        case (.english, .topicPlaceholder): "Topic, e.g. travel or software"
        case (.english, .chooseTextFile): "Choose .txt file"
        case (.english, .wordCount): "%d words"
        case (.english, .inputLanguage): "Input language"
        case (.english, .translationLanguage): "Translation language"
        case (.english, .cardDirection): "Card front: input word · Card back: translation"
        case (.english, .outputName): "Output filename"
        case (.english, .includeAudio): "Generate pronunciation audio"
        case (.english, .includeImage): "Generate learning image"
        case (.english, .buildAndSave): "Build and save .apkg"
        case (.english, .awaitingAI): "Waiting for AI"
        case (.english, .independentSenses): "Independent meanings and usage"
        case (.german, .title): "Anki-Stapel erstellen"
        case (.german, .subtitle): "Wörter durch Kommas oder Zeilen trennen oder eine Textdatei wählen. Eigenständige Bedeutungen werden getrennte Karten."
        case (.german, .topicPlaceholder): "Thema, z. B. Reisen oder Software"
        case (.german, .chooseTextFile): ".txt-Datei auswählen"
        case (.german, .wordCount): "%d Wörter"
        case (.german, .inputLanguage): "Eingabesprache"
        case (.german, .translationLanguage): "Übersetzungssprache"
        case (.german, .cardDirection): "Vorderseite: Eingabewort · Rückseite: Übersetzung"
        case (.german, .outputName): "Ausgabedatei"
        case (.german, .includeAudio): "Aussprache erzeugen"
        case (.german, .includeImage): "Lernbild erzeugen"
        case (.german, .buildAndSave): ".apkg erstellen und speichern"
        case (.german, .awaitingAI): "Warten auf KI"
        case (.german, .independentSenses): "Eigenständige Bedeutungen und Verwendung"
        case (.persian, .title): "ساخت دسته‌ای فایل Anki"
        case (.persian, .subtitle): "کلمه‌ها را با کاما، خط جدید، یا یک فایل متنی وارد کنید. هر معنی مستقل یک کارت جدا می‌شود."
        case (.persian, .topicPlaceholder): "موضوع، مثلاً سفر یا برنامه‌نویسی"
        case (.persian, .chooseTextFile): "انتخاب فایل .txt"
        case (.persian, .wordCount): "%d کلمه"
        case (.persian, .inputLanguage): "زبان واژه‌های ورودی"
        case (.persian, .translationLanguage): "زبان ترجمه"
        case (.persian, .cardDirection): "روی کارت: واژهٔ ورودی · پشت کارت: ترجمه"
        case (.persian, .outputName): "نام فایل خروجی"
        case (.persian, .includeAudio): "تولید صدای تلفظ"
        case (.persian, .includeImage): "تولید تصویر آموزشی"
        case (.persian, .buildAndSave): "ساخت و ذخیرهٔ فایل .apkg"
        case (.persian, .awaitingAI): "در انتظار AI"
        case (.persian, .independentSenses): "معنی‌ها و کاربردهای مستقل"
        }
    }

    private var packageImporter: some View {
        return PrototypeCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("ورود فایل Anki", systemImage: "square.and.arrow.down")
                        .font(.headline)
                    Spacer()
                    Text("پیش‌بررسی امن")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PrototypeTheme.accent)
                }

                if isInspectingPackage {
                    ProgressView("در حال بررسی ساختار بسته…")
                } else if let packagePreview {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(packagePreview.fileName, systemImage: "checkmark.shield.fill")
                            .foregroundStyle(PrototypeTheme.mint)
                        Text("\(packagePreview.entryCount) فایل · \(packagePreview.mediaEntryCount) رسانه · دیتابیس: \(packagePreview.collectionName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("حجم بازشدهٔ اعلام‌شده: \(packagePreview.expandedBytes.formatted(.byteCount(style: .file)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let importResult {
                            Label("\(importResult.addedCount) جدید · \(importResult.updatedCount) اصلاح‌شده · \(importResult.skippedCount) تکراری", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PrototypeTheme.mint)
                            importCompletionActions
                        } else {
                            Text("فایل آماده است؛ برای ثبت کارت‌ها دکمهٔ ورود را بزن.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    Text("فایل قبل از استخراج از نظر مسیرهای خطرناک، رمزگذاری، تعداد فایل، حجم بازشده و نسبت فشرده‌سازی بررسی می‌شود.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    isImporterPresented = true
                } label: {
                    Label("انتخاب فایل .apkg", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isInspectingPackage || isImportingPackage)

                if let packagePreview, importResult == nil {
                    Button {
                        importPackage(packagePreview)
                    } label: {
                        if isImportingPackage {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("تأیید و ورود به LinguaBrain", systemImage: "square.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isImportingPackage)
                }
            }
        }
    }

    private var importReturnCopy: String {
        switch localization.language {
        case .english: "Back to add options"
        case .german: "Zurück zu den Hinzufügeoptionen"
        case .persian: "بازگشت به گزینه‌های افزودن"
        }
    }

    @ViewBuilder
    private var importCompletionActions: some View {
        Button(importReturnCopy) {
            packagePreview = nil
            importResult = nil
            addSection = .singleCard
        }
        .buttonStyle(.bordered)
    }

    private func inspectSelectedPackage(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            if let previousURL = packagePreview?.stagedPackageURL {
                try? FileManager.default.removeItem(at: previousURL)
            }
            isInspectingPackage = true
            packagePreview = nil
            importResult = nil
            Task {
                do {
                    let preview = try await Task.detached(priority: .userInitiated) {
                        let hasAccess = url.startAccessingSecurityScopedResource()
                        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                        return try APKGArchiveInspector().inspect(url: url)
                    }.value
                    packagePreview = preview
                } catch {
                    packageError = error.localizedDescription
                }
                isInspectingPackage = false
            }
        } catch {
            packageError = error.localizedDescription
        }
    }

    private func importPackage(_ preview: APKGImportPreview) {
        isImportingPackage = true
        Task {
            do {
                let candidates = try await Task.detached(priority: .userInitiated) {
                    try APKGCardReader().readCards(from: preview)
                }.value
                guard !candidates.isEmpty else { throw APKGImportError.noCards }
                guard let result = store.importCards(
                    candidates,
                    deckName: preview.deckName,
                    sourcePackage: preview.fileName
                ) else {
                    throw APKGImportError.databaseWriteFailed(store.lastPersistenceError ?? "خطای ناشناخته")
                }
                // Keep the learner's target language (German) and align the
                // support language with the imported deck (English). Without
                // this, Library's language-pair filter can hide a successful
                // import even though the cards are persisted.
                if let first = candidates.first {
                    languageSettings.selectSource(first.sourceLanguageTag)
                    languageSettings.selectTarget(first.targetLanguageTag)
                }
                importResult = result
                try? FileManager.default.removeItem(at: preview.stagedPackageURL)
            } catch {
                packageError = error.localizedDescription
            }
            isImportingPackage = false
        }
    }

    private var packageErrorBinding: Binding<Bool> {
        Binding(
            get: { packageError != nil },
            set: { if !$0 { packageError = nil } }
        )
    }

    private var cardPreview: some View {
        let rawPreview = generatedCard?.prototypeWord(domain: domain, sourceLanguageTag: languageSettings.sourceLanguageTag, targetLanguageTag: languageSettings.targetLanguageTag) ?? PrototypeWord(
            german: word.isEmpty ? "arbeiten" : word,
            persian: "—",
            level: "—",
            partOfSpeech: batchCopy(.awaitingAI),
            example: "",
            exampleTranslation: "",
            domain: domain
        )
        let preview = rawPreview.withLanguagePair(
            source: languageSettings.sourceLanguageTag,
            target: languageSettings.targetLanguageTag
        )
        return PrototypeCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
            Label(localization.localized("card.previewReady"), systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PrototypeTheme.mint)
                    Spacer()
                    Text("\(preview.level) · \(preview.partOfSpeech)").font(.caption).foregroundStyle(.secondary)
                }
                LanguageText(text: preview.german, languageTag: preview.targetLanguageTag, font: .largeTitle.bold())
                LanguageText(text: preview.persian, languageTag: preview.sourceLanguageTag, font: .title2)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text(localization.localized("card.example")).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    LanguageText(text: preview.example.isEmpty ? localization.localized("card.examplePending") : preview.example, languageTag: preview.targetLanguageTag, font: .title3)
                    LanguageText(text: preview.exampleTranslation, languageTag: preview.sourceLanguageTag, font: .body, color: .secondary)
                }
                if let generatedCard, !generatedCard.senses.isEmpty {
                    Divider()
                    Text(batchCopy(.independentSenses))
                        .font(.headline)
                    ForEach(Array(generatedCard.senses.enumerated()), id: \.offset) { index, sense in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(index + 1). \(sense.meaning)").font(.body.bold())
                            Text(sense.usage).font(.caption).foregroundStyle(.secondary)
                            LanguageText(text: sense.example.target, languageTag: preview.targetLanguageTag, font: .subheadline)
                            LanguageText(text: sense.example.source, languageTag: preview.sourceLanguageTag, font: .caption, color: .secondary)
                            if !sense.collocations.isEmpty {
                                Text(sense.collocations.joined(separator: " · "))
                                    .font(.caption2)
                                    .foregroundStyle(PrototypeTheme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                HStack {
                    Label(preview.partOfSpeech, systemImage: "square.stack.3d.up.fill")
                    Label(preview.level, systemImage: "graduationcap.fill")
                    Label(domain, systemImage: "tag.fill")
                }
                .font(.caption)
                .foregroundStyle(PrototypeTheme.accent)
                HStack {
                    Button {
                        generateAudio()
                    } label: {
                        Label(isGeneratingAudio ? localization.localized("media.generatingAudio") : localization.localized("media.generateAudio"), systemImage: "waveform")
                    }
                    .disabled(isGeneratingAudio || aiSettings.audioMode == .off)
                    if let generatedAudio {
                        Button(localization.localized("media.playAudio"), systemImage: "play.fill") {
                            audioPlayer = try? AVAudioPlayer(data: generatedAudio)
                            audioPlayer?.play()
                        }
                    }
                }
                Button {
                    guard generatedCard != nil else { return }
                    let cards = generatedCard.map { card in [card.consolidatedPrototypeWord(
                        domain: domain,
                        sourceLanguageTag: languageSettings.sourceLanguageTag,
                        targetLanguageTag: languageSettings.targetLanguageTag
                    )] } ?? [preview]
                    let saved = store.addGeneratedCards(cards, sharedPronunciationAudio: generatedAudio)
                    if saved {
                        generatedCardSaved = true
                    } else {
                        packageError = store.lastPersistenceError
                    }
                } label: {
                    Label(generatedCardSaved ? localization.localized("card.addedToLibrary") : localization.localized("card.approveAndAdd"), systemImage: generatedCardSaved ? "checkmark.circle.fill" : "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(generatedCard == nil || generatedCardSaved)
            }
        }
    }
}

private extension UTType {
    static let ankiDeckPackage = UTType(filenameExtension: "apkg") ?? .archive
}

struct APKGImportPreview: Sendable {
    let fileName: String
    let entryCount: Int
    let mediaEntryCount: Int
    let expandedBytes: Int64
    let collectionName: String
    let stagedPackageURL: URL
    let collectionEntry: APKGCollectionEntry
    let entries: [APKGCollectionEntry]

    var deckName: String {
        URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    }
}

struct APKGCollectionEntry: Sendable {
    let name: String
    let compressionMethod: UInt16
    let compressedSize: Int
    let expandedSize: Int
    let localHeaderOffset: UInt64
}

enum APKGInspectionError: LocalizedError {
    case fileTooLarge
    case malformedArchive
    case unsupportedZip64
    case tooManyEntries
    case unsafePath(String)
    case encryptedEntry(String)
    case unsupportedCompression(String)
    case expandedSizeExceeded
    case suspiciousCompressionRatio(String)
    case duplicateEntry(String)
    case missingCollection

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "حجم فایل از حد مجاز ۵۱۲ مگابایت بیشتر است."
        case .malformedArchive: "ساختار ZIP فایل معتبر نیست."
        case .unsupportedZip64: "بسته‌های ZIP64 فعلاً پشتیبانی نمی‌شوند."
        case .tooManyEntries: "تعداد فایل‌های داخل بسته از حد ایمن بیشتر است."
        case .unsafePath(let path): "مسیر ناامن داخل بسته پیدا شد: \(path)"
        case .encryptedEntry(let path): "فایل رمزگذاری‌شده پشتیبانی نمی‌شود: \(path)"
        case .unsupportedCompression(let path): "روش فشرده‌سازی این فایل پشتیبانی نمی‌شود: \(path)"
        case .expandedSizeExceeded: "حجم بازشدهٔ بسته از حد ایمن بیشتر است."
        case .suspiciousCompressionRatio(let path): "نسبت فشرده‌سازی مشکوک است: \(path)"
        case .duplicateEntry(let path): "نام تکراری داخل بسته پیدا شد: \(path)"
        case .missingCollection: "فایل دیتابیس Anki داخل بسته پیدا نشد."
        }
    }
}

struct APKGArchiveInspector: Sendable {
    private let maximumArchiveBytes: UInt64 = 512 * 1_024 * 1_024
    private let maximumExpandedBytes: UInt64 = 1_024 * 1_024 * 1_024
    private let maximumEntryBytes: UInt64 = 128 * 1_024 * 1_024
    private let maximumEntries = 10_000
    private let maximumCompressionRatio: UInt64 = 200

    func inspect(url: URL) throws -> APKGImportPreview {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let fileSize = try handle.seekToEnd()
        guard fileSize <= maximumArchiveBytes else { throw APKGInspectionError.fileTooLarge }

        let tailSize = min(fileSize, 65_557)
        try handle.seek(toOffset: fileSize - tailSize)
        guard let tail = try handle.read(upToCount: Int(tailSize)),
              let eocd = tail.lastIndex(ofLittleEndianUInt32: 0x06054B50),
              eocd + 22 <= tail.count else {
            throw APKGInspectionError.malformedArchive
        }

        let disk = tail.uint16LE(at: eocd + 4)
        let centralDisk = tail.uint16LE(at: eocd + 6)
        let entriesOnDisk = tail.uint16LE(at: eocd + 8)
        let entryCount = tail.uint16LE(at: eocd + 10)
        let centralSize = tail.uint32LE(at: eocd + 12)
        let centralOffset = tail.uint32LE(at: eocd + 16)
        guard disk == 0, centralDisk == 0, entriesOnDisk == entryCount else {
            throw APKGInspectionError.malformedArchive
        }
        guard entryCount != UInt16.max,
              centralSize != UInt32.max,
              centralOffset != UInt32.max else {
            throw APKGInspectionError.unsupportedZip64
        }
        guard Int(entryCount) <= maximumEntries else { throw APKGInspectionError.tooManyEntries }
        guard UInt64(centralOffset) + UInt64(centralSize) <= fileSize,
              centralSize <= 32 * 1_024 * 1_024 else {
            throw APKGInspectionError.malformedArchive
        }

        try handle.seek(toOffset: UInt64(centralOffset))
        guard let central = try handle.read(upToCount: Int(centralSize)), central.count == Int(centralSize) else {
            throw APKGInspectionError.malformedArchive
        }

        var cursor = 0
        var expandedBytes: UInt64 = 0
        var names = Set<String>()
        var collectionName: String?
        var collectionEntry: APKGCollectionEntry?
        var mediaEntries = 0
        var archiveEntries: [APKGCollectionEntry] = []

        for _ in 0..<Int(entryCount) {
            guard cursor + 46 <= central.count,
                  central.uint32LE(at: cursor) == 0x02014B50 else {
                throw APKGInspectionError.malformedArchive
            }
            let flags = central.uint16LE(at: cursor + 8)
            let method = central.uint16LE(at: cursor + 10)
            let compressed = UInt64(central.uint32LE(at: cursor + 20))
            let expanded = UInt64(central.uint32LE(at: cursor + 24))
            let externalAttributes = central.uint32LE(at: cursor + 38)
            let localHeaderOffset = UInt64(central.uint32LE(at: cursor + 42))
            let nameLength = Int(central.uint16LE(at: cursor + 28))
            let extraLength = Int(central.uint16LE(at: cursor + 30))
            let commentLength = Int(central.uint16LE(at: cursor + 32))
            let end = cursor + 46 + nameLength + extraLength + commentLength
            guard nameLength > 0, end <= central.count,
                  let name = String(data: central.subdata(in: cursor + 46..<cursor + 46 + nameLength), encoding: .utf8) else {
                throw APKGInspectionError.malformedArchive
            }

            try validatePath(name)
            guard names.insert(name).inserted else { throw APKGInspectionError.duplicateEntry(name) }
            guard flags & 0x1 == 0 else { throw APKGInspectionError.encryptedEntry(name) }
            guard method == 0 || method == 8 else { throw APKGInspectionError.unsupportedCompression(name) }
            let unixFileType = (externalAttributes >> 16) & 0xF000
            guard unixFileType != 0xA000 else { throw APKGInspectionError.unsafePath(name) }
            guard expanded <= maximumEntryBytes else { throw APKGInspectionError.expandedSizeExceeded }
            expandedBytes += expanded
            guard expandedBytes <= maximumExpandedBytes else { throw APKGInspectionError.expandedSizeExceeded }
            if compressed == 0, expanded > 0 {
                throw APKGInspectionError.suspiciousCompressionRatio(name)
            }
            if compressed > 0, expanded / compressed > maximumCompressionRatio {
                throw APKGInspectionError.suspiciousCompressionRatio(name)
            }

            let parsedEntry = APKGCollectionEntry(name: name, compressionMethod: method, compressedSize: Int(compressed), expandedSize: Int(expanded), localHeaderOffset: localHeaderOffset)
            archiveEntries.append(parsedEntry)
            if ["collection.anki21b", "collection.anki21", "collection.anki2"].contains(name) {
                let preferred = preferredCollection(current: collectionName, candidate: name)
                if preferred != collectionName {
                    collectionName = preferred
                    collectionEntry = APKGCollectionEntry(
                        name: name,
                        compressionMethod: method,
                        compressedSize: Int(compressed),
                        expandedSize: Int(expanded),
                        localHeaderOffset: localHeaderOffset
                    )
                }
            } else if name == "media" || Self.isPotentialMediaEntry(name) {
                mediaEntries += 1
            }
            cursor = end
        }

        guard cursor == central.count, let collectionName, let collectionEntry else {
            throw APKGInspectionError.missingCollection
        }
        let stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinguaBrain-APKG", isDirectory: true)
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let stagedURL = stagingDirectory.appendingPathComponent("\(UUID().uuidString).apkg")
        try FileManager.default.copyItem(at: url, to: stagedURL)
        return APKGImportPreview(
            fileName: url.lastPathComponent,
            entryCount: Int(entryCount),
            mediaEntryCount: mediaEntries,
            expandedBytes: Int64(expandedBytes),
            collectionName: collectionName,
            stagedPackageURL: stagedURL,
            collectionEntry: collectionEntry
            , entries: archiveEntries
        )
    }

    private func validatePath(_ name: String) throws {
        let normalized = name.replacingOccurrences(of: "\\", with: "/")
        let components = normalized.split(separator: "/", omittingEmptySubsequences: false)
        guard !normalized.hasPrefix("/"),
              !normalized.hasPrefix("~"),
              !normalized.contains(":"),
              !components.contains(".."),
              !components.contains(".") else {
            throw APKGInspectionError.unsafePath(name)
        }
    }

    private func preferredCollection(current: String?, candidate: String) -> String {
        let priority = ["collection.anki2": 0, "collection.anki21": 1, "collection.anki21b": 2]
        guard let current else { return candidate }
        return (priority[candidate] ?? 0) > (priority[current] ?? 0) ? candidate : current
    }

    private static func isPotentialMediaEntry(_ name: String) -> Bool {
        let stem = (name as NSString).deletingPathExtension
        return name.allSatisfy(\.isNumber) || (!stem.isEmpty && stem.allSatisfy(\.isNumber))
    }
}

enum APKGImportError: LocalizedError {
    case unsupportedModernCollection
    case malformedCollection
    case noCards
    case databaseOpenFailed
    case databaseQueryFailed(String)
    case databaseWriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedModernCollection:
            "این بسته از فرمت جدید collection.anki21b استفاده می‌کند که هنوز پشتیبانی نمی‌شود. خروجی سازگار collection.anki21 یا collection.anki2 را وارد کن."
        case .malformedCollection: "دیتابیس داخل بسته معتبر نیست."
        case .noCards: "هیچ کارت قابل ورود در فایل پیدا نشد."
        case .databaseOpenFailed: "دیتابیس Anki به‌صورت امن باز نشد."
        case .databaseQueryFailed(let message): "خواندن کارت‌های Anki انجام نشد: \(message)"
        case .databaseWriteFailed(let message): message
        }
    }
}

struct APKGCardReader: Sendable {
    private let maximumCards = 100_000

    func readCards(from preview: APKGImportPreview) throws -> [PrototypeImportedCard] {
        guard preview.collectionName != "collection.anki21b" else {
            throw APKGImportError.unsupportedModernCollection
        }
        let databaseURL = try extractCollection(from: preview)
        defer { try? FileManager.default.removeItem(at: databaseURL) }
        let media = try extractMedia(from: preview)
        return try readSQLiteCards(at: databaseURL, packageName: preview.fileName, media: media)
    }

    private func extractMedia(from preview: APKGImportPreview) throws -> [String: Data] {
        let handle = try FileHandle(forReadingFrom: preview.stagedPackageURL)
        defer { try? handle.close() }
        var result: [String: Data] = [:]
        var numeric: [String: Data] = [:]
        var manifest: [String: String] = [:]
        let mediaEntryNames = Set(preview.entries.compactMap { entry -> String? in
            guard !["collection.anki21b", "collection.anki21", "collection.anki2", "manifest.json"].contains(entry.name) else { return nil }
            return entry.name
        })
        for entry in preview.entries where mediaEntryNames.contains(entry.name) {
            try handle.seek(toOffset: entry.localHeaderOffset)
            guard let header = try handle.read(upToCount: 30), header.count == 30 else { continue }
            let nameLength = Int(header.uint16LE(at: 26)); let extraLength = Int(header.uint16LE(at: 28))
            try handle.seek(toOffset: entry.localHeaderOffset + UInt64(30 + nameLength + extraLength))
            guard let compressed = try handle.read(upToCount: entry.compressedSize), compressed.count == entry.compressedSize else { continue }
            let data: Data
            if entry.compressionMethod == 0 { data = compressed }
            else if entry.compressionMethod == 8 { data = try inflateRaw(compressed, expandedSize: entry.expandedSize) }
            else { continue }
            if data.count == entry.expandedSize {
                if entry.name == "media", let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                    manifest = object
                } else { numeric[entry.name] = data }
            }
        }
        result = numeric
        for (index, filename) in manifest {
            if let data = numeric[index] ?? numeric[filename] {
                result[filename] = data
            } else if let matchingEntry = numeric.first(where: {
                ($0.key as NSString).deletingPathExtension == index
            }) {
                result[filename] = matchingEntry.value
            }
        }
        return result
    }

    private func extractCollection(from preview: APKGImportPreview) throws -> URL {
        let handle = try FileHandle(forReadingFrom: preview.stagedPackageURL)
        defer { try? handle.close() }
        let entry = preview.collectionEntry
        try handle.seek(toOffset: entry.localHeaderOffset)
        guard let header = try handle.read(upToCount: 30), header.count == 30,
              header.uint32LE(at: 0) == 0x04034B50 else {
            throw APKGImportError.malformedCollection
        }
        let nameLength = Int(header.uint16LE(at: 26))
        let extraLength = Int(header.uint16LE(at: 28))
        try handle.seek(toOffset: entry.localHeaderOffset + UInt64(30 + nameLength + extraLength))
        guard let compressed = try handle.read(upToCount: entry.compressedSize),
              compressed.count == entry.compressedSize else {
            throw APKGImportError.malformedCollection
        }

        let database: Data
        switch entry.compressionMethod {
        case 0: database = compressed
        case 8: database = try inflateRaw(compressed, expandedSize: entry.expandedSize)
        default: throw APKGImportError.malformedCollection
        }
        guard database.count == entry.expandedSize,
              database.starts(with: Data("SQLite format 3\0".utf8)) else {
            throw APKGImportError.malformedCollection
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LinguaBrain-\(UUID().uuidString).sqlite")
        try database.write(to: url, options: .atomic)
        return url
    }

    private func inflateRaw(_ input: Data, expandedSize: Int) throws -> Data {
        var output = Data(count: expandedSize)
        let status: Int32 = input.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                var stream = z_stream()
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(input.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(expandedSize)
                let initialized = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
                guard initialized == Z_OK else { return initialized }
                defer { inflateEnd(&stream) }
                let result = inflate(&stream, Z_FINISH)
                guard result == Z_STREAM_END, stream.total_out == expandedSize else { return Z_DATA_ERROR }
                return Z_OK
            }
        }
        guard status == Z_OK else { throw APKGImportError.malformedCollection }
        return output
    }

    private func readSQLiteCards(at url: URL, packageName: String, media: [String: Data]) throws -> [PrototypeImportedCard] {
        var database: OpaquePointer?
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK,
              let database else {
            throw APKGImportError.databaseOpenFailed
        }
        defer { sqlite3_close(database) }

        let modelFields = try readModelFields(from: database)
        var statement: OpaquePointer?
        let standardSQL = "SELECT c.id, n.mid, n.flds, n.tags FROM cards c JOIN notes n ON n.id = c.nid ORDER BY c.id LIMIT \(maximumCards)"
        let legacySQL = "SELECT c.id, n.mid, n.fields, n.tags FROM cards c JOIN notes n ON n.id = c.nid ORDER BY c.id LIMIT \(maximumCards)"
        if sqlite3_prepare_v2(database, standardSQL, -1, &statement, nil) != SQLITE_OK {
            statement = nil
            guard sqlite3_prepare_v2(database, legacySQL, -1, &statement, nil) == SQLITE_OK else {
                throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
            }
        }
        guard let statement else {
            throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }

        var cards: [PrototypeImportedCard] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let cardID = sqlite3_column_int64(statement, 0)
            let modelID = sqlite3_column_int64(statement, 1)
            guard let fieldsText = sqlite3_column_text(statement, 2) else { continue }
            let rawFields = String(cString: fieldsText)
            let fieldValues: [String]
            if rawFields.hasPrefix("["),
               let data = rawFields.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([String].self, from: data) {
                fieldValues = decoded
            } else {
                fieldValues = rawFields.split(separator: "\u{001F}", omittingEmptySubsequences: false).map(String.init)
            }
            let names = modelFields[String(modelID)] ?? []
            var values = Dictionary(uniqueKeysWithValues: zip(names, fieldValues))
            if let tagsText = sqlite3_column_text(statement, 3) {
                values["Tags"] = String(cString: tagsText)
            }
            guard let word = mapWord(fields: fieldValues, named: values) else { continue }
            let mediaNames = values.values.flatMap { value -> [String] in
                let sound = value.matches(of: /\[sound:([^\]]+)\]/).compactMap { String($0.output.1) }
                let images = value.matches(of: /(?:src|href)=["']([^"']+)["']/).compactMap { String($0.output.1) }
                return (sound + images).map(Self.normalizedMediaName)
            }
            let audio = mediaNames.first(where: { media[$0] != nil && !($0.lowercased().hasSuffix(".png") || $0.lowercased().hasSuffix(".jpg") || $0.lowercased().hasSuffix(".jpeg") || $0.lowercased().hasSuffix(".webp")) }).flatMap { media[$0] }
            let image = mediaNames.first(where: { media[$0] != nil && ["png", "jpg", "jpeg", "webp", "gif"].contains(($0 as NSString).pathExtension.lowercased()) }).flatMap { media[$0] }
            // Some Anki exporters omit extensions in the media manifest or
            // rewrite HTML references. Fall back to file signatures so media
            // is still attached safely instead of silently disappearing.
            let imageCandidates = media.values.filter(Self.isImageData)
            let audioCandidates = media.values.filter(Self.isAudioData)
            let fallbackImage = image ?? (imageCandidates.count == 1 ? imageCandidates[0] : nil)
            let fallbackAudio = audio ?? (audioCandidates.count == 1 ? audioCandidates[0] : nil)
            cards.append(
                PrototypeImportedCard(
                    sourceIdentifier: "\(packageName.lowercased())::\(cardID)",
                    word: word,
                    sourceLanguageTag: sanitize(values["SourceLanguageTag"] ?? word.sourceLanguageTag),
                    targetLanguageTag: sanitize(values["TargetLanguageTag"] ?? word.targetLanguageTag)
                    , pronunciationAudio: fallbackAudio
                    , illustrationImage: fallbackImage
                )
            )
        }
        guard sqlite3_errcode(database) == SQLITE_OK || sqlite3_errcode(database) == SQLITE_DONE else {
            throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
        }
        guard !cards.isEmpty else { throw APKGImportError.noCards }
        return cards
    }

    private func readModelFields(from database: OpaquePointer) throws -> [String: [String]] {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(database, "SELECT models FROM col LIMIT 1", -1, &statement, nil) == SQLITE_OK,
           let statement {
            defer { sqlite3_finalize(statement) }
            if sqlite3_step(statement) == SQLITE_ROW,
               let text = sqlite3_column_text(statement, 0),
               let data = String(cString: text).data(using: .utf8),
               let models = try JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
                return models.mapValues { model in
                    guard let fields = model["flds"] as? [[String: Any]] else { return [] }
                    return fields.sorted { ($0["ord"] as? Int ?? 0) < ($1["ord"] as? Int ?? 0) }
                        .compactMap { $0["name"] as? String }
                }
            }
        }

        // LinguaBrain's legacy collection writer stores model fields in its
        // normalized `models` table instead of the standard `col.models` JSON.
        statement = nil
        guard sqlite3_prepare_v2(database, "SELECT id, fields FROM models", -1, &statement, nil) == SQLITE_OK,
              let fallbackStatement = statement else {
            throw APKGImportError.databaseQueryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(fallbackStatement) }
        var result: [String: [String]] = [:]
        while sqlite3_step(fallbackStatement) == SQLITE_ROW {
            let modelID = sqlite3_column_int64(fallbackStatement, 0)
            guard let text = sqlite3_column_text(fallbackStatement, 1) else { continue }
            result[String(modelID)] = String(cString: text)
                .split(separator: ",", omittingEmptySubsequences: false)
                .map(String.init)
        }
        guard !result.isEmpty else { throw APKGImportError.databaseQueryFailed("تعریف فیلدهای مدل کارت معتبر نیست.") }
        return result
    }

    private static func normalizedMediaName(_ raw: String) -> String {
        let decoded = raw.removingPercentEncoding ?? raw
        return decoded
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func mapWord(fields: [String], named values: [String: String]) -> PrototypeWord? {
        if let source = values["SourceText"], let target = values["TargetText"] {
            let normalizedSource = sanitize(source)
            let normalizedTarget = sanitize(target)
            guard !normalizedSource.isEmpty, !normalizedTarget.isEmpty else { return nil }
            let sourceTag = sanitize(values["SourceLanguageTag"] ?? "fa")
            let targetTag = sanitize(values["TargetLanguageTag"] ?? "de")
            let examples = PrototypeExamplePairing.pair(target: values["TargetExample"] ?? "", source: values["SourceExample"] ?? "")
            return PrototypeWord(
                german: normalizedTarget,
                persian: normalizedSource,
                level: sanitize(values["Level"] ?? "A1"),
                partOfSpeech: sanitize(values["PartOfSpeech"] ?? "Imported"),
                example: sanitize(values["TargetExample"] ?? ""),
                exampleTranslation: sanitize(values["SourceExample"] ?? ""),
                examples: examples,
                domain: sanitize(values["Domain"] ?? "General"),
                sourceLanguageTag: sourceTag,
                targetLanguageTag: targetTag
            )
        }

        if let rawJSON = values["LinguaBrainJSON"],
           let data = rawJSON.data(using: .utf8),
           let payload = try? JSONDecoder().decode(LinguaBrainAnkiPayload.self, from: data) {
            let rawWord = sanitize(payload.word)
            let compactWord = sanitize(rawWord.components(separatedBy: "—").first ?? rawWord)
            let german = compactWord.isEmpty ? sanitize(payload.headword) : compactWord
            guard !german.isEmpty else { return nil }
            let firstExample = payload.examples.first
            let examples = payload.examples.map { PrototypeExample(target: sanitize($0.de), source: sanitize($0.fa)) }
            return PrototypeWord(
                german: german,
                persian: payload.meaningFA.map(sanitize).filter { !$0.isEmpty }.joined(separator: "، "),
                article: germanArticle(in: german),
                level: sanitize(payload.level),
                partOfSpeech: sanitize(payload.partOfSpeechFA),
                example: firstExample.map { sanitize($0.de) } ?? "",
                exampleTranslation: firstExample.map { sanitize($0.fa) } ?? "",
                examples: examples
            )
        }

        // LinguaBrain batch exports carry explicit language and example fields.
        // Read this contract before the legacy Front/Back format below, whose
        // front side was historically Persian and back side German.
        if let front = values["Front"], let back = values["Back"],
           let sourceLanguage = values["SourceLanguageTag"],
           let targetLanguage = values["TargetLanguageTag"] {
            let target = sanitize(front)
            let source = sanitize(back)
            guard !target.isEmpty else { return nil }
            let targetExample = sanitize(values["Example"] ?? "")
            let sourceExample = sanitize(values["ExampleTranslation"] ?? "")
            return PrototypeWord(
                german: target,
                persian: source.isEmpty ? "—" : source,
                article: germanArticle(in: target),
                level: sanitize(values["Level"] ?? "—"),
                partOfSpeech: sanitize(values["PartOfSpeech"] ?? "Imported"),
                example: targetExample,
                exampleTranslation: sourceExample,
                examples: PrototypeExamplePairing.pair(target: targetExample, source: sourceExample),
                domain: sanitize(values["Domain"] ?? PrototypeDomainClassifier.general),
                sourceLanguageTag: sanitize(sourceLanguage),
                targetLanguageTag: sanitize(targetLanguage)
            )
        }

        // Compatibility with APKG files produced by older anki_single builds:
        // Front = Persian meaning + grammar, Back = German headword, Level/Stars.
        if let front = values["Front"], let back = values["Back"] {
            let persian = front.components(separatedBy: "\n\n").first.map(sanitize) ?? ""
            let german = sanitize(back.components(separatedBy: "|").first ?? back)
            guard !german.isEmpty else { return nil }
            return PrototypeWord(
                german: german,
                persian: persian.isEmpty ? "—" : persian.replacingOccurrences(of: "\n", with: "، "),
                article: germanArticle(in: back),
                level: sanitize(values["Level"] ?? "—"),
                partOfSpeech: extractPartOfSpeech(from: back) ?? "Imported",
                example: "",
                exampleTranslation: ""
            )
        }

        // Standard frequency decks often use semantic field names instead of
        // Hermes' contract names. Prefer those names before the positional
        // fallback so German-English decks are not silently imported as fa-de.
        if let german = values["German"], let english = values["English"] {
            let normalizedGerman = sanitize(german)
            let normalizedEnglish = sanitize(english)
            guard !normalizedGerman.isEmpty, !normalizedEnglish.isEmpty else { return nil }
            return PrototypeWord(
                german: normalizedGerman,
                persian: normalizedEnglish,
                article: germanArticle(in: normalizedGerman),
                level: sanitize(values["Level"] ?? "—"),
                partOfSpeech: sanitize(values["Part of speech"] ?? values["PartOfSpeech"] ?? "Imported"),
                example: sanitize(values["Sample sentence"] ?? ""),
                exampleTranslation: sanitize(values["Sample sentence translation"] ?? ""),
                domain: PrototypeDomainClassifier.classify(
                    german: normalizedGerman,
                    source: normalizedEnglish,
                    example: sanitize(values["Sample sentence"] ?? ""),
                    explicitDomain: values["Domain"] ?? values["Topic"] ?? values["Category"] ?? values["Tags"]
                ),
                // The German headword is the learning target in LinguaBrain;
                // English is the support/source language for this frequency deck.
                sourceLanguageTag: "en",
                targetLanguageTag: "de"
            )
        }

        // Compatibility fallback for common LinguaBrain/Anki exports whose
        // model JSON is absent or has non-standard field names.
        if fields.count >= 9 {
            let source = sanitize(fields[2]); let target = sanitize(fields[3])
            if !source.isEmpty && !target.isEmpty {
                return PrototypeWord(
                    german: target, persian: source,
                    level: sanitize(fields[6]), partOfSpeech: sanitize(fields[7]),
                    example: sanitize(fields[4]), exampleTranslation: sanitize(fields[5]),
                    examples: PrototypeExamplePairing.pair(target: fields[4], source: fields[5]),
                    domain: sanitize(fields[8]), sourceLanguageTag: "fa", targetLanguageTag: "de"
                )
            }
        }

        guard let first = fields.first else { return nil }
        let front = sanitize(first)
        let back = fields.count > 1 ? sanitize(fields[1]) : ""
        guard !front.isEmpty else { return nil }
        return PrototypeWord(
            german: front,
            persian: back.isEmpty ? "—" : back,
            level: "—",
            partOfSpeech: "Imported",
            example: "",
            exampleTranslation: ""
        )
    }

    private func germanArticle(in value: String) -> String? {
        let normalized = sanitize(value).lowercased()
        return ["der", "die", "das"].first { normalized.contains("\($0) ") }
    }


    private func extractPartOfSpeech(from value: String) -> String? {
        guard let opening = value.lastIndex(of: "("), let closing = value.lastIndex(of: ")"), opening < closing else {
            return nil
        }
        let result = sanitize(String(value[value.index(after: opening)..<closing]))
        return result.isEmpty ? nil : result
    }

    private func sanitize(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: #"\[sound:[^\]]+\]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
        let entities = ["&nbsp;": " ", "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\""]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func isImageData(_ data: Data) -> Bool {
        data.starts(with: [0x89, 0x50, 0x4E, 0x47]) || data.starts(with: [0xFF, 0xD8, 0xFF]) || data.starts(with: [0x47, 0x49, 0x46, 0x38])
    }

    private static func isAudioData(_ data: Data) -> Bool {
        data.starts(with: Array("RIFF".utf8)) || data.starts(with: Array("ID3".utf8)) || data.starts(with: [0xFF, 0xFB])
    }
}

private struct LinguaBrainAnkiPayload: Decodable {
    struct Example: Decodable {
        let de: String
        let fa: String
        let en: String
    }

    let word: String
    let headword: String
    let partOfSpeechFA: String
    let level: String
    let meaningFA: [String]
    let examples: [Example]

    enum CodingKeys: String, CodingKey {
        case word, headword, level, examples
        case partOfSpeechFA = "part_of_speech_fa"
        case meaningFA = "meaning_fa"
    }
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16
            | UInt32(self[offset + 3]) << 24
    }

    func lastIndex(ofLittleEndianUInt32 value: UInt32) -> Int? {
        guard count >= 4 else { return nil }
        for index in stride(from: count - 4, through: 0, by: -1) {
            if uint32LE(at: index) == value { return index }
        }
        return nil
    }
}
