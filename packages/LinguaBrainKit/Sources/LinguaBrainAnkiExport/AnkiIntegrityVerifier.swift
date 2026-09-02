import Foundation
import CryptoKit
import LinguaBrainDomain

public struct IntegrityVerificationResult: Sendable, Equatable {
    public let isVerified: Bool
    public let collectionChecksum: String?
    public let mediaChecksums: [String: String]
    public let errors: [IntegrityError]
    public let verifiedAt: Date
    
    public init(
        isVerified: Bool = false,
        collectionChecksum: String? = nil,
        mediaChecksums: [String: String] = [:],
        errors: [IntegrityError] = [],
        verifiedAt: Date = Date()
    ) {
        self.isVerified = isVerified
        self.collectionChecksum = collectionChecksum
        self.mediaChecksums = mediaChecksums
        self.errors = errors
        self.verifiedAt = verifiedAt
    }
}

public struct IntegrityError: Sendable, Equatable, Identifiable {
    public let id = UUID()
    public let entryType: EntryType
    public let index: Int
    public let expectedChecksum: String
    public let actualChecksum: String?
    public let message: String
    
    public enum EntryType: String, Sendable, Equatable {
        case collection
        case media
    }
    
    public init(
        entryType: EntryType,
        index: Int = 0,
        expectedChecksum: String,
        actualChecksum: String? = nil,
        message: String
    ) {
        self.entryType = entryType
        self.index = index
        self.expectedChecksum = expectedChecksum
        self.actualChecksum = actualChecksum
        self.message = message
    }
}

public class AnkiIntegrityVerifier {
    private let config: AnkiExportConfiguration
    private let inspector: OfflineAnkiPackageInspector
    
    public init(config: AnkiExportConfiguration = AnkiExportConfiguration()) {
        self.config = config
        self.inspector = OfflineAnkiPackageInspector(config: config)
    }
    
    public func verifyPostWrite(at url: URL, expectedManifest: ExportManifest) async throws -> IntegrityVerificationResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return IntegrityVerificationResult(
                isVerified: false,
                errors: [IntegrityError(
                    entryType: .collection,
                    expectedChecksum: expectedManifest.exportID,
                    message: "Package file not found at \(url.path)"
                )]
            )
        }
        
        var errors: [IntegrityError] = []
        var mediaChecksums: [String: String] = [:]
        var collectionChecksum: String?
        
        let tempExtractDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("integrity-verification-\(UUID().uuidString.prefix(8))")
        
        defer {
            try? FileManager.default.removeItem(at: tempExtractDir)
        }
        
        try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
        
        do {
            try await extractForVerification(at: url, to: tempExtractDir)
        } catch {
            return IntegrityVerificationResult(
                isVerified: false,
                errors: [IntegrityError(
                    entryType: .collection,
                    expectedChecksum: expectedManifest.exportID,
                    message: "Extraction failed: \(error.localizedDescription)"
                )]
            )
        }
        
        let collectionURL = tempExtractDir.appendingPathComponent("collection.anki21")
        let mediaDirURL = tempExtractDir.appendingPathComponent("media")
        
        if FileManager.default.fileExists(atPath: collectionURL.path) {
            collectionChecksum = try computeChecksum(for: collectionURL)
            
            if expectedManifest.validation.integrity != .pending && 
               collectionChecksum != expectedManifest.exportID {
                errors.append(IntegrityError(
                    entryType: .collection,
                    expectedChecksum: expectedManifest.exportID,
                    actualChecksum: collectionChecksum,
                    message: "Collection checksum mismatch"
                ))
            }
        } else {
            errors.append(IntegrityError(
                entryType: .collection,
                expectedChecksum: expectedManifest.exportID,
                message: "collection.anki21 not found in package"
            ))
        }
        
