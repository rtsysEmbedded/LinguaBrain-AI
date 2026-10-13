import XCTest
import LinguaBrainDomain
@testable import LinguaBrain

@MainActor final class ListeningPracticeTests: XCTestCase {
    func testTranscriptAndTranslationStayHiddenUntilReveal() async {
        let exercise = ExerciseInstance(reviewUnit: ReviewUnit(skill: .listening, objectiveKey: "negation"), prompt: "audio", sourceLanguage: "de", targetLanguage: "fa")
        let sentence = Sentence(text: "Er kommt nicht.", translation: "او نمی‌آید.")
        let fake = ListeningSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.prepare(exercise: exercise)
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: model.state.phase, evaluationAvailable: false, hasExplicitReveal: false))
        XCTAssertNotNil(ListeningPracticeView(model: model, exercise: exercise, sentence: sentence).body)
    }

    func testTranscriptVisibilityAllowsFeedbackOrExplicitRevealOnly() {
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: .answering, evaluationAvailable: false, hasExplicitReveal: false))
        XCTAssertTrue(PracticeReferenceAnswerVisibility.isVisible(phase: .feedback, evaluationAvailable: true, hasExplicitReveal: false))
        XCTAssertTrue(PracticeReferenceAnswerVisibility.isVisible(phase: .revealed, evaluationAvailable: false, hasExplicitReveal: true))
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: .unavailable(.providerUnavailable), evaluationAvailable: false, hasExplicitReveal: false))
    }
}

private actor ListeningSessionFake: PracticeSessionUseCases {
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
    func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent]) async throws -> Attempt { Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: response, submittedAt: .now) }
}
