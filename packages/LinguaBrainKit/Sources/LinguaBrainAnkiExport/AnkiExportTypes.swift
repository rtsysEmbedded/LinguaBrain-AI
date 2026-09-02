import Foundation
import LinguaBrainDomain

public struct AnkiExportConfiguration: Sendable, Equatable {
    public var maxCards: Int
    public var maxMediaBytes: Int
    public var allowCancellation: Bool
    public var collectionSchemaVersion: String
    public var schedulingPolicy: SchedulingPolicy

    public init(
        maxCards: Int = 500,
        maxMediaBytes: Int = 500 * 1024 * 1024,
        allowCancellation: Bool = true,
        collectionSchemaVersion: String = "anki21",
        schedulingPolicy: SchedulingPolicy = .preserved
    ) {
        self.maxCards = maxCards
        self.maxMediaBytes = maxMediaBytes
        self.allowCancellation = allowCancellation
        self.collectionSchemaVersion = collectionSchemaVersion
        self.schedulingPolicy = schedulingPolicy
    }

    public enum SchedulingPolicy: String, Sendable, Equatable, Codable {
        case preserved
        case freshAnkiWithWarning
    }
}

public enum AnkiExportError: Error, Equatable, Sendable, Hashable {
    case noApprovedCards
    case invalidSelection(reason: String)
    case missingMedia(assetID: String)
    case checksumMismatch(expected: String, actual: String)
    case unsupportedSchema(version: String)
    case sqliteError(code: Int32, message: String)
    case zipError(message: String)
    case limitExceeded(type: LimitType, current: Int, maximum: Int)
    case cancelled
    case roundTripMismatch(details: String)
    case invalidPath(path: String)
    case fileAlreadyExists(path: String)
    case diskFull(requiredBytes: Int, availableBytes: Int)

    public enum LimitType: String, Sendable, Equatable {
        case cardCount
        case mediaBytes
        case entrySize
    }

    public var localizedDescription: String {
        switch self {
        case .noApprovedCards:
            return "No approved cards available for export"
        case .invalidSelection(let reason):
            return "Invalid export selection: \(reason)"
        case .missingMedia(let assetID):
            return "Missing media asset: \(assetID)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch: expected \(expected), got \(actual)"
        case .unsupportedSchema(let version):
            return "Unsupported collection schema version: \(version)"
        case .sqliteError(let code, let message):
            return "SQLite error (\(code)): \(message)"
        case .zipError(let message):
            return "ZIP archive error: \(message)"
        case .limitExceeded(let type, let current, let maximum):
            return "\(type.rawValue) limit exceeded: \(current) of \(maximum)"
        case .cancelled:
            return "Export was cancelled"
        case .roundTripMismatch(let details):
            return "Round-trip validation failed: \(details)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .fileAlreadyExists(let path):
            return "File already exists: \(path)"
        case .diskFull(let required, let available):
            return "Insufficient disk space: required \(required) bytes, available \(available) bytes"
        }
    }
}

public final class ExportCancellation {
    private var _isCancelled: Bool = false

    public var isCancelled: Bool {
        get { 
            // Atomic read using serial queue
            return queue.sync { _isCancelled }
        }
    }

    private let queue = DispatchQueue(label: "cancellation.queue", attributes: .concurrent)

    public init() {}

    public func cancel() {
        queue.async(flags: .barrier) {
            self._isCancelled = true
        }
    }

    public func checkCancellation() throws {
        let cancelled = queue.sync { _isCancelled }
        if cancelled {
            throw AnkiExportError.cancelled
        }
    }
}

public struct ExportProgress: Sendable {
    public var cardsExported: Int
    public var mediaBytesExported: Int
    public var totalCards: Int
    public var totalBytes: Int

    public init(
        cardsExported: Int = 0,
        mediaBytesExported: Int = 0,
        totalCards: Int = 0,
        totalBytes: Int = 0
    ) {
        self.cardsExported = cardsExported
        self.mediaBytesExported = mediaBytesExported
        self.totalCards = totalCards
        self.totalBytes = totalBytes
    }

    public var isComplete: Bool {
        cardsExported >= totalCards && mediaBytesExported >= totalBytes
    }

    public var progressFraction: Double {
        guard totalCards > 0 else { return 0.0 }
        return Double(cardsExported) / Double(totalCards)
    }
}