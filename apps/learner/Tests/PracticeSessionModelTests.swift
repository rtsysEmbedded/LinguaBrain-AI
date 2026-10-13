import Foundation
import LinguaBrainDomain
import SwiftUI
import XCTest
@testable import LinguaBrain

@MainActor
final class PracticeSessionModelTests: XCTestCase {
    func testMapsEveryApplicationStateToAnExplicitPresentationPhase() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "model-states")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            sessionID: exercise.id,
            exerciseID: exercise.id,
            reviewUnitID: unit.id,
            response: "antwort",
            submittedAt: Date(timeIntervalSince1970: 10),
            outcome: .pending
        )
        let cases: [(PracticeState, PracticePresentationPhase)] = [
            (.answering, .answering),
            (.evaluating, .evaluating),
            (.feedback, .feedback),
            (.revealed, .revealed),
            (.unavailable, .unavailable(.providerUnavailable)),
            (.finished, .finished)
        ]

        for (applicationState, expectedPhase) in cases {
            let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: applicationState, attempts: [attempt]))
            let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
            await model.load(exercise: exercise)
            XCTAssertEqual(model.state.phase, expectedPhase)
        }

        let loadingFake = DelayedModelSession()
        let loadingModel = PracticeSessionModel(composition: PracticeComposition(session: loadingFake))
        let loading = Task { @MainActor in await loadingModel.load(exercise: exercise) }
        await loadingFake.waitUntilPrepareStarts()
        XCTAssertEqual(loadingModel.state.phase, .loading)
        loadingModel.cancel()
        await loadingFake.releaseFirst()
        await loading.value
    }

    func testEmptyQueueIsNotLoadingAndCompositionUsesInjectedSession() async {
        let fake = ModelSessionFake()
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: nil)
        XCTAssertEqual(model.state.phase, .empty)
        let prepareCount = await fake.prepareCount()
        XCTAssertEqual(prepareCount, 0)
    }

    func testAnswerAndFeedbackSurviveRedrawAndResume() async throws {
        let unit = ReviewUnit(skill: .grammar, objectiveKey: "resume")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            sessionID: exercise.id,
            exerciseID: exercise.id,
            reviewUnitID: unit.id,
            response: "gespeichert",
            submittedAt: Date(timeIntervalSince1970: 20),
            outcome: .partial,
            feedback: [TypedFeedback(message: "Almost")]
        )
        let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .feedback, attempts: [attempt]))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)
        XCTAssertEqual(model.state.answerText, "gespeichert")
        XCTAssertEqual(model.state.feedback, [TypedFeedback(message: "Almost")])
        await model.resume()
        XCTAssertEqual(model.answerText, "gespeichert")
        XCTAssertEqual(model.state.phase, .feedback)
    }

    func testSubmitUsesTheApplicationBoundaryAndKeepsTheOriginalAnswer() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "submit")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!,
            sessionID: exercise.id,
            exerciseID: exercise.id,
            reviewUnitID: unit.id,
            response: "typed answer",
            submittedAt: Date(timeIntervalSince1970: 30),
            outcome: .correct,
            feedback: [TypedFeedback(message: "Good")]
        )
        let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .feedback, attempts: [attempt]))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)
        model.answerText = "typed answer"
        await model.submit()
        XCTAssertEqual(model.state.phase, .feedback)
        XCTAssertEqual(model.state.answerText, "typed answer")
        let intents = await fake.recordedIntents()
        XCTAssertEqual(intents, ["prepare", "resume"])
    }

    func testIntentNamesDelegateToApplicationAndRepeatedContinueIsSafe() async throws {
        let unit = ReviewUnit(skill: .listening, objectiveKey: "intents")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)
        await model.requestHint()
        await model.reveal()
        await model.copyAnswer()
        await model.skip()
        await model.retry()
        await model.continue()
        let intents = await fake.recordedIntents()
        XCTAssertEqual(intents, ["prepare", "hint", "reveal", "copy", "skip", "retry", "continue"])
    }

    func testProviderUnavailableIsAStateAndPersistenceFailureIsRecoverable() async {
        let unit = ReviewUnit(skill: .speaking, objectiveKey: "unavailable")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let unavailable = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .unavailable))
        let unavailableModel = PracticeSessionModel(composition: PracticeComposition(session: unavailable))
        await unavailableModel.load(exercise: exercise)
        XCTAssertEqual(unavailableModel.state.phase, .unavailable(.providerUnavailable))

        let failing = ModelSessionFake(error: TestModelError.persistence)
        let failingModel = PracticeSessionModel(composition: PracticeComposition(session: failing))
        await failingModel.load(exercise: exercise)
        XCTAssertEqual(failingModel.state.phase, .recoverableFailure(.persistence))
    }

    func testLateResultFromSupersededExerciseDoesNotChangeCurrentState() async throws {
        let firstUnit = ReviewUnit(skill: .writing, objectiveKey: "first")
        let secondUnit = ReviewUnit(skill: .writing, objectiveKey: "second")
        let first = ExerciseInstance(reviewUnit: firstUnit, prompt: "first", sourceLanguage: "fa", targetLanguage: "de")
        let second = ExerciseInstance(reviewUnit: secondUnit, prompt: "second", sourceLanguage: "fa", targetLanguage: "de")
        let fake = DelayedModelSession()
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))

        let firstLoad = Task { @MainActor in await model.load(exercise: first) }
        await fake.waitUntilPrepareStarts()
        let secondLoad = Task { @MainActor in await model.load(exercise: second) }
        await fake.releaseFirst()
        await secondLoad.value
        await firstLoad.value
        XCTAssertEqual(model.state.exercise?.id, second.id)
        XCTAssertEqual(model.state.answerText, "")
    }

    func testCancellationInvalidatesPendingPresentationWork() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "cancel")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "p", sourceLanguage: "fa", targetLanguage: "de")
        let fake = DelayedModelSession()
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        let load = Task { @MainActor in await model.load(exercise: exercise) }
        await fake.waitUntilPrepareStarts()
        model.cancel()
        await fake.releaseFirst()
        await load.value
        XCTAssertEqual(model.state.exercise, exercise)
        XCTAssertNotEqual(model.state.phase, .answering)
    }

    func testLegacyRecognitionAndReverseReviewRemainConstructible() {
        _ = ReviewPrototypeView(mode: .recognition)
        _ = ReviewPrototypeView(mode: .reverseTranslation)
    }

    func testScaffoldAcceptsInjectedContentAndSupportsBothDirections() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "scaffold")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "Prompt", sourceLanguage: "fa", targetLanguage: "de")
        let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)

        let scaffold = PracticeScaffold(
            model: model,
            titleKey: "practice.shared.title",
            instructionKey: "practice.shared.instruction",
            descriptionKey: "practice.shared.description",
            promptContent: { Text("German prompt") },
            answerEntry: { binding in TextField("Answer", text: binding) },
            revealedContent: { Text("SECRET MODEL ANSWER") }
        )

        _ = scaffold.environment(\.layoutDirection, .leftToRight)
        _ = scaffold.environment(\.layoutDirection, .rightToLeft)
        XCTAssertEqual(model.state.phase, .answering)
    }

    func testAnswerTextDirectionFollowsAnswerLanguageNotInterfaceLanguage() {
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "fa"), .rightToLeft)
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "fa-IR"), .rightToLeft)
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "de-DE"), .leftToRight)
        XCTAssertEqual(PracticeLanguageDirection.layoutDirection(for: "en_US"), .leftToRight)

        let interfaceDirection = LayoutDirection.rightToLeft
        let answerDirection = PracticeLanguageDirection.layoutDirection(for: "de")
        XCTAssertEqual(interfaceDirection, .rightToLeft)
        XCTAssertEqual(answerDirection, .leftToRight)
        XCTAssertNotEqual(interfaceDirection, answerDirection)
    }

    func testScaffoldRendersNarrowLargeTextSurfaceWithoutExposingAnswerBeforeReveal() async throws {
        let unit = ReviewUnit(skill: .writing, objectiveKey: "layout-qa")
        let exercise = ExerciseInstance(
            reviewUnit: unit,
            prompt: "Persian prompt",
            sourceLanguage: "fa",
            targetLanguage: "de"
        )
        let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: .answering))
        let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
        await model.load(exercise: exercise)

        let localization = PrototypeLocalization(defaults: try XCTUnwrap(UserDefaults(suiteName: "t011-layout-qa")))
        let scaffold = PracticeScaffold(
            model: model,
            titleKey: "practice.shared.title",
            instructionKey: "practice.shared.instruction",
            descriptionKey: "practice.shared.description",
            answerLanguageTag: exercise.targetLanguage,
            referenceAnswer: "SECRET MODEL ANSWER",
            promptContent: { Text("Persian prompt") },
            answerEntry: { binding in TextField("Answer", text: binding) },
            revealedContent: { Text("SECRET MODEL ANSWER") }
        )
        .environment(localization)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dynamicTypeSize, .accessibility5)
        .frame(width: 280)

        let renderer = ImageRenderer(content: scaffold)
        renderer.proposedSize = ProposedViewSize(width: 280, height: 1_400)
        renderer.scale = 1

        XCTAssertNotNil(renderer.uiImage)
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(
            phase: model.state.phase,
            evaluationAvailable: false,
            hasExplicitReveal: false
        ))
    }

    func testScaffoldRendersEverySharedStateAtSupportedSmokeWidths() async throws {
        let unit = ReviewUnit(skill: .grammar, objectiveKey: "all-state-layout-qa")
        let exercise = ExerciseInstance(
            reviewUnit: unit,
            prompt: "Persian prompt",
            sourceLanguage: "fa",
            targetLanguage: "de"
        )
        let localization = PrototypeLocalization(defaults: try XCTUnwrap(UserDefaults(suiteName: "t011-all-state-layout-qa")))
        let states: [PracticeState] = [
            .answering, .evaluating, .feedback, .revealed,
            .unavailable, .finished
        ]

        for applicationState in states {
            let fake = ModelSessionFake(snapshot: PracticeSessionSnapshot(exercise: exercise, state: applicationState))
            let model = PracticeSessionModel(composition: PracticeComposition(session: fake))
            await model.load(exercise: exercise)

            let scaffold = AnyView(
                PracticeScaffold(
                    model: model,
                    titleKey: "practice.shared.title",
                    instructionKey: "practice.shared.instruction",
                    descriptionKey: "practice.shared.description",
                    answerLanguageTag: exercise.targetLanguage,
                    referenceAnswer: "SECRET MODEL ANSWER",
                    promptContent: { Text("Persian prompt") },
                    answerEntry: { binding in TextField("Answer", text: binding) },
                    revealedContent: { Text("SECRET MODEL ANSWER") }
                )
                .environment(localization)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.dynamicTypeSize, .accessibility5)
            )

            for width in [280.0, 320.0, 744.0] {
                let renderer = ImageRenderer(content: scaffold.frame(width: width))
                renderer.proposedSize = ProposedViewSize(width: width, height: 1_400)
                renderer.scale = 1
                XCTAssertNotNil(renderer.uiImage, "Could not render \(applicationState) at width \(width)")
            }
        }

        let loadingModel = PracticeSessionModel(composition: PracticeComposition(session: ModelSessionFake()))
        let loadingScaffold = AnyView(
            PracticeScaffold(
                model: loadingModel,
                titleKey: "practice.shared.title",
                instructionKey: "practice.shared.instruction",
                descriptionKey: "practice.shared.description",
                promptContent: { Text("Persian prompt") },
                answerEntry: { binding in TextField("Answer", text: binding) },
                revealedContent: { Text("SECRET MODEL ANSWER") }
            )
            .environment(localization)
            .environment(\.dynamicTypeSize, .accessibility5)
            .frame(width: 280)
        )
        let loadingRenderer = ImageRenderer(content: loadingScaffold)
        loadingRenderer.proposedSize = ProposedViewSize(width: 280, height: 1_000)
        XCTAssertNotNil(loadingRenderer.uiImage)
        XCTAssertEqual(loadingModel.state.phase, .empty)

        let failingModel = PracticeSessionModel(
            composition: PracticeComposition(session: ModelSessionFake(error: TestModelError.persistence))
        )
        await failingModel.load(exercise: exercise)
        let failureScaffold = AnyView(
            PracticeScaffold(
                model: failingModel,
                titleKey: "practice.shared.title",
                instructionKey: "practice.shared.instruction",
                descriptionKey: "practice.shared.description",
                promptContent: { Text("Persian prompt") },
                answerEntry: { binding in TextField("Answer", text: binding) },
                revealedContent: { Text("SECRET MODEL ANSWER") }
            )
            .environment(localization)
            .environment(\.dynamicTypeSize, .accessibility5)
            .frame(width: 280)
        )
        let failureRenderer = ImageRenderer(content: failureScaffold)
        failureRenderer.proposedSize = ProposedViewSize(width: 280, height: 1_000)
        XCTAssertNotNil(failureRenderer.uiImage)
        XCTAssertEqual(failingModel.state.phase, .recoverableFailure(.persistence))
    }

    func testReferenceAnswerVisibilityNeverLeaksBeforeReveal() {
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: .loading, evaluationAvailable: true, hasExplicitReveal: false))
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: .answering, evaluationAvailable: true, hasExplicitReveal: false))
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: .evaluating, evaluationAvailable: true, hasExplicitReveal: false))
        XCTAssertTrue(PracticeReferenceAnswerVisibility.isVisible(phase: .revealed, evaluationAvailable: false, hasExplicitReveal: true))
        XCTAssertTrue(PracticeReferenceAnswerVisibility.isVisible(phase: .feedback, evaluationAvailable: true, hasExplicitReveal: false))
        XCTAssertFalse(PracticeReferenceAnswerVisibility.isVisible(phase: .unavailable(.providerUnavailable), evaluationAvailable: false, hasExplicitReveal: false))
    }
}

