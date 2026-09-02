import SwiftUI
import AVFoundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

private enum MixedPracticeKind: CaseIterable {
    case direct, reverse, article, collocation, oddMeaning
}

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
    @State private var mixedKind: MixedPracticeKind = .direct
    @State private var selectedArticle: String?
    @State private var articleAnswered = false
    @State private var articleWasWrong = false
    @State private var forcedRepeatID: UUID?
    @State private var meaningOptions: [String] = []
    @State private var selectedMeaning: String?
    @State private var meaningAnswered = false
    @State private var meaningWasWrong = false
    @State private var selectedExample = PrototypeExample(target: "", source: "")

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
        if mode == .mixedGame { return localization.localized("mixedPractice.title") }
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
                Text(promptText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if mode == .mixedGame && mixedKind == .article {
                    LanguageText(
                        text: word.german.replacingOccurrences(of: "^\\S+\\s", with: "", options: .regularExpression),
                        languageTag: word.targetLanguageTag,
                        font: .system(size: 38, weight: .bold, design: .rounded)
                    )
                } else if mode == .mixedGame && mixedKind == .collocation {
                    LanguageText(text: selectedExample.target, languageTag: word.targetLanguageTag, font: .title2.bold())
                } else if mode == .recognition || (mode == .mixedGame && mixedKind == .direct) {
                    LanguageText(
                        text: word.german,
                        languageTag: word.targetLanguageTag,
                        font: .system(size: 38, weight: .bold, design: .rounded)
                    )
                } else if !(mode == .mixedGame && mixedKind == .article) {
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

                #if os(macOS)
                if let data = store.illustrationImage(for: word), let image = NSImage(data: data) {
                    Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                }
                #else
                if let data = store.illustrationImage(for: word), let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180)
                }
                #endif

                if mode == .mixedGame && mixedKind == .article && !articleAnswered {
                    HStack(spacing: 12) {
                        ForEach(["der", "die", "das"], id: \.self) { article in
                            Button(article) {
                                selectedArticle = article
                                articleAnswered = true
                                articleWasWrong = article != correctArticle(for: word)
                                withAnimation(.snappy) { revealed = true }
                            }
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if mode == .mixedGame && mixedKind == .oddMeaning && !meaningAnswered {
                    VStack(spacing: 10) {
                        ForEach(meaningOptions, id: \.self) { meaning in
                            Button(meaning) {
                                selectedMeaning = meaning
                                meaningAnswered = true
                                meaningWasWrong = meaning != meaningOptions.first(where: { !relatedMeanings(for: word).contains($0) })
                                withAnimation(.snappy) { revealed = true }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if revealed {
                    Divider()
                    if mode == .mixedGame && mixedKind == .article {
                        LanguageText(text: correctArticle(for: word) ?? "—", languageTag: word.targetLanguageTag, font: .title.bold())
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title3)
                        Text(selectedArticle == correctArticle(for: word) ? "درست" : "نادرست · پاسخ درست: \(correctArticle(for: word) ?? "—")")
                            .font(.headline)
                            .foregroundStyle(selectedArticle == correctArticle(for: word) ? PrototypeTheme.mint : .red)
                    } else if mode == .mixedGame && mixedKind == .oddMeaning {
                        let related = relatedMeanings(for: word)
                        let unrelated = meaningOptions.first(where: { !related.contains($0) }) ?? "—"
                        Text(selectedMeaning == unrelated ? "درست" : "نادرست · معنی نامرتبط: \(unrelated)")
                            .font(.headline)
                            .foregroundStyle(selectedMeaning == unrelated ? PrototypeTheme.mint : .red)
                    } else if mode == .mixedGame && mixedKind == .collocation {
                        LanguageText(text: selectedExample.source, languageTag: word.sourceLanguageTag, font: .title3)
                } else if mode == .recognition || (mode == .mixedGame && (mixedKind == .direct || mixedKind == .oddMeaning)) {
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title.bold())
                    } else {
                        LanguageText(text: word.german, languageTag: word.targetLanguageTag, font: .title.bold())
                    }
                    LanguageText(text: selectedExample.target, languageTag: word.targetLanguageTag, font: .title3)
                    LanguageText(text: selectedExample.source, languageTag: word.sourceLanguageTag, color: .secondary)
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

    private var promptText: String {
        guard mode == .mixedGame else {
            return localization.localized(mode == .recognition ? "reviewPrompt" : "reversePrompt")
        }
        switch mixedKind {
        case .direct: return localization.localized("mixedPractice.directPrompt")
        case .reverse: return localization.localized("mixedPractice.reversePrompt")
        case .article: return localization.localized("mixedPractice.articlePrompt")
        case .collocation: return localization.localized("mixedPractice.collocationPrompt")
        case .oddMeaning: return localization.localized("mixedPractice.oddMeaningPrompt")
        }
    }

    private func relatedMeanings(for word: PrototypeWord) -> [String] {
        Array(Set(store.words.filter {
            $0.german.caseInsensitiveCompare(word.german) == .orderedSame && $0.partOfSpeech == word.partOfSpeech
        }.map(\.persian)))
    }

    private func correctArticle(for word: PrototypeWord) -> String? {
        if let article = word.article?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           ["der", "die", "das"].contains(article) {
            return article
        }
        let first = word.german.split(separator: " ").first?.lowercased()
        return first.flatMap { ["der", "die", "das"].contains($0) ? String($0) : nil }
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
        if articleWasWrong || meaningWasWrong {
            forcedRepeatID = word.id
        }

        withAnimation(.snappy) {
            revealed = false
            currentWordID = nil
            selectNextCard()
        }
    }

    private func selectNextCard() {
        if let forcedRepeatID {
            self.forcedRepeatID = nil
            currentWordID = forcedRepeatID
            revealed = false
            if mode == .mixedGame {
                let repeatMeaning = meaningWasWrong
                mixedKind = repeatMeaning ? .oddMeaning : .article
                selectedArticle = nil
                articleAnswered = false
                articleWasWrong = false
                selectedMeaning = nil
                meaningAnswered = false
                if repeatMeaning, let word = currentWord {
                    let related = Array(relatedMeanings(for: word).prefix(3))
                    let unrelated = store.words.map(\.persian).first(where: { !related.contains($0) && $0 != word.persian }) ?? "—"
                    meaningOptions = (related + [unrelated]).shuffled()
                }
                meaningWasWrong = false
            }
            waitingUntil = nil
            return
        }
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
            let nextID = queue.remove(at: index)
            currentWordID = nextID
            if let word = store.words.first(where: { $0.id == nextID }) {
                selectedExample = word.examples.randomElement() ?? PrototypeExample(target: word.example, source: word.exampleTranslation)
            }
            if mode == .mixedGame {
                let eligibleKinds: [MixedPracticeKind] = store.words.first(where: { $0.id == nextID }).flatMap { word in
                    let canTestArticle = correctArticle(for: word) != nil &&
                        (word.partOfSpeech.localizedCaseInsensitiveContains("noun") ||
                         word.partOfSpeech.localizedCaseInsensitiveContains("اسم") ||
                         word.article != nil)
                    let canTestOddMeaning = relatedMeanings(for: word).count >= 3 && word.partOfSpeech.localizedCaseInsensitiveContains("verb")
                    return (canTestOddMeaning ? [.direct, .reverse, .collocation, .oddMeaning] : [.direct, .reverse, .collocation]) +
                        (canTestArticle ? [.article] : [])
                } ?? [.direct, .reverse, .collocation]
                mixedKind = eligibleKinds.randomElement() ?? .direct
                selectedArticle = nil
                articleAnswered = false
                articleWasWrong = false
                meaningOptions = []
                selectedMeaning = nil
                meaningAnswered = false
                meaningWasWrong = false
                if mixedKind == .oddMeaning, let word = currentWord {
                    let related = Array(relatedMeanings(for: word).prefix(3))
                    let unrelated = store.words.map(\.persian).first(where: { !related.contains($0) && $0 != word.persian }) ?? "—"
                    meaningOptions = (related + [unrelated]).shuffled()
                }
            }
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
