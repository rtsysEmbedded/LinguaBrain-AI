import Foundation
import SQLite3
import LinguaBrainDomain

public struct OfflineInspectionResult: Sendable, Equatable {
    public let isOfflineValid: Bool
    public let collectionExists: Bool
    public let mediaDirectoryExists: Bool
    public let manifestExists: Bool
    public let mediaCount: Int
    public let cardCount: Int
    public let validationIssues: [String]
    public let textOnlyFallbackRequired: Bool
    public let missingMediaAssets: [String]
    
    public init(
        isOfflineValid: Bool = true,
        collectionExists: Bool = false,
        mediaDirectoryExists: Bool = false,
        manifestExists: Bool = false,
        mediaCount: Int = 0,
        cardCount: Int = 0,
        validationIssues: [String] = [],
        textOnlyFallbackRequired: Bool = false,
        missingMediaAssets: [String] = []
    ) {
        self.isOfflineValid = isOfflineValid
        self.collectionExists = collectionExists
        self.mediaDirectoryExists = mediaDirectoryExists
        self.manifestExists = manifestExists
        self.mediaCount = mediaCount
        self.cardCount = cardCount
        self.validationIssues = validationIssues
        self.textOnlyFallbackRequired = textOnlyFallbackRequired
        self.missingMediaAssets = missingMediaAssets
    }
}

public class OfflineAnkiPackageInspector {
    private let config: AnkiExportConfiguration
    
    public init(config: AnkiExportConfiguration = AnkiExportConfiguration()) {
        self.config = config
    }
    
    public func inspectPackage(at url: URL) throws -> OfflineInspectionResult {
        let tempExtractDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("apkg-inspect-\(UUID().uuidString.prefix(8))")
        
        defer {
            try? FileManager.default.removeItem(at: tempExtractDir)
        }
        
        do {
            try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
            try extractPackage(at: url, to: tempExtractDir)
        } catch {
            return OfflineInspectionResult(
                isOfflineValid: false,
                validationIssues: ["Failed to extract package: \(error.localizedDescription)"]
            )
        }
        
        let collectionURL = tempExtractDir.appendingPathComponent("collection.anki21")
        let manifestURL = tempExtractDir.appendingPathComponent("manifest.json")
        let mediaDirURL = tempExtractDir.appendingPathComponent("media")
        
        let collectionExists = FileManager.default.fileExists(atPath: collectionURL.path)
        let manifestExists = FileManager.default.fileExists(atPath: manifestURL.path)
        let mediaDirectoryExists = FileManager.default.fileExists(atPath: mediaDirURL.path)
        
        var validationIssues: [String] = []
        var missingMediaAssets: [String] = []
        var textOnlyFallbackRequired = false
        
        if !collectionExists {
            validationIssues.append("collection.anki21 missing")
        }
        
        if !manifestExists {
            validationIssues.append("manifest.json missing")
        }
        
        var cardCount = 0
        var mediaCount = 0
        
        if collectionExists {
            do {
                cardCount = try countCardsInCollection(at: collectionURL)
            } catch {
                validationIssues.append("Failed to read collection: \(error.localizedDescription)")
            }
        }
        
        if mediaDirectoryExists {
            mediaCount = try countMediaFiles(at: mediaDirURL)
            
            if manifestExists {
                let missing = try verifyMediaAgainstManifest(
                    mediaDir: mediaDirURL,
                    manifestURL: manifestURL
                )
                missingMediaAssets = missing
                if !missing.isEmpty {
                    textOnlyFallbackRequired = true
                    validationIssues.append("Missing media files: \(missing.joined(separator: ", "))")
                }
            }
        }
        
        if cardCount > config.maxCards {
            validationIssues.append("Card count \(cardCount) exceeds limit \(config.maxCards)")
        }
        
        let isOfflineValid = validationIssues.isEmpty && cardCount > 0
        
        return OfflineInspectionResult(
            isOfflineValid: isOfflineValid && cardCount <= config.maxCards,
            collectionExists: collectionExists,
            mediaDirectoryExists: mediaDirectoryExists,
            manifestExists: manifestExists,
            mediaCount: mediaCount,
            cardCount: cardCount,
            validationIssues: validationIssues,
            textOnlyFallbackRequired: textOnlyFallbackRequired,
            missingMediaAssets: missingMediaAssets
        )
    }
    
