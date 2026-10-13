import XCTest
import LinguaBrainAI
import LinguaBrainApplication
import LinguaBrainDomain
import LinguaBrainPersistence
@testable import LinguaBrain

/// T033 app wiring: Today routes, the card snapshot, and the capability
/// decisions shown before an exercise is loaded.
@MainActor
final class SkillPracticeRoutingTests: XCTestCase {
    private func makeComposition(gradedSkills: Set<PracticeSkill> = []) -> PracticeComposition {
        PracticeComposition(
            repository: InMemoryPracticeRepository(),
            evaluator: UnavailablePracticeEvaluator(),
            clock: SystemPracticeClock(),
            scheduler: PracticeFSRS6Scheduler(),
            gradedSkills: gradedSkills
        )
    }

    func testEveryTodayRouteMapsToItsPracticeSkill() {
        for mode in PrototypeSkillPracticeMode.allCases {
            XCTAssertEqual(PrototypeSkillPracticeMode(practiceSkill: mode.practiceSkill), mode)
        }
        XCTAssertEqual(Set(PrototypeSkillPracticeMode.allCases.map(\.practiceSkill)), Set(PracticeSkill.allCases))
    }

    func testCardSnapshotKeepsTheLanguagePairAndReviewMarker() throws {
        let store = PrototypeStore(inMemory: true)
        let batch = PrototypeWord(german: "prüfen", persian: "بررسی کردن", level: "A2", partOfSpeech: "Verb", example: "Ich prüfe es.", exampleTranslation: "آن را بررسی می‌کنم.", domain: "general")
        XCTAssertTrue(store.addGeneratedCards([batch]))
        let cards = PrototypeStorePracticeCards(store: store)
        let pair = cards.cards(sourceLanguage: batch.sourceLanguageTag, targetLanguage: batch.targetLanguageTag)
        let candidate = try XCTUnwrap(pair.first { $0.cardID == batch.id })
        XCTAssertEqual(candidate.targetText, "prüfen")
        XCTAssertEqual(candidate.sourceMeaning, "بررسی کردن")
        XCTAssertEqual(candidate.exampleReview, .unreviewed)
        XCTAssertTrue(pair.allSatisfy { $0.sourceLanguage == batch.sourceLanguageTag && $0.targetLanguage == batch.targetLanguageTag })
        let seed = pair.first { candidate in PrototypeData.words.contains { $0.id == candidate.cardID } }
        XCTAssertEqual(seed?.exampleReview, .reviewed)
    }

    func testCapabilityProbeGatesUnsupportedModesExplicitly() {
        let store = PrototypeStore(inMemory: true)
        let pair = (source: LearningContentRules.bundled.defaults.sourceLanguageTag, target: LearningContentRules.bundled.defaults.targetLanguageTag)
        let probe = PracticeCapabilityProbe(
            composition: makeComposition(),
            cards: PrototypeStorePracticeCards(store: store),
            aiSettings: PrototypeAISettings(),
            sourceLanguage: pair.source,
            targetLanguage: pair.target,
            hasReviewedGrammarContent: false
        )
        XCTAssertEqual(probe.availability(for: .writing), .available(.ungradedNoProvider))
        XCTAssertEqual(probe.availability(for: .grammar), .unavailable(.noReviewedGrammarContent))
        XCTAssertEqual(probe.availability(for: .speaking), .unavailable(.pronunciationNotValidated))
        XCTAssertEqual(probe.evaluatorState(for: .writing), .notConfigured, "No evaluator is routed for writing in this composition")
    }

    func testProgressHasNoEvidenceBeforePractice() async throws {
        let store = PrototypeStore(inMemory: true)
        let probe = PracticeCapabilityProbe(
            composition: makeComposition(),
            cards: PrototypeStorePracticeCards(store: store),
            aiSettings: PrototypeAISettings(),
            sourceLanguage: LearningContentRules.bundled.defaults.sourceLanguageTag,
            targetLanguage: LearningContentRules.bundled.defaults.targetLanguageTag,
            hasReviewedGrammarContent: false
        )
        let progress = try await probe.progress()
        XCTAssertEqual(progress.count, PracticeSkill.allCases.count)
        XCTAssertTrue(progress.allSatisfy { $0.averageMastery == nil })
    }

    func testEveryUnavailableReasonAndGradingNoticeIsLocalized() {
        var keys = PracticeAvailabilityReason.allCases.flatMap { ["practice.unavailable.\($0.rawValue).title", "practice.unavailable.\($0.rawValue).detail"] }
        keys += ["storageNotReady", "loadFailed"].flatMap { ["practice.unavailable.\($0).title", "practice.unavailable.\($0).detail"] }
        keys += [PracticeGrading.ungradedNoProvider, .ungradedConsentRequired].map { "practice.grading.\($0.rawValue)" }
        for language in PrototypeAppLanguage.allCases {
            for key in keys {
                XCTAssertNotEqual(PrototypeLocalization.localized(key, language: language), key, "\(key) missing for \(language)")
            }
        }
    }

    func testEvaluationWithoutAProviderIsExplicitlyUngraded() async throws {
        let unit = ReviewUnit(learnerID: PracticeLearner.localID, skill: .writing, objectiveKey: "writing.card.test")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "gehen", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "Ich gehe.", submittedAt: Date())
        let evaluator = SettingsBackedPracticeEvaluator(
            skill: .writing,
            repository: InMemoryPracticeRepository(),
            grammarContext: FactoryGrammarContextResolver(),
            environment: { nil }
        )
        let result = try await evaluator.evaluate(attempt, exercise: exercise)
        XCTAssertEqual(result.outcome, .unavailable)
        XCTAssertEqual(result.unavailableReason, .providerUnavailable)
        XCTAssertEqual(result.evaluatorVersion, SettingsBackedPracticeEvaluator.notConfiguredVersion)
    }

    func testLiveCompositionGradesWritingGrammarAndListeningOnly() {
        let composition = PracticeComposition.live(
            repository: InMemoryPracticeRepository(),
            settings: PrototypeAISettings(),
            store: PrototypeStore(inMemory: true),
            grammarContext: FactoryGrammarContextResolver()
        )
        XCTAssertEqual(composition.gradedSkills, [.writing, .grammar, .listening])
    }
}
