import Foundation
import LinguaBrainDomain

/// The direction encoded by the SwiftData prototype. `mixedGame` is not a
/// durable direction and is deliberately excluded from the migration plan.
public enum LegacyReviewDirection: String, Codable, Sendable, Equatable {
    case recognition
    case reverse
}

public struct LegacyCardSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let deckID: UUID
    public let position: Int
    public let german: String
    public let persian: String
    public let article: String?
    public let level: String
    public let partOfSpeech: String
    public let example: String
    public let exampleTranslation: String
    public let examplesJSON: String
    public let sensesJSON: String
    public let domain: String
    public let createdAt: Date
    public let sourceIdentifier: String?
    public let sourcePackage: String?
    public let sourceLanguageTag: String
    public let targetLanguageTag: String
    public let pronunciationAudioAssetID: UUID?
    public let pronunciationAudioFilename: String?
    public let illustrationImageAssetID: UUID?
    public let illustrationImageFilename: String?

    public init(
        id: UUID, deckID: UUID, position: Int, german: String, persian: String,
        article: String?, level: String, partOfSpeech: String, example: String,
        exampleTranslation: String, examplesJSON: String = "[]", sensesJSON: String = "[]",
        domain: String = "عمومی", createdAt: Date, sourceIdentifier: String? = nil,
        sourcePackage: String? = nil, sourceLanguageTag: String = "fa",
        targetLanguageTag: String = "de", pronunciationAudioAssetID: UUID? = nil,
        pronunciationAudioFilename: String? = nil, illustrationImageAssetID: UUID? = nil,
        illustrationImageFilename: String? = nil
    ) {
        self.id = id; self.deckID = deckID; self.position = position; self.german = german; self.persian = persian
        self.article = article; self.level = level; self.partOfSpeech = partOfSpeech; self.example = example
        self.exampleTranslation = exampleTranslation; self.examplesJSON = examplesJSON; self.sensesJSON = sensesJSON
        self.domain = domain; self.createdAt = createdAt; self.sourceIdentifier = sourceIdentifier; self.sourcePackage = sourcePackage
        self.sourceLanguageTag = sourceLanguageTag; self.targetLanguageTag = targetLanguageTag
        self.pronunciationAudioAssetID = pronunciationAudioAssetID; self.pronunciationAudioFilename = pronunciationAudioFilename
        self.illustrationImageAssetID = illustrationImageAssetID; self.illustrationImageFilename = illustrationImageFilename
    }
}

public struct LegacyReviewSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let wordKey: String
    public let gradeRawValue: String
    public let reviewedAt: Date
    public let dueAt: Date
    public let stability: Double
    public let difficulty: Double
    public let phaseRawValue: String
    public let learningStep: Int
    public let scheduledDays: Double
    public let elapsedDays: Double
    public let algorithmVersion: String

    public init(id: UUID, wordKey: String, gradeRawValue: String, reviewedAt: Date, dueAt: Date,
                stability: Double, difficulty: Double, phaseRawValue: String, learningStep: Int,
                scheduledDays: Double, elapsedDays: Double, algorithmVersion: String) {
        self.id = id; self.wordKey = wordKey; self.gradeRawValue = gradeRawValue; self.reviewedAt = reviewedAt; self.dueAt = dueAt
        self.stability = stability; self.difficulty = difficulty; self.phaseRawValue = phaseRawValue; self.learningStep = learningStep
        self.scheduledDays = scheduledDays; self.elapsedDays = elapsedDays; self.algorithmVersion = algorithmVersion
    }
}

public struct LegacyMasterySnapshot: Codable, Sendable, Equatable {
    public let id: String
    public let cardID: UUID
    public let skillRawValue: String
    public let score: Double
    public let attempts: Int
    public let correct: Int
    public let lastUpdated: Date?

    public init(id: String, cardID: UUID, skillRawValue: String, score: Double, attempts: Int,
                correct: Int, lastUpdated: Date?) {
        self.id = id; self.cardID = cardID; self.skillRawValue = skillRawValue; self.score = score
        self.attempts = attempts; self.correct = correct; self.lastUpdated = lastUpdated
    }
}

