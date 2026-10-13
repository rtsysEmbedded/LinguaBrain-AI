import Foundation
import LinguaBrainDomain

public enum SentenceLearningError: Error, Equatable, Sendable {
    case invalidContent
    case revalidationRequired
}

public enum SentenceLearningDecision: String, Codable, Sendable, Equatable {
    case accepted
    case duplicate
    case declined
}

public struct SentenceLearningRequest: Codable, Sendable, Equatable {
    public let learnerID: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let meaningKey: String
    public let attemptID: UUID
    public let originalResponse: String
    public let minimalCorrection: String
    public let naturalVariant: String?
    public let validation: SentenceValidationStatus
    public let provenance: Provenance?
    public let ruleReferences: [RuleReference]
    public let lexicalReferences: [LexicalReference]

    public init(learnerID: String, sourceLanguage: String, targetLanguage: String, meaningKey: String, attemptID: UUID, originalResponse: String, minimalCorrection: String, naturalVariant: String? = nil, validation: SentenceValidationStatus = .validated, provenance: Provenance? = nil, ruleReferences: [RuleReference] = [], lexicalReferences: [LexicalReference] = []) {
        self.learnerID = learnerID; self.sourceLanguage = sourceLanguage; self.targetLanguage = targetLanguage; self.meaningKey = meaningKey; self.attemptID = attemptID; self.originalResponse = originalResponse; self.minimalCorrection = minimalCorrection; self.naturalVariant = naturalVariant; self.validation = validation; self.provenance = provenance; self.ruleReferences = ruleReferences; self.lexicalReferences = lexicalReferences
    }
}

public struct SentenceLearningResult: Codable, Sendable, Equatable {
    public let decision: SentenceLearningDecision
    public let sentence: Sentence?
    public let revision: Int?
    public let sourceAttemptID: UUID

    public init(decision: SentenceLearningDecision, sentence: Sentence?, revision: Int?, sourceAttemptID: UUID) {
        self.decision = decision; self.sentence = sentence; self.revision = revision; self.sourceAttemptID = sourceAttemptID
    }
}

/// Owns acceptance of validated correction proposals. The learner response is
/// copied into immutable sentence evidence and is never replaced by a later
/// correction. Sentence identity includes learner and meaning scope, so a
/// private sentence cannot leak to another learner or objective.
public actor SentenceLearningService {
    private let repository: any PracticeRepository

    public init(repository: any PracticeRepository) { self.repository = repository }

    public func accept(_ request: SentenceLearningRequest) async throws -> SentenceLearningResult {
        guard !request.learnerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.meaningKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.originalResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.minimalCorrection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.validation == .validated else { throw SentenceLearningError.invalidContent }

        let id = scopedSentenceID(learnerID: request.learnerID, source: request.sourceLanguage, target: request.targetLanguage, meaning: request.meaningKey)
        let existing = try await repository.sentence(id: id, revision: 1)
        if let existing, existing.text == request.minimalCorrection, existing.translation == request.meaningKey {
            return SentenceLearningResult(decision: .duplicate, sentence: existing, revision: existing.revision, sourceAttemptID: request.attemptID)
        }

        let revision = existing.map { $0.revision + 1 } ?? 1
        let sentence = Sentence(id: id, revision: revision, text: request.minimalCorrection, translation: request.meaningKey, originalLearnerResponse: request.originalResponse, minimalCorrection: request.minimalCorrection, naturalVariant: request.naturalVariant, validation: request.validation, provenance: request.provenance, ruleReferences: request.ruleReferences, lexicalReferences: request.lexicalReferences)
        try await repository.transaction { try await repository.saveSentence(sentence) }
        return SentenceLearningResult(decision: existing == nil ? .accepted : .accepted, sentence: sentence, revision: revision, sourceAttemptID: request.attemptID)
    }

    public func decline(attemptID: UUID) -> SentenceLearningResult {
        SentenceLearningResult(decision: .declined, sentence: nil, revision: nil, sourceAttemptID: attemptID)
    }

    public func editAcceptedSentence(_ sentence: Sentence, text: String, revalidated: Bool, sourceAttemptID: UUID) async throws -> SentenceLearningResult {
        guard revalidated else { throw SentenceLearningError.revalidationRequired }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SentenceLearningError.invalidContent }
        let edited = Sentence(id: sentence.id, revision: sentence.revision + 1, text: trimmed, translation: sentence.translation, originalLearnerResponse: sentence.originalLearnerResponse, minimalCorrection: trimmed, naturalVariant: sentence.naturalVariant, validation: .validated, provenance: sentence.provenance, ruleReferences: sentence.ruleReferences, lexicalReferences: sentence.lexicalReferences)
        try await repository.transaction { try await repository.saveSentence(edited) }
        return SentenceLearningResult(decision: .accepted, sentence: edited, revision: edited.revision, sourceAttemptID: sourceAttemptID)
    }

    private func scopedSentenceID(learnerID: String, source: String, target: String, meaning: String) -> UUID {
        let value = [learnerID, source, target, meaning].joined(separator: "|")
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 0x100000001b3 }
        var bytes = withUnsafeBytes(of: hash.bigEndian, Array.init) + withUnsafeBytes(of: (~hash).bigEndian, Array.init)
        bytes += bytes.prefix(8)
        bytes[6] = (bytes[6] & 0x0f) | 0x50; bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
