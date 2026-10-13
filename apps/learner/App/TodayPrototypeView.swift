import SwiftUI
import LinguaBrainDomain
import LinguaBrainApplication

struct TodayPrototypeView: View {
    /// Feature 004 practice composition; `nil` until the practice store has
    /// started, in which case the skill routes explain that storage is not
    /// ready.
    let practiceComposition: PracticeComposition?

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @Environment(PrototypeAISettings.self) private var aiSettings
    /// Weakest available skill with evidence in the active pair, if any.
    @State private var recommendedSkill: PracticeSkill?
    @State private var energy = LearningContentRules.bundled.dailyPlan.defaultEnergy
    // A new day starts from the learner's daily goal (Settings).
    @State private var selectedTime = LearningContentRules.bundled.dailyPlan.availableMinutes(
        forDailyGoal: PrototypeLearnerProfile.storedDailyGoalMinutes()
    )
    @State private var motivation = LearningContentRules.bundled.dailyPlan.defaultMotivation
    @State private var selectedMode = LearningSessionMode.balanced.rawValue
    @State private var selectedDomain = Self.allDomains
    @State private var customDomains = PrototypeDomainCatalog.customDomains
    @State private var didLoadDailyState = false
    @State private var dailyStateCapturedAt: Date?

    /// Picker tag for "all topics"; never stored as a learner domain.
    private static let allDomains = "today.domain.all"
    private static let availableMinuteOptions = LearningContentRules.bundled.dailyPlan.availableMinuteOptions

    init(practiceComposition: PracticeComposition? = nil) {
        self.practiceComposition = practiceComposition
    }

    private var activeWords: [PrototypeWord] {
        let words = store.words(
            sourceLanguageTag: languageSettings.sourceLanguageTag,
            targetLanguageTag: languageSettings.targetLanguageTag
        )
        return selectedDomain == Self.allDomains ? words : words.filter { $0.domain == selectedDomain }
    }

    private var reviewedCount: Int { store.reviewedCount(in: activeWords) }
    private var unreviewedCount: Int { store.unreviewedCount(in: activeWords) }
    private var dueCount: Int { store.dueCount(in: activeWords) }
    private var weakCount: Int { store.weakCount(in: activeWords) }

    private var newCardLimit: Int {
        min(unreviewedCount, LearningContentRules.bundled.dailyPlan.newCardCount(
            energy: energy,
            availableMinutes: selectedTime,
            motivation: motivation,
            modeRawValue: selectedMode
        ))
    }