public struct LegacyLearningEventSnapshot: Codable, Sendable, Equatable {
    public let id: UUID
    public let cardID: UUID
    public let skillRawValue: String
    public let correct: Bool
    public let occurredAt: Date
    public let responseTimeMilliseconds: Int?
    public let answer: String?
    public let expectedAnswersJSON: String

    public init(id: UUID, cardID: UUID, skillRawValue: String, correct: Bool, occurredAt: Date,
                responseTimeMilliseconds: Int?, answer: String?, expectedAnswersJSON: String = "[]") {
        self.id = id; self.cardID = cardID; self.skillRawValue = skillRawValue; self.correct = correct; self.occurredAt = occurredAt
        self.responseTimeMilliseconds = responseTimeMilliseconds; self.answer = answer; self.expectedAnswersJSON = expectedAnswersJSON
    }
}

public struct LegacyPracticeSnapshot: Codable, Sendable, Equatable {
    public let sourceStoreID: String
    public let cards: [LegacyCardSnapshot]
    public let reviews: [LegacyReviewSnapshot]
    public let masteries: [LegacyMasterySnapshot]
    public let learningEvents: [LegacyLearningEventSnapshot]
    public let capturedAt: Date

    public init(sourceStoreID: String, cards: [LegacyCardSnapshot], reviews: [LegacyReviewSnapshot],
                masteries: [LegacyMasterySnapshot], learningEvents: [LegacyLearningEventSnapshot],
                capturedAt: Date) {
        self.sourceStoreID = sourceStoreID; self.cards = cards; self.reviews = reviews; self.masteries = masteries
        self.learningEvents = learningEvents; self.capturedAt = capturedAt
    }
}

public enum LegacyMigrationIssue: Error, Codable, Sendable, Equatable {
    case emptySourceStoreID
    case duplicateCard(UUID)
    case duplicateReview(UUID)
    case duplicateMastery(String)
    case duplicateEvent(UUID)
    case malformedReviewKey(String)
    case ambiguousReviewKey(String)
    case missingCard(String)
    case invalidGrade(UUID, String)
    case invalidNumericField(String)
    case invalidMasteryCounts(String)
    case unsupportedReviewDirection(String)
    case unsupportedSkill(String)
}

public enum LegacyPracticeMigrationError: Error, Sendable, Equatable {
    case invalidSnapshot([LegacyMigrationIssue])
    case checkpointDoesNotMatchPlan
    case verificationMismatch(expected: LegacyMigrationCounts, actual: LegacyMigrationCounts)
    case digestMismatch(expected: String, actual: String)
}

public struct LegacyReviewEvidence: Codable, Sendable, Equatable {
    public let rowKey: String
    public let sourceStoreID: String
    public let sourceReviewID: UUID
    public let legacyCardKey: String
    public let cardID: UUID
    public let rawWordKey: String
    public let direction: LegacyReviewDirection
    public let gradeRawValue: String
    public let reviewedAt: Date
    public let dueAt: Date
    public let stability: Double
    public let difficulty: Double
    public let phaseRawValue: String
    public let learningStep: Int
    public let scheduledDays: Double
    public let elapsedDays: Double
    public let algorithmVersion: String

    public var legacyUnitKey: String { "unit::\(sourceStoreID)::\(cardID.uuidString.lowercased())::\(direction.rawValue)" }
}

public struct LegacyMasteryEvidence: Codable, Sendable, Equatable {
    public let rowKey: String
    public let sourceStoreID: String
    public let sourceMasteryID: String
    public let legacyCardKey: String
    public let cardID: UUID
    public let skillRawValue: String
    public let score: Double
    public let attempts: Int
    public let correct: Int
    public let lastUpdated: Date?
}

public struct LegacyEventEvidence: Codable, Sendable, Equatable {
    public let rowKey: String
    public let sourceStoreID: String
    public let sourceEventID: UUID
    public let legacyCardKey: String
    public let cardID: UUID
    public let skillRawValue: String
    public let correct: Bool
    public let occurredAt: Date
    public let responseTimeMilliseconds: Int?
    public let answer: String?
    public let expectedAnswersJSON: String
}

