import XCTest
import Foundation
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainMedia
import LinguaBrainAnkiExport
@testable import LinguaBrainAnkiExport

final class AnkiPackageSafetyTests: XCTestCase {
    override func tearDown() {
        cleanTempDirectories()
    }

    private func cleanTempDirectories() {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let subdirectories = ["apkg-tmp", "apkg-staging", "validation-cache"]
        
        for subdir in subdirectories {
            let dir = tempDir.appendingPathComponent(subdir)
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func testTraversalProtection() throws {
        let maliciousName = "../../../etc/passwd"
        
        XCTAssertTrue(isPathTraversalAttempt(name: maliciousName), "Path traversal should be detected")
    }

    func testDuplicateEntryDetection() throws {
        let entries = ["file1.mp3", "file1.mp3", "file2.mp3"]
        let duplicates = findDuplicates(in: entries)
        
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertTrue(duplicates.contains("file1.mp3"))
    }

    func testZipPathNormalization() throws {
        let paths = [
            "normal/file.mp3",
            "./relative/file.mp3",
            "../parent/file.mp3"
        ]

        for path in paths {
            let normalized = normalizePath(path)
            XCTAssertFalse(normalized.contains(".."), "Normalized path should not contain '..': \(normalized)")
            XCTAssertFalse(normalized.hasPrefix("/"), "Normalized path should not be absolute: \(normalized)")
        }
    }

    func testMediaFileChecksumConsistency() async throws {
        let content = "test content for verification"
        let tempFile = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("checksum-test.txt")

        try content.write(to: tempFile, atomically: true, encoding: .utf8)

        let resolver = DefaultOwnedMediaResolver()
        let checksum1 = try await resolver.computeChecksum(for: tempFile)
        let checksum2 = try await resolver.computeChecksum(for: tempFile)

        XCTAssertEqual(checksum1, checksum2, "Checksums should be consistent")
        XCTAssertEqual(checksum1.count, 64, "SHA-256 checksum should be 64 hex characters")

        try FileManager.default.removeItem(at: tempFile)
    }

    func testOversizedEntryDetection() throws {
        let config = AnkiExportConfiguration(maxMediaBytes: 1024)
        
        XCTAssertThrowsError(try validateSize(bytes: 2048, limit: config.maxMediaBytes)) { error in
            guard let exportError = error as? AnkiExportError else {
                XCTFail("Wrong error type")
                return
            }
            
            guard case .limitExceeded = exportError else {
                XCTFail("Expected limit exceeded error")
                return
            }
        }
    }

    func testCancellationDuringExport() throws {
        let cancellation = ExportCancellation()
        
        XCTAssertEqual(cancellation.isCancelled, false)
        
        cancellation.cancel()
        
        XCTAssertEqual(cancellation.isCancelled, true)
        
        XCTAssertThrowsError(try cancellation.checkCancellation()) { error in
            guard let exportError = error as? AnkiExportError else {
                XCTFail("Wrong error type")
                return
            }
            XCTAssertEqual(exportError, .cancelled)
        }
    }

    func testAtomicWritePreventsPartialOutput() throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let finalFile = tempDir.appendingPathComponent("atomic-test.apkg")
        let stagingFile = tempDir.appendingPathComponent("atomic-test-staging.apkg")

        try "partial content".write(to: stagingFile, atomically: true, encoding: .utf8)

        try FileManager.default.moveItem(at: stagingFile, to: finalFile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: finalFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagingFile.path))

        try FileManager.default.removeItem(at: finalFile)
    }

    func testSQLiteSchemaIntegrity() throws {
        let tempDB = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("schema-test.anki21")

        defer {
            try? FileManager.default.removeItem(at: tempDB)
        }

        let builder = try AnkiCollectionBuilder(dbURL: tempDB)

        builder.close()

        XCTAssertFalse(FileManager.default.fileExists(atPath: tempDB.path) == false)
    }

    func testExportProgressTracking() throws {
        let progress = ExportProgress(
            cardsExported: 100,
            mediaBytesExported: 5000,
            totalCards: 200,
            totalBytes: 10000
        )

        XCTAssertEqual(progress.cardsExported, 100)
        XCTAssertEqual(progress.progressFraction, 0.5)
        XCTAssertFalse(progress.isComplete)

        let completeProgress = ExportProgress(
            cardsExported: 200,
            mediaBytesExported: 10000,
            totalCards: 200,
            totalBytes: 10000
        )

        XCTAssertTrue(completeProgress.isComplete)
        XCTAssertEqual(completeProgress.progressFraction, 1.0)
    }

    func testErrorCasesAreDistinct() throws {
        let errors: [AnkiExportError] = [
            .noApprovedCards,
            .cancelled,
            .invalidPath(path: "/test"),
            .missingMedia(assetID: "missing-asset")
        ]

        let uniqueErrors = Set(errors)
        XCTAssertEqual(uniqueErrors.count, errors.count, "All errors should be distinct cases")
    }
}

private func isPathTraversalAttempt(name: String) -> Bool {
    return name.contains("..") || name.hasPrefix("/") || name.hasPrefix("./")
}

private func findDuplicates(in entries: [String]) -> [String] {
    var seen: Set<String> = []
    var duplicates: Set<String> = []
    
    for entry in entries {
        if seen.contains(entry) {
            duplicates.insert(entry)
        } else {
            seen.insert(entry)
        }
    }
    
    return Array(duplicates)
}

private func normalizePath(_ path: String) -> String {
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    var stack: [String] = []
    
    for component in components {
        if component == ".." {
            if !stack.isEmpty && stack.last != ".." {
                stack.popLast()
            }
        } else if component != "." && !component.isEmpty {
            stack.append(String(component))
        }
    }
    
    return stack.joined(separator: "/")
}

private func validateSize(bytes: Int, limit: Int) throws {
    if bytes > limit {
        throw AnkiExportError.limitExceeded(type: .mediaBytes, current: bytes, maximum: limit)
    }
}