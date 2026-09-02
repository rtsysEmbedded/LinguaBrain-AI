import Foundation
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainPersistence
import LinguaBrainMedia

public class AnkiExportApplicationService {
    private let selectionService: ApprovedCardExportSelection
    private let workspace: ExportWorkspacePort
    private let mediaResolver: OwnedMediaResolver
    private let collectionBuilder: CollectionBuilderPort
    private let packageWriter: AnkiPackageWriter
    private let validator: AnkiPackageValidator
    private let configuration: AnkiExportConfiguration
    private let cancellation: ExportCancellation

    public protocol CollectionBuilderPort: Sendable {
        func buildCollection(from bundles: [GeneratedCardBundle], deckID: Int64) async throws -> URL
    }

    public init(
        selectionService: ApprovedCardExportSelection,
        workspace: ExportWorkspacePort,
        mediaResolver: OwnedMediaResolver,
        collectionBuilder: CollectionBuilderPort,
        configuration: AnkiExportConfiguration = AnkiExportConfiguration(),
        validator: AnkiPackageValidator = AnkiPackageValidator()
    ) {
        self.selectionService = selectionService
        self.workspace = workspace
        self.mediaResolver = mediaResolver
        self.collectionBuilder = collectionBuilder
        self.packageWriter = AnkiPackageWriter(config: configuration)
        self.validator = validator
        self.configuration = configuration
        self.cancellation = ExportCancellation()
    }

    public func exportApprovedCards(
        selection: ExportSelection,
        destination: URL,
        progressHandler: ((ExportProgress) -> Void)? = nil
    ) async throws -> AnkiExportResult {
        try await cancellation.checkCancellation()

        let startTime = Date()

        progressHandler?(ExportProgress(
            cardsExported: 0,
            mediaBytesExported: 0,
            totalCards: selection.selectedBundles.count
        ))

        let collectionURL = try await buildCollection(selection: selection)

        let mediaEntries = try await packageMedia(selection: selection)

        let manifest = ExportManifest(
            sourceGroups: Array(selection.sourceGroups),
            cardIdentities: selection.selectedBundles.map { $0.identity.compositeKey },
            mediaEntries: mediaEntries,
            schedulingPolicy: configuration.schedulingPolicy
        )

        let packageURL = try await packageWriter.createAPKG(
            collectionURL: collectionURL,
            mediaDirectory: workspace.workspaceDirectory?.appendingPathComponent("media", isDirectory: true),
            manifest: manifest,
            destination: destination
        )

        let validationReport = try await validator.validatePackage(at: packageURL)

        let endTime = Date()
        let exportResult = AnkiExportResult(
            packageURL: packageURL,
            manifest: manifest,
            validationReport: validationReport,
            checksum: manifest.exportID,
            exportDuration: endTime.timeIntervalSince(startTime)
        )

        progressHandler?(ExportProgress(
            cardsExported: selection.selectedBundles.count,
            mediaBytesExported: mediaEntries.reduce(0) { $0 + $1.byteSize },
            totalCards: selection.selectedBundles.count
        ))

        return exportResult
    }

    private func buildCollection(selection: ExportSelection) async throws -> URL {
        try await cancellation.checkCancellation()

        guard let workspaceDir = workspace.workspaceDirectory else {
            throw AnkiExportError.invalidPath(path: "workspace not available")
        }

        let collectionURL = workspaceDir.appendingPathComponent("collection.anki21")

        var builder = try AnkiCollectionBuilder(dbURL: collectionURL, config: configuration)

        for bundle in selection.selectedBundles {
            try await cancellation.checkCancellation()

            let modelID = AnkiCollectionRecords.computeModelID(name: "HermesCard")
            let deckID = AnkiCollectionRecords.computeDeckID(name: "Hermes Export")

            let note = AnkiNoteRecord(
                noteID: AnkiCollectionRecords.computeNoteID(for: bundle.identity),
                modelID: modelID,
                deckID: deckID,
                fieldStrings: buildFields(from: bundle),
                tags: AnkiCollectionMapper.buildTags(for: bundle)
            )

            try builder.insertNote(note)

            let card = AnkiCardRecord(
                cardID: note.noteID + 1,
                noteID: note.noteID,
                deckID: deckID,
                templateID: 0,
                due: 0,
                ordinal: 0,
                type: 0
            )

            try builder.insertCard(card)
        }

        try builder.finalizeCollection()
        builder.close()

        return collectionURL
    }

    private func buildFields(from bundle: GeneratedCardBundle) -> [String] {
        let firstSense = bundle.senses.first ?? LexicalSense(
            sourceLanguage: bundle.identity.sourceLanguage,
            targetLanguage: bundle.identity.targetLanguage,
            lemma: bundle.identity.lemma,
            senseKey: bundle.identity.senseKey,
            partOfSpeech: bundle.identity.partOfSpeech,
            meaning: "",
            translation: ""
        )

        return [
            bundle.identity.lemma,
            firstSense.translation,
            bundle.identity.direction.rawValue
        ].filter { !$0.isEmpty }
    }

    private func packageMedia(selection: ExportSelection) async throws -> [MediaManifestEntry] {
        try await cancellation.checkCancellation()

        guard let workspaceDir = workspace.workspaceDirectory else {
            throw AnkiExportError.invalidPath(path: "workspace not available")
        }

        let mediaDir = workspaceDir.appendingPathComponent("media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let allMedia = selection.selectedBundles.flatMap { $0.mediaAssets }
        
        return try await AnkiMediaPackager(resolver: mediaResolver).packageMedia(
            from: allMedia,
            to: mediaDir,
            config: configuration
        )
    }

    public func cancel() {
        cancellation.cancel()
    }

    public struct ExportRequest {
        public let selection: ExportSelection
        public let destination: URL
        public let configuration: AnkiExportConfiguration
        public let progressHandler: ((ExportProgress) -> Void)?

        public init(
            selection: ExportSelection,
            destination: URL,
            configuration: AnkiExportConfiguration = AnkiExportConfiguration(),
            progressHandler: ((ExportProgress) -> Void)? = nil
        ) {
            self.selection = selection
            self.destination = destination
            self.configuration = configuration
            self.progressHandler = progressHandler
        }
    }
}
