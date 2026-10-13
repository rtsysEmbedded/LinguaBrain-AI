import Foundation
import LinguaBrainDomain

/// The portable export contains learner-owned practice evidence only. Provider
/// credentials, private audio bytes and database locations are deliberately not
/// part of this value.
public struct PracticeDataExport: Codable, Sendable, Equatable {
    public let learnerID: String
    public let sentences: [Sentence]
    public let attempts: [Attempt]
    public let learningEvents: [PracticeLearningEvent]

    public init(learnerID: String, sentences: [Sentence] = [], attempts: [Attempt] = [], learningEvents: [PracticeLearningEvent] = []) {
        self.learnerID = learnerID
        self.sentences = sentences
        self.attempts = attempts
        self.learningEvents = learningEvents
    }
}

public protocol PracticeDataOwnershipStore: Sendable {
    func exportPracticeData(learnerID: String) async throws -> PracticeDataExport
    func deletePrivatePracticeData(learnerID: String) async throws
    func isProviderConsentGranted(learnerID: String) async -> Bool
}

public enum PracticeDataOwnershipError: Error, Equatable, Sendable {
    case consentRequired
    case deletionFailed
}

/// Application-owned privacy boundary. Views receive results from this service
/// and never reach into a repository, media store, or provider configuration.
public struct PracticeDataOwnershipService: Sendable {
    private let store: any PracticeDataOwnershipStore

    public init(store: any PracticeDataOwnershipStore) { self.store = store }

    public func export(learnerID: String) async throws -> PracticeDataExport {
        try await store.exportPracticeData(learnerID: learnerID)
    }

    public func deletePrivateData(learnerID: String) async throws {
        try await store.deletePrivatePracticeData(learnerID: learnerID)
    }

    public func canRequestProviderData(learnerID: String) async -> Bool {
        await store.isProviderConsentGranted(learnerID: learnerID)
    }

    public func requireProviderConsent(learnerID: String) async throws {
        guard await canRequestProviderData(learnerID: learnerID) else {
            throw PracticeDataOwnershipError.consentRequired
        }
    }
}
