import Foundation
import XCTest
@testable import LinguaBrainAI
@testable import LinguaBrainApplication
@testable import LinguaBrainDomain

final class WritingEvaluationProviderTests: XCTestCase {
    func testDecoderMapsValidatedWritingProposalAndPreservesOriginal() throws {
        let document = try loadDocument()
        let fixture = try XCTUnwrap((document["fixtures"] as? [[String: Any]])?.first { $0["fixtureID"] as? String == "verb-position-error" })
        let input = try XCTUnwrap(input(from: fixture))
        let output = try XCTUnwrap(fixture["output"] as? [String: Any])
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": "writing-evaluation-v1", "output": output])
        let result = try PracticeEvaluationDecoder().decode(data: data, request: input, attemptID: UUID(), exerciseID: UUID(), reviewUnitID: UUID())
        XCTAssertEqual(result.outcome, .partial)
        XCTAssertEqual(result.score, 0.5)
        XCTAssertEqual(result.meaningStatus, .preserved)
        XCTAssertEqual(result.minimalCorrection, "Weil ich heute nach Hause gehe.")
        XCTAssertEqual(result.originalLearnerSentence, input.learnerSentence)
        XCTAssertEqual(result.rules.first?.code, "de.word_order.verb_final")
    }

    func testDecoderRejectsMalformedAndMeaningChangingAutoApproval() throws {
        let document = try loadDocument()
        let fixtures = try XCTUnwrap(document["fixtures"] as? [[String: Any]])
        let malformed = try XCTUnwrap(fixtures.first { $0["fixtureID"] as? String == "malformed-payload" })
        let request = try XCTUnwrap(input(from: malformed))
        let malformedData = try JSONSerialization.data(withJSONObject: ["schemaVersion": "writing-evaluation-v1", "output": malformed["output"] as Any])
        XCTAssertThrowsError(try PracticeEvaluationDecoder().decode(data: malformedData, request: request))

        let changed = try XCTUnwrap(fixtures.first { $0["fixtureID"] as? String == "meaning-changing-correction" })
        let changedInput = try XCTUnwrap(input(from: changed))
        var output = try XCTUnwrap(changed["output"] as? [String: Any])
        output["approvalPolicy"] = "autoApproveAllowed"
        let changedData = try JSONSerialization.data(withJSONObject: ["schemaVersion": "writing-evaluation-v1", "output": output])
        XCTAssertThrowsError(try PracticeEvaluationDecoder().decode(data: changedData, request: changedInput)) { error in
            XCTAssertEqual(error as? PracticeEvaluationDecoderError, .meaningChangeRequiresReview)
        }
    }

    func testProviderUsesInjectedTransportAndMapsCancellationWithoutLoggingResponse() async throws {
        let response = try JSONSerialization.data(withJSONObject: [
            "choices": [["message": ["content": "{\"schemaVersion\":\"writing-evaluation-v1\",\"output\":{\"outcome\":\"unavailable\",\"meaningAssessment\":{\"status\":\"uncertain\",\"confidence\":null},\"originalLearnerSentence\":\"Ich gehe.\",\"minimalCorrection\":null,\"naturalVariant\":null,\"explanation\":{\"language\":\"fa\",\"text\":\"در دسترس نیست\"},\"feedback\":[],\"ruleReferences\":[],\"affectedSpans\":[],\"score\":null,\"confidence\":null,\"unavailableReason\":\"providerUnavailable\",\"provenance\":{\"provider\":\"fixture\",\"model\":\"fixture\",\"evaluatorVersion\":\"1\",\"schemaVersion\":\"writing-evaluation-v1\",\"promptVersion\":\"writing-rubric-v1\",\"validatorVersion\":\"writing-validator-1\"},\"approvalPolicy\":\"humanReviewRequired\",\"canonicalContentAction\":\"none\",\"masterySchedulingMutation\":false}}"]]]
        ])
        let transport = FixedWritingTransport(data: response)
        let provider = WritingEvaluationProvider(configuration: ProviderConfiguration(mode: .local, endpoint: "https://fixture.invalid/v1", consentRequired: false), credentialLoader: EmptyCredentialLoader(), transport: transport)
        let unit = ReviewUnit(learnerID: "fixture", skill: .writing, objectiveKey: "write", sentenceID: UUID(), sentenceRevision: 1)
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "gehen", sourceLanguage: "fa", targetLanguage: "de")
        let attempt = Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "Ich gehe.", submittedAt: Date())
        let result = try await provider.evaluate(attempt, exercise: exercise)
        XCTAssertEqual(result.outcome, .unavailable)
        XCTAssertEqual(result.unavailableReason, .providerUnavailable)
        XCTAssertEqual(transport.requestCount, 1)
    }

    private func loadDocument() throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "practice-writing", withExtension: "json", subdirectory: "Fixtures"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func input(from fixture: [String: Any]) -> WritingEvaluationRequest? {
        guard let input = fixture["input"] as? [String: Any],
              let learnerID = input["learnerID"] as? String,
              let sourceLanguage = input["sourceLanguage"] as? String,
              let targetLanguage = input["targetLanguage"] as? String,
              let cefrLevel = input["cefrLevel"] as? String,
              let targetWord = input["targetWord"] as? String,
              let partOfSpeech = input["partOfSpeech"] as? String,
              let sentenceRevision = input["sentenceRevision"] as? Int,
              let allowedContext = input["allowedContext"] as? String,
              let learnerSentence = input["learnerSentence"] as? String else { return nil }
        return WritingEvaluationRequest(learnerID: learnerID, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage, cefrLevel: cefrLevel, targetWord: targetWord, partOfSpeech: partOfSpeech, sentenceRevision: sentenceRevision, allowedContext: allowedContext, learnerSentence: learnerSentence)
    }
}

private struct EmptyCredentialLoader: CredentialLoader {
    func loadCredential(for scope: String) throws -> String? { nil }
}

private struct FixedWritingTransport: WritingEvaluationTransport {
    let data: Data
    let requestCountBox = Counter()
    var requestCount: Int { requestCountBox.value }

    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requestCountBox.increment()
        let response = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://fixture.invalid")!, statusCode: 200, httpVersion: nil, headerFields: nil))
        return (data, response)
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
}
