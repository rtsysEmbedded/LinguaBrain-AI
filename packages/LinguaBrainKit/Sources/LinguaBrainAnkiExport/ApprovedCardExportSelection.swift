import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

public protocol ApprovedCardSelectionPort: Sendable {
    func fetchApprovedCards(identities: [CardIdentity]) async throws -> [GeneratedCardBundle]
    func fetchAllApprovedBundles() async throws -> [GeneratedCardBundle]
    func filterApprovedCards(
        sourceGroup: CardSource?,
        languagePair: (source: String?, target: String?)?,
        deck: String?,
        cardIDs: [String]?
    ) async throws -> [GeneratedCardBundle]
}

public struct ApprovedCardExportSelection {
    private let persistencePort: PersistencePort
    private let cancellation: ExportCancellation

    public init(
        persistencePort: PersistencePort,
        cancellation: ExportCancellation = ExportCancellation()
    ) {
        self.persistencePort = persistencePort
        self.cancellation = cancellation
    }

    public func selectCards(forExport identities: [CardIdentity]) async throws -> ExportSelection {
        try await cancellation.checkCancellation()
        
        let bundles = try await persistencePort.approvedBundles()
            .filter { bundle in
                identities.contains(bundle.identity)
            }
        
        let selectedBundles = try await filterRejectedAndMutate(bundles)
        
        return ExportSelection(
            selectedBundles: selectedBundles,
            sourceGroups: Set(selectedBundles.map { $0.provenance.provider }),
            totalCards: selectedBundles.count
        )
    }

    public func selectAllApprovedCards() async throws -> ExportSelection {
        try await cancellation.checkCancellation()
        
        let bundles = try await persistencePort.approvedBundles()
        
        let selectedBundles = try await filterRejectedAndMutate(bundles)
        
        return ExportSelection(
            selectedBundles: selectedBundles,
            sourceGroups: Set(selectedBundles.map { $0.provenance.provider }),
            totalCards: selectedBundles.count
        )
    }

    public func selectCards(
        sourceGroup: CardSource? = nil,
        languagePair: (source: String?, target: String?)? = nil,
        deck: String? = nil,
        cardIDs: [String]? = nil
    ) async throws -> ExportSelection {
        try await cancellation.checkCancellation()
        
        let bundles = try await filterApprovedBundles(
            sourceGroup: sourceGroup,
            languagePair: languagePair,
            deck: deck,
            cardIDs: cardIDs
        )
        
        let selectedBundles = try await filterRejectedAndMutate(bundles)
        
        return ExportSelection(
            selectedBundles: selectedBundles,
            sourceGroups: Set(bundles.map { $0.provenance.provider }),
            totalCards: selectedBundles.count
        )
    }

    private func filterRejectedAndMutate(_ bundles: [GeneratedCardBundle]) async throws -> [GeneratedCardBundle] {
        return bundles.filter { bundle in
            bundle.approvalState != .rejected && bundle.approvalState != .pending
        }
    }

    private func filterApprovedBundles(
        sourceGroup: CardSource?,
        languagePair: (source: String?, target: String?)?,
        deck: String?,
        cardIDs: [String]?
    ) async throws -> [GeneratedCardBundle] {
        var bundles = try await persistencePort.approvedBundles()
        
        if let sourceGroup = sourceGroup {
            bundles = bundles.filter { bundle in
                // Filter by source - generated vs imported
                true // Placeholder - actual filtering depends on provenance
            }
        }
        
        if let languagePair = languagePair {
            if let source = languagePair.source {
                bundles = bundles.filter { $0.identity.sourceLanguage == source }
            }
            if let target = languagePair.target {
                bundles = bundles.filter { $0.identity.targetLanguage == target }
            }
        }
        
        if let deck = deck {
            // Deck filtering would be applied based on card properties
            // Placeholder for now
        }
        
        if let cardIDs = cardIDs, !cardIDs.isEmpty {
            bundles = bundles.filter { bundle in
                cardIDs.contains(bundle.identity.senseKey)
            }
        }
        
        return bundles
    }

    public func cancel() {
        cancellation.cancel()
    }
}

public struct ExportSelection: Sendable {
    public let selectedBundles: [GeneratedCardBundle]
    public let sourceGroups: Set<String>
    public let totalCards: Int
    public let selectionTimestamp: Date

    public init(
        selectedBundles: [GeneratedCardBundle],
        sourceGroups: Set<String>,
        totalCards: Int,
        selectionTimestamp: Date = Date()
    ) {
        self.selectedBundles = selectedBundles
        self.sourceGroups = sourceGroups
        self.totalCards = totalCards
        self.selectionTimestamp = selectionTimestamp
    }
}

public enum ExportSelectionError: Error, Equatable, Sendable {
    case noApprovedCards
    case invalidFilter(reason: String)
    case cancellationRequested
}

extension ExportSelectionError {
    public var localizedDescription: String {
        switch self {
        case .noApprovedCards:
            return "No approved cards available for export"
        case .invalidFilter(let reason):
            return "Invalid selection filter: \(reason)"
        case .cancellationRequested:
            return "Export selection cancelled"
        }
    }
}
