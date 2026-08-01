import SwiftUI

struct OnboardingPrototypeView: View {
    @State private var level = "B1"
    @State private var mission = "کار در آلمان"

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
                    Text("به LinguaBrain خوش آمدی")
                        .font(.largeTitle.bold())
                    Text("مربی زبان شخصی که هر روز با تو سازگار می‌شود")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                PrototypeCard {
                    VStack(spacing: 18) {
                        LabeledContent("زبان توضیحات", value: "فارسی")
                        LabeledContent("زبان یادگیری", value: "Deutsch")
                        Picker("سطح فعلی", selection: $level) {
                            ForEach(["مبتدی", "A1", "A2", "B1", "B2"], id: \.self) { Text($0) }
                        }
                        Picker("هدف", selection: $mission) {
                            ForEach(["مکالمه روزمره", "کار در آلمان", "آزمون Goethe", "سفر"], id: \.self) { Text($0) }
                        }
                    }
                }

                Button(action: {}) {
                    Text("ساخت مسیر یادگیری من")
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
        .navigationTitle("راه‌اندازی")
    }
}
