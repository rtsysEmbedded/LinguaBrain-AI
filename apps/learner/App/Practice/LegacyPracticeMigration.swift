import CryptoKit
import Foundation
import Observation
import SwiftData
import LinguaBrainDomain
import LinguaBrainPersistence

enum PracticeCutoverFailure: String, Error, Codable, Sendable, Equatable {
    case legacyStoreMissing
    case legacyStoreUnreadable
    case backupFailed
    case migrationFailed
    case validationFailed
    case activationFailed
    case recoveryFailed

    var recoveryGuidance: String {
        switch self {
        case .legacyStoreMissing: "The legacy learning store was not found. No migration was attempted."
        case .legacyStoreUnreadable: "The legacy store could not be read. Keep the retained source and use the verified backup before retrying."
        case .backupFailed: "The required pre-migration backup could not be created. Nothing was activated."
        case .migrationFailed: "Migration stopped safely. The retained source and any checkpoint remain available for recovery and retry."
        case .validationFailed: "Validation did not pass. GRDB was not activated; compare counts, identities, and the retained source."
        case .activationFailed: "The new store was not activated. Keep the backup and retry after diagnosing the local store."
        case .recoveryFailed: "Recovery did not complete. Keep both stores intact and use the platform recovery procedure."
        }
    }
}

enum PracticeCutoverState: Codable, Sendable, Equatable {
    case notStarted
    case backingUp
    case readingLegacy
    case migrating(completed: Int, total: Int)
    case validating
    case active
    case recoverableFailure(PracticeCutoverFailure)

    var isActive: Bool { self == .active }
}

struct PracticeRuntimePaths: Sendable, Equatable {
    let legacyStoreURL: URL
    let practiceStoreURL: URL
    let backupRootURL: URL

    init(legacyStoreURL: URL, practiceStoreURL: URL, backupRootURL: URL) {
        self.legacyStoreURL = legacyStoreURL
        self.practiceStoreURL = practiceStoreURL
        self.backupRootURL = backupRootURL
    }

    @MainActor static var live: Self {
        let fileManager = FileManager.default
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = support.appendingPathComponent("LinguaBrain", isDirectory: true)
        return Self(
            legacyStoreURL: PrototypeStore.persistentStoreURL,
            practiceStoreURL: root.appendingPathComponent("Practice.sqlite"),
            backupRootURL: root.appendingPathComponent("PracticeCutoverBackups", isDirectory: true)
        )
    }
}

struct PracticeBackupFile: Codable, Sendable, Equatable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
}

struct PracticeBackupManifest: Codable, Sendable, Equatable {
    let sourceStoreID: String
    let sourceURLDescription: String
    let createdAt: Date
    let files: [PracticeBackupFile]
}

struct PracticeStoreBackupReceipt: Codable, Sendable, Equatable {
    let sourceStoreURL: URL
    let backupDirectoryURL: URL
    let itemNames: [String]
    let manifest: PracticeBackupManifest
}

private struct PracticeCutoverActivation: Codable, Sendable, Equatable {
    let sourceStoreID: String
    let backupReceipt: PracticeStoreBackupReceipt
    let activatedAt: Date
}

enum PracticeBackupError: Error, Equatable, Sendable {
    case sourceMissing
    case targetExists
    case manifestUnreadable
}

