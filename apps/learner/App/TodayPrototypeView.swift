import SwiftUI

struct TodayPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var energy = 6.0
    @State private var selectedTime = 20

    private var activeWords: [PrototypeWord] {
        store.words(
            sourceLanguageTag: languageSettings.sourceLanguageTag,
            targetLanguageTag: languageSettings.targetLanguageTag
        )
    }

    private var reviewedCount: Int { store.reviewedCount(in: activeWords) }
    private var unreviewedCount: Int { store.unreviewedCount(in: activeWords) }
    private var dueCount: Int { store.dueCount(in: activeWords) }
    private var weakCount: Int { store.weakCount(in: activeWords) }

    private var newCardLimit: Int {
        let energyFactor = 0.45 + (energy / 12)
        let timeCapacity = Double(selectedTime) / 1.8
        return min(unreviewedCount, max(0, min(20, Int((timeCapacity * energyFactor).rounded()))))
    }

    private var learningMode: String {
        if energy <= 3 { return localization.localized("حالت بازیابی") }
        if energy >= 8 { return localization.localized("حالت چالش") }
        return localization.localized("حالت رشد")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                checkIn
                todayPlan
                weakArea
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("امروز")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "bell.badge")
                }
                .accessibilityLabel("اعلان‌ها")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Guten Morgen 👋")
                        .font(.title2.weight(.bold))
                        .environment(\.layoutDirection, .leftToRight)
                    Text("امروز یک قدم کوچک اما پیوسته برداریم.")
                        .foregroundStyle(.white.opacity(0.88))
                }
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 34))
            }

            HStack(spacing: 10) {
                MetricPill(value: "\(dueCount)", label: "مرور", symbol: "arrow.clockwise", color: PrototypeTheme.accent)
                MetricPill(value: "\(unreviewedCount)", label: "جدید", symbol: "sparkles", color: PrototypeTheme.pink)
                MetricPill(value: store.averageStrength(in: activeWords).formatted(.percent.precision(.fractionLength(0))), label: "حافظه", symbol: "brain", color: PrototypeTheme.mint)
            }
            .foregroundStyle(.primary)
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(PrototypeTheme.heroGradient, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: PrototypeTheme.accent.opacity(0.22), radius: 20, y: 10)
    }

    private var checkIn: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeader(title: "امروز چه‌قدر انرژی داری؟", subtitle: "برنامه بر اساس حال امروزت تنظیم می‌شود")
                HStack {
                    Image(systemName: "battery.25percent").foregroundStyle(.secondary)
                    Slider(value: $energy, in: 1...10, step: 1)
                    Image(systemName: "battery.100percent").foregroundStyle(PrototypeTheme.mint)
                    Text(Int(energy), format: .number)
                        .font(.headline.monospacedDigit())
                        .frame(width: 28)
                }
                Picker("زمان آزاد", selection: $selectedTime) {
                    Text("۵ دقیقه").tag(5)
                    Text("۱۰ دقیقه").tag(10)
                    Text("۲۰ دقیقه").tag(20)
                    Text("۳۰ دقیقه").tag(30)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var todayPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "برنامه پیشنهادی", subtitle: "\(localization.minutes(selectedTime)) · \(learningMode)")
            PrototypeCard {
                VStack(spacing: 0) {
                    planRow(symbol: "rectangle.stack.fill", color: PrototypeTheme.accent, title: "مرور هوشمند", detail: localization.reviewSummary(due: dueCount, new: newCardLimit), time: localization.minutes(selectedTime))
                    Divider().padding(.vertical, 12)
                    planRow(symbol: "text.book.closed.fill", color: PrototypeTheme.blue, title: "متن کوتاه", detail: "محیط کار · سطح B1", time: localization.minutes(7))
                    Divider().padding(.vertical, 12)
                    planRow(symbol: "character.bubble.fill", color: PrototypeTheme.pink, title: "ترجمه معکوس", detail: "فارسی به آلمانی", time: localization.minutes(5))
                }
            }

            NavigationLink {
                ReviewPrototypeView(newCardLimit: newCardLimit)
            } label: {
                Label("شروع جلسه امروز", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            NavigationLink {
                ReviewPrototypeView(newCardLimit: newCardLimit, mode: .reverseTranslation)
            } label: {
                Label("تمرین ترجمهٔ معکوس", systemImage: "character.bubble.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func planRow(symbol: String, color: Color, title: String, detail: String, time: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(localization.localized(title)).font(.headline)
                Text(localization.localized(detail)).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text(localization.localized(time)).font(.caption.weight(.medium)).foregroundStyle(.secondary)
        }
    }

    private var weakArea: some View {
        PrototypeCard {
            HStack(spacing: 16) {
                Image(systemName: "ear.badge.waveform")
                    .font(.title2)
                    .foregroundStyle(PrototypeTheme.pink)
                    .frame(width: 52, height: 52)
                    .background(PrototypeTheme.pink.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("پیشنهاد مربی").font(.headline)
                    Text(reviewedCount == 0 ? "وضعیت کاربر ریست است. مرور را شروع کن تا همهٔ بخش‌ها هم‌زمان تغییر کنند." : "تا اینجا \(reviewedCount) واژه مرور شده و \(weakCount) واژه نیاز به تمرین بیشتر دارد.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
