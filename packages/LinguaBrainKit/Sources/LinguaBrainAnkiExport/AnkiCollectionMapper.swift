import Foundation
import LinguaBrainDomain
import LinguaBrainApplication

public struct AnkiCollectionMapper {
    public static func mapBundleToNote(
        _ bundle: GeneratedCardBundle,
        modelID: Int64,
        deckID: Int64
    ) -> AnkiNoteRecord {
        let firstSense = bundle.senses.first ?? LexicalSense(
            sourceLanguage: bundle.identity.sourceLanguage,
            targetLanguage: bundle.identity.targetLanguage,
            lemma: bundle.identity.lemma,
            senseKey: bundle.identity.senseKey,
            partOfSpeech: bundle.identity.partOfSpeech,
            meaning: "",
            translation: ""
        )

        let fields = [
            bundle.identity.lemma,
            firstSense.translation,
            bundle.identity.direction.rawValue,
            bundle.provenance.provider,
            bundle.provenance.generatedAt.timeIntervalSince1970.description
        ].filter { !$0.isEmpty }

        let noteID = AnkiCollectionRecords.computeNoteID(for: bundle.identity)
        
        return AnkiNoteRecord(
            noteID: noteID,
            modelID: modelID,
            deckID: deckID,
            fieldStrings: fields,
            tags: buildTags(for: bundle),
            sortIDX: noteID
        )
    }

    public static func mapBundleToCard(
        bundle: GeneratedCardBundle,
        noteID: Int64,
        deckID: Int64,
        templateOrdinal: Int = 0
    ) -> AnkiCardRecord {
        return AnkiCardRecord(
            cardID: AnkiCollectionRecords.computeCardID(noteID: noteID, ordinal: templateOrdinal),
            noteID: noteID,
            deckID: deckID,
            templateID: Int64(templateOrdinal),
            due: 0,
            ordinal: Int32(templateOrdinal),
            type: 0,
            queue: 1,
            reps: 0,
            lapses: 0,
            ease: 1
        )
    }

    public static func mapBundleToDeck(
        sourceGroup: String,
        languagePair: (source: String, target: String)?
    ) -> AnkiDeckRecord {
        let deckName: String
        if let pair = languagePair {
            deckName = "Hermes Export/\(pair.source)→\(pair.target)"
        } else {
            deckName = "Hermes Export/\(sourceGroup)"
        }
        
        let deckID = AnkiCollectionRecords.computeDeckID(name: deckName)
        
        return AnkiDeckRecord(
            deckID: deckID,
            name: deckName
        )
    }

    public static func mapBundleToModel(
        name: String,
        fieldNames: [String],
        templateName: String = "Card"
    ) -> AnkiModelRecord {
        let modelID = AnkiCollectionRecords.computeModelID(name: name)
        
        let template = AnkiTemplateRecord(
            name: templateName,
            questionFormat: buildQuestionFormat(fields: fieldNames),
            answerFormat: buildAnswerFormat(fields: fieldNames)
        )
        
        return AnkiModelRecord(
            modelID: modelID,
            name: name,
            fieldNames: fieldNames,
            templates: [template]
        )
    }

    public static func mapBundleToTags(bundle: GeneratedCardBundle) -> [AnkiTagRecord] {
        let tags: [String] = [
            bundle.identity.direction.rawValue,
            bundle.approvalState.rawValue,
            "hermes-export",
            bundle.identity.sourceLanguage,
            bundle.identity.targetLanguage
        ].filter { !$0.isEmpty }

        return tags.map { AnkiTagRecord(tag: $0) }
    }

    public static func buildTags(for bundle: GeneratedCardBundle) -> [String] {
        return [
            bundle.identity.direction.rawValue,
            bundle.approvalState.rawValue,
            "hermes-export",
            bundle.identity.sourceLanguage,
            bundle.identity.targetLanguage
        ].filter { !$0.isEmpty }
    }

    private static func buildQuestionFormat(fields: [String]) -> String {
        guard !fields.isEmpty else {
            return "{{Front}}"
        }
        
        let fieldRefs = fields.enumerated().map { index, _ in
            "{{#fields.\(index)}}{{fields.\(index)}}{{/fields}}"
        }.joined(separator: "\n")
        
        return fieldRefs
    }

    private static func buildAnswerFormat(fields: [String]) -> String {
        guard !fields.isEmpty else {
            return "{{Front}}"
        }
        
        let fieldRefs = fields.enumerated().map { index, _ in
            "{{#fields.\(index)}}{{fields.\(index)}}{{/fields}}"
        }.joined(separator: "\n")
        
        return """
        <hr id="answer">
        """ + fieldRefs
    }

    public static func mapProvenanceToTags(provider: String, model: String) -> [String] {
        return ["provenance-\(provider)", "model-\(model)"]
    }
}

extension AnkiNoteRecord {
    public static func fromBundle(
        _ bundle: GeneratedCardBundle,
        modelID: Int64,
        deckID: Int64
    ) -> AnkiNoteRecord {
        return AnkiCollectionMapper.mapBundleToNote(bundle, modelID: modelID, deckID: deckID)
    }
}