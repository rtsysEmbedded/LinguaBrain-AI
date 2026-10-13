import SwiftUI
import LinguaBrainApplication
import LinguaBrainDomain

struct ProgressPrototypeView: View {
    /// Source of practice-skill evidence (GRDB); `nil` until the practice
    /// store has started.
    let practiceComposition: PracticeComposition?

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @Environment(PrototypeAISettings.self) private var aiSettings
    @State private var isResetConfirmationPresented = false
    @State private var persistenceError: String?
    /// Evidence-based mastery per practice skill for the active pair.
    @State private var practiceProgress: [PracticeSkill: PracticeSkillProgress] = [:]

    init(practiceComposition: PracticeComposition? = nil) {
        self.practiceComposition = practiceComposition
    }

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
        .navigationTitle(localization.localized("progress.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(localization.localized("progress.resetStatus"), systemImage: "arrow.counterclockwise") {
                    isResetConfirmationPresented = true
                }
            }
        }
        .confirmationDialog(
            localization.localized("progress.resetConfirmTitle"),
            isPresented: $isResetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(localization.localized("progress.resetConfirmAction"), role: .destructive) {
                resetProgress()
            }
            Button(localization.localized("common.cancel"), role: .cancel) {}
        } message: {
            Text(localization.localized("progress.resetConfirmMessage"))
        }
        .alert(localization.localized("common.storageError"), isPresented: persistenceErrorBinding) {
            Button(localization.localized("common.ok"), role: .cancel) {
                persistenceError = nil
                store.clearPersistenceError()
            }
        } message: {
            Text(persistenceError ?? localization.localized("common.unknownError"))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(localization.localized("progress.monthGrowth")).font(.title2.bold()).foregroundStyle(.white)
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("\(reviewedCount)").font(.largeTitle.bold())
                    Text(localization.localized("progress.reviewedWords")).font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text(averageStrength.formatted(.percent.precision(.fractionLength(0)))).font(.largeTitle.bold())
                    Text(localization.localized("progress.averageStrength")).font(.caption).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                VStack(alignment: .leading) {
                    Text("\(totalReviews)").font(.largeTitle.bold())
                    Text(localization.localized("progress.totalAnswers")).font(.caption).foregroundStyle(.white.opacity(0.8))
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
                SectionHeader(title: "progress.weeklyActivity", subtitle: "progress.weeklyActivitySubtitle")
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(week.enumerated()), id: \.offset) { index, value in
                        VStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(index == 5 ? PrototypeTheme.heroGradient : LinearGradient(colors: [PrototypeTheme.accent.opacity(0.36)], startPoint: .top, endPoint: .bottom))
                                .frame(height: CGFloat(value) * 2.2)
                            Text(weekdayInitials[index])
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
                SectionHeader(title: "progress.skillMap", subtitle: "progress.skillMapSubtitle")
                SkillProgressRow(label: "progress.skill.recognition", value: recognitionMastery, color: PrototypeTheme.mint)
                SkillProgressRow(label: "progress.skill.recall", value: recallMastery, color: PrototypeTheme.accent)
                SkillProgressRow(label: "progress.skill.listening", value: practiceProgress[.listening]?.averageMastery, color: PrototypeTheme.pink)
                SkillProgressRow(label: "progress.skill.writing", value: practiceProgress[.writing]?.averageMastery, color: PrototypeTheme.blue)
                SkillProgressRow(label: "progress.skill.production", value: practiceProgress[.speaking]?.averageMastery, color: .orange)
                SkillProgressRow(label: "progress.skill.grammar", value: practiceProgress[.grammar]?.averageMastery, color: .purple)
            }
        }
        .task(id: "\(languageSettings.sourceLanguageTag)>\(languageSettings.targetLanguageTag)>\(store.words.count)") {
            await loadPracticeProgress()
        }
    }

    private func loadPracticeProgress() async {
        guard let practiceComposition else {
            practiceProgress = [:]
            return
        }
        let probe = PracticeCapabilityProbe(
            composition: practiceComposition,
            cards: PrototypeStorePracticeCards(store: store),
            aiSettings: aiSettings,
            sourceLanguage: languageSettings.sourceLanguageTag,
            targetLanguage: languageSettings.targetLanguageTag
        )
        let summaries = (try? await probe.progress()) ?? []
        practiceProgress = Dictionary(uniqueKeysWithValues: summaries.map { ($0.skill, $0) })
    }

    private var insight: some View {
        PrototypeCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 5) {
                    Text(localization.localized("progress.weeklyInsight")).font(.headline)
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
                    Text(localization.localized("progress.testMode")).font(.headline)
                    Text(resetDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localization.localized("progress.reset")) {
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

    private var insightDescription: String {
        reviewedCount == 0
            ? localization.localized("progress.insight.empty")
            : localization.formatted("progress.insight.summary", "\(totalReviews)", "\(reviewedCount)")
    }

    private var resetDescription: String {
        localization.localized("progress.resetDescription")
    }

    /// Very short weekday symbols in the interface language, Saturday first to
    /// match the order of `week`.
    private var weekdayInitials: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = localization.language.locale
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return Array(symbols[6...] + symbols[..<6])
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )
    }
}
