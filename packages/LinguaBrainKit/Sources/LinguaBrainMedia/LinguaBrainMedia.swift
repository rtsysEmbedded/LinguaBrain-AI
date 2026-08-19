import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

/// Media capabilities and configuration (T020)
public struct MediaCapabilities: Sendable, Equatable {
    public let supportedTypes: [MediaKind]
    public let quota: Int?
    public let consentRequired: Bool

    public init(supportedTypes: [MediaKind], quota: Int? = nil, consentRequired: Bool = true) {
        self.supportedTypes = supportedTypes
        self.quota = quota
        self.consentRequired = consentRequired
    }
}

/// Media provider adapter for audio generation (T021, FR-008)
public final class AudioMediaProviderAdapter: AudioProviderPort, @unchecked Sendable {
    private let mediaProvider: MediaProviderProtocol

    public init(_ mediaProvider: MediaProviderProtocol) {
        self.mediaProvider = mediaProvider
    }

    public func generateAudio(for request: GenerationRequest, sense: LexicalSense) async throws -> MediaAsset {
        try await mediaProvider.generateMedia(
            kind: .audio,
            request: request,
            sense: sense
        )
    }
}

/// Media provider adapter for image generation (T021, FR-008)
public final class ImageMediaProviderAdapter: ImageProviderPort, @unchecked Sendable {
    private let mediaProvider: MediaProviderProtocol

    public init(_ mediaProvider: MediaProviderProtocol) {
        self.mediaProvider = mediaProvider
    }

    public func generateImage(for request: GenerationRequest, sense: LexicalSense) async throws -> MediaAsset {
        try await mediaProvider.generateMedia(
            kind: .image,
            request: request,
            sense: sense
        )
    }
}

/// Unified media provider interface (T021, FR-010)
public protocol MediaProviderProtocol: Sendable {
    func generateMedia(kind: MediaKind, request: GenerationRequest, sense: LexicalSense) async throws -> MediaAsset
}

extension MediaProviderProtocol {
    /// Capability reporting for independent audio/image providers (T021)
    public var audioCapability: MediaCapabilities {
        MediaCapabilities(
            supportedTypes: [.audio],
            quota: nil,
            consentRequired: true
        )
    }

    public var imageCapability: MediaCapabilities {
        MediaCapabilities(
            supportedTypes: [.image],
            quota: nil,
            consentRequired: true
        )
    }
}

/// Media cache policy defined for the media slice (T020, out of MVP scope but kept compiled).
public enum MediaCachePolicy: Sendable, Equatable {
    case permanent
    case ttl(TimeInterval)
    case maxSize(Int)
}
