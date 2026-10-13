import CloudKit
import Foundation
import Observation

struct PrototypeCloudCard: Codable, Sendable {
    let id: UUID
    let deckName: String
    let position: Int
    let german: String
    let persian: String
    let article: String?
    let level: String
    let partOfSpeech: String
    let example: String
    let exampleTranslation: String
    let examplesJSON: String
    let domain: String
    let createdAt: Date
    let sourceIdentifier: String?
    let sourcePackage: String?
    let sourceLanguageTag: String
    let targetLanguageTag: String
    let pronunciationAudio: Data?
    let pronunciationAudioFilename: String?
    /// Absent in snapshots written before the field existed; read as `false`.
    let contentReviewed: Bool?
}

struct PrototypeCloudCardSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let savedAt: Date
    let cards: [PrototypeCloudCard]
}

enum PrototypeCloudBackupStatus: Equatable {
    case idle, checking, syncing
    case synced(Date, Int)
    case unavailable(String)
    case failed(String)
}

@MainActor
@Observable
final class PrototypeCloudBackupController {
    private static let enabledKey = "prototype.icloud.cardBackup.enabled"
    private static let recordType = "LinguaBrainCardBackup"
    private static let recordName = "primary-card-snapshot"
    private static let lastSyncedIDsKey = "prototype.icloud.cardBackup.lastSyncedIDs"

    var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }
    private(set) var status: PrototypeCloudBackupStatus = .idle

    init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    func syncIfEnabled(store: PrototypeStore) async {
        guard isEnabled else { return }
        await sync(store: store)
    }

    func sync(store: PrototypeStore) async {
        guard isEnabled else { return }
        status = .checking
        do {
            let container = CKContainer(identifier: "iCloud.ai.linguabrain.prototype")
            let accountStatus = try await container.accountStatus()
            guard accountStatus == .available else {
                status = .unavailable(Self.message(for: accountStatus))
                return
            }

            status = .syncing
            let database = container.privateCloudDatabase
            let recordID = CKRecord.ID(recordName: Self.recordName)
            let localBeforeMerge = try store.cloudBackupCards()
            let localIDs = Set(localBeforeMerge.map(\.id))
            let previousIDs = Set(
                UserDefaults.standard.stringArray(forKey: Self.lastSyncedIDsKey)?
                    .compactMap(UUID.init(uuidString:)) ?? []
            )
            let locallyDeletedIDs = previousIDs.subtracting(localIDs)
            if let remote = try await fetchSnapshot(database: database, recordID: recordID) {
                try store.mergeCloudCards(remote.cards.filter { !locallyDeletedIDs.contains($0.id) })
            }

            let cards = try store.cloudBackupCards()
            let snapshot = PrototypeCloudCardSnapshot(schemaVersion: 1, savedAt: .now, cards: cards)
            let data = try JSONEncoder().encode(snapshot)
            let record: CKRecord
            do {
                record = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: Self.recordType, recordID: recordID)
            }
            record["schemaVersion"] = snapshot.schemaVersion as CKRecordValue
            record["savedAt"] = snapshot.savedAt as CKRecordValue
            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("linguabrain-card-backup-\(UUID().uuidString).json")
            try data.write(to: temporaryURL, options: [.atomic, .completeFileProtection])
            defer { try? FileManager.default.removeItem(at: temporaryURL) }
            record["payloadAsset"] = CKAsset(fileURL: temporaryURL)
            record["payload"] = nil
            _ = try await database.save(record)
            UserDefaults.standard.set(cards.map { $0.id.uuidString }, forKey: Self.lastSyncedIDsKey)
            status = .synced(snapshot.savedAt, cards.count)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func fetchSnapshot(database: CKDatabase, recordID: CKRecord.ID) async throws -> PrototypeCloudCardSnapshot? {
        do {
            let record = try await database.record(for: recordID)
            let data: Data?
            if let asset = record["payloadAsset"] as? CKAsset, let url = asset.fileURL {
                data = try Data(contentsOf: url)
            } else {
                data = record["payload"] as? Data
            }
            guard let data else { return nil }
            return try JSONDecoder().decode(PrototypeCloudCardSnapshot.self, from: data)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    private static func message(for status: CKAccountStatus) -> String {
        switch status {
        case .noAccount: PrototypeLocalization.current("cloudBackup.status.noAccount")
        case .restricted: PrototypeLocalization.current("cloudBackup.status.restricted")
        case .couldNotDetermine: PrototypeLocalization.current("cloudBackup.status.couldNotDetermine")
        case .temporarilyUnavailable: PrototypeLocalization.current("cloudBackup.status.temporarilyUnavailable")
        case .available: ""
        @unknown default: PrototypeLocalization.current("cloudBackup.status.unavailable")
        }
    }
}
