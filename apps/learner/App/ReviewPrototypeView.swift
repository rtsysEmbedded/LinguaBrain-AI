import SwiftUI

struct ReviewPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @State private var revealed = false
    @State private var currentIndex = 0
    @State private var ratings: [PrototypeReviewGrade] = []
    @State private var isComplete = false

    private var words: [PrototypeWord] { store.words }

    private var currentWord: PrototypeWord {
        words[min(currentIndex, words.count - 1)]
    }

    private var progress: Double {
        guard !words.isEmpty else { return 0 }
        return isComplete ? 1 : Double(currentIndex) / Double(words.count)
    }

    var body: some View {
        Group {
            if isComplete {
                completionView
            } else {
                reviewView
            }
        }
        .padding()
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .background(PrototypeBackground())
        .navigationTitle("مرور هوشمند")
    }

    private var reviewView: some View {
        VStack(spacing: 22) {
            HStack {
                Text("مرور \(currentIndex + 1) از \(words.count)")
                    .font(.subheadline.weight(.medium))
                ProgressView(value: progress)
                    .tint(PrototypeTheme.accent)
                    .animation(.snappy, value: currentIndex)
                Text("آفلاین")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(spacing: 22) {
                Text("این واژه به فارسی یعنی چه؟")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(currentWord.german)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.center)
                    .contentTransition(.numericText())

                if revealed {
                    Divider()
                    Text(currentWord.persian)
                        .font(.title.bold())
                    GermanText(text: currentWord.example, font: .title3)
                    Text(currentWord.exampleTranslation)
                        .foregroundStyle(.secondary)
                } else {
                    Button("نمایش پاسخ") {
                        withAnimation(.snappy) { revealed = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.space, modifiers: [])
                }
            }
            .id(currentWord.id)
            .padding(28)
            .frame(maxWidth: 650, minHeight: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PrototypeTheme.accent.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: PrototypeTheme.accent.opacity(0.12), radius: 24, y: 12)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))

            if revealed {
                VStack(spacing: 10) {
                    Text("پاسخت چطور بود؟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                    ForEach(PrototypeReviewGrade.allCases) { rating in
                            ratingButton(rating)
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
        }
    }

    private var completionView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(PrototypeTheme.mint)

            VStack(spacing: 7) {
                Text("مرور امروز تمام شد")
                    .font(.largeTitle.bold())
                Text("\(ratings.count) کارت را مرور کردی")
                    .foregroundStyle(.secondary)
            }

            PrototypeCard {
                VStack(spacing: 14) {
                    ForEach(PrototypeReviewGrade.allCases) { rating in
                        HStack {
                            Label(rating.title, systemImage: rating.symbol)
                                .foregroundStyle(rating.color)
                            Spacer()
                            Text("\(ratings.filter { $0 == rating }.count)")
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
            }
            .frame(maxWidth: 440)

            Button("مرور دوباره") {
                resetSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
    }

    private func ratingButton(_ rating: PrototypeReviewGrade) -> some View {
        Button {
            submit(rating)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: rating.symbol)
                Text(rating.title)
                    .font(.caption.weight(.semibold))
                Text(rating.previewInterval)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(rating.color)
        .accessibilityLabel("\(rating.title)، مرور بعدی \(rating.previewInterval)")
    }

    private func submit(_ rating: PrototypeReviewGrade) {
        guard revealed, !isComplete else { return }
        ratings.append(rating)
        store.record(rating, for: currentWord)

        withAnimation(.snappy) {
            if currentIndex + 1 < words.count {
                currentIndex += 1
                revealed = false
            } else {
                isComplete = true
            }
        }
    }

    private func resetSession() {
        withAnimation(.snappy) {
            currentIndex = 0
            ratings = []
            revealed = false
            isComplete = false
        }
    }
}

#Preview("Interactive Review") {
    NavigationStack {
        ReviewPrototypeView()
    }
    .environment(PrototypeStore())
    .environment(\.layoutDirection, .rightToLeft)
    .tint(PrototypeTheme.accent)
}