struct PracticeStoreBackupService: Sendable {
    func createBackup(sourceURL: URL, destinationRoot: URL, sourceStoreID: String, fileManager: FileManager = .default) throws -> PracticeStoreBackupReceipt {
        guard fileManager.fileExists(atPath: sourceURL.path) else { throw PracticeBackupError.sourceMissing }
        try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        let backupDirectory = destinationRoot.appendingPathComponent("cutover-\(sourceStoreID)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let items = [sourceURL] + ["-wal", "-shm", "-journal"].map { URL(fileURLWithPath: sourceURL.path + $0) }.filter { fileManager.fileExists(atPath: $0.path) }
        do {
            for item in items { try fileManager.copyItem(at: item, to: backupDirectory.appendingPathComponent(item.lastPathComponent)) }
            let files = try manifestFiles(in: backupDirectory, fileManager: fileManager)
            let manifest = PracticeBackupManifest(sourceStoreID: sourceStoreID, sourceURLDescription: "legacy SwiftData store", createdAt: .now, files: files)
            let data = try JSONEncoder().encode(manifest)
            try data.write(to: backupDirectory.appendingPathComponent("manifest.json"), options: .atomic)
            return PracticeStoreBackupReceipt(sourceStoreURL: sourceURL, backupDirectoryURL: backupDirectory, itemNames: items.map(\.lastPathComponent), manifest: manifest)
        } catch {
            try? fileManager.removeItem(at: backupDirectory)
            throw error
        }
    }

    func restore(_ receipt: PracticeStoreBackupReceipt, fileManager: FileManager = .default) throws {
        guard !fileManager.fileExists(atPath: receipt.sourceStoreURL.path) else { throw PracticeBackupError.targetExists }
        try fileManager.createDirectory(at: receipt.sourceStoreURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var copiedTargets: [URL] = []
        do {
            let manifestURL = receipt.backupDirectoryURL.appendingPathComponent("manifest.json")
            let manifestData = try Data(contentsOf: manifestURL)
            let storedManifest = try JSONDecoder().decode(PracticeBackupManifest.self, from: manifestData)
            guard storedManifest == receipt.manifest else { throw PracticeBackupError.manifestUnreadable }
            for itemName in receipt.itemNames {
                let source = receipt.backupDirectoryURL.appendingPathComponent(itemName)
                guard fileManager.fileExists(atPath: source.path) else { throw PracticeBackupError.manifestUnreadable }
                let target = receipt.sourceStoreURL.lastPathComponent == itemName
                    ? receipt.sourceStoreURL
                    : URL(fileURLWithPath: receipt.sourceStoreURL.path + itemName.replacingOccurrences(of: receipt.sourceStoreURL.lastPathComponent, with: ""))
                if let expected = receipt.manifest.files.first(where: { $0.relativePath == itemName }) {
                    let data = try Data(contentsOf: source)
                    guard data.count == expected.byteCount, Self.digest(data) == expected.sha256 else { throw PracticeBackupError.manifestUnreadable }
                }
                try fileManager.copyItem(at: source, to: target)
                copiedTargets.append(target)
            }
        } catch {
            for target in copiedTargets { try? fileManager.removeItem(at: target) }
            throw PracticeBackupError.manifestUnreadable
        }
    }

    private func manifestFiles(in directory: URL, fileManager: FileManager) throws -> [PracticeBackupFile] {
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var files: [PracticeBackupFile] = []
        for case let file as URL in enumerator {
            let values = try file.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true, file.lastPathComponent != "manifest.json" else { continue }
            let data = try Data(contentsOf: file)
            let relative = String(file.path.dropFirst(directory.path.count + 1))
            files.append(PracticeBackupFile(relativePath: relative, byteCount: data.count, sha256: Self.digest(data)))
        }
        return files.sorted { $0.relativePath < $1.relativePath }
    }

    private static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}

@MainActor
struct LegacySwiftDataSnapshotReader {
    private let container: ModelContainer

    init(storeURL: URL) throws {
        let configuration = ModelConfiguration("LinguaBrain-legacy-read-only", schema: nil, url: storeURL, allowsSave: false, cloudKitDatabase: .none)
        container = try ModelContainer(
            for: PrototypeDeckRecord.self, PrototypeMediaAssetRecord.self, PrototypeCardRecord.self,
            PrototypeReviewRecord.self, PrototypeSkillMasteryRecord.self, PrototypeLearningEventRecord.self,
            PrototypeLearningMissionRecord.self, PrototypeDailyLearningStateRecord.self,
            configurations: configuration
        )
    }

    func snapshot(sourceStoreID: String) throws -> LegacyPracticeSnapshot {
        let context = ModelContext(container)
        let cards = try context.fetch(FetchDescriptor<PrototypeCardRecord>()).sorted { $0.id.uuidString < $1.id.uuidString }.map { card in
            LegacyCardSnapshot(id: card.id, deckID: card.deckID, position: card.position, german: card.german, persian: card.persian,
                article: card.article, level: card.level, partOfSpeech: card.partOfSpeech, example: card.example,
                exampleTranslation: card.exampleTranslation, examplesJSON: card.examplesJSON, sensesJSON: card.sensesJSON,
                domain: card.domain, createdAt: card.createdAt, sourceIdentifier: card.sourceIdentifier, sourcePackage: card.sourcePackage,
                sourceLanguageTag: card.sourceLanguageTag, targetLanguageTag: card.targetLanguageTag,
                pronunciationAudioAssetID: card.pronunciationAudioAssetID, pronunciationAudioFilename: card.pronunciationAudioFilename,
                illustrationImageAssetID: card.illustrationImageAssetID, illustrationImageFilename: card.illustrationImageFilename)
        }
        let reviews = try context.fetch(FetchDescriptor<PrototypeReviewRecord>()).map { review in
            LegacyReviewSnapshot(id: review.id, wordKey: review.wordKey, gradeRawValue: review.gradeRawValue, reviewedAt: review.reviewedAt,
                dueAt: review.dueAt, stability: review.stability, difficulty: review.difficulty, phaseRawValue: review.phaseRawValue,
                learningStep: review.learningStep, scheduledDays: review.scheduledDays, elapsedDays: review.elapsedDays, algorithmVersion: review.algorithmVersion)
        }
        let masteries = try context.fetch(FetchDescriptor<PrototypeSkillMasteryRecord>()).map { mastery in
            LegacyMasterySnapshot(id: mastery.id, cardID: mastery.cardID, skillRawValue: mastery.skillRawValue, score: mastery.score,
                attempts: mastery.attempts, correct: mastery.correct, lastUpdated: mastery.lastUpdated)
        }
        let events = try context.fetch(FetchDescriptor<PrototypeLearningEventRecord>()).map { event in
            LegacyLearningEventSnapshot(id: event.id, cardID: event.cardID, skillRawValue: event.skillRawValue, correct: event.correct,
                occurredAt: event.occurredAt, responseTimeMilliseconds: event.responseTimeMilliseconds, answer: event.answer,
                expectedAnswersJSON: event.expectedAnswersJSON)
        }
        return LegacyPracticeSnapshot(sourceStoreID: sourceStoreID, cards: cards, reviews: reviews, masteries: masteries, learningEvents: events, capturedAt: .now)
    }
}

@MainActor
@Observable
final class PracticeCutoverCoordinator {
    private(set) var state: PracticeCutoverState = .notStarted
    private(set) var repository: GRDBPracticeRepository?
    private(set) var backupReceipt: PracticeStoreBackupReceipt?
    private let paths: PracticeRuntimePaths
    private let backupService = PracticeStoreBackupService()
    private let repositoryBuilder: @Sendable (URL) throws -> GRDBPracticeRepository
    var legacySourceExists: Bool { FileManager.default.fileExists(atPath: paths.legacyStoreURL.path) }

    init(
        paths: PracticeRuntimePaths = .live,
        repositoryBuilder: @escaping @Sendable (URL) throws -> GRDBPracticeRepository = { try GRDBPracticeRepository(url: $0) }
    ) {
        self.paths = paths
        self.repositoryBuilder = repositoryBuilder
    }

    func start() async {
        guard !state.isActive, case .notStarted = state else { return }
        do {
            let sourceStoreID = Self.sourceStoreID(for: paths.legacyStoreURL)
            if let activation = try loadActivation(), activation.sourceStoreID == sourceStoreID,
               FileManager.default.fileExists(atPath: paths.practiceStoreURL.path) {
                repository = try repositoryBuilder(paths.practiceStoreURL)
                backupReceipt = activation.backupReceipt
                state = .active
                return
            }
            state = .backingUp
            guard FileManager.default.fileExists(atPath: paths.legacyStoreURL.path) else { throw PracticeBackupError.sourceMissing }
            let receipt: PracticeStoreBackupReceipt
            do {
                receipt = try backupService.createBackup(sourceURL: paths.legacyStoreURL, destinationRoot: paths.backupRootURL, sourceStoreID: sourceStoreID)
            } catch let error as PracticeBackupError {
                throw error
            } catch {
                throw LegacyPracticeCutoverError.backup
            }
            backupReceipt = receipt
            state = .readingLegacy
            let snapshot = try LegacySwiftDataSnapshotReader(storeURL: paths.legacyStoreURL).snapshot(sourceStoreID: sourceStoreID)
            let plan = try LegacyPracticeMigrationPlanner().makePlan(from: snapshot)
            var staging = try GRDBLegacyMigrationStagingStore(url: paths.practiceStoreURL)
            var previousCheckpoint = try await staging.checkpoint(sourceStoreID: sourceStoreID)
            if let checkpoint = previousCheckpoint,
               (checkpoint.planDigest != plan.digest || checkpoint.expectedRows != plan.rows.count) {
                try quarantineIncompletePracticeStore()
                staging = try GRDBLegacyMigrationStagingStore(url: paths.practiceStoreURL)
                previousCheckpoint = nil
            }
            state = .migrating(completed: previousCheckpoint?.completedRows ?? 0, total: plan.rows.count)
            let report = try await LegacyPracticeMigrationRunner().run(plan: plan, resumeFrom: previousCheckpoint, sink: staging, now: .now) { @MainActor [weak self] completed, total in
                self?.state = .migrating(completed: completed, total: total)
            }
            state = .validating
            let counts = try await staging.counts(sourceStoreID: sourceStoreID)
            guard let checkpoint = try await staging.checkpoint(sourceStoreID: sourceStoreID), checkpoint.completedRows == plan.rows.count, report.appliedRows == plan.rows.count else { throw LegacyPracticeMigrationError.checkpointDoesNotMatchPlan }
            try plan.verify(actualCounts: counts, actualDigest: checkpoint.planDigest)
            let expectedLegacyObjectiveCount = Set(plan.rows.compactMap { row -> String? in
                guard case let .review(review) = row else { return nil }
                return review.legacyUnitKey
            }).count
            guard try await staging.foreignKeysAreValid(), try await staging.legacyObjectiveCount(sourceStoreID: sourceStoreID) == expectedLegacyObjectiveCount else { throw LegacyPracticeCutoverError.validation }
            if let first = snapshot.cards.first {
                guard try await staging.representativeCardMatches(sourceStoreID: sourceStoreID, cardID: first.id, german: first.german, persian: first.persian) else { throw LegacyPracticeCutoverError.validation }
            }
            let newRepository = try repositoryBuilder(paths.practiceStoreURL)
            try await newRepository.transaction {
                for seed in plan.newSkillSeeds {
                    let unit = ReviewUnit(learnerID: "local", skill: seed.skill, objectiveKey: "legacy-card:\(seed.cardID.uuidString.lowercased())")
                    try await newRepository.saveReviewUnit(unit, projection: PracticeMasteryProjection(state: seed.state))
                }
            }
            for seed in plan.newSkillSeeds {
                let unit = ReviewUnit(learnerID: "local", skill: seed.skill, objectiveKey: "legacy-card:\(seed.cardID.uuidString.lowercased())")
                guard try await newRepository.projection(for: unit.id)?.state == .unknown, try await newRepository.attempts(for: unit).isEmpty else { throw LegacyPracticeCutoverError.validation }
            }
            repository = newRepository
            try saveActivation(PracticeCutoverActivation(sourceStoreID: sourceStoreID, backupReceipt: receipt, activatedAt: .now))
            state = .active
        } catch let failure as PracticeCutoverFailure {
            repository = nil; state = .recoverableFailure(failure)
        } catch let error as PracticeBackupError {
            repository = nil; state = .recoverableFailure(error == .sourceMissing ? .legacyStoreMissing : .backupFailed)
        } catch let error as LegacyPracticeCutoverError {
            repository = nil; state = .recoverableFailure(error == .validation ? .validationFailed : .backupFailed)
        } catch let error as LegacyPracticeMigrationError {
            repository = nil; state = .recoverableFailure(error.isValidationFailure ? .validationFailed : .migrationFailed)
        } catch {
            repository = nil; state = .recoverableFailure(.legacyStoreUnreadable)
        }
    }

    func retry() async {
        guard case .recoverableFailure = state else { return }
        state = .notStarted
        await start()
    }

    func restoreBackup() throws {
        guard let backupReceipt else { throw PracticeCutoverFailure.recoveryFailed }
        do {
            try backupService.restore(backupReceipt)
            state = .notStarted
        } catch { state = .recoverableFailure(.recoveryFailed); throw error }
    }

    private var activationURL: URL { paths.backupRootURL.appendingPathComponent("active-cutover.json") }

    private func loadActivation() throws -> PracticeCutoverActivation? {
        guard FileManager.default.fileExists(atPath: activationURL.path) else { return nil }
        return try JSONDecoder().decode(PracticeCutoverActivation.self, from: Data(contentsOf: activationURL))
    }

    private func saveActivation(_ activation: PracticeCutoverActivation) throws {
        try FileManager.default.createDirectory(at: paths.backupRootURL, withIntermediateDirectories: true)
        try JSONEncoder().encode(activation).write(to: activationURL, options: .atomic)
    }

    private func quarantineIncompletePracticeStore() throws {
        let manager = FileManager.default
        guard manager.fileExists(atPath: paths.practiceStoreURL.path) else { return }
        let directory = paths.backupRootURL.appendingPathComponent("IncompletePracticeStores", isDirectory: true)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "Practice-\(Int(Date().timeIntervalSince1970))"
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let source = URL(fileURLWithPath: paths.practiceStoreURL.path + suffix)
            guard manager.fileExists(atPath: source.path) else { continue }
            try manager.moveItem(at: source, to: directory.appendingPathComponent(name + suffix))
        }
    }

    static func sourceStoreID(for url: URL) -> String {
        let normalized = url.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(normalized.utf8)).map { String(format: "%02x", $0) }.joined()
        return "swiftdata-\(digest.prefix(24))"
    }
}

private enum LegacyPracticeCutoverError: Error, Equatable { case validation, backup }

private extension LegacyPracticeMigrationError {
    var isValidationFailure: Bool {
        switch self {
        case .verificationMismatch, .digestMismatch: true
        case .invalidSnapshot, .checkpointDoesNotMatchPlan: false
        }
    }
}