public struct LegacyCardEvidence: Codable, Sendable, Equatable {
    public let rowKey: String
    public let sourceStoreID: String
    public let card: LegacyCardSnapshot

    public init(rowKey: String, sourceStoreID: String, card: LegacyCardSnapshot) {
        self.rowKey = rowKey; self.sourceStoreID = sourceStoreID; self.card = card
    }
}

public struct LegacyNewSkillSeed: Codable, Sendable, Equatable {
    public let cardID: UUID
    public let skill: PracticeSkill
    public let state: PracticeMasteryState

    public init(cardID: UUID, skill: PracticeSkill, state: PracticeMasteryState = .unknown) {
        self.cardID = cardID; self.skill = skill; self.state = state
    }
}

public enum LegacyMigrationRow: Codable, Sendable, Equatable {
    case card(LegacyCardEvidence)
    case review(LegacyReviewEvidence)
    case mastery(LegacyMasteryEvidence)
    case event(LegacyEventEvidence)

    public var rowKey: String {
        switch self {
        case let .card(value): value.rowKey
        case let .review(value): value.rowKey
        case let .mastery(value): value.rowKey
        case let .event(value): value.rowKey
        }
    }
}

public struct LegacyMigrationCounts: Codable, Sendable, Equatable {
    public let cards: Int
    public let reviews: Int
    public let masteries: Int
    public let events: Int

    public init(cards: Int = 0, reviews: Int = 0, masteries: Int = 0, events: Int = 0) {
        self.cards = cards; self.reviews = reviews; self.masteries = masteries; self.events = events
    }
    public var total: Int { cards + reviews + masteries + events }
}

public struct LegacyPracticeMigrationPlan: Codable, Sendable, Equatable {
    public static let migrationID = "swiftdata-v1-to-practice-v2"
    public let sourceStoreID: String
    public let migrationID: String
    public let rows: [LegacyMigrationRow]
    public let newSkillSeeds: [LegacyNewSkillSeed]
    public let excludedSkillValues: [String]
    public let expectedCounts: LegacyMigrationCounts
    public let digest: String

    public init(sourceStoreID: String, rows: [LegacyMigrationRow], newSkillSeeds: [LegacyNewSkillSeed],
                excludedSkillValues: [String]) {
        self.sourceStoreID = sourceStoreID; self.migrationID = Self.migrationID; self.rows = rows
        self.newSkillSeeds = newSkillSeeds; self.excludedSkillValues = excludedSkillValues
        var counts = LegacyMigrationCounts()
        for row in rows {
            switch row { case .card: counts = .init(cards: counts.cards + 1, reviews: counts.reviews, masteries: counts.masteries, events: counts.events)
            case .review: counts = .init(cards: counts.cards, reviews: counts.reviews + 1, masteries: counts.masteries, events: counts.events)
            case .mastery: counts = .init(cards: counts.cards, reviews: counts.reviews, masteries: counts.masteries + 1, events: counts.events)
            case .event: counts = .init(cards: counts.cards, reviews: counts.reviews, masteries: counts.masteries, events: counts.events + 1) }
        }
        self.expectedCounts = counts
        self.digest = LegacyMigrationDigest.make(rows: rows)
    }

    public func verify(actualCounts: LegacyMigrationCounts, actualDigest: String) throws {
        guard actualCounts == expectedCounts else { throw LegacyPracticeMigrationError.verificationMismatch(expected: expectedCounts, actual: actualCounts) }
        guard actualDigest == digest else { throw LegacyPracticeMigrationError.digestMismatch(expected: digest, actual: actualDigest) }
    }
}

public struct LegacyMigrationCheckpoint: Codable, Sendable, Equatable {
    public let sourceStoreID: String
    public let migrationID: String
    public let lastRowKey: String?
    public let completedRows: Int
    public let expectedRows: Int
    public let planDigest: String
    public let updatedAt: Date

    public init(sourceStoreID: String, migrationID: String, lastRowKey: String?, completedRows: Int,
                expectedRows: Int, planDigest: String, updatedAt: Date) {
        self.sourceStoreID = sourceStoreID; self.migrationID = migrationID; self.lastRowKey = lastRowKey
        self.completedRows = completedRows; self.expectedRows = expectedRows; self.planDigest = planDigest; self.updatedAt = updatedAt
    }
}

