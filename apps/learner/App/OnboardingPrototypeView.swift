import SwiftUI

struct OnboardingPrototypeView: View {
    private static let rules = LearningContentRules.bundled

    @Environment(PrototypeLocalization.self) private var localization
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
                        LabeledContent(localization.text(.explanationLanguage), value: PrototypeAppLanguage.persian.nativeName)
                        LabeledContent(localization.text(.learningLanguage), value: PrototypeAppLanguage.german.nativeName)
                        Picker(localization.text(.currentLevel), selection: $level) {
                            ForEach(Self.rules.onboarding.levels, id: \.self) { level in
                                Text(Self.rules.levels.cefr.contains(level) ? level : localization.localized("onboarding.level.\(level)"))
                            }
                        }
                        Picker(localization.localized("onboarding.goal"), selection: $mission) {
                            ForEach(Self.rules.onboarding.missionKeys, id: \.self) { Text(localization.localized($0)) }
                        }
                    }
                }

                Button(action: {}) {
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
    }
}
