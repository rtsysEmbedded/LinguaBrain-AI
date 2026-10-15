import SwiftUI
import AVFoundation
import LinguaBrainDomain
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
    @State private var answerText = ""
    @State private var answerEvaluation: ReviewAnswerEvaluation?
    @State private var answerStartedAt: Date?

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
            .replacingOccurrences(of: "%1$@", with: "\u{2068}\(languageName(languageSettings.sourceLanguageTag))\u{2069}")
            .replacingOccurrences(of: "%2$@", with: "\u{2068}\(languageName(languageSettings.targetLanguageTag))\u{2069}")
    }

    private func languageName(_ tag: String) -> String {
        switch tag {
        case "de": return localization.localized("language.german")
        case "en": return localization.localized("language.english")
        case "fa": return localization.localized("language.persian")
        default: return tag
        }
    }

    private func responseCountText(_ count: Int) -> String {
        let key = count == 1 ? "recordedResponses.one" : "recordedResponses.other"
        return localization.localized(key).replacingOccurrences(of: "%d", with: "\(count)")
    }

    private func queueCountText(_ count: Int) -> String {
        let key = count == 1 ? "queueCount.one" : "queueCount.other"
        return localization.localized(key).replacingOccurrences(of: "%d", with: "\(count)")
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
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(reviewTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .environment(\.layoutDirection, .leftToRight)
            }
        }
        .task {
            guard !hasStarted else { return }
            startSession()
        }
        .alert(localization.localized("common.storageError"), isPresented: persistenceErrorBinding) {
            Button(localization.localized("common.ok"), role: .cancel) {
                persistenceError = nil
                store.clearPersistenceError()
            }
        } message: {
            Text(persistenceError ?? localization.localized("common.unknownError"))
        }
    }

    private func reviewView(word: PrototypeWord) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Text(responseCountText(ratings.count))
                        .font(.subheadline.weight(.medium))
                        .frame(width: 112, alignment: .leading)
                    ProgressView(value: progress)
                        .tint(PrototypeTheme.accent)
                    Text(queueCountText(queue.count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 76, alignment: .trailing)
                }

            VStack(spacing: 18) {
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

                if !revealed && mode != .mixedGame {
                    Button(localization.localized("revealAnswer")) {
                        withAnimation(.snappy) { revealed = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if revealed {
                    Divider()
                    if mode == .mixedGame && mixedKind == .article {
                        LanguageText(text: correctArticle(for: word) ?? "—", languageTag: word.targetLanguageTag, font: .title.bold())
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title3)
                        Text(selectedArticle == correctArticle(for: word)
                             ? localization.localized("review.correct")
                             : localization.localized("review.articleIncorrect").replacingOccurrences(of: "%@", with: correctArticle(for: word) ?? "—"))
                            .font(.headline)
                            .foregroundStyle(selectedArticle == correctArticle(for: word) ? PrototypeTheme.mint : .red)
                    } else if mode == .mixedGame && mixedKind == .oddMeaning {
                        let related = relatedMeanings(for: word)
                        let unrelated = meaningOptions.first(where: { !related.contains($0) }) ?? "—"
                        Text(selectedMeaning == unrelated
                             ? localization.localized("review.correct")
                             : localization.localized("review.unrelatedIncorrect").replacingOccurrences(of: "%@", with: unrelated))
                            .font(.headline)
                            .foregroundStyle(selectedMeaning == unrelated ? PrototypeTheme.mint : .red)
                    } else if mode == .mixedGame && mixedKind == .collocation {
                        LanguageText(text: selectedExample.source, languageTag: word.sourceLanguageTag, font: .title3)
                } else if mode == .recognition || (mode == .mixedGame && (mixedKind == .direct || mixedKind == .oddMeaning)) {
                        LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .title3.weight(.semibold))
                    } else {
                        LanguageText(text: word.german, languageTag: word.targetLanguageTag, font: .title3.weight(.semibold))
                    }
                    Divider()
                    LanguageText(
                        text: selectedExample.target,
                        languageTag: word.targetLanguageTag,
                        font: .subheadline,
                        color: .secondary
                    )
                    LanguageText(
                        text: selectedExample.source,
                        languageTag: word.sourceLanguageTag,
                        font: .subheadline,
                        color: .secondary
                    )
                    if let answerEvaluation {
                        answerFeedback(answerEvaluation, for: word)
                    }
                } else if mode == .mixedGame {
                    Button(localization.localized("revealAnswer")) {
                        withAnimation(.snappy) { revealed = true }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .id(word.id)
            .padding(24)
            .frame(maxWidth: 650)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(PrototypeTheme.accent.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: PrototypeTheme.accent.opacity(0.12), radius: 24, y: 12)

            if revealed && answerEvaluation == nil {
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

            }
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func answerEntry(for word: PrototypeWord) -> some View {
        TextField(localization.localized("review.answerPlaceholder"), text: $answerText)
            .textFieldStyle(.roundedBorder)
            .submitLabel(.done)
            .onSubmit { evaluateAnswer(for: word) }
        Button(localization.localized("review.checkAnswer")) {
            evaluateAnswer(for: word)
        }
        .buttonStyle(.borderedProminent)
        .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @ViewBuilder
    private func answerFeedback(_ evaluation: ReviewAnswerEvaluation, for word: PrototypeWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                evaluation.correct ? localization.localized("review.correct") : localization.localized("review.incorrect"),
                systemImage: evaluation.correct ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(evaluation.correct ? PrototypeTheme.mint : .red)
            Text(localization.localized("review.expectedAnswer").replacingOccurrences(of: "%@", with: expectedAnswer(for: word)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !evaluation.correct {
                Text(correctionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(localization.localized("review.tryAgain")) {
                    answerEvaluation = nil
                    answerText = ""
                    revealed = false
                }
                .buttonStyle(.bordered)
            }
            Button(localization.localized("review.continue")) {
                submitAutomatically(evaluation, for: word)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 4)
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

    private func evaluateAnswer(for word: PrototypeWord) {
        let answer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        if mode == .recognition {
            answerEvaluation = ReviewAnswerEvaluator.recognition(
                answer: answer,
                acceptedMeanings: acceptedMeanings(for: word)
            )
        } else if mode == .reverseTranslation {
            answerEvaluation = ReviewAnswerEvaluator.reverseRecall(
                answer: answer,
                acceptedForms: acceptedForms(for: word)
            )
        }
        withAnimation(.snappy) { revealed = true }
    }

    private func acceptedMeanings(for word: PrototypeWord) -> [String] {
        let senseMeanings = word.senses.map(\.meaning)
        let cardMeanings = word.persian
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .components(separatedBy: "\n")
        return Array(Set(senseMeanings + cardMeanings + [word.persian])).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func acceptedForms(for word: PrototypeWord) -> [String] {
        let full = word.german.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutArticle = full.replacingOccurrences(of: "^(der|die|das)\\s+", with: "", options: .regularExpression)
        return withoutArticle == full ? [full] : [full, withoutArticle]
    }

    private func expectedAnswer(for word: PrototypeWord) -> String {
        mode == .recognition ? acceptedMeanings(for: word).joined(separator: " / ") : acceptedForms(for: word).joined(separator: " / ")
    }

    private var correctionHint: String {
        switch mode {
        case .recognition:
            return localization.localized("review.correction.meaning")
        case .reverseTranslation:
            return localization.localized("review.correction.form")
        case .mixedGame:
            return localization.localized("review.correctionHint")
        }
    }

    private func submitAutomatically(_ evaluation: ReviewAnswerEvaluation, for word: PrototypeWord) {
        let skill: LearningSkill = mode == .reverseTranslation ? .recall : .recognition
        let grade: PrototypeReviewGrade = evaluation.correct ? .good : .again
        let responseTimeMilliseconds = answerStartedAt.map { max(0, Int(Date.now.timeIntervalSince($0) * 1_000)) }
        guard let schedule = store.record(
            grade,
            for: word,
            mode: mode,
            skill: skill,
            responseTimeMilliseconds: responseTimeMilliseconds,
            answer: answerText,
            expectedAnswers: evaluation.expectedAnswers
        ) else {
            persistenceError = store.lastPersistenceError
            return
        }
        ratings.append(grade)
        if schedule.isShortTerm { queue.append(word.id) }
        withAnimation(.snappy) {
            answerEvaluation = nil
            answerText = ""
            revealed = false
            currentWordID = nil
            selectNextCard()
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
            Text(localization.localized("review.waitingTitle"))
                .font(.title2.bold())
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let seconds = max(0, Int(date.timeIntervalSince(context.date).rounded(.up)))
                Text(localization.localized("nextCardIn").replacingOccurrences(of: "%@", with: localization.duration(seconds)))
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(localization.localized("review.waitingDescription"))
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
        .accessibilityLabel(localization.localized("review.nextReviewAccessibility").replacingOccurrences(of: "%@", with: rating.title).replacingOccurrences(of: "%2$@", with: interval))
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
        answerText = ""
        answerEvaluation = nil
        answerStartedAt = nil
        isComplete = false
        hasStarted = true
        selectNextCard()
    }

    private func submit(_ rating: PrototypeReviewGrade, for word: PrototypeWord) {
        guard revealed, currentWordID == word.id else { return }
        let skill: LearningSkill? = mode == .mixedGame ? mixedSkill : nil
        guard let schedule = store.record(rating, for: word, mode: mode, skill: skill) else {
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

    private var mixedSkill: LearningSkill {
        switch mixedKind {
        case .article: .grammar
        case .collocation: .production
        case .reverse: .recall
        case .direct, .oddMeaning: .recognition
        }
    }

    private func selectNextCard() {
        if let forcedRepeatID {
            self.forcedRepeatID = nil
            currentWordID = forcedRepeatID
            revealed = false
            answerText = ""
            answerEvaluation = nil
            answerStartedAt = .now
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
            answerText = ""
            answerEvaluation = nil
            answerStartedAt = .now
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

/// A skill-specific practice session. Recognition/reverse review remains the
/// fast default, while these focused sessions create evidence for the other
/// dimensions of the learner model instead of displaying hard-coded zeros.
enum PrototypeSkillPracticeMode: String, CaseIterable, Identifiable, Sendable {
    case listening
    case writing
    case speaking
    case grammar

    var id: String { rawValue }

    var skill: LearningSkill {
        switch self {
        case .listening: .listening
        case .writing: .writing
        case .speaking: .production
        case .grammar: .grammar
        }
    }

    var titleKey: String { "skillPractice.\(rawValue).title" }
    var promptKey: String { "skillPractice.\(rawValue).prompt" }
    var descriptionKey: String { "skillPractice.\(rawValue).description" }
    var symbol: String {
        switch self {
        case .listening: "ear.and.waveform"
        case .writing: "pencil.and.scribble"
        case .speaking: "text.bubble"
        case .grammar: "text.book.closed"
        }
    }

    var scheduleMode: PrototypeReviewMode {
        switch self {
        case .listening, .grammar: .recognition
        case .writing, .speaking: .reverseTranslation
        }
    }
}

/// Feature switches loaded from Resources/Configuration/features.json.
/// Missing or malformed configuration falls back to an empty set of practice
/// modes so that disabled features never reappear by accident.
struct PrototypeFeatureConfiguration: Decodable, Sendable {
    struct SkillPractice: Decodable, Sendable {
        let enabledModes: [String]
    }

    struct TranscriptExport: Decodable, Sendable {
        let defaultFilename: String
    }

    let skillPractice: SkillPractice
    let transcriptExport: TranscriptExport

    static let shared: PrototypeFeatureConfiguration? = {
        let url = Bundle.main.url(forResource: "features", withExtension: "json")
            ?? Bundle.main.url(forResource: "features", withExtension: "json", subdirectory: "Configuration")
        return url.flatMap { try? JSONDecoder().decode(PrototypeFeatureConfiguration.self, from: Data(contentsOf: $0)) }
    }()
}

extension PrototypeSkillPracticeMode {
    static var enabledCases: [PrototypeSkillPracticeMode] {
        let enabled = Set(PrototypeFeatureConfiguration.shared?.skillPractice.enabledModes ?? [])
        return allCases.filter { enabled.contains($0.rawValue) }
    }
}

struct SkillPracticeView: View {
    let practiceMode: PrototypeSkillPracticeMode
    let cardLimit: Int?

    @Environment(PrototypeStore.self) private var store
    @Environment(PrototypeLocalization.self) private var localization
    @Environment(PrototypeLanguageSettings.self) private var languageSettings
    @State private var queue: [UUID] = []
    @State private var currentWordID: UUID?
    @State private var answerText = ""
    @State private var evaluation: ReviewAnswerEvaluation?
    @State private var answerRevealed = false
    @State private var answerStartedAt: Date?
    @State private var completed = false
    @State private var started = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var speechSynthesizer = AVSpeechSynthesizer()
    @State private var voiceTranscription = LiveTranscriptionController()
    @State private var persistenceError: String?

    init(practiceMode: PrototypeSkillPracticeMode, cardLimit: Int? = nil) {
        self.practiceMode = practiceMode
        self.cardLimit = cardLimit
    }

    private var activeWords: [PrototypeWord] {
        store.words(
            sourceLanguageTag: languageSettings.sourceLanguageTag,
            targetLanguageTag: languageSettings.targetLanguageTag
        )
    }

    private var currentWord: PrototypeWord? {
        guard let currentWordID else { return nil }
        return activeWords.first { $0.id == currentWordID }
    }

    var body: some View {
        Group {
            if !started {
                ProgressView(localization.localized("preparingReviewQueue"))
            } else if completed {
                completionView
            } else if let word = currentWord {
                practiceCard(for: word)
            } else {
                ProgressView(localization.localized("preparingReviewQueue"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .background(PrototypeBackground())
        .navigationTitle(localization.localized(practiceMode.titleKey))
        .task {
            guard !started else { return }
            startSession()
        }
        .onChange(of: voiceTranscription.visibleText) { _, value in
            // Speech-assisted production keeps the live transcript in the
            // answer field so the learner can review/edit it before scoring.
            guard practiceMode == .speaking, evaluation == nil, !value.isEmpty else { return }
            answerText = value
        }
        .onDisappear {
            if voiceTranscription.isRecording { voiceTranscription.stop() }
        }
        .alert(localization.localized("card.operationFailed"), isPresented: persistenceErrorBinding) {
            Button(localization.localized("common.ok"), role: .cancel) {
                persistenceError = nil
                store.clearPersistenceError()
            }
        } message: {
            Text(persistenceError ?? localization.localized("common.unknownError"))
        }
    }

    @ViewBuilder
    private func practiceCard(for word: PrototypeWord) -> some View {
        ScrollView {
        VStack(spacing: 24) {
            HStack {
                Label(localization.localized(practiceMode.titleKey), systemImage: practiceMode.symbol)
                    .font(.headline)
                    .foregroundStyle(PrototypeTheme.accent)
                Spacer()
                Text("\(queue.count + 1) / \(max(queue.count + 1, cardLimit ?? 10))")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            PrototypeCard {
                VStack(alignment: .leading, spacing: 20) {
                    Text(localization.localized(practiceMode.promptKey))
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(localization.localized(practiceMode.descriptionKey))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    promptContent(for: word)

                    if practiceMode == .speaking {
                        Text(localization.localized("skillPractice.textProductionNote"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if practiceMode == .speaking {
                        speakingRecorder(for: word)
                    }

                    if practiceMode == .speaking {
                        TextEditor(text: $answerText)
                            .frame(minHeight: 110)
                            .padding(8)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        TextField(localization.localized("skillPractice.answerPlaceholder"), text: $answerText)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .padding(.vertical, 4)
                            .onSubmit { evaluateAnswer(for: word) }
                    }

                    HStack {
                        Button(localization.localized("skillPractice.submit")) { evaluateAnswer(for: word) }
                            .buttonStyle(.borderedProminent)
                            .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || evaluation != nil)
                        Button(localization.localized("skillPractice.showAnswer")) { answerRevealed = true }
                            .buttonStyle(.bordered)
                        Button(localization.localized("skillPractice.skip")) { selectNext() }
                            .buttonStyle(.bordered)
                    }
                    .controlSize(.large)

                    if answerRevealed {
                        answerReveal(for: word)
                    }

                    if let evaluation {
                        feedback(for: evaluation, word: word)
                    }
                }
            }
        }
        }
    }

    @ViewBuilder
    private func speakingRecorder(for word: PrototypeWord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    if voiceTranscription.isRecording {
                        stopVoiceCapture()
                    } else {
                        startVoiceCapture(for: word)
                    }
                } label: {
                    Label(
                        localization.localized(voiceTranscription.isRecording ? "skillPractice.stopSpeaking" : "skillPractice.startSpeaking"),
                        systemImage: voiceTranscription.isRecording ? "stop.fill" : "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(voiceTranscription.isRecording ? .red : PrototypeTheme.accent)

                if !voiceTranscription.visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(localization.localized("skillPractice.useTranscript")) {
                        answerText = voiceTranscription.visibleText
                    }
                    .buttonStyle(.bordered)
                }
            }

            if voiceTranscription.isRecording || voiceTranscription.inputLevel > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.16))
                            Capsule()
                                .fill(voiceTranscription.inputLevel > 0.04 ? PrototypeTheme.accent : .secondary)
                                .frame(width: proxy.size.width * max(0.03, voiceTranscription.inputLevel))
                        }
                    }
                    .frame(height: 8)
                    Text(localization.localized(voiceTranscription.isRecording ? "skillPractice.voiceListening" : "skillPractice.voiceReady"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 18)
            }

            if !voiceTranscription.visibleText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localization.localized("skillPractice.voiceTranscript"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(voiceTranscription.visibleText)
                        .font(.subheadline)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            if let errorMessage = voiceTranscription.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func startVoiceCapture(for word: PrototypeWord) {
        voiceTranscription.stop()
        voiceTranscription.clear()
        // Use Apple's on-device transcriber for this first pronunciation pass.
        // It keeps the exercise usable without an API key and avoids coupling
        // the scoring path to the unstable Realtime network transport.
        voiceTranscription.provider = .appleOnDevice
        voiceTranscription.start(languageTag: word.targetLanguageTag)
    }

    private func stopVoiceCapture() {
        voiceTranscription.stop()
        Task { @MainActor in
            // SpeechAnalyzer finalizes its last partial result asynchronously.
            try? await Task.sleep(for: .milliseconds(400))
            let finalText = voiceTranscription.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalText.isEmpty, evaluation == nil { answerText = finalText }
        }
    }

    @ViewBuilder
    private func promptContent(for word: PrototypeWord) -> some View {
        switch practiceMode {
        case .listening:
            VStack(spacing: 12) {
                Button {
                    playPrompt(for: word)
                } label: {
                    Label(localization.localized("skillPractice.playAudio"), systemImage: "play.circle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                Text(localization.localized("skillPractice.listening.prompt"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(localization.localized("skillPractice.listening.sentenceHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .writing, .speaking:
            LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, font: .system(size: 30, weight: .bold, design: .rounded))
        case .grammar:
            VStack(alignment: .leading, spacing: 8) {
                LanguageText(text: grammarPrompt(for: word), languageTag: word.targetLanguageTag, font: .system(size: 30, weight: .bold, design: .rounded))
                LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, color: .secondary)
            }
        }
    }

    @ViewBuilder
    private func answerReveal(for word: PrototypeWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(localization.localized("skillPractice.correctAnswer"), systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(PrototypeTheme.accent)
            if practiceMode == .listening, let example = word.examples.first?.target, !example.isEmpty {
                GermanText(text: example, font: .title3.weight(.semibold))
                LanguageText(text: word.persian, languageTag: word.sourceLanguageTag, color: .secondary)
            } else {
                LanguageText(text: expectedAnswers(for: word).joined(separator: " / "), languageTag: practiceMode == .listening ? word.sourceLanguageTag : word.targetLanguageTag, font: .title3.weight(.semibold))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrototypeTheme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func feedback(for result: ReviewAnswerEvaluation, word: PrototypeWord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                result.correct ? localization.localized("review.correct") : localization.localized("review.incorrect"),
                systemImage: result.correct ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .foregroundStyle(result.correct ? PrototypeTheme.mint : .red)
            Text(localization.localized("review.expectedAnswer").replacingOccurrences(of: "%@", with: expectedAnswers(for: word).joined(separator: " / ")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !result.correct {
                Text(localization.localized("review.correctionHint"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(localization.localized("review.tryAgain")) {
                    evaluation = nil
                    answerText = ""
                    answerStartedAt = .now
                }
                .buttonStyle(.bordered)
            }
            Button(localization.localized("review.continue")) {
                submit(result, for: word)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.top, 4)
    }

    private func startSession() {
        let now = Date.now
        let sorted = activeWords.sorted { lhs, rhs in
            let leftAttempts = store.skillAttemptCount(for: lhs, skill: practiceMode.skill)
            let rightAttempts = store.skillAttemptCount(for: rhs, skill: practiceMode.skill)
            if (leftAttempts > 0) != (rightAttempts > 0) { return leftAttempts == 0 }
            let leftMastery = store.mastery(for: lhs, skill: practiceMode.skill)
            let rightMastery = store.mastery(for: rhs, skill: practiceMode.skill)
            if leftMastery != rightMastery { return leftMastery < rightMastery }
            let leftDue = store.dueDate(for: lhs, mode: practiceMode.scheduleMode) ?? .distantPast
            let rightDue = store.dueDate(for: rhs, mode: practiceMode.scheduleMode) ?? .distantPast
            if (leftDue <= now) != (rightDue <= now) { return leftDue <= now }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let limit = max(1, cardLimit ?? 10)
        queue = Array(sorted.prefix(limit)).map(\.id)
        started = true
        completed = queue.isEmpty
        selectNext()
    }

    private func selectNext() {
        guard !queue.isEmpty else {
            currentWordID = nil
            completed = true
            return
        }
        currentWordID = queue.removeFirst()
        answerText = ""
        evaluation = nil
        answerRevealed = false
        answerStartedAt = .now
        if practiceMode == .listening, let word = currentWord {
            playPrompt(for: word)
        }
    }

    private func evaluateAnswer(for word: PrototypeWord) {
        let answer = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return }
        switch practiceMode {
        case .listening:
            evaluation = ReviewAnswerEvaluator.recognition(answer: answer, acceptedMeanings: acceptedMeanings(for: word))
        case .writing:
            evaluation = ReviewAnswerEvaluator.reverseRecall(answer: answer, acceptedForms: acceptedForms(for: word))
        case .speaking:
            evaluation = ReviewAnswerEvaluator.production(answer: answer, acceptedForms: acceptedForms(for: word))
        case .grammar:
            evaluation = ReviewAnswerEvaluator.reverseRecall(answer: answer, acceptedForms: expectedAnswers(for: word))
        }
    }

    private func submit(_ result: ReviewAnswerEvaluation, for word: PrototypeWord) {
        let grade: PrototypeReviewGrade = result.correct ? .good : .again
        let responseTime = answerStartedAt.map { max(0, Int(Date.now.timeIntervalSince($0) * 1_000)) }
        guard store.record(
            grade,
            for: word,
            mode: practiceMode.scheduleMode,
            skill: practiceMode.skill,
            responseTimeMilliseconds: responseTime,
            answer: answerText,
            expectedAnswers: result.expectedAnswers
        ) != nil else {
            persistenceError = store.lastPersistenceError
            return
        }
        if grade == .again { queue.append(word.id) }
        selectNext()
    }

    private func playPrompt(for word: PrototypeWord) {
        if let data = store.pronunciationAudio(for: word), let player = try? AVAudioPlayer(data: data) {
            audioPlayer = player
            player.play()
            return
        }
        let utterance = AVSpeechUtterance(string: word.examples.first?.target ?? word.german)
        utterance.voice = AVSpeechSynthesisVoice(language: word.targetLanguageTag)
        utterance.rate = 0.45
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }

    private func acceptedMeanings(for word: PrototypeWord) -> [String] {
        let values = word.senses.map(\.meaning) + word.persian
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .components(separatedBy: "\n")
        return Array(Set(values)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func acceptedForms(for word: PrototypeWord) -> [String] {
        let full = word.german.trimmingCharacters(in: .whitespacesAndNewlines)
        let bare = full.replacingOccurrences(of: "^(der|die|das)\\s+", with: "", options: .regularExpression)
        return bare == full ? [full] : [full, bare]
    }

    private func expectedAnswers(for word: PrototypeWord) -> [String] {
        switch practiceMode {
        case .listening: return acceptedMeanings(for: word)
        case .writing, .speaking: return acceptedForms(for: word)
        case .grammar:
            if let article = word.article?.trimmingCharacters(in: .whitespacesAndNewlines), !article.isEmpty { return [article] }
            return acceptedForms(for: word)
        }
    }

    private func grammarPrompt(for word: PrototypeWord) -> String {
        let bare = word.german.replacingOccurrences(of: "^(der|die|das)\\s+", with: "", options: .regularExpression)
        return word.article == nil ? bare : "___ \(bare)"
    }

    private var completionView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 58))
                .foregroundStyle(PrototypeTheme.mint)
            Text(localization.localized("reviewCompleteTitle"))
                .font(.largeTitle.bold())
            Text(localization.localized(practiceMode.descriptionKey))
                .foregroundStyle(.secondary)
            Button(localization.localized("retryQueue")) {
                started = false
                startSession()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var persistenceErrorBinding: Binding<Bool> {
        Binding(
            get: { persistenceError != nil },
            set: { if !$0 { persistenceError = nil } }
        )
    }
}
