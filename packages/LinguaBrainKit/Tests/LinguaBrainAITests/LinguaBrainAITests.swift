import XCTest
@testable import LinguaBrainDomain
@testable import LinguaBrainAI

final class LinguaBrainAITests: XCTestCase {

    func testProposalDecodingAcceptsGenerationV1() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "version": "generation-v1",
            "lemma": "Bank",
            "senses": [
                ["senseKey": "bank-n-finance", "partOfSpeech": "noun", "meaning": "financial institution",
                 "translation": "بانک", "level": "A1", "examples": []]
            ],
            "provenance": ["provider": "openai", "model": "gpt-4o-mini", "schemaVersion": "generation-v1"]
        ])
        let proposal = try ProposalDecoder().decode(from: data)
        XCTAssertEqual(proposal.lemma, "Bank")
        XCTAssertEqual(proposal.senses.count, 1)
        XCTAssertEqual(proposal.senses[0].senseKey, "bank-n-finance")
    }

    func testProposalDecodingRejectsUnsupportedVersion() {
        let data = try! JSONSerialization.data(withJSONObject: [
            "version": "generation-v99",
            "lemma": "Bank",
            "senses": [],
            "provenance": ["provider": "x", "model": "y"]
        ])
        XCTAssertThrowsError(try ProposalDecoder().decode(from: data)) { error in
            guard case ContractError.unsupportedVersion = error else {
                return XCTFail("expected unsupportedVersion, got \(error)")
            }
        }
    }

    func testValidatorRejectsUnsafeTextAndIncompleteSenses() throws {
        let validator = StrictProposalValidator()
        let safe = CardProposal(
            lemma: "Bank",
            senses: [LexicalSense(sourceLanguage: "",
                                  targetLanguage: "",
                                  lemma: "Bank", senseKey: "bank-n", partOfSpeech: "noun",
                                  meaning: "bank", translation: "بانک")],
            provenance: Provenance(provider: "x", model: "y")
        )
        XCTAssertTrue(validator.isValid(safe))

        let unsafeProposal = CardProposal(
            lemma: "Bank<script>alert(1)</script>",
            senses: [],
            provenance: Provenance(provider: "x", model: "y")
        )
        let issues = try validator.validate(unsafeProposal)
        XCTAssertTrue(issues.contains { $0 == "lemma contains unsafe text" })
        XCTAssertTrue(issues.contains { $0 == "proposal has no senses" })
    }

    func testIdentityCombinesAllDiscriminators() {
        let detector = DuplicateDetector()
        let sense = LexicalSense(sourceLanguage: "de", targetLanguage: "fa",
                                 lemma: "Bank", senseKey: "bank-n-finance", partOfSpeech: "noun",
                                 meaning: "financial institution", translation: "بانک")
        let finance = detector.identity(sourceLanguage: "de", targetLanguage: "fa", lemma: "Bank",
                                        sense: sense, direction: .recognition)
        let riverSense = LexicalSense(sourceLanguage: "de", targetLanguage: "fa",
                                      lemma: "Bank", senseKey: "bank-n-river", partOfSpeech: "noun",
                                      meaning: "river edge", translation: "کناره")
        let river = detector.identity(sourceLanguage: "de", targetLanguage: "fa", lemma: "Bank",
                                      sense: riverSense, direction: .recognition)
        XCTAssertNotEqual(finance, river)
        XCTAssertNotEqual(finance.compositeKey, river.compositeKey)
    }

    func testBundledFixtureDecodesAsValidProposal() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "card-proposal-valid", withExtension: "json", subdirectory: "Fixtures") else {
            return XCTFail("missing bundled fixture card-proposal-valid.json")
        }
        let data = try Data(contentsOf: url)
        let proposal = try ProposalDecoder().decode(from: data)
        XCTAssertEqual(proposal.lemma, "Bank")
        XCTAssertEqual(proposal.senses.first?.senseKey, "bank-n-finance")
        XCTAssertTrue(StrictProposalValidator().isValid(proposal))
    }

    func testBundledGenerationContractFixtureDeclaresStableFields() throws {
        let bundle = Bundle.module
        guard let url = bundle.url(forResource: "generation-contract-v1", withExtension: "json", subdirectory: "Fixtures") else {
            return XCTFail("missing bundled fixture generation-contract-v1.json")
        }
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["version"] as? String, "generation-v1")
        XCTAssertEqual((json["fields"] as? [String])?.isEmpty, false)
    }

    func testProvenanceCapturesGeneratorsAndSchema() {
        let provenance = Provenance(
            provider: "openai",
            model: "gpt-4o-mini",
            schemaVersion: "generation-v1",
            validatorVersion: "strict-1"
        )
        XCTAssertEqual(provenance.provider, "openai")
        XCTAssertEqual(provenance.schemaVersion, "generation-v1")
    }

    // MARK: - T019: LexicalSense initialization tests

    func testLexicalSenseInitializerWithAllFields() {
        let sense = LexicalSense(
            sourceLanguage: "de",
            targetLanguage: "fa",
            lemma: "Bank",
            senseKey: "bank-n-finance",
            partOfSpeech: "noun",
            meaning: "financial institution",
            examples: [
                Sentence(text: "Bank example", translation: "مثال بانک")
            ],
            translation: "بانک",
            level: "A1",
            qualifier: "formal",
            direction: .recognition
        )
        XCTAssertEqual(sense.sourceLanguage, "de")
        XCTAssertEqual(sense.targetLanguage, "fa")
        XCTAssertEqual(sense.lemma, "Bank")
        XCTAssertEqual(sense.senseKey, "bank-n-finance")
        XCTAssertEqual(sense.partOfSpeech, "noun")
        XCTAssertEqual(sense.meaning, "financial institution")
        XCTAssertEqual(sense.examples.count, 1)
        XCTAssertEqual(sense.examples[0].text, "Bank example")
        XCTAssertEqual(sense.examples[0].translation, "مثال بانک")
        XCTAssertEqual(sense.translation, "بانک")
        XCTAssertEqual(sense.level, "A1")
        XCTAssertEqual(sense.qualifier, "formal")
        XCTAssertEqual(sense.direction, .recognition)
    }

    func testLexicalSenseInitializerWithDefaults() {
        let sense = LexicalSense(
            sourceLanguage: "de",
            targetLanguage: "fa",
            lemma: "River",
            senseKey: "river-n",
            partOfSpeech: "noun",
            meaning: "flowing water",
            translation: "رودخانه"
        )
        XCTAssertEqual(sense.sourceLanguage, "de")
        XCTAssertEqual(sense.targetLanguage, "fa")
        XCTAssertEqual(sense.lemma, "River")
        XCTAssertEqual(sense.senseKey, "river-n")
        XCTAssertEqual(sense.examples, [])
        XCTAssertNil(sense.level)
        XCTAssertNil(sense.qualifier)
        XCTAssertEqual(sense.direction, .recognition)
    }

    // MARK: - T019: Map multi-sense proposals to LexicalSense

    func testMapProposalSensesCreatesGeneratedCardBundle() {
        let request = GenerationRequest(
            sourceLanguage: "en",
            targetLanguage: "es",
            level: "A1",
            count: 2,
            directions: [.recognition],
            mediaPreferences: MediaPreferences(audioEnabled: false, imageEnabled: false)
        )
        let proposal = CardProposal(
            lemma: "Bank",
            senses: [
                LexicalSense(
                    sourceLanguage: "en",
                    targetLanguage: "es",
                    lemma: "Bank",
                    senseKey: "bank-n-finance",
                    partOfSpeech: "noun",
                    meaning: "financial institution",
                    translation: "banco",
                    level: "A1"
                ),
                LexicalSense(
                    sourceLanguage: "en",
                    targetLanguage: "es",
                    lemma: "Bank",
                    senseKey: "bank-n-river",
                    partOfSpeech: "noun",
                    meaning: "river edge",
                    translation: "orilla",
                    level: "A2"
                )
            ],
            provenance: Provenance(provider: "test", model: "test-model", schemaVersion: "test-v1")
        )
        let bundle = mapProposalSenses(proposal, request: request, direction: .recognition)

        XCTAssertEqual(bundle.identity.lemma, "Bank")
        XCTAssertEqual(bundle.identity.sourceLanguage, "en")
        XCTAssertEqual(bundle.identity.targetLanguage, "es")
        XCTAssertEqual(bundle.senses.count, 2)
        XCTAssertEqual(bundle.senses[0].senseKey, "bank-n-finance")
        XCTAssertEqual(bundle.senses[1].senseKey, "bank-n-river")
        XCTAssertEqual(bundle.senses[0].sourceLanguage, "en")
        XCTAssertEqual(bundle.senses[0].targetLanguage, "es")
        XCTAssertEqual(bundle.senses[1].sourceLanguage, "en")
        XCTAssertEqual(bundle.senses[1].targetLanguage, "es")
        XCTAssertEqual(bundle.directions, [.recognition])
        XCTAssertEqual(bundle.approvalState, .pending)
    }
}
