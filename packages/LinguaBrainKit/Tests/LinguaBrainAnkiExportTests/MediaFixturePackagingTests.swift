import XCTest
import LinguaBrainDomain
import LinguaBrainAnkiExport

/// Packages the real MP3 and JPEG fixtures (audit finding A6) and checks the
/// manifest against the bytes on disk.
final class MediaFixturePackagingTests: XCTestCase {
    private func fixtureURL(_ name: String) throws -> URL {
        let fixtures = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return fixtures.appendingPathComponent("media").appendingPathComponent(name)
    }

    func testFixturesAreRealMediaFiles() throws {
        let audio = try Data(contentsOf: fixtureURL("test-audio.mp3"))
        let image = try Data(contentsOf: fixtureURL("test-image.jpg"))
        // MPEG audio frame sync: 11 set bits.
        XCTAssertEqual(audio[audio.startIndex], 0xFF)
        XCTAssertEqual(audio[audio.startIndex + 1] & 0xE0, 0xE0)
        // JPEG start-of-image marker followed by another marker.
        XCTAssertEqual(Array(image.prefix(3)), [0xFF, 0xD8, 0xFF])
    }

    func testPackagerCopiesFixturesWithChecksumSizeAndMimeType() async throws {
        let audioURL = try fixtureURL("test-audio.mp3")
        let imageURL = try fixtureURL("test-image.jpg")
        let assets = [
            MediaAsset(kind: .audio, locale: "de", checksum: "", provider: "fixture", model: "fixture", cacheReference: audioURL.path),
            MediaAsset(kind: .image, locale: "de", checksum: "", provider: "fixture", model: "fixture", cacheReference: imageURL.path)
        ]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }

        let entries = try await AnkiMediaPackager().packageMedia(from: assets, to: directory, config: AnkiExportConfiguration())

        XCTAssertEqual(entries.map(\.mimeType), ["audio/mpeg", "image/jpeg"])
        XCTAssertEqual(entries.map(\.sha256), [
            "d1c93dedab01e40951c4732d81090a0095a16b38f2557ec1f123d9b96bc143bf",
            "8ed423b7a4919dc9e17970ad064703418b2824d15f1768359cadff9a256c5e4b"
        ])
        XCTAssertEqual(entries.map(\.byteSize), [1254, 633])
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("0.media")), try Data(contentsOf: audioURL))
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("1.media")), try Data(contentsOf: imageURL))
    }
}
