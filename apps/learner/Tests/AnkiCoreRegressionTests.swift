import XCTest
@testable import LinguaBrain

final class AnkiCoreRegressionTests: XCTestCase {
    func testInterfaceLanguageSwitchPersistsWithoutChangingLearningPair() throws {
        let suiteName = "LinguaBrain.LocalizationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let pair = PrototypeLanguageSettings(defaults: defaults)
        pair.sourceLanguageTag = "en"
        pair.targetLanguageTag = "de"

        let localization = PrototypeLocalization(defaults: defaults)
        for language in PrototypeAppLanguage.allCases {
            for key in PrototypeTextKey.allCases {
                XCTAssertFalse(PrototypeLocalization.text(key, language: language).isEmpty)
            }
        }
        localization.language = .english
        XCTAssertEqual(localization.text(.settingsTitle), "Settings")
        XCTAssertEqual(localization.language.layoutDirection, .leftToRight)

        localization.language = .german
        XCTAssertEqual(localization.text(.settingsTitle), "Einstellungen")
        XCTAssertEqual(localization.language.layoutDirection, .leftToRight)

        localization.language = .persian
        XCTAssertEqual(localization.text(.settingsTitle), "تنظیمات")
        XCTAssertEqual(localization.language.layoutDirection, .rightToLeft)

        let restoredLocalization = PrototypeLocalization(defaults: defaults)
        let restoredPair = PrototypeLanguageSettings(defaults: defaults)
        XCTAssertEqual(restoredLocalization.language, .persian)
        XCTAssertEqual(restoredPair.sourceLanguageTag, "en")
        XCTAssertEqual(restoredPair.targetLanguageTag, "de")
        XCTAssertTrue(restoredPair.isValidPair)
    }

    func testSanitizedLanguagePairAnkiFixturesCarryExplicitDirection() throws {
        let fixtures = try APKGFixtureFactory.loadLanguagePairFixtures()
        XCTAssertEqual(Set(fixtures.map { "\($0.sourceLanguageTag)->\($0.targetLanguageTag)" }), ["fa->de", "en->de", "de->en"])

        for fixture in fixtures {
            let packageURL = try APKGFixtureFactory.makeLanguagePairPackage(from: fixture)
            defer { try? FileManager.default.removeItem(at: packageURL.deletingLastPathComponent()) }
            let preview = try APKGArchiveInspector().inspect(url: packageURL)
            defer { try? FileManager.default.removeItem(at: preview.stagedPackageURL) }

            let card = try XCTUnwrap(APKGCardReader().readCards(from: preview).first)
            XCTAssertEqual(card.sourceLanguageTag, fixture.sourceLanguageTag)
            XCTAssertEqual(card.targetLanguageTag, fixture.targetLanguageTag)
            XCTAssertEqual(card.word.german, fixture.sourceText)
            XCTAssertEqual(card.word.persian, fixture.targetText)
            XCTAssertEqual(card.word.example, fixture.sourceExample)
            XCTAssertEqual(card.word.exampleTranslation, fixture.targetExample)
        }
    }

    func testSanitizedLegacyPackageInspectsAndMapsLinguaBrainFields() throws {
        let fixture = try APKGFixtureFactory.loadFixture()
        let packageURL = try APKGFixtureFactory.makeLegacyPackage(from: fixture)
        defer { try? FileManager.default.removeItem(at: packageURL.deletingLastPathComponent()) }

        let preview = try APKGArchiveInspector().inspect(url: packageURL)
        defer { try? FileManager.default.removeItem(at: preview.stagedPackageURL) }

        XCTAssertEqual(preview.collectionName, "collection.anki21")
        XCTAssertEqual(preview.entryCount, 2)
        XCTAssertEqual(preview.mediaEntryCount, 1)

        let cards = try APKGCardReader().readCards(from: preview)
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards[0].sourceIdentifier, "sanitized-legacy.apkg::\(fixture.cardID)")
        XCTAssertEqual(cards[0].word.german, "arbeiten")
        XCTAssertEqual(cards[0].word.persian, "کار کردن")
        XCTAssertEqual(cards[0].word.level, "A1")
        XCTAssertEqual(cards[0].word.partOfSpeech, "فعل")
        XCTAssertEqual(cards[0].word.example, "Ich arbeite heute.")
        XCTAssertEqual(cards[0].word.exampleTranslation, "من امروز کار می‌کنم.")
    }

    @MainActor
    func testReimportUpdatesBySourceAndThenSkipsUnchangedSemanticDuplicate() throws {
        let store = PrototypeStore(inMemory: true)
        let source = "regression.apkg::42"
        let initial = PrototypeImportedCard(
            sourceIdentifier: source,
            word: PrototypeWord(
                german: "entlassen", persian: "اخراج کردن", level: "B1", partOfSpeech: "Verb",
                example: "Die Firma entlässt ihn.", exampleTranslation: "شرکت او را اخراج می‌کند.", domain: "کار"
            )
        )
        let first = try XCTUnwrap(store.importCards([initial], deckName: "Regression", sourcePackage: "regression.apkg"))
        XCTAssertEqual(first.addedCount, 1)
        XCTAssertEqual(first.updatedCount, 0)

        let changed = PrototypeImportedCard(
            sourceIdentifier: source,
            word: PrototypeWord(
                german: "entlassen", persian: "مرخص کردن", level: "B2", partOfSpeech: "Verb",
                example: "Der Arzt entlässt den Patienten.", exampleTranslation: "پزشک بیمار را مرخص می‌کند.", domain: "پزشکی"
            )
        )
        let second = try XCTUnwrap(store.importCards([changed], deckName: "Regression", sourcePackage: "regression.apkg"))
        XCTAssertEqual(second.addedCount, 0)
        XCTAssertEqual(second.updatedCount, 1)
        XCTAssertTrue(store.words.contains { $0.persian == "مرخص کردن" && $0.domain == "پزشکی" })

        let duplicateSense = PrototypeImportedCard(sourceIdentifier: "regression.apkg::43", word: changed.word)
        let third = try XCTUnwrap(store.importCards([duplicateSense], deckName: "Regression", sourcePackage: "regression.apkg"))
        XCTAssertEqual(third.addedCount, 0)
        XCTAssertEqual(third.skippedCount, 1)
    }

    @MainActor
    func testReviewDirectionsAndDueTimeRemainIndependent() throws {
        let store = PrototypeStore(inMemory: true)
        let word = try XCTUnwrap(store.words.first)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let recognition = try XCTUnwrap(store.record(.hard, for: word, mode: .recognition, at: now))
        XCTAssertEqual(store.reviewCount(for: word, mode: .recognition), 1)
        XCTAssertEqual(store.reviewCount(for: word, mode: .reverseTranslation), 0)
        XCTAssertFalse(store.isReviewable(word, mode: .recognition, at: now))
        XCTAssertTrue(store.isReviewable(word, mode: .recognition, at: recognition.dueAt))

        let reverse = try XCTUnwrap(store.record(.easy, for: word, mode: .reverseTranslation, at: now))
        XCTAssertEqual(store.reviewCount(for: word, mode: .reverseTranslation), 1)
        XCTAssertEqual(store.dueDate(for: word, mode: .recognition), recognition.dueAt)
        XCTAssertEqual(store.dueDate(for: word, mode: .reverseTranslation), reverse.dueAt)
        XCTAssertNotEqual(recognition.dueAt, reverse.dueAt)
    }
}
