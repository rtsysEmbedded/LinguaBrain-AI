import Foundation
import LinguaBrainAI
import LinguaBrainApplication
import LinguaBrainDomain

/// Everything one evaluation needs, copied from the main-actor settings and
/// store at the moment of evaluation.
struct PracticeEvaluationEnvironment: Sendable {
    let configuration: ProviderConfiguration
    let apiKey: String?
    let temperature: Double?
    let cards: PrototypeStorePracticeCards
    let templates: AIPromptCatalog.Templates

    /// Whether answers may be sent to the configured Text provider. This is
    /// the single rule used by the capability notice and by evaluation.
    @MainActor
    static func state(settings: PrototypeAISettings) -> PracticeCapabilityFacts.EvaluatorState {
        guard settings.textMode != .off, settings.protocolName == ProviderCatalog.bundled.defaultProtocol else { return .notConfigured }
        if settings.textMode == .cloud {
            guard settings.hasAPIKey else { return .notConfigured }
            guard settings.cloudConsent else { return .consentRequired }
        }
        return .ready
    }

    /// `nil` when answers may not be sent; nothing is sent in that case.
    @MainActor
    static func current(settings: PrototypeAISettings, store: PrototypeStore) -> PracticeEvaluationEnvironment? {
        guard state(settings: settings) == .ready,
              let mode = ProviderMode(rawValue: settings.textMode.rawValue) else { return nil }
        let profile = ProviderCatalog.bundled.requests.practiceEvaluation
        return PracticeEvaluationEnvironment(
            configuration: ProviderConfiguration(
                mode: mode,
                endpoint: settings.endpoint,
                protocolName: settings.protocolName,
                modelID: settings.modelID,
                apiKeyScope: CredentialScope.text,
                consentRequired: settings.textMode == .cloud,
                timeoutSeconds: profile.timeoutSeconds
            ),
            apiKey: try? settings.apiKey(),
            temperature: profile.temperature,
            cards: PrototypeStorePracticeCards(store: store),
            templates: AIPromptCatalog.bundled.templates
        )
    }

    enum CredentialScope {
        static let text = "text"
    }
}

/// Supplies a credential copied from the Keychain for one evaluation.
private struct SnapshotCredentialLoader: CredentialLoader {
    let key: String?
    func loadCredential(for scope: String) throws -> String? { key }
}

/// Evaluates practice answers with the configured Text provider. Settings,
/// credential, and consent are read for every evaluation, so a change in
/// Settings applies to the next answer; without a usable provider the result
/// is an explicit unavailable result and no request is made.
struct SettingsBackedPracticeEvaluator: PracticeEvaluator {
    static let notConfiguredVersion = "provider-not-configured"

    let skill: PracticeSkill
    let repository: any PracticeRepository
    let grammarContext: any GrammarEvaluationContextResolving
    let environment: @MainActor @Sendable () -> PracticeEvaluationEnvironment?

    func evaluate(_ attempt: Attempt, exercise: ExerciseInstance) async throws -> EvaluationResult {
        guard let environment = await environment() else {
            return .unavailable(
                reason: .providerUnavailable,
                evaluatorVersion: Self.notConfiguredVersion,
                attemptID: attempt.id,
                exerciseID: exercise.id,
                reviewUnitID: exercise.reviewUnit.id,
                sentenceRevision: exercise.reviewUnit.sentenceRevision
            )
        }
        let credentials = SnapshotCredentialLoader(key: environment.apiKey)
        switch skill {
        case .writing:
            let instructions = PromptTemplate.render(environment.templates.practiceWritingEvaluation, [
                "ruleIDs": PracticeEvaluationDecoder.ruleIDs.sorted().joined(separator: ", ")
            ])
            return try await WritingEvaluationProvider(
                configuration: environment.configuration,
                credentialLoader: credentials,
                options: PracticeChatOptions(instructions: instructions, temperature: environment.temperature),
                contextResolver: CardWritingContextResolver(cards: environment.cards)
            ).evaluate(attempt, exercise: exercise)
        case .grammar:
            return try await GrammarEvaluationProvider(
                transport: ChatGrammarEvaluationTransport(
                    configuration: environment.configuration,
                    credentialLoader: credentials,
                    options: PracticeChatOptions(instructions: environment.templates.practiceGrammarEvaluation, temperature: environment.temperature)
                ),
                contextResolver: grammarContext
            ).evaluate(attempt, exercise: exercise)
        case .listening:
            let locale = exercise.targetLanguage
            return try await ListeningEvaluationProvider(
                transport: ChatListeningEvaluationTransport(
                    configuration: environment.configuration,
                    credentialLoader: credentials,
                    options: PracticeChatOptions(instructions: environment.templates.practiceListeningEvaluation, temperature: environment.temperature)
                ),
                contextResolver: RepositoryListeningContextResolver(repository: repository) { sentence in
                    AppleSentencePlayback.checksum(for: sentence, locale: locale, voiceIdentifier: nil)
                }
            ).evaluate(attempt, exercise: exercise)
        case .speaking:
            return .unavailable(
                reason: .unsupported,
                evaluatorVersion: Self.notConfiguredVersion,
                attemptID: attempt.id,
                exerciseID: exercise.id,
                reviewUnitID: exercise.reviewUnit.id
            )
        }
    }
}

extension PracticeComposition {
    /// Production composition: GRDB repository, FSRS-6 scheduler, and
    /// provider-backed evaluation for writing, grammar, and listening.
    @MainActor
    static func live(
        repository: any PracticeRepository & PracticeProgressReading,
        settings: PrototypeAISettings,
        store: PrototypeStore,
        grammarContext: any GrammarEvaluationContextResolving
    ) -> PracticeComposition {
        let environment: @MainActor @Sendable () -> PracticeEvaluationEnvironment? = {
            PracticeEvaluationEnvironment.current(settings: settings, store: store)
        }
        let graded: [PracticeSkill] = [.writing, .grammar, .listening]
        let evaluators = Dictionary(uniqueKeysWithValues: graded.map { skill -> (PracticeSkill, any PracticeEvaluator) in
            (skill, SettingsBackedPracticeEvaluator(skill: skill, repository: repository, grammarContext: grammarContext, environment: environment))
        })
        return PracticeComposition(
            repository: repository,
            evaluator: PracticeEvaluatorRouter(evaluators: evaluators),
            clock: SystemPracticeClock(),
            scheduler: PracticeFSRS6Scheduler(),
            gradedSkills: Set(graded)
        )
    }
}
