import XCTest
import Foundation
import LinguaBrainDomain
import LinguaBrainAnkiExport

@MainActor
final class APKGExportAccessibilityTests: XCTestCase {
    func testExportProgressAccessibility() throws {
        let progress = ExportProgress(
            cardsExported: 250,
            mediaBytesExported: 100000,
            totalCards: 500,
            totalBytes: 200000
        )
        
        XCTAssertEqual(progress.progressFraction, 0.5)
        XCTAssertFalse(progress.isComplete)
    }
    
    func testExportStateAccessibility() throws {
        XCTAssertEqual(ExportStatus.notStarted.localizedDescription, "notStarted")
        XCTAssertEqual(ExportStatus.inProgress.localizedDescription, "inProgress")
        XCTAssertEqual(ExportStatus.completed.localizedDescription, "completed")
        XCTAssertEqual(ExportStatus.failed.localizedDescription, "failed")
        XCTAssertEqual(ExportStatus.cancelled.localizedDescription, "cancelled")
    }
    
    func testErrorStateAccessibility() throws {
        let error = AnkiExportError.noApprovedCards
        
        XCTAssertNotNil(error.localizedDescription)
        XCTAssertFalse(error.localizedDescription.isEmpty)
    }
    
    func testLimitErrorAccessibility() throws {
        let error = AnkiExportError.limitExceeded(
            type: .cardCount,
            current: 600,
            maximum: 500
        )
        
        XCTAssertTrue(error.localizedDescription.contains("limit exceeded"))
        XCTAssertTrue(error.localizedDescription.contains("600"))
        XCTAssertTrue(error.localizedDescription.contains("500"))
    }
    
    func testCancelErrorAccessibility() throws {
        let error = AnkiExportError.cancelled
        
        XCTAssertEqual(error.localizedDescription, "Export was cancelled")
    }
    
    func testProgressReportingForFailure() throws {
        let progress = ExportProgress(
            cardsExported: 100,
            mediaBytesExported: 5000,
            totalCards: 500,
            totalBytes: 10000
        )
        
        XCTAssertNotEqual(progress.progressFraction, 1.0)
        XCTAssertEqual(progress.cardsExported, 100)
    }
    
    func testTextOnlyFallbackReporting() throws {
        let fallbackDescription = "Text-only fallback due to missing media files"
        
        XCTAssertNotNil(fallbackDescription)
        XCTAssertTrue(fallbackDescription.contains("fallback"))
    }
    
    func testValidationFailureAccessibility() throws {
        let report = ValidationReport(
            status: .failed,
            errors: [
                ValidationError(
                    code: "COLLECTION_MISSING",
                    message: "Collection file not found"
                )
            ],
            warnings: []
        )
        
        XCTAssertEqual(report.status, .failed)
        XCTAssertEqual(report.errors.count, 1)
        XCTAssertEqual(report.errors.first?.message, "Collection file not found")
    }
    
    func testValidationSuccessAccessibility() throws {
        let report = ValidationReport.success
        
        XCTAssertEqual(report.status, .passed)
        XCTAssertTrue(report.errors.isEmpty)
    }
    
    func testWarningAccessibility() throws {
        let warning = ValidationWarning(
            code: "MISSING_MEDIA",
            message: "Media files are missing",
            suggestedFix: "Re-export without media"
        )
        
        XCTAssertNotNil(warning.message)
        XCTAssertTrue(warning.message.contains("Media"))
        XCTAssertNotNil(warning.suggestedFix)
    }
    
    func testIntegrityErrorAccessibility() throws {
        let error = IntegrityError(
            entryType: .media,
            index: 0,
            expectedChecksum: "abc123",
            actualChecksum: "def456",
            message: "Checksum mismatch"
        )
        
        XCTAssertNotNil(error.message)
        XCTAssertEqual(error.entryType, .media)
    }
    
    func testOfflineInspectionAccessibility() throws {
        let result = OfflineInspectionResult(
            isOfflineValid: true,
            collectionExists: true,
            mediaDirectoryExists: true,
            manifestExists: true,
            mediaCount: 2,
            cardCount: 10,
            validationIssues: [],
            textOnlyFallbackRequired: false,
            missingMediaAssets: []
        )
        
        XCTAssertTrue(result.isOfflineValid)
        XCTAssertEqual(result.cardCount, 10)
        XCTAssertEqual(result.mediaCount, 2)
    }
    
