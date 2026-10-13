import XCTest
import Foundation
@testable import LinguaBrain

@MainActor
final class GenerationPrototypeIntegrationTests: XCTestCase {

    // T018: an app-level generation + approval journey drives the orchestrator and
    // persists the approved bundle through the application/persistence boundary, then
    // reads it back (restart proof).
    func testGenerateApproveAndReloadThroughBoundary() async throws {
        let model = GenerationPrototypeModel()
        model.topic = "Bank"
        model.sourceLanguage = "de"
        model.targetLanguage = "fa"

        model.generate()
        // Wait for the asynchronous generation used by the UI.
        await waitUntil(timeout: 5) { !model.isGenerating && model.currentProposal != nil }
        let proposal = try XCTUnwrap(model.currentProposal)
        XCTAssertEqual(proposal.sourceLanguage, "de")
        XCTAssertEqual(proposal.targetLanguage, "fa")
        XCTAssertEqual(model.cards.count, proposal.senses.count * directionCount)

        // Approve each reviewable card.
        let ids = model.cards.map(\.id)
        for id in ids { model.approve(id) }
        await waitUntil(timeout: 5) {
            model.cards.allSatisfy { $0.state == .approved }
        }
        XCTAssertEqual(model.approvedCount, model.cards.count)

        // Reload approved bundles back through the boundary.
        let persisted = await model.reloadPersisted()
        XCTAssertGreaterThanOrEqual(persisted, 1)
    }

    func testRejectedCardIsNotApproved() async throws {
        let model = GenerationPrototypeModel()
        model.topic = "Bank"
        model.generate()
        await waitUntil(timeout: 5) { model.currentProposal != nil }

        if let first = model.cards.first {
            model.reject(first.id)
            await waitUntil(timeout: 5) {
                model.cards.contains { $0.id == first.id && $0.state == .rejected }
            }
        }
        // No approved bundle should exist yet.
        let persisted = await model.reloadPersisted()
        XCTAssertEqual(persisted, 0)
    }

    func testAPKGMediaSurvivesExportAndImport() async throws {
        let store = PrototypeStore(inMemory: true)
        let word = PrototypeWord(
            german: "Haus",
            persian: "خانه",
            level: "A1",
            partOfSpeech: "noun",
            example: "Das ist ein Haus.",
            exampleTranslation: "این یک خانه است.",
            domain: "general"
        )
        let audio = Data([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00])
        let image = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="))
        XCTAssertTrue(store.addGeneratedCard(word, pronunciationAudio: audio, illustrationImage: image))

        let document = try await PrototypeAPKGExporter.makeDocument(from: [word], store: store)
        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-roundtrip-\(UUID().uuidString).apkg")
        defer { try? FileManager.default.removeItem(at: packageURL) }
        try document.data.write(to: packageURL, options: .atomic)

        let preview = try APKGArchiveInspector().inspect(url: packageURL)
        XCTAssertEqual(preview.mediaEntryCount, 3, "Expected numeric audio/image entries plus the media map")
        let imported = try APKGCardReader().readCards(from: preview)
        let importedWord = try XCTUnwrap(imported.first)
        XCTAssertEqual(importedWord.word.german, word.german)
        XCTAssertEqual(importedWord.word.persian, word.persian)
        XCTAssertEqual(importedWord.word.example, word.example)
        XCTAssertEqual(importedWord.word.exampleTranslation, word.exampleTranslation)
        XCTAssertEqual(importedWord.sourceLanguageTag, word.sourceLanguageTag)
        XCTAssertEqual(importedWord.targetLanguageTag, word.targetLanguageTag)
        XCTAssertEqual(importedWord.pronunciationAudio, audio)
        XCTAssertEqual(importedWord.illustrationImage, image)
    }

