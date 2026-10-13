import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainPersistence

private enum MigrationFixtureError: Error { case interrupted }

final class LegacyPracticeMigrationTests: XCTestCase {
    func testPlannerMapsRecognitionAndReverseHistoryAndSeedsOtherSkillsUnknown() throws {
        let snapshot = fixture()
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: snapshot)

        XCTAssertEqual(plan.expectedCounts, LegacyMigrationCounts(cards: 1, reviews: 2, masteries: 2, events: 1))
        XCTAssertEqual(plan.excludedSkillValues, [LearningSkill.writing.rawValue])
        XCTAssertEqual(plan.newSkillSeeds.count, 4)
        XCTAssertTrue(plan.newSkillSeeds.allSatisfy { $0.state == .unknown })
        XCTAssertTrue(plan.rows.contains { row in
            guard case let .review(review) = row else { return false }
            return review.direction == .reverse && review.sourceReviewID == UUID(uuidString: "00000000-0000-0000-0000-000000000002")
                && review.dueAt == Date(timeIntervalSince1970: 500)
                && review.stability == 12.5 && review.difficulty == 4.2
                && review.algorithmVersion == "FSRS-6.0/default-21"
        })
    }

    func testGRDBStagingReopensWithCountsCheckpointAndForeignKeys() async throws {
        let url = temporaryURL("migration-reopen")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try GRDBLegacyMigrationStagingStore(url: url)
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: fixture())
        let report = try await LegacyPracticeMigrationRunner().run(plan: plan, sink: store, now: date(900))
        XCTAssertEqual(report.appliedRows, plan.rows.count)
        let storedCounts = try await store.counts(sourceStoreID: plan.sourceStoreID)
        XCTAssertEqual(storedCounts, plan.expectedCounts)
        let foreignKeysValid = try await store.foreignKeysAreValid()
        XCTAssertTrue(foreignKeysValid)

        let reopened = try GRDBLegacyMigrationStagingStore(url: url)
        let reopenedCheckpoint = try await reopened.checkpoint(sourceStoreID: plan.sourceStoreID)
        let reopenedCounts = try await reopened.counts(sourceStoreID: plan.sourceStoreID)
        XCTAssertEqual(reopenedCheckpoint, report.checkpoint)
        XCTAssertEqual(reopenedCounts, plan.expectedCounts)
        _ = try await LegacyPracticeMigrationRunner().run(plan: plan, sink: reopened, now: date(901))
        let repeatedCounts = try await reopened.counts(sourceStoreID: plan.sourceStoreID)
        XCTAssertEqual(repeatedCounts, plan.expectedCounts)
    }

    func testInterruptedMigrationResumesFromDurableCheckpointWithoutDuplicateRows() async throws {
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: fixture())
        let sink = RecordingSink(failAtApply: 3)
        do {
            _ = try await LegacyPracticeMigrationRunner().run(plan: plan, sink: sink, now: date(100))
            XCTFail("expected interruption")
        } catch MigrationFixtureError.interrupted { }

        let checkpoint = await sink.currentCheckpoint()
        XCTAssertEqual(checkpoint?.completedRows, 2)
        _ = try await LegacyPracticeMigrationRunner().run(plan: plan, resumeFrom: checkpoint, sink: sink, now: date(200))
        let uniqueRows = await sink.uniqueRowCount()
        let finalCheckpoint = await sink.currentCheckpoint()
        XCTAssertEqual(uniqueRows, plan.rows.count)
        XCTAssertEqual(finalCheckpoint?.completedRows, plan.rows.count)
    }

    func testRepeatedMigrationIsIdempotentByStableRowKeys() async throws {
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: fixture())
        let sink = RecordingSink()
        _ = try await LegacyPracticeMigrationRunner().run(plan: plan, sink: sink, now: date(100))
        _ = try await LegacyPracticeMigrationRunner().run(plan: plan, sink: sink, now: date(200))
        let uniqueRows = await sink.uniqueRowCount()
        let applyCalls = await sink.applyCallCount()
        XCTAssertEqual(uniqueRows, plan.rows.count)
        XCTAssertEqual(applyCalls, plan.rows.count * 2)
    }

    func testMalformedLegacyDataIsRejectedBeforeAnyStagingWrite() throws {
        let cardID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        var bad = fixture()
        bad = LegacyPracticeSnapshot(sourceStoreID: bad.sourceStoreID, cards: [
            card(id: cardID, german: "Hallo"), card(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, german: "Hallo")
        ], reviews: [LegacyReviewSnapshot(id: UUID(), wordKey: "Hallo", gradeRawValue: "not-a-grade", reviewedAt: date(1), dueAt: date(2), stability: 1, difficulty: 1, phaseRawValue: "review", learningStep: 0, scheduledDays: 1, elapsedDays: 1, algorithmVersion: "FSRS-6.0/default-21")], masteries: [], learningEvents: [], capturedAt: date(0))
        do {
            _ = try LegacyPracticeMigrationPlanner().makePlan(from: bad)
            XCTFail("expected malformed snapshot")
        } catch let LegacyPracticeMigrationError.invalidSnapshot(issues) {
            XCTAssertTrue(issues.contains { if case .ambiguousReviewKey = $0 { return true }; return false })
        }
    }

    func testVerificationRejectsCountOrDigestMismatch() throws {
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: fixture())
        XCTAssertThrowsError(try plan.verify(actualCounts: LegacyMigrationCounts(cards: 1), actualDigest: plan.digest)) { error in
            guard case let LegacyPracticeMigrationError.verificationMismatch(expected, actual) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(expected, plan.expectedCounts); XCTAssertNotEqual(actual, expected)
        }
        XCTAssertThrowsError(try plan.verify(actualCounts: plan.expectedCounts, actualDigest: "changed")) { error in
            guard case let LegacyPracticeMigrationError.digestMismatch(expected, actual) = error else { return XCTFail("wrong error: \(error)") }
            XCTAssertEqual(expected, plan.digest); XCTAssertEqual(actual, "changed")
        }
    }

    private func fixture() -> LegacyPracticeSnapshot {
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let reverseID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        return LegacyPracticeSnapshot(sourceStoreID: "swiftdata-fixture-v1", cards: [card(id: id)], reviews: [
            LegacyReviewSnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, wordKey: "card:\(id.uuidString.lowercased())", gradeRawValue: "good", reviewedAt: date(100), dueAt: date(400), stability: 8.5, difficulty: 5.1, phaseRawValue: "review", learningStep: 0, scheduledDays: 3, elapsedDays: 2, algorithmVersion: "FSRS-6.0/default-21"),
            LegacyReviewSnapshot(id: reverseID, wordKey: "card:\(id.uuidString.lowercased())::reverse", gradeRawValue: "again", reviewedAt: date(200), dueAt: date(500), stability: 12.5, difficulty: 4.2, phaseRawValue: "relearning", learningStep: 1, scheduledDays: 0.1, elapsedDays: 5, algorithmVersion: "FSRS-6.0/default-21")
        ], masteries: [
            LegacyMasterySnapshot(id: "\(id.uuidString)::recognition", cardID: id, skillRawValue: LearningSkill.recognition.rawValue, score: 0.75, attempts: 4, correct: 3, lastUpdated: date(300)),
            LegacyMasterySnapshot(id: "\(id.uuidString)::recall", cardID: id, skillRawValue: LearningSkill.recall.rawValue, score: 0.5, attempts: 2, correct: 1, lastUpdated: date(300)),
            LegacyMasterySnapshot(id: "\(id.uuidString)::writing", cardID: id, skillRawValue: LearningSkill.writing.rawValue, score: 1, attempts: 1, correct: 1, lastUpdated: date(300))
        ], learningEvents: [
            LegacyLearningEventSnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, cardID: id, skillRawValue: LearningSkill.recognition.rawValue, correct: true, occurredAt: date(350), responseTimeMilliseconds: 900, answer: "Haus", expectedAnswersJSON: "[\"Haus\"]"),
            LegacyLearningEventSnapshot(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, cardID: id, skillRawValue: LearningSkill.writing.rawValue, correct: true, occurredAt: date(360), responseTimeMilliseconds: nil, answer: "Das Haus", expectedAnswersJSON: "[]")
        ], capturedAt: date(999))
    }

    private func card(id: UUID, german: String = "Haus") -> LegacyCardSnapshot {
        card(id: id, german: german, deckID: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!)
    }

    private func card(id: UUID, german: String, deckID: UUID) -> LegacyCardSnapshot {
        LegacyCardSnapshot(id: id, deckID: deckID, position: 1, german: german, persian: "خانه", article: "das", level: "A1", partOfSpeech: "Nomen", example: "Das Haus ist alt.", exampleTranslation: "خانه قدیمی است.", examplesJSON: "[]", sensesJSON: "[]", createdAt: date(10), sourceIdentifier: "fixture-card", sourcePackage: "fixture", sourceLanguageTag: "fa", targetLanguageTag: "de", pronunciationAudioAssetID: nil, pronunciationAudioFilename: nil, illustrationImageAssetID: nil, illustrationImageFilename: nil)
    }

    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }
    private func temporaryURL(_ name: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString).sqlite") }
}

private actor RecordingSink: LegacyPracticeMigrationSink {
    private let failAtApply: Int?
    private var applyCalls = 0
    private var rows: [String: LegacyMigrationRow] = [:]
    private var checkpoint: LegacyMigrationCheckpoint?

    init(failAtApply: Int? = nil) { self.failAtApply = failAtApply }

    func apply(_ row: LegacyMigrationRow) async throws {
        applyCalls += 1
        if applyCalls == failAtApply { throw MigrationFixtureError.interrupted }
        rows[row.rowKey] = row
    }
    func save(_ checkpoint: LegacyMigrationCheckpoint) async throws { self.checkpoint = checkpoint }
    func uniqueRowCount() -> Int { rows.count }
    func applyCallCount() -> Int { applyCalls }
    func currentCheckpoint() -> LegacyMigrationCheckpoint? { checkpoint }
}
