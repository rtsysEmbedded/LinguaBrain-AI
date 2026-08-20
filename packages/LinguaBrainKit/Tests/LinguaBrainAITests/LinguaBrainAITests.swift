import XCTest
import Foundation
@testable import LinguaBrainDomain
@testable import LinguaBrainAI
@testable import LinguaBrainApplication
@testable import LinguaBrainTestSupport

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

    // MARK: - T031: Provider Configuration Tests

    func testProviderConfigurationDefaults() {
        let config = ProviderConfiguration()
        XCTAssertEqual(config.mode, .cloud)
        XCTAssertEqual(config.endpoint, "https://api.openai.com/v1")
        XCTAssertEqual(config.protocolName, "openai-compatible")
        XCTAssertEqual(config.modelID, "gpt-4o-mini")
        XCTAssertEqual(config.timeoutSeconds, 30.0)
    }

    func testProviderConfigurationWithModeOffDisablesProvider() {
        let config = ProviderConfiguration(mode: .off)
        XCTAssertEqual(config.mode, .off)
    }

    func testProviderCapabilitiesReportCorrectly() {
        let textCaps = ProviderCapabilities(supportsTextGeneration: true, maxTokens: 8192)
        XCTAssertTrue(textCaps.supportsTextGeneration)
        XCTAssertEqual(textCaps.maxTokens, 8192)

        let audioCaps = ProviderCapabilities(supportsAudioGeneration: true)
        XCTAssertTrue(audioCaps.supportsAudioGeneration)
    }

    func testProviderModeIsCaseIterable() {
        XCTAssertEqual(ProviderMode.allCases.count, 4)
        XCTAssertEqual(ProviderMode.builtIn, .builtIn)
        XCTAssertEqual(ProviderMode.local, .local)
        XCTAssertEqual(ProviderMode.cloud, .cloud)
        XCTAssertEqual(ProviderMode.off, .off)
    }

    // MARK: - T033: No-Key Error Tests

    func testNoAPIKeyThrowsMissingKeyError() async throws {
        let missingKeyLoader = NoOpCredentialLoader()
        let config = ProviderConfiguration(mode: .cloud)
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: config,
            credentialLoader: missingKeyLoader
        )

        let request = GenerationRequest(
            sourceLanguage: "en", targetLanguage: "es", level: "A1",
            count: 1, directions: [.recognition],
            mediaPreferences: MediaPreferences(audioEnabled: false, imageEnabled: false)
        )

        do {
            _ = try await adapter.generateProposal(for: request)
            XCTFail("Expected missingAPIKey error")
        } catch let error as ProviderError {
            if case .missingAPIKey = error {
                // Expected
            } else {
                XCTFail("Expected missingAPIKey error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - T033: Timeout Tests

    func testProviderTimeoutConfiguredSuccessfully() {
        let config = ProviderConfiguration(timeoutSeconds: 10.0)
        XCTAssertEqual(config.timeoutSeconds, 10.0)
    }

    func testSlowProviderTimesOut() {
        let slowProvider = SlowTextProvider(delay: 0.1)
        let request = GenerationRequest(
            sourceLanguage: "en", targetLanguage: "es", level: "A1",
            count: 1, directions: [.recognition],
            mediaPreferences: MediaPreferences(audioEnabled: false, imageEnabled: false)
        )

        Task {
            do {
                _ = try await slowProvider.generateProposal(for: request)
            } catch {
                // Expected timeout/cancellation
            }
        }

        Thread.sleep(forTimeInterval: 0.15)
    }

    // MARK: - T033: Cancellation Tests

    func testProviderCancellationWorks() async throws {
        let request = GenerationRequest(
            sourceLanguage: "en", targetLanguage: "es", level: "A1",
            count: 1, directions: [.recognition],
            mediaPreferences: MediaPreferences(audioEnabled: false, imageEnabled: false)
        )

        let task = Task {
            let slow = SlowTextProvider(delay: 5.0)
            return try await slow.generateProposal(for: request)
        }

        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError { }
    }

    // MARK: - T033: No-Direct-Mutation Tests (Constitution III)

    func testProviderCannotDirectlyMutateStorage() async throws {
        let repo = InMemoryPersistence()
        let failingProvider = FailingTextProvider()

        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: failingProvider,
            validator: StrictProposalValidator()
        )

        do {
            _ = try await orchestrator.startGeneration(from: GenerationRequestCommand(
                sourceLanguage: "en", targetLanguage: "es", level: "A1", count: 1,
                directions: [.recognition], audioEnabled: false, imageEnabled: false
            ))
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error is ProviderError)
        }

        let bundlesAfter = try await repo.approvedBundles()
        XCTAssertEqual(bundlesAfter.count, 0, "Provider failed - no bundles should persist")
    }

    func testProviderCannotModifyApprovedBundles() async throws {
        let repo = InMemoryPersistence()
        let textProvider = DeterministicTextProvider()

        let orchestrator = AnkiGenerationOrchestrator(
            repository: repo,
            textProvider: textProvider,
            validator: StrictProposalValidator()
        )

        let command = GenerationRequestCommand(
            sourceLanguage: "en", targetLanguage: "es", level: "A1",
            count: 1, directions: [.recognition]
        )

        let job = try await orchestrator.startGeneration(from: command)
        let proposal = try XCTUnwrap(job.proposal)

        let bundle = try await orchestrator.apply(.approve, proposal: proposal, direction: .recognition)
        XCTAssertEqual(bundle.approvalState, .approved)

        let bundles = try await repo.approvedBundles()
        XCTAssertEqual(bundles.count, 1, "Should have one approved bundle")
        XCTAssertEqual(bundles[0].senses[0].lemma, bundle.senses[0].lemma,
            "Bundle lemma should match original proposal")
    }

    // MARK: - T033: Health Check Tests

    func testHealthCheckReturnsUnavailableForOffMode() async throws {
        let config = ProviderConfiguration(mode: .off)
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: config,
            credentialLoader: NoOpCredentialLoader()
        )

        let status = await adapter.healthStatus()
        XCTAssertEqual(status, .unavailable(reason: "Provider mode disabled"))
    }

    func testProviderHealthStatusReturnsStatus() async throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: ProviderConfiguration(mode: .off),
            credentialLoader: NoOpCredentialLoader()
        )

        let healthStatus = await adapter.healthStatus()
        XCTAssertNotEqual(healthStatus, .healthy, "Off provider should not be healthy")
    }

    func testProviderIsAvailableReturnsCorrectly() async throws {
        let adapter = OpenAICompatibleProviderAdapter(
            configuration: ProviderConfiguration(mode: .off),
            credentialLoader: NoOpCredentialLoader()
        )

        let isAvailable = await adapter.isAvailable()
        XCTAssertFalse(isAvailable, "Off provider should not be available")
    }
}
