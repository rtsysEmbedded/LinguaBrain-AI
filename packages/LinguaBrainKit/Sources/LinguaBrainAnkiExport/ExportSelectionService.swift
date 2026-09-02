import Foundation
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainPersistence

public struct ExportSelectionService {
    public struct SelectionCriteria: Sendable {
        public var sourceGroup: CardSource?
        public var languagePair: (source: String?, target: String?)?
        public var deck: String?
        public var cardIDs: [String]?
        public var approvedOnly: Bool = true

        public init(
            sourceGroup: CardSource? = nil,
            languagePair: (source: String?, target: String?)? = nil,
            deck: String? = nil,
            cardIDs: [String]? = nil,
            approvedOnly: Bool = true
        ) {
            self.sourceGroup = sourceGroup
            self.languagePair = languagePair
            self.deck = deck
            self.cardIDs = cardIDs
            self.approvedOnly = approvedOnly
        }
    }

    public struct SelectionResult: Sendable {
        public let selectedBundles: [GeneratedCardBundle]
        public let sourceGroups: Set<CardSource>
        public let totalCards: Int
        public let criteria: SelectionCriteria
        public let provenanceTags: [ExportProvenanceTag]

        public init(
            selectedBundles: [GeneratedCardBundle],
            sourceGroups: Set<CardSource>,
            totalCards: Int,
            criteria: SelectionCriteria,
            provenanceTags: [ExportProvenanceTag] = []
        ) {
            self.selectedBundles = selectedBundles
            self.sourceGroups = sourceGroups
            self.totalCards = totalCards
            self.criteria = criteria
            self.provenanceTags = provenanceTags
        }
    }

    public struct ExportProvenanceTag: Sendable, Equatable {
        public let sourceGroup: CardSource
        public let cardIDs: [String]
        public let selectedCount: Int
        public let exclusions: [String]

        public init(
            sourceGroup: CardSource,
            cardIDs: [String] = [],
            selectedCount: Int = 0,
            exclusions: [String] = []
        ) {
            self.sourceGroup = sourceGroup
            self.cardIDs = cardIDs
            self.selectedCount = selectedCount
            self.exclusions = exclusions
        }
    }

    private let persistencePort: PersistencePort
    private let cancellation: ExportCancellation

    public init(
        persistencePort: PersistencePort,
        cancellation: ExportCancellation = ExportCancellation()
    ) {
        self.persistencePort = persistencePort
        self.cancellation = cancellation
    }

    public func select(criteria: SelectionCriteria) async throws -> SelectionResult {
        try await cancellation.checkCancellation()

        let allBundles = try await persistencePort.approvedBundles()

        let filteredBundles = filterBundles(allBundles, criteria: criteria)

        let selectedBundles = filterApproved(filteredBundles)

        let sourceGroups = Set(selectedBundles.map { $0.provenance.provider == "hermes" ? CardSource.generated : CardSource.imported })
        let provenanceTags = buildProvenanceTags(from: selectedBundles, criteria: criteria)

        return SelectionResult(
            selectedBundles: selectedBundles,
            sourceGroups: sourceGroups,
            totalCards: selectedBundles.count,
            criteria: criteria,
            provenanceTags: provenanceTags
        )
    }

    private func filterBundles(
        _ bundles: [GeneratedCardBundle],
        criteria: SelectionCriteria
    ) -> [GeneratedCardBundle] {
        return bundles.filter { bundle in
            if let cardIDs = criteria.cardIDs, !cardIDs.isEmpty {
                guard cardIDs.contains(bundle.identity.senseKey) else { return false }
            }

            if let sourceGroup = criteria.sourceGroup {
                let bundleSourceGroup = bundle.provenance.provider == "hermes" ? CardSource.generated : .imported
                guard bundleSourceGroup == sourceGroup else { return false }
            }

            if let languagePair = criteria.languagePair {
                if let source = languagePair.source {
                    guard bundle.identity.sourceLanguage == source else { return false }
                }
                if let target = languagePair.target {
                    guard bundle.identity.targetLanguage == target else { return false }
                }
            }

            return true
        }
    }

    private func filterApproved(_ bundles: [GeneratedCardBundle]) -> [GeneratedCardBundle] {
        return bundles.filter { bundle in
            bundle.approvalState != .rejected && bundle.approvalState != .pending
        }
    }

    private func buildProvenanceTags(
        from bundles: [GeneratedCardBundle],
        criteria: SelectionCriteria
    ) -> [ExportProvenanceTag] {
        var tags: [ExportProvenanceTag] = []

        let groupedBySource = Dictionary(grouping: bundles, by: { $0.provenance.provider })

        for (sourceGroup, sourceBundles) in groupedBySource {
            let cardIDs = sourceBundles.map { $0.identity.senseKey }
            let tag = ExportProvenanceTag(
                sourceGroup: CardSource(rawValue: sourceGroup) ?? .generated,
                cardIDs: cardIDs,
                selectedCount: sourceBundles.count
            )
            tags.append(tag)
        }

        return tags
    }

    public func selectAllApproved() async throws -> SelectionResult {
        let allBundles = try await persistencePort.approvedBundles()
        let approvedBundles = filterApproved(allBundles)

        let sourceGroups = Set(approvedBundles.map { $0.provenance.provider == "hermes" ? CardSource.generated : CardSource.imported })
        let provenanceTags = buildProvenanceTags(from: approvedBundles, criteria: SelectionCriteria())

        return SelectionResult(
            selectedBundles: approvedBundles,
            sourceGroups: sourceGroups,
            totalCards: approvedBundles.count,
            criteria: SelectionCriteria(),
            provenanceTags: provenanceTags
        )
    }

    public func cancel() {
        cancellation.cancel()
    }
}