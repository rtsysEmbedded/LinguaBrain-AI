import Foundation
import GRDB

/// A GRDB-backed staging sink for migration rehearsal. It is intentionally
/// separate from `GRDBPracticeRepository`: no app composition uses it and it
/// never reads, deletes, or writes the existing SwiftData store.
public actor GRDBLegacyMigrationStagingStore: LegacyPracticeMigrationSink {
    private let pool: DatabasePool

    public init(url: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in try db.execute(sql: "PRAGMA foreign_keys = ON") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        pool = try DatabasePool(path: url.path, configuration: configuration)
        try PracticeMigrations.migrator().migrate(pool)
    }

    public func apply(_ row: LegacyMigrationRow) async throws {
        try await pool.write { db in
            switch row {
            case let .card(evidence):
                let card = evidence.card
                try db.execute(sql: """
                INSERT OR IGNORE INTO practice_legacy_cards
                (legacy_card_key, source_store_id, card_id, deck_id, position, german, persian, article, level, part_of_speech, example, example_translation, examples_json, senses_json, domain, created_at, source_identifier, source_package, source_language_tag, target_language_tag, pronunciation_audio_asset_id, pronunciation_audio_filename, illustration_image_asset_id, illustration_image_filename)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [
                    evidence.rowKey, evidence.sourceStoreID, card.id.uuidString, card.deckID.uuidString, card.position, card.german, card.persian,
                    card.article, card.level, card.partOfSpeech, card.example, card.exampleTranslation, card.examplesJSON, card.sensesJSON,
                    card.domain, card.createdAt.timeIntervalSince1970, card.sourceIdentifier, card.sourcePackage, card.sourceLanguageTag,
                    card.targetLanguageTag, card.pronunciationAudioAssetID?.uuidString, card.pronunciationAudioFilename,
                    card.illustrationImageAssetID?.uuidString, card.illustrationImageFilename
                ])
            case let .review(review):
                try db.execute(sql: """
                INSERT INTO practice_legacy_review_units
                (legacy_unit_key, source_store_id, legacy_card_key, card_id, direction, raw_word_key, latest_review_id, reviewed_at, due_at, stability, difficulty, phase_raw_value, learning_step, scheduled_days, elapsed_days, algorithm_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(legacy_unit_key) DO UPDATE SET
                    raw_word_key=excluded.raw_word_key, latest_review_id=excluded.latest_review_id,
                    reviewed_at=excluded.reviewed_at, due_at=excluded.due_at, stability=excluded.stability,
                    difficulty=excluded.difficulty, phase_raw_value=excluded.phase_raw_value,
                    learning_step=excluded.learning_step, scheduled_days=excluded.scheduled_days,
                    elapsed_days=excluded.elapsed_days, algorithm_version=excluded.algorithm_version
                WHERE excluded.reviewed_at >= practice_legacy_review_units.reviewed_at
                """, arguments: [review.legacyUnitKey, review.sourceStoreID, review.legacyCardKey, review.cardID.uuidString,
                    review.direction.rawValue, review.rawWordKey, review.sourceReviewID.uuidString, review.reviewedAt.timeIntervalSince1970,
                    review.dueAt.timeIntervalSince1970, review.stability, review.difficulty, review.phaseRawValue, review.learningStep,
                    review.scheduledDays, review.elapsedDays, review.algorithmVersion])
                try db.execute(sql: """
                INSERT OR IGNORE INTO practice_legacy_reviews
                (legacy_review_key, source_store_id, legacy_review_id, legacy_card_id, legacy_unit_key, raw_word_key, direction, grade_raw_value, reviewed_at, due_at, stability, difficulty, phase_raw_value, learning_step, scheduled_days, elapsed_days, algorithm_version)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [review.rowKey, review.sourceStoreID, review.sourceReviewID.uuidString, review.legacyCardKey, review.legacyUnitKey, review.rawWordKey,
                    review.direction.rawValue, review.gradeRawValue, review.reviewedAt.timeIntervalSince1970, review.dueAt.timeIntervalSince1970,
                    review.stability, review.difficulty, review.phaseRawValue, review.learningStep, review.scheduledDays, review.elapsedDays, review.algorithmVersion])
                try db.execute(sql: "UPDATE practice_legacy_review_units SET review_count = (SELECT COUNT(*) FROM practice_legacy_reviews WHERE legacy_unit_key = ?) WHERE legacy_unit_key = ?", arguments: [review.legacyUnitKey, review.legacyUnitKey])
            case let .mastery(mastery):
                try db.execute(sql: """
                INSERT OR IGNORE INTO practice_legacy_mastery
                (legacy_mastery_key, source_store_id, legacy_mastery_id, legacy_card_id, skill_raw_value, score, attempts, correct, last_updated)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [mastery.rowKey, mastery.sourceStoreID, mastery.sourceMasteryID, mastery.legacyCardKey, mastery.skillRawValue,
                    mastery.score, mastery.attempts, mastery.correct, mastery.lastUpdated?.timeIntervalSince1970])
            case let .event(event):
                try db.execute(sql: """
                INSERT OR IGNORE INTO practice_legacy_events
                (legacy_event_key, source_store_id, legacy_event_id, legacy_card_id, skill_raw_value, correct, occurred_at, response_time_milliseconds, answer, expected_answers_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, arguments: [event.rowKey, event.sourceStoreID, event.sourceEventID.uuidString, event.legacyCardKey, event.skillRawValue,
                    event.correct ? 1 : 0, event.occurredAt.timeIntervalSince1970, event.responseTimeMilliseconds, event.answer, event.expectedAnswersJSON])
            }
        }
    }

    public func save(_ checkpoint: LegacyMigrationCheckpoint) async throws {
        try await pool.write { db in
            try db.execute(sql: """
            INSERT INTO practice_migration_checkpoints
            (checkpoint_key, source_store_id, migration_id, last_row_key, completed_rows, expected_rows, plan_digest, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(source_store_id, migration_id) DO UPDATE SET
                checkpoint_key=excluded.checkpoint_key, last_row_key=excluded.last_row_key,
                completed_rows=excluded.completed_rows, expected_rows=excluded.expected_rows,
                plan_digest=excluded.plan_digest, updated_at=excluded.updated_at
            """, arguments: [
                "\(checkpoint.sourceStoreID)::\(checkpoint.migrationID)", checkpoint.sourceStoreID, checkpoint.migrationID,
                checkpoint.lastRowKey, checkpoint.completedRows, checkpoint.expectedRows, checkpoint.planDigest,
                checkpoint.updatedAt.timeIntervalSince1970
            ])
        }
    }

    public func checkpoint(sourceStoreID: String, migrationID: String = LegacyPracticeMigrationPlan.migrationID) async throws -> LegacyMigrationCheckpoint? {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM practice_migration_checkpoints WHERE source_store_id = ? AND migration_id = ?", arguments: [sourceStoreID, migrationID]) else { return nil }
            return LegacyMigrationCheckpoint(sourceStoreID: row["source_store_id"] as String, migrationID: row["migration_id"] as String,
                lastRowKey: row["last_row_key"] as String?, completedRows: row["completed_rows"] as Int,
                expectedRows: row["expected_rows"] as Int, planDigest: row["plan_digest"] as String,
                updatedAt: Date(timeIntervalSince1970: row["updated_at"] as Double))
        }
    }

    public func counts(sourceStoreID: String) async throws -> LegacyMigrationCounts {
        try await pool.read { db in
            func count(_ table: String) throws -> Int { try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table) WHERE source_store_id = ?", arguments: [sourceStoreID]) ?? 0 }
            return LegacyMigrationCounts(cards: try count("practice_legacy_cards"), reviews: try count("practice_legacy_reviews"), masteries: try count("practice_legacy_mastery"), events: try count("practice_legacy_events"))
        }
    }

    public func legacyObjectiveCount(sourceStoreID: String) async throws -> Int {
        try await pool.read { db in try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM practice_legacy_review_units WHERE source_store_id = ?", arguments: [sourceStoreID]) ?? 0 }
    }

    public func representativeCardMatches(sourceStoreID: String, cardID: UUID, german: String, persian: String) async throws -> Bool {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT german, persian FROM practice_legacy_cards WHERE source_store_id = ? AND card_id = ?", arguments: [sourceStoreID, cardID.uuidString]) else { return false }
            return (row["german"] as String) == german && (row["persian"] as String) == persian
        }
    }

    public func review(sourceStoreID: String, reviewID: UUID) async throws -> LegacyReviewEvidence? {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT r.*, u.card_id AS resolved_card_id FROM practice_legacy_reviews r JOIN practice_legacy_review_units u ON u.legacy_unit_key = r.legacy_unit_key WHERE r.source_store_id = ? AND r.legacy_review_id = ?", arguments: [sourceStoreID, reviewID.uuidString]) else { return nil }
            guard let cardID = UUID(uuidString: row["resolved_card_id"] as String),
                  let sourceReviewID = UUID(uuidString: row["legacy_review_id"] as String),
                  let direction = LegacyReviewDirection(rawValue: row["direction"] as String) else { return nil }
            return LegacyReviewEvidence(
                rowKey: row["legacy_review_key"] as String,
                sourceStoreID: row["source_store_id"] as String,
                sourceReviewID: sourceReviewID,
                legacyCardKey: row["legacy_card_id"] as String,
                cardID: cardID,
                rawWordKey: row["raw_word_key"] as String,
                direction: direction,
                gradeRawValue: row["grade_raw_value"] as String,
                reviewedAt: Date(timeIntervalSince1970: row["reviewed_at"] as Double),
                dueAt: Date(timeIntervalSince1970: row["due_at"] as Double),
                stability: row["stability"] as Double,
                difficulty: row["difficulty"] as Double,
                phaseRawValue: row["phase_raw_value"] as String,
                learningStep: row["learning_step"] as Int,
                scheduledDays: row["scheduled_days"] as Double,
                elapsedDays: row["elapsed_days"] as Double,
                algorithmVersion: row["algorithm_version"] as String
            )
        }
    }

    public func foreignKeysAreValid() async throws -> Bool { try await pool.read { try Row.fetchAll($0, sql: "PRAGMA foreign_key_check").isEmpty } }

}
