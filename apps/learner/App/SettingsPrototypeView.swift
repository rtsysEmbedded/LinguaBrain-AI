import SwiftUI

struct SettingsPrototypeView: View {
    var body: some View {
        ZStack {
            PrototypeBackground()

            ScrollView {
                LazyVStack(spacing: 18) {
                    profileCard
                    learningSummary
                    settingsGroup(
                        title: "یادگیری و زبان",
                        subtitle: "مسیر آموزشی و شیوهٔ تمرین",
                        items: [
                            .init(title: "زبان‌ها و سطح", detail: "فارسی ← آلمانی · B1", symbol: "character.book.closed.fill", color: .blue, destination: .languages),
                            .init(title: "هدف‌ها و برنامهٔ روزانه", detail: "کار در آلمان · ۲۰ دقیقه", symbol: "target", color: PrototypeTheme.pink, destination: .learning),
                            .init(title: "مرور و تمرین", detail: "مرور تطبیقی · حالت متعادل", symbol: "rectangle.stack.fill", color: .orange, destination: .review),
                            .init(title: "صدا و تلفظ", detail: "صدای آلمانی · سرعت عادی", symbol: "waveform", color: PrototypeTheme.mint, destination: .audio)
                        ]
                    )
                    settingsGroup(
                        title: "هوش مصنوعی و آفلاین",
                        subtitle: "مدل‌ها، دانلودها و هزینه",
                        items: [
                            .init(title: "دستیار هوشمند", detail: "Apple Intelligence · آماده", symbol: "apple.intelligence", color: PrototypeTheme.accent, destination: .ai),
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
        .navigationTitle("تنظیمات")
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
                    Text("یادگیرندهٔ آلمانی · سطح B1")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("همگام‌سازی فقط روی دستگاه", systemImage: "iphone.gen3")
                        .font(.caption)
                        .foregroundStyle(PrototypeTheme.mint)
                }
                Spacer()
                Button("ویرایش") { }
                    .buttonStyle(.bordered)
            }
        }
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
    let item: SettingsItem

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(item.color.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text(item.detail)
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
    @State private var dailyGoal = 20
    @State private var notifications = true
    @State private var offlineOnly = false
    @State private var audioSpeed = 1.0

    var body: some View {
        Form {
            switch section {
            case .languages:
                Section("زبان اصلی") {
                    LabeledContent("زبان رابط", value: "فارسی")
                    LabeledContent("زبان مقصد", value: "آلمانی")
                    LabeledContent("سطح فعلی", value: "B1")
                    LabeledContent("سطح هدف", value: "B2")
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
                Section("روی دستگاه") {
                    Label("Apple Foundation Models", systemImage: "apple.intelligence")
                    Text("در صورت پشتیبانی دستگاه و زبان، اولویت با پردازش خصوصی روی دستگاه است.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("ارائه‌دهندگان اختیاری") {
                    Label("OpenAI / OpenRouter", systemImage: "cloud.fill")
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
        .navigationTitle(section.title)
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsPrototypeView()
    }
    .environment(\.layoutDirection, .rightToLeft)
    .tint(PrototypeTheme.accent)
}
