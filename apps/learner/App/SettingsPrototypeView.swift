import SwiftUI
import CryptoKit
import Observation
import Security

struct SettingsPrototypeView: View {
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings

    var body: some View {
        ZStack {
            PrototypeBackground()

            ScrollView {
                LazyVStack(spacing: 18) {
                    profileCard
                    learningSummary
                    settingsGroup(
                        title: localization.text(.learningAndLanguage),
                        subtitle: localization.text(.learningAndLanguageSubtitle),
                        items: [
                            .init(
                                title: localization.text(.languagesAndLevel),
                                detail: "\(languageName(languageSettings.sourceLanguageTag)) → \(languageName(languageSettings.targetLanguageTag)) · B1",
                                symbol: "character.book.closed.fill", color: .blue, destination: .languages
                            ),
                            .init(title: customDomainsTitle, detail: customDomainsSubtitle, symbol: "square.grid.2x2", color: .purple, destination: .domains),
                            .init(title: localization.text(.goalsAndDailyPlan), detail: localization.localized("کار در آلمان · ۲۰ دقیقه"), symbol: "target", color: PrototypeTheme.pink, destination: .learning),
                            .init(title: localization.text(.reviewAndPractice), detail: localization.localized("مرور تطبیقی · حالت متعادل"), symbol: "rectangle.stack.fill", color: .orange, destination: .review),
                            .init(title: localization.text(.audioAndPronunciation), detail: localization.localized("صدای آلمانی · سرعت عادی"), symbol: "waveform", color: PrototypeTheme.mint, destination: .audio)
                        ]
                    )
                    settingsGroup(
                        title: localization.localized("هوش مصنوعی و آفلاین"),
                        subtitle: localization.localized("مدل‌ها، دانلودها و هزینه"),
                        items: [
                            .init(title: localization.localized("دستیار هوشمند"), detail: localization.localized("provider.configurable"), symbol: "wand.and.stars", color: PrototypeTheme.accent, destination: .ai),
                            .init(title: localization.localized("محتوای آفلاین"), detail: localization.localized("۱۸۴ مگابایت روی دستگاه"), symbol: "arrow.down.circle.fill", color: .indigo, destination: .offline)
                        ]
                    )
                    settingsGroup(
                        title: localization.localized("برنامه و حساب"),
                        subtitle: nil,
                        items: [
                            .init(title: localization.localized("حریم خصوصی و داده‌ها"), detail: localization.localized("محلی · پشتیبان اختیاری iCloud"), symbol: "lock.shield.fill", color: .green, destination: .privacy),
                            .init(title: localization.localized("دسترس‌پذیری و ظاهر"), detail: localization.localized("هماهنگ با سیستم"), symbol: "accessibility", color: .teal, destination: .accessibility),
                            .init(title: localization.localized("دربارهٔ LinguaBrain"), detail: localization.localized("Visual Prototype 0.2"), symbol: "info.circle.fill", color: .gray, destination: .about)
                        ]
                    )
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(localization.text(.settingsTitle))
    }

    private var customDomainsTitle: String {
        switch localization.language {
        case .english: "Custom categories"
        case .german: "Eigene Kategorien"
        case .persian: "دسته‌های سفارشی"
        }
    }

    private var customDomainsSubtitle: String {
        switch localization.language {
        case .english: "Create and manage your learning topics"
        case .german: "Eigene Lernthemen erstellen und verwalten"
        case .persian: "ساخت و مدیریت موضوع‌های یادگیری"
        }
    }

    private var profileCard: some View {
        PrototypeCard {
            HStack(spacing: 16) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(PrototypeTheme.heroGradient)
                        .frame(width: 68, height: 68)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                    Circle()
                        .fill(PrototypeTheme.mint)
                        .frame(width: 19, height: 19)
                        .overlay {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .overlay { Circle().stroke(.background, lineWidth: 3) }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("سعید رضایی")
                        .font(.title3.weight(.bold))
                    Text(localization.text(.learnerSubtitle))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(localization.text(.deviceOnlySync), systemImage: "iphone.gen3")
                        .font(.caption)
                        .foregroundStyle(PrototypeTheme.mint)
                }
                Spacer()
                Button(localization.text(.edit)) { }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func languageName(_ tag: String) -> String {
        PrototypeAppLanguage(rawValue: tag)?.nativeName ?? tag
    }

    private var learningSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "خلاصهٔ مسیر شما", subtitle: "تنظیماتی که برنامهٔ امروز را شکل می‌دهند")
            HStack(spacing: 10) {
                MetricPill(value: "B2", label: "سطح هدف", symbol: "flag.checkered", color: PrototypeTheme.accent)
                MetricPill(value: "۲۰ دقیقه", label: "هدف روزانه", symbol: "clock.fill", color: .orange)
                MetricPill(value: "آلمان", label: "مأموریت", symbol: "briefcase.fill", color: PrototypeTheme.mint)
            }
        }
    }

    private func settingsGroup(title: String, subtitle: String?, items: [SettingsItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, subtitle: subtitle)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        SettingsDetailPrototypeView(section: item.destination)
                    } label: {
                        SettingsRow(item: item)
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.primary.opacity(0.07), lineWidth: 1)
            }
        }
    }
}

