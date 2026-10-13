import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication
@testable import LinguaBrainPersistence

private struct CatalogClock: PracticeClock { let date: Date; func now() -> Date { date } }

private struct CorrectEvaluator: PracticeEvaluator {
    func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        EvaluationResult(outcome: .correct, score: 1, confidence: 0.95, feedback: [TypedFeedback(message: "ok")], evaluatorVersion: "test-correct")
    }
}

private struct SkillTaggingEvaluator: PracticeEvaluator {
    let tag: String
    func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        EvaluationResult(outcome: .correct, score: 1, confidence: 0.95, evaluatorVersion: tag)
    }
}

private struct StaticCardSource: PracticeCardSource {
    let cards: [PracticeCardCandidate]
    func practiceCards(sourceLanguage: String, targetLanguage: String) async throws -> [PracticeCardCandidate] {
        cards.filter { $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage }
    }
}

private func card(
    _ number: Int, _ target: String, review: PracticeCardCandidate.ExampleReview = .reviewed,
    source: String = "fa", destination: String = "de"
) -> PracticeCardCandidate {
    PracticeCardCandidate(
        cardID: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!,
        targetText: target, sourceMeaning: "meaning \(number)", partOfSpeech: "Verb", cefrLevel: "A2",
        exampleTarget: "Ich \(target) heute.", exampleSource: "translation \(number)", exampleReview: review,
        sourceLanguage: source, targetLanguage: destination
    )
}

final class PracticeIntegrationCatalogTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testWritingRetrievalIsDeterministicAndScopedToTheLanguagePair() async throws {
        let repository = InMemoryPracticeRepository()
        let source = StaticCardSource(cards: [card(1, "arbeiten"), card(2, "lernen"), card(3, "house", source: "fa", destination: "en")])
        let retrieval = CardBackedWritingRetrieval(cards: source, repository: repository, clock: CatalogClock(date: now), sourceLanguage: "fa", targetLanguage: "de")

        let first = try await retrieval.nextWritingExercise(learnerID: "local", cefrLevel: "B1", seed: 7)
        let second = try await retrieval.nextWritingExercise(learnerID: "local", cefrLevel: "B1", seed: 7)