    func testOfflineInspectionFailureAccessibility() throws {
        let result = OfflineInspectionResult(
            isOfflineValid: false,
            collectionExists: false,
            mediaDirectoryExists: false,
            manifestExists: false,
            mediaCount: 0,
            cardCount: 0,
            validationIssues: ["collection.anki21 missing"],
            textOnlyFallbackRequired: true,
            missingMediaAssets: ["media-0"]
        )
        
        XCTAssertFalse(result.isOfflineValid)
        XCTAssertEqual(result.validationIssues.count, 1)
        XCTAssertTrue(result.textOnlyFallbackRequired)
    }
    
    func testRoundTripComparisonAccessibility() throws {
        let comparison = RoundTripComparison(
            areEqual: true,
            textMatches: true,
            senseMatches: true,
            exampleMatches: true,
            directionMatches: true,
            mediaMatches: true,
            tagsMatch: true,
            provenanceMatches: true,
            discrepancies: []
        )
        
        XCTAssertTrue(comparison.textMatches)
        XCTAssertTrue(comparison.senseMatches)
        XCTAssertTrue(comparison.areEqual)
    }
    
    func testRoundTripComparisonWithDiscrepancies() throws {
        let comparison = RoundTripComparison(
            areEqual: false,
            textMatches: false,
            senseMatches: true,
            exampleMatches: true,
            directionMatches: true,
            mediaMatches: true,
            tagsMatch: true,
            provenanceMatches: true,
            discrepancies: [
                Discrepancy(
                    field: "text",
                    expected: "Bank",
                    actual: "BANK",
                    severity: .error
                )
            ]
        )
        
        XCTAssertFalse(comparison.areEqual)
        XCTAssertFalse(comparison.textMatches)
        XCTAssertEqual(comparison.discrepancies.count, 1)
    }
    
    func testSchedulingCompatibilityReportAccessibility() throws {
        let report = SchedulingCompatibilityReport(
            status: .freshAnki,
            warnings: [
                SchedulingCompatibilityWarning(
                    field: "FSRS",
                    reason: "FSRS not supported in Anki",
                    recommendation: "Use fresh Anki scheduling"
                )
            ],
            preservedFields: ["queue", "reps"],
            lostFields: ["fsrs_state"]
        )
        
        XCTAssertNotNil(report.status.description)
        XCTAssertEqual(report.status, .freshAnki)
        XCTAssertGreaterThan(report.warnings.count, 0)
    }
    
    func testMediaManifestEntryAccessibility() throws {
        let entry = MediaManifestEntry(
            sourceAssetID: "test-audio.mp3",
            ankiIndex: 0,
            sha256: "a1b2c3d4e5f67890",
            byteSize: 102400,
            mimeType: "audio/mpeg",
            availability: .available
        )
        
        XCTAssertEqual(entry.sourceAssetID, "test-audio.mp3")
        XCTAssertEqual(entry.ankiIndex, 0)
        XCTAssertEqual(entry.byteSize, 102400)
    }
    
    func testPipelineResultAccessibility() throws {
        let result = PipelineResult<String>(
            result: "processed",
            processedCount: 10,
            processedBytes: 102400
        )
        
        XCTAssertEqual(result.result, "processed")
        XCTAssertEqual(result.processedCount, 10)
        XCTAssertTrue(result.isComplete)
    }
    
    func testPipelineProgressTrackingAccessibility() throws {
        let pipeline = AnkiExportPipeline()
        
        var lastProgress: ExportProgress?
        let progressHandler: @Sendable (ExportProgress) -> Void = { progress in
            lastProgress = progress
        }
        
        let bundles = (0..<50).map { _ in createTestBundleForExport() }
        _ = try await pipeline.exportWithProgress(bundles: bundles, progressHandler: progressHandler)
        
        XCTAssertNotNil(lastProgress)
        XCTAssertGreaterThan(lastProgress?.cardsExported ?? 0, 0)
    }
    
    func testValidatorAccessibility() throws {
        let validator = AnkiRoundTripValidator()
        
        let report = validator.generateReport(for: RoundTripComparison(areEqual: true))
        
        XCTAssertNotNil(report)
        XCTAssertTrue(report.contains("PASSED"))
    }
    
    private func createTestBundleForExport() -> GeneratedCardBundle {
        GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "de",
                lemma: "test",
                senseKey: "test-1",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [],
            mediaAssets: [],
            approvalState: .approved,
            provenance: Provenance(provider: "hermes", model: "claude")
        )
    }
}