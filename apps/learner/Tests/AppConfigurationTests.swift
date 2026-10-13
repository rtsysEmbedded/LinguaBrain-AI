import Foundation
import XCTest
@testable import LinguaBrain

final class AppConfigurationTests: XCTestCase {
    func testBundledProviderCatalogLoadsCompleteDefaults() {
        let catalog = ProviderCatalog.bundled
        XCTAssertEqual(catalog.schemaVersion, 1)
        XCTAssertNotNil(PrototypeProviderMode(rawValue: catalog.defaultMode))
        XCTAssertNotNil(URL(string: catalog.endpoints.text))
        XCTAssertNotNil(URL(string: catalog.endpoints.image))
        XCTAssertNotNil(URL(string: catalog.endpoints.realtimeTranscription))
        for model in [catalog.models.text, catalog.models.image, catalog.models.speech, catalog.models.transcript, catalog.models.stream] {
            XCTAssertFalse(model.isEmpty)
        }
        XCTAssertTrue(catalog.defaultModelOptions.speech.contains(catalog.models.speech))
        XCTAssertTrue(catalog.realtimeTranscription.supportedModels.contains(catalog.models.transcript))
        XCTAssertTrue(catalog.realtimeTranscription.supportedModels.contains(catalog.models.stream))
        XCTAssertGreaterThan(catalog.requests.generateCard.timeoutSeconds, 0)
    }

    func testRealtimeProfilesUseConfiguredLanguageField() {
        let realtime = ProviderCatalog.bundled.realtimeTranscription
        for model in realtime.supportedModels {
            let configuration = realtime.configuration(model: model, languageTag: "de")
            XCTAssertEqual(configuration["model"] as? String, model)
            XCTAssertFalse(configuration["language"] != nil && configuration["languages"] != nil)
        }
    }

    func testBundledPromptCatalogLoadsAndResolvesTopicScopes() {
        let prompts = AIPromptCatalog.bundled
        XCTAssertEqual(prompts.schemaVersion, 1)
        XCTAssertFalse(prompts.templates.generateCardSystem.isEmpty)
        XCTAssertFalse(prompts.categoryScopes.isEmpty)
        XCTAssertTrue(prompts.categoryScope(for: "Software").hasPrefix("software development"))
        XCTAssertEqual(
            prompts.categoryScope(for: "Kochen"),
            PromptTemplate.render(prompts.defaultCategoryScope, ["domain": "Kochen"])
        )
    }

    func testBundledContentRulesAndSeedCardsLoad() {
        let rules = LearningContentRules.bundled
        XCTAssertEqual(rules.schemaVersion, 1)
        XCTAssertNotEqual(rules.defaults.sourceLanguageTag, rules.defaults.targetLanguageTag)
        XCTAssertTrue(PrototypeDomainClassifier.isGeneric(rules.defaults.domain))
        XCTAssertFalse(rules.domainKeywords.isEmpty)

        let seeds = SeedCardCatalog.bundled
        XCTAssertEqual(seeds.schemaVersion, 1)
        XCTAssertEqual(PrototypeData.words.count, seeds.words.count)
        XCTAssertEqual(Set(PrototypeData.multilingualSamples.map(\.id)).count, seeds.multilingualSamples.count)
        XCTAssertEqual(
            PrototypeData.multilingualSamples.first?.id.uuidString.lowercased(),
            "71000000-0000-4000-8000-000000000001"
        )
    }

    func testLevelListsAreConsistent() {
        let levels = LearningContentRules.bundled.levels
        XCTAssertEqual(levels.cefr, ["A1", "A2", "B1", "B2", "C1", "C2"])
        XCTAssertTrue(Set(levels.cardGeneration).isSubset(of: levels.cefr))
        XCTAssertTrue(levels.cardGeneration.contains(levels.cardGenerationDefault))
        let onboarding = LearningContentRules.bundled.onboarding
        XCTAssertTrue(onboarding.levels.contains(onboarding.defaultLevel))
        XCTAssertTrue(onboarding.missionKeys.contains(onboarding.defaultMissionKey))
        XCTAssertFalse(LearningContentRules.bundled.addWord.defaultExportFileName.isEmpty)
        XCTAssertTrue(levels.meets("b2", minimum: "B1"))
        XCTAssertFalse(levels.meets("A2", minimum: "B1"))
        XCTAssertFalse(levels.meets("unknown", minimum: "A1"))
    }

    /// Reference values from the formula that was previously written inline
    /// in `TodayPrototypeView`.
    func testDailyPlanReproducesReferenceValues() {
        let plan = LearningContentRules.bundled.dailyPlan
        XCTAssertEqual(plan.newCardCount(energy: 6, availableMinutes: 20, motivation: 3, modeRawValue: "balanced"), 11)
        XCTAssertEqual(plan.newCardCount(energy: 6, availableMinutes: 20, motivation: 3, modeRawValue: "lightReview"), 8)
        XCTAssertEqual(plan.newCardCount(energy: 6, availableMinutes: 20, motivation: 3, modeRawValue: "challenge"), 13)
        XCTAssertEqual(plan.newCardCount(energy: 6, availableMinutes: 20, motivation: 3, modeRawValue: "unknown"), 11)
        XCTAssertEqual(plan.newCardCount(energy: 10, availableMinutes: 30, motivation: 5, modeRawValue: "challenge"), plan.maximumNewCards)
        XCTAssertEqual(plan.newCardCount(energy: 1, availableMinutes: 5, motivation: 1, modeRawValue: "lightReview"), 1)
        XCTAssertTrue(plan.availableMinuteOptions.contains(plan.defaultAvailableMinutes))
        XCTAssertLessThan(plan.recoveryEnergyAtMost, plan.challengeEnergyAtLeast)
    }

    func testBatchGenerationPromptsRender() {
        let templates = AIPromptCatalog.bundled.templates
        XCTAssertEqual(
            PromptTemplate.render(templates.cardImageIllustration, ["word": "das Haus"]),
            "A clear, literal educational illustration of das Haus, no text"
        )
        XCTAssertTrue(PromptTemplate.render(templates.generateCardSchemaRetry, ["word": "Haus"]).contains("'Haus'"))
        let retry = PromptTemplate.render(templates.generateCardSourceLanguageRetry, ["sourceLanguageTag": "fa", "passage": "{x}"])
        XCTAssertTrue(retry.contains("strictly in fa."))
        XCTAssertTrue(retry.hasSuffix("Original passage: {x}"))
    }

    func testTemplateRenderingIsSinglePass() {
        XCTAssertEqual(PromptTemplate.render("{a} and {b}", ["a": "{b}", "b": "x"]), "{b} and x")
        XCTAssertEqual(PromptTemplate.render("keep {unknown}", [:]), "keep {unknown}")
        XCTAssertEqual(PromptTemplate.render("open { only", ["only": "x"]), "open { only")
    }
}