        XCTAssertEqual(first, second)
        let descriptor = try XCTUnwrap(first)
        XCTAssertTrue(["arbeiten", "lernen"].contains(descriptor.targetWord))
        XCTAssertEqual(descriptor.exercise.reviewUnit.skill, .writing)
        XCTAssertEqual(descriptor.cefrLevel, "A2")
        XCTAssertTrue(descriptor.allowedContext.hasPrefix("meaning"), "The support-language meaning is context, not a model sentence")
        XCTAssertEqual(descriptor.exercise.targetLanguage, "de")
    }

    func testWritingRetrievalReturnsNilWithoutCards() async throws {
        let retrieval = CardBackedWritingRetrieval(cards: StaticCardSource(cards: []), repository: InMemoryPracticeRepository(), clock: CatalogClock(date: now), sourceLanguage: "fa", targetLanguage: "de")
        let descriptor = try await retrieval.nextWritingExercise(learnerID: "local", cefrLevel: "A1", seed: 0)
        XCTAssertNil(descriptor)
    }

    func testCompletedOccurrenceStartsAFreshExerciseWhileProgressKeepsEvidence() async throws {
        let repository = InMemoryPracticeRepository()
        let clock = CatalogClock(date: now)
        let retrieval = CardBackedWritingRetrieval(cards: StaticCardSource(cards: [card(1, "arbeiten")]), repository: repository, clock: clock, sourceLanguage: "fa", targetLanguage: "de")
        let session = PracticeSessionService(repository: repository, evaluator: CorrectEvaluator(), clock: clock)

        let firstCandidate = try await retrieval.nextWritingExercise(learnerID: "local", cefrLevel: "A2", seed: 0)
        let first = try XCTUnwrap(firstCandidate)
        _ = try await session.prepare(exercise: first.exercise)
        _ = try await session.submit(exercise: first.exercise, response: "Ich arbeite heute.")

        let secondCandidate = try await retrieval.nextWritingExercise(learnerID: "local", cefrLevel: "A2", seed: 0)
        let second = try XCTUnwrap(secondCandidate)
        XCTAssertEqual(second.exercise.reviewUnit, first.exercise.reviewUnit)
        XCTAssertNotEqual(second.exercise.id, first.exercise.id, "A completed occurrence must not be reopened")

        let fresh = try await PracticeSessionService(repository: repository, evaluator: CorrectEvaluator(), clock: clock).prepare(exercise: second.exercise)
        XCTAssertEqual(fresh.state, .answering)
        XCTAssertTrue(fresh.attempts.isEmpty)

        let progress = PracticeProgressCalculator.summarize(skill: .writing, units: try await repository.unitProgress(skill: .writing, learnerID: "local"))
        XCTAssertEqual(progress.evidencedUnitCount, 1)
        XCTAssertNotNil(progress.averageMastery)
    }

    func testInterruptedOccurrenceIsResumedWithTheSameExercise() async throws {
        let repository = InMemoryPracticeRepository()
        let clock = CatalogClock(date: now)
        let unit = ReviewUnit(learnerID: "local", skill: .writing, objectiveKey: CardBackedWritingRetrieval.objectiveKey(cardID: card(1, "x").cardID))
        let exercise = ExerciseInstance(id: PracticeOccurrence.exerciseID(for: unit, attempts: []), reviewUnit: unit, prompt: "x", sourceLanguage: "fa", targetLanguage: "de")
        let session = PracticeSessionService(repository: repository, evaluator: CorrectEvaluator(), clock: clock)
        _ = try await session.prepare(exercise: exercise)
        _ = try await session.reveal(exerciseID: exercise.id)

        let attempts = try await repository.attempts(for: unit)
        XCTAssertEqual(attempts.last?.outcome, .pending)
        XCTAssertEqual(PracticeOccurrence.exerciseID(for: unit, attempts: attempts), exercise.id)
    }

    func testProgressWithoutIndependentEvidenceIsNotZero() {
        let unit = ReviewUnit(skill: .grammar, objectiveKey: "g")
        let summary = PracticeProgressCalculator.summarize(skill: .grammar, units: [PracticeUnitProgress(unit: unit, projection: PracticeMasteryProjection())])
        XCTAssertNil(summary.averageMastery)
        XCTAssertFalse(summary.hasEvidence)
        XCTAssertNil(PracticeProgressCalculator.weakestSkill([summary], available: [.grammar]))
    }

    func testWeakestSkillUsesOnlyAvailableEvidencedSkills() {
        let summaries = [
            PracticeSkillProgress(skill: .writing, evidencedUnitCount: 2, averageMastery: 0.8),
            PracticeSkillProgress(skill: .listening, evidencedUnitCount: 1, averageMastery: 0.3),
            PracticeSkillProgress(skill: .grammar, evidencedUnitCount: 1, averageMastery: 0.1)
        ]
        XCTAssertEqual(PracticeProgressCalculator.weakestSkill(summaries, available: [.writing, .listening]), .listening)
    }

    func testListeningUsesOnlyReviewedExamplesAndStoresTheSentenceRevision() async throws {
        let repository = InMemoryPracticeRepository()
        let source = StaticCardSource(cards: [card(1, "arbeiten", review: .unreviewed), card(2, "lernen")])
        let retrieval = CardSentenceListeningRetrieval(cards: source, repository: repository, clock: CatalogClock(date: now), sourceLanguage: "fa", targetLanguage: "de")

        let hasMaterial = try await retrieval.hasMaterial()
        XCTAssertTrue(hasMaterial)
        let descriptorCandidate = try await retrieval.nextListeningExercise(learnerID: "local", seed: 0)
        let descriptor = try XCTUnwrap(descriptorCandidate)
        XCTAssertEqual(descriptor.sentence.text, "Ich lernen heute.")
        XCTAssertEqual(descriptor.exercise.reviewUnit.sentenceID, descriptor.sentence.id)
        XCTAssertEqual(descriptor.exercise.reviewUnit.sentenceRevision, descriptor.sentence.revision)
        let stored = try await repository.sentence(id: descriptor.sentence.id, revision: descriptor.sentence.revision)
        XCTAssertEqual(stored?.translation, "translation 2")

        let unreviewedOnly = CardSentenceListeningRetrieval(cards: StaticCardSource(cards: [card(1, "x", review: .unreviewed)]), repository: repository, clock: CatalogClock(date: now), sourceLanguage: "fa", targetLanguage: "de")
        let noMaterial = try await unreviewedOnly.hasMaterial()
        XCTAssertFalse(noMaterial)
    }

    func testCapabilityGateExplainsEveryUnavailableMode() {
        let none = PracticeCapabilityFacts(hasCards: false, hasReviewedSentences: false, hasReviewedGrammarContent: false, sentenceAudioAvailable: false, pronunciationValidated: false, evaluator: .notConfigured)
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .writing, facts: none), .unavailable(.noCards))
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .grammar, facts: none), .unavailable(.noReviewedGrammarContent))
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .listening, facts: none), .unavailable(.noReviewedSentences))
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .speaking, facts: none), .unavailable(.pronunciationNotValidated))

        let noAudio = PracticeCapabilityFacts(hasCards: true, hasReviewedSentences: true, hasReviewedGrammarContent: true, sentenceAudioAvailable: false, pronunciationValidated: false, evaluator: .consentRequired)
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .listening, facts: noAudio), .unavailable(.sentenceAudioUnavailable))
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .writing, facts: noAudio), .available(.ungradedConsentRequired))

        let ready = PracticeCapabilityFacts(hasCards: true, hasReviewedSentences: true, hasReviewedGrammarContent: true, sentenceAudioAvailable: true, pronunciationValidated: false, evaluator: .ready)
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .grammar, facts: ready), .available(.graded))
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .speaking, facts: ready), .unavailable(.pronunciationNotValidated))
    }

    func testEvaluatorRouterDispatchesBySkillAndNeverCrossGrades() async throws {
        let router = PracticeEvaluatorRouter(evaluators: [.writing: SkillTaggingEvaluator(tag: "writing-evaluator")])
        let writing = ExerciseInstance(reviewUnit: ReviewUnit(skill: .writing, objectiveKey: "w"), prompt: "w", sourceLanguage: "fa", targetLanguage: "de")
        let grammar = ExerciseInstance(reviewUnit: ReviewUnit(skill: .grammar, objectiveKey: "g"), prompt: "g", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(exerciseID: writing.id, reviewUnitID: writing.reviewUnit.id, response: "x", submittedAt: now, attemptIndex: 0)

        let writingResult = try await router.evaluate(attempt, exercise: writing)
        let grammarResult = try await router.evaluate(attempt, exercise: grammar)
        XCTAssertEqual(writingResult.evaluatorVersion, "writing-evaluator")
        XCTAssertEqual(grammarResult.outcome, .unavailable)
        XCTAssertEqual(grammarResult.evaluatorVersion, PracticeEvaluatorRouter.unroutedEvaluatorVersion)
        XCTAssertTrue(router.handles(.writing))
        XCTAssertFalse(router.handles(.listening))
    }

    func testGRDBProgressReadsPersistedProjections() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-progress-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = try GRDBPracticeRepository(url: url)
        let unit = ReviewUnit(learnerID: "local", skill: .writing, objectiveKey: "writing.card.test")
        try await repository.saveReviewUnit(unit, projection: PracticeMasteryProjection(state: .learning, score: 0.6, independentEvidenceCount: 1, independentScoreTotal: 0.6))
        try await repository.saveReviewUnit(ReviewUnit(learnerID: "local", skill: .grammar, objectiveKey: "g"), projection: nil)

        let writing = try await repository.unitProgress(skill: .writing, learnerID: "local")
        XCTAssertEqual(writing.map(\.unit), [unit])
        XCTAssertEqual(writing.first?.projection?.score, 0.6)
        XCTAssertEqual(PracticeProgressCalculator.summarize(skill: .writing, units: writing).averageMastery, 0.6)
        let other = try await repository.unitProgress(skill: .writing, learnerID: "someone-else")
        XCTAssertTrue(other.isEmpty)
    }

    func testProgressIsLimitedToTheActiveLanguagePair() async throws {
        let repository = InMemoryPracticeRepository()
        let clock = CatalogClock(date: now)
        let german = card(1, "arbeiten")
        let english = card(2, "work", source: "fa", destination: "en")
        let session = PracticeSessionService(repository: repository, evaluator: CorrectEvaluator(), clock: clock)
        for (pairCard, target) in [(german, "de"), (english, "en")] {
            let retrieval = CardBackedWritingRetrieval(cards: StaticCardSource(cards: [pairCard]), repository: repository, clock: clock, sourceLanguage: "fa", targetLanguage: target)
            let candidate = try await retrieval.nextWritingExercise(learnerID: "local", cefrLevel: "A2", seed: 0)
            let descriptor = try XCTUnwrap(candidate)
            _ = try await session.prepare(exercise: descriptor.exercise)
            _ = try await session.submit(exercise: descriptor.exercise, response: "answer")
        }

        let keys: [PracticeSkill: Set<String>] = [
            .writing: PracticeCatalogKeys.objectiveKeys(skill: .writing, cards: [german]),
            .listening: PracticeCatalogKeys.objectiveKeys(skill: .listening, cards: [german])
        ]
        let summaries = try await PracticeProgressCalculator.summaries(skills: [.writing, .listening], learnerID: "local", objectiveKeys: keys, reader: repository)
        XCTAssertEqual(summaries.map(\.skill), [.writing, .listening])
        XCTAssertEqual(summaries[0].evidencedUnitCount, 1, "Only the German card's unit counts for the German pair")
        XCTAssertNil(summaries[1].averageMastery)
    }

    func testListeningKeysMatchTheUnitsTheRetrievalCreates() async throws {
        let repository = InMemoryPracticeRepository()
        let reviewed = card(1, "arbeiten")
        let retrieval = CardSentenceListeningRetrieval(cards: StaticCardSource(cards: [reviewed, card(2, "lernen", review: .unreviewed)]), repository: repository, clock: CatalogClock(date: now), sourceLanguage: "fa", targetLanguage: "de")
        let candidate = try await retrieval.nextListeningExercise(learnerID: "local", seed: 0)
        let descriptor = try XCTUnwrap(candidate)
        XCTAssertEqual(PracticeCatalogKeys.objectiveKeys(skill: .listening, cards: [reviewed, card(2, "lernen", review: .unreviewed)]), [descriptor.exercise.reviewUnit.objectiveKey])
        XCTAssertEqual(PracticeCatalogKeys.objectiveKeys(skill: .grammar, cards: [reviewed]), [])
    }

    func testCapabilityFactsAreDerivedFromCards() {
        let none = PracticeCapabilityFacts(cards: [], hasReviewedGrammarContent: false, sentenceAudioAvailable: true, pronunciationValidated: false, evaluator: .notConfigured)
        XCTAssertFalse(none.hasCards)
        XCTAssertFalse(none.hasReviewedSentences)
        let unreviewed = PracticeCapabilityFacts(cards: [card(1, "x", review: .unreviewed)], hasReviewedGrammarContent: false, sentenceAudioAvailable: true, pronunciationValidated: false, evaluator: .notConfigured)
        XCTAssertTrue(unreviewed.hasCards)
        XCTAssertFalse(unreviewed.hasReviewedSentences)
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .listening, facts: unreviewed), .unavailable(.noReviewedSentences))
        XCTAssertEqual(PracticeCapabilityGate.availability(for: .writing, facts: unreviewed), .available(.ungradedNoProvider))
    }


    private func grammarCatalog(reviewed: Bool) -> GrammarContentCatalog {
        let rule = GrammarRule(code: "de.preposition.case", category: "preposition", targetLanguage: "de", grammaticalRole: "preposition_case")
        let entry = GrammarTemplateEntry(
            id: "mit-1", reviewStatus: reviewed ? .reviewed : .pendingReview, draftedBy: "assistant",
            reviewedBy: reviewed ? "teacher" : nil, reviewedAt: reviewed ? "2026-10-13" : nil,
            sourceLanguage: "fa", targetLanguage: "de", cefrLevel: "A2", mode: .explainError, ruleCode: rule.code,
            grammaticalRole: rule.grammaticalRole, prompt: "Ich fahre mit der Bus.", referenceAnswer: "Ich fahre mit dem Bus.",
            referenceExplanation: "mit + Dativ", hints: ["mit"], errorSpan: "der Bus"
        )
        return GrammarContentCatalog(rules: [rule], templates: [entry])
    }

    func testGrammarDraftsAreNeverOffered() async throws {
        let draft = grammarCatalog(reviewed: false)
        XCTAssertFalse(draft.hasReviewedContent(learnerID: "local", sourceLanguage: "fa", targetLanguage: "de"))
        let retrieval = CuratedGrammarRetrieval(catalog: draft, repository: InMemoryPracticeRepository(), clock: CatalogClock(date: now), sourceLanguage: "fa", targetLanguage: "de")
        let exercise = try await retrieval.nextGrammarExercise(learnerID: "local", seed: 0)
        XCTAssertNil(exercise)
        XCTAssertNil(draft.curatedEntry(objectiveKey: "grammar.mit-1"))
    }

    func testReviewedGrammarStartsAFreshOccurrenceAfterCompletion() async throws {
        let catalog = grammarCatalog(reviewed: true)
        XCTAssertTrue(catalog.hasReviewedContent(learnerID: "local", sourceLanguage: "fa", targetLanguage: "de"))
        XCTAssertFalse(catalog.hasReviewedContent(learnerID: "local", sourceLanguage: "en", targetLanguage: "de"))
        XCTAssertEqual(catalog.objectiveKeys(learnerID: "local", sourceLanguage: "fa", targetLanguage: "de"), ["grammar.mit-1"])
        let repository = InMemoryPracticeRepository()
        let clock = CatalogClock(date: now)
        let retrieval = CuratedGrammarRetrieval(catalog: catalog, repository: repository, clock: clock, sourceLanguage: "fa", targetLanguage: "de")
        let firstCandidate = try await retrieval.nextGrammarExercise(learnerID: "local", seed: 0)
        let first = try XCTUnwrap(firstCandidate)
        XCTAssertEqual(first.exercise.reviewUnit.objectiveKey, "grammar.mit-1")
        XCTAssertEqual(first.cleanSource, "curated")
        let session = PracticeSessionService(repository: repository, evaluator: CorrectEvaluator(), clock: clock)
        _ = try await session.prepare(exercise: first.exercise)
        _ = try await session.submit(exercise: first.exercise, response: "mit verlangt den Dativ")
        let secondCandidate = try await retrieval.nextGrammarExercise(learnerID: "local", seed: 0)
        let second = try XCTUnwrap(secondCandidate)
        XCTAssertEqual(second.exercise.reviewUnit, first.exercise.reviewUnit)
        XCTAssertNotEqual(second.exercise.id, first.exercise.id)
    }

    func testReviewedEntryNeedsAReviewerAndDate() {
        let entry = GrammarTemplateEntry(id: "x", reviewStatus: .reviewed, sourceLanguage: "fa", targetLanguage: "de", cefrLevel: "A1", mode: .explainUsage, ruleCode: "r", grammaticalRole: "g", prompt: "p", referenceAnswer: "a", referenceExplanation: "e")
        XCTAssertFalse(entry.isCurated)
        XCTAssertEqual(entry.template(learnerID: "local").cleanSource, "draft")
    }
}