    public func validateOfflineIntegrity(at url: URL) throws -> ValidationReport {
        let inspection = try inspectPackage(at: url)
        
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        if !inspection.collectionExists {
            errors.append(ValidationError(
                code: "COLLECTION_MISSING",
                message: "collection.anki21 not found in package"
            ))
        }
        
        if !inspection.manifestExists {
            errors.append(ValidationError(
                code: "MANIFEST_MISSING",
                message: "manifest.json not found in package"
            ))
        }
        
        if !inspection.mediaDirectoryExists && inspection.mediaCount > 0 {
            errors.append(ValidationError(
                code: "MEDIA_DIRECTORY_MISSING",
                message: "media directory missing but media entries expected"
            ))
        }
        
        if inspection.textOnlyFallbackRequired {
            warnings.append(ValidationWarning(
                code: "MISSING_MEDIA",
                message: "Some media assets are missing; text-only fallback required",
                suggestedFix: "Export without media or resolve missing assets"
            ))
        }
        
        if !inspection.isOfflineValid {
            errors.append(ValidationError(
                code: "OFFLINE_INTEGRITY_FAILED",
                message: "Package failed offline integrity checks"
            ))
        }
        
        let status = errors.isEmpty ? ValidationStatus.passed : ValidationStatus.failed
        
        return ValidationReport(
            status: status,
            errors: errors,
            warnings: warnings
        )
    }
    
    private func extractPackage(at url: URL, to destination: URL) throws {
#if os(macOS)
        let zipData = try Data(contentsOf: url)
        let stagingZip = destination.appendingPathComponent("staging.zip")
        try zipData.write(to: stagingZip)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-o", stagingZip.path, "-d", destination.path]
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            try FileManager.default.removeItem(at: stagingZip)
            throw AnkiExportError.zipError(message: "Failed to extract ZIP archive")
        }
        
        try FileManager.default.removeItem(at: stagingZip)
#else
        throw AnkiExportError.zipError(message: "Portable ZIP extraction is not available on this platform")
#endif
    }
    
    private func countCardsInCollection(at url: URL) throws -> Int {
        var db: OpaquePointer?
        let path = url.path.cString(using: .utf8)!
        
        guard sqlite3_open(path, &db) == SQLITE_OK else {
            sqlite3_close(db)
            throw AnkiExportError.sqliteError(code: -1, message: "Failed to open database")
        }
        
        defer {
            sqlite3_close(db)
        }
        
        var stmt: OpaquePointer?
        let query = "SELECT COUNT(*) FROM notes"
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            throw AnkiExportError.sqliteError(code: -1, message: "Failed to prepare query")
        }
        
        var count = 0
        if sqlite3_step(stmt) == SQLITE_ROW {
            count = Int(sqlite3_column_int(stmt, 0))
        }
        
        sqlite3_finalize(stmt)
        return count
    }
    
    private func countMediaFiles(at url: URL) throws -> Int {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return 0
        }
        
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return contents.count
    }
    
    private func verifyMediaAgainstManifest(mediaDir: URL, manifestURL: URL) throws -> [String] {
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let mediaEntries = json["mediaEntries"] as? [[String: Any]] else {
            return []
        }
        
        var missing: [String] = []
        
        for entry in mediaEntries {
            if let ankiIndex = entry["ankiIndex"] as? Int {
                let mediaFile = mediaDir.appendingPathComponent("\(ankiIndex).media")
                if !FileManager.default.fileExists(atPath: mediaFile.path) {
                    if let sha256 = entry["sha256"] as? String {
                        missing.append("index\(ankiIndex)-\(sha256.prefix(8))")
                    } else {
                        missing.append("index\(ankiIndex)")
                    }
                }
            }
        }
        
        return missing
    }
}
