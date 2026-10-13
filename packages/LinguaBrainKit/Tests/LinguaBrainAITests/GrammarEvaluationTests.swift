import XCTest
import LinguaBrainDomain
import LinguaBrainApplication
@testable import LinguaBrainAI

final class GrammarEvaluationTests: XCTestCase {
    struct Transport: GrammarEvaluationTransport {
        let result: Result<GrammarEvaluationProposal, Error>
        func evaluate(_ request: GrammarEvaluationRequest) async throws -> GrammarEvaluationProposal { try result.get() }
    }
    private let rule = GrammarExerciseFactory.rules["de.conjunction.weil"]!
    private let exercise = ExerciseInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000002101")!, reviewUnit: ReviewUnit(skill: .grammar, objectiveKey: "weil"), prompt: "Er bleibt, weil er krank ist.", sourceLanguage: "fa", targetLanguage: "de")
    private func attempt(_ text: String) -> Attempt { Attempt(id: UUID(uuidString: "00000000-0000-0000-0000-000000002102")!, exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: text, submittedAt: Date(timeIntervalSince1970: 10)) }

    func testAcceptsEquivalentLearnerWordingAndKeepsExplanationAndApplicationSeparate() async throws {
        let proposal = GrammarEvaluationProposal(outcome: .correct, score: 1, confidence: 0.9, explanationFeedback: "معنی قاعده درست است.", applicationFeedback: "در جمله هم درست اعمال شده.", rule: RuleReference(code: rule.code))
        let provider = GrammarEvaluationProvider(transport: Transport(result: .success(proposal)))
        let result = try await provider.evaluate(GrammarEvaluationRequest(prompt: exercise.prompt, explanation: "بعد از weil فعل صرف‌شده آخر می‌آید", rule: rule), attempt: attempt("بعد از weil فعل آخر می‌آید"), exercise: exercise)
        XCTAssertEqual(result.outcome, .correct); XCTAssertEqual(result.feedback.count, 2); XCTAssertEqual(result.rules, [RuleReference(code: rule.code)])
    }
    func testWrongRuleCannotBeApproved() async {
        let proposal = GrammarEvaluationProposal(outcome: .correct, score: 1, confidence: 1, explanationFeedback: "x", applicationFeedback: "y", rule: RuleReference(code: "invented"))
        do { _ = try await GrammarEvaluationProvider(transport: Transport(result: .success(proposal))).evaluate(GrammarEvaluationRequest(prompt: exercise.prompt, explanation: "x", rule: rule), attempt: attempt("x"), exercise: exercise); XCTFail("expected rejection") }
        catch { XCTAssertEqual(error as? PracticeEvaluationError, .malformedOutput) }
    }
    func testFailureCancellationAndLowConfidenceRemainUngraded() async {
        let low = GrammarEvaluationProposal(outcome: .incorrect, score: 0, confidence: 0.2, explanationFeedback: "x", applicationFeedback: "y", rule: RuleReference(code: rule.code))
        do { _ = try await GrammarEvaluationProvider(transport: Transport(result: .success(low))).evaluate(GrammarEvaluationRequest(prompt: exercise.prompt, explanation: "x", rule: rule), attempt: attempt("x"), exercise: exercise); XCTFail() } catch { XCTAssertEqual(error as? PracticeEvaluationError, .malformedOutput) }
        do { _ = try await GrammarEvaluationProvider(transport: Transport(result: .failure(CancellationError()))).evaluate(GrammarEvaluationRequest(prompt: exercise.prompt, explanation: "x", rule: rule), attempt: attempt("x"), exercise: exercise); XCTFail() } catch { XCTAssertEqual(error as? PracticeEvaluationError, .cancelled) }
    }

    func testPracticeEvaluatorEntryPointResolvesOnlyCanonicalRule() async throws {
        let canonicalExercise = ExerciseInstance(
            id: exercise.id,
            reviewUnit: ReviewUnit(skill: .grammar, objectiveKey: rule.code),
            prompt: exercise.prompt,
            sourceLanguage: exercise.sourceLanguage,
            targetLanguage: exercise.targetLanguage
        )
        let proposal = GrammarEvaluationProposal(outcome: .partial, score: 0.65, confidence: 0.9, explanationFeedback: "قاعده را می‌داند.", applicationFeedback: "مثال ناقص است.", rule: RuleReference(code: rule.code))
        let provider = GrammarEvaluationProvider(transport: Transport(result: .success(proposal)))
        let result = try await provider.evaluate(attempt("بعد از weil فعل آخر است"), exercise: canonicalExercise)
        XCTAssertEqual(result.outcome, .partial)
        XCTAssertEqual(result.feedback.count, 2)

        let unknown = ExerciseInstance(reviewUnit: ReviewUnit(skill: .grammar, objectiveKey: "invented.rule"), prompt: "x", sourceLanguage: "fa", targetLanguage: "de")
        do {
            _ = try await provider.evaluate(attempt("x"), exercise: unknown)
            XCTFail("Unknown canonical rule must be rejected")
        } catch {
            XCTAssertEqual(error as? PracticeEvaluationError, .malformedOutput)
        }
    }
}
