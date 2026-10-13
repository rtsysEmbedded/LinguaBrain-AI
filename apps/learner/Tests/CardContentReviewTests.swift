import XCTest
@testable import LinguaBrain

/// Reviewed-content marker used to choose listening material (T033 design,
/// Section 7.3, option a).
@MainActor
final class CardContentReviewTests: XCTestCase {
    private func makeWord(_ german: String) -> PrototypeWord {
        PrototypeWord(
            german: german,
            persian: "آزمون",
            level: "A2",
            partOfSpeech: "Verb",
            example: "Ich \(german) heute.",
            exampleTranslation: "من امروز آزمون می‌کنم.",
            domain: "general"
        )
    }

    func testBuiltInSeedCardsAreReviewed() throws {
        let store = PrototypeStore(inMemory: true)
        let seed = try XCTUnwrap(store.words.first { word in PrototypeData.words.contains { $0.id == word.id } })
        XCTAssertTrue(store.isContentReviewed(seed))
    }

    func testBatchCardsStartUnreviewedAndPreviewApprovedCardsAreReviewed() {
        let store = PrototypeStore(inMemory: true)
        let batch = makeWord("prüfen")
        let previewed = makeWord("bestätigen")
        XCTAssertTrue(store.addGeneratedCards([batch]))
        XCTAssertTrue(store.addGeneratedCards([previewed], contentReviewed: true))
        XCTAssertFalse(store.isContentReviewed(batch))
        XCTAssertTrue(store.isContentReviewed(previewed))
    }

    func testLearnerCanMarkAndUnmarkACardAsReviewed() {
        let store = PrototypeStore(inMemory: true)
        let word = makeWord("markieren")
        XCTAssertTrue(store.addGeneratedCard(word))
        XCTAssertTrue(store.setContentReviewed(true, for: word))
        XCTAssertTrue(store.isContentReviewed(word))
        XCTAssertTrue(store.setContentReviewed(false, for: word))
        XCTAssertFalse(store.isContentReviewed(word))
    }

    func testCloudBackupKeepsTheReviewMarker() throws {
        let source = PrototypeStore(inMemory: true)
        let word = makeWord("sichern")
        XCTAssertTrue(source.addGeneratedCard(word, contentReviewed: true))
        let snapshot = try source.cloudBackupCards()
        XCTAssertEqual(snapshot.first { $0.id == word.id }?.contentReviewed, true)

        let restored = PrototypeStore(inMemory: true)
        try restored.mergeCloudCards(snapshot)
        XCTAssertTrue(restored.isContentReviewed(word))
    }

    func testSnapshotsWithoutTheMarkerDecodeAsUnreviewed() throws {
        let json = #"{"id":"6F1C3D1E-6E0B-4B8E-9F3A-1D2C3B4A5E6F","deckName":"d","position":0,"german":"g","persian":"p","level":"A1","partOfSpeech":"Nomen","example":"e","exampleTranslation":"t","examplesJSON":"[]","domain":"general","createdAt":0,"sourceLanguageTag":"fa","targetLanguageTag":"de"}"#
        let card = try JSONDecoder().decode(PrototypeCloudCard.self, from: Data(json.utf8))
        XCTAssertNil(card.contentReviewed)
    }
}
