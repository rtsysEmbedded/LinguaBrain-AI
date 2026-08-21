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
    case languages, learning, review, audio, ai, offline, privacy, accessibility, about

    func title(for localization: PrototypeLocalization) -> String {
        switch self {
        case .languages: localization.text(.languagesAndLevel)
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
            audioModelID = storedAudioModel.isEmpty || storedAudioModel == "standard" ? "gpt-4o-mini-tts" : storedAudioModel
        } else {
            audioVoice = storedVoice.isEmpty ? "de-DE-Standard-A" : storedVoice
            audioModelID = storedAudioModel.isEmpty ? "standard" : storedAudioModel
        }
        imageModelID = UserDefaults.standard.string(forKey: Self.imageModelKey) ?? "gpt-image-1-mini"
        modelID = UserDefaults.standard.string(forKey: Self.modelKey) ?? "gpt-4o-mini"
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
        (try? Self.readKey(account: Self.keychainAccount + "." + provider)) != nil
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
                    ForEach(PrototypeProviderMode.allCases) { mode in
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
                    TextField(localization.localized("provider.voice"), text: $settings.audioVoice)
                        .environment(\.layoutDirection, .leftToRight)
                    TextField(localization.localized("provider.modelID"), text: $settings.audioModelID)
                        .environment(\.layoutDirection, .leftToRight)
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
    let example: Example
    let senses: [Sense]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetText = try container.decode(String.self, forKey: .targetText)
        sourceMeaning = try container.decode(String.self, forKey: .sourceMeaning)
        level = try container.decode(String.self, forKey: .level)
        partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        article = try container.decode(String.self, forKey: .article)
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

    func prototypeWords(domain: String, sourceLanguageTag: String, targetLanguageTag: String) -> [PrototypeWord] {
        guard !senses.isEmpty else { return [prototypeWord(domain: domain, sourceLanguageTag: sourceLanguageTag, targetLanguageTag: targetLanguageTag)] }
        return senses.map { sense in
            PrototypeWord(
                german: targetText,
                persian: sense.meaning,
                article: article.isEmpty ? nil : article,
                level: level,
                partOfSpeech: partOfSpeech,
                example: sense.example.target,
                exampleTranslation: sense.example.source,
                domain: domain,
                sourceLanguageTag: sourceLanguageTag,
                targetLanguageTag: targetLanguageTag
            )
        }
    }
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

    func generateCard(word: String, domain: String, model: String, apiKey: String, sourceLanguageTag: String = "fa", targetLanguageTag: String = "de") async throws -> ConfiguredProviderCard {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "targetText": ["type": "string"],
                "sourceMeaning": ["type": "string"],
                "level": ["type": "string"],
                "partOfSpeech": ["type": "string"],
                "article": ["type": "string"],
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
            "required": ["targetText", "sourceMeaning", "level", "partOfSpeech", "article", "example", "senses"],
            "additionalProperties": false
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You create accurate language-learning cards. The learning language is \(targetLanguageTag); the learner's support language is \(sourceLanguageTag). Return a shared lexical parent plus up to three important independent senses. Each sense must have its own natural example, usage/register, and collocations. Use an empty article for non-nouns."],
                ["role": "user", "content": "Create a complete card for the \(targetLanguageTag) word or phrase '\(word)' using the domain '\(domain)'. Include all common meanings that are useful at the learner level, but do not invent obscure meanings. Return targetText and examples in \(targetLanguageTag), and meanings/translations in \(sourceLanguageTag). Return only the requested JSON fields."]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "linguabrain_card", "strict": true, "schema": schema]
            ],
            "temperature": 0.2,
            "max_tokens": 700
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
}

private struct ProviderChatEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
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
