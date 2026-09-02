import XCTest
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainAnkiExport
@testable import LinguaBrainAnkiExport

final class AnkiCollectionExportTests: XCTestCase {
    func testNoteRecordDeterministicID() throws {
        let identity = CardIdentity(
            sourceLanguage: "en",
            targetLanguage: "es",
            lemma: "Bank",
            senseKey: "bank-n-finance",
            partOfSpeech: "noun",
            direction: .recognition
        )

        let id1 = AnkiCollectionRecords.computeNoteID(for: identity)
        let id2 = AnkiCollectionRecords.computeNoteID(for: identity)

        XCTAssertEqual(id1, id2, "Deterministic IDs should be consistent")
    }

    func testNoteRecordDifferentIdentities() throws {
        let identity1 = CardIdentity(
            sourceLanguage: "en",
            targetLanguage: "es",
            lemma: "Bank",
            senseKey: "bank-n-finance",
            partOfSpeech: "noun",
            direction: .recognition
        )

        let identity2 = CardIdentity(
            sourceLanguage: "en",
            targetLanguage: "es",
            lemma: "Bank",
            senseKey: "bank-n-institution",
            partOfSpeech: "noun",
            direction: .recognition
        )

        let id1 = AnkiCollectionRecords.computeNoteID(for: identity1)
        let id2 = AnkiCollectionRecords.computeNoteID(for: identity2)

        XCTAssertNotEqual(id1, id2, "Different identities should produce different IDs")
    }

    func testDeckRecordCreation() throws {
        let deck = AnkiDeckRecord(
            deckID: 12345,
            name: "Test Deck"
        )

        XCTAssertEqual(deck.deckID, 12345)
        XCTAssertEqual(deck.name, "Test Deck")
    }

    func testModelRecordCreation() throws {
        let model = AnkiModelRecord(
            modelID: 1001,
            name: "Basic",
            fieldNames: ["Front", "Back"],
            templates: [
                AnkiTemplateRecord(name: "Card")
            ]
        )

        XCTAssertEqual(model.modelID, 1001)
        XCTAssertEqual(model.name, "Basic")
        XCTAssertEqual(model.fieldNames.count, 2)
    }

    func testUnicodeRTLPreservation() throws {
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "fa",
                targetLanguage: "de",
                lemma: "بانک",
                senseKey: "bank-n-finance",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [
                LexicalSense(
                    sourceLanguage: "fa",
                    targetLanguage: "de",
                    lemma: "بانک",
                    senseKey: "bank-n-finance",
                    partOfSpeech: "noun",
                    meaning: "financial institution",
                    translation: "Bank"
                )
            ],
            provenance: Provenance(provider: "test", model: "test")
        )

        let note = AnkiNoteRecord.fromBundle(
            bundle,
            modelID: 1001,
            deckID: 2001
        )

        XCTAssertNotNil(note.fieldStrings.first)
        XCTAssertTrue(note.fieldStrings.first?.contains("بانک") ?? false)
    }

    func testCardRecordCreation() throws {
        let noteID = Int64(123456789)
        let card = AnkiCardRecord(
            cardID: noteID + 1,
            noteID: noteID,
            deckID: 2001,
            ordinal: 0,
            queue: 1,
            reps: 0,
            lapses: 0,
            ease: 1
        )

        XCTAssertEqual(card.cardID, noteID + 1)
        XCTAssertEqual(card.noteID, noteID)
        XCTAssertEqual(card.queue, 1)
    }

    func testTagRecordCreation() throws {
        let tag = AnkiTagRecord(tag: "hermes-export")

        XCTAssertEqual(tag.tag, "hermes-export")
    }

    func testMapperBuildsTags() throws {
        let bundle = GeneratedCardBundle(
            identity: CardIdentity(
                sourceLanguage: "en",
                targetLanguage: "es",
                lemma: "Bank",
                senseKey: "bank-n-finance",
                partOfSpeech: "noun",
                direction: .recognition
            ),
            senses: [],
            approvalState: .approved,
            provenance: Provenance(provider: "hermes", model: "claude")
        )

        let tags = AnkiCollectionMapper.buildTags(for: bundle)

        XCTAssertTrue(tags.contains("recognition"))
        XCTAssertTrue(tags.contains("approved"))
        XCTAssertTrue(tags.contains("hermes-export"))
        XCTAssertTrue(tags.contains("en"))
        XCTAssertTrue(tags.contains("es"))
    }

    func testMapperCreatesDeckName() throws {
        let deck = AnkiCollectionMapper.mapBundleToDeck(
            sourceGroup: "hermes",
            languagePair: (source: "en", target: "es")
        )

        XCTAssertNotNil(deck.name)
        XCTAssertNotNil(deck.deckID)
    }

    func testMapperCreatesModel() throws {
        let model = AnkiCollectionMapper.mapBundleToModel(
            name: "Card",
            fieldNames: ["Front", "Back"]
        )

        XCTAssertEqual(model.name, "Card")
        XCTAssertEqual(model.fieldNames.count, 2)
        XCTAssertEqual(model.formatVersion, 31)
    }
}