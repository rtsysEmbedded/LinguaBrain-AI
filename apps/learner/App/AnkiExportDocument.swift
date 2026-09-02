import SwiftUI
import UniformTypeIdentifiers

public struct AnkiExportDocument: FileDocument, Transferable {
    public static let readableContentTypes: [UTType] = [.fileURL]
    public static let writableContentTypes: [UTType] = [.fileURL, .apkg]

    public let exportURL: URL?
    public let exportStatus: ExportStatus
    public let sourceGroups: [String]
    public let cardCount: Int
    public let mediaCount: Int

    public init(
        url: URL? = nil,
        status: ExportStatus = .notStarted,
        sourceGroups: [String] = [],
        cardCount: Int = 0,
        mediaCount: Int = 0
    ) {
        self.exportURL = url
        self.exportStatus = status
        self.sourceGroups = sourceGroups
        self.cardCount = cardCount
        self.mediaCount = mediaCount
    }

    public init(configuration: ReadConfiguration) throws {
        if let urlData = configuration.file.regularFileContents,
           let urlString = String(data: urlData, encoding: .utf8),
           let url = URL(string: urlString) {
            self.exportURL = url
            self.exportStatus = .completed
            self.sourceGroups = []
            self.cardCount = 0
            self.mediaCount = 0
        } else {
            self.exportURL = nil
            self.exportStatus = .notStarted
            self.sourceGroups = []
            self.cardCount = 0
            self.mediaCount = 0
        }
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let urlString = exportURL?.absoluteString ?? ""
        let data = Data(urlString.utf8)
        return FileWrapper(regularFileWithContents: data)
    }

    public static func transferable(from transformation: TransferRepresentation) -> some TransformedContent<AnkiExportDocument> {
        TransferableRepresentation(transformation)
    }

    public static let apkg = UTType("com.anki.apkg")
}

public enum ExportStatus: String, Codable, Sendable {
    case notStarted
    case inProgress
    case completed
    case failed
    case cancelled

    public var localizedDescription: String {
        switch self {
        case .notStarted: return "notStarted"
        case .inProgress: return "inProgress"
        case .completed: return "completed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        }
    }
}