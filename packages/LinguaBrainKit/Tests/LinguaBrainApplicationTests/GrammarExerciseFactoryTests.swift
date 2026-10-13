import XCTest
import LinguaBrainDomain
@testable import LinguaBrainApplication

final class GrammarExerciseFactoryTests: XCTestCase {
    private func input(_ changes: (inout GrammarExerciseTemplate) -> Void = { _ in }) -> GrammarExerciseTemplate {
        var value = GrammarExerciseTemplate(objectiveKey: "verb-final", sourceLanguage: "en", targetLanguage: "de", cefrLevel: "A2", mode: .explainError, ruleCode: "de.word_order.verb_final", grammaticalRole: "main_verb_position", prompt: "Ich weiß, dass er heute kommt.", referenceAnswer: "Put the finite verb at the end of the subordinate clause.", referenceExplanation: "After dass, the finite verb comes last.", hints: ["Find the conjunction.", "Look at the verb position."], errorSpan: "kommt")
        changes(&value); return value
    }
    func testCuratedExerciseIsDeterministicAndKeepsExplanationRequired() throws {
        let a = try GrammarExerciseFactory.make(input()); let b = try GrammarExerciseFactory.make(input())
        XCTAssertEqual(a, b); XCTAssertEqual(a.rule.code, "de.word_order.verb_final"); XCTAssertTrue(a.requiresLearnerExplanation)
    }
    func testUsageAllowsOptionalDemonstrationAndScaffold() throws {
        var x = input { $0.mode = .explainUsage; $0.demonstration = "weil ich lerne"; $0.clozeScaffold = "..., weil ich ___." }
        XCTAssertEqual(try GrammarExerciseFactory.make(x).mode, .explainUsage)
    }
    func testRejectsAmbiguousMultipleDirtyOrWrongRoleContent() {
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.isAmbiguous = true }))
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.issueCount = 2 }))
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.cleanSource = "generated" }))
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.grammaticalRole = "preposition_case" }))
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.ruleCode = "unknown" }))
    }
    func testHintsAreBoundedAndExplanationIsNotReplacedByCloze() {
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.hints = ["a", "a"] }))
        XCTAssertThrowsError(try GrammarExerciseFactory.make(input { $0.hints = ["1", "2", "3", "4"] }))
        XCTAssertNoThrow(try GrammarExerciseFactory.make(input { $0.clozeScaffold = "Ich ___ Deutsch." }))
    }
}