    func testConsolidatedCardKeepsEveryProviderSense() throws {
        let json = #"""
        {
          "targetText": "aufführen",
          "sourceMeaning": "اجرا کردن",
          "level": "B2",
          "partOfSpeech": "verb",
          "article": "",
          "topicRelevance": "direct",
          "example": { "target": "Sie führt das Stück auf.", "source": "او نمایش را اجرا می‌کند." },
          "senses": [
            { "meaning": "ذکر کردن", "usage": "formal", "example": { "target": "Er führt Gründe auf.", "source": "او دلایلی را ذکر می‌کند." }, "collocations": [] },
            { "meaning": "اجرا کردن", "usage": "theatre", "example": { "target": "Sie führt das Stück auf.", "source": "او نمایش را اجرا می‌کند." }, "collocations": [] }
          ]
        }
        """#
        let draft = try JSONDecoder().decode(ConfiguredProviderCard.self, from: Data(json.utf8))
        let card = draft.consolidatedPrototypeWord(domain: "theatre", sourceLanguageTag: "fa", targetLanguageTag: "de")

        XCTAssertTrue(card.persian.contains("اجرا کردن"))
        XCTAssertTrue(card.persian.contains("ذکر کردن"))
        XCTAssertEqual(card.examples.count, 2)
        XCTAssertEqual(card.domain, "theatre")
    }

    func testDeletingSelectedCardRemovesMediaAndLearningState() {
        let store = PrototypeStore(inMemory: true)
        let word = PrototypeWord(
            german: "löschen",
            persian: "حذف کردن",
            level: "A2",
            partOfSpeech: "verb",
            example: "Ich lösche die Karte.",
            exampleTranslation: "من کارت را حذف می‌کنم.",
            domain: "general"
        )
        XCTAssertTrue(store.addGeneratedCard(word, pronunciationAudio: Data([0x49, 0x44, 0x33]), illustrationImage: Data([0x89, 0x50, 0x4E, 0x47])))
        _ = store.record(.good, for: word)

        XCTAssertTrue(store.deleteCards(ids: [word.id]))
        XCTAssertFalse(store.words.contains(where: { $0.id == word.id }))
        XCTAssertNil(store.pronunciationAudio(for: word))
        XCTAssertNil(store.illustrationImage(for: word))
        XCTAssertEqual(store.reviewCount(for: word), 0)
    }

    func testDeletingOneIndependentMeaningKeepsSharedAudioForRemainingCard() {
        let store = PrototypeStore(inMemory: true)
        let first = PrototypeWord(
            german: "aufführen", persian: "اجرا کردن", level: "B2", partOfSpeech: "verb",
            example: "Sie führt das Stück auf.", exampleTranslation: "او نمایش را اجرا می‌کند.", domain: "theatre"
        )
        let second = PrototypeWord(
            german: "aufführen", persian: "ذکر کردن", level: "B2", partOfSpeech: "verb",
            example: "Er führt Gründe auf.", exampleTranslation: "او دلایلی را ذکر می‌کند.", domain: "theatre"
        )
        let audio = Data([0x49, 0x44, 0x33])

        XCTAssertTrue(store.addGeneratedCards([first, second], sharedPronunciationAudio: audio))
        XCTAssertEqual(store.pronunciationAudio(for: first), audio)
        XCTAssertEqual(store.pronunciationAudio(for: second), audio)

        XCTAssertTrue(store.deleteCards(ids: [first.id]))
        XCTAssertNil(store.pronunciationAudio(for: first))
        XCTAssertEqual(store.pronunciationAudio(for: second), audio)

        XCTAssertTrue(store.deleteCards(ids: [second.id]))
        XCTAssertNil(store.pronunciationAudio(for: second))
    }

    func testDailyLearningStateIsPersistedPerCalendarDay() throws {
        let store = PrototypeStore(inMemory: true)
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 12)))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))

        XCTAssertNil(store.dailyLearningState(for: date))
        store.saveDailyLearningState(energy: 2, availableMinutes: 5, motivation: 1, modeRawValue: "lightReview", for: date)

        let persisted = try XCTUnwrap(store.dailyLearningState(for: date))
        XCTAssertEqual(persisted.energy, 2)
        XCTAssertEqual(persisted.availableMinutes, 5)
        XCTAssertEqual(persisted.motivation, 1)
        XCTAssertEqual(persisted.modeRawValue, "lightReview")
        XCTAssertNil(store.dailyLearningState(for: nextDay))

        // Upsert must replace the same day's check-in rather than create a
        // second record that could make the planner input ambiguous.
        store.saveDailyLearningState(energy: 9, availableMinutes: 30, for: date)
        let updated = try XCTUnwrap(store.dailyLearningState(for: date))
        XCTAssertEqual(updated.energy, 9)
        XCTAssertEqual(updated.availableMinutes, 30)
    }

    func testSkillMasteryAndCorrectiveEvidenceAreStoredPerSkill() {
        let store = PrototypeStore(inMemory: true)
        let word = PrototypeWord(
            german: "arbeiten",
            persian: "کار کردن",
            level: "A1",
            partOfSpeech: "verb",
            example: "Ich arbeite heute.",
            exampleTranslation: "من امروز کار می‌کنم.",
            domain: "general"
        )
        XCTAssertTrue(store.addGeneratedCard(word))

        let reviewDate = Date(timeIntervalSince1970: 1_000)
        _ = store.record(
            .good,
            for: word,
            mode: .recognition,
            skill: .listening,
            responseTimeMilliseconds: 820,
            answer: "کار کردن",
            expectedAnswers: ["کار کردن"],
            at: reviewDate
        )
        _ = store.record(
            .again,
            for: word,
            mode: .reverseTranslation,
            skill: .recall,
            responseTimeMilliseconds: 1_400,
            answer: "arbeiten",
            expectedAnswers: ["arbeiten"],
            at: reviewDate.addingTimeInterval(1)
        )

        XCTAssertEqual(store.mastery(for: word, skill: .listening), 1, accuracy: 0.0001)
        XCTAssertEqual(store.mastery(for: word, skill: .recall), 0, accuracy: 0.0001)
        let listening = store.skillMastery(for: word)[.listening] ?? -1
        XCTAssertEqual(listening, 1, accuracy: 0.0001)
    }

    // MARK: Helpers

    var directionCount: Int { 2 } // recognition + recall

    func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}
