import Foundation
import GRDB
import LinguaBrainDomain
import LinguaBrainApplication

/// The production practice adapter. GRDB rows and SQL are intentionally kept
/// private to this target; callers exchange only domain values and ports.
public actor GRDBPracticeRepository: PracticeRepository {
    private enum Operation { case sentence(Sentence); case unit(ReviewUnit, PracticeMasteryProjection?); case attempt(Attempt); case learningEvent(PracticeLearningEvent) }
    private let pool: DatabasePool
    private var transactionOperations: [Operation]?

    public init(url: URL) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in try db.execute(sql: "PRAGMA foreign_keys = ON") }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        pool = try DatabasePool(path: url.path, configuration: configuration)
        try PracticeMigrations.migrator().migrate(pool)
    }

    public func saveReviewUnit(_ unit: ReviewUnit, projection: PracticeMasteryProjection? = nil) async throws {
        if transactionOperations != nil { transactionOperations?.append(.unit(unit, projection)); return }
        try await pool.write { try Self.persist(unit: unit, projection: projection, in: $0) }
    }
    public func reviewUnit(id: UUID) async throws -> ReviewUnit? {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM practice_review_units WHERE unit_id = ?", arguments: [id.uuidString]) else { return nil }
            return Self.unit(from: row)
        }
    }
    public func projection(for unitID: UUID) async throws -> PracticeMasteryProjection? {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT mastery_state, mastery_score, due_at, algorithm_version, scheduler_state, independent_evidence_count, independent_score_total FROM practice_review_units WHERE unit_id = ?", arguments: [unitID.uuidString]), let state = PracticeMasteryState(rawValue: row["mastery_state"] as String) else { return nil }
            return PracticeMasteryProjection(state: state, score: row["mastery_score"] as Double?, dueAt: (row["due_at"] as Double?).map(Date.init(timeIntervalSince1970:)), algorithmVersion: row["algorithm_version"] as String?, schedulerState: row["scheduler_state"] as String?, independentEvidenceCount: row["independent_evidence_count"] as Int? ?? 0, independentScoreTotal: row["independent_score_total"] as Double? ?? 0)
        }
    }
    public func saveSentence(_ sentence: Sentence) async throws {
        if transactionOperations != nil { transactionOperations?.append(.sentence(sentence)); return }
        try await pool.write { try Self.persist(sentence: sentence, in: $0) }
    }
    public func sentence(id: UUID, revision: Int) async throws -> Sentence? {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM practice_sentences WHERE sentence_id = ? AND revision = ?", arguments: [id.uuidString, revision]) else { return nil }
            return try Self.sentence(from: row, db: db)
        }
    }
    public func saveAttempt(_ attempt: Attempt) async throws {
        if transactionOperations != nil { transactionOperations?.append(.attempt(attempt)); return }
        try await pool.write { try Self.persist(attempt: attempt, in: $0) }
    }
    public func attempt(id: UUID) async throws -> Attempt? {
        try await pool.read { db in try Self.attempt(id: id, in: db) }
    }
    public func attempt(idempotencyKey: IdempotencyKey) async throws -> Attempt? {
        try await pool.read { db in
            guard let row = try Row.fetchOne(db, sql: "SELECT * FROM practice_attempts WHERE idempotency_key = ?", arguments: [idempotencyKey.rawValue]) else { return nil }
            return try Self.attempt(from: row, db: db)
        }
    }
    public func attempts(for unit: ReviewUnit) async throws -> [Attempt] {
        try await pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM practice_attempts WHERE unit_id = ? ORDER BY attempt_index, submitted_at, attempt_id", arguments: [unit.id.uuidString]).map { try Self.attempt(from: $0, db: db) }
        }
    }
    public func saveLearningEvent(_ event: PracticeLearningEvent) async throws {
        if transactionOperations != nil { transactionOperations?.append(.learningEvent(event)); return }
        try await pool.write { try Self.persist(learningEvent: event, in: $0) }
    }
    public func learningEvent(id: UUID) async throws -> PracticeLearningEvent? {
        try await pool.read { db in try Self.learningEvent(id: id, in: db) }
    }
    public func learningEvents(for unit: ReviewUnit) async throws -> [PracticeLearningEvent] {
        try await pool.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM practice_learning_events WHERE unit_id = ? ORDER BY occurred_at, event_id", arguments: [unit.id.uuidString]).map(Self.learningEvent)
        }
    }

    /// Buffers domain writes while the async application closure runs, then
    /// applies the complete batch inside one SQLite transaction. Failure drops
    /// the batch before any learner-visible state is committed.
    public func transaction(_ operation: @Sendable () async throws -> Void) async throws {
        guard transactionOperations == nil else { throw PracticePersistenceError.transactionInProgress }
        transactionOperations = []
        do {
            try await operation()
            let operations = transactionOperations ?? []
            try await pool.write { db in
                // DatabasePool.write supplies the single SQLite transaction.
                // Do not nest db.inTransaction here.
                for operation in operations {
                    switch operation {
                    case let .sentence(sentence): try Self.persist(sentence: sentence, in: db)
                    case let .unit(unit, projection): try Self.persist(unit: unit, projection: projection, in: db)
                    case let .attempt(attempt): try Self.persist(attempt: attempt, in: db)
                    case let .learningEvent(event): try Self.persist(learningEvent: event, in: db)
                    }
                }
            }
            transactionOperations = nil
        } catch {
            transactionOperations = nil
            throw error
        }
    }

    public func validateForeignKeys() async throws -> Bool { try await pool.read { try Row.fetchAll($0, sql: "PRAGMA foreign_key_check").isEmpty } }

    private static func persist(sentence: Sentence, in db: Database) throws {
        if let existing = try Row.fetchOne(db, sql: "SELECT text, translation FROM practice_sentences WHERE sentence_id = ? AND revision = ?", arguments: [sentence.id.uuidString, sentence.revision]) {
            let same = (existing["text"] as String) == sentence.text && (existing["translation"] as String) == sentence.translation
            if !same { throw PracticePersistenceError.immutableRevision }
            return
        }
        try db.execute(sql: "INSERT INTO practice_sentences(sentence_id, revision, text, translation, original_learner_response, minimal_correction, natural_variant, validation, provenance_json) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", arguments: [sentence.id.uuidString, sentence.revision, sentence.text, sentence.translation, sentence.originalLearnerResponse, sentence.minimalCorrection, sentence.naturalVariant, sentence.validation.rawValue, Self.json(sentence.provenance)])
        for (index, rule) in sentence.ruleReferences.enumerated() { try db.execute(sql: "INSERT INTO practice_sentence_rules(sentence_id, revision, ordinal, code, span) VALUES (?, ?, ?, ?, ?)", arguments: [sentence.id.uuidString, sentence.revision, index, rule.code, rule.span]) }
        for (index, reference) in sentence.lexicalReferences.enumerated() { try db.execute(sql: "INSERT INTO practice_sentence_lexical_refs(sentence_id, revision, ordinal, sense_key, surface) VALUES (?, ?, ?, ?, ?)", arguments: [sentence.id.uuidString, sentence.revision, index, reference.senseKey, reference.surface]) }
    }

    private static func persist(unit: ReviewUnit, projection: PracticeMasteryProjection?, in db: Database) throws {
        let projection = projection ?? PracticeMasteryProjection()
        try db.execute(sql: """
        INSERT INTO practice_review_units(unit_id, stable_key, learner_id, skill, objective_key, sentence_id, sentence_revision, mastery_state, mastery_score, due_at, algorithm_version, scheduler_state, independent_evidence_count, independent_score_total, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(unit_id) DO UPDATE SET stable_key=excluded.stable_key, learner_id=excluded.learner_id, skill=excluded.skill, objective_key=excluded.objective_key, sentence_id=excluded.sentence_id, sentence_revision=excluded.sentence_revision, mastery_state=excluded.mastery_state, mastery_score=excluded.mastery_score, due_at=excluded.due_at, algorithm_version=excluded.algorithm_version, scheduler_state=excluded.scheduler_state, independent_evidence_count=excluded.independent_evidence_count, independent_score_total=excluded.independent_score_total, updated_at=excluded.updated_at
        """, arguments: [unit.id.uuidString, unit.stableKey, unit.learnerID, unit.skill.rawValue, unit.objectiveKey, unit.sentenceID?.uuidString, unit.sentenceRevision, projection.state.rawValue, projection.score, projection.dueAt?.timeIntervalSince1970, projection.algorithmVersion, projection.schedulerState, projection.independentEvidenceCount, projection.independentScoreTotal, Date().timeIntervalSince1970])
    }

    private static func persist(attempt: Attempt, in db: Database) throws {
        if let existing = try Row.fetchOne(db, sql: "SELECT outcome FROM practice_attempts WHERE attempt_id = ?", arguments: [attempt.id.uuidString]), (existing["outcome"] as String) != AttemptOutcome.pending.rawValue { return }
        if let key = attempt.idempotencyKey?.rawValue, let existing = try Row.fetchOne(db, sql: "SELECT attempt_id FROM practice_attempts WHERE idempotency_key = ?", arguments: [key]), (existing["attempt_id"] as String) != attempt.id.uuidString { return }
        try db.execute(sql: """
        INSERT INTO practice_attempts(attempt_id, session_id, exercise_id, unit_id, response, submitted_at, idempotency_key, attempt_index, outcome, evaluator_result_json, events_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(attempt_id) DO UPDATE SET session_id=excluded.session_id, exercise_id=excluded.exercise_id, unit_id=excluded.unit_id, response=excluded.response, submitted_at=excluded.submitted_at, idempotency_key=excluded.idempotency_key, attempt_index=excluded.attempt_index, outcome=excluded.outcome, evaluator_result_json=excluded.evaluator_result_json, events_json=excluded.events_json
        WHERE practice_attempts.outcome = 'pending'
        """, arguments: [attempt.id.uuidString, attempt.sessionID?.uuidString, attempt.exerciseID.uuidString, attempt.reviewUnitID.uuidString, attempt.response, attempt.submittedAt.timeIntervalSince1970, attempt.idempotencyKey?.rawValue, attempt.attemptIndex, attempt.outcome.rawValue, Self.json(attempt.evaluatorResult), Self.json(attempt.events)])
        try db.execute(sql: "DELETE FROM practice_help_events WHERE attempt_id = ?", arguments: [attempt.id.uuidString])
        try db.execute(sql: "DELETE FROM practice_feedback WHERE attempt_id = ?", arguments: [attempt.id.uuidString])
        try db.execute(sql: "DELETE FROM practice_attempt_rules WHERE attempt_id = ?", arguments: [attempt.id.uuidString])
        for help in attempt.help { try db.execute(sql: "INSERT INTO practice_help_events(event_id, attempt_id, kind, occurred_at) VALUES (?, ?, ?, ?)", arguments: [help.id.uuidString, attempt.id.uuidString, help.kind.rawValue, help.at.timeIntervalSince1970]) }
        for (index, feedback) in attempt.feedback.enumerated() { try db.execute(sql: "INSERT INTO practice_feedback(attempt_id, ordinal, message, is_error, confidence) VALUES (?, ?, ?, ?, ?)", arguments: [attempt.id.uuidString, index, feedback.message, feedback.isError ? 1 : 0, feedback.confidence]) }
        for (index, rule) in attempt.rules.enumerated() { try db.execute(sql: "INSERT INTO practice_attempt_rules(attempt_id, ordinal, code, span) VALUES (?, ?, ?, ?)", arguments: [attempt.id.uuidString, index, rule.code, rule.span]) }
    }

    private static func persist(learningEvent event: PracticeLearningEvent, in db: Database) throws {
        if let existing = try learningEvent(id: event.id, in: db) {
            if existing != event { throw PracticePersistenceError.immutableLearningEvent }
            return
        }
        try db.execute(sql: """
        INSERT INTO practice_learning_events(event_id, attempt_id, unit_id, skill, outcome, score, mastery_delta, independent_recall_eligible, scheduling_eligible, schedule_rating, unavailable_reason, occurred_at, policy_version)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, arguments: [event.id.uuidString, event.attemptID.uuidString, event.reviewUnitID.uuidString, event.skill.rawValue, event.outcome.rawValue, event.score, event.masteryDelta, event.independentRecallEligible ? 1 : 0, event.schedulingEligible ? 1 : 0, event.scheduleRating?.rawValue, event.unavailableReason?.rawValue, event.occurredAt.timeIntervalSince1970, event.policyVersion])
    }

    private static func attempt(id: UUID, in db: Database) throws -> Attempt? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM practice_attempts WHERE attempt_id = ?", arguments: [id.uuidString]) else { return nil }
        return try attempt(from: row, db: db)
    }
    private static func attempt(from row: Row, db: Database) throws -> Attempt {
        let id: UUID = try uuid(row["attempt_id"] as String); let session = (row["session_id"] as String?).flatMap(UUID.init(uuidString:)); let exercise = try uuid(row["exercise_id"] as String); let unit = try uuid(row["unit_id"] as String)
        let attemptID = id.uuidString
        let help = try Row.fetchAll(db, sql: "SELECT * FROM practice_help_events WHERE attempt_id = ? ORDER BY occurred_at, event_id", arguments: [attemptID]).map { HelpEvent(id: try uuid($0["event_id"] as String), kind: try helpKind($0["kind"] as String), at: Date(timeIntervalSince1970: $0["occurred_at"] as Double)) }
        let feedback = try Row.fetchAll(db, sql: "SELECT * FROM practice_feedback WHERE attempt_id = ? ORDER BY ordinal", arguments: [attemptID]).map { TypedFeedback(message: $0["message"] as String, isError: ($0["is_error"] as Int64) == 1, confidence: $0["confidence"] as Double?) }
        let rules = try Row.fetchAll(db, sql: "SELECT * FROM practice_attempt_rules WHERE attempt_id = ? ORDER BY ordinal", arguments: [attemptID]).map { RuleReference(code: $0["code"] as String, span: $0["span"] as String?) }
        return Attempt(id: id, sessionID: session, exerciseID: exercise, reviewUnitID: unit, response: row["response"] as String, submittedAt: Date(timeIntervalSince1970: row["submitted_at"] as Double), attemptIndex: row["attempt_index"] as Int? ?? 0, idempotencyKey: (row["idempotency_key"] as String?).map(IdempotencyKey.init(rawValue:)), outcome: try outcome(row["outcome"] as String), evaluatorResult: try decodeJSON(row["evaluator_result_json"] as String?), feedback: feedback, help: help, events: (try decodeJSON(row["events_json"] as String?)) ?? [], rules: rules)
    }
    private static func sentence(from row: Row, db: Database) throws -> Sentence {
        let id = try uuid(row["sentence_id"] as String); let revision = row["revision"] as Int
        let rules = try Row.fetchAll(db, sql: "SELECT * FROM practice_sentence_rules WHERE sentence_id = ? AND revision = ? ORDER BY ordinal", arguments: [id.uuidString, revision]).map { RuleReference(code: $0["code"] as String, span: $0["span"] as String?) }
        let refs = try Row.fetchAll(db, sql: "SELECT * FROM practice_sentence_lexical_refs WHERE sentence_id = ? AND revision = ? ORDER BY ordinal", arguments: [id.uuidString, revision]).map { LexicalReference(senseKey: $0["sense_key"] as String, surface: $0["surface"] as String?) }
        return Sentence(id: id, revision: revision, text: row["text"] as String, translation: row["translation"] as String, originalLearnerResponse: row["original_learner_response"] as String?, minimalCorrection: row["minimal_correction"] as String?, naturalVariant: row["natural_variant"] as String?, validation: try validation(row["validation"] as String), provenance: try decodeJSON(row["provenance_json"] as String?), ruleReferences: rules, lexicalReferences: refs)
    }
    private static func unit(from row: Row) -> ReviewUnit { ReviewUnit(id: UUID(uuidString: row["unit_id"] as String), learnerID: row["learner_id"] as String, skill: PracticeSkill(rawValue: row["skill"] as String)!, objectiveKey: row["objective_key"] as String, sentenceID: (row["sentence_id"] as String?).flatMap(UUID.init(uuidString:)), sentenceRevision: row["sentence_revision"] as Int?) }
    private static func learningEvent(id: UUID, in db: Database) throws -> PracticeLearningEvent? {
        guard let row = try Row.fetchOne(db, sql: "SELECT * FROM practice_learning_events WHERE event_id = ?", arguments: [id.uuidString]) else { return nil }
        return try learningEvent(from: row)
    }
    private static func learningEvent(from row: Row) throws -> PracticeLearningEvent {
        guard let id = UUID(uuidString: row["event_id"] as String), let attemptID = UUID(uuidString: row["attempt_id"] as String), let unitID = UUID(uuidString: row["unit_id"] as String), let skill = PracticeSkill(rawValue: row["skill"] as String), let outcome = AttemptOutcome(rawValue: row["outcome"] as String) else {
            throw PracticePersistenceError.invalidRecord
        }
        let rating = (row["schedule_rating"] as String?).flatMap(PracticeScheduleRating.init(rawValue:))
        return PracticeLearningEvent(id: id, attemptID: attemptID, reviewUnitID: unitID, skill: skill, outcome: outcome, score: row["score"] as Double?, masteryDelta: row["mastery_delta"] as Double, independentRecallEligible: (row["independent_recall_eligible"] as Int64) == 1, schedulingEligible: (row["scheduling_eligible"] as Int64) == 1, scheduleRating: rating, unavailableReason: (row["unavailable_reason"] as String?).flatMap(PracticeUnavailableReason.init(rawValue:)), occurredAt: Date(timeIntervalSince1970: row["occurred_at"] as Double), policyVersion: row["policy_version"] as String)
    }
    private static func json<T: Encodable>(_ value: T?) -> String? { guard let value else { return nil }; return try? String(data: JSONEncoder().encode(value), encoding: .utf8) }
    private static func decodeJSON<T: Decodable>(_ value: String?) throws -> T? { guard let value else { return nil }; return try JSONDecoder().decode(T.self, from: Data(value.utf8)) }
    private static func uuid(_ value: String) throws -> UUID { guard let value = UUID(uuidString: value) else { throw PracticePersistenceError.invalidRecord }; return value }
    private static func outcome(_ value: String) throws -> AttemptOutcome { guard let value = AttemptOutcome(rawValue: value) else { throw PracticePersistenceError.invalidRecord }; return value }
    private static func helpKind(_ value: String) throws -> HelpKind { guard let value = HelpKind(rawValue: value) else { throw PracticePersistenceError.invalidRecord }; return value }
    private static func validation(_ value: String) throws -> SentenceValidationStatus { guard let value = SentenceValidationStatus(rawValue: value) else { throw PracticePersistenceError.invalidRecord }; return value }
}
