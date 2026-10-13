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

    func testTemplateRenderingIsSinglePass() {
        XCTAssertEqual(PromptTemplate.render("{a} and {b}", ["a": "{b}", "b": "x"]), "{b} and x")
        XCTAssertEqual(PromptTemplate.render("keep {unknown}", [:]), "keep {unknown}")
        XCTAssertEqual(PromptTemplate.render("open { only", ["only": "x"]), "open { only")
    }
}