public protocol LegacyPracticeMigrationSink: Sendable {
    func apply(_ row: LegacyMigrationRow) async throws
    func save(_ checkpoint: LegacyMigrationCheckpoint) async throws
}

public struct LegacyMigrationReport: Codable, Sendable, Equatable {
    public let sourceStoreID: String
    public let appliedRows: Int
    public let checkpoint: LegacyMigrationCheckpoint
    public let expectedCounts: LegacyMigrationCounts
}

public struct LegacyPracticeMigrationPlanner: Sendable {
    public init() {}

    public func makePlan(from snapshot: LegacyPracticeSnapshot) throws -> LegacyPracticeMigrationPlan {
        var issues: [LegacyMigrationIssue] = []
        guard !snapshot.sourceStoreID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw LegacyPracticeMigrationError.invalidSnapshot([.emptySourceStoreID]) }
        var cardsByID: [UUID: LegacyCardSnapshot] = [:]
        for card in snapshot.cards {
            if cardsByID.updateValue(card, forKey: card.id) != nil { issues.append(.duplicateCard(card.id)) }
        }
        if issues.isEmpty == false { throw LegacyPracticeMigrationError.invalidSnapshot(issues) }

        let sortedCards: [LegacyMigrationRow] = snapshot.cards.sorted { $0.id.uuidString < $1.id.uuidString }.map { card in
            .card(LegacyCardEvidence(rowKey: "card::\(snapshot.sourceStoreID)::\(card.id.uuidString.lowercased())", sourceStoreID: snapshot.sourceStoreID, card: card))
        }
        var reviewRows: [LegacyMigrationRow] = []
        var seenReviews = Set<UUID>()
        for review in snapshot.reviews.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            guard seenReviews.insert(review.id).inserted else { issues.append(.duplicateReview(review.id)); continue }
            guard let resolved = resolve(review.wordKey, cards: snapshot.cards) else {
                issues.append(issueForReviewKey(review.wordKey, cards: snapshot.cards)); continue
            }
            guard validGrade(review.gradeRawValue) else { issues.append(.invalidGrade(review.id, review.gradeRawValue)); continue }
            guard validReviewNumbers(review) else { issues.append(.invalidNumericField(review.id.uuidString)); continue }
            let rowKey = "review::\(snapshot.sourceStoreID)::\(review.id.uuidString.lowercased())"
            reviewRows.append(.review(LegacyReviewEvidence(rowKey: rowKey, sourceStoreID: snapshot.sourceStoreID, sourceReviewID: review.id, legacyCardKey: cardKey(snapshot.sourceStoreID, resolved.card.id), cardID: resolved.card.id, rawWordKey: review.wordKey, direction: resolved.direction, gradeRawValue: review.gradeRawValue, reviewedAt: review.reviewedAt, dueAt: review.dueAt, stability: review.stability, difficulty: review.difficulty, phaseRawValue: review.phaseRawValue, learningStep: review.learningStep, scheduledDays: review.scheduledDays, elapsedDays: review.elapsedDays, algorithmVersion: review.algorithmVersion)))
        }

        var masteryRows: [LegacyMigrationRow] = []
        var excludedSkills = Set<String>()
        var seenMasteries = Set<String>()
        for mastery in snapshot.masteries.sorted(by: { $0.id < $1.id }) {
            guard seenMasteries.insert(mastery.id).inserted else { issues.append(.duplicateMastery(mastery.id)); continue }
            guard let card = cardsByID[mastery.cardID] else { issues.append(.missingCard("mastery::\(mastery.id)")); continue }
            guard let direction = legacyDirection(for: mastery.skillRawValue) else { excludedSkills.insert(mastery.skillRawValue); continue }
            guard mastery.attempts >= 0, mastery.correct >= 0, mastery.correct <= mastery.attempts, mastery.score.isFinite else { issues.append(.invalidMasteryCounts(mastery.id)); continue }
            let rowKey = "mastery::\(snapshot.sourceStoreID)::\(mastery.id)"
            _ = direction
            masteryRows.append(.mastery(LegacyMasteryEvidence(rowKey: rowKey, sourceStoreID: snapshot.sourceStoreID, sourceMasteryID: mastery.id, legacyCardKey: cardKey(snapshot.sourceStoreID, card.id), cardID: card.id, skillRawValue: mastery.skillRawValue, score: mastery.score, attempts: mastery.attempts, correct: mastery.correct, lastUpdated: mastery.lastUpdated)))
        }

        var eventRows: [LegacyMigrationRow] = []
        var seenEvents = Set<UUID>()
        for event in snapshot.learningEvents.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            guard seenEvents.insert(event.id).inserted else { issues.append(.duplicateEvent(event.id)); continue }
            guard let card = cardsByID[event.cardID] else { issues.append(.missingCard("event::\(event.id.uuidString)")); continue }
            guard legacyDirection(for: event.skillRawValue) != nil else { excludedSkills.insert(event.skillRawValue); continue }
            let rowKey = "event::\(snapshot.sourceStoreID)::\(event.id.uuidString.lowercased())"
            eventRows.append(.event(LegacyEventEvidence(rowKey: rowKey, sourceStoreID: snapshot.sourceStoreID, sourceEventID: event.id, legacyCardKey: cardKey(snapshot.sourceStoreID, card.id), cardID: card.id, skillRawValue: event.skillRawValue, correct: event.correct, occurredAt: event.occurredAt, responseTimeMilliseconds: event.responseTimeMilliseconds, answer: event.answer, expectedAnswersJSON: event.expectedAnswersJSON)))
        }
        guard issues.isEmpty else { throw LegacyPracticeMigrationError.invalidSnapshot(issues) }

        let seeds = snapshot.cards.sorted { $0.id.uuidString < $1.id.uuidString }.flatMap { card in
            PracticeSkill.allCases.map { LegacyNewSkillSeed(cardID: card.id, skill: $0) }
        }
        return LegacyPracticeMigrationPlan(sourceStoreID: snapshot.sourceStoreID, rows: sortedCards + reviewRows + masteryRows + eventRows, newSkillSeeds: seeds, excludedSkillValues: excludedSkills.sorted())
    }

    private func resolve(_ rawKey: String, cards: [LegacyCardSnapshot]) -> (card: LegacyCardSnapshot, direction: LegacyReviewDirection)? {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let direction: LegacyReviewDirection = trimmed.hasSuffix("::reverse") ? .reverse : .recognition
        let base = direction == .reverse ? String(trimmed.dropLast("::reverse".count)) : trimmed
        if base.hasSuffix("::mixed") { return nil }
        if base.hasPrefix("card:") {
            let value = String(base.dropFirst("card:".count))
            guard let id = UUID(uuidString: value) else { return nil }
            return cards.first(where: { $0.id == id }).map { ($0, direction) }
        }
        let normalized = base.lowercased()
        let matches = cards.filter { $0.german.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }
        return matches.count == 1 ? (matches[0], direction) : nil
    }

    private func issueForReviewKey(_ key: String, cards: [LegacyCardSnapshot]) -> LegacyMigrationIssue {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.hasSuffix("::reverse") ? String(trimmed.dropLast("::reverse".count)) : trimmed
        if base.hasSuffix("::mixed") { return .unsupportedReviewDirection(key) }
        let matches = cards.filter { $0.german.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == base.lowercased() }
        return matches.count > 1 ? .ambiguousReviewKey(key) : .malformedReviewKey(key)
    }

    private func legacyDirection(for rawSkill: String) -> LegacyReviewDirection? {
        switch rawSkill { case LearningSkill.recognition.rawValue: return .recognition; case LearningSkill.recall.rawValue: return .reverse; default: return nil }
    }
    private func validGrade(_ value: String) -> Bool { ["again", "hard", "good", "easy"].contains(value) }
    private func validReviewNumbers(_ value: LegacyReviewSnapshot) -> Bool {
        [value.stability, value.difficulty, value.scheduledDays, value.elapsedDays].allSatisfy { $0.isFinite && $0 >= 0 } && value.learningStep >= 0
    }
}