if FileManager.default.fileExists(atPath: mediaDirURL.path) {
            do {
                let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaDirURL, includingPropertiesForKeys: nil)
            
                for mediaFileURL in mediaFiles {
                    let mediaURL = mediaFileURL
                    let fileName = mediaFileURL.lastPathComponent
                    let checksum = try computeChecksum(for: mediaURL)
                    mediaChecksums[fileName] = checksum
                    
                    if let entry = expectedManifest.mediaEntries.first(where: { $0.ankiIndex == Int(fileName.split(separator: ".").first.map(String.init) ?? "-1") ?? -1 }) {
                        if checksum != entry.sha256 {
                            errors.append(IntegrityError(
                                entryType: .media,
                                index: entry.ankiIndex,
                                expectedChecksum: entry.sha256,
                                actualChecksum: checksum,
                                message: "Media checksum mismatch for index \(entry.ankiIndex)"
                            ))
                        }
                    }
                }
            } catch {
                errors.append(IntegrityError(
                    entryType: .media,
                    expectedChecksum: "",
                    message: "Failed to read media directory: \(error.localizedDescription)"
                ))
            }
        }
        
        let isVerified = errors.isEmpty
        
        return IntegrityVerificationResult(
            isVerified: isVerified,
            collectionChecksum: collectionChecksum,
            mediaChecksums: mediaChecksums,
            errors: errors,
            verifiedAt: Date()
        )
    }
    
    public func verifyPostRead(at url: URL, expectedManifest: ExportManifest?) async throws -> IntegrityVerificationResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return IntegrityVerificationResult(
                isVerified: false,
                errors: [IntegrityError(
                    entryType: .collection,
                    expectedChecksum: expectedManifest?.exportID ?? "",
                    message: "Package file not found at \(url.path)"
                )]
            )
        }
        
        if let manifest = expectedManifest {
            return try await verifyPostWrite(at: url, expectedManifest: manifest)
        }
        
        let tempExtractDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("read-verification-\(UUID().uuidString.prefix(8))")
        
        defer {
            try? FileManager.default.removeItem(at: tempExtractDir)
        }
        
        do {
            try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)
            try await extractForVerification(at: url, to: tempExtractDir)
        } catch {
            return IntegrityVerificationResult(
                isVerified: false,
                errors: [IntegrityError(
                    entryType: .collection,
                    expectedChecksum: "",
                    message: "Extraction failed: \(error.localizedDescription)"
                )]
            )
        }
        
        let collectionURL = tempExtractDir.appendingPathComponent("collection.anki21")
        let mediaDirURL = tempExtractDir.appendingPathComponent("media")
        
        var errors: [IntegrityError] = []
        var mediaChecksums: [String: String] = [:]
        var collectionChecksum: String? = nil
        
        if FileManager.default.fileExists(atPath: collectionURL.path) {
            collectionChecksum = try computeChecksum(for: collectionURL)
        }
        
        if FileManager.default.fileExists(atPath: mediaDirURL.path) {
            do {
                let mediaFiles = try FileManager.default.contentsOfDirectory(at: mediaDirURL, includingPropertiesForKeys: nil)
                for mediaFileURL in mediaFiles {
                    let mediaURL = mediaFileURL
                    let fileName = mediaFileURL.lastPathComponent
                    let checksum = try computeChecksum(for: mediaURL)
                    mediaChecksums[fileName] = checksum
                }
            } catch {
                errors.append(IntegrityError(
                    entryType: .media,
                    expectedChecksum: "",
                    message: "Failed to read media directory: \(error.localizedDescription)"
                ))
            }
        }
        
        return IntegrityVerificationResult(
            isVerified: errors.isEmpty,
            collectionChecksum: collectionChecksum,
            mediaChecksums: mediaChecksums,
            errors: errors
        )
    }
    
    private func extractForVerification(at url: URL, to destination: URL) async throws {
#if os(macOS)
        let zipData = try Data(contentsOf: url)
        let stagingZip = destination.appendingPathComponent("staging.zip")
        try zipData.write(to: stagingZip)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        task.arguments = ["-o", stagingZip.path, "-d", destination.path]
        
        try task.run()
        task.waitUntilExit()
        
        guard task.terminationStatus == 0 else {
            throw AnkiExportError.zipError(message: "Extraction failed")
        }
        
        try FileManager.default.removeItem(at: stagingZip)
#else
        throw AnkiExportError.zipError(message: "Portable ZIP extraction is not available on this platform")
#endif
    }
    
    private func computeChecksum(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public func validateChecksum(content: Data, expected: String) -> Bool {
        let digest = SHA256.hash(data: content)
        let actual = digest.compactMap { String(format: "%02x", $0) }.joined()
        return actual == expected
    }
}
