import Foundation
import Synchronization
import XCTest
@testable import LinguaBrainAI
@testable import LinguaBrainApplication
@testable import LinguaBrainDomain
@testable import LinguaBrainPersistence

/// Records the request and answers with a fixed chat-completions body.
private final class RecordingTransport: WritingEvaluationTransport {
    private let requests = Mutex<[URLRequest]>([])
    let content: String
    let statusCode: Int

    init(content: String, statusCode: Int = 200) {
        self.content = content
        self.statusCode = statusCode
    }

    var lastRequest: URLRequest? { requests.withLock { $0.last } }

    func send(request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.withLock { $0.append(request) }
        let body = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
        return (body, HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!)
    }
}

private struct KeyLoader: CredentialLoader {
    func loadCredential(for scope: String) throws -> String? { "test-key" }
}

private struct Cards: PracticeCardSource {
    let cards: [PracticeCardCandidate]
    func practiceCards(sourceLanguage: String, targetLanguage: String) async throws -> [PracticeCardCandidate] {
        cards.filter { $0.sourceLanguage == sourceLanguage && $0.targetLanguage == targetLanguage }
    }
}

private struct FixedGrammarContext: GrammarEvaluationContextResolving {
    let context: GrammarEvaluationContext
    func context(for exercise: ExerciseInstance) async throws -> GrammarEvaluationContext? { context }
}

final class ChatPracticeEvaluationTests: XCTestCase {
    private let configuration = ProviderConfiguration(mode: .cloud, endpoint: "https://provider.example/v1/", modelID: "model-x", consentRequired: true)
    private let card = PracticeCardCandidate(
        cardID: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!, targetText: "gehen", sourceMeaning: "رفتن",
        partOfSpeech: "verb", cefrLevel: "A1", exampleTarget: "Ich gehe nach Hause.", exampleSource: "به خانه می‌روم.",
        exampleReview: .reviewed, sourceLanguage: "fa", targetLanguage: "de"
    )

    private func body(_ request: URLRequest?) throws -> [String: Any] {
        let data = try XCTUnwrap(request?.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func writingExercise() -> ExerciseInstance {
        let unit = ReviewUnit(learnerID: "local", skill: .writing, objectiveKey: CardBackedWritingRetrieval.objectiveKey(cardID: card.cardID))
        return ExerciseInstance(reviewUnit: unit, prompt: card.targetText, sourceLanguage: "fa", targetLanguage: "de")
    }

    private func validWritingOutput(for sentence: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "practice-writing", withExtension: "json", subdirectory: "Fixtures"))
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let fixture = try XCTUnwrap((document["fixtures"] as? [[String: Any]])?.first { $0["fixtureID"] as? String == "verb-position-error" })
        var output = try XCTUnwrap(fixture["output"] as? [String: Any])
        XCTAssertEqual(output["originalLearnerSentence"] as? String, sentence)
        output["provenance"] = ["provider": "provider.example", "model": "model-x", "evaluatorVersion": WritingEvaluationProvider.evaluatorVersion,
                                "schemaVersion": PracticeEvaluationDecoder.schemaVersion, "promptVersion": PracticeEvaluationDecoder.rubricVersion,
                                "validatorVersion": PracticeEvaluationDecoder.validatorVersion]
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": PracticeEvaluationDecoder.schemaVersion, "output": output])
        return String(decoding: data, as: UTF8.self)
    }

    func testWritingRequestCarriesCardContextInstructionsAndPinnedSchema() async throws {
        let sentence = "Weil ich heute nach Hause gehen."
        let transport = RecordingTransport(content: try validWritingOutput(for: sentence))
        let provider = WritingEvaluationProvider(
            configuration: configuration, credentialLoader: KeyLoader(), transport: transport,
            options: PracticeChatOptions(instructions: "SYSTEM", temperature: nil),
            contextResolver: CardWritingContextResolver(cards: Cards(cards: [card]))
        )
        let exercise = writingExercise()
        let result = try await provider.evaluate(Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: sentence, submittedAt: Date()), exercise: exercise)

