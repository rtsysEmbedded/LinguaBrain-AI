import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

public actor InMemoryPracticeRepository: PracticeRepository {
    private var records: [UUID: Attempt] = [:]
    private var units: [UUID: (ReviewUnit, PracticeMasteryProjection?)] = [:]
    private var sentences: [String: Sentence] = [:]
    private var learningEvents: [UUID: PracticeLearningEvent] = [:]
    private var failNextTransactionWith: PracticePersistenceError?
    public init() {}
    public func failNextTransaction() { failNextTransactionWith = .transactionInProgress }
    public func saveReviewUnit(_ unit: ReviewUnit, projection: PracticeMasteryProjection? = nil) async throws { units[unit.id] = (unit, projection) }
    public func reviewUnit(id: UUID) async throws -> ReviewUnit? { units[id]?.0 }
    public func projection(for unitID: UUID) async throws -> PracticeMasteryProjection? { units[unitID]?.1 }
    public func saveSentence(_ sentence: Sentence) async throws { sentences["\(sentence.id):\(sentence.revision)"] = sentence }
    public func sentence(id: UUID, revision: Int) async throws -> Sentence? { sentences["\(id):\(revision)"] }
    public func saveAttempt(_ attempt: Attempt) async throws {
        if let existing = records[attempt.id], existing.outcome != .pending { return }
        records[attempt.id] = attempt
    }
    public func attempt(id: UUID) async throws -> Attempt? { records[id] }
    public func attempt(idempotencyKey: IdempotencyKey) async throws -> Attempt? { records.values.first { $0.idempotencyKey == idempotencyKey } }
    public func attempts(for unit: ReviewUnit) async throws -> [Attempt] { records.values.filter { $0.reviewUnitID == unit.id }.sorted { ($0.attemptIndex, $0.submittedAt, $0.id.uuidString) < ($1.attemptIndex, $1.submittedAt, $1.id.uuidString) } }
    public func saveLearningEvent(_ event: PracticeLearningEvent) async throws { if let old = learningEvents[event.id], old != event { throw PracticePersistenceError.immutableLearningEvent }; learningEvents[event.id] = event }
    public func learningEvent(id: UUID) async throws -> PracticeLearningEvent? { learningEvents[id] }
    public func learningEvents(for unit: ReviewUnit) async throws -> [PracticeLearningEvent] { learningEvents.values.filter { $0.reviewUnitID == unit.id }.sorted { $0.occurredAt < $1.occurredAt } }
    /// This is intentionally a test fake. It snapshots state so tests do not
    /// accidentally imply production transaction guarantees.
    public func transaction(_ operation: @Sendable () async throws -> Void) async throws {
        if let failure = failNextTransactionWith { failNextTransactionWith = nil; throw failure }
        let before = records
        let beforeUnits = units; let beforeSentences = sentences; let beforeEvents = learningEvents
        do { try await operation() } catch { records = before; units = beforeUnits; sentences = beforeSentences; learningEvents = beforeEvents; throw error }
    }
}

public enum PracticePersistenceError: Error, Equatable, Sendable { case invalidStore; case invalidRecord; case immutableRevision; case immutableLearningEvent; case transactionInProgress }

/// File-backed contract fixture. It uses an atomic replacement write and
/// commits a transaction only after every operation succeeds. It is not wired
/// into production composition until the ADR-003 GRDB cutover is approved.
public actor FileBackedPracticeRepository: PracticeRepository {
    private struct Store: Codable { var attempts: [UUID: Attempt] = [:]; var units: [UUID: StoredUnit] = [:]; var sentences: [String: Sentence] = [:]; var learningEvents: [UUID: PracticeLearningEvent] = [:] }
    private struct StoredUnit: Codable { let unit: ReviewUnit; let projection: PracticeMasteryProjection? }
    private let url: URL
    private var store: Store
    private var inTransaction = false

    public init(url: URL) throws {
        self.url = url
        if FileManager.default.fileExists(atPath: url.path) {
            do { store = try JSONDecoder().decode(Store.self, from: Data(contentsOf: url)) }
            catch { throw PracticePersistenceError.invalidStore }
        } else { store = Store() }
    }

    public func saveAttempt(_ attempt: Attempt) async throws {
        if let existing = store.attempts[attempt.id], existing.outcome != .pending { return }
        store.attempts[attempt.id] = attempt
        if !inTransaction { try flush() }
    }
    public func saveReviewUnit(_ unit: ReviewUnit, projection: PracticeMasteryProjection? = nil) async throws { store.units[unit.id] = StoredUnit(unit: unit, projection: projection); if !inTransaction { try flush() } }
    public func reviewUnit(id: UUID) async throws -> ReviewUnit? { store.units[id]?.unit }
    public func projection(for unitID: UUID) async throws -> PracticeMasteryProjection? { store.units[unitID]?.projection }
    public func saveSentence(_ sentence: Sentence) async throws { store.sentences["\(sentence.id):\(sentence.revision)"] = sentence; if !inTransaction { try flush() } }
    public func sentence(id: UUID, revision: Int) async throws -> Sentence? { store.sentences["\(id):\(revision)"] }
    public func attempt(id: UUID) async throws -> Attempt? { store.attempts[id] }
    public func attempt(idempotencyKey: IdempotencyKey) async throws -> Attempt? { store.attempts.values.first { $0.idempotencyKey == idempotencyKey } }
    public func attempts(for unit: ReviewUnit) async throws -> [Attempt] { store.attempts.values.filter { $0.reviewUnitID == unit.id }.sorted { ($0.attemptIndex, $0.submittedAt, $0.id.uuidString) < ($1.attemptIndex, $1.submittedAt, $1.id.uuidString) } }
    public func saveLearningEvent(_ event: PracticeLearningEvent) async throws { if let old = store.learningEvents[event.id], old != event { throw PracticePersistenceError.immutableLearningEvent }; store.learningEvents[event.id] = event; if !inTransaction { try flush() } }
    public func learningEvent(id: UUID) async throws -> PracticeLearningEvent? { store.learningEvents[id] }
    public func learningEvents(for unit: ReviewUnit) async throws -> [PracticeLearningEvent] { store.learningEvents.values.filter { $0.reviewUnitID == unit.id }.sorted { $0.occurredAt < $1.occurredAt } }
    public func transaction(_ operation: @Sendable () async throws -> Void) async throws {
        let before = store
        inTransaction = true
        do { try await operation(); inTransaction = false; try flush() }
        catch { store = before; inTransaction = false; throw error }
    }
    private func flush() throws {
        let data = try JSONEncoder().encode(store)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
