import Foundation
import GRDB

public enum PracticeMigrations {
    public static let schemaVersion = 3
    public static let migrationIdentifier = "practice_001_core"
    public static let legacyStagingMigrationIdentifier = "practice_002_legacy_migration_staging"
    public static let reviewEffectsMigrationIdentifier = "practice_003_review_effects"

    public static func migrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration(migrationIdentifier) { db in
            try db.execute(sql: """
            CREATE TABLE practice_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);
            INSERT INTO practice_metadata(key, value) VALUES ('schema_version', '1');
            CREATE TABLE practice_sentences (
                sentence_id TEXT NOT NULL, revision INTEGER NOT NULL CHECK (revision > 0),
                text TEXT NOT NULL, translation TEXT NOT NULL, original_learner_response TEXT,
                minimal_correction TEXT, natural_variant TEXT,
                validation TEXT NOT NULL CHECK (validation IN ('unvalidated','validated','rejected')),
                provenance_json TEXT, PRIMARY KEY (sentence_id, revision)
            );
            CREATE TABLE practice_sentence_rules (
                sentence_id TEXT NOT NULL, revision INTEGER NOT NULL, ordinal INTEGER NOT NULL,
                code TEXT NOT NULL, span TEXT, PRIMARY KEY (sentence_id, revision, ordinal),
                FOREIGN KEY (sentence_id, revision) REFERENCES practice_sentences(sentence_id, revision) ON DELETE CASCADE
            );
            CREATE TABLE practice_sentence_lexical_refs (
                sentence_id TEXT NOT NULL, revision INTEGER NOT NULL, ordinal INTEGER NOT NULL,
                sense_key TEXT NOT NULL, surface TEXT, PRIMARY KEY (sentence_id, revision, ordinal),
                FOREIGN KEY (sentence_id, revision) REFERENCES practice_sentences(sentence_id, revision) ON DELETE CASCADE
            );
            CREATE TABLE practice_review_units (
                unit_id TEXT PRIMARY KEY NOT NULL, stable_key TEXT NOT NULL UNIQUE, learner_id TEXT NOT NULL,
                skill TEXT NOT NULL CHECK (skill IN ('writing','grammar','listening','speaking')),
                objective_key TEXT NOT NULL, sentence_id TEXT, sentence_revision INTEGER,
                mastery_state TEXT NOT NULL DEFAULT 'unknown' CHECK (mastery_state IN ('unknown','new','learning','mastered')),
                mastery_score REAL, due_at REAL, algorithm_version TEXT, scheduler_state TEXT, updated_at REAL NOT NULL,
                FOREIGN KEY (sentence_id, sentence_revision) REFERENCES practice_sentences(sentence_id, revision),
                CHECK ((sentence_id IS NULL AND sentence_revision IS NULL) OR (sentence_id IS NOT NULL AND sentence_revision IS NOT NULL))
            );
            CREATE TABLE practice_attempts (
                attempt_id TEXT PRIMARY KEY NOT NULL, session_id TEXT, exercise_id TEXT NOT NULL, unit_id TEXT NOT NULL,
                response TEXT NOT NULL, submitted_at REAL NOT NULL, idempotency_key TEXT UNIQUE,
                outcome TEXT NOT NULL CHECK (outcome IN ('correct','incorrect','skipped','unavailable','pending')),
                FOREIGN KEY (unit_id) REFERENCES practice_review_units(unit_id)
            );
            CREATE TABLE practice_help_events (
                event_id TEXT PRIMARY KEY NOT NULL, attempt_id TEXT NOT NULL,
                kind TEXT NOT NULL CHECK (kind IN ('hint','reveal','copiedAnswer','retry')), occurred_at REAL NOT NULL,
                FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE
            );
            CREATE TABLE practice_feedback (
                attempt_id TEXT NOT NULL, ordinal INTEGER NOT NULL, message TEXT NOT NULL,
                is_error INTEGER NOT NULL CHECK (is_error IN (0,1)), confidence REAL,
                PRIMARY KEY (attempt_id, ordinal), FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE
            );
            CREATE TABLE practice_attempt_rules (
                attempt_id TEXT NOT NULL, ordinal INTEGER NOT NULL, code TEXT NOT NULL, span TEXT,
                PRIMARY KEY (attempt_id, ordinal), FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE
            );
            CREATE INDEX practice_units_due_idx ON practice_review_units(due_at, skill);
            CREATE INDEX practice_attempts_unit_idx ON practice_attempts(unit_id, submitted_at);
            CREATE INDEX practice_help_attempt_idx ON practice_help_events(attempt_id, occurred_at);
            """)
        }
        migrator.registerMigration(legacyStagingMigrationIdentifier) { db in
            try db.execute(sql: """
            CREATE TABLE practice_legacy_cards (
                legacy_card_key TEXT PRIMARY KEY NOT NULL,
                source_store_id TEXT NOT NULL,
                card_id TEXT NOT NULL,
                deck_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                german TEXT NOT NULL,
                persian TEXT NOT NULL,
                article TEXT,
                level TEXT NOT NULL,
                part_of_speech TEXT NOT NULL,
                example TEXT NOT NULL,
                example_translation TEXT NOT NULL,
                examples_json TEXT NOT NULL,
                senses_json TEXT NOT NULL,
                domain TEXT NOT NULL,
                created_at REAL NOT NULL,
                source_identifier TEXT,
                source_package TEXT,
                source_language_tag TEXT NOT NULL,
                target_language_tag TEXT NOT NULL,
                pronunciation_audio_asset_id TEXT,
                pronunciation_audio_filename TEXT,
                illustration_image_asset_id TEXT,
                illustration_image_filename TEXT,
                UNIQUE(source_store_id, card_id)
            );
            CREATE TABLE practice_legacy_review_units (
                legacy_unit_key TEXT PRIMARY KEY NOT NULL,
                source_store_id TEXT NOT NULL,
                legacy_card_key TEXT NOT NULL,
                card_id TEXT NOT NULL,
                direction TEXT NOT NULL CHECK (direction IN ('recognition','reverse')),
                raw_word_key TEXT NOT NULL,
                latest_review_id TEXT NOT NULL,
                reviewed_at REAL NOT NULL,
                due_at REAL NOT NULL,
                stability REAL NOT NULL,
                difficulty REAL NOT NULL,
                phase_raw_value TEXT NOT NULL,
                learning_step INTEGER NOT NULL,
                scheduled_days REAL NOT NULL,
                elapsed_days REAL NOT NULL,
                algorithm_version TEXT NOT NULL,
                review_count INTEGER NOT NULL DEFAULT 0,
                UNIQUE(source_store_id, card_id, direction),
                FOREIGN KEY(legacy_card_key) REFERENCES practice_legacy_cards(legacy_card_key)
            );
            CREATE TABLE practice_legacy_reviews (
                legacy_review_key TEXT PRIMARY KEY NOT NULL,
                source_store_id TEXT NOT NULL,
                legacy_review_id TEXT NOT NULL,
                legacy_card_id TEXT NOT NULL,
                legacy_unit_key TEXT NOT NULL,
                raw_word_key TEXT NOT NULL,
                direction TEXT NOT NULL CHECK (direction IN ('recognition','reverse')),
                grade_raw_value TEXT NOT NULL,
                reviewed_at REAL NOT NULL,
                due_at REAL NOT NULL,
                stability REAL NOT NULL,
                difficulty REAL NOT NULL,
                phase_raw_value TEXT NOT NULL,
                learning_step INTEGER NOT NULL,
                scheduled_days REAL NOT NULL,
                elapsed_days REAL NOT NULL,
                algorithm_version TEXT NOT NULL,
                UNIQUE(source_store_id, legacy_review_id),
                FOREIGN KEY(legacy_card_id) REFERENCES practice_legacy_cards(legacy_card_key),
                FOREIGN KEY(legacy_unit_key) REFERENCES practice_legacy_review_units(legacy_unit_key)
            );
            CREATE TABLE practice_legacy_mastery (
                legacy_mastery_key TEXT PRIMARY KEY NOT NULL,
                source_store_id TEXT NOT NULL,
                legacy_mastery_id TEXT NOT NULL,
                legacy_card_id TEXT NOT NULL,
                skill_raw_value TEXT NOT NULL,
                score REAL NOT NULL,
                attempts INTEGER NOT NULL,
                correct INTEGER NOT NULL,
                last_updated REAL,
                UNIQUE(source_store_id, legacy_mastery_id),
                FOREIGN KEY(legacy_card_id) REFERENCES practice_legacy_cards(legacy_card_key)
            );
            CREATE TABLE practice_legacy_events (
                legacy_event_key TEXT PRIMARY KEY NOT NULL,
                source_store_id TEXT NOT NULL,
                legacy_event_id TEXT NOT NULL,
                legacy_card_id TEXT NOT NULL,
                skill_raw_value TEXT NOT NULL,
                correct INTEGER NOT NULL CHECK (correct IN (0,1)),
                occurred_at REAL NOT NULL,
                response_time_milliseconds INTEGER,
                answer TEXT,
                expected_answers_json TEXT NOT NULL,
                UNIQUE(source_store_id, legacy_event_id),
                FOREIGN KEY(legacy_card_id) REFERENCES practice_legacy_cards(legacy_card_key)
            );
            CREATE TABLE practice_migration_checkpoints (
                checkpoint_key TEXT PRIMARY KEY NOT NULL,
                source_store_id TEXT NOT NULL,
                migration_id TEXT NOT NULL,
                last_row_key TEXT,
                completed_rows INTEGER NOT NULL,
                expected_rows INTEGER NOT NULL,
                plan_digest TEXT NOT NULL,
                updated_at REAL NOT NULL,
                UNIQUE(source_store_id, migration_id)
            );
            CREATE INDEX practice_legacy_reviews_card_idx ON practice_legacy_reviews(legacy_card_id, reviewed_at);
            CREATE INDEX practice_legacy_reviews_due_idx ON practice_legacy_reviews(due_at, direction);
            CREATE INDEX practice_legacy_units_due_idx ON practice_legacy_review_units(due_at, direction);
            CREATE INDEX practice_legacy_mastery_card_idx ON practice_legacy_mastery(legacy_card_id, skill_raw_value);
            CREATE INDEX practice_legacy_events_card_idx ON practice_legacy_events(legacy_card_id, occurred_at);
            """)
            try db.execute(sql: "UPDATE practice_metadata SET value = '2' WHERE key = 'schema_version'")
        }
        migrator.registerMigration(reviewEffectsMigrationIdentifier) { db in
            // Rebuild the attempt table so an existing schema-2 database gains
            // the partial outcome while retaining every old row and child row.
            // The migration itself is one SQLite transaction.
            try db.execute(sql: "CREATE TABLE practice_help_events_backup AS SELECT event_id, attempt_id, kind, occurred_at FROM practice_help_events")
            try db.execute(sql: "CREATE TABLE practice_feedback_backup AS SELECT attempt_id, ordinal, message, is_error, confidence FROM practice_feedback")
            try db.execute(sql: "CREATE TABLE practice_attempt_rules_backup AS SELECT attempt_id, ordinal, code, span FROM practice_attempt_rules")
            try db.execute(sql: "DROP TABLE practice_help_events")
            try db.execute(sql: "DROP TABLE practice_feedback")
            try db.execute(sql: "DROP TABLE practice_attempt_rules")
            try db.execute(sql: "ALTER TABLE practice_attempts RENAME TO practice_attempts_schema2")
            try db.execute(sql: """
            CREATE TABLE practice_attempts (
                attempt_id TEXT PRIMARY KEY NOT NULL, session_id TEXT, exercise_id TEXT NOT NULL, unit_id TEXT NOT NULL,
                response TEXT NOT NULL, submitted_at REAL NOT NULL, idempotency_key TEXT UNIQUE,
                attempt_index INTEGER NOT NULL DEFAULT 0, outcome TEXT NOT NULL CHECK (outcome IN ('correct','partial','incorrect','skipped','unavailable','pending')),
                evaluator_result_json TEXT, events_json TEXT,
                FOREIGN KEY (unit_id) REFERENCES practice_review_units(unit_id)
            )
            """)
            try db.execute(sql: """
            INSERT INTO practice_attempts(attempt_id, session_id, exercise_id, unit_id, response, submitted_at, idempotency_key, attempt_index, outcome)
            SELECT attempt_id, session_id, exercise_id, unit_id, response, submitted_at, idempotency_key, 0, outcome FROM practice_attempts_schema2
            """)
            try db.execute(sql: "DROP TABLE practice_attempts_schema2")
            try db.execute(sql: """
            CREATE TABLE practice_help_events (
                event_id TEXT PRIMARY KEY NOT NULL, attempt_id TEXT NOT NULL,
                kind TEXT NOT NULL CHECK (kind IN ('hint','reveal','copiedAnswer','retry')), occurred_at REAL NOT NULL,
                FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE
            )
            """)
            try db.execute(sql: """
            CREATE TABLE practice_feedback (
                attempt_id TEXT NOT NULL, ordinal INTEGER NOT NULL, message TEXT NOT NULL,
                is_error INTEGER NOT NULL CHECK (is_error IN (0,1)), confidence REAL,
                PRIMARY KEY (attempt_id, ordinal), FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE
            )
            """)
            try db.execute(sql: """
            CREATE TABLE practice_attempt_rules (
                attempt_id TEXT NOT NULL, ordinal INTEGER NOT NULL, code TEXT NOT NULL, span TEXT,
                PRIMARY KEY (attempt_id, ordinal), FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE
            )
            """)
            try db.execute(sql: "INSERT INTO practice_help_events SELECT * FROM practice_help_events_backup")
            try db.execute(sql: "INSERT INTO practice_feedback SELECT * FROM practice_feedback_backup")
            try db.execute(sql: "INSERT INTO practice_attempt_rules SELECT * FROM practice_attempt_rules_backup")
            try db.execute(sql: "DROP TABLE practice_help_events_backup")
            try db.execute(sql: "DROP TABLE practice_feedback_backup")
            try db.execute(sql: "DROP TABLE practice_attempt_rules_backup")

            try db.execute(sql: "ALTER TABLE practice_review_units ADD COLUMN independent_evidence_count INTEGER NOT NULL DEFAULT 0")
            try db.execute(sql: "ALTER TABLE practice_review_units ADD COLUMN independent_score_total REAL NOT NULL DEFAULT 0")
            try db.execute(sql: """
            CREATE TABLE practice_learning_events (
                event_id TEXT PRIMARY KEY NOT NULL, attempt_id TEXT NOT NULL UNIQUE, unit_id TEXT NOT NULL,
                skill TEXT NOT NULL CHECK (skill IN ('writing','grammar','listening','speaking')),
                outcome TEXT NOT NULL CHECK (outcome IN ('correct','partial','incorrect','skipped','unavailable','pending')),
                score REAL, mastery_delta REAL NOT NULL, independent_recall_eligible INTEGER NOT NULL CHECK (independent_recall_eligible IN (0,1)),
                scheduling_eligible INTEGER NOT NULL CHECK (scheduling_eligible IN (0,1)), schedule_rating TEXT,
                unavailable_reason TEXT, occurred_at REAL NOT NULL, policy_version TEXT NOT NULL,
                FOREIGN KEY (attempt_id) REFERENCES practice_attempts(attempt_id) ON DELETE CASCADE,
                FOREIGN KEY (unit_id) REFERENCES practice_review_units(unit_id)
            )
            """)
            try db.execute(sql: "CREATE INDEX practice_learning_events_unit_idx ON practice_learning_events(unit_id, occurred_at)")
            try db.execute(sql: "CREATE INDEX practice_learning_events_attempt_idx ON practice_learning_events(attempt_id)")
            try db.execute(sql: "CREATE INDEX practice_attempts_unit_idx_v3 ON practice_attempts(unit_id, submitted_at)")
            try db.execute(sql: "CREATE INDEX practice_help_attempt_idx_v3 ON practice_help_events(attempt_id, occurred_at)")
            try db.execute(sql: "UPDATE practice_metadata SET value = '3' WHERE key = 'schema_version'")
        }
        return migrator
    }

    /// T006 preparation only: these tables are a retained, idempotent staging
    /// copy. They are not a production cutover or a second live writer.
    public static func migrationPolicy() -> String { "legacy recognition/reverse records remain immutable; ambiguous records stay in the retained source and are not copied" }
}
