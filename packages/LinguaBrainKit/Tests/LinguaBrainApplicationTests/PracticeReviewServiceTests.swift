import Foundation
import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication
@testable import LinguaBrainPersistence

private struct ReviewFixedClock: PracticeClock, Sendable { let value: Date; func now() -> Date { value } }

private final class RecordingFSRS: PracticeFSRSScheduler, @unchecked Sendable {
    let algorithmVersion = "FSRS-6.0/test"
    private let lock = NSLock()
    private(set) var ratings: [PracticeScheduleRating] = []
    func schedule(previous: PracticeMasteryProjection?, rating: PracticeScheduleRating, at: Date) -> PracticeMasteryProjection {
        lock.lock(); ratings.append(rating); lock.unlock()
        let seconds: TimeInterval = switch rating { case .good: 86_400; case .hard: 43_200; case .again: 600 }
        return PracticeMasteryProjection(state: .learning, dueAt: at.addingTimeInterval(seconds), algorithmVersion: algorithmVersion, schedulerState: rating.rawValue, independentEvidenceCount: previous?.independentEvidenceCount ?? 0, independentScoreTotal: previous?.independentScoreTotal ?? 0)
    }
    var callCount: Int { lock.lock(); defer { lock.unlock() }; return ratings.count }
}

final class PracticeReviewServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    private func unit(_ skill: PracticeSkill, _ suffix: String = "") -> ReviewUnit {
        ReviewUnit(learnerID: "learner", skill: skill, objectiveKey: "objective-\(skill.rawValue)-\(suffix)")
    }

    private func attempt(for unit: ReviewUnit, index: Int = 0, help: [HelpEvent] = [], events: [PracticeEvent] = []) -> Attempt {
        Attempt(id: UUID(), exerciseID: UUID(), reviewUnitID: unit.id, response: "learner response", submittedAt: now, attemptIndex: index, idempotencyKey: IdempotencyKey(rawValue: "request-\(unit.id)-\(index)"), help: help, events: events)
    }

    func testCorrectPartialAndIncorrectMapToMasteryAndFSRSOnce() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now))
        for (skill, outcome, expectedScore, expectedRating) in [(PracticeSkill.writing, AttemptOutcome.correct, 1.0, PracticeScheduleRating.good), (.grammar, .partial, 0.5, .hard), (.listening, .incorrect, 0.0, .again)] {
            let reviewUnit = unit(skill); try await repository.saveReviewUnit(reviewUnit)
            let result = try await service.apply(attempt: attempt(for: reviewUnit), evaluation: EvaluationResult(outcome: outcome))
            XCTAssertEqual(result.decision.outcome, outcome); XCTAssertEqual(result.decision.score, expectedScore); XCTAssertEqual(result.decision.masteryDelta, expectedScore); XCTAssertEqual(result.learningEvent.scheduleRating, expectedRating)
            XCTAssertEqual(result.projection.independentEvidenceCount, 1); XCTAssertEqual(result.projection.score, expectedScore); XCTAssertEqual(result.projection.dueAt, now.addingTimeInterval(expectedRating == .good ? 86_400 : expectedRating == .hard ? 43_200 : 600))
        }
        XCTAssertEqual(scheduler.callCount, 3)
    }

    func testRevealAndCopiedAnswerNeverCreateIndependentEffect() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now)); let reviewUnit = unit(.speaking); try await repository.saveReviewUnit(reviewUnit)
        let revealed = try await service.apply(attempt: attempt(for: reviewUnit, help: [HelpEvent(kind: .reveal, at: now)]), evaluation: EvaluationResult(outcome: .correct))
        XCTAssertEqual(revealed.decision.outcome, .correct); XCTAssertFalse(revealed.decision.independentRecallEligible); XCTAssertNil(revealed.decision.scheduleRating); XCTAssertEqual(revealed.projection, PracticeMasteryProjection());
        let copied = try await service.apply(attempt: attempt(for: reviewUnit, index: 1, help: [HelpEvent(kind: .copiedAnswer, at: now)]), evaluation: EvaluationResult(outcome: .correct))
        let events = try await repository.learningEvents(for: reviewUnit)
        XCTAssertFalse(copied.learningEvent.schedulingEligible); XCTAssertEqual(events.count, 2); XCTAssertEqual(scheduler.callCount, 0)
    }

    func testSkipUnavailableCancellationAndMalformedOutputRemainUngraded() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now)); let reviewUnit = unit(.listening); try await repository.saveReviewUnit(reviewUnit)
        let skipped = try await service.apply(attempt: attempt(for: reviewUnit, events: [PracticeEvent(kind: .skip, at: now)]), evaluation: EvaluationResult(outcome: .correct)); XCTAssertEqual(skipped.attempt.outcome, .skipped); XCTAssertEqual(skipped.decision.masteryDelta, 0)
        let cancelled = try await service.apply(attempt: attempt(for: reviewUnit, index: 1), evaluation: .unavailable(reason: .cancelled)); XCTAssertEqual(cancelled.attempt.outcome, .unavailable); XCTAssertEqual(cancelled.learningEvent.unavailableReason, .cancelled)
        let malformed = try await service.apply(attempt: attempt(for: reviewUnit, index: 2), evaluation: EvaluationResult(outcome: .incorrect, score: 4)); XCTAssertEqual(malformed.attempt.outcome, .unavailable); XCTAssertEqual(malformed.learningEvent.unavailableReason, .malformedOutput)
        let projection = try await repository.projection(for: reviewUnit.id)
        XCTAssertEqual(scheduler.callCount, 0); XCTAssertNil(projection)
    }

    func testRetryPreservesFirstAttemptAndSchedulesOnlyIndependentRetry() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now)); let reviewUnit = unit(.writing); try await repository.saveReviewUnit(reviewUnit)
        let first = try await service.apply(attempt: attempt(for: reviewUnit, help: [HelpEvent(kind: .reveal, at: now)]), evaluation: EvaluationResult(outcome: .correct)); let retry = try await service.apply(attempt: attempt(for: reviewUnit, index: 1, events: [PracticeEvent(kind: .retry, at: now)]), evaluation: EvaluationResult(outcome: .correct))
        let attempts = try await repository.attempts(for: reviewUnit); let projection = try await repository.projection(for: reviewUnit.id)
        XCTAssertFalse(first.learningEvent.independentRecallEligible); XCTAssertTrue(retry.learningEvent.independentRecallEligible); XCTAssertEqual(attempts.count, 2); XCTAssertEqual(projection?.independentEvidenceCount, 1); XCTAssertEqual(scheduler.callCount, 1)
    }

    func testDuplicateDeliveryIsIdempotentAndDoesNotReschedule() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now)); let reviewUnit = unit(.grammar); try await repository.saveReviewUnit(reviewUnit); let value = attempt(for: reviewUnit)
        _ = try await service.apply(attempt: value, evaluation: EvaluationResult(outcome: .partial)); let duplicate = try await service.apply(attempt: value, evaluation: EvaluationResult(outcome: .correct))
        let keyReplay = Attempt(id: UUID(), exerciseID: value.exerciseID, reviewUnitID: value.reviewUnitID, response: "different transport copy", submittedAt: value.submittedAt, idempotencyKey: value.idempotencyKey)
        let keyedDuplicate = try await service.apply(attempt: keyReplay, evaluation: EvaluationResult(outcome: .correct))
        let events = try await repository.learningEvents(for: reviewUnit); let projection = try await repository.projection(for: reviewUnit.id)
        XCTAssertTrue(duplicate.wasDuplicate); XCTAssertTrue(keyedDuplicate.wasDuplicate); XCTAssertEqual(keyedDuplicate.attempt.id, value.id); XCTAssertEqual(events.count, 1); XCTAssertEqual(projection?.independentEvidenceCount, 1); XCTAssertEqual(scheduler.callCount, 1)
    }

    func testFourSkillsHaveIndependentSchedulingState() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now))
        for skill in PracticeSkill.allCases { let reviewUnit = unit(skill); try await repository.saveReviewUnit(reviewUnit); _ = try await service.apply(attempt: attempt(for: reviewUnit), evaluation: EvaluationResult(outcome: .correct)) }
        var projections: [PracticeMasteryProjection?] = []
        for skill in PracticeSkill.allCases { projections.append(try await repository.projection(for: unit(skill).id)) }
        XCTAssertEqual(projections.compactMap { $0?.dueAt }.count, 4); XCTAssertEqual(Set(projections.compactMap { $0?.algorithmVersion }).count, 1)
    }

    func testTransactionFailureLeavesAttemptEventAndProjectionUnchanged() async throws {
        let repository = InMemoryPracticeRepository(); let scheduler = RecordingFSRS(); let service = PracticeReviewService(repository: repository, scheduler: scheduler, clock: ReviewFixedClock(value: now)); let reviewUnit = unit(.speaking); try await repository.saveReviewUnit(reviewUnit); await repository.failNextTransaction(); let value = attempt(for: reviewUnit)
        do { _ = try await service.apply(attempt: value, evaluation: EvaluationResult(outcome: .correct)); XCTFail("expected transaction failure") } catch { }
        let savedAttempt = try await repository.attempt(id: value.id); let savedEvent = try await repository.learningEvent(id: value.id); let projection = try await repository.projection(for: reviewUnit.id)
        XCTAssertNil(savedAttempt); XCTAssertNil(savedEvent); XCTAssertNil(projection); XCTAssertEqual(scheduler.callCount, 1)
    }

    func testProductionGRDBCommitReopensWithMasteryEventAndPinnedSchedulerState() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-review-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = try GRDBPracticeRepository(url: url); let reviewUnit = unit(.grammar); try await repository.saveReviewUnit(reviewUnit)
        let service = PracticeReviewService(repository: repository, clock: ReviewFixedClock(value: now))
        let result = try await service.apply(attempt: attempt(for: reviewUnit), evaluation: EvaluationResult(outcome: .correct, confidence: 0.9, evaluatorVersion: "fixture"))
        XCTAssertEqual(result.projection.algorithmVersion, PracticeFSRS6Scheduler.version); XCTAssertNotNil(result.projection.schedulerState)
        let reopened = try GRDBPracticeRepository(url: url); let reopenedAttempt = try await reopened.attempt(id: result.attempt.id); let reopenedEvent = try await reopened.learningEvent(id: result.learningEvent.id); let reopenedProjection = try await reopened.projection(for: reviewUnit.id)
        XCTAssertEqual(reopenedAttempt?.outcome, .correct); XCTAssertEqual(reopenedEvent, result.learningEvent); XCTAssertEqual(reopenedProjection?.independentEvidenceCount, 1)
    }
}
