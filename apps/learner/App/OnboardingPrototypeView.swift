import SwiftUI

struct OnboardingPrototypeView: View {
    private static let beginnerLevel = "beginner"
    private static let levels = [beginnerLevel, "A1", "A2", "B1", "B2"]
    private static let missionKeys = [
        "onboarding.mission.everyday", "onboarding.mission.work", "onboarding.mission.goethe", "onboarding.mission.travel"
    ]

    @Environment(PrototypeLocalization.self) private var localization
    @State private var level = "B1"
    @State private var mission = "onboarding.mission.work"

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
                            ForEach(Self.levels, id: \.self) { level in
                                Text(level == Self.beginnerLevel ? localization.localized("onboarding.level.beginner") : level)
                            }
                        }
                        Picker(localization.localized("onboarding.goal"), selection: $mission) {
                            ForEach(Self.missionKeys, id: \.self) { Text(localization.localized($0)) }
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
