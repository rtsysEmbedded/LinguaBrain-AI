import Foundation
import SwiftData
import XCTest
import LinguaBrainDomain
import LinguaBrainPersistence
@testable import LinguaBrain

@MainActor
final class LegacyPracticeMigrationTests: XCTestCase {
    func testCleanCutoverBacksUpMigratesAndSeedsNewSkillsAsUnknown() async throws {
        let fixture = try makeFixture()
        defer { removeFixture(fixture) }

        let coordinator = try makeCoordinator(fixture)
        await coordinator.start()

        XCTAssertEqual(coordinator.state, .active)
        XCTAssertEqual(coordinator.backupReceipt?.manifest.sourceStoreID, PracticeCutoverCoordinator.sourceStoreID(for: fixture.legacyURL))
        XCTAssertFalse(coordinator.backupReceipt?.manifest.files.isEmpty ?? true)

        let staging = try GRDBLegacyMigrationStagingStore(url: fixture.practiceURL)
        let sourceID = PracticeCutoverCoordinator.sourceStoreID(for: fixture.legacyURL)
        let counts = try await staging.counts(sourceStoreID: sourceID)
        let objectiveCount = try await staging.legacyObjectiveCount(sourceStoreID: sourceID)
        let foreignKeysValid = try await staging.foreignKeysAreValid()
        XCTAssertEqual(counts, LegacyMigrationCounts(cards: 1, reviews: 3, masteries: 2, events: 1))
        XCTAssertEqual(objectiveCount, 2)
        XCTAssertTrue(foreignKeysValid)

        let reverseID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let reverse = try await staging.review(sourceStoreID: sourceID, reviewID: reverseID)
        XCTAssertEqual(reverse?.direction, .reverse)
        XCTAssertEqual(reverse?.dueAt, Date(timeIntervalSince1970: 500))
        XCTAssertEqual(reverse?.stability, 12.5)
        XCTAssertEqual(reverse?.difficulty, 4.2)
        XCTAssertEqual(reverse?.algorithmVersion, "FSRS-6.0/default-21")

        let repository = try XCTUnwrap(coordinator.repository)
        for skill in PracticeSkill.allCases {
            let unit = ReviewUnit(skill: skill, objectiveKey: "legacy-card:\(fixture.cardID.uuidString.lowercased())")
            let storedUnit = try await repository.reviewUnit(id: unit.id)
            let projection = try await repository.projection(for: unit.id)
            let attempts = try await repository.attempts(for: unit)
            XCTAssertEqual(storedUnit, unit)
            XCTAssertEqual(projection?.state, .unknown)
            XCTAssertTrue(attempts.isEmpty)
        }
    }

