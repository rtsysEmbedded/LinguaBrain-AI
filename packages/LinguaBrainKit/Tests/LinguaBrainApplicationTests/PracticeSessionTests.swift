import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication
@testable import LinguaBrainPersistence

private struct FixedClock: PracticeClock { let date: Date; func now() -> Date { date } }
private struct FakeEvaluator: PracticeEvaluator { func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult { EvaluationResult(outcome: .correct, feedback: [TypedFeedback(message: "ok")]) } }
private struct CancellationEvaluator: PracticeEvaluator { func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult { throw CancellationError() } }
private struct PartialEvaluator: PracticeEvaluator { func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult { EvaluationResult(outcome: .partial, score: 0.5, confidence: 0.9, feedback: [TypedFeedback(message: "almost")], rules: [RuleReference(code: "R-1")], evaluatorVersion: "fixture-1") } }
private struct SequenceEvaluator: PracticeEvaluator {
    let outcomes: [AttemptOutcome]
    func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult { EvaluationResult(outcome: outcomes[min(attempt.attemptIndex, outcomes.count - 1)]) }
}
private enum TestFailure: Error { case expected }

private actor DelayedEvaluator: PracticeEvaluator {
    var continuations: [CheckedContinuation<EvaluationResult, Never>] = []
    var started = 0
    var startedWaiter: (Int, CheckedContinuation<Void, Never>)?
    func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        started += 1
        if let waiter = startedWaiter, started >= waiter.0 { startedWaiter = nil; waiter.1.resume() }
        return await withCheckedContinuation { continuations.append($0) }
    }
    func waitUntilStarted(_ count: Int) async { if started >= count { return }; await withCheckedContinuation { startedWaiter = (count, $0) } }
    func finishNext() { guard !continuations.isEmpty else { return }; continuations.removeFirst().resume(returning: EvaluationResult(outcome: .correct)) }
}

