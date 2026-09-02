import Foundation
import LinguaBrainDomain

public struct AnkiNoteRecord: Sendable, Equatable {
    public let noteID: Int64
    public let modelID: Int64
    public let deckID: Int64
    public let fieldStrings: [String]
    public let tags: [String]
    public let sortIDX: Int64
    public let creationTime: TimeInterval
    public let modificationTime: TimeInterval

    public init(
        noteID: Int64,
        modelID: Int64,
        deckID: Int64,
        fieldStrings: [String],
        tags: [String] = [],
        sortIDX: Int64 = 0,
        creationTime: TimeInterval = Date().timeIntervalSince1970,
        modificationTime: TimeInterval = 0
    ) {
        self.noteID = noteID
        self.modelID = modelID
        self.deckID = deckID
        self.fieldStrings = fieldStrings
        self.tags = tags
        self.sortIDX = sortIDX
        self.creationTime = creationTime
        self.modificationTime = modificationTime
    }

    public static func deterministicID(seed: UInt64) -> Int64 {
        return Int64(bitPattern: seed)
    }
}

public struct AnkiCardRecord: Sendable, Equatable {
    public let cardID: Int64
    public let noteID: Int64
    public let deckID: Int64
    public let templateID: Int64
    public let due: Int64
    public let ordinal: Int32
    public let type: Int32
    public let queue: Int32
    public let reps: Int32
    public let lapses: Int32
    public let ease: Int32
    public let lastReview: TimeInterval?
    public let nextReview: TimeInterval?
    public let intervals: [Double]?

    public init(
        cardID: Int64,
        noteID: Int64,
        deckID: Int64,
        templateID: Int64 = 0,
        due: Int64 = 0,
        ordinal: Int32 = 0,
        type: Int32 = 0,
        queue: Int32 = 1,
        reps: Int32 = 0,
        lapses: Int32 = 0,
        ease: Int32 = 1,
        lastReview: TimeInterval? = nil,
        nextReview: TimeInterval? = nil,
        intervals: [Double]? = nil
    ) {
        self.cardID = cardID
        self.noteID = noteID
        self.deckID = deckID
        self.templateID = templateID
        self.due = due
        self.ordinal = ordinal
        self.type = type
        self.queue = queue
        self.reps = reps
        self.lapses = lapses
        self.ease = ease
        self.lastReview = lastReview
        self.nextReview = nextReview
        self.intervals = intervals
    }
}

public struct AnkiModelRecord: Sendable, Equatable {
    public let modelID: Int64
    public let name: String
    public let fieldNames: [String]
    public let templates: [AnkiTemplateRecord]
    public let css: String
    public let formatVersion: Int32
    public let sortFieldType: Int32

    public static let defaultCSS = """
    .card {
        font-family: Arial, sans-serif;
        font-size: 20px;
        text-align: left;
        color: black;
        background-color: white;
    }
    """

    public init(
        modelID: Int64,
        name: String,
        fieldNames: [String],
        templates: [AnkiTemplateRecord],
        css: String = AnkiModelRecord.defaultCSS,
        formatVersion: Int32 = 31,
        sortFieldType: Int32 = 0
    ) {
        self.modelID = modelID
        self.name = name
        self.fieldNames = fieldNames
        self.templates = templates
        self.css = css
        self.formatVersion = formatVersion
        self.sortFieldType = sortFieldType
    }
}

public struct AnkiTemplateRecord: Sendable, Equatable, Codable {
    public let name: String
    public let questionFormat: String
    public let answerFormat: String

    public init(
        name: String,
        questionFormat: String = "{{#fields.0}}{{fields.0}}{{/fields}} {{#fields.1}}{{fields.1}}{{/fields}}",
        answerFormat: String = "{{#fields.0}}{{fields.0}}{{/fields}} {{#fields.1}}{{fields.1}}{{/fields}}"
    ) {
        self.name = name
        self.questionFormat = questionFormat
        self.answerFormat = answerFormat
    }
}

public struct AnkiDeckRecord: Sendable, Equatable {
    public let deckID: Int64
    public let name: String
    public let parentID: Int64
    public let timestamp: TimeInterval

    public init(
        deckID: Int64,
        name: String,
        parentID: Int64 = 0,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.deckID = deckID
        self.name = name
        self.parentID = parentID
        self.timestamp = timestamp
    }
}

public struct AnkiTagRecord: Sendable, Equatable {
    public let tag: String
    public let creationTime: TimeInterval?

    public init(tag: String, creationTime: TimeInterval? = nil) {
        self.tag = tag
        self.creationTime = creationTime
    }
}

public struct AnkiCollectionRecords {
    public static func computeNoteID(for identity: CardIdentity) -> Int64 {
        let components = [
            identity.sourceLanguage,
            identity.targetLanguage,
            identity.lemma.lowercased(),
            identity.senseKey.lowercased(),
            identity.partOfSpeech.lowercased(),
            identity.direction.rawValue
        ]
        
        let hash = components.joined(separator: "|").hashValue
        let seed = UInt64(abs(hash)) & 0x7FFFFFFFFFFFFFFF
        return AnkiNoteRecord.deterministicID(seed: seed)
    }

    public static func computeCardID(noteID: Int64, ordinal: Int) -> Int64 {
        return noteID + Int64(ordinal)
    }

    public static func computeModelID(name: String) -> Int64 {
        let hash = name.hashValue
        let seed = UInt64(abs(hash)) & 0x7FFFFFFFFFFFFFFF
        return AnkiNoteRecord.deterministicID(seed: seed) + 0x1000
    }

    public static func computeDeckID(name: String) -> Int64 {
        let hash = name.hashValue
        let seed = UInt64(abs(hash)) & 0x7FFFFFFFFFFFFFFF
        return AnkiNoteRecord.deterministicID(seed: seed) + 0x2000
    }
}