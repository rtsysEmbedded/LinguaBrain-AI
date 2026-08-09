import SwiftUI

struct ReviewPrototypeView: View {
    @Environment(PrototypeStore.self) private var store
    @State private var revealed = false
    @State private var queue: [UUID] = []
    @State private var currentWordID: UUID?
    @State private var ratings: [PrototypeReviewGrade] = []
    @State private var waitingUntil: Date?
    @State private var isComplete = false
    @State private var hasStarted = false
    @State private var persistenceError: String?

    private var currentWord: PrototypeWord? {
        guard let currentWordID else { return nil }
        return store.words.first { $0.id == currentWordID }
    }

    private var progress: Double {
        Double(store.reviewedCount) / Double(max(store.words.count, 1))
    }

    var body: some View {
        Group {
            if !hasStarted {
                ProgressView("آماده‌کردن صف مرور…")
            } else if isComplete {
                completionView
            } else if let waitingUntil {
                waitingView(until: waitingUntil)
            } else if let currentWord {
                reviewView(word: currentWord)
            }
        }
        .padding()
        .frame(maxWidth: 820)
        .frame(maxWidth: .infinity)
        .background(PrototypeBackground())
        .navigationTitle("مرور هوشمند")
        .task {
            guard !hasStarted else { return }
            startSession()
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

    private func reviewView(word: PrototypeWord) -> some View {
        VStack(spacing: 22) {
            HStack {
                Text("\(ratings.count) پاسخ ثبت‌شده")
                    .font(.subheadline.weight(.medium))
                ProgressView(value: progress)
                    .tint(PrototypeTheme.accent)
                Text("\(queue.count) در صف")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(spacing: 22) {
                Text("این واژه به فارسی یعنی چه؟")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(word.german)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .environment(\.layoutDirection, .leftToRight)
                    .multilineTextAlignment(.center)

                if revealed {
                    Divider()
                    Text(word.persian).font(.title.bold())
                    GermanText(text: word.example, font: .title3)
                    Text(word.exampleTranslation).foregroundStyle(.secondary)
                } else {
                    Button("نمایش پاسخ") {
                        withAnimation(.snappy) { revealed = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.space, modifiers: [])
                }
            }
            .id(word.id)
            .padding(28)
            .frame(maxWidth: 650, minHeight: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PrototypeTheme.accent.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: PrototypeTheme.accent.opacity(0.12), radius: 24, y: 12)

            if revealed {
                VStack(spacing: 10) {
                    Text("پاسخت چطور بود؟")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(PrototypeReviewGrade.allCases) { rating in
                            ratingButton(rating, word: word)
                        }
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Spacer()
        }
    }

    private func waitingView(until date: Date) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(PrototypeTheme.accent)
            Text("کارت‌های سخت در زمان مقرر برمی‌گردند")
                .font(.title2.bold())
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int(date.timeIntervalSince(context.date).rounded(.up)))
                Text("کارت بعدی تا \(seconds) ثانیهٔ دیگر")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text("می‌توانی این صفحه را باز نگه داری؛ صف به‌طور خودکار ادامه پیدا می‌کند.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .task(id: date) {
            let delay = max(0, date.timeIntervalSinceNow)
            try? await Task.sleep(for: .seconds(delay))
            selectNextCard()
        }
    }

    private var completionView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(PrototypeTheme.mint)
            Text("مرورهای فعلی تمام شد").font(.largeTitle.bold())
            Text("\(ratings.count) پاسخ در این جلسه ثبت شد")
                .foregroundStyle(.secondary)

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

            Button("بررسی دوبارهٔ صف") {
                startSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
    }

    private func ratingButton(_ rating: PrototypeReviewGrade, word: PrototypeWord) -> some View {
        Button {
            submit(rating, for: word)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: rating.symbol)
                Text(rating.title).font(.caption.weight(.semibold))
                Text(rating.previewInterval).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(rating.color)
        .accessibilityLabel("\(rating.title)، مرور بعدی \(rating.previewInterval)")
    }

    private func startSession() {
        queue = store.words.filter { word in
            store.isReviewable(word) || store.lastGrade(for: word)?.repeatsInCurrentSession == true
        }.map(\.id)
        currentWordID = nil
        waitingUntil = nil
        ratings = []
        isComplete = false
        hasStarted = true
        selectNextCard()
    }

    private func submit(_ rating: PrototypeReviewGrade, for word: PrototypeWord) {
        guard revealed, currentWordID == word.id else { return }
        guard store.record(rating, for: word) else {
            persistenceError = store.lastPersistenceError
            return
        }
        ratings.append(rating)

        if rating.repeatsInCurrentSession {
            queue.append(word.id)
        }

        withAnimation(.snappy) {
            revealed = false
            currentWordID = nil
            selectNextCard()
        }
    }

    private func selectNextCard() {
        let now = Date.now
        // Repeated cards that are now due take priority over unseen cards.
        let dueRepeatIndex = queue.firstIndex(where: { id in
            guard let word = store.words.first(where: { $0.id == id }) else { return false }
            return store.reviewCount(for: word) > 0 && store.isReviewable(word, at: now)
        })
        let nextIndex = dueRepeatIndex ?? queue.firstIndex(where: { id in
            guard let word = store.words.first(where: { $0.id == id }) else { return false }
            return store.isReviewable(word, at: now)
        })

        if let index = nextIndex {
            currentWordID = queue.remove(at: index)
            waitingUntil = nil
            return
        }

        let futureDates = queue.compactMap { id in
            store.words.first(where: { $0.id == id }).flatMap(store.dueDate(for:))
        }

        if let nextDate = futureDates.min() {
            waitingUntil = nextDate
            currentWordID = nil
        } else {
            waitingUntil = nil
            currentWordID = nil
            isComplete = true
        }
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )
    }
}

#Preview("Scheduled Review") {
    NavigationStack { ReviewPrototypeView() }
        .environment(PrototypeStore(inMemory: true))
        .environment(\.layoutDirection, .rightToLeft)
        .tint(PrototypeTheme.accent)
}