public struct LegacyPracticeMigrationRunner: Sendable {
    public init() {}

    public func run(plan: LegacyPracticeMigrationPlan, resumeFrom checkpoint: LegacyMigrationCheckpoint? = nil,
                    sink: any LegacyPracticeMigrationSink, now: Date = .now,
                    progress: (@MainActor @Sendable (Int, Int) -> Void)? = nil) async throws -> LegacyMigrationReport {
        if let checkpoint, checkpoint.sourceStoreID != plan.sourceStoreID || checkpoint.migrationID != plan.migrationID || checkpoint.planDigest != plan.digest || checkpoint.expectedRows != plan.rows.count {
            throw LegacyPracticeMigrationError.checkpointDoesNotMatchPlan
        }
        var startIndex = 0
        if let lastRowKey = checkpoint?.lastRowKey {
            guard let index = plan.rows.firstIndex(where: { $0.rowKey == lastRowKey }) else { throw LegacyPracticeMigrationError.checkpointDoesNotMatchPlan }
            guard checkpoint?.completedRows == index + 1 else { throw LegacyPracticeMigrationError.checkpointDoesNotMatchPlan }
            startIndex = index + 1
        } else if checkpoint?.completedRows != nil && checkpoint?.completedRows != 0 {
            throw LegacyPracticeMigrationError.checkpointDoesNotMatchPlan
        }
        var appliedRows = checkpoint?.completedRows ?? 0
        var lastRowKey = checkpoint?.lastRowKey
        await progress?(appliedRows, plan.rows.count)
        for row in plan.rows.dropFirst(startIndex) {
            try await sink.apply(row)
            appliedRows += 1
            lastRowKey = row.rowKey
            try await sink.save(LegacyMigrationCheckpoint(sourceStoreID: plan.sourceStoreID, migrationID: plan.migrationID, lastRowKey: lastRowKey, completedRows: appliedRows, expectedRows: plan.rows.count, planDigest: plan.digest, updatedAt: now))
            await progress?(appliedRows, plan.rows.count)
        }
        let finalCheckpoint = LegacyMigrationCheckpoint(sourceStoreID: plan.sourceStoreID, migrationID: plan.migrationID, lastRowKey: lastRowKey, completedRows: appliedRows, expectedRows: plan.rows.count, planDigest: plan.digest, updatedAt: now)
        return LegacyMigrationReport(sourceStoreID: plan.sourceStoreID, appliedRows: appliedRows, checkpoint: finalCheckpoint, expectedCounts: plan.expectedCounts)
    }
}