private enum TestModelError: Error { case persistence }

private actor ModelSessionFake: PracticeSessionUseCases {
    private let configuredSnapshot: PracticeSessionSnapshot?
    private let configuredError: Error?
    private var intents: [String] = []
    private var prepareCalls = 0

    init(snapshot: PracticeSessionSnapshot? = nil, error: Error? = nil) {
        configuredSnapshot = snapshot
        configuredError = error
    }

    func prepare(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot { try result("prepare", exercise: exercise) }
    func resume(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot { try result("resume", exercise: exercise) }
    func requestHint(exerciseID: UUID) async throws -> PracticeSessionSnapshot { try result("hint", exerciseID: exerciseID) }
    func reveal(exerciseID: UUID, answerCopied: Bool) async throws -> PracticeSessionSnapshot { try result(answerCopied ? "copy" : "reveal", exerciseID: exerciseID) }
    func skip(exerciseID: UUID) async throws -> PracticeSessionSnapshot { try result("skip", exerciseID: exerciseID) }
    func retry(exerciseID: UUID) async throws -> PracticeSessionSnapshot { try result("retry", exerciseID: exerciseID) }
    func `continue`(exerciseID: UUID) async throws -> PracticeSessionSnapshot { try result("continue", exerciseID: exerciseID) }
    func finish(exerciseID: UUID) async throws -> PracticeSessionSnapshot { try result("finish", exerciseID: exerciseID) }
    func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent]) async throws -> Attempt { try XCTUnwrap(configuredSnapshot?.currentAttempt) }

    func prepareCount() -> Int { prepareCalls }
    func recordedIntents() -> [String] { intents }

    private func result(_ intent: String, exercise: ExerciseInstance) throws -> PracticeSessionSnapshot {
        prepareCalls += intent == "prepare" ? 1 : 0
        intents.append(intent)
        if let configuredError { throw configuredError }
        return configuredSnapshot ?? PracticeSessionSnapshot(exercise: exercise, state: .answering)
    }

    private func result(_ intent: String, exerciseID: UUID) throws -> PracticeSessionSnapshot {
        intents.append(intent)
        if let configuredError { throw configuredError }
        guard let configuredSnapshot else {
            throw TestModelError.persistence
        }
        return configuredSnapshot
    }
}

