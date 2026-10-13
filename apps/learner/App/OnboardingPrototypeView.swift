import SwiftUI

struct OnboardingPrototypeView: View {
    private static let rules = LearningContentRules.bundled

    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @Environment(PrototypeLearnerProfile.self) private var learnerProfile
    @Environment(PrototypeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var level = LearningContentRules.bundled.onboarding.defaultLevel
    @State private var mission = LearningContentRules.bundled.onboarding.defaultMissionKey

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                Spacer(minLength: 20)
                ZStack {
                    Circle().fill(PrototypeTheme.heroGradient)
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                }
                .frame(width: 104, height: 104)
                .shadow(color: PrototypeTheme.accent.opacity(0.24), radius: 22, y: 10)

                VStack(spacing: 8) {
                    Text(localization.localized("onboarding.welcome"))
                        .font(.largeTitle.bold())
                    Text(localization.localized("onboarding.tagline"))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                PrototypeCard {
                    VStack(spacing: 18) {
                        LabeledContent(localization.text(.explanationLanguage), value: languageName(languageSettings.sourceLanguageTag))
                        LabeledContent(localization.text(.learningLanguage), value: languageName(languageSettings.targetLanguageTag))
                        Picker(localization.text(.currentLevel), selection: $level) {
                            ForEach(Self.rules.onboarding.levels, id: \.self) { level in
                                Text(localization.levelName(level))
                            }
                        }
                        Picker(localization.localized("onboarding.goal"), selection: $mission) {
                            ForEach(Self.rules.onboarding.missionKeys, id: \.self) { Text(localization.localized($0)) }
                        }
                    }
                }

                Button(action: createPath) {
                    Text(localization.localized("onboarding.createPath"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(PrototypeBackground())
        .navigationTitle(localization.localized("onboarding.title"))
        .onAppear {
            level = learnerProfile.currentLevel
            mission = store.activeMissionKey
        }
    }

    private func languageName(_ tag: String) -> String {
        PrototypeAppLanguage(rawValue: tag)?.nativeName ?? tag
    }

    /// Saves the chosen level and goal as the learner profile.
    private func createPath() {
        learnerProfile.currentLevel = level
        store.setActiveMissionKey(mission)
        learnerProfile.onboardingCompleted = true
        dismiss()
    }

}
