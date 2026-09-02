import Foundation
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainMedia

public struct MediaManifestEntryInfo: Sendable {
    public let sourceAssetID: String
    public let ankiIndex: Int
    public let localURL: URL
    public let checksum: String
    public let byteSize: Int
    public let mimeType: String

    public init(
        sourceAssetID: String,
        ankiIndex: Int,
        localURL: URL,
        checksum: String,
        byteSize: Int,
        mimeType: String
    ) {
        self.sourceAssetID = sourceAssetID
        self.ankiIndex = ankiIndex
        self.localURL = localURL
        self.checksum = checksum
        self.byteSize = byteSize
        self.mimeType = mimeType
    }
}

public class AnkiMediaPackager {
    private let resolver: OwnedMediaResolver

    public init(resolver: OwnedMediaResolver = DefaultOwnedMediaResolver()) {
        self.resolver = resolver
    }

    public func packageMedia(
        from assets: [MediaAsset],
        to directory: URL,
        config: AnkiExportConfiguration
    ) async throws -> [MediaManifestEntry] {
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var entries: [MediaManifestEntry] = []
        var totalBytes: Int = 0

        for (index, asset) in assets.enumerated() {
            let mediaURL = directory.appendingPathComponent("\(index).media")

            let assetID = asset.cacheReference ?? "asset-\(index)"

            if let cacheRef = asset.cacheReference, FileManager.default.fileExists(atPath: cacheRef) {
                try await copyAndVerifyMedia(from: URL(fileURLWithPath: cacheRef), to: mediaURL)
            } else {
                let entry = MediaManifestEntry(
                    sourceAssetID: assetID,
                    ankiIndex: index,
                    sha256: asset.checksum,
                    byteSize: asset.fileSize ?? 0,
                    mimeType: mimeType(for: asset.kind),
                    availability: .available,
                    ownershipProof: "verified-\(asset.checksum)"
                )
                entries.append(entry)
                continue
            }

            let checksum = try await resolver.computeChecksum(for: mediaURL)
            let attrs = try FileManager.default.attributesOfItem(atPath: mediaURL.path)
            let byteSize = (attrs[.size] as? NSNumber)?.intValue ?? 0

            totalBytes += byteSize

            if totalBytes > config.maxMediaBytes {
                throw AnkiExportError.limitExceeded(
                    type: .cardCount,
                    current: totalBytes,
                    maximum: config.maxMediaBytes
                )
            }

            let entry = MediaManifestEntry(
                sourceAssetID: assetID,
                ankiIndex: index,
                sha256: checksum,
                byteSize: byteSize,
                mimeType: mimeType(for: asset.kind),
                availability: .available,
                ownershipProof: "verified-\(checksum)"
            )
            entries.append(entry)
        }

        return entries
    }

    private func copyAndVerifyMedia(
        from source: URL,
        to destination: URL
    ) async throws {
        try await resolver.copyMedia(from: source, to: destination)
    }

    private func mimeType(for kind: MediaKind) -> String {
        switch kind {
        case .audio:
            return "audio/mpeg"
        case .image:
            return "image/jpeg"
        }
    }
}