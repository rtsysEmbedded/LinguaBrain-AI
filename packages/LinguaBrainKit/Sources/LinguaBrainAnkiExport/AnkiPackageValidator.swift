import Foundation
import SQLite3
import LinguaBrainDomain

public class AnkiPackageValidator {
    private let config: AnkiExportConfiguration

    public init(config: AnkiExportConfiguration = AnkiExportConfiguration()) {
        self.config = config
    }

    public func validatePackage(at url: URL) async throws -> ValidationReport {
        var errors: [ValidationError] = []
        let warnings: [ValidationWarning] = []

        guard FileManager.default.fileExists(atPath: url.path) else {
            errors.append(ValidationError(
                code: "MISSING_PACKAGE",
                message: "Package file not found at \(url.path)"
            ))
            return ValidationReport(status: .failed, errors: errors, warnings: warnings)
        }

        if try await !validateRequiredEntries(at: url) {
            errors.append(ValidationError(
                code: "MISSING_REQUIRED_ENTRIES",
                message: "Package missing required entries"
            ))
        }

        if let colError = try await validateSQLiteCollection(at: url) {
            errors.append(colError)
        }

        if await !validateManifestConsistency(at: url) {
            errors.append(ValidationError(
                code: "MANIFEST_INCONSISTENCY",
                message: "Manifest entries do not match actual files"
            ))
        }

        let status: ValidationStatus = errors.isEmpty ? .passed : .failed

        return ValidationReport(
            status: status,
            errors: errors,
            warnings: warnings
        )
    }

    private func validateRequiredEntries(at url: URL) async throws -> Bool {
        let inspection = try OfflineAnkiPackageInspector(config: config).inspectPackage(at: url)
        return inspection.collectionExists && inspection.manifestExists
    }

    private func validateSQLiteCollection(at url: URL) async throws -> ValidationError? {
        let inspection = try OfflineAnkiPackageInspector(config: config).inspectPackage(at: url)
        if !inspection.collectionExists || inspection.cardCount == 0 {
            return ValidationError(
                code: "SQLITE_VALIDATION_ERROR",
                message: inspection.validationIssues.joined(separator: "; ")
            )
        }
        return nil
    }

    private func validateManifestConsistency(at url: URL) async -> Bool {
        guard let inspection = try? OfflineAnkiPackageInspector(config: config).inspectPackage(at: url) else { return false }
        return inspection.validationIssues.filter { $0.localizedCaseInsensitiveContains("media") }.isEmpty
    }

    public static func validateAPKG(url: URL, maxCards: Int, maxBytes: Int) async throws -> Bool {
        let validator = AnkiPackageValidator()
        let report = try await validator.validatePackage(at: url)
        return report.status == .passed
    }
}
