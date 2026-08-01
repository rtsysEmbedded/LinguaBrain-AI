import SwiftUI

struct SettingsPrototypeView: View {
    @State private var dailyGoal = 20
    @State private var offlineOnly = false
    @State private var notifications = true

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(PrototypeTheme.heroGradient)
                        .frame(width: 58, height: 58)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                        }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("سعید رضایی").font(.headline)
                        Text("فارسی ← آلمانی · B1").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("یادگیری") {
                Picker("هدف روزانه", selection: $dailyGoal) {
                    Text("۱۰ دقیقه").tag(10)
                    Text("۲۰ دقیقه").tag(20)
                    Text("۳۰ دقیقه").tag(30)
                    Text("۶۰ دقیقه").tag(60)
                }
                LabeledContent("ماموریت فعال", value: "کار در آلمان")
                LabeledContent("سطح هدف", value: "B2")
                Toggle("یادآوری روزانه", isOn: $notifications)
            }

            Section("هوش مصنوعی") {
                LabeledContent("مدل روی دستگاه", value: "در حال بررسی")
                LabeledContent("مدل ابری", value: "تنظیم نشده")
                Toggle("فقط حالت آفلاین", isOn: $offlineOnly)
                NavigationLink("تنظیم ارائه‌دهنده AI") {
                    AISettingsPrototypeView()
                }
            }

            Section("داده و حریم خصوصی") {
                Label("داده‌ها فقط روی این دستگاه هستند", systemImage: "lock.shield.fill")
                    .foregroundStyle(PrototypeTheme.mint)
                Button("خروجی گرفتن از داده‌ها", action: {})
                Button("حذف تمام داده‌ها", role: .destructive, action: {})
            }

            Section("نمونه طراحی") {
                NavigationLink("نمایش راه‌اندازی اولیه") {
                    OnboardingPrototypeView()
                }
                LabeledContent("نسخه", value: "Visual Prototype 0.1")
            }
        }
        .navigationTitle("تنظیمات")
    }
}

private struct AISettingsPrototypeView: View {
    var body: some View {
        Form {
            Section("مسیر پیشنهادی") {
                Label("Apple Foundation Models", systemImage: "apple.intelligence")
                Text("در صورت پشتیبانی دستگاه و زبان استفاده می‌شود.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("جایگزین‌ها") {
                Label("OpenAI / OpenRouter", systemImage: "cloud.fill")
                Label("LM Studio / Ollama", systemImage: "desktopcomputer")
            }
        }
        .navigationTitle("هوش مصنوعی")
    }
}
