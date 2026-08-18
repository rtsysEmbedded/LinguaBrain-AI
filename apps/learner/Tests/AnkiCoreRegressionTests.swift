import XCTest
@testable import LinguaBrain

final class AnkiCoreRegressionTests: XCTestCase {
    func testModernFixtureCatalogIsOwnedAndCoversT005Matrix() throws {
        let url = try XCTUnwrap(Bundle(for: FixtureBundleMarker.self).url(forResource: "modern-apkg-fixtures", withExtension: "json"))
        let catalog = try JSONDecoder().decode(ModernFixtureCatalog.self, from: Data(contentsOf: url))
        XCTAssertEqual(catalog.upstreamCommit, "967aa0d578fc75181e292e95326f9b58698da25c")
        XCTAssertEqual(catalog.fixtures.count, 10)
        let kinds = Set(catalog.fixtures.map { $0.kind })
        XCTAssertEqual(kinds, ["accepted", "corrupt", "unsupported", "hostile"])
        XCTAssertTrue(catalog.fixtures.allSatisfy { $0.id.range(of: #"^[a-z0-9-]+$"#, options: .regularExpression) != nil })
        XCTAssertTrue(catalog.fixtures.filter { $0.expected == "accepted" }.allSatisfy { $0.schema == 11 || $0.schema == 18 })
        XCTAssertTrue(catalog.fixtures.filter { $0.expected == "rejected" }.allSatisfy { $0.kind != "accepted" })
    }
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
        XCTAssertEqual(localization.minutes(20), "20 min")
        XCTAssertEqual(localization.reviewSummary(due: 3, new: 4), "3 reviews + 4 new cards")

        localization.language = .german
        XCTAssertEqual(localization.text(.settingsTitle), "Einstellungen")
        XCTAssertEqual(localization.language.layoutDirection, .leftToRight)
        XCTAssertEqual(localization.minutes(20), "20 Min.")

        localization.language = .persian
        XCTAssertEqual(localization.text(.settingsTitle), "تنظیمات")
        XCTAssertEqual(localization.language.layoutDirection, .rightToLeft)
        XCTAssertEqual(localization.minutes(20), "20 دقیقه")

        let restoredLocalization = PrototypeLocalization(defaults: defaults)
        let restoredPair = PrototypeLanguageSettings(defaults: defaults)
        XCTAssertEqual(restoredLocalization.language, .persian)
        XCTAssertEqual(restoredPair.sourceLanguageTag, "en")
        XCTAssertEqual(restoredPair.targetLanguageTag, "de")
        XCTAssertTrue(restoredPair.isValidPair)

        restoredPair.selectTarget("en")
        restoredPair.selectSource("en")
        XCTAssertEqual(restoredPair.sourceLanguageTag, "en")
        XCTAssertEqual(restoredPair.targetLanguageTag, "de")
        XCTAssertTrue(restoredPair.isValidPair)
    }

    func testSettingsAndReviewLocalizationKeysHaveAllSupportedLanguages() {
        let requiredKeys = [
            "برنامهٔ روزانه", "روش تمرین", "provider.cloudConsent",
            "recognitionReviewFormat", "reverseReviewTitle", "recordedResponses", "queueCount",
            "duration.minute", "duration.day", "duration.year"
        ]
        for language in PrototypeAppLanguage.allCases {
            let localization = PrototypeLocalization()
            localization.language = language
            for key in requiredKeys {
                XCTAssertFalse(localization.localized(key).isEmpty, "Missing (key) for (language.rawValue)")
                XCTAssertNotEqual(localization.localized(key), key, "Untranslated (key) for (language.rawValue)")
            }
        }
    }

    func testA1MediaPlanIsOptionalDeterministicAndTextSafe() {
        let a1 = PrototypeWord(german: "das Haus", persian: "خانه", level: "A1", partOfSpeech: "Nomen", example: "Das Haus ist neu.", exampleTranslation: "خانه جدید است.")
        let b1 = PrototypeWord(german: "die Entscheidung", persian: "تصمیم", level: "B1", partOfSpeech: "Nomen", example: "Die Entscheidung ist wichtig.", exampleTranslation: "تصمیم مهم است.")

        let plan = PrototypeA1MediaPlanner.plan(for: a1, includeAudio: true, includeImage: true)
        XCTAssertTrue(plan.isEligible)
        XCTAssertEqual(plan.audioCacheKey, "audio.v1.de|das_Haus|A1")
        XCTAssertEqual(plan.imageCacheKey, "image.v1.de|das_Haus|A1")
        XCTAssertNotNil(plan.imagePrompt)

        let textOnly = PrototypeA1MediaPlanner.plan(for: a1, includeAudio: false, includeImage: false)
        XCTAssertTrue(textOnly.isEligible)
        XCTAssertNil(textOnly.audioCacheKey)
        XCTAssertNil(textOnly.imageCacheKey)

        let higherLevel = PrototypeA1MediaPlanner.plan(for: b1, includeAudio: true, includeImage: true)
        XCTAssertFalse(higherLevel.isEligible)
        XCTAssertNil(higherLevel.imagePrompt)
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
            XCTAssertEqual(card.word.german, fixture.targetText)
            XCTAssertEqual(card.word.persian, fixture.sourceText)
            XCTAssertEqual(card.word.example, fixture.targetExample)
            XCTAssertEqual(card.word.exampleTranslation, fixture.sourceExample)
            XCTAssertEqual(card.word.sourceLanguageTag, fixture.sourceLanguageTag)
            XCTAssertEqual(card.word.targetLanguageTag, fixture.targetLanguageTag)
        }
    }

    @MainActor
    func testEverySupportedDirectedLanguagePairHasIsolatedLearningCards() {
        let store = PrototypeStore(inMemory: true)
        let languages = ["fa", "de", "en"]

        for source in languages {
            for target in languages where target != source {
                let cards = store.words(sourceLanguageTag: source, targetLanguageTag: target)
                XCTAssertGreaterThanOrEqual(cards.count, 5, "Missing test cards for \(source)→\(target)")
                XCTAssertTrue(cards.allSatisfy {
                    $0.sourceLanguageTag == source && $0.targetLanguageTag == target
                })
            }
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
        XCTAssertTrue(store.words.contains {
            $0.persian == "مرخص کردن" && $0.sourceLanguageTag == "fa" && $0.targetLanguageTag == "de"
        })

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

    @MainActor
    func testAllFourRatingsPersistIndependentReviewEvents() throws {
        let store = PrototypeStore(inMemory: true)
        let words = Array(store.words.prefix(4))
        XCTAssertEqual(words.count, 4)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        for (word, grade) in zip(words, PrototypeReviewGrade.allCases) {
            XCTAssertNotNil(store.record(grade, for: word, mode: .recognition, at: now))
            XCTAssertEqual(store.reviewCount(for: word, mode: .recognition), 1)
            XCTAssertFalse(store.isReviewable(word, mode: .recognition, at: now))
        }

        XCTAssertEqual(store.totalReviews, 4)
        XCTAssertEqual(store.grades.values.flatMap { $0 }.count, 4)
        XCTAssertEqual(store.reviewCount(for: words[0], mode: .reverseTranslation), 0)
    }
}
