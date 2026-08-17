import SwiftUI
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
                            .init(title: localization.text(.goalsAndDailyPlan), detail: "کار در آلمان · ۲۰ دقیقه", symbol: "target", color: PrototypeTheme.pink, destination: .learning),
                            .init(title: localization.text(.reviewAndPractice), detail: "مرور تطبیقی · حالت متعادل", symbol: "rectangle.stack.fill", color: .orange, destination: .review),
                            .init(title: localization.text(.audioAndPronunciation), detail: "صدای آلمانی · سرعت عادی", symbol: "waveform", color: PrototypeTheme.mint, destination: .audio)
                        ]
                    )
                    settingsGroup(
                        title: "هوش مصنوعی و آفلاین",
                        subtitle: "مدل‌ها، دانلودها و هزینه",
                        items: [
                            .init(title: "دستیار هوشمند", detail: "OpenRouter · قابل تنظیم", symbol: "wand.and.stars", color: PrototypeTheme.accent, destination: .ai),
                            .init(title: "محتوای آفلاین", detail: "۱۸۴ مگابایت روی دستگاه", symbol: "arrow.down.circle.fill", color: .indigo, destination: .offline)
                        ]
                    )
                    settingsGroup(
                        title: "برنامه و حساب",
                        subtitle: nil,
                        items: [
                            .init(title: "حریم خصوصی و داده‌ها", detail: "ذخیرهٔ محلی", symbol: "lock.shield.fill", color: .green, destination: .privacy),
                            .init(title: "دسترس‌پذیری و ظاهر", detail: "هماهنگ با سیستم", symbol: "accessibility", color: .teal, destination: .accessibility),
                            .init(title: "دربارهٔ LinguaBrain", detail: "Visual Prototype 0.2", symbol: "info.circle.fill", color: .gray, destination: .about)
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

    var title: String {
        switch self {
        case .languages: "زبان‌ها و سطح"
        case .learning: "هدف‌ها و برنامهٔ روزانه"
        case .review: "مرور و تمرین"
        case .audio: "صدا و تلفظ"
        case .ai: "دستیار هوشمند"
        case .offline: "محتوای آفلاین"
        case .privacy: "حریم خصوصی و داده‌ها"
        case .accessibility: "دسترس‌پذیری و ظاهر"
        case .about: "دربارهٔ LinguaBrain"
        }
    }
}

private struct SettingsDetailPrototypeView: View {
    let section: SettingsSection
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
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
                        Label("Source and learning languages must be different.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            case .learning:
                Section("برنامهٔ روزانه") {
                    Picker("هدف روزانه", selection: $dailyGoal) {
                        Text("۱۰ دقیقه").tag(10)
                        Text("۲۰ دقیقه").tag(20)
                        Text("۳۰ دقیقه").tag(30)
                        Text("۶۰ دقیقه").tag(60)
                    }
                    LabeledContent("مأموریت فعال", value: "کار در آلمان")
                    Toggle("یادآوری روزانه", isOn: $notifications)
                }
            case .review:
                Section("روش تمرین") {
                    LabeledContent("الگوریتم مرور", value: "تطبیقی")
                    LabeledContent("جهت ترجمه", value: "هر دو جهت")
                    Toggle("مرور شنیداری", isOn: $notifications)
                }
            case .audio:
                Section("پخش") {
                    LabeledContent("صدای آلمانی", value: "Anna")
                    Slider(value: $audioSpeed, in: 0.5...1.5, step: 0.1) {
                        Text("سرعت پخش")
                    }
                    LabeledContent("سرعت", value: audioSpeed.formatted(.number.precision(.fractionLength(1))) + "×")
                }
            case .ai:
                OpenRouterSettingsForm()
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
                Section("وضعیت") {
                    Label("داده‌ها در این نمونه فقط روی دستگاه هستند", systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)
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
        .navigationTitle(section == .languages ? localization.text(.languageSettings) : section.title)
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
}

private struct OpenRouterSettingsForm: View {
    @Environment(PrototypeAISettings.self) private var settings
    @State private var apiKey = ""
    @State private var statusMessage: String?
    @State private var isTesting = false

    var body: some View {
        @Bindable var settings = settings
        Section("OpenRouter") {
            SecureField(settings.hasAPIKey ? "کلید ذخیره شده؛ برای تغییر دوباره وارد کن" : "OpenRouter API Key", text: $apiKey)
                .textContentType(.password)
                .environment(\.layoutDirection, .leftToRight)
            TextField("Model ID", text: $settings.modelID)
                .environment(\.layoutDirection, .leftToRight)
            Toggle("اجازهٔ ارسال واژه و تنظیمات کارت به OpenRouter", isOn: $settings.cloudConsent)
            Text("کلید فقط در Keychain ذخیره می‌شود. متن درخواست از OpenRouter و Provider مدل انتخاب‌شده عبور می‌کند.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("ذخیرهٔ امن کلید") {
                    do {
                        try settings.saveAPIKey(apiKey)
                        apiKey = ""
                        statusMessage = "کلید در Keychain ذخیره شد."
                    } catch {
                        statusMessage = error.localizedDescription
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("تست اتصال") { testConnection() }
                    .disabled(!settings.hasAPIKey || isTesting)

                if settings.hasAPIKey {
                    Button("حذف کلید", role: .destructive) {
                        settings.deleteAPIKey()
                        statusMessage = "کلید حذف شد."
                    }
                }
            }

            if isTesting { ProgressView("در حال آزمایش…") }
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
                try await OpenRouterClient().testConnection(apiKey: try settings.apiKey())
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
    private static let modelKey = "prototype.openrouter.model"
    private static let consentKey = "prototype.openrouter.cloudConsent"
    private static let keychainService = "ai.linguabrain.openrouter"
    private static let keychainAccount = "api-key"

    var modelID: String {
        didSet { UserDefaults.standard.set(modelID, forKey: Self.modelKey) }
    }
    var cloudConsent: Bool {
        didSet { UserDefaults.standard.set(cloudConsent, forKey: Self.consentKey) }
    }
    private(set) var hasAPIKey: Bool

    init() {
        modelID = UserDefaults.standard.string(forKey: Self.modelKey) ?? "google/gemini-2.5-flash"
        cloudConsent = UserDefaults.standard.bool(forKey: Self.consentKey)
        hasAPIKey = (try? Self.readKey()) != nil
    }

    func saveAPIKey(_ value: String) throws {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw OpenRouterError.missingAPIKey }
        Self.deleteStoredKey()
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: Self.keychainService,
            kSecAttrAccount: Self.keychainAccount,
            kSecValueData: Data(key.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw OpenRouterError.keychain(status) }
        hasAPIKey = true
    }

    func apiKey() throws -> String {
        guard let key = try Self.readKey() else { throw OpenRouterError.missingAPIKey }
        return key
    }

    func deleteAPIKey() {
        Self.deleteStoredKey()
        hasAPIKey = false
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
            throw OpenRouterError.keychain(status)
        }
        return key
    }

    private static func deleteStoredKey() {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: keychainAccount
        ] as CFDictionary)
    }
}

enum OpenRouterError: LocalizedError {
    case missingAPIKey
    case consentRequired
    case invalidResponse
    case service(Int, String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "ابتدا API Key مربوط به OpenRouter را در تنظیمات ذخیره کن."
        case .consentRequired: "در تنظیمات، اجازهٔ ارسال داده به OpenRouter را فعال کن."
        case .invalidResponse: "پاسخ OpenRouter با ساختار کارت سازگار نبود."
        case .service(let status, let message): "OpenRouter (\(status)): \(message)"
        case .keychain(let status): "ذخیره یا خواندن Keychain انجام نشد (\(status))."
        }
    }
}

struct OpenRouterGeneratedCard: Codable, Sendable {
    struct Example: Codable, Sendable {
        let german: String
        let persian: String
    }

    let german: String
    let persianMeaning: String
    let level: String
    let partOfSpeech: String
    let article: String
    let example: Example

    func prototypeWord(domain: String) -> PrototypeWord {
        PrototypeWord(
            german: german,
            persian: persianMeaning,
            article: article.isEmpty ? nil : article,
            level: level,
            partOfSpeech: partOfSpeech,
            example: example.german,
            exampleTranslation: example.persian,
            domain: domain
        )
    }
}

struct OpenRouterClient: Sendable {
    func testConnection(apiKey: String) async throws {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/key")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenRouterError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw OpenRouterError.service(http.statusCode, "کلید یا اتصال معتبر نیست.") }
    }

    func generateCard(word: String, domain: String, model: String, apiKey: String) async throws -> OpenRouterGeneratedCard {
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "german": ["type": "string"],
                "persianMeaning": ["type": "string"],
                "level": ["type": "string"],
                "partOfSpeech": ["type": "string"],
                "article": ["type": "string"],
                "example": [
                    "type": "object",
                    "properties": ["german": ["type": "string"], "persian": ["type": "string"]],
                    "required": ["german", "persian"],
                    "additionalProperties": false
                ]
            ],
            "required": ["german", "persianMeaning", "level", "partOfSpeech", "article", "example"],
            "additionalProperties": false
        ]
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": "You create accurate German-to-Persian language-learning cards. Treat each domain-specific meaning as a separate lexical sense. Return only the requested structured result. Use an empty article for non-nouns."],
                ["role": "user", "content": "Create one card for the German word or phrase '\(word)' using specifically the sense that belongs to the domain '\(domain)'. Do not fall back to its most common meaning when another sense is natural in this domain. Use a concise Persian meaning and one domain-specific German example with an accurate Persian translation."]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "linguabrain_card", "strict": true, "schema": schema]
            ],
            "provider": ["require_parameters": true, "data_collection": "deny"],
            "temperature": 0.2,
            "max_tokens": 700
        ]
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LinguaBrain", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenRouterError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }?["message"] as? String ?? "درخواست ناموفق بود."
            throw OpenRouterError.service(http.statusCode, message)
        }
        let envelope = try JSONDecoder().decode(OpenRouterEnvelope.self, from: data)
        guard let content = envelope.choices.first?.message.content,
              let contentData = content.data(using: .utf8) else { throw OpenRouterError.invalidResponse }
        return try JSONDecoder().decode(OpenRouterGeneratedCard.self, from: contentData)
    }
}

private struct OpenRouterEnvelope: Decodable {
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
