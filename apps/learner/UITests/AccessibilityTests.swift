import XCTest

@MainActor
final class AccessibilityTests: XCTestCase {
    
    func testGenerationPreviewSupportsDynamicType() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let generationButton = app.buttons["generation.generate"]
        XCTAssertTrue(generationButton.exists, "Generation button should exist")
        
        generationButton.tap()
        
        let previewText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Baک'")).firstMatch
        XCTAssertTrue(previewText.waitForExistence(timeout: 5), "Preview text should appear")
    }
    
    func testCardRenderingSupportsVoiceOver() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let previewText = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'Bank'")).firstMatch
        XCTAssertTrue(previewText.waitForExistence(timeout: 5), "Card preview should exist")
        
        previewText.swipeRight()
        
        let translation = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'بانک'")).firstMatch
        XCTAssertTrue(translation.waitForExistence(timeout: 3), "Translation should be accessible")
    }
    
    func testMixedPracticeGameRtlLtrLayout() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let modePicker = app.pickers["modePicker"]
        if modePicker.exists {
            modePicker.tap()
            let mixedPractice = app.tables.cells["mixedPractice"]
            if mixedPractice.exists {
                mixedPractice.tap()
            }
        }
        
        let mixedPracticeButton = app.buttons["mixedPractice.title"]
        if mixedPracticeButton.exists {
            mixedPracticeButton.tap()
        }
        
        let directTranslation = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'direct'")).firstMatch
        XCTAssertTrue(directTranslation.waitForExistence(timeout: 3), "Direct translation option should exist")
    }
    
    func testSettingsMenuAccessibility() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let settingsButton = app.navigationBars.buttons["settings"])
        XCTAssertTrue(settingsButton.exists, "Settings button should exist")
    }
    
    func testExportPreviewSupportsKeyboardNavigation() async throws {
        let app = XCUIApplication()
        app.launch()
        
        let nextButton = app.buttons["Next"]
        XCTAssertTrue(nextButton.exists, "Next button should exist for keyboard navigation")
        
        let previousButton = app.buttons["Previous"]
        XCTAssertTrue(previousButton.exists, "Previous button should exist for keyboard navigation")
    }
}