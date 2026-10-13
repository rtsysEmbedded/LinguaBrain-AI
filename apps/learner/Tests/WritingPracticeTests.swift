import Foundation
import SwiftUI
import XCTest
import LinguaBrainApplication
import LinguaBrainDomain
@testable import LinguaBrain

@MainActor
final class WritingPracticeTests: XCTestCase {
    func testWritingSurfaceUsesMultilineAnswerAndTargetMetadata() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "writing-surface")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "Write a sentence", sourceLanguage: "fa", targetLanguage: "de")
        let descriptor = WritingExerciseDescriptor(
            exercise: exercise,
            targetWord: "aufstehen",
            partOfSpeech: "verb",
            cefrLevel: "A2",
            allowedContext: "A morning routine"
        )
        let fake = WritingSurfaceSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)

        let view = WritingPracticeView(model: model, descriptor: descriptor)
        XCTAssertNotNil(view.body)
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "de-DE"), .leftToRight)
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "fa-IR"), .rightToLeft)
    }

    func testWritingSurfaceDoesNotExposeReferenceAnswerBeforeEvaluation() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "writing-hidden-answer")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "Create a sentence", sourceLanguage: "fa", targetLanguage: "de")
        let fake = WritingSurfaceSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)

        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: model.state.phase, evaluationAvailable: false, hasExplicitReveal: false))
        XCTAssertNil(model.state.attempts.last?.evaluatorResult?.minimalCorrection)
    }

    func testCorrectionAcceptanceUsesInjectedBoundaryAndPreservesOriginalResponse() async throws {
        let exercise = ExerciseInstance(reviewUnit: ReviewUnit(skill: .writing, objectiveKey: "accept-correction"), prompt: "Write", sourceLanguage: "fa", targetLanguage: "de")
        let request = SentenceLearningRequest(learnerID: exercise.reviewUnit.learnerID, sourceLanguage: exercise.sourceLanguage, targetLanguage: exercise.targetLanguage, meaningKey: "morning routine", attemptID: UUID(uuidString: "00000000-0000-0000-0000-000000001501")!, originalResponse: "Ich aufstehe früh", minimalCorrection: "Ich stehe früh auf", ruleReferences: [RuleReference(code: "de.word_order.verb_final")])
        let acceptance = WritingCorrectionAcceptanceFake()
        let result = try await acceptance.accept(request)
        XCTAssertEqual(result.decision, .accepted)
        let saved = await acceptance.saved
        XCTAssertEqual(saved?.originalResponse, "Ich aufstehe früh")
        XCTAssertEqual(saved?.minimalCorrection, "Ich stehe früh auf")
    }
}

private actor WritingCorrectionAcceptanceFake: WritingCorrectionAcceptance {
    private(set) var saved: SentenceLearningRequest?
    func accept(_ request: SentenceLearningRequest) async throws -> SentenceLearningResult {
        saved = request
        return SentenceLearningResult(decision: .accepted, sentence: nil, revision: 1, sourceAttemptID: request.attemptID)
    }
}

private actor WritingSurfaceSessionFake: PracticeSessionUseCases {
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
        snapshot.attempts.last ?? Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: response, submittedAt: Date())
    }
}