        XCTAssertEqual(result.outcome, .partial)
        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.url?.absoluteString, "https://provider.example/v1/chat/completions")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        let json = try body(request)
        XCTAssertNil(json["temperature"], "No temperature is sent when none is configured")
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.first?["content"], "SYSTEM")
        let sent = try JSONDecoder().decode(WritingEvaluationRequest.self, from: Data(try XCTUnwrap(messages.last?["content"]).utf8))
        XCTAssertEqual(sent.targetWord, "gehen")
        XCTAssertEqual(sent.partOfSpeech, "verb")
        XCTAssertEqual(sent.cefrLevel, "A1")
        XCTAssertEqual(sent.allowedContext, "رفتن", "The card meaning is the allowed context")
        let format = try XCTUnwrap(json["response_format"] as? [String: Any])
        let schemaEnvelope = try XCTUnwrap(format["json_schema"] as? [String: Any])
        XCTAssertEqual(schemaEnvelope["strict"] as? Bool, true)
        let schemaText = String(decoding: try JSONSerialization.data(withJSONObject: schemaEnvelope), as: UTF8.self)
        for constant in [PracticeEvaluationDecoder.schemaVersion, PracticeEvaluationDecoder.rubricVersion, PracticeEvaluationDecoder.validatorVersion, "provider.example", "model-x"] {
            XCTAssertTrue(schemaText.contains("\"\(constant)\""), constant)
        }
    }

    func testHTTPFailureAndMalformedContentBecomeTypedErrors() async throws {
        let exercise = writingExercise()
        let attempt = Attempt(exerciseID: exercise.id, reviewUnitID: exercise.reviewUnit.id, response: "x", submittedAt: Date())
        let failing = WritingEvaluationProvider(configuration: configuration, credentialLoader: KeyLoader(), transport: RecordingTransport(content: "{}", statusCode: 500))
        do { _ = try await failing.evaluate(attempt, exercise: exercise); XCTFail("expected failure") }
        catch { XCTAssertEqual(error as? PracticeEvaluationError, .providerUnavailable) }
        let malformed = WritingEvaluationProvider(configuration: configuration, credentialLoader: KeyLoader(), transport: RecordingTransport(content: "not json"))
        do { _ = try await malformed.evaluate(attempt, exercise: exercise); XCTFail("expected failure") }
        catch { XCTAssertEqual(error as? PracticeEvaluationError, .malformedOutput) }
        let off = WritingEvaluationProvider(configuration: ProviderConfiguration(mode: .off), credentialLoader: KeyLoader(), transport: RecordingTransport(content: "{}"))
        do { _ = try await off.evaluate(attempt, exercise: exercise); XCTFail("expected failure") }
        catch { XCTAssertEqual(error as? PracticeEvaluationError, .providerUnavailable) }
    }

    func testGrammarTransportPinsTheRuleAndSendsTheReviewedReference() async throws {
        let rule = GrammarRule(code: "de.conjunction.weil", category: "conjunction", targetLanguage: "de", grammaticalRole: "subordinate_conjunction")
        let transport = RecordingTransport(content: #"{"outcome":"partial","score":0.6,"confidence":0.9,"explanationFeedback":"e","applicationFeedback":"a","ruleCode":"de.conjunction.weil"}"#)
        let provider = GrammarEvaluationProvider(
            transport: ChatGrammarEvaluationTransport(configuration: configuration, credentialLoader: KeyLoader(), options: PracticeChatOptions(instructions: "G", temperature: 0), transport: transport),
            contextResolver: FixedGrammarContext(context: GrammarEvaluationContext(rule: rule, referenceAnswer: "Ich bleibe zu Hause, weil ich krank bin.", referenceExplanation: "verb last"))
        )
        let unit = ReviewUnit(learnerID: "local", skill: .grammar, objectiveKey: "grammar.de.conjunction.weil.1")
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: "Ich bleibe zu Hause, weil ich bin krank.", sourceLanguage: "fa", targetLanguage: "de")
        let result = try await provider.evaluate(Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "فعل آخر می‌آید", submittedAt: Date()), exercise: exercise)

        XCTAssertEqual(result.outcome, .partial)
        XCTAssertEqual(result.provenance?.provider, "provider.example")
        XCTAssertEqual(result.provenance?.model, "model-x")
        let json = try body(transport.lastRequest)
        XCTAssertEqual(json["temperature"] as? Double, 0)
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        let user = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(messages.last?["content"]).utf8)) as? [String: Any])
        XCTAssertEqual(user["referenceAnswer"] as? String, "Ich bleibe zu Hause, weil ich krank bin.")
        XCTAssertEqual(user["ruleCode"] as? String, rule.code)
        let schemaText = String(decoding: try JSONSerialization.data(withJSONObject: try XCTUnwrap(json["response_format"])), as: UTF8.self)
        XCTAssertTrue(schemaText.contains("\"enum\":[\"de.conjunction.weil\"]"))
    }

    func testListeningUsesTheStoredSentenceRevisionAndChecksum() async throws {
        let repository = InMemoryPracticeRepository()
        let sentence = CardSentenceListeningRetrieval.sentence(for: card)
        try await repository.saveSentence(sentence)
        let unit = ReviewUnit(learnerID: "local", skill: .listening, objectiveKey: CardSentenceListeningRetrieval.objectiveKey(sentenceID: sentence.id), sentenceID: sentence.id, sentenceRevision: sentence.revision)
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: sentence.text, sourceLanguage: "fa", targetLanguage: "de")
        let transport = RecordingTransport(content: #"{"meaningStatus":"preserved","slots":[{"slot":"agent","status":"preserved"},{"slot":"action","status":"preserved"}],"score":1,"confidence":0.95,"feedback":["ok"]}"#)
        let provider = ListeningEvaluationProvider(
            transport: ChatListeningEvaluationTransport(configuration: configuration, credentialLoader: KeyLoader(), options: PracticeChatOptions(instructions: "L"), transport: transport),
            contextResolver: RepositoryListeningContextResolver(repository: repository, audioChecksum: { "checksum-\($0.revision)" })
        )
        let result = try await provider.evaluate(Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "به خانه می‌روم", submittedAt: Date()), exercise: exercise)

        XCTAssertEqual(result.outcome, .correct)
        XCTAssertEqual(result.sentenceRevision, sentence.revision)
        XCTAssertEqual(result.evaluatorVersion, ChatListeningEvaluationTransport.evaluatorVersion)
        let messages = try XCTUnwrap(try body(transport.lastRequest)["messages"] as? [[String: String]])
        let user = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(try XCTUnwrap(messages.last?["content"]).utf8)) as? [String: String])
        XCTAssertEqual(user["sentence"], sentence.text)
        XCTAssertEqual(user["reviewedTranslation"], sentence.translation)
    }

    func testListeningOutcomeFollowsTheContractSlotRules() {
        XCTAssertEqual(ChatListeningEvaluationTransport.outcome(for: [.agent: .preserved, .action: .preserved, .negation: .preserved]), .correct)
        XCTAssertEqual(ChatListeningEvaluationTransport.outcome(for: [.agent: .preserved, .modality: .missing]), .partial)
        XCTAssertEqual(ChatListeningEvaluationTransport.outcome(for: [.action: .preserved, .patient: .changed]), .partial)
        XCTAssertEqual(ChatListeningEvaluationTransport.outcome(for: [.negation: .changed, .agent: .preserved]), .incorrect)
        XCTAssertEqual(ChatListeningEvaluationTransport.outcome(for: [.tense: .changed]), .incorrect)
    }

    func testListeningReversedNegationIsIncorrectEvenIfTheModelSaysOtherwise() async throws {
        let repository = InMemoryPracticeRepository()
        let sentence = CardSentenceListeningRetrieval.sentence(for: card)
        try await repository.saveSentence(sentence)
        let unit = ReviewUnit(learnerID: "local", skill: .listening, objectiveKey: CardSentenceListeningRetrieval.objectiveKey(sentenceID: sentence.id), sentenceID: sentence.id, sentenceRevision: sentence.revision)
        let exercise = ExerciseInstance(reviewUnit: unit, prompt: sentence.text, sourceLanguage: "fa", targetLanguage: "de")
        let resolver = RepositoryListeningContextResolver(repository: repository, audioChecksum: { _ in "c" })
        let negated = RecordingTransport(content: #"{"meaningStatus":"changed","slots":[{"slot":"negation","status":"changed"},{"slot":"action","status":"preserved"}],"score":0.9,"confidence":0.9,"feedback":["x"]}"#)
        let result = try await ListeningEvaluationProvider(transport: ChatListeningEvaluationTransport(configuration: configuration, credentialLoader: KeyLoader(), options: PracticeChatOptions(instructions: "L"), transport: negated), contextResolver: resolver)
            .evaluate(Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "به خانه نمی‌روم", submittedAt: Date()), exercise: exercise)
        XCTAssertEqual(result.outcome, .incorrect)
        XCTAssertEqual(result.rules.map(\.code), ["listening.slot.negation"])

        let uncertain = RecordingTransport(content: #"{"meaningStatus":"uncertain","slots":[],"score":0.5,"confidence":0.4,"feedback":[]}"#)
        let unavailable = try await ListeningEvaluationProvider(transport: ChatListeningEvaluationTransport(configuration: configuration, credentialLoader: KeyLoader(), options: PracticeChatOptions(instructions: "L"), transport: uncertain), contextResolver: resolver)
            .evaluate(Attempt(exerciseID: exercise.id, reviewUnitID: unit.id, response: "؟", submittedAt: Date()), exercise: exercise)
        XCTAssertEqual(unavailable.outcome, .unavailable)
        XCTAssertEqual(unavailable.unavailableReason, .lowConfidence)
    }
}
