import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainPersistence

private enum GRDBTestFailure: Error { case expected }

final class GRDBPracticeRepositoryTests: XCTestCase {
    private func makeStore() throws -> (GRDBPracticeRepository, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("practice-grdb-\(UUID().uuidString).sqlite")
        return (try GRDBPracticeRepository(url: url), url)
    }

    func testRoundTripPersistsAllPracticeRowsAndReopens() async throws {
        let (repo, url) = try makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sentence = Sentence(text: "Ich lerne.", translation: "من یاد می‌گیرم", originalLearnerResponse: "Ich lerne", minimalCorrection: "Ich lerne.", naturalVariant: "Ich lerne gerade.", validation: .validated, ruleReferences: [RuleReference(code: "punctuation", span: ".")], lexicalReferences: [LexicalReference(senseKey: "lernen.v1", surface: "lerne")])
        let unit = ReviewUnit(learnerID: "learner", skill: .writing, objectiveKey: "sentence", sentenceID: sentence.id, sentenceRevision: sentence.revision)
        let attempt = Attempt(sessionID: UUID(), exerciseID: UUID(), reviewUnitID: unit.id, response: "Ich lerne", submittedAt: Date(timeIntervalSince1970: 10), attemptIndex: 1, idempotencyKey: IdempotencyKey(rawValue: "attempt-1"), outcome: .partial, evaluatorResult: PracticeEvaluation(outcome: .partial, score: 0.5, confidence: 0.9, provenance: Provenance(provider: "fixture", model: "evaluator")), feedback: [TypedFeedback(message: "Almost", confidence: 0.9)], help: [HelpEvent(kind: .hint, at: Date(timeIntervalSince1970: 9))], events: [PracticeEvent(kind: .retry, at: Date(timeIntervalSince1970: 8))], rules: [RuleReference(code: "punctuation", span: ".")])
        let learningEvent = PracticeLearningEvent(attemptID: attempt.id, reviewUnitID: unit.id, skill: unit.skill, outcome: .partial, score: 0.5, masteryDelta: 0.5, independentRecallEligible: true, schedulingEligible: true, scheduleRating: .hard, occurredAt: Date(timeIntervalSince1970: 10))
        try await repo.transaction { try await repo.saveSentence(sentence); try await repo.saveReviewUnit(unit, projection: PracticeMasteryProjection(state: .learning, score: 0.5, dueAt: Date(timeIntervalSince1970: 100), algorithmVersion: "fsrs-6.0", independentEvidenceCount: 1, independentScoreTotal: 0.5)); try await repo.saveAttempt(attempt); try await repo.saveLearningEvent(learningEvent) }
        let loadedSentence = try await repo.sentence(id: sentence.id, revision: 1); XCTAssertEqual(loadedSentence?.minimalCorrection, "Ich lerne.")
        let loadedUnit = try await repo.reviewUnit(id: unit.id); XCTAssertEqual(loadedUnit?.stableKey, unit.stableKey)
        let reopened = try GRDBPracticeRepository(url: url); let loaded = try await reopened.attempt(id: attempt.id)
        let reopenedEvent = try await reopened.learningEvent(id: learningEvent.id); let reopenedProjection = try await reopened.projection(for: unit.id)
        XCTAssertEqual(loaded?.outcome, .partial); XCTAssertEqual(loaded?.attemptIndex, 1); XCTAssertEqual(loaded?.evaluatorResult?.score, 0.5); XCTAssertEqual(loaded?.feedback.first?.confidence, 0.9); XCTAssertEqual(loaded?.help.first?.kind, .hint); XCTAssertEqual(loaded?.events.first?.kind, .retry); XCTAssertEqual(reopenedEvent, learningEvent); XCTAssertEqual(reopenedProjection?.independentEvidenceCount, 1); let valid = try await reopened.validateForeignKeys(); XCTAssertTrue(valid)
    }

    func testForeignKeyAndImmutableRevisionConstraintsAreEnforced() async throws {
        let (repo, url) = try makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let unit = ReviewUnit(skill: .grammar, objectiveKey: "orphan"); let orphan = Attempt(exerciseID: UUID(), reviewUnitID: unit.id, response: "x", submittedAt: Date())
        await assertThrows { try await repo.saveAttempt(orphan) }
        let sentence = Sentence(text: "A", translation: "B"); try await repo.saveSentence(sentence)
        await assertThrows { try await repo.saveSentence(Sentence(id: sentence.id, revision: sentence.revision, text: "changed", translation: "B")) }
    }

    func testIdempotencyKeyDoesNotCreateSecondAttempt() async throws {
        let (repo, url) = try makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let unit = ReviewUnit(skill: .listening, objectiveKey: "idempotent"); try await repo.saveReviewUnit(unit)
        let key = IdempotencyKey(rawValue: "same-request")
        let first = Attempt(exerciseID: UUID(), reviewUnitID: unit.id, response: "one", submittedAt: Date(), idempotencyKey: key)
        let second = Attempt(exerciseID: UUID(), reviewUnitID: unit.id, response: "two", submittedAt: Date(), idempotencyKey: key)
        try await repo.saveAttempt(first); try await repo.saveAttempt(second)
        let attempts = try await repo.attempts(for: unit); XCTAssertEqual(attempts.count, 1); XCTAssertEqual(attempts.first?.response, "one")
    }

    func testFailedTransactionLeavesNoPartialState() async throws {
        let (repo, url) = try makeStore(); defer { try? FileManager.default.removeItem(at: url) }
        let sentence = Sentence(text: "A", translation: "B"); let unit = ReviewUnit(skill: .speaking, objectiveKey: "rollback", sentenceID: sentence.id, sentenceRevision: 1); let attempt = Attempt(exerciseID: UUID(), reviewUnitID: unit.id, response: "audio", submittedAt: Date())
        do { try await repo.transaction { try await repo.saveSentence(sentence); try await repo.saveReviewUnit(unit); try await repo.saveAttempt(attempt); throw GRDBTestFailure.expected } } catch GRDBTestFailure.expected {}
        let rolledSentence = try await repo.sentence(id: sentence.id, revision: 1); let rolledUnit = try await repo.reviewUnit(id: unit.id); let rolledAttempt = try await repo.attempt(id: attempt.id); XCTAssertNil(rolledSentence); XCTAssertNil(rolledUnit); XCTAssertNil(rolledAttempt)
        let reopened = try GRDBPracticeRepository(url: url); let reopenedSentence = try await reopened.sentence(id: sentence.id, revision: 1); XCTAssertNil(reopenedSentence); let valid = try await reopened.validateForeignKeys(); XCTAssertTrue(valid)
    }

    private func assertThrows(_ operation: () async throws -> Void) async {
        do { try await operation(); XCTFail("expected error") } catch { }
    }
}