final class PracticeSessionTests: XCTestCase {
    func testResponseIsPersistedWhenEvaluatorFails() async throws {
        struct Failing: PracticeEvaluator { func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult { throw ProviderError.unavailable(reason: "offline") } }
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .writing, objectiveKey: "w"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        _ = try await PracticeSessionService(repository: repo, evaluator: Failing(), clock: FixedClock(date: Date(timeIntervalSince1970: 1))).submit(exercise: exercise, response: "antwort")
        let attempts = try await repo.attempts(for: unit); XCTAssertEqual(attempts.count, 1); XCTAssertEqual(attempts[0].outcome, .unavailable); XCTAssertEqual(attempts[0].response, "antwort")
    }
    func testSuccessfulEvaluationIsGraded() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .listening, objectiveKey: "l"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let result = try await PracticeSessionService(repository: repo, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 1))).submit(exercise: exercise, response: "verstanden")
        XCTAssertEqual(result.outcome, .correct)
        let attempts = try await repo.attempts(for: unit)
        XCTAssertEqual(attempts.count, 1)
    }

    func testPrepareHelpRevealRetryAndAssistanceEvidence() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .writing, objectiveKey: "w2"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 1)))
        let prepared = try await service.prepare(exercise: exercise); XCTAssertEqual(prepared.state, .answering)
        _ = try await service.requestHint(exerciseID: exercise.id)
        let revealed = try await service.reveal(exerciseID: exercise.id, answerCopied: true); XCTAssertEqual(revealed.state, .revealed)
        _ = try await service.retry(exerciseID: exercise.id)
        let attempt = try await service.submit(exercise: exercise, response: "copied")
        XCTAssertEqual(attempt.outcome, .correct); XCTAssertFalse(PracticeEvidencePolicy.countsAsIndependentRecall(outcome: attempt.outcome, help: attempt.help))
        let finished = try await service.continue(exerciseID: exercise.id); XCTAssertEqual(finished.state, .finished)
    }

    func testDuplicateSubmitCreatesOneAttemptAndLateResultCannotGradeRetry() async throws {
        let repo = InMemoryPracticeRepository(); let evaluator = DelayedEvaluator(); let unit = ReviewUnit(skill: .listening, objectiveKey: "late"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: evaluator, clock: FixedClock(date: Date(timeIntervalSince1970: 1)))
        let first = Task { try await service.submit(exercise: exercise, response: "first") }
        await evaluator.waitUntilStarted(1)
        let duplicate = try await service.submit(exercise: exercise, response: "first")
        XCTAssertEqual(duplicate.outcome, .pending); let duringEvaluation = try await repo.attempts(for: unit); XCTAssertEqual(duringEvaluation.count, 1)
        _ = try await service.retry(exerciseID: exercise.id)
        let second = Task { try await service.submit(exercise: exercise, response: "second") }
        await evaluator.waitUntilStarted(2); await evaluator.finishNext(); _ = try await first.value; await evaluator.finishNext(); _ = try await second.value
        let attempts = try await repo.attempts(for: unit); XCTAssertEqual(attempts.count, 2); XCTAssertEqual(attempts.first(where: { $0.response == "first" })?.outcome, .pending); XCTAssertEqual(attempts.first(where: { $0.response == "second" })?.outcome, .correct)
    }

    func testCancellationLeavesSavedAttemptUnavailableWithoutThrowing() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .speaking, objectiveKey: "cancel"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let result = try await PracticeSessionService(repository: repo, evaluator: CancellationEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 1))).submit(exercise: exercise, response: "audio")
        XCTAssertEqual(result.outcome, .unavailable)
        let cancelledAttempts = try await repo.attempts(for: unit); XCTAssertEqual(cancelledAttempts.first?.outcome, .unavailable)
    }

    func testRevealBeforeSubmitIsDurableAndSuppressesIndependentRecall() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .writing, objectiveKey: "reveal-before-submit"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 10)))
        _ = try await service.prepare(exercise: exercise)
        _ = try await service.reveal(exerciseID: exercise.id, answerCopied: true)
        let persistedBeforeSubmit = try await repo.attempts(for: unit)
        XCTAssertEqual(persistedBeforeSubmit.count, 1)
        XCTAssertEqual(persistedBeforeSubmit[0].outcome, .pending)
        XCTAssertEqual(Set(persistedBeforeSubmit[0].help.map(\.kind)), Set([.reveal, .copiedAnswer]))
        XCTAssertEqual(Set(persistedBeforeSubmit[0].events.map(\.kind)), Set([.reveal, .copiedAnswer]))

        let completed = try await service.submit(exercise: exercise, response: "copied")
        XCTAssertEqual(completed.outcome, .correct)
        XCTAssertFalse(PracticeEvidencePolicy.countsAsIndependentRecall(outcome: completed.outcome, help: completed.help))
        let events = try await repo.learningEvents(for: unit)
        XCTAssertEqual(events.count, 1)
        XCTAssertFalse(events[0].schedulingEligible)
    }

    func testSkipIsPersistedAndHasNoMasteryOrSchedulingEffect() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .grammar, objectiveKey: "skip"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 20)))
        _ = try await service.prepare(exercise: exercise)
        let skipped = try await service.skip(exerciseID: exercise.id)
        XCTAssertEqual(skipped.state, .finished)
        XCTAssertEqual(skipped.currentAttempt?.outcome, .skipped)
        let events = try await repo.learningEvents(for: unit)
        XCTAssertEqual(events.map(\.outcome), [.skipped])
        XCTAssertFalse(events[0].schedulingEligible)
        let projection = try await repo.projection(for: unit.id)
        XCTAssertEqual(projection, PracticeMasteryProjection())
        let repeatedSkip = try await service.skip(exerciseID: exercise.id)
        XCTAssertEqual(repeatedSkip.state, .finished)
    }

    func testPartialOutcomeAndEvaluatorEvidenceReachReviewBoundaryUnchanged() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .listening, objectiveKey: "partial"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let result = try await PracticeSessionService(repository: repo, evaluator: PartialEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 30))).submit(exercise: exercise, response: "fast richtig")
        XCTAssertEqual(result.outcome, .partial)
        XCTAssertEqual(result.evaluatorResult?.score, 0.5)
        XCTAssertEqual(result.evaluatorResult?.evaluatorVersion, "fixture-1")
        XCTAssertEqual(result.rules, [RuleReference(code: "R-1")])
        let projection = try await repo.projection(for: unit.id)
        XCTAssertEqual(projection?.independentEvidenceCount, 1)
        XCTAssertEqual(projection?.independentScoreTotal, 0.5)
    }

    func testRetryPreservesFirstAttemptAndOnlyRetryIsASeparateSubmission() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .speaking, objectiveKey: "retry-preserve"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: SequenceEvaluator(outcomes: [.incorrect, .correct]), clock: FixedClock(date: Date(timeIntervalSince1970: 40)))
        let first = try await service.submit(exercise: exercise, response: "first")
        XCTAssertEqual(first.outcome, .incorrect)
        _ = try await service.retry(exerciseID: exercise.id)
        let repeatedRetry = try await service.retry(exerciseID: exercise.id)
        XCTAssertEqual(repeatedRetry.attempts.count, 2)
        let second = try await service.submit(exercise: exercise, response: "second")
        XCTAssertEqual(second.outcome, .correct)
        let attempts = try await repo.attempts(for: unit)
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts[0].response, "first")
        XCTAssertEqual(attempts[0].outcome, .incorrect)
        XCTAssertEqual(attempts[1].response, "second")
        XCTAssertEqual(attempts[1].events.map(\.kind), [.retry])
    }

    func testRepeatedContinueIsIdempotentAndRetryLimitFinishesSession() async throws {
        let repo = InMemoryPracticeRepository(); let unit = ReviewUnit(skill: .writing, objectiveKey: "bounded"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 50)), maximumAttempts: 1)
        _ = try await service.submit(exercise: exercise, response: "one")
        let firstContinue = try await service.continue(exerciseID: exercise.id)
        XCTAssertEqual(firstContinue.state, .finished)
        let repeatedContinue = try await service.continue(exerciseID: exercise.id)
        XCTAssertEqual(repeatedContinue.state, .finished)
        let retryAfterFinish = try await service.retry(exerciseID: exercise.id)
        XCTAssertEqual(retryAfterFinish.state, .finished)
        let attempts = try await repo.attempts(for: unit)
        XCTAssertEqual(attempts.count, 1)
    }

    func testResumeRebuildsRevealAndInterruptedResponseFromGRDB() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-session-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let unit = ReviewUnit(skill: .listening, objectiveKey: "resume"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let firstRepository = try GRDBPracticeRepository(url: url)
        let firstService = PracticeSessionService(repository: firstRepository, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 60)))
        _ = try await firstService.prepare(exercise: exercise)
        _ = try await firstService.reveal(exerciseID: exercise.id)
        let resumedReveal = try await PracticeSessionService(repository: firstRepository, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 60))).resume(exercise: exercise)
        XCTAssertEqual(resumedReveal.state, .revealed)
        XCTAssertEqual(resumedReveal.help.map(\.kind), [.reveal])

        let interrupted = Attempt(id: UUID(uuidString: "00000000-0000-0000-0000-000000000061")!, exerciseID: exercise.id, reviewUnitID: unit.id, response: "saved before crash", submittedAt: Date(timeIntervalSince1970: 61), outcome: .pending)
        try await firstRepository.saveAttempt(interrupted)
        let recovered = try await PracticeSessionService(repository: firstRepository, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 62))).resume(exercise: exercise)
        XCTAssertEqual(recovered.state, .unavailable)
        XCTAssertEqual(recovered.currentAttempt?.response, "saved before crash")
    }

    func testFailedPreEvaluationTransactionLeavesNoDraftOrHelpState() async throws {
        let repo = InMemoryPracticeRepository(); await repo.failNextTransaction(); let unit = ReviewUnit(skill: .grammar, objectiveKey: "atomic-session"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let service = PracticeSessionService(repository: repo, evaluator: FakeEvaluator(), clock: FixedClock(date: Date(timeIntervalSince1970: 70)))
        _ = try await service.prepare(exercise: exercise)
        do { _ = try await service.reveal(exerciseID: exercise.id); XCTFail("expected durable help transaction to fail") } catch is PracticePersistenceError {}
        let attempts = try await repo.attempts(for: unit)
        XCTAssertTrue(attempts.isEmpty)
        let resumed = try await service.prepare(exercise: exercise)
        XCTAssertEqual(resumed.help, [])
    }

    func testFileRepositoryRollsBackAndSurvivesReopen() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let repo = try FileBackedPracticeRepository(url: url); let unit = ReviewUnit(skill: .grammar, objectiveKey: "persist"); let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let saved = Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "r", submittedAt: Date(timeIntervalSince1970: 1)); try await repo.saveAttempt(saved)
        let second = Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "rollback", submittedAt: Date(timeIntervalSince1970: 2))
        do { try await repo.transaction { try await repo.saveAttempt(second); throw TestFailure.expected } } catch TestFailure.expected {}
        let rolledBack = try await repo.attempt(id: second.id); XCTAssertNil(rolledBack); let reopened = try FileBackedPracticeRepository(url: url); let reopenedAttempt = try await reopened.attempt(id: saved.id); XCTAssertEqual(reopenedAttempt?.response, "r")
    }
}