private actor DelayedModelSession: PracticeSessionUseCases {
    private var firstPrepareStarted = false
    private var firstContinuation: CheckedContinuation<PracticeSessionSnapshot, Never>?
    private var firstExercise: ExerciseInstance?
    private var releasedFirst = false

    func prepare(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot {
        if !releasedFirst {
            firstPrepareStarted = true
            firstExercise = exercise
            return await withCheckedContinuation { firstContinuation = $0 }
        }
        return PracticeSessionSnapshot(exercise: exercise, state: .answering)
    }

    func resume(exercise: ExerciseInstance) async throws -> PracticeSessionSnapshot { try await prepare(exercise: exercise) }
    func requestHint(exerciseID: UUID) async throws -> PracticeSessionSnapshot { fatalError("not used") }
    func reveal(exerciseID: UUID, answerCopied: Bool) async throws -> PracticeSessionSnapshot { fatalError("not used") }
    func skip(exerciseID: UUID) async throws -> PracticeSessionSnapshot { fatalError("not used") }
    func retry(exerciseID: UUID) async throws -> PracticeSessionSnapshot { fatalError("not used") }
    func `continue`(exerciseID: UUID) async throws -> PracticeSessionSnapshot { fatalError("not used") }
    func finish(exerciseID: UUID) async throws -> PracticeSessionSnapshot { fatalError("not used") }
    func submit(exercise: ExerciseInstance, response: String, help: [HelpEvent]) async throws -> Attempt { fatalError("not used") }

    func waitUntilPrepareStarts() async {
        while !firstPrepareStarted { await Task.yield() }
    }

    func releaseFirst() {
        releasedFirst = true
        if let firstExercise {
            firstContinuation?.resume(returning: PracticeSessionSnapshot(exercise: firstExercise, state: .feedback))
        }
        firstContinuation = nil
    }
}
