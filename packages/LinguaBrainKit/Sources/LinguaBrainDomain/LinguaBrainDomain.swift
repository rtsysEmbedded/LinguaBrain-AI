import Foundation

// MARK: - Generation Request (T004, data-model.md)

public struct GenerationRequest: Equatable, Sendable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var level: String
    public var topic: String?
    public var items: [String]
    public var count: Int
    public var directions: [ReviewDirection]
    public var mediaPreferences: MediaPreferences
    public var ownerScope: String
    public var idempotencyKey: IdempotencyKey

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        level: String,
        topic: String? = nil,
        items: [String] = [],
        count: Int,
        directions: [ReviewDirection],
        mediaPreferences: MediaPreferences,
        ownerScope: String = "local",
        idempotencyKey: IdempotencyKey = .random()
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.level = level
        self.topic = topic
        self.items = items
        self.count = count
        self.directions = directions
        self.mediaPreferences = mediaPreferences
        self.ownerScope = ownerScope
        self.idempotencyKey = idempotencyKey
    }
}

public struct MediaPreferences: Equatable, Sendable {
    public var audioEnabled: Bool
    public var imageEnabled: Bool

    public init(audioEnabled: Bool, imageEnabled: Bool) {
        self.audioEnabled = audioEnabled
        self.imageEnabled = imageEnabled
    }
}

// MARK: - Review Direction

public enum ReviewDirection: String, CaseIterable, Codable, Sendable, Equatable {
    case recognition
    case recall
}

// MARK: - Idempotency (T004)

public struct IdempotencyKey: Hashable, Codable, Sendable, Equatable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func random() -> IdempotencyKey {
        IdempotencyKey(rawValue: UUID().uuidString)
    }
}

// MARK: - Generation Job (T004)

public enum GenerationJobStatus: String, Codable, Sendable, Equatable {
    case queued
    case running
    case waitingForApproval
    case approved
    case rejected
    case partial
    case cancelled
}

public struct GenerationJob: Equatable, Sendable {
    public var id: String
    public var request: GenerationRequest
    public var status: GenerationJobStatus
    public var stage: GenerationStage
    public var attempts: Int
    public var provider: String?
    public var model: String?
    public var schemaVersions: [String]
    public var errors: [String]
    public var cancellationRequested: Bool
    public var proposal: CardProposal?
    public var timestamps: [String: Date]

    public init(
        id: String,
        request: GenerationRequest,
        status: GenerationJobStatus = .queued,
        stage: GenerationStage = .queued,
        attempts: Int = 0,
        provider: String? = nil,
        model: String? = nil,
        schemaVersions: [String] = [],
        errors: [String] = [],
        cancellationRequested: Bool = false,
        proposal: CardProposal? = nil,
        timestamps: [String: Date] = [:]
    ) {
        self.id = id
        self.request = request
        self.status = status
        self.stage = stage
        self.attempts = attempts
        self.provider = provider
        self.model = model
        self.schemaVersions = schemaVersions
        self.errors = errors
        self.cancellationRequested = cancellationRequested
        self.proposal = proposal
        self.timestamps = timestamps
    }
}

public enum GenerationStage: String, Codable, Sendable, Equatable {
    case queued
    case requestingProvider
    case validating
    case awaitingApproval
    case persisting
    case completed
    case failed
    case cancelled
}

// MARK: - Lexical Sense and Sentence (T008, data-model.md)

public struct LexicalSense: Equatable, Sendable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var lemma: String
    public var senseKey: String
    public var partOfSpeech: String
    public var meaning: String
    public var examples: [Sentence]
    public var translation: String
    public var level: String?
    public var qualifier: String?
    public var direction: ReviewDirection

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        lemma: String,
        senseKey: String,
        partOfSpeech: String,
        meaning: String,
        examples: [Sentence] = [],
        translation: String,
        level: String? = nil,
        qualifier: String? = nil,
        direction: ReviewDirection = .recognition
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.lemma = lemma
        self.senseKey = senseKey
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.examples = examples
        self.translation = translation
        self.level = level
        self.qualifier = qualifier
        self.direction = direction
    }
}