    private var learningMode: String {
        let plan = LearningContentRules.bundled.dailyPlan
        if energy <= plan.recoveryEnergyAtMost { return localization.localized("today.mode.recovery") }
        if energy >= plan.challengeEnergyAtLeast { return localization.localized("today.mode.challenge") }
        return localization.localized("today.mode.growth")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hero
                checkIn
                todayPlan
                skillPractice
                weakArea
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized("today.title"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {}) {
                    Image(systemName: "bell.badge")
                }
                .accessibilityLabel(localization.localized("today.notifications"))
            }
        }
        .onAppear {
            customDomains = PrototypeDomainCatalog.customDomains
            loadDailyStateIfNeeded()
        }
        .onChange(of: energy) { _, _ in
            persistDailyState()
        }
        .onChange(of: selectedTime) { _, _ in
            persistDailyState()
        }
        .onChange(of: motivation) { _, _ in
            persistDailyState()
        }
        .onChange(of: selectedMode) { _, _ in
            persistDailyState()
        }
    }

    private func loadDailyStateIfNeeded() {
        guard !didLoadDailyState else { return }
        if let state = store.dailyLearningState() {
            if !state.isStale {
                energy = state.energy
                selectedTime = state.availableMinutes
                motivation = state.motivation
                selectedMode = state.modeRawValue
                dailyStateCapturedAt = state.capturedAt
            }
        }
        didLoadDailyState = true
    }

    private func persistDailyState() {
        guard didLoadDailyState else { return }
        store.saveDailyLearningState(
            energy: energy,
            availableMinutes: selectedTime,
            motivation: motivation,
            modeRawValue: selectedMode
        )
        dailyStateCapturedAt = .now
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(localization.localized("today.greeting"))
                        .font(.title2.weight(.bold))
                        .environment(\.layoutDirection, .leftToRight)
                    Text(localization.localized("today.encouragement"))
                        .foregroundStyle(.white.opacity(0.88))
                }
                Spacer()
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 34))
            }

            HStack(spacing: 10) {
                MetricPill(value: "\(dueCount)", label: "today.metric.review", symbol: "arrow.clockwise", color: PrototypeTheme.accent)
                MetricPill(value: "\(unreviewedCount)", label: "today.metric.new", symbol: "sparkles", color: PrototypeTheme.pink)
                MetricPill(value: store.averageStrength(in: activeWords).formatted(.percent.precision(.fractionLength(0))), label: "today.metric.memory", symbol: "brain", color: PrototypeTheme.mint)
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
                SectionHeader(title: "today.energyQuestion", subtitle: "today.energySubtitle")
                HStack {
                    Image(systemName: "battery.25percent").foregroundStyle(.secondary)
                    Slider(value: $energy, in: 1...10, step: 1)
                    Image(systemName: "battery.100percent").foregroundStyle(PrototypeTheme.mint)
                    Text(Int(energy), format: .number)
                        .font(.headline.monospacedDigit())
                        .frame(width: 28)
                }
                Picker(localization.localized("today.availableTime"), selection: $selectedTime) {
                    ForEach(Self.availableMinuteOptions, id: \.self) { minutes in
                        Text(localization.minutesLong(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                Picker(localization.localized("daily.motivation"), selection: $motivation) {
                    Text(localization.localized("daily.motivation.low")).tag(1)
                    Text(localization.localized("daily.motivation.normal")).tag(3)
                    Text(localization.localized("daily.motivation.high")).tag(5)
                }
                .pickerStyle(.segmented)
                Picker(localization.localized("daily.mode"), selection: $selectedMode) {
                    Text(localization.localized("daily.mode.light")).tag(LearningSessionMode.lightReview.rawValue)
                    Text(localization.localized("daily.mode.balanced")).tag(LearningSessionMode.balanced.rawValue)
                    Text(localization.localized("daily.mode.challenge")).tag(LearningSessionMode.challenge.rawValue)
                }
                .pickerStyle(.segmented)
                Picker(localization.localized("today.domainPicker"), selection: $selectedDomain) {
                    Text(localization.localized(Self.allDomains)).tag(Self.allDomains)
                    ForEach(customDomains, id: \.self) { Text($0).tag($0) }
                }
                .onAppear { customDomains = PrototypeDomainCatalog.customDomains }
            }
        }
    }

    private var todayPlan: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "today.suggestedReview", subtitle: localization.formatted("today.dueCardsSubtitle", localization.minutes(selectedTime)))
            PrototypeCard {
                planRow(
                    symbol: "rectangle.stack.fill",
                    color: PrototypeTheme.accent,
                    title: "today.reviewCards",
                    detail: localization.reviewSummary(due: dueCount, new: newCardLimit),
                    time: localization.minutes(selectedTime)
                )
            }

            NavigationLink {
                ReviewPrototypeView(newCardLimit: newCardLimit, mode: .recognition)
            } label: {
                Label(localization.localized("today.startReview"), systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
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
                    Text(localization.localized("coachSuggestion")).font(.headline)
                    Text(localization.coachMessage(reviewed: reviewedCount, weak: weakCount))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var skillPractice: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "skillPractice.title",
                subtitle: "skillPractice.subtitle"
            )
            PrototypeCard {
                VStack(spacing: 10) {
                    if let recommendedSkill {
                        let mode = PrototypeSkillPracticeMode(practiceSkill: recommendedSkill)
                        NavigationLink {
                            SkillPracticeEntryView(skill: recommendedSkill, composition: practiceComposition)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(PrototypeTheme.pink)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localization.localized("skillPractice.recommendation.title"))
                                        .font(.subheadline.weight(.semibold))
                                    Text(localization.formatted("skillPractice.recommendation.detail", localization.localized(mode.titleKey)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    ForEach(PrototypeSkillPracticeMode.allCases) { practiceMode in
                        NavigationLink {
                            SkillPracticeEntryView(skill: practiceMode.practiceSkill, composition: practiceComposition)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: practiceMode.symbol)
                                    .foregroundStyle(PrototypeTheme.accent)
                                    .frame(width: 32)
                                Text(localization.localized(practiceMode.titleKey))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if practiceMode != PrototypeSkillPracticeMode.allCases.last {
                            Divider()
                        }
                    }
                }
            }
        }
        .task(id: "\(languageSettings.sourceLanguageTag)>\(languageSettings.targetLanguageTag)>\(store.words.count)") {
            await loadRecommendation()
        }
    }

    /// Recommends the available skill with the lowest evidenced mastery.
    /// Skills without evidence are not called weak.
    private func loadRecommendation() async {
        guard let practiceComposition else {
            recommendedSkill = nil
            return
        }
        let probe = PracticeCapabilityProbe(
            composition: practiceComposition,
            cards: PrototypeStorePracticeCards(store: store),
            aiSettings: aiSettings,
            sourceLanguage: languageSettings.sourceLanguageTag,
            targetLanguage: languageSettings.targetLanguageTag,
            hasReviewedGrammarContent: false
        )
        let available = Set(PracticeSkill.allCases.filter { probe.availability(for: $0).isAvailable })
        let summaries = (try? await probe.progress()) ?? []
        recommendedSkill = PracticeProgressCalculator.weakestSkill(summaries, available: available)
    }
}
