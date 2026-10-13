import SwiftUI
import LinguaBrainDomain

struct ProgressPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var isResetConfirmationPresented = false
    @State private var persistenceError: String?

    private var activeWords: [PrototypeWord] {
        store.words(
            sourceLanguageTag: languageSettings.sourceLanguageTag,
            targetLanguageTag: languageSettings.targetLanguageTag
        )
    }
    private var reviewedCount: Int { store.reviewedCount(in: activeWords) }
    private var averageStrength: Double { store.averageStrength(in: activeWords) }
    private var totalReviews: Int { store.totalReviews(in: activeWords) }
    private var recognitionMastery: Double { averageMastery(mode: .recognition) }
    private var recallMastery: Double { averageMastery(mode: .reverseTranslation) }
    private var listeningMastery: Double { averageSkillMastery(.listening) }
    private var writingMastery: Double { averageSkillMastery(.writing) }
    private var productionMastery: Double { averageSkillMastery(.production) }
    private var grammarMastery: Double { averageSkillMastery(.grammar) }
    private var week: [Int] { [0, 0, 0, 0, 0, 0, min(totalReviews, 50)] }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                summary
                weeklyActivity
                skills
                insight
                resetControl
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle("پیشرفت")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("ریست وضعیت", systemImage: "arrow.counterclockwise") {
                    isResetConfirmationPresented = true
                }
            }
        }
        .confirmationDialog(
            "همهٔ سابقه‌های مرور پاک شوند؟",
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("پاک‌کردن کامل سابقه", role: .destructive) {
                resetProgress()
            }
            Button("انصراف", role: .cancel) {}
        } message: {
            Text("این کار تمام واژه‌ها را به حالت اولیه برمی‌گرداند و قابل بازگشت نیست.")
        }
        .alert("خطای ذخیره‌سازی", isPresented: persistenceErrorBinding) {
            Button("باشه", role: .cancel) {
                persistenceError = nil
                store.clearPersistenceError()
            }
        } message: {
            Text(persistenceError ?? "خطای ناشناخته")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("رشد این ماه").font(.title2.bold()).foregroundStyle(.white)
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("\(reviewedCount)").font(.largeTitle.bold())
                    Text("واژه مرورشده").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(averageStrength.formatted(.percent.precision(.fractionLength(0)))).font(.largeTitle.bold())
                    Text("قدرت میانگین").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(totalReviews)").font(.largeTitle.bold())
                    Text("کل پاسخ‌ها").font(.caption).foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(22)
        .foregroundStyle(.white)
        .background(PrototypeTheme.heroGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var weeklyActivity: some View {
        PrototypeCard {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "فعالیت هفتگی", subtitle: "دقیقه مطالعه در هر روز")
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(index == 5 ? PrototypeTheme.heroGradient : LinearGradient(colors: [PrototypeTheme.accent.opacity(0.36)], startPoint: .top, endPoint: .bottom))
                                .frame(height: CGFloat(value) * 2.2)
                            Text(["ش", "ی", "د", "س", "چ", "پ", "ج"][index])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120, alignment: .bottom)
            }
        }
    }

    private var skills: some View {
        PrototypeCard {
            VStack(spacing: 17) {
                SectionHeader(title: "نقشه مهارت‌ها", subtitle: "تسلط واقعی، نه فقط تعداد واژه‌ها")
                SkillProgressRow(label: "تشخیص واژه", value: recognitionMastery, color: PrototypeTheme.mint)
                SkillProgressRow(label: "یادآوری فعال", value: recallMastery, color: PrototypeTheme.accent)
                SkillProgressRow(label: "شنیداری", value: listeningMastery, color: PrototypeTheme.pink)
                SkillProgressRow(label: "نوشتن", value: writingMastery, color: PrototypeTheme.blue)
                SkillProgressRow(label: "استفاده در جمله", value: productionMastery, color: .orange)
                SkillProgressRow(label: "گرامر", value: grammarMastery, color: .purple)
            }
        }
    }

    private var insight: some View {
        PrototypeCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 5) {
                    Text("بینش این هفته").font(.headline)
                    Text(insightDescription)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var resetControl: some View {
        PrototypeCard {
            HStack(spacing: 14) {
                Image(systemName: "testtube.2")
                    .font(.title2)
                    .foregroundStyle(PrototypeTheme.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("حالت آزمایش عملکرد").font(.headline)
                    Text(resetDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("ریست") {
                    isResetConfirmationPresented = true
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }

    private func resetProgress() {
        guard store.reset() else {
            persistenceError = store.lastPersistenceError
            return
        }
    }

    private func averageMastery(mode: PrototypeReviewMode) -> Double {
        let reviewed = activeWords.filter { store.reviewCount(for: $0, mode: mode) > 0 }
        guard !reviewed.isEmpty else { return 0 }
        return reviewed.reduce(0) { $0 + store.mastery(for: $1, mode: mode) } / Double(reviewed.count)
    }

    private func averageSkillMastery(_ skill: LearningSkill) -> Double {
        let attempted = activeWords.filter { store.skillAttemptCount(for: $0, skill: skill) > 0 }
        guard !attempted.isEmpty else { return 0 }
        return attempted.reduce(0) { $0 + store.mastery(for: $1, skill: skill) } / Double(attempted.count)
    }

    private var insightDescription: String {
        switch (localization.language, reviewedCount == 0) {
        case (.english, true): "No data has been recorded yet. This section will update after you review cards."
        case (.german, true): "Es wurden noch keine Daten erfasst. Dieser Bereich wird nach dem Wiederholen aktualisiert."
        case (.persian, true): "هنوز هیچ داده‌ای ثبت نشده است. پس از مرور، این بخش تغییر می‌کند."
        case (.english, false): "Current data comes from \(totalReviews) answers across \(reviewedCount) words; listening and writing have no data yet."
        case (.german, false): "Die aktuellen Daten stammen aus \(totalReviews) Antworten zu \(reviewedCount) Wörtern; für Hören und Schreiben gibt es noch keine Daten."
        case (.persian, false): "داده‌های فعلی از \(totalReviews) پاسخ روی \(reviewedCount) واژه ساخته شده‌اند؛ شنیداری و نوشتن هنوز داده ندارند."
        }
    }

    private var resetDescription: String {
        switch localization.language {
        case .english: "Return every word to its initial, unreviewed state."
        case .german: "Alle Wörter in ihren ursprünglichen, nicht wiederholten Zustand zurücksetzen."
        case .persian: "همهٔ واژه‌ها را به وضعیت اولیه و بدون مرور برگردان."
        }
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )
    }
}