// MARK: - Sense Mapping Helper (T019)

/// Maps multi-sense proposals to LexicalSense with proper language-pair and direction context.
public func mapProposalSenses(
    _ proposal: CardProposal,
    request: GenerationRequest,
    direction: ReviewDirection
) -> GeneratedCardBundle {
    let senses = proposal.senses.map { sense in
        LexicalSense(
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage,
            lemma: sense.lemma,
            senseKey: sense.senseKey,
            partOfSpeech: sense.partOfSpeech,
            meaning: sense.meaning,
            examples: sense.examples,
            translation: sense.translation,
            level: sense.level,
            qualifier: sense.qualifier,
            direction: direction
        )
    }
    
    let bundleIdentity = CardIdentity(
        sourceLanguage: request.sourceLanguage,
        targetLanguage: request.targetLanguage,
        lemma: proposal.lemma,
        senseKey: senses.first?.senseKey ?? "",
        partOfSpeech: senses.first?.partOfSpeech ?? "",
        direction: direction
    )
    
    return GeneratedCardBundle(
        identity: bundleIdentity,
        senses: senses,
        directions: [direction],
        mediaAssets: [],
        approvalState: .pending,
        provenance: proposal.provenance
    )
}

public struct Sentence: Equatable, Sendable {
    public var text: String
    public var translation: String

    public init(text: String, translation: String) {
        self.text = text
        self.translation = translation
    }
}

// MARK: - Media (data-model.md)

public struct MediaAsset: Equatable, Sendable {
    public var kind: MediaKind
    public var locale: String
    public var checksum: String
    public var fileSize: Int?
    public var provider: String
    public var model: String
    public var generatedAt: Date
    public var consentContext: String?
    public var cacheReference: String?
    public var availability: MediaAvailability
    public var fallbackReason: String?

    public init(
        kind: MediaKind,
        locale: String,
        checksum: String,
        fileSize: Int? = nil,
        provider: String,
        model: String,
        generatedAt: Date = Date(),
        consentContext: String? = nil,
        cacheReference: String? = nil,
        availability: MediaAvailability = .available,
        fallbackReason: String? = nil
    ) {
        self.kind = kind
        self.locale = locale
        self.checksum = checksum
        self.fileSize = fileSize
        self.provider = provider
        self.model = model
        self.generatedAt = generatedAt
        self.consentContext = consentContext
        self.cacheReference = cacheReference
        self.availability = availability
        self.fallbackReason = fallbackReason
    }
}

public enum MediaKind: String, Codable, Sendable, Equatable {
    case audio
    case image
}

public enum MediaAvailability: String, Codable, Sendable, Equatable {
    case available
    case missing
}

// MARK: - Provenance (T005, FR-015)

public struct Provenance: Equatable, Sendable {
    public var provider: String
    public var model: String
    public var promptVersion: String?
    public var schemaVersion: String?
    public var validatorVersion: String?
    public var mediaProviders: [MediaKind: String]
    public var consent: String?
    public var generatedAt: Date

    public init(
        provider: String,
        model: String,
        promptVersion: String? = nil,
        schemaVersion: String? = nil,
        validatorVersion: String? = nil,
        mediaProviders: [MediaKind: String] = [:],
        consent: String? = nil,
        generatedAt: Date = Date()
    ) {
        self.provider = provider
        self.model = model
        self.promptVersion = promptVersion
        self.schemaVersion = schemaVersion
        self.validatorVersion = validatorVersion
        self.mediaProviders = mediaProviders
        self.consent = consent
        self.generatedAt = generatedAt
    }
}

// MARK: - Proposal (T005, FR-002)

public struct CardProposal: Equatable, Sendable {
    public var lemma: String
    public var senses: [LexicalSense]
    public var warnings: [String]
    public var validationIssues: [String]
    public var sourceLanguage: String
    public var targetLanguage: String
    public var provenance: Provenance

    public init(
        lemma: String,
        senses: [LexicalSense],
        warnings: [String] = [],
        validationIssues: [String] = [],
        sourceLanguage: String = "",
        targetLanguage: String = "",
        provenance: Provenance
    ) {
        self.lemma = lemma
        self.senses = senses
        self.warnings = warnings
        self.validationIssues = validationIssues
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.provenance = provenance
    }

    public var isValid: Bool { validationIssues.isEmpty }
}

// MARK: - Approved Bundle (T005, FR-007, data-model.md)

public struct GeneratedCardBundle: Equatable, Sendable {
    public var identity: CardIdentity
    public var senses: [LexicalSense]
    public var directions: [ReviewDirection]
    public var mediaAssets: [MediaAsset]
    public var approvalState: ApprovalState
    public var provenance: Provenance

    public init(
        identity: CardIdentity,
        senses: [LexicalSense],
        directions: [ReviewDirection] = ReviewDirection.allCases,
        mediaAssets: [MediaAsset] = [],
        approvalState: ApprovalState = .approved,
        provenance: Provenance
    ) {
        self.identity = identity
        self.senses = senses
        self.directions = directions
        self.mediaAssets = mediaAssets
        self.approvalState = approvalState
        self.provenance = provenance
    }
}

public enum ApprovalState: String, Codable, Sendable, Equatable {
    case pending
    case approved
    case rejected
}

// MARK: - Export (T025, FR-012)

/// Represents whether a card bundle was generated by Hermes or imported from Anki.
public enum CardSource: String, Codable, Sendable, Equatable {
    case generated
    case imported
}

/// Export selection model separating generated vs imported cards.
public struct ExportManifest: Equatable, Sendable {
    public var selectedBundles: [GeneratedCardBundle]
    public var bundledMedia: [MediaAsset]
    public var exportFormat: ExportFormat
    public var provenance: Provenance
    public var exportedAt: Date

    public enum ExportFormat: String, Codable, Sendable, Equatable {
        case tsv
        case apkg
    }

    public init(
        selectedBundles: [GeneratedCardBundle],
        bundledMedia: [MediaAsset] = [],
        exportFormat: ExportFormat = .tsv,
        provenance: Provenance,
        exportedAt: Date = Date()
    ) {
        self.selectedBundles = selectedBundles
        self.bundledMedia = bundledMedia
        self.exportFormat = exportFormat
        self.provenance = provenance
        self.exportedAt = exportedAt
    }
}

// MARK: - Identity and Duplicate Detection (T008, FR-004/005, data-model.md)

public struct CardIdentity: Hashable, Codable, Sendable, Equatable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var lemma: String
    public var senseKey: String
    public var partOfSpeech: String
    public var direction: ReviewDirection

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        lemma: String,
        senseKey: String,
        partOfSpeech: String,
        direction: ReviewDirection
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.lemma = lemma
        self.senseKey = senseKey
        self.partOfSpeech = partOfSpeech
        self.direction = direction
    }

    /// Stable across retries and exports; independent senses and directions have independent identities.
    public var compositeKey: String {
        [sourceLanguage, targetLanguage, lemma, senseKey, partOfSpeech, direction.rawValue]
            .joined(separator: "|")
    }
}

public struct DuplicateDetector {
    public init() {}

    /// Detects duplicates using language pair + lemma + sense + part-of-speech + direction (FR-005).
    public func identity(
        sourceLanguage: String,
        targetLanguage: String,
        lemma: String,
        sense: LexicalSense,
        direction: ReviewDirection
    ) -> CardIdentity {
        CardIdentity(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            lemma: lemma,
            senseKey: sense.senseKey,
            partOfSpeech: sense.partOfSpeech,
            direction: direction
        )
    }
}
