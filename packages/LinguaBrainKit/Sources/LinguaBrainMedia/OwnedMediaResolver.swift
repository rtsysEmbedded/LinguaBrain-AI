import Foundation
import CryptoKit
import LinguaBrainDomain
import LinguaBrainApplication

public protocol OwnedMediaResolver: Sendable {
    func resolveMediaReference(for assetID: String) async throws -> MediaReference
    func computeChecksum(for mediaURL: URL) async throws -> String
    func copyMedia(from sourceURL: URL, to destinationURL: URL) async throws
}

public struct MediaReference: Sendable, Equatable {
    public let assetID: String
    public let localURL: URL
    public let checksum: String
    public let byteSize: Int
    public let mimeType: String
    public let ownershipProof: String

    public init(
        assetID: String,
        localURL: URL,
        checksum: String,
        byteSize: Int,
        mimeType: String,
        ownershipProof: String
    ) {
        self.assetID = assetID
        self.localURL = localURL
        self.checksum = checksum
        self.byteSize = byteSize
        self.mimeType = mimeType
        self.ownershipProof = ownershipProof
    }
}

public final class DefaultOwnedMediaResolver: OwnedMediaResolver {
    private var fileManager: FileManager { FileManager.default }
    private let queue = DispatchQueue(label: "media.resolver", qos: .userInitiated)

    public init() {}

    public func computeChecksum(for mediaURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let data = try Data(contentsOf: mediaURL)
                    let hash = SHA256.hash(data: data)
                    let hexString = hash.compactMap { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: hexString)
                } catch {
                    continuation.resume(throwing: MediaError.missingFile(url: mediaURL.path))
                }
            }
        }
    }

    public func resolveMediaReference(for assetID: String) async throws -> MediaReference {
        let mediaURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("media")
            .appendingPathComponent(assetID)

        guard fileManager.fileExists(atPath: mediaURL.path) else {
            throw MediaError.missingAsset(id: assetID)
        }

        let checksum = try await computeChecksum(for: mediaURL)
        let attrs = try fileManager.attributesOfItem(atPath: mediaURL.path)
        let byteSize = (attrs[.size] as? NSNumber)?.intValue ?? 0

        let mimeType = Self.mimeType(for: mediaURL)

        return MediaReference(
            assetID: assetID,
            localURL: mediaURL,
            checksum: checksum,
            byteSize: byteSize,
            mimeType: mimeType,
            ownershipProof: "verified-\(checksum)"
        )
    }

    public func copyMedia(from sourceURL: URL, to destinationURL: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let destinationDir = destinationURL.deletingLastPathComponent()
                    if !self.fileManager.fileExists(atPath: destinationDir.path) {
                        try self.fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
                    }

                    if self.fileManager.fileExists(atPath: destinationURL.path) {
                        try? self.fileManager.removeItem(at: destinationURL)
                    }
                    try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: MediaError.copyFailed(from: sourceURL.path, to: destinationURL.path, error: error))
                }
            }
        }
    }

    private static func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case "mp3", "wav", "m4a", "aac", "ogg":
            return "audio/mpeg"
        case "mp4", "mov", "m4v", "webm":
            return "video/mp4"
        case "jpg", "jpeg", "png", "gif", "webp":
            return "image/jpeg"
        default:
            return "application/octet-stream"
        }
    }
}

public enum MediaError: Error, Sendable {
    case missingAsset(id: String)
    case missingFile(url: String)
    case copyFailed(from: String, to: String, error: Error)
    case invalidChecksum(expected: String, actual: String)

    public var localizedDescription: String {
        switch self {
        case .missingAsset(let id):
            return "Missing media asset: \(id)"
        case .missingFile(let url):
            return "Media file not found: \(url)"
        case .copyFailed(let from, let to, let error):
            return "Failed to copy media from \(from) to \(to): \(error.localizedDescription)"
        case .invalidChecksum(let expected, let actual):
            return "Checksum mismatch: expected \(expected), got \(actual)"
        }
    }
}