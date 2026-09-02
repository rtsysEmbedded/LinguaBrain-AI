import Foundation
import LinguaBrainDomain
import LinguaBrainApplication
import LinguaBrainMedia

public struct PipelineResult<T: Sendable>: Sendable {
    public let result: T
    public let processedCount: Int
    public let processedBytes: Int
    public let duration: TimeInterval
    public let isComplete: Bool
    
    public init(
        result: T,
        processedCount: Int,
        processedBytes: Int,
        duration: TimeInterval = Date().timeIntervalSince1970,
        isComplete: Bool = true
    ) {
        self.result = result
        self.processedCount = processedCount
        self.processedBytes = processedBytes
        self.duration = duration
        self.isComplete = isComplete
    }
}

public class AnkiExportPipeline {
    private let config: AnkiExportConfiguration
    private let cancellation: ExportCancellation
    
    public init(
        config: AnkiExportConfiguration = AnkiExportConfiguration(),
        cancellation: ExportCancellation? = nil
    ) {
        self.config = config
        self.cancellation = cancellation ?? ExportCancellation()
    }
    
    public var isCancelled: Bool {
        cancellation.isCancelled
    }
    
    public func checkCancellation() throws {
        try cancellation.checkCancellation()
    }
    
    public func checkCardLimit(count: Int) throws {
        if count > config.maxCards {
            throw AnkiExportError.limitExceeded(
                type: .cardCount,
                current: count,
                maximum: config.maxCards
            )
        }
    }
    
    public func checkMediaLimit(bytes: Int) throws {
        if bytes > config.maxMediaBytes {
            throw AnkiExportError.limitExceeded(
                type: .mediaBytes,
                current: bytes,
                maximum: config.maxMediaBytes
            )
        }
    }
    
    public func checkEntrySize(bytes: Int) throws {
        if bytes > config.maxMediaBytes {
            throw AnkiExportError.limitExceeded(
                type: .entrySize,
                current: bytes,
                maximum: config.maxMediaBytes
            )
        }
    }
    
    public func streamMedia<T: Sendable>(
        from bundles: [GeneratedCardBundle],
        processor: @escaping @Sendable (MediaAsset, Int) async throws -> T
    ) async throws -> PipelineResult<[T]> {
        var results: [T] = []
        var totalCount = 0
        var totalBytes = 0
        
        var index = 0
        for bundle in bundles {
            try await checkCancellation()
            
            for asset in bundle.mediaAssets {
                let result = try await processor(asset, index)
                results.append(result)
                
                if let size = asset.fileSize {
                    totalBytes += size
                }
                
                totalCount += 1
                index += 1
                
                try await checkMediaLimit(bytes: totalBytes)
            }
        }
        
        try await checkCardLimit(count: totalCount)
        
        return PipelineResult(
            result: results,
            processedCount: totalCount,
            processedBytes: totalBytes
        )
    }
    
    public func streamCards<T: Sendable>(
        from bundles: [GeneratedCardBundle],
        processor: @escaping @Sendable (GeneratedCardBundle, Int) async throws -> T
    ) async throws -> PipelineResult<[T]> {
        var results: [T] = []
        var processedCount = 0
        
        for (index, bundle) in bundles.enumerated() {
            try await checkCancellation()
            
            try await checkCardLimit(count: index + 1)
            
            let result = try await processor(bundle, index)
            results.append(result)
            processedCount += 1
        }
        
        return PipelineResult(
            result: results,
            processedCount: processedCount,
            processedBytes: 0
        )
    }
    
    public func boundedExport<T: Sendable>(
        from bundles: [GeneratedCardBundle],
        maxCards: Int? = nil,
        maxBytes: Int? = nil,
        processor: @escaping @Sendable (GeneratedCardBundle, Int) async throws -> T
    ) async throws -> PipelineResult<[T]> {
        let effectiveMaxCards = maxCards ?? config.maxCards
        let effectiveMaxBytes = maxBytes ?? config.maxMediaBytes
        
        var results: [T] = []
        var processedCount = 0
        var processedBytes = 0
        
        for (index, bundle) in bundles.enumerated() {
            try await checkCancellation()
            
            if processedCount >= effectiveMaxCards {
                throw AnkiExportError.limitExceeded(
                    type: .cardCount,
                    current: processedCount,
                    maximum: effectiveMaxCards
                )
            }
            
            try await checkCardLimit(count: index + 1)
            
            if !bundle.mediaAssets.isEmpty {
                let bundleBytes = bundle.mediaAssets.reduce(0) { $0 + ($1.fileSize ?? 0) }
                if processedBytes + bundleBytes > effectiveMaxBytes {
                    throw AnkiExportError.limitExceeded(
                        type: .mediaBytes,
                        current: processedBytes + bundleBytes,
                        maximum: effectiveMaxBytes
                    )
                }
                processedBytes += bundleBytes
            }
            
            let result = try await processor(bundle, index)
            results.append(result)
            processedCount += 1
        }
        
        return PipelineResult(
            result: results,
            processedCount: processedCount,
            processedBytes: processedBytes
        )
    }
    
    public func exportWithProgress(
        bundles: [GeneratedCardBundle],
        progressHandler: @escaping @Sendable (ExportProgress) -> Void
    ) async throws -> ExportResult {
        var totalCards = bundles.count
        var exportedCards = 0
        var totalMediaBytes = 0
        
        for bundle in bundles {
            totalMediaBytes += bundle.mediaAssets.reduce(0) { $0 + ($1.fileSize ?? 0) }
        }
        
        progressHandler(ExportProgress(
            cardsExported: 0,
            mediaBytesExported: 0,
            totalCards: totalCards,
            totalBytes: totalMediaBytes
        ))
        
        try await checkCardLimit(count: totalCards)
        try await checkMediaLimit(bytes: totalMediaBytes)
        
        for (index, bundle) in bundles.enumerated() {
            try await checkCancellation()
            
            exportedCards += 1
            
            var exportedBytes = 0
            for asset in bundle.mediaAssets {
                exportedBytes += asset.fileSize ?? 0
            }
            
            progressHandler(ExportProgress(
                cardsExported: exportedCards,
                mediaBytesExported: exportedBytes,
                totalCards: totalCards,
                totalBytes: totalMediaBytes
            ))
        }
        
        return ExportResult(
            success: true,
            cardCount: exportedCards,
            mediaBytes: totalMediaBytes
        )
    }
}

public struct ExportResult: Sendable {
    public let success: Bool
    public let cardCount: Int
    public let mediaBytes: Int
    
    public init(success: Bool, cardCount: Int, mediaBytes: Int) {
        self.success = success
        self.cardCount = cardCount
        self.mediaBytes = mediaBytes
    }
}