private struct SettingsRow: View {
    @Environment(PrototypeLocalization.self) private var localization
    let item: SettingsItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(item.color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(localization.localized(item.title))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(localization.localized(item.detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.left")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct SettingsItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    let destination: SettingsSection
}

private enum SettingsSection {
    case languages, domains, learning, review, audio, ai, offline, privacy, accessibility, about

    func title(for localization: PrototypeLocalization) -> String {
        switch self {
        case .languages: localization.text(.languagesAndLevel)
        case .domains:
            switch localization.language {
            case .english: "Custom categories"
            case .german: "Eigene Kategorien"
            case .persian: "دسته‌های سفارشی"
            }
        case .learning: localization.text(.goalsAndDailyPlan)
        case .review: localization.text(.reviewAndPractice)
        case .audio: localization.text(.audioAndPronunciation)
        case .ai, .offline, .privacy, .accessibility, .about: localization.localized(rawValue)
        }
    }

    private var rawValue: String {
        switch self {
        case .ai: "settings.ai"
        case .offline: "settings.offline"
        case .privacy: "settings.privacy"
        case .accessibility: "settings.accessibility"
        case .about: "settings.about"
        default: ""
        }
    }
}

private struct SettingsDetailPrototypeView: View {
    let section: SettingsSection
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeCloudBackupController.self) private var cloudBackup
    @State private var dailyGoal = 20
    @State private var notifications = true
    @State private var offlineOnly = false
    @State private var audioSpeed = 1.0

    var body: some View {
        Form {
            switch section {
            case .languages:
                Section(localization.text(.languageSettings)) {
                    Picker(localization.text(.interfaceLanguage), selection: interfaceLanguageBinding) {
                        ForEach(PrototypeAppLanguage.allCases) { language in
                            Text(language.nativeName).tag(language)
                        }
                    }
                    Picker(localization.text(.explanationLanguage), selection: sourceLanguageBinding) {
                        ForEach(PrototypeAppLanguage.allCases) { language in
                            Text(language.nativeName).tag(language.rawValue)
                        }
                    }
                    Picker(localization.text(.learningLanguage), selection: targetLanguageBinding) {
                        ForEach(PrototypeAppLanguage.allCases) { language in
                            Text(language.nativeName).tag(language.rawValue)
                        }
                    }
                    LabeledContent(localization.text(.currentLevel), value: "B1")
                    LabeledContent(localization.text(.targetLevel), value: "B2")
                    if !languageSettings.isValidPair {
                        Label(localization.localized("Source and learning languages must be different."), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            case .domains:
                CustomDomainsSettingsContent()
            case .learning:
                Section(localization.localized("برنامهٔ روزانه")) {
                    Picker(localization.localized("هدف روزانه"), selection: $dailyGoal) {
                        Text(localization.localized("۱۰ دقیقه")).tag(10)
                        Text(localization.localized("۲۰ دقیقه")).tag(20)
                        Text(localization.localized("۳۰ دقیقه")).tag(30)
                        Text(localization.localized("۶۰ دقیقه")).tag(60)
                    }
                    LabeledContent(localization.localized("مأموریت فعال"), value: localization.localized("کار در آلمان"))
                    Toggle(localization.localized("یادآوری روزانه"), isOn: $notifications)
                }
            case .review:
                Section(localization.localized("روش تمرین")) {
                    LabeledContent(localization.localized("الگوریتم مرور"), value: localization.localized("تطبیقی"))
                    LabeledContent(localization.localized("جهت ترجمه"), value: localization.localized("هر دو جهت"))
                    Toggle(localization.localized("مرور شنیداری"), isOn: $notifications)
                }
            case .audio:
                Section(localization.localized("پخش")) {
                    LabeledContent(localization.localized("صدای آلمانی"), value: "Anna")
                    Slider(value: $audioSpeed, in: 0.5...1.5, step: 0.1) {
                        Text(localization.localized("سرعت پخش"))
                    }
                    LabeledContent("سرعت", value: audioSpeed.formatted(.number.precision(.fractionLength(1))) + "×")
                }
            case .ai:
                ProviderMenuIndex()
                Section("Apple Intelligence — آینده") {
                    Label("Apple Foundation Models · بدون API Key", systemImage: "apple.intelligence")
                    Text("پس از ارزیابی پشتیبانی و کیفیت فارسی، پردازش محلی Apple به‌عنوان Provider اختیاری اضافه می‌شود.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("سایر ارائه‌دهندگان آینده") {
                    Label("LM Studio / Ollama", systemImage: "desktopcomputer")
                    Toggle("فقط حالت آفلاین", isOn: $offlineOnly)
                }
            case .offline:
                Section("دانلودشده") {
                    LabeledContent("واژگان پایه", value: "۱۲۰ مگابایت")
                    LabeledContent("صداهای آلمانی", value: "۶۴ مگابایت")
                    Button("مدیریت دانلودها") { }
                }
            case .privacy:
                @Bindable var cloudBackup = cloudBackup
                Section("پشتیبان iCloud") {
                    Toggle("ذخیرهٔ کارت‌های من در iCloud", isOn: $cloudBackup.isEnabled)
                    Text("کارت‌های ساخته‌شده و بسته‌های Anki واردشده در پایگاه خصوصی iCloud شما نگهداری می‌شوند. کارت‌های نمونهٔ برنامه ارسال نمی‌شوند.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("همگام‌سازی اکنون") {
                        Task { await cloudBackup.sync(store: store) }
                    }
                    .disabled(!cloudBackup.isEnabled || isCloudSyncBusy)
                    cloudStatusView
                }
                Section("داده‌های محلی") {
                    Button("خروجی گرفتن از داده‌ها") { }
                    Button("حذف تمام داده‌ها", role: .destructive) { }
                }
            case .accessibility:
                Section("نمایش و دسترسی") {
                    Toggle("متن خواناتر", isOn: $notifications)
                    LabeledContent("اندازهٔ نوشته", value: "هماهنگ با سیستم")
                    LabeledContent("ظاهر", value: "خودکار")
                }
            case .about:
                Section {
                    LabeledContent("نسخه", value: "Visual Prototype 0.2")
                    NavigationLink("نمایش راه‌اندازی اولیه") {
                        OnboardingPrototypeView()
                    }
                }
            }
        }
        .navigationTitle(section == .languages ? localization.text(.languageSettings) : section.title(for: localization))
        .onChange(of: cloudBackup.isEnabled) { _, enabled in
            guard section == .privacy, enabled else { return }
            Task { await cloudBackup.sync(store: store) }
        }
    }

    private var interfaceLanguageBinding: Binding<PrototypeAppLanguage> {
        Binding(get: { localization.language }, set: { localization.language = $0 })
    }

    private var sourceLanguageBinding: Binding<String> {
        Binding(get: { languageSettings.sourceLanguageTag }, set: { languageSettings.selectSource($0) })
    }

    private var targetLanguageBinding: Binding<String> {
        Binding(get: { languageSettings.targetLanguageTag }, set: { languageSettings.selectTarget($0) })
    }

    private var isCloudSyncBusy: Bool {
        cloudBackup.status == .checking || cloudBackup.status == .syncing
    }

    @ViewBuilder
    private var cloudStatusView: some View {
        switch cloudBackup.status {
        case .idle:
            Label("هنوز همگام‌سازی نشده است", systemImage: "icloud")
        case .checking:
            Label("در حال بررسی حساب iCloud…", systemImage: "icloud")
        case .syncing:
            HStack { ProgressView(); Text("در حال پشتیبان‌گیری و بازیابی…") }
        case let .synced(date, count):
            Label("آخرین همگام‌سازی: \(date.formatted(date: .abbreviated, time: .shortened)) · \(count) کارت", systemImage: "checkmark.icloud.fill")
                .foregroundStyle(.green)
        case let .unavailable(message):
            Label(message, systemImage: "icloud.slash")
                .foregroundStyle(.orange)
        case let .failed(message):
            Label("همگام‌سازی ناموفق بود: \(message)", systemImage: "exclamationmark.icloud.fill")
                .foregroundStyle(.red)
        }
    }
}

private struct CustomDomainsSettingsContent: View {
    @Environment(PrototypeLocalization.self) private var localization
    @State private var domains = PrototypeDomainCatalog.customDomains
    @State private var newDomain = ""

    var body: some View {
        Section(copy.title) {
            Text(copy.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField(copy.placeholder, text: $newDomain)
                Button(copy.add) {
                    if PrototypeDomainCatalog.add(newDomain) != nil {
                        domains = PrototypeDomainCatalog.customDomains
                        newDomain = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newDomain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if domains.isEmpty {
                Text(copy.empty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(domains, id: \.self) { domain in
                    HStack {
                        Text(domain)
                        Spacer()
                        Button(role: .destructive) {
                            PrototypeDomainCatalog.remove(domain)
                            domains = PrototypeDomainCatalog.customDomains
                        } label: {
                            Label(copy.delete, systemImage: "trash")
                        }
                    }
                }
            }
        }
        .onAppear { domains = PrototypeDomainCatalog.customDomains }
    }

    private var copy: (title: String, subtitle: String, placeholder: String, add: String, empty: String, delete: String) {
        switch localization.language {
        case .english: ("Custom categories", "Create topics that constrain AI card generation.", "Category name", "Add", "No custom categories yet.", "Delete")
        case .german: ("Eigene Kategorien", "Erstellen Sie Themen, die die KI-Kartenerstellung eingrenzen.", "Kategoriename", "Hinzufügen", "Noch keine eigenen Kategorien.", "Löschen")
        case .persian: ("دسته‌های سفارشی", "موضوع‌هایی بسازید که تولید کارت با هوش مصنوعی را محدود می‌کنند.", "نام دسته", "افزودن", "هنوز دستهٔ سفارشی ندارید.", "حذف")
        }
    }
}

private struct LegacyProviderSettingsForm: View {
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeAISettings.self) private var settings
    @State private var apiKey = ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        @Bindable var settings = settings
        Section(localization.localized("provider.text")) {
            SecureField(settings.hasAPIKey ? localization.localized("provider.savedKeyChange") : localization.localized("provider.apiKey"), text: $apiKey)
                .textContentType(.password)
                .environment(\.layoutDirection, .leftToRight)
            TextField("Model ID", text: $settings.modelID)
                .environment(\.layoutDirection, .leftToRight)
            Toggle(localization.localized("provider.cloudConsent"), isOn: $settings.cloudConsent)
            Text(localization.localized("provider.keychainNotice"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button(localization.localized("ذخیرهٔ امن کلید")) {
                    do {
                        try settings.saveAPIKey(apiKey)
                        apiKey = ""
                        statusMessage = "کلید در Keychain ذخیره شد."
                    } catch {
                        statusMessage = error.localizedDescription
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(localization.localized("تست اتصال")) { testConnection() }
                    .disabled(!settings.hasAPIKey || isTesting)

                if settings.hasAPIKey {
                    Button(localization.localized("حذف کلید"), role: .destructive) {
                        settings.deleteAPIKey()
                        statusMessage = "کلید حذف شد."
                    }
                }
            }

            if isTesting { ProgressView(localization.localized("در حال آزمایش…")) }
            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(statusMessage.contains("موفق") ? PrototypeTheme.mint : .secondary)
            }
        }
    }

    private func testConnection() {
        isTesting = true
        Task {
            do {
                try await ConfiguredProviderClient(baseURL: settings.endpoint, protocolName: settings.protocolName).testConnection(apiKey: try settings.apiKey())
                statusMessage = "اتصال موفق بود."
            } catch {
                statusMessage = error.localizedDescription
            }
            isTesting = false
        }
    }
}

@MainActor
@Observable
final class PrototypeAISettings {
    private static let modelKey = "prototype.provider.text.model"
    private static let consentKey = "prototype.provider.cloudConsent"
    private static let keychainService = "ai.linguabrain.provider"
    private static let keychainAccount = "api-key"
    private static let textModeKey = "prototype.provider.text.mode"
    private static let audioModeKey = "prototype.provider.audio.mode"
    private static let imageModeKey = "prototype.provider.image.mode"
    private static let endpointKey = "prototype.provider.endpoint"
    private static let audioEndpointKey = "prototype.provider.audio.endpoint"
    private static let imageEndpointKey = "prototype.provider.image.endpoint"
    private static let protocolKey = "prototype.provider.protocol"
    private static let audioProtocolKey = "prototype.provider.audio.protocol"
    private static let audioVoiceKey = "prototype.provider.audio.voice"
    private static let imageModelKey = "prototype.provider.image.model"
    private static let audioModelKey = "prototype.provider.audio.model"
    private static let audioModelOptionsKey = "prototype.provider.audio.model-options"
    private static let audioTranscriptModelKey = "prototype.provider.audio.transcript-model"
    private static let audioTranscriptModelOptionsKey = "prototype.provider.audio.transcript-model-options"
    private static let audioStreamModelKey = "prototype.provider.audio.stream-model"
    private static let audioStreamModelOptionsKey = "prototype.provider.audio.stream-model-options"

    var textMode: PrototypeProviderMode { didSet { UserDefaults.standard.set(textMode.rawValue, forKey: Self.textModeKey) } }
    var audioMode: PrototypeProviderMode { didSet { UserDefaults.standard.set(audioMode.rawValue, forKey: Self.audioModeKey) } }
    var imageMode: PrototypeProviderMode { didSet { UserDefaults.standard.set(imageMode.rawValue, forKey: Self.imageModeKey) } }
    var endpoint: String { didSet { UserDefaults.standard.set(endpoint, forKey: Self.endpointKey) } }
    var audioEndpoint: String { didSet { UserDefaults.standard.set(audioEndpoint, forKey: Self.audioEndpointKey) } }
    var imageEndpoint: String { didSet { UserDefaults.standard.set(imageEndpoint, forKey: Self.imageEndpointKey) } }
    var protocolName: String { didSet { UserDefaults.standard.set(protocolName, forKey: Self.protocolKey) } }
    var audioProtocolName: String { didSet { UserDefaults.standard.set(audioProtocolName, forKey: Self.audioProtocolKey) } }
    var audioVoice: String { didSet { UserDefaults.standard.set(audioVoice, forKey: Self.audioVoiceKey) } }
    var imageModelID: String { didSet { UserDefaults.standard.set(imageModelID, forKey: Self.imageModelKey) } }
    var audioModelID: String { didSet { UserDefaults.standard.set(audioModelID, forKey: Self.audioModelKey) } }
    var audioModelOptions: [String] {
        didSet { UserDefaults.standard.set(audioModelOptions, forKey: Self.audioModelOptionsKey) }
    }
    var audioTranscriptModelID: String { didSet { UserDefaults.standard.set(audioTranscriptModelID, forKey: Self.audioTranscriptModelKey) } }
    var audioTranscriptModelOptions: [String] {
        didSet { UserDefaults.standard.set(audioTranscriptModelOptions, forKey: Self.audioTranscriptModelOptionsKey) }
    }
    var audioStreamModelID: String { didSet { UserDefaults.standard.set(audioStreamModelID, forKey: Self.audioStreamModelKey) } }
    var audioStreamModelOptions: [String] {
        didSet { UserDefaults.standard.set(audioStreamModelOptions, forKey: Self.audioStreamModelOptionsKey) }
    }

    var modelID: String {
        didSet { UserDefaults.standard.set(modelID, forKey: Self.modelKey) }
    }
    var cloudConsent: Bool {
        didSet { UserDefaults.standard.set(cloudConsent, forKey: Self.consentKey) }
    }
    private(set) var hasAPIKey: Bool

    init() {
        textMode = PrototypeProviderMode(rawValue: UserDefaults.standard.string(forKey: Self.textModeKey) ?? "cloud") ?? .cloud
        audioMode = PrototypeProviderMode(rawValue: UserDefaults.standard.string(forKey: Self.audioModeKey) ?? "cloud") ?? .cloud
        imageMode = PrototypeProviderMode(rawValue: UserDefaults.standard.string(forKey: Self.imageModeKey) ?? "cloud") ?? .cloud
        let storedTextEndpoint = UserDefaults.standard.string(forKey: Self.endpointKey) ?? ""
        if storedTextEndpoint.localizedCaseInsensitiveContains("openrouter.ai") {
            endpoint = "https://api.openai.com/v1"
            UserDefaults.standard.set("https://api.openai.com/v1", forKey: Self.endpointKey)
        } else {
            endpoint = storedTextEndpoint.isEmpty ? "https://api.openai.com/v1" : storedTextEndpoint
        }
        let storedProtocol = UserDefaults.standard.string(forKey: Self.protocolKey) ?? ""
        let resolvedProtocol = storedProtocol == "google-native" ? "google-native" : "openai-compatible"
        let storedAudioEndpoint = UserDefaults.standard.string(forKey: Self.audioEndpointKey) ?? ""
        // Audio follows the provider configuration already saved on this device.
        // Do not silently switch an existing installation to Google.
        let resolvedEndpoint = storedTextEndpoint.isEmpty ? "https://api.openai.com/v1" : storedTextEndpoint
        let candidateAudioEndpoint = storedAudioEndpoint.isEmpty ? resolvedEndpoint : storedAudioEndpoint
        audioEndpoint = (resolvedProtocol == "openai-compatible" && candidateAudioEndpoint.contains("texttospeech.googleapis.com"))
            ? resolvedEndpoint
            : candidateAudioEndpoint
        imageEndpoint = UserDefaults.standard.string(forKey: Self.imageEndpointKey) ?? "https://api.openai.com/v1"
        protocolName = resolvedProtocol
        let storedAudioProtocol = UserDefaults.standard.string(forKey: Self.audioProtocolKey)
        let resolvedAudioProtocol = (resolvedProtocol == "openai-compatible" && storedAudioProtocol == "google-native")
            ? "openai-compatible"
            : (storedAudioProtocol ?? resolvedProtocol)
        // Repair the stale Google values written by the previous implementation
        // when this device is configured for OpenAI-compatible speech.
        let storedVoice = UserDefaults.standard.string(forKey: Self.audioVoiceKey) ?? ""
        let storedAudioModel = UserDefaults.standard.string(forKey: Self.audioModelKey) ?? ""
        audioProtocolName = resolvedAudioProtocol
        if resolvedAudioProtocol == "openai-compatible" {
            audioVoice = storedVoice.isEmpty || storedVoice.contains("Standard-") ? "alloy" : storedVoice
            // `audioModelID` remains the speech-synthesis role used by card
            // pronunciation. Older builds stored transcription models here;
            // migrate those installations back to a valid TTS default.
            let storedLooksLikeTranscription = storedAudioModel.localizedCaseInsensitiveContains("transcri")
                || storedAudioModel.localizedCaseInsensitiveContains("whisper")
            audioModelID = storedAudioModel.isEmpty || storedAudioModel == "standard" || storedLooksLikeTranscription
                ? "gpt-4o-mini-tts"
                : storedAudioModel
        } else {
            audioVoice = storedVoice.isEmpty ? "de-DE-Standard-A" : storedVoice
            audioModelID = storedAudioModel.isEmpty ? "standard" : storedAudioModel
        }
        imageModelID = UserDefaults.standard.string(forKey: Self.imageModelKey) ?? "gpt-image-1-mini"
        modelID = UserDefaults.standard.string(forKey: Self.modelKey) ?? "gpt-4o-mini"
        let storedAudioOptions = UserDefaults.standard.stringArray(forKey: Self.audioModelOptionsKey) ?? []
        let storedTranscriptOptions = UserDefaults.standard.stringArray(forKey: Self.audioTranscriptModelOptionsKey) ?? []
        let storedStreamOptions = UserDefaults.standard.stringArray(forKey: Self.audioStreamModelOptionsKey) ?? []
        if resolvedAudioProtocol == "openai-compatible" {
            let migratedSpeech = storedAudioOptions.filter {
                $0.localizedCaseInsensitiveContains("tts") || $0.localizedCaseInsensitiveContains("speech-generation")
            }
            let migratedTranscript = storedAudioOptions.filter {
                ($0.localizedCaseInsensitiveContains("transcri") || $0.localizedCaseInsensitiveContains("whisper"))
                    && !$0.localizedCaseInsensitiveContains("live")
                    && !$0.localizedCaseInsensitiveContains("realtime")
            }
            let migratedStream = storedAudioOptions.filter {
                $0.localizedCaseInsensitiveContains("live-transcri") || $0.localizedCaseInsensitiveContains("realtime-whisper")
            }
            audioModelOptions = migratedSpeech.isEmpty ? ["gpt-4o-mini-tts", "tts-1", "tts-1-hd"] : migratedSpeech
            audioTranscriptModelOptions = storedTranscriptOptions.isEmpty
                ? (migratedTranscript.isEmpty ? ["gpt-transcribe", "gpt-4o-transcribe", "gpt-4o-mini-transcribe", "whisper-1"] : migratedTranscript)
                : storedTranscriptOptions
            audioStreamModelOptions = storedStreamOptions.isEmpty
                ? (migratedStream.isEmpty ? ["gpt-live-transcribe", "gpt-realtime-whisper"] : migratedStream)
                : storedStreamOptions
        } else {
            audioModelOptions = storedAudioOptions
            audioTranscriptModelOptions = storedTranscriptOptions
            audioStreamModelOptions = storedStreamOptions
        }
        audioTranscriptModelID = UserDefaults.standard.string(forKey: Self.audioTranscriptModelKey) ?? "gpt-transcribe"
        audioStreamModelID = UserDefaults.standard.string(forKey: Self.audioStreamModelKey) ?? "gpt-live-transcribe"
        cloudConsent = UserDefaults.standard.bool(forKey: Self.consentKey)
        hasAPIKey = (try? Self.readTextOrLegacyKey()) != nil
    }

    func saveAPIKey(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ProviderError.missingAPIKey }
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: Self.keychainAccount,
            kSecValueData: Data(key.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        var status = SecItemUpdate([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: Self.keychainAccount
        ] as CFDictionary, [kSecValueData: Data(key.utf8)] as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(attributes as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ProviderError.keychain(status) }
        hasAPIKey = true
    }

    func apiKey() throws -> String {
        guard let key = try Self.readTextOrLegacyKey() else { throw ProviderError.missingAPIKey }
        return key
    }

    func deleteAPIKey() {
        #if DEBUG
        print("[ProviderDebug] delete requested: service=\(Self.keychainService) accounts=\(Self.keychainAccount),\(Self.keychainAccount).text")
        #endif
        Self.deleteStoredKey()
        Self.deleteStoredKey(account: Self.keychainAccount + ".text")
        hasAPIKey = false
    }

    func hasAPIKey(for provider: String) -> Bool {
        (try? Self.readKey(account: Self.keychainAccount + "." + provider)) != nil || (try? Self.readTextOrLegacyKey()) != nil
    }

    func deleteAPIKey(for provider: String) {
        #if DEBUG
        print("[ProviderDebug] delete provider key: provider=\(provider) account=\(Self.keychainAccount).\(provider)")
        #endif
        Self.deleteStoredKey(account: Self.keychainAccount + "." + provider)
        if provider == "text" {
            Self.deleteStoredKey()
            hasAPIKey = false
        }
    }

    func saveProviderAPIKey(_ value: String, provider: String = "text") throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ProviderError.missingAPIKey }
        #if DEBUG
        if key.count > 512 {
            print("[ProviderDebug] warning: credential length=\(key.count); this is unusually large for an API key. Verify that only the key text was pasted.")
        }
        #endif
        try saveKey(key, account: Self.keychainAccount + "." + provider)
        // Keep the legacy account synchronized for already-installed builds that
        // still read the pre-provider Keychain account.
        if provider == "text" {
            try saveKey(key, account: Self.keychainAccount)
        }
    }

    func providerAPIKey(_ provider: String = "text") throws -> String { try Self.readKey(account: Self.keychainAccount + "." + provider) ?? apiKey() }

    func apiKey(for provider: String) throws -> String { try Self.readKey(account: Self.keychainAccount + "." + provider) ?? apiKey() }

    private func saveKey(_ key: String, account: String) throws {
        var status = SecItemUpdate([kSecClass: kSecClassGenericPassword, kSecAttrService: Self.keychainService, kSecAttrAccount: account] as CFDictionary, [kSecValueData: Data(key.utf8)] as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd([kSecClass: kSecClassGenericPassword, kSecAttrService: Self.keychainService, kSecAttrAccount: account, kSecValueData: Data(key.utf8), kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ProviderError.keychain(status) }
        ProviderCredentialDiagnostics.logSave(account: account, key: key)
        hasAPIKey = true
    }

    private static func readKey(account: String) throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([kSecClass: kSecClassGenericPassword, kSecAttrService: keychainService, kSecAttrAccount: account, kSecReturnData: true, kSecMatchLimit: kSecMatchLimitOne] as CFDictionary, &result)
        if status == errSecItemNotFound {
            #if DEBUG
            print("[ProviderDebug] key not found: service=\(keychainService) account=\(account)")
            #endif
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else { throw ProviderError.keychain(status) }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func readTextOrLegacyKey() throws -> String? {
        if let key = try readKey(account: keychainAccount + ".text") {
            ProviderCredentialDiagnostics.logRead(account: keychainAccount + ".text", key: key)
            return key
        }
        if let key = try readKey() {
            ProviderCredentialDiagnostics.logRead(account: keychainAccount, key: key)
            return key
        }
        return nil
    }

    private static func readKey() throws -> String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw ProviderError.keychain(status)
        }
        return key
    }

    private static func deleteStoredKey() {
        deleteStoredKey(account: keychainAccount)
    }

    private static func deleteStoredKey(account: String) {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account
        ] as CFDictionary)
    }
}

enum ProviderCredentialDiagnostics {
    static func logSave(account: String, key: String) {
        #if DEBUG
        print("[ProviderDebug] saved key: service=ai.linguabrain.provider account=\(account) length=\(key.count) fingerprint=\(fingerprint(key)) storage=Keychain")
        #endif
    }

    static func logRead(account: String, key: String) {
        #if DEBUG
        print("[ProviderDebug] read key: service=ai.linguabrain.provider account=\(account) length=\(key.count) fingerprint=\(fingerprint(key)) storage=Keychain")
        #endif
    }

    static func logRequest(endpoint: String, model: String, account: String, key: String) {
        #if DEBUG
        print("[ProviderDebug] request: endpoint=\(endpoint) model=\(model) account=\(account) keyLength=\(key.count) keyFingerprint=\(fingerprint(key))")
        #endif
    }

    private static func fingerprint(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined().prefix(12).description
    }
}

enum PrototypeProviderMode: String, CaseIterable, Identifiable {
    case builtIn = "built-in"
    case local
    case cloud
    case off

    var id: Self { self }
    static var audioCases: [Self] { [.local, .cloud, .off] }
    var label: String {
        switch self {
        case .builtIn: "provider.builtIn"
        case .local: "provider.local"
        case .cloud: "provider.cloud"
        case .off: "provider.off"
        }
    }
}

private struct ProviderMenusForm: View {
    @Environment(PrototypeAISettings.self) private var settings
    @Environment(PrototypeLocalization.self) private var localization

    var body: some View {
        @Bindable var settings = settings
        Section(localization.localized("provider.text")) {
            Picker(localization.localized("provider.mode"), selection: $settings.textMode) {
                ForEach(PrototypeProviderMode.allCases) { mode in Text(localization.localized(mode.label)).tag(mode) }
            }
            TextField(localization.localized("provider.modelID"), text: $settings.modelID)
                .environment(\.layoutDirection, .leftToRight)
        }
        Section(localization.localized("provider.audio")) {
            Picker(localization.localized("provider.mode"), selection: $settings.audioMode) {
                ForEach(PrototypeProviderMode.allCases) { mode in Text(localization.localized(mode.label)).tag(mode) }
            }
        }
        Section(localization.localized("provider.image")) {
            Picker(localization.localized("provider.mode"), selection: $settings.imageMode) {
                ForEach(PrototypeProviderMode.allCases) { mode in Text(localization.localized(mode.label)).tag(mode) }
            }
        }
        Section(localization.localized("provider.connection")) {
            TextField(localization.localized("provider.endpoint"), text: $settings.endpoint)
                .environment(\.layoutDirection, .leftToRight)
            Picker(localization.localized("provider.protocol"), selection: $settings.protocolName) {
                Text(localization.localized("provider.openAICompatible")).tag("openai-compatible")
                Text(localization.localized("provider.googleNative")).tag("google-native")
            }
        }
        Text(localization.localized("provider.entitlementNote"))
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private enum PrototypeProviderKind: String, CaseIterable, Identifiable {
    case text, audio, image
    var id: Self { self }
    var titleKey: String { "provider.\(rawValue)" }
    var symbol: String {
        switch self { case .text: "text.alignleft"; case .audio: "waveform"; case .image: "photo" }
    }
}

private struct ProviderMenuIndex: View {
    @Environment(PrototypeLocalization.self) private var localization

    var body: some View {
        Section(localization.localized("provider.title")) {
            ForEach(PrototypeProviderKind.allCases) { kind in
                NavigationLink {
                    ProviderConfigurationView(kind: kind)
                } label: {
                    Label(localization.localized(kind.titleKey), systemImage: kind.symbol)
                }
            }
        }
    }
}

private struct ProviderConfigurationView: View {
    let kind: PrototypeProviderKind
    @Environment(PrototypeAISettings.self) private var settings
    @Environment(PrototypeLocalization.self) private var localization
    @State private var apiKey = ""
    @State private var keyMessage: String?
    @State private var isTestingConnection = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section(localization.localized(kind.titleKey)) {
                Picker(localization.localized("provider.mode"), selection: modeBinding(settings: settings)) {
                    ForEach(kind == .audio ? PrototypeProviderMode.audioCases : PrototypeProviderMode.allCases) { mode in
                        Text(localization.localized(mode.label)).tag(mode)
                    }
                }
                if kind == .text {
                    TextField(localization.localized("provider.modelID"), text: $settings.modelID)
                        .environment(\.layoutDirection, .leftToRight)
                    if settings.textMode == .cloud {
                        Toggle(localization.localized("provider.cloudConsent"), isOn: $settings.cloudConsent)
                        Text(localization.localized("provider.cloudConsentNotice"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if kind == .audio {
                    if settings.audioMode == .cloud {
                        if settings.audioModelOptions.isEmpty,
                           settings.audioTranscriptModelOptions.isEmpty,
                           settings.audioStreamModelOptions.isEmpty {
                            Text(localization.localized("provider.audioModelsNotLoaded"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker(localization.localized("provider.audioSpeechModel"), selection: $settings.audioModelID) {
                                ForEach(settings.audioModelOptions, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            Picker(localization.localized("provider.audioTranscriptModel"), selection: $settings.audioTranscriptModelID) {
                                ForEach(settings.audioTranscriptModelOptions, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            Picker(localization.localized("provider.audioStreamModel"), selection: $settings.audioStreamModelID) {
                                ForEach(settings.audioStreamModelOptions, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            Text(localization.localized("provider.audioModelRolesDescription"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if settings.audioMode == .local {
                        Text(localization.localized("provider.audioLocalDescription"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    TextField(localization.localized("provider.modelID"), text: $settings.imageModelID)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
            Section(localization.localized("provider.connection")) {
                TextField(localization.localized("provider.endpoint"), text: endpointBinding(settings: settings))
                    .environment(\.layoutDirection, .leftToRight)
                if kind == .audio {
                    Picker(localization.localized("provider.protocol"), selection: $settings.audioProtocolName) {
                        Text(localization.localized("provider.openAICompatible")).tag("openai-compatible")
                        Text(localization.localized("provider.googleNative")).tag("google-native")
                    }
                } else {
                    Picker(localization.localized("provider.protocol"), selection: $settings.protocolName) {
                        Text(localization.localized("provider.openAICompatible")).tag("openai-compatible")
                        Text(localization.localized("provider.googleNative")).tag("google-native")
                    }
                }
                if kind != .image || settings.imageMode == .cloud {
                    SecureField(localization.localized("provider.apiKey"), text: $apiKey)
                        .environment(\.layoutDirection, .leftToRight)
                    HStack {
                        Button(localization.localized("provider.saveKey")) {
                            do {
                                try settings.saveProviderAPIKey(apiKey, provider: kind.rawValue)
                                apiKey = ""
                                keyMessage = localization.localized("provider.keySaved")
                            } catch { keyMessage = error.localizedDescription }
                        }
                        if settings.hasAPIKey(for: kind.rawValue) {
                            Button(localization.localized("provider.deleteKey"), role: .destructive) {
                                settings.deleteAPIKey(for: kind.rawValue)
                                keyMessage = localization.localized("provider.keyDeleted")
                            }
                        }
                    }
                    if let keyMessage { Text(keyMessage).font(.caption).foregroundStyle(.secondary) }
                    if kind == .text {
                        Button(localization.localized("provider.testConnection")) {
                            testTextConnection(settings: settings)
                        }
                        .disabled(isTestingConnection || !settings.hasAPIKey(for: kind.rawValue))
                        if isTestingConnection { ProgressView() }
                    } else if kind == .audio {
                        Button(localization.localized("provider.testConnection")) {
                            testAudioConnection(settings: settings)
                        }
                        .disabled(isTestingConnection || !settings.hasAPIKey(for: kind.rawValue))
                        if isTestingConnection { ProgressView() }
                    }
                }
            }
        }
        .navigationTitle(localization.localized(kind.titleKey))
    }

    private func modeBinding(settings: PrototypeAISettings) -> Binding<PrototypeProviderMode> {
        switch kind {
        case .text: Binding(get: { settings.textMode }, set: { settings.textMode = $0 })
        case .audio: Binding(get: { settings.audioMode }, set: { settings.audioMode = $0 })
        case .image: Binding(get: { settings.imageMode }, set: { settings.imageMode = $0 })
        }
    }

    private func endpointBinding(settings: PrototypeAISettings) -> Binding<String> {
        switch kind {
        case .text: Binding(get: { settings.endpoint }, set: { settings.endpoint = $0 })
        case .audio: Binding(get: { settings.audioEndpoint }, set: { settings.audioEndpoint = $0 })
        case .image: Binding(get: { settings.imageEndpoint }, set: { settings.imageEndpoint = $0 })
        }
    }

    private func testTextConnection(settings: PrototypeAISettings) {
        isTestingConnection = true
        Task {
            do {
                let key = try settings.apiKey()
                try await ConfiguredProviderClient(baseURL: settings.endpoint, protocolName: settings.protocolName)
                    .testConnection(apiKey: key)
                keyMessage = localization.localized("provider.connectionSuccess")
            } catch {
                keyMessage = error.localizedDescription
            }
            isTestingConnection = false
        }
    }

    private func testAudioConnection(settings: PrototypeAISettings) {
        isTestingConnection = true
        Task {
            do {
                let key = try settings.apiKey(for: "audio")
                let catalog = try await ConfiguredProviderClient(baseURL: settings.audioEndpoint, protocolName: settings.audioProtocolName)
                    .fetchAudioModelCatalog(apiKey: key)
                settings.audioModelOptions = catalog.speech
                settings.audioTranscriptModelOptions = catalog.transcript
                settings.audioStreamModelOptions = catalog.stream
                if !catalog.speech.contains(settings.audioModelID) {
                    settings.audioModelID = catalog.speech.first ?? "gpt-4o-mini-tts"
                }
                if !catalog.transcript.contains(settings.audioTranscriptModelID) {
                    settings.audioTranscriptModelID = catalog.transcript.first ?? "gpt-transcribe"
                }
                if !catalog.stream.contains(settings.audioStreamModelID) {
                    settings.audioStreamModelID = catalog.stream.first ?? "gpt-live-transcribe"
                }
                keyMessage = localization.localized("provider.audioConnectionSuccess")
            } catch {
                keyMessage = error.localizedDescription
            }
            isTestingConnection = false
        }
    }
}

enum ProviderError: LocalizedError {
    case missingAPIKey
    case consentRequired
    case providerDisabled
    case unsupportedProtocol
    case invalidResponse
    case service(Int, String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "ابتدا API Key مربوط به provider انتخاب‌شده را در تنظیمات ذخیره کن."
        case .consentRequired: "برای provider ابری، اجازهٔ ارسال داده را در تنظیمات فعال کن."
        case .providerDisabled: "تولید متن در تنظیمات خاموش است."
        case .unsupportedProtocol: "پروتکل انتخاب‌شده هنوز برای تولید کارت پشتیبانی نمی‌شود."
        case .invalidResponse: "پاسخ provider با ساختار کارت سازگار نبود."
        case .service(let status, let message): "Provider (\(status)): \(message)"
        case .keychain(let status): "ذخیره یا خواندن Keychain انجام نشد (\(status))."
        }
    }
}

struct ConfiguredProviderCard: Codable, Sendable {
    enum TopicRelevance: String, Codable, Sendable {
        case direct
        case contextual
        case unrelated
    }

    struct Example: Codable, Sendable {
        let target: String
        let source: String
    }

    struct Sense: Codable, Sendable {
        let meaning: String
        let usage: String
        let example: Example
        let collocations: [String]
    }

    let targetText: String
    let sourceMeaning: String
    let level: String
    let partOfSpeech: String
    let article: String
    let topicRelevance: TopicRelevance
    let example: Example
    let senses: [Sense]

    func hasValidSourceLanguage(_ languageTag: String) -> Bool {
        guard languageTag == "fa" else { return true }
        let sourceFields = [sourceMeaning, example.source] + senses.flatMap { [$0.meaning, $0.usage, $0.example.source] }
        return sourceFields.allSatisfy { value in
            value.unicodeScalars.contains { (0x0600...0x06FF).contains($0.value) }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetText = try container.decode(String.self, forKey: .targetText)
        sourceMeaning = try container.decode(String.self, forKey: .sourceMeaning)
        level = try container.decode(String.self, forKey: .level)
        partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        article = try container.decode(String.self, forKey: .article)
        topicRelevance = try container.decode(TopicRelevance.self, forKey: .topicRelevance)
        example = try container.decode(Example.self, forKey: .example)
        senses = try container.decodeIfPresent([Sense].self, forKey: .senses) ?? []
    }

    func prototypeWord(domain: String, sourceLanguageTag: String, targetLanguageTag: String) -> PrototypeWord {
        PrototypeWord(
            german: targetText,
            persian: sourceMeaning,
            article: article.isEmpty ? nil : article,
            level: level,
            partOfSpeech: partOfSpeech,
            example: example.target,
            exampleTranslation: example.source,
            domain: domain,
            sourceLanguageTag: sourceLanguageTag,
            targetLanguageTag: targetLanguageTag
        )
    }

    func prototypeWords(domain: String, sourceLanguageTag: String, targetLanguageTag: String, representativeSenseIndexes: [Int]? = nil) -> [PrototypeWord] {
        guard !senses.isEmpty else { return [prototypeWord(domain: domain, sourceLanguageTag: sourceLanguageTag, targetLanguageTag: targetLanguageTag)] }
        let allowedIndexes = representativeSenseIndexes.map(Set.init)
        var seenMeanings = Set<String>()
        let cards = senses.enumerated().compactMap { index, sense -> PrototypeWord? in
            if let allowedIndexes, !allowedIndexes.contains(index) { return nil }
            let meaning = sense.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedMeaning = meaning.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !meaning.isEmpty, seenMeanings.insert(normalizedMeaning).inserted else { return nil }
            let persistedSense = PrototypeSense(
                meaning: meaning,
                usage: sense.usage.trimmingCharacters(in: .whitespacesAndNewlines),
                example: PrototypeExample(target: sense.example.target, source: sense.example.source),
                collocations: sense.collocations.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
            return PrototypeWord(
                german: targetText,
                persian: meaning,
                article: article.isEmpty ? nil : article,
                level: level,
                partOfSpeech: partOfSpeech,
                example: sense.example.target,
                exampleTranslation: sense.example.source,
                examples: [PrototypeExample(target: sense.example.target, source: sense.example.source)],
                senses: [persistedSense],
                domain: domain,
                sourceLanguageTag: sourceLanguageTag,
                targetLanguageTag: targetLanguageTag
            )
        }
        return cards.isEmpty ? [consolidatedPrototypeWord(domain: domain, sourceLanguageTag: sourceLanguageTag, targetLanguageTag: targetLanguageTag)] : cards
    }

    /// A submitted word is one learning item. Preserve all independently
    /// returned meanings and examples on that item instead of silently keeping
    /// only the provider's first sense.
    func consolidatedPrototypeWord(domain: String, sourceLanguageTag: String, targetLanguageTag: String) -> PrototypeWord {
        var seenMeanings = Set<String>()
        let meanings = ([sourceMeaning] + senses.map(\.meaning)).filter { meaning in
            let normalized = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return !normalized.isEmpty && seenMeanings.insert(normalized).inserted
        }
        var seenExamples = Set<String>()
        let examples = ([example] + senses.map(\.example)).filter { example in
            let normalized = "\(example.target)\u{001F}\(example.source)"
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return !normalized.isEmpty && seenExamples.insert(normalized).inserted
        }
        let primaryExample = examples.first ?? example
        let persistedSenses = senses.compactMap { sense -> PrototypeSense? in
            let meaning = sense.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !meaning.isEmpty else { return nil }
            return PrototypeSense(
                meaning: meaning,
                usage: sense.usage.trimmingCharacters(in: .whitespacesAndNewlines),
                example: PrototypeExample(target: sense.example.target, source: sense.example.source),
                collocations: sense.collocations.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            )
        }
        return PrototypeWord(
            german: targetText,
            persian: meanings.joined(separator: "\n• "),
            article: article.isEmpty ? nil : article,
            level: level,
            partOfSpeech: partOfSpeech,
            example: primaryExample.target,
            exampleTranslation: primaryExample.source,
            examples: examples.map { PrototypeExample(target: $0.target, source: $0.source) },
            senses: persistedSenses,
            domain: domain,
            sourceLanguageTag: sourceLanguageTag,
            targetLanguageTag: targetLanguageTag
        )
    }
}

struct NormalizedVocabularyItem: Codable, Sendable {
    let lemma: String
    let actualLevel: String
    let confidence: Double
}

struct ConfiguredProviderClient: Sendable {
    let baseURL: String
    let protocolName: String

    init(baseURL: String = "https://api.openai.com/v1", protocolName: String = "openai-compatible") {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.protocolName = protocolName
    }

    func testConnection(apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "\(baseURL)/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.service(http.statusCode, http.statusCode == 401 ? "کلید API معتبر نیست یا برای این endpoint قابل استفاده نیست." : "کلید یا اتصال معتبر نیست.")
        }
    }

    struct AudioModelCatalog {
        let speech: [String]
        let transcript: [String]
        let stream: [String]
    }

    func fetchAudioModelCatalog(apiKey: String) async throws -> AudioModelCatalog {
        var request = URLRequest(url: URL(string: "\(baseURL)/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.service(http.statusCode, http.statusCode == 401 ? "کلید API معتبر نیست یا برای این endpoint قابل استفاده نیست." : "دریافت فهرست مدل‌ها ناموفق بود.")
        }
        guard let envelope = try? JSONDecoder().decode(ProviderModelsEnvelope.self, from: data) else {
            throw ProviderError.invalidResponse
        }
        let models = envelope.data.map(\.id)
        if baseURL.localizedCaseInsensitiveContains("api.openai.com") {
            let speechOrder = ["gpt-4o-mini-tts", "tts-1", "tts-1-hd"]
            let transcriptOrder = ["gpt-transcribe", "gpt-4o-transcribe", "gpt-4o-mini-transcribe", "gpt-4o-transcribe-diarize", "whisper-1"]
            let streamOrder = ["gpt-live-transcribe", "gpt-realtime-whisper"]
            let speechModels = models.filter { id in
                let normalized = id.lowercased()
                return normalized.contains("tts") || (normalized.contains("speech") && !normalized.contains("speech-to-text"))
            }
            let transcriptModels = models.filter { id in
                let normalized = id.lowercased()
                return (normalized.contains("transcri") || normalized.contains("whisper"))
                    && !normalized.contains("live") && !normalized.contains("realtime")
            }
            let streamModels = models.filter { id in
                let normalized = id.lowercased()
                return normalized.contains("live-transcri") || normalized.contains("realtime-whisper")
            }
            return AudioModelCatalog(
                speech: Self.preferredModels(speechModels, including: speechOrder, order: speechOrder),
                transcript: Self.preferredModels(transcriptModels, including: transcriptOrder, order: transcriptOrder),
                stream: Self.preferredModels(streamModels, including: streamOrder, order: streamOrder)
            )
        }
        let speech = models.filter { id in
            let normalized = id.lowercased()
            return normalized.contains("tts") || normalized.contains("speech-generation")
        }.sorted()
        let stream = models.filter { id in
            let normalized = id.lowercased()
            return normalized.contains("live") || normalized.contains("realtime") || normalized.contains("stream")
        }.filter { $0.localizedCaseInsensitiveContains("transcri") || $0.localizedCaseInsensitiveContains("whisper") }.sorted()
        let transcript = models.filter { id in
            let normalized = id.lowercased()
            return normalized.contains("transcri") || normalized.contains("whisper") || normalized.contains("speech-to-text")
        }.filter { !stream.contains($0) }.sorted()
        return AudioModelCatalog(speech: speech, transcript: transcript, stream: stream)
    }

    private static func preferredModels(_ discovered: [String], including official: [String], order: [String]) -> [String] {
        let candidates = Array(Set(discovered).union(official))
        return candidates.sorted { left, right in
            let leftPriority = order.firstIndex(of: left) ?? Int.max
            let rightPriority = order.firstIndex(of: right) ?? Int.max
            return leftPriority == rightPriority ? left < right : leftPriority < rightPriority
        }
    }

    func translateText(_ text: String, model: String, apiKey: String, sourceLanguageTag: String, targetLanguageTag: String) async throws -> String {
        let body: [String: Any] = ["model": model, "messages": [["role": "system", "content": "Translate faithfully from \(sourceLanguageTag) to \(targetLanguageTag). Preserve paragraphs and return only the translation."], ["role": "user", "content": text]], "temperature": 0.1]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else { throw ProviderError.invalidResponse }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func extractImportantWords(from text: String, topic: String, languageTag: String, minimumLevel: String, model: String, apiKey: String) async throws -> [String] {
        let candidateProperties: [String: Any] = ["surfaceForm": ["type": "string"], "lemma": ["type": "string"], "partOfSpeech": ["type": "string", "enum": ["noun", "verb", "adjective", "adverb", "fixedExpression"]], "estimatedLevel": ["type": "string", "enum": ["A1", "A2", "B1", "B2", "C1", "C2"]], "topicRelevance": ["type": "string", "enum": ["direct", "contextual"]], "confidence": ["type": "number", "minimum": 0, "maximum": 1], "reason": ["type": "string"]]
        let schema: [String: Any] = ["type": "object", "properties": ["candidates": ["type": "array", "minItems": 1, "maxItems": 8, "items": ["type": "object", "properties": candidateProperties, "required": ["surfaceForm", "lemma", "partOfSpeech", "estimatedLevel", "topicRelevance", "confidence", "reason"], "additionalProperties": false]]], "required": ["candidates"], "additionalProperties": false]
        let instruction = "Select 3 to 8 genuinely important vocabulary items from this \(languageTag) passage for a learner studying '\(topic)' at CEFR \(minimumLevel) or higher. For every candidate return the exact surface form found in the passage and its canonical dictionary lemma. For German, verbs must be infinitives, nouns must use dictionary capitalization without an article in lemma, adjectives must be uninflected, and separable verbs must use their complete infinitive. Choose only content words or fixed expressions central to the passage/topic whose standard lexical CEFR level is \(minimumLevel) or above. Exclude articles, pronouns, conjunctions, prepositions, modal and auxiliary verbs, names, numbers, generic function words, and anything normally taught below \(minimumLevel). Confidence measures certainty in both lemma and CEFR classification. Return only JSON."
        let body: [String: Any] = ["model": model, "messages": [["role": "system", "content": instruction], ["role": "user", "content": text]], "response_format": ["type": "json_schema", "json_schema": ["name": "important_vocabulary", "strict": true, "schema": schema]], "temperature": 0.1, "max_tokens": 300]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String,
              let payload = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any],
              let candidates = payload["candidates"] as? [[String: Any]] else { throw ProviderError.invalidResponse }
        let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
        let minimumIndex = levels.firstIndex(of: minimumLevel) ?? 0
        let words = candidates.compactMap { candidate -> String? in
            guard let lemma = candidate["lemma"] as? String, let estimatedLevel = candidate["estimatedLevel"] as? String,
                  let confidence = candidate["confidence"] as? Double, confidence >= 0.8,
                  let levelIndex = levels.firstIndex(of: estimatedLevel), levelIndex >= minimumIndex else { return nil }
            return lemma
        }
        var seen = Set<String>()
        return words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted }
    }

    func normalizeVocabularyItem(_ surfaceForm: String, passage: String, languageTag: String, model: String, apiKey: String) async throws -> NormalizedVocabularyItem {
        let schema: [String: Any] = ["type": "object", "properties": ["lemma": ["type": "string"], "actualLevel": ["type": "string", "enum": ["A1", "A2", "B1", "B2", "C1", "C2"]], "confidence": ["type": "number", "minimum": 0, "maximum": 1]], "required": ["lemma", "actualLevel", "confidence"], "additionalProperties": false]
        let instruction = "Normalize the supplied \(languageTag) vocabulary item using its passage context. Return only its canonical dictionary headword and actual lexical CEFR level. For German: verbs must be infinitives, separable and reflexive verbs must retain their complete dictionary form, nouns must use dictionary capitalization without adding an article, and adjectives must be uninflected. Never echo an inflected surface form as lemma unless it is already the canonical dictionary form. Return only JSON."
        let userPayload = try JSONSerialization.data(withJSONObject: ["surfaceForm": surfaceForm, "passage": passage])
        let body: [String: Any] = ["model": model, "messages": [["role": "system", "content": instruction], ["role": "user", "content": String(decoding: userPayload, as: UTF8.self)]], "response_format": ["type": "json_schema", "json_schema": ["name": "normalized_vocabulary", "strict": true, "schema": schema]], "temperature": 0, "max_tokens": 120]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = root["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any], let content = message["content"] as? String else { throw ProviderError.invalidResponse }
        return try JSONDecoder().decode(NormalizedVocabularyItem.self, from: Data(content.utf8))
    }

    func representativeSenseIndexes(for card: ConfiguredProviderCard, model: String, apiKey: String) async throws -> [Int] {
        guard card.senses.count > 1 else { return card.senses.isEmpty ? [] : [0] }
        let schema: [String: Any] = ["type": "object", "properties": ["representativeIndexes": ["type": "array", "minItems": 1, "items": ["type": "integer"]]], "required": ["representativeIndexes"], "additionalProperties": false]
        let senses = card.senses.enumerated().map { ["index": $0.offset, "meaning": $0.element.meaning, "usage": $0.element.usage, "example": $0.element.example.target] as [String: Any] }
        let instruction = "Act as a strict lexicographic deduplicator. Return one zero-based representative index for each genuinely independent dictionary meaning. Merge paraphrases, near-synonyms, register or usage differences, collocations, grammatical variants, and different examples into the same meaning. Most ordinary words should produce one representative. Multiple representatives are allowed only when a learner must recall materially different definitions. Return only JSON."
        let payload = try JSONSerialization.data(withJSONObject: ["headword": card.targetText, "partOfSpeech": card.partOfSpeech, "senses": senses])
        let body: [String: Any] = ["model": model, "messages": [["role": "system", "content": instruction], ["role": "user", "content": String(decoding: payload, as: UTF8.self)]], "response_format": ["type": "json_schema", "json_schema": ["name": "sense_deduplication", "strict": true, "schema": schema]], "temperature": 0, "max_tokens": 150]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"; request.timeoutInterval = 45
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let root = try JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = root["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any], let content = message["content"] as? String, let decoded = try JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any], let indexes = decoded["representativeIndexes"] as? [Int] else { throw ProviderError.invalidResponse }
        return Array(Set(indexes.filter { card.senses.indices.contains($0) })).sorted()
    }

    func generateCard(word: String, domain: String, model: String, apiKey: String, sourceLanguageTag: String = "fa", targetLanguageTag: String = "de", context: String? = nil, level: String? = nil) async throws -> ConfiguredProviderCard {
        let categoryScope = categoryScope(for: domain) + "; meanings and usage must be in source language \(sourceLanguageTag) (Persian script when fa), while target examples remain in \(targetLanguageTag)"
        let contextInstruction = "IMPORTANT LANGUAGE CONTRACT: targetText and example.target are \(targetLanguageTag); sourceMeaning, every senses.meaning, senses.usage, and example.source are \(sourceLanguageTag). Report the headword's actual CEFR level; never raise or relabel it to match the learner's requested minimum. " + ((context.map { "Use this learner-supplied passage as the primary context (do not copy it verbatim): \($0.prefix(4000))" } ?? "No passage was supplied; use authentic examples for the category.")) + (level.map { " The learner requested minimum CEFR \($0), but accuracy of the word's actual level is mandatory." } ?? "")
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "targetText": ["type": "string"],
                "sourceMeaning": ["type": "string"],
                "level": ["type": "string"],
                "partOfSpeech": ["type": "string"],
                "article": ["type": "string"],
                "topicRelevance": ["type": "string", "enum": ["direct", "contextual", "unrelated"]],
                "example": [
                    "type": "object",
                    "properties": ["target": ["type": "string"], "source": ["type": "string"]],
                    "required": ["target", "source"],
                    "additionalProperties": false
                ],
                "senses": [
                    "type": "array",
                    "maxItems": 3,
                    "items": [
                        "type": "object",
                        "properties": [
                            "meaning": ["type": "string"],
                            "usage": ["type": "string"],
                            "example": ["type": "object", "properties": ["target": ["type": "string"], "source": ["type": "string"]], "required": ["target", "source"], "additionalProperties": false],
                            "collocations": ["type": "array", "items": ["type": "string"]]
                        ],
                        "required": ["meaning", "usage", "example", "collocations"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["targetText", "sourceMeaning", "level", "partOfSpeech", "article", "topicRelevance", "example", "senses"],
            "additionalProperties": false
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You are an expert lexicographer and curriculum-aware language teacher creating accurate learning cards. The learning language is \(targetLanguageTag); the learner's support language is \(sourceLanguageTag). The selected topic is the organizing principle of the card, not a pass/fail filter. Establish the supplied headword's real spelling, grammar, and dictionary meanings, then choose the meaning and usage most useful inside the supplied topic scope. Preserve targetText as the supplied headword apart from normal capitalization or a required article. Never replace it with another word and never invent a meaning or collocation. General verbs, adjectives, and everyday nouns belong when they naturally occur in topic-specific instructions, questions, rules, reports, warnings, or conversations. Make the primary meaning, example, usage note, and collocations concretely reflect the topic wherever linguistically natural. Do not split paraphrases, register variants, grammar variants, synonyms, usage notes, collocations, or different examples into separate senses. An ordinary noun normally has one card: only return multiple senses for unmistakably independent dictionary homonyms. Return only genuinely independent dictionary meanings. Use an empty article for non-nouns. All meanings and example.source values must be in \(sourceLanguageTag); targetText and example.target values must be in \(targetLanguageTag)."],
                ["role": "user", "content": "Create a complete card for the \(targetLanguageTag) headword '\(word)' in the learner category '\(domain)'. Topic scope: \(categoryScope). \(contextInstruction) Treat all of these as relevant parts of the category and use the closest natural context for this word. The first meaning and primary example must prioritize the selected topic when a genuine use exists. Set topicRelevance to direct for specialist terminology, contextual for an ordinary word naturally used in this topic, and unrelated only when no honest topical use exists; this label is informational and must never prevent returning a card. Choose a precise sourceMeaning and a natural, realistic example. Return up to three genuinely independent meanings, with the topic-relevant meaning first. Other common independent meanings may follow when useful, but do not create multiple cards for mere paraphrases. If the word is uncommon or ambiguous, keep the requested headword and return the best supported dictionary analysis instead of guessing another word. Fill every required JSON field and return only the requested JSON object."]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "linguabrain_card", "strict": true, "schema": schema]
            ],
            "temperature": 0.1,
            "max_tokens": 1_200
        ]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        if !apiKey.isEmpty { request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }?["message"] as? String ?? "درخواست ناموفق بود."
            let normalizedMessage = http.statusCode == 401 ? "کلید API معتبر نیست یا برای این endpoint قابل استفاده نیست." : message
            throw ProviderError.service(http.statusCode, normalizedMessage)
        }
        let envelope = try JSONDecoder().decode(ProviderChatEnvelope.self, from: data)
        guard let content = envelope.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else { throw ProviderError.invalidResponse }
        return try JSONDecoder().decode(ConfiguredProviderCard.self, from: contentData)
    }

    private func categoryScope(for domain: String) -> String {
        let normalized = domain.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.contains("fuhrerschein") || normalized.contains("führerschein") || normalized.contains("driv") || normalized.contains("verkehr") || normalized.contains("road") || normalized.contains("رانند") || normalized.contains("گواهینامه") {
            return "driving and road traffic; driving-licence theory and practical tests; roads, lanes, intersections and right of way; traffic laws, signs and signals; speed, distance and parking; vehicles and their operation; drivers, cyclists and pedestrians; hazards, weather, accidents and first aid; offences, fines, alcohol or drugs, police checks, insurance, registration and licensing administration"
        }
        if normalized == "software" || normalized.contains("برنامه") {
            return "software development, applications, interfaces, data, debugging, security, deployment, technical documentation and workplace communication"
        }
        if normalized == "medical" || normalized.contains("پزش") || normalized.contains("gesund") {
            return "healthcare, symptoms, anatomy, diagnosis, treatment, medication, appointments, hospitals, emergencies and communication with patients"
        }
        if normalized == "work" || normalized.contains("کار") || normalized.contains("beruf") {
            return "workplaces, professions, tasks, meetings, employment, applications, contracts, schedules, collaboration and professional communication"
        }
        if normalized == "general" {
            return "common everyday situations, practical communication, home, travel, services, relationships, news and public life"
        }
        return "the topic '\(domain)' and its terminology, actors, objects, places, actions, rules, processes, risks, documents, common questions and authentic real-world conversations"
    }

    func translate(text: String, targetLanguageTag: String, model: String, apiKey: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "Translate the user's text into language code \(targetLanguageTag). Preserve meaning, names, numbers, and paragraph breaks. Return only the translation."],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "max_tokens": 2_000
        ]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }?["message"] as? String ?? "ترجمه ناموفق بود."
            throw ProviderError.service(http.statusCode, message)
        }
        let envelope = try JSONDecoder().decode(ProviderChatEnvelope.self, from: data)
        guard let content = envelope.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse
        }
        return content
    }

    func streamTranslate(text: String, targetLanguageTag: String, model: String, apiKey: String, onDelta: @escaping @Sendable (String) async -> Void) async throws {
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": "Translate into language code \(targetLanguageTag). Return only the translation."],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "max_tokens": 2_000
        ]
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.invalidResponse
        }
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(ProviderStreamEnvelope.self, from: data),
                  let delta = chunk.choices.first?.delta.content,
                  !delta.isEmpty else { continue }
            await onDelta(delta)
        }
    }
}

private struct ProviderChatEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }
    let choices: [Choice]
}

private struct ProviderModelsEnvelope: Decodable {
    struct Model: Decodable { let id: String }
    let data: [Model]
}

private struct ProviderStreamEnvelope: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }
    let choices: [Choice]
}

#Preview("Settings") {
    NavigationStack {
        SettingsPrototypeView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .tint(PrototypeTheme.accent)
}
