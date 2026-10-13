import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication
@testable import LinguaBrainTestSupport

final class PracticeFakeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    func testFixedIDsAndSchedulerProduceRepeatableValues() {
        let ids = FixedPracticeIDs.fixture
        XCTAssertEqual(ids.exerciseID.uuidString, "00000000-0000-0000-0000-000000000101")
        let scheduler = RecordingPracticeScheduler()
        let projection = scheduler.schedule(previous: nil, rating: .good, at: now)
        XCTAssertEqual(projection.dueAt, now.addingTimeInterval(86_400))
        XCTAssertEqual(scheduler.ratings, [.good])
    }

    func testScriptedEvaluatorSupportsDelayedReleaseAndCancellation() async throws {
        let ids = FixedPracticeIDs.fixture
        let unit = ReviewUnit(id: ids.reviewUnitID, skill: .speaking, objectiveKey: "fake")
        let exercise = ExerciseInstance(id: ids.exerciseID, reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(id: ids.firstAttemptID, exerciseID: exercise.id, reviewUnitID: unit.id, response: "antwort", submittedAt: now)
        let evaluator = ScriptedPracticeEvaluator(steps: [.delayed(EvaluationResult(outcome: .correct)), .cancellation])
        let pending = Task { try await evaluator.evaluate(attempt, exercise: exercise) }
        for _ in 0..<20 {
            if !(await evaluator.pendingAttemptIDs().isEmpty) { break }
            await Task.yield()
        }
        let pendingIDs = await evaluator.pendingAttemptIDs()
        XCTAssertEqual(pendingIDs, [attempt.id])
        await evaluator.release(attemptID: attempt.id, with: EvaluationResult(outcome: .partial, score: 0.5))
        let released = try await pending.value
        XCTAssertEqual(released.outcome, .partial)

        let cancellation = Task { try await evaluator.evaluate(attempt, exercise: exercise) }
        do { _ = try await cancellation.value; XCTFail("expected scripted cancellation") } catch is CancellationError { }
    }

    func testScriptedMediaAndRepositoryFailureInjectionAreDeterministic() async throws {
        let ids = FixedPracticeIDs.fixture
        let unit = ReviewUnit(id: ids.reviewUnitID, skill: .listening, objectiveKey: "media")
        let sentence = Sentence(id: ids.sentenceID, revision: 1, text: "Haus", translation: "خانه")
        let media = MediaAsset(kind: .audio, locale: "de-DE", checksum: "fixture", provider: "fake", model: "fake", generatedAt: now)
        let mediaFake = ScriptedPracticeMedia(audio: .success(media), recording: .success(Data([1, 2, 3])), pronunciation: .success(EvaluationResult(outcome: .correct)))
        let audio = try await mediaFake.sentenceAudio(for: sentence)
        XCTAssertEqual(audio, media)
        let recording = try await mediaFake.record()
        XCTAssertEqual(recording, Data([1, 2, 3]))
        let pronunciation = try await mediaFake.assessPronunciation(Data(), sentence: sentence)
        XCTAssertEqual(pronunciation.outcome, .correct)

        let repository = DeterministicPracticeRepository()
        try await repository.saveReviewUnit(unit)
        let attempt = Attempt(id: ids.firstAttemptID, exerciseID: ids.exerciseID, reviewUnitID: unit.id, response: "saved", submittedAt: now)
        await repository.failNextTransaction()
        do {
            try await repository.transaction { try await repository.saveAttempt(attempt) }
            XCTFail("expected injected transaction failure")
        } catch PracticeFakeError.injectedTransactionFailure { }
        let missing = try await repository.attempt(id: attempt.id)
        XCTAssertNil(missing)
        try await repository.saveAttempt(attempt)
        let saved = try await repository.attempt(id: attempt.id)
        XCTAssertEqual(saved, attempt)
    }

    func testDeterministicRepositoryAndReviewServiceCoverAllFourSkillsIndependently() async throws {
        let repository = DeterministicPracticeRepository()
        let scheduler = RecordingPracticeScheduler()
        let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: FixedPracticeClock(date: now))
        let unitIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000204")!
        ]
        let attemptIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000211")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000212")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000213")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000214")!
        ]
        for (index, skill) in PracticeSkill.allCases.enumerated() {
            let unit = ReviewUnit(id: unitIDs[index], skill: skill, objectiveKey: "independent-\(skill.rawValue)")
            try await repository.saveReviewUnit(unit)
            let attempt = Attempt(id: attemptIDs[index], exerciseID: UUID(uuidString: "00000000-0000-0000-0000-000000000220")!, reviewUnitID: unit.id, response: "answer", submittedAt: now, idempotencyKey: IdempotencyKey(rawValue: "fake-\(index)"))
            let result = try await service.apply(attempt: attempt, evaluation: EvaluationResult(outcome: .correct))
            XCTAssertEqual(result.learningEvent.skill, skill)
            XCTAssertEqual(result.projection.independentEvidenceCount, 1)
        }
        XCTAssertEqual(scheduler.callCount, PracticeSkill.allCases.count)
    }
}