    func testRepeatedLaunchIsIdempotentAndKeepsLegacySource() async throws {
        let fixture = try makeFixture()
        defer { removeFixture(fixture) }
        let first = try makeCoordinator(fixture)
        await first.start()
        let second = try makeCoordinator(fixture)
        await second.start()

        XCTAssertEqual(second.state, .active)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.legacyURL.path))
        let staging = try GRDBLegacyMigrationStagingStore(url: fixture.practiceURL)
        let sourceID = PracticeCutoverCoordinator.sourceStoreID(for: fixture.legacyURL)
        let counts = try await staging.counts(sourceStoreID: sourceID)
        let objectiveCount = try await staging.legacyObjectiveCount(sourceStoreID: sourceID)
        XCTAssertEqual(counts, LegacyMigrationCounts(cards: 1, reviews: 3, masteries: 2, events: 1))
        XCTAssertEqual(objectiveCount, 2)
    }

    func testAppBridgeResumesAfterInterruptedSyntheticMigration() async throws {
        let fixture = try makeFixture()
        defer { removeFixture(fixture) }
        let sourceID = PracticeCutoverCoordinator.sourceStoreID(for: fixture.legacyURL)
        let snapshot = try LegacySwiftDataSnapshotReader(storeURL: fixture.legacyURL).snapshot(sourceStoreID: sourceID)
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: snapshot)
        let sink = AppInterruptingSink(failOnApply: 2)

        do {
            _ = try await LegacyPracticeMigrationRunner().run(plan: plan, sink: sink, now: Date(timeIntervalSince1970: 1))
            XCTFail("expected the synthetic interruption")
        } catch is AppFixtureError { }

        let checkpoint = await sink.checkpointValue()
        XCTAssertEqual(checkpoint?.completedRows, 1)
        _ = try await LegacyPracticeMigrationRunner().run(plan: plan, resumeFrom: checkpoint, sink: sink, now: Date(timeIntervalSince1970: 2))
        let rowCount = await sink.rowCount()
        XCTAssertEqual(rowCount, plan.rows.count)
    }

    func testMissingAndCorruptLegacyStoresBecomeRecoverableFailures() async throws {
        let missing = try makeEmptyFixture()
        defer { removeFixture(missing) }
        let missingCoordinator = try makeCoordinator(missing)
        await missingCoordinator.start()
        XCTAssertEqual(missingCoordinator.state, .recoverableFailure(.legacyStoreMissing))

        let corrupt = try makeEmptyFixture()
        defer { removeFixture(corrupt) }
        try Data("not a sqlite store".utf8).write(to: corrupt.legacyURL)
        let corruptCoordinator = try makeCoordinator(corrupt)
        await corruptCoordinator.start()
        XCTAssertEqual(corruptCoordinator.state, .recoverableFailure(.legacyStoreUnreadable))
        XCTAssertNotNil(corruptCoordinator.backupReceipt)
    }

    func testBackupFailureDoesNotCreateOrActivatePracticeStore() async throws {
        let fixture = try makeFixture()
        defer { removeFixture(fixture) }
        try Data("backup destination is intentionally a file".utf8).write(to: fixture.backupURL)

        let coordinator = try makeCoordinator(fixture)
        await coordinator.start()
        XCTAssertEqual(coordinator.state, .recoverableFailure(.backupFailed))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.practiceURL.path))
    }

    func testValidationMismatchIsRejectedBeforeActivation() throws {
        let cardID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let snapshot = LegacyPracticeSnapshot(
            sourceStoreID: "synthetic-validation",
            cards: [legacyCard(id: cardID)],
            reviews: [], masteries: [], learningEvents: [], capturedAt: Date(timeIntervalSince1970: 1)
        )
        let plan = try LegacyPracticeMigrationPlanner().makePlan(from: snapshot)
        XCTAssertThrowsError(try plan.verify(actualCounts: LegacyMigrationCounts(cards: 0), actualDigest: plan.digest)) { error in
            guard case LegacyPracticeMigrationError.verificationMismatch = error else { return XCTFail("unexpected error: \(error)") }
        }
    }

    func testRecoveryRestoresSyntheticLegacyStoreFromVerifiedBackup() throws {
        let fixture = try makeFixture()
        defer { removeFixture(fixture) }
        let sourceID = PracticeCutoverCoordinator.sourceStoreID(for: fixture.legacyURL)
        let receipt = try PracticeStoreBackupService().createBackup(sourceURL: fixture.legacyURL, destinationRoot: fixture.backupURL, sourceStoreID: sourceID)
        removeStoreFiles(at: fixture.legacyURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.legacyURL.path))

        try PracticeStoreBackupService().restore(receipt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.legacyURL.path))
        let restored = try LegacySwiftDataSnapshotReader(storeURL: fixture.legacyURL).snapshot(sourceStoreID: sourceID)
        XCTAssertEqual(restored.reviews.count, 3)
        XCTAssertEqual(restored.reviews.map(\.wordKey).sorted(), ["card:\(fixture.cardID.uuidString.lowercased())", "card:\(fixture.cardID.uuidString.lowercased())", "card:\(fixture.cardID.uuidString.lowercased())::reverse"])
    }

    func testPrototypeReviewWriterRemainsAvailableUntilTheReviewRouteUsesGRDB() {
        let store = PrototypeStore(inMemory: true)
        let word = store.words[0]

        XCTAssertNotNil(store.record(.good, for: word, at: Date(timeIntervalSince1970: 1)))
        XCTAssertEqual(store.reviewCount(for: word), 1)
    }

    private struct Fixture {
        let root: URL
        let legacyURL: URL
        let practiceURL: URL
        let backupURL: URL
        let cardID: UUID
    }

    private func makeFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("practice-cutover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fixture = Fixture(root: root, legacyURL: root.appendingPathComponent("legacy.store"), practiceURL: root.appendingPathComponent("practice.sqlite"), backupURL: root.appendingPathComponent("backups", isDirectory: true), cardID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        try writeLegacyFixture(fixture)
        return fixture
    }

    private func makeEmptyFixture() throws -> Fixture {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("practice-cutover-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return Fixture(root: root, legacyURL: root.appendingPathComponent("legacy.store"), practiceURL: root.appendingPathComponent("practice.sqlite"), backupURL: root.appendingPathComponent("backups", isDirectory: true), cardID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    }

    private func makeCoordinator(_ fixture: Fixture) throws -> PracticeCutoverCoordinator {
        PracticeCutoverCoordinator(paths: PracticeRuntimePaths(legacyStoreURL: fixture.legacyURL, practiceStoreURL: fixture.practiceURL, backupRootURL: fixture.backupURL))
    }

    private func writeLegacyFixture(_ fixture: Fixture) throws {
        let configuration = ModelConfiguration("synthetic-legacy", schema: nil, url: fixture.legacyURL, allowsSave: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: PrototypeDeckRecord.self, PrototypeMediaAssetRecord.self, PrototypeCardRecord.self, PrototypeReviewRecord.self, PrototypeSkillMasteryRecord.self, PrototypeLearningEventRecord.self, PrototypeLearningMissionRecord.self, PrototypeDailyLearningStateRecord.self, configurations: configuration)
        let context = ModelContext(container)
        let deck = PrototypeDeckRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!, name: "Synthetic")
        let word = PrototypeWord(id: fixture.cardID, german: "Haus", persian: "خانه", article: "das", level: "A1", partOfSpeech: "Nomen", example: "Das Haus ist alt.", exampleTranslation: "خانه قدیمی است.", domain: "home")
        let card = PrototypeCardRecord(word: word, deckID: deck.id, position: 1, createdAt: Date(timeIntervalSince1970: 10), sourceIdentifier: "synthetic", sourcePackage: "tests")
        context.insert(deck)
        context.insert(card)
        context.insert(PrototypeReviewRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, wordKey: "card:\(fixture.cardID.uuidString.lowercased())", gradeRawValue: "good", reviewedAt: Date(timeIntervalSince1970: 100), dueAt: Date(timeIntervalSince1970: 400), stability: 8.5, difficulty: 5.1, phaseRawValue: "review", learningStep: 0, scheduledDays: 3, elapsedDays: 2, algorithmVersion: "FSRS-6.0/default-21"))
        context.insert(PrototypeReviewRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!, wordKey: "card:\(fixture.cardID.uuidString.lowercased())::reverse", gradeRawValue: "again", reviewedAt: Date(timeIntervalSince1970: 200), dueAt: Date(timeIntervalSince1970: 500), stability: 12.5, difficulty: 4.2, phaseRawValue: "relearning", learningStep: 1, scheduledDays: 0.1, elapsedDays: 5, algorithmVersion: "FSRS-6.0/default-21"))
        context.insert(PrototypeReviewRecord(id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!, wordKey: "card:\(fixture.cardID.uuidString.lowercased())", gradeRawValue: "easy", reviewedAt: Date(timeIntervalSince1970: 300), dueAt: Date(timeIntervalSince1970: 700), stability: 14, difficulty: 4.6, phaseRawValue: "review", learningStep: 0, scheduledDays: 7, elapsedDays: 3, algorithmVersion: "FSRS-6.0/default-21"))
        context.insert(PrototypeSkillMasteryRecord(cardID: fixture.cardID, skillRawValue: LearningSkill.recognition.rawValue, score: 0.75, attempts: 4, correct: 3, lastUpdated: Date(timeIntervalSince1970: 300)))
        context.insert(PrototypeSkillMasteryRecord(cardID: fixture.cardID, skillRawValue: LearningSkill.recall.rawValue, score: 0.5, attempts: 2, correct: 1, lastUpdated: Date(timeIntervalSince1970: 300)))
        context.insert(PrototypeSkillMasteryRecord(cardID: fixture.cardID, skillRawValue: LearningSkill.writing.rawValue, score: 1, attempts: 1, correct: 1, lastUpdated: Date(timeIntervalSince1970: 300)))
        context.insert(PrototypeLearningEventRecord(cardID: fixture.cardID, skillRawValue: LearningSkill.recognition.rawValue, correct: true, occurredAt: Date(timeIntervalSince1970: 350), responseTimeMilliseconds: 900, answer: "Haus", expectedAnswers: ["Haus"]))
        context.insert(PrototypeLearningEventRecord(cardID: fixture.cardID, skillRawValue: LearningSkill.writing.rawValue, correct: true, occurredAt: Date(timeIntervalSince1970: 360), answer: "Das Haus"))
        try context.save()
    }

    private func legacyCard(id: UUID) -> LegacyCardSnapshot {
        LegacyCardSnapshot(id: id, deckID: UUID(), position: 1, german: "Haus", persian: "خانه", article: "das", level: "A1", partOfSpeech: "Nomen", example: "Das Haus ist alt.", exampleTranslation: "خانه قدیمی است.", createdAt: Date(timeIntervalSince1970: 10))
    }

    private func removeFixture(_ fixture: Fixture) {
        try? FileManager.default.removeItem(at: fixture.root)
    }

    private func removeStoreFiles(at url: URL) {
        let manager = FileManager.default
        for suffix in ["", "-wal", "-shm", "-journal"] { try? manager.removeItem(atPath: url.path + suffix) }
    }
}

private enum AppFixtureError: Error { case interrupted }

private actor AppInterruptingSink: LegacyPracticeMigrationSink {
    private let failOnApply: Int
    private var applyCount = 0
    private var rows: Set<String> = []
    private var checkpoint: LegacyMigrationCheckpoint?

    init(failOnApply: Int) { self.failOnApply = failOnApply }

    func apply(_ row: LegacyMigrationRow) async throws {
        applyCount += 1
        if applyCount == failOnApply { throw AppFixtureError.interrupted }
        rows.insert(row.rowKey)
    }

    func save(_ checkpoint: LegacyMigrationCheckpoint) async throws { self.checkpoint = checkpoint }
    func checkpointValue() -> LegacyMigrationCheckpoint? { checkpoint }
    func rowCount() -> Int { rows.count }
}
