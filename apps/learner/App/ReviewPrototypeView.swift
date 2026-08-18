import SwiftUI
import AVFoundation

struct ReviewPrototypeView: View {
    let newCardLimit: Int?
    let mode: PrototypeReviewMode
    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var revealed = false
    @State private var queue: [UUID] = []
    @State private var currentWordID: UUID?
    @State private var ratings: [PrototypeReviewGrade] = []
    @State private var waitingUntil: Date?
    @State private var isComplete = false
    @State private var hasStarted = false
    @State private var persistenceError: String?
    @State private var audioPlayer: AVAudioPlayer?

    init(newCardLimit: Int? = nil, mode: PrototypeReviewMode = .recognition) {
        self.newCardLimit = newCardLimit
        self.mode = mode
    }

    private var currentWord: PrototypeWord? {
        guard let currentWordID else { return nil }
        return store.words.first { $0.id == currentWordID }
    }

    private var activeWords: [PrototypeWord] {
        store.words(
            sourceLanguageTag: languageSettings.sourceLanguageTag,
            targetLanguageTag: languageSettings.targetLanguageTag
        )
    }

    private var progress: Double {
        Double(store.reviewedCount(in: activeWords)) / Double(max(activeWords.count, 1))
    }

    private var reviewTitle: String {
        guard mode == .recognition else { return localization.localized("reverseReviewTitle") }
        return localization.localized("recognitionReviewFormat")
            .replacingOccurrences(of: "%1$@", with: languageName(languageSettings.sourceLanguageTag))
            .replacingOccurrences(of: "%2$@", with: languageName(languageSettings.targetLanguageTag))
    }

    private func languageName(_ tag: String) -> String {
        switch tag {
        case "de": return "Deutsch"
        case "en": return "English"
        case "fa": return "فارسی"
        default: return tag
        }
    }

    var body: some View {
        Group {
            if !hasStarted {
                ProgressView(localization.localized("preparingReviewQueue"))
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
        .navigationTitle(reviewTitle)
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
                Text(localization.localized("recordedResponses").replacingOccurrences(of: "%d", with: "\(ratings.count)"))
                    .font(.subheadline.weight(.medium))
                ProgressView(value: progress)
                    .tint(PrototypeTheme.accent)
                Text(localization.localized("queueCount").replacingOccurrences(of: "%d", with: "\(queue.count)"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 10)

            VStack(spacing: 22) {
                Text(localization.localized(mode == .recognition ? "reviewPrompt" : "reversePrompt"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if mode == .recognition {
                    LanguageText(
                        text: word.german,
                        languageTag: word.targetLanguageTag,
                        font: .system(size: 38, weight: .bold, design: .rounded)
                    )
                } else {
                    LanguageText(
                        text: word.persian,
                        languageTag: word.sourceLanguageTag,
                        font: .system(size: 34, weight: .bold, design: .rounded)
                    )
                }

                if let audio = store.pronunciationAudio(for: word) {
                    Button(localization.localized("media.playAudio"), systemImage: "play.circle.fill") {
                        audioPlayer = try? AVAudioPlayer(data: audio)
                        audioPlayer?.play()
                    }
                    .buttonStyle(.bordered)
                }

                if revealed {
                    Divider()
                    if mode == .recognition {
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title.bold())
                    } else {
                        LanguageText(text: word.german, languageTag: word.targetLanguageTag, font: .title.bold())
                    }
                    LanguageText(text: word.example, languageTag: word.targetLanguageTag, font: .title3)
                    LanguageText(text: word.exampleTranslation, languageTag: word.sourceLanguageTag, color: .secondary)
                } else {
                    Button(localization.localized("revealAnswer")) {
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
                    Text(localization.localized("answerRating"))
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
                Text(localization.localized("nextCardIn").replacingOccurrences(of: "%@", with: localization.duration(seconds)))
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
            Text(localization.localized("reviewCompleteTitle")).font(.largeTitle.bold())
            Text(localization.localized("sessionResponses").replacingOccurrences(of: "%d", with: "\(ratings.count)"))
                .foregroundStyle(.secondary)

            PrototypeCard {
                VStack(spacing: 14) {
                    ForEach(PrototypeReviewGrade.allCases) { rating in
                        HStack {
                            Label(localization.localized(rating.localizationKey), systemImage: rating.symbol)
                                .foregroundStyle(rating.color)
                            Spacer()
                            Text("\(ratings.filter { $0 == rating }.count)")
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
            }
            .frame(maxWidth: 440)

            Button(localization.localized("retryQueue")) {
                startSession()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
    }

    private func ratingButton(_ rating: PrototypeReviewGrade, word: PrototypeWord) -> some View {
        let schedule = store.previewSchedule(for: rating, word: word, mode: mode)
        let interval = localization.duration(max(0, Int(schedule.dueAt.timeIntervalSince(schedule.state.lastReview).rounded())))
        return Button {
            submit(rating, for: word)
        } label: {
            VStack(spacing: 5) {
                Image(systemName: rating.symbol)
                Text(localization.localized(rating.localizationKey)).font(.caption.weight(.semibold))
                Text(interval).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(rating.color)
        .accessibilityLabel("\(rating.title)، مرور بعدی \(interval)")
    }

    private func startSession() {
        let due = activeWords.filter {
            store.reviewCount(for: $0, mode: mode) > 0 && store.isReviewable($0, mode: mode)
        }
        let shortTerm = activeWords.filter {
            store.reviewCount(for: $0, mode: mode) > 0
                && !store.isReviewable($0, mode: mode)
                && store.shouldRepeatInCurrentSession($0, mode: mode)
        }
        let unseen = activeWords.filter { store.reviewCount(for: $0, mode: mode) == 0 }
        let newCards = Array(unseen.prefix(newCardLimit ?? unseen.count))
        queue = (due + newCards + shortTerm).map(\.id)
        currentWordID = nil
        waitingUntil = nil
        ratings = []
        isComplete = false
        hasStarted = true
        selectNextCard()
    }

    private func submit(_ rating: PrototypeReviewGrade, for word: PrototypeWord) {
        guard revealed, currentWordID == word.id else { return }
        guard let schedule = store.record(rating, for: word, mode: mode) else {
            persistenceError = store.lastPersistenceError
            return
        }
        ratings.append(rating)

        if schedule.isShortTerm {
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
            return store.reviewCount(for: word, mode: mode) > 0 && store.isReviewable(word, mode: mode, at: now)
        })
        let nextIndex = dueRepeatIndex ?? queue.firstIndex(where: { id in
            guard let word = store.words.first(where: { $0.id == id }) else { return false }
            return store.isReviewable(word, mode: mode, at: now)
        })

        if let index = nextIndex {
            currentWordID = queue.remove(at: index)
            waitingUntil = nil
            return
        }

        let futureDates = queue.compactMap { id in
            store.words.first(where: { $0.id == id }).flatMap { store.dueDate(for: $0, mode: mode) }
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
