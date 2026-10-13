import XCTest
import UniformTypeIdentifiers
@testable import LinguaBrain

/// App export document tests moved from the untargeted
/// `AnkiExportIntegrationTests.swift` (audit finding B1). Package-level
/// selection and round-trip tests moved to `LinguaBrainAnkiExportTests`.
@MainActor
final class AnkiExportDocumentTests: XCTestCase {
    func testTSVDocumentKeepsText() {
        let document = AnkiTSVDocument(text: "test\ttsv\ncontent")
        XCTAssertEqual(document.text, "test\ttsv\ncontent")
        XCTAssertEqual(AnkiTSVDocument.readableContentTypes, [.plainText])
    }

    func testAPKGDocumentKeepsCountsAndPackageData() {
        let data = Data([0x50, 0x4B, 0x03, 0x04])
        let document = AnkiAPKGDocument(sourceGroups: ["generated", "imported"], cardCount: 10, mediaCount: 2, data: data)
        XCTAssertEqual(document.sourceGroups, ["generated", "imported"])
        XCTAssertEqual(document.cardCount, 10)
        XCTAssertEqual(document.mediaCount, 2)
        XCTAssertEqual(document.data, data)
        XCTAssertEqual(AnkiAPKGDocument.readableContentTypes, [AnkiExportDocument.apkg])
        XCTAssertEqual(AnkiAPKGDocument.writableContentTypes, [AnkiExportDocument.apkg])
    }

    func testExportStatusDescriptionIsItsRawValue() {
        for status in [ExportStatus.notStarted, .inProgress, .completed, .failed, .cancelled] {
            XCTAssertEqual(status.localizedDescription, status.rawValue)
        }
    }
}