private func cardKey(_ sourceStoreID: String, _ cardID: UUID) -> String { "card::\(sourceStoreID)::\(cardID.uuidString.lowercased())" }

private enum LegacyMigrationDigest {
    static func make(rows: [LegacyMigrationRow]) -> String {
        let value = rows.map { row in
            switch row {
            case let .card(evidence):
                let card = evidence.card
                return "card|\(evidence.rowKey)|\(card.id)|\(card.german)|\(card.persian)|\(card.createdAt.timeIntervalSince1970)"
            case let .review(review): return "review|\(review.rowKey)|\(review.cardID)|\(review.rawWordKey)|\(review.gradeRawValue)|\(review.reviewedAt.timeIntervalSince1970)|\(review.dueAt.timeIntervalSince1970)|\(review.stability)|\(review.difficulty)|\(review.algorithmVersion)"
            case let .mastery(mastery): return "mastery|\(mastery.rowKey)|\(mastery.cardID)|\(mastery.skillRawValue)|\(mastery.score)|\(mastery.attempts)|\(mastery.correct)|\(mastery.lastUpdated?.timeIntervalSince1970 as Any)"
            case let .event(event): return "event|\(event.rowKey)|\(event.cardID)|\(event.skillRawValue)|\(event.correct)|\(event.occurredAt.timeIntervalSince1970)|\(event.responseTimeMilliseconds as Any)|\(event.expectedAnswersJSON)"
            }
        }.joined(separator: "\u{1f}")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        return String(format: "%016llx", hash)
    }
}
