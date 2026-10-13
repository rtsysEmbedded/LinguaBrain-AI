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
    @Environment(PrototypeLearnerProfile.self) private var learnerProfile
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
                        audioPlayer = learnerProfile.makeAudioPlayer(data: audio)
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
        .accessibilityLabel(localization.formatted("review.nextReviewAccessibility", localization.localized(rating.localizationKey), interval))
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
                    let rules = LearningContentRules.bundled
                    let canTestArticle = correctArticle(for: word) != nil &&
                        (rules.nounPartOfSpeechMarkers.contains { word.partOfSpeech.localizedCaseInsensitiveContains($0) } ||
                         word.article != nil)
                    let canTestOddMeaning = relatedMeanings(for: word).count >= 3
                        && rules.verbPartOfSpeechMarkers.contains { word.partOfSpeech.localizedCaseInsensitiveContains($0) }
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
        .environment(PrototypeLocalization())
        .environment(PrototypeLanguageSettings())
        .environment(PrototypeLearnerProfile())
        .environment(\.layoutDirection, .rightToLeft)
        .tint(PrototypeTheme.accent)
}

/// The four skill-practice routes on Today. Each maps to a Feature 004
/// practice skill; recognition and recall stay in the Anki review queue.
enum PrototypeSkillPracticeMode: String, CaseIterable, Identifiable, Sendable {
    case listening
    case writing
    case speaking
    case grammar

    var id: String { rawValue }

    var practiceSkill: PracticeSkill {
        switch self {
        case .listening: .listening
        case .writing: .writing
        case .speaking: .speaking
        case .grammar: .grammar
        }
    }

    init(practiceSkill: PracticeSkill) {
        switch practiceSkill {
        case .listening: self = .listening
        case .writing: self = .writing
        case .speaking: self = .speaking
        case .grammar: self = .grammar
        }
    }

    var titleKey: String { "skillPractice.\(rawValue).title" }
    var symbol: String {
        switch self {
        case .listening: "ear.and.waveform"
        case .writing: "pencil.and.scribble"
        case .speaking: "text.bubble"
        case .grammar: "text.book.closed"
        }
    }
}
