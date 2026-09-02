import Foundation
import LinguaBrainDomain

public struct AnkiExportRequest: Sendable {
    public let selection: ExportSelection
    public let configuration: AnkiExportConfiguration
    public let destination: URL
    public let progressHandler: (@Sendable (ExportProgress) -> Void)?

    public init(
        selection: ExportSelection,
        configuration: AnkiExportConfiguration = AnkiExportConfiguration(),
        destination: URL,
        progressHandler: (@Sendable (ExportProgress) -> Void)? = nil
    ) {
        self.selection = selection
        self.configuration = configuration
        self.destination = destination
        self.progressHandler = progressHandler
    }
}

public struct AnkiExportResult: Sendable, Equatable {
    public let packageURL: URL
    public let manifest: ExportManifest
    public let validationReport: ValidationReport
    public let checksum: String
    public let exportDuration: TimeInterval

    public init(
        packageURL: URL,
        manifest: ExportManifest,
        validationReport: ValidationReport,
        checksum: String,
        exportDuration: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.packageURL = packageURL
        self.manifest = manifest
        self.validationReport = validationReport
        self.checksum = checksum
        self.exportDuration = exportDuration
    }

    public var isSuccess: Bool {
        return validationReport.status == ValidationStatus.passed
    }
}

public struct ExportManifest: Sendable, Equatable, Codable {
    public let exportID: String
    public let schemaVersion: String
    public let sourceGroups: [String]
    public let cardIdentities: [String]
    public let collectionEntry: String
    public let mediaEntries: [MediaManifestEntry]
    public let schedulingPolicy: AnkiExportConfiguration.SchedulingPolicy
    public let validation: ManifestValidation
    public let exportedAt: Date
    public let provenance: Provenance?
    
    public init(
        exportID: String = UUID().uuidString,
        schemaVersion: String = "apkg-export-v1",
        sourceGroups: [String] = [],
        cardIdentities: [String] = [],
        collectionEntry: String = "collection.anki21",
        mediaEntries: [MediaManifestEntry] = [],
        schedulingPolicy: AnkiExportConfiguration.SchedulingPolicy = .preserved,
        validation: ManifestValidation = ManifestValidation(),
        exportedAt: Date = Date(),
        provenance: Provenance? = nil
    ) {
        self.exportID = exportID
        self.schemaVersion = schemaVersion
        self.sourceGroups = sourceGroups
        self.cardIdentities = cardIdentities
        self.collectionEntry = collectionEntry
        self.mediaEntries = mediaEntries
        self.schedulingPolicy = schedulingPolicy
        self.validation = validation
        self.exportedAt = exportedAt
        self.provenance = provenance
    }
}

public struct MediaManifestEntry: Sendable, Equatable, Codable {
    public let sourceAssetID: String
    public let ankiIndex: Int
    public let sha256: String
    public let byteSize: Int
    public let mimeType: String
    public let availability: MediaAvailability
    public let ownershipProof: String?

    public init(
        sourceAssetID: String,
        ankiIndex: Int,
        sha256: String,
        byteSize: Int,
        mimeType: String = "application/octet-stream",
        availability: MediaAvailability = .available,
        ownershipProof: String? = nil
    ) {
        self.sourceAssetID = sourceAssetID
        self.ankiIndex = ankiIndex
        self.sha256 = sha256
        self.byteSize = byteSize
        self.mimeType = mimeType
        self.availability = availability
        self.ownershipProof = ownershipProof
    }
}

public struct ManifestValidation: Sendable, Equatable, Codable {
    public let integrity: ValidationStatus
    public let mediaCheck: ValidationStatus
    public let scheduleWarning: String?

    public init(
        integrity: ValidationStatus = .pending,
        mediaCheck: ValidationStatus = .pending,
        scheduleWarning: String? = nil
    ) {
        self.integrity = integrity
        self.mediaCheck = mediaCheck
        self.scheduleWarning = scheduleWarning
    }
}

public enum ValidationStatus: String, Sendable, Equatable, Codable {
    case pending
    case passed
    case failed
    case warned

    public var description: String {
        rawValue.capitalized
    }
}

public struct ValidationReport: Sendable, Equatable, Codable {
    public let status: ValidationStatus
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]
    public let timestamp: Date

    public init(
        status: ValidationStatus,
        errors: [ValidationError] = [],
        warnings: [ValidationWarning] = [],
        timestamp: Date = Date()
    ) {
        self.status = status
        self.errors = errors
        self.warnings = warnings
        self.timestamp = timestamp
    }

    public static var success: ValidationReport {
        ValidationReport(status: .passed)
    }
}

public struct ValidationError: Sendable, Equatable, Identifiable, Codable {
    public let id = UUID()
    public let code: String
    public let message: String
    public let severity: ValidationErrorSeverity
    public let file: String?
    public let line: Int?

    public init(
        code: String,
        message: String,
        severity: ValidationErrorSeverity = .error,
        file: String? = nil,
        line: Int? = nil
    ) {
        self.code = code
        self.message = message
        self.severity = severity
        self.file = file
        self.line = line
    }
}

public enum ValidationErrorSeverity: String, Sendable, Equatable, Codable {
    case warning
    case error
    case critical
}

public struct ValidationWarning: Sendable, Equatable, Identifiable, Codable {
    public let id = UUID()
    public let code: String
    public let message: String
    public let suggestedFix: String?

    public init(code: String, message: String, suggestedFix: String? = nil) {
        self.code = code
        self.message = message
        self.suggestedFix = suggestedFix
    }
}