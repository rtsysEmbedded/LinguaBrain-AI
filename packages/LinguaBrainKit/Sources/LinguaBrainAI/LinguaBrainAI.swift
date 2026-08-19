import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

// MARK: - Versioned Contracts (T002, T007)

public struct ContractVersion: Equatable, Sendable {
    public static let generationV1 = ContractVersion("generation", 1)
    public static let exportV1 = ContractVersion("export", 1)

    public let name: String
    public let number: Int

    public init(_ name: String, _ number: Int) {
        self.name = name
        self.number = number
    }

    public var identifier: String { "\(name)-v\(number)" }
}

public enum ContractError: Error, Equatable, Sendable {
    case unsupportedVersion(String)
    case malformedProposal(String)
}

// MARK: - Proposal Decoding (T007, FR-002)

public struct ProposalJSONWireModel: Codable, Sendable {
    public var version: String
    public var lemma: String
    public var senses: [SenseWireModel]
    public var provenance: ProvenanceWireModel

    public init(version: String, lemma: String, senses: [SenseWireModel], provenance: ProvenanceWireModel) {
        self.version = version
        self.lemma = lemma
        self.senses = senses
        self.provenance = provenance
    }
}

public struct SenseWireModel: Codable, Sendable {
    public var senseKey: String
    public var partOfSpeech: String
    public var meaning: String
    public var translation: String
    public var level: String?
    public var qualifier: String?
    public var examples: [SentenceWireModel]

    public init(
        senseKey: String, partOfSpeech: String, meaning: String, translation: String,
        level: String? = nil, qualifier: String? = nil, examples: [SentenceWireModel] = []
    ) {
        self.senseKey = senseKey
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.translation = translation
        self.level = level
        self.qualifier = qualifier
        self.examples = examples
    }
}

public struct SentenceWireModel: Codable, Sendable {
    public var text: String
    public var translation: String

    public init(text: String, translation: String) {
        self.text = text
        self.translation = translation
    }
}

public struct ProvenanceWireModel: Codable, Sendable {
    public var provider: String
    public var model: String
    public var schemaVersion: String?
    public var validatorVersion: String?

    public init(provider: String, model: String, schemaVersion: String? = nil, validatorVersion: String? = nil) {
        self.provider = provider
        self.model = model
        self.schemaVersion = schemaVersion
        self.validatorVersion = validatorVersion
    }
}

public struct ProposalDecoder {
    public init() {}

    /// Decodes a versioned proposal and rejects unsupported versions (T007).
    public func decode(from data: Data) throws -> CardProposal {
        let wire = try JSONDecoder().decode(ProposalJSONWireModel.self, from: data)
        let fallback = ContractVersion.generationV1
        guard wire.version == fallback.identifier else {
            throw ContractError.unsupportedVersion(wire.version)
        }

        let senses = wire.senses.map { s in
            LexicalSense(
                sourceLanguage: "",
                targetLanguage: "",
                lemma: wire.lemma,
                senseKey: s.senseKey,
                partOfSpeech: s.partOfSpeech,
                meaning: s.meaning,
                examples: s.examples.map { Sentence(text: $0.text, translation: $0.translation) },
                translation: s.translation,
                level: s.level,
                qualifier: s.qualifier
            )
        }

        return CardProposal(
            lemma: wire.lemma,
            senses: senses,
            provenance: Provenance(
                provider: wire.provenance.provider,
                model: wire.provenance.model,
                schemaVersion: wire.provenance.schemaVersion,
                validatorVersion: wire.provenance.validatorVersion
            )
        )
    }
}

// MARK: - Schema Validation (T007, T010, FR-003)

/// Applies structural and safety validation outside the model boundary (FR-003).
public struct StrictProposalValidator: ProposalValidator {
    public init() {}

    public func validate(_ proposal: CardProposal) throws -> [String] {
        var issues: [String] = []

        // Safety check: reject script/HTML injection in text fields.
        if unsafe(proposal.lemma) {
            issues.append("lemma contains unsafe text")
        }
        if proposal.senses.isEmpty {
            issues.append("proposal has no senses")
        }
        for sense in proposal.senses {
            if sense.senseKey.isEmpty {
                issues.append("sense lacks sense_key")
            }
            if sense.partOfSpeech.isEmpty {
                issues.append("sense \(sense.senseKey) lacks part_of_speech")
            }
            if sense.translation.isEmpty {
                issues.append("sense \(sense.senseKey) lacks translation")
            }
            if unsafe(sense.meaning) {
                issues.append("sense \(sense.senseKey) contains unsafe text")
            }
            for example in sense.examples {
                if example.text.isEmpty || example.translation.isEmpty {
                    issues.append("sense \(sense.senseKey) has incomplete example")
                }
            }
        }
        return issues
    }

    public func isValid(_ proposal: CardProposal) -> Bool {
        (try? validate(proposal).isEmpty) ?? false
    }

    private func unsafe(_ text: String) -> Bool {
        text.localizedCaseInsensitiveContains("<script")
            || text.localizedCaseInsensitiveContains("javascript:")
            || text.contains("&lt;")
    }
}
