import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainApplication

final class TSVExportTests: XCTestCase {

    func testExportManifestWithGeneratedCards() throws {
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "es",
                lemma: "Bank",
                senseKey: "bank-n-finance",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [
                LexicalSense(
                    sourceLanguage: "en",
                    targetLanguage: "es",
                    lemma: "Bank",
                    senseKey: "bank-n-finance",
                    partOfSpeech: "noun",
                    meaning: "financial institution",
                    examples: [
                        Sentence(text: "I went to the bank", translation: "Fui al banco")
                    ],
                    translation: "banco",
                    level: "A1"
                )
            ],
            provenance: Provenance(provider: "test", model: "test-model")
        )

        let manifest = ExportManifest(
            selectedBundles: [bundle],
            exportFormat: .tsv,
            provenance: Provenance(provider: "test", model: "test-model")
        )

        let exporter = TSVExporter()
        let tsv = try exporter.export(manifest)

        XCTAssertTrue(tsv.contains("Bank"))
        XCTAssertTrue(tsv.contains("banco"))
        XCTAssertTrue(tsv.contains("bank-n-finance"))
        XCTAssertTrue(tsv.contains("noun"))
        XCTAssertTrue(tsv.contains("financial institution"))
        XCTAssertTrue(tsv.contains("en"))
        XCTAssertTrue(tsv.contains("es"))
    }

    func testExportManifestPreservesUnicode() throws {
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "de",
                targetLanguage: "fa",
                lemma: "Bank",
                senseKey: "bank-n-finance",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [
                LexicalSense(
                    sourceLanguage: "de",
                    targetLanguage: "fa",
                    lemma: "Bank",
                    senseKey: "bank-n-finance",
                    partOfSpeech: "noun",
                    meaning: "financial institution",
                    translation: "بانک"
                )
            ],
            provenance: Provenance(provider: "test", model: "test-model")
        )

        let manifest = ExportManifest(
            selectedBundles: [bundle],
            exportFormat: .tsv,
            provenance: Provenance(provider: "test", model: "test-model")
        )

        let exporter = TSVExporter()
        let tsv = try exporter.export(manifest)

        XCTAssertTrue(tsv.contains("بانک"))
    }

    func testExportManifestWithExamples() throws {
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "es",
                lemma: "Hello",
                senseKey: "hello-interj",
                partOfSpeech: "interjection",
                direction: .recognition
            ),
            senses: [
                LexicalSense(
                    sourceLanguage: "en",
                    targetLanguage: "es",
                    lemma: "Hello",
                    senseKey: "hello-interj",
                    partOfSpeech: "interjection",
                    meaning: "greeting",
                    examples: [
                        Sentence(text: "Hello, how are you?", translation: "Hola, ¿cómo estás?")
                    ],
                    translation: "hola"
                )
            ],
            provenance: Provenance(provider: "test", model: "test-model")
        )

        let manifest = ExportManifest(
            selectedBundles: [bundle],
            exportFormat: .tsv,
            provenance: Provenance(provider: "test", model: "test-model")
        )

        let exporter = TSVExporter()
        let tsv = try exporter.export(manifest)

        XCTAssertTrue(tsv.contains("Hello, how are you?"))
        XCTAssertTrue(tsv.contains("Hola, ¿cómo estás?"))
    }
}