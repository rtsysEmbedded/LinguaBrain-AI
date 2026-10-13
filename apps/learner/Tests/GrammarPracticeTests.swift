import XCTest
import SwiftUI
import LinguaBrainApplication
import LinguaBrainDomain
@testable import LinguaBrain

@MainActor
final class GrammarPracticeTests: XCTestCase {
    func testGrammarSurfaceSeparatesPromptExampleAndLearnerExplanation() async throws {
        let input = GrammarExerciseTemplate(
            learnerID: "learner",
            objectiveKey: "de.conjunction.weil",
            sourceLanguage: "de",
            targetLanguage: "de",
            cefrLevel: "A2",
            mode: .explainUsage,
            ruleCode: "de.conjunction.weil",
            grammaticalRole: "subordinate_conjunction",
            prompt: "Warum steht das Verb am Ende?",
            referenceAnswer: "Nach weil steht das finite Verb am Ende.",
            referenceExplanation: "Weil leitet einen Nebensatz ein.",
            demonstration: "Er bleibt, weil er krank ist."
        )
        let descriptor = try GrammarExerciseFactory.make(input, rules: GrammarContentCatalog.bundled.ruleIndex)
        let fake = GrammarSurfaceSessionFake(snapshot: PracticeSessionSnapshot(exercise: descriptor.exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.prepare(exercise: descriptor.exercise)

        XCTAssertNotNil(GrammarPracticeView(model: model, descriptor: descriptor).body)
        XCTAssertEqual(descriptor.mode, .explainUsage)
        XCTAssertNotNil(descriptor.demonstration)
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: model.state.phase, evaluationAvailable: false, hasExplicitReveal: false))
    }

    func testGrammarSentenceAndLearnerAnswerCanUseIndependentDirections() {
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "de-DE"), .leftToRight)
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "fa-IR"), .rightToLeft)
    }
}

private actor GrammarSurfaceSessionFake: PracticeSessionUseCases {
    let snapshot: PracticeSessionSnapshot
    init(snapshot: PracticeSessionSnapshot) { self.snapshot = snapshot }
    func prepare(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot { snapshot }
    func resume(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot { snapshot }
    func requestHint(exerciseID: UUID) async throws -> PracticeSessionSnapshot { snapshot }
    func reveal(exerciseID: UUID, answerCopied: Bool) async throws -> PracticeSessionSnapshot { snapshot }
    func skip(exerciseID: UUID) async throws -> PracticeSessionSnapshot { snapshot }
    func retry(exerciseID: UUID) async throws -> PracticeSessionSnapshot { snapshot }
    func `continue`(exerciseID: UUID) async throws -> PracticeSessionSnapshot { snapshot }
    func finish(exerciseID: UUID) async throws -> PracticeSessionSnapshot { snapshot }
    func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent]) async throws -> Attempt {
        Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: response, submittedAt: Date(timeIntervalSince1970: 1))
    }
}
