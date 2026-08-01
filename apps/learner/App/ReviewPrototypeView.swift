import SwiftUI

struct ReviewPrototypeView: View {
    @State private var revealed = false
    @State private var progress = 0.35

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Text("مرور ۴ از ۱۲").font(.subheadline.weight(.medium))
                ProgressView(value: progress).tint(PrototypeTheme.accent)
                Text("۸ دقیقه").font(.caption).foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(spacing: 22) {
                Text("این واژه به فارسی یعنی چه؟")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("die Entscheidung")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.center)

                if revealed {
                    Divider()
                    Text("تصمیم").font(.title.bold())
                    GermanText(text: "Wir treffen morgen eine Entscheidung.", font: .title3)
                    Text("ما فردا تصمیم می‌گیریم.").foregroundStyle(.secondary)
                } else {
                    Button("نمایش پاسخ") {
                        withAnimation(.snappy) { revealed = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(28)
            .frame(maxWidth: 650, minHeight: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PrototypeTheme.accent.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: PrototypeTheme.accent.opacity(0.12), radius: 24, y: 12)

            if revealed {
                HStack(spacing: 10) {
                    ratingButton("دوباره", symbol: "arrow.counterclockwise", color: .red)
                    ratingButton("سخت", symbol: "flame.fill", color: .orange)
                    ratingButton("خوب", symbol: "checkmark", color: PrototypeTheme.blue)
                    ratingButton("آسان", symbol: "bolt.fill", color: PrototypeTheme.mint)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .background(PrototypeBackground())
        .navigationTitle("مرور هوشمند")
    }

    private func ratingButton(_ title: String, symbol: String, color: Color) -> some View {
        Button(action: {}) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                Text(title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(color)
    }
}
