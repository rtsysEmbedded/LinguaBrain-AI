import Foundation
import XCTest

final class WritingEvaluationFixtureTests: XCTestCase {
    func testEveryWritingFixtureMatchesItsExpectedValidation() throws {
        let document = try loadDocument()
        XCTAssertEqual(document["schemaVersion"] as? String, "writing-evaluation-v1")
        XCTAssertEqual(document["rubricVersion"] as? String, "writing-rubric-v1")

        let fixtures = try XCTUnwrap(document["fixtures"] as? [[String: Any]])
        XCTAssertEqual(fixtures.count, 13)

        for fixture in fixtures {
            let id = try XCTUnwrap(fixture["fixtureID"] as? String)
            let expected = try XCTUnwrap(fixture["expectedValidation"] as? String)
            let errors = WritingFixtureValidator.validate(fixture)

            switch expected {
            case "accept":
                XCTAssertTrue(errors.isEmpty, "\(id) rejected: \(errors)")
            case "reject":
                XCTAssertFalse(errors.isEmpty, "\(id) unexpectedly accepted")
            case "normalizeUnavailable":
                XCTAssertTrue(errors.contains("lowConfidence"), "\(id) did not identify low confidence: \(errors)")
            default:
                XCTFail("unknown expectedValidation for \(id): \(expected)")
            }
        }
    }

    func testCorrectAlternativesDoNotReceiveUnnecessaryCorrections() throws {
        for id in ["correct-no-correction", "separable-verb-valid", "style-only-improvement"] {
            let fixture = try fixture(id: id)
            let output = try XCTUnwrap(fixture["output"] as? [String: Any])
            XCTAssertEqual(output["outcome"] as? String, "correct")
            XCTAssertTrue(output["minimalCorrection"] is NSNull, "\(id) should not force a correction")
        }

        let styleOutput = try XCTUnwrap(try fixture(id: "style-only-improvement")["output"] as? [String: Any])
        XCTAssertEqual(styleOutput["naturalVariant"] as? String, "Heute habe ich Zeit für den Kurs.")
    }

    func testMeaningChangingCorrectionRequiresHumanReview() throws {
        let fixture = try fixture(id: "meaning-changing-correction")
        let output = try XCTUnwrap(fixture["output"] as? [String: Any])
        let meaning = try XCTUnwrap(output["meaningAssessment"] as? [String: Any])
        XCTAssertEqual(meaning["status"] as? String, "changed")
        XCTAssertEqual(output["approvalPolicy"] as? String, "humanReviewRequired")
        XCTAssertEqual(output["canonicalContentAction"] as? String, "none")
        XCTAssertEqual(output["masterySchedulingMutation"] as? Bool, false)
    }

    func testValidatorRejectsOversizedLanguageSpanScoreConfidenceAndRulePayloads() throws {
        var oversized = try fixture(id: "correct-no-correction")
        var oversizedInput = try XCTUnwrap(oversized["input"] as? [String: Any])
        oversizedInput["learnerSentence"] = String(repeating: "a", count: 501)
        oversized["input"] = oversizedInput
        XCTAssertTrue(WritingFixtureValidator.validate(oversized).contains("textTooLong"))

        var invalidLanguage = try fixture(id: "correct-no-correction")
        var invalidLanguageInput = try XCTUnwrap(invalidLanguage["input"] as? [String: Any])
        invalidLanguageInput["targetLanguage"] = "xx"
        invalidLanguage["input"] = invalidLanguageInput
        XCTAssertTrue(WritingFixtureValidator.validate(invalidLanguage).contains("unsupportedLanguage"))

        var invalidSpan = try fixture(id: "verb-position-error")
        var invalidSpanOutput = try XCTUnwrap(invalidSpan["output"] as? [String: Any])
        invalidSpanOutput["affectedSpans"] = [[
            "start": 0,
            "end": 999,
            "text": "outside",
            "category": "grammar",
            "ruleID": "de.word_order.verb_final"
        ]]
        invalidSpan["output"] = invalidSpanOutput
        XCTAssertTrue(WritingFixtureValidator.validate(invalidSpan).contains("invalidSpan"))

        var invalidScore = try fixture(id: "correct-no-correction")
        var invalidScoreOutput = try XCTUnwrap(invalidScore["output"] as? [String: Any])
        invalidScoreOutput["score"] = 1.5
        invalidScore["output"] = invalidScoreOutput
        XCTAssertTrue(WritingFixtureValidator.validate(invalidScore).contains("invalidScore"))

        var invalidConfidence = try fixture(id: "correct-no-correction")
        var invalidConfidenceOutput = try XCTUnwrap(invalidConfidence["output"] as? [String: Any])
        invalidConfidenceOutput["confidence"] = -0.1
        invalidConfidence["output"] = invalidConfidenceOutput
        XCTAssertTrue(WritingFixtureValidator.validate(invalidConfidence).contains("invalidConfidence"))

        var unknownRule = try fixture(id: "verb-position-error")
        var unknownRuleOutput = try XCTUnwrap(unknownRule["output"] as? [String: Any])
        unknownRuleOutput["ruleReferences"] = [["id": "de.unknown.rule", "category": "grammar"]]
        unknownRule["output"] = unknownRuleOutput
        XCTAssertTrue(WritingFixtureValidator.validate(unknownRule).contains("unknownRule"))
    }

    func testLowConfidenceAndUnavailableResultsRemainUngraded() throws {
        for id in ["ambiguous-intent", "provider-unavailable", "cancelled"] {
            let fixture = try fixture(id: id)
            let output = try XCTUnwrap(fixture["output"] as? [String: Any])
            XCTAssertEqual(output["outcome"] as? String, "unavailable")
            XCTAssertTrue(output["score"] is NSNull)
            XCTAssertTrue(output["confidence"] is NSNull)
            XCTAssertEqual(output["masterySchedulingMutation"] as? Bool, false)
        }

        let lowConfidence = try fixture(id: "low-confidence")
        XCTAssertTrue(WritingFixtureValidator.validate(lowConfidence).contains("lowConfidence"))
    }

    func testAcceptedProposalsCannotMutateCanonicalLearningState() throws {
        let document = try loadDocument()
        let fixtures = try XCTUnwrap(document["fixtures"] as? [[String: Any]])
        for fixture in fixtures where (fixture["expectedValidation"] as? String) != "reject" {
            let id = try XCTUnwrap(fixture["fixtureID"] as? String)
            let output = try XCTUnwrap(fixture["output"] as? [String: Any])
            XCTAssertEqual(output["canonicalContentAction"] as? String, "none", id)
            XCTAssertEqual(output["masterySchedulingMutation"] as? Bool, false, id)
        }
    }

    private func loadDocument() throws -> [String: Any] {
        let bundle = Bundle.module
        let url = try XCTUnwrap(bundle.url(forResource: "practice-writing", withExtension: "json", subdirectory: "Fixtures"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func fixture(id: String) throws -> [String: Any] {
        let document = try loadDocument()
        let fixtures = try XCTUnwrap(document["fixtures"] as? [[String: Any]])
        return try XCTUnwrap(fixtures.first { $0["fixtureID"] as? String == id })
    }
}

private enum WritingFixtureValidator {
    private static let languages: Set<String> = ["fa", "de", "en"]
    private static let levels: Set<String> = ["A1", "A2", "B1", "B2", "C1", "C2"]
    private static let partsOfSpeech: Set<String> = ["noun", "verb", "adjective", "adverb", "preposition", "conjunction", "pronoun", "article", "phrase", "other"]
    private static let outcomes: Set<String> = ["correct", "partial", "incorrect", "unavailable"]
    private static let meaningStatuses: Set<String> = ["preserved", "partiallyPreserved", "changed", "uncertain"]
    private static let feedbackTypes: Set<String> = ["grammar", "vocabulary", "meaning", "style", "targetWord"]
    private static let severities: Set<String> = ["info", "warning", "error"]
    private static let categories: Set<String> = ["grammar", "vocabulary", "meaning", "style"]
    private static let ruleIDs: Set<String> = [
        "de.word_order.verb_final",
        "de.verb.separable",
        "de.verb.inflection",
        "de.lexical.target_missing",
        "de.lexical.unrelated",
        "meaning.intent_uncertain",
        "style.naturalness"
    ]
    private static let unavailableReasons: Set<String> = [
        "uncertainIntent", "unsupportedLanguage", "lowConfidence", "malformedOutput", "providerUnavailable", "cancelled"
    ]

    static func validate(_ fixture: [String: Any]) -> Set<String> {
        var errors = Set<String>()
        guard let input = fixture["input"] as? [String: Any] else {
            errors.insert("missingInput")
            return errors
        }
        guard let output = fixture["output"] as? [String: Any] else {
            errors.insert("missingOutput")
            return errors
        }

        requiredString(input, "learnerID", errors: &errors)
        requiredString(input, "sourceLanguage", errors: &errors)
        requiredString(input, "targetLanguage", errors: &errors)
        requiredString(input, "cefrLevel", errors: &errors)
        requiredString(input, "targetWord", errors: &errors)
        requiredString(input, "partOfSpeech", errors: &errors)
        requiredString(input, "exerciseObjective", errors: &errors)
        guard let revision = integer(input["sentenceRevision"]), revision > 0 else { errors.insert("invalidRevision"); return errors }

        guard let sourceLanguage = input["sourceLanguage"] as? String, languages.contains(sourceLanguage),
              let targetLanguage = input["targetLanguage"] as? String, languages.contains(targetLanguage) else {
            errors.insert("unsupportedLanguage")
            return errors
        }
        if let level = input["cefrLevel"] as? String, !levels.contains(level) { errors.insert("invalidLevel") }
        if let part = input["partOfSpeech"] as? String, !partsOfSpeech.contains(part) { errors.insert("invalidPartOfSpeech") }
        if input["exerciseObjective"] as? String != "write_sentence_with_target_word" { errors.insert("invalidObjective") }

        guard let sentence = input["learnerSentence"] as? String, !sentence.isEmpty else {
            errors.insert("missingLearnerSentence")
            return errors
        }
        for key in ["allowedContext", "targetWord", "learnerSentence"] {
            if let value = input[key] as? String, value.count > 500 { errors.insert("textTooLong") }
        }
        if let targetWord = input["targetWord"] as? String, targetWord.count > 120 { errors.insert("targetWordTooLong") }

        guard let outcome = output["outcome"] as? String, outcomes.contains(outcome) else {
            errors.insert("invalidOutcome")
            return errors
        }
        guard let meaning = output["meaningAssessment"] as? [String: Any],
              let meaningStatus = meaning["status"] as? String,
              meaningStatuses.contains(meaningStatus) else {
            errors.insert("invalidMeaningAssessment")
            return errors
        }
        if let meaningConfidence = optionalNumber(meaning["confidence"]), !isUnit(meaningConfidence) {
            errors.insert("invalidConfidence")
        }
        if output["originalLearnerSentence"] as? String != sentence { errors.insert("originalResponseMismatch") }
        for key in ["minimalCorrection", "naturalVariant"] {
            if let value = optionalString(output[key]), value.count > 500 { errors.insert("textTooLong") }
        }

        guard let explanation = output["explanation"] as? [String: Any],
              let explanationLanguage = explanation["language"] as? String,
              languages.contains(explanationLanguage),
              let explanationText = explanation["text"] as? String,
              !explanationText.isEmpty else {
            errors.insert("invalidExplanation")
            return errors
        }
        if explanationText.count > 500 { errors.insert("textTooLong") }

        if let feedback = output["feedback"] as? [[String: Any]] {
            if feedback.count > 8 { errors.insert("tooManyFeedbackItems") }
            for item in feedback {
                guard let type = item["type"] as? String, feedbackTypes.contains(type),
                      let message = item["message"] as? String, !message.isEmpty,
                      let severity = item["severity"] as? String, severities.contains(severity) else {
                    errors.insert("invalidFeedback")
                    continue
                }
                if message.count > 240 { errors.insert("feedbackTooLong") }
            }
        } else {
            errors.insert("invalidFeedback")
        }

        var seenRuleIDs = Set<String>()
        if let rules = output["ruleReferences"] as? [[String: Any]] {
            if rules.count > 8 { errors.insert("tooManyRules") }
            for rule in rules {
                guard let id = rule["id"] as? String, ruleIDs.contains(id),
                      let category = rule["category"] as? String, categories.contains(category) else {
                    errors.insert(rule["id"] as? String == nil ? "invalidRule" : "unknownRule")
                    continue
                }
                seenRuleIDs.insert(id)
            }
        } else {
            errors.insert("invalidRules")
        }

        if let spans = output["affectedSpans"] as? [[String: Any]] {
            if spans.count > 8 { errors.insert("tooManySpans") }
            let scalars = Array(sentence)
            for span in spans {
                guard let start = integer(span["start"]), let end = integer(span["end"]),
                      start >= 0, end > start, end <= scalars.count,
                      let text = span["text"] as? String,
                      let category = span["category"] as? String, categories.contains(category),
                      let ruleID = span["ruleID"] as? String, seenRuleIDs.contains(ruleID),
                      String(scalars[start..<end]) == text else {
                    errors.insert("invalidSpan")
                    continue
                }
            }
        } else {
            errors.insert("invalidSpans")
        }

        let score = optionalNumber(output["score"])
        let confidence = optionalNumber(output["confidence"])
        switch outcome {
        case "correct", "partial", "incorrect":
            if let score {
                if !isUnit(score) { errors.insert("invalidScore") }
            } else {
                errors.insert("invalidScore")
            }
            if let confidence {
                if !isUnit(confidence) { errors.insert("invalidConfidence") }
                if confidence < 0.70 { errors.insert("lowConfidence") }
            } else {
                errors.insert("invalidConfidence")
            }
            if !isNull(output["unavailableReason"]) { errors.insert("invalidUnavailableResult") }
        case "unavailable":
            if score != nil || confidence != nil { errors.insert("invalidUnavailableResult") }
            if let reason = output["unavailableReason"] as? String {
                if !unavailableReasons.contains(reason) { errors.insert("invalidUnavailableReason") }
            } else {
                errors.insert("invalidUnavailableReason")
            }
        default:
            break
        }

        guard let provenance = output["provenance"] as? [String: Any] else {
            errors.insert("missingProvenance")
            return errors
        }
        for key in ["provider", "model", "evaluatorVersion", "schemaVersion", "promptVersion", "validatorVersion"] {
            if !((provenance[key] as? String)?.isEmpty == false) { errors.insert("invalidProvenance") }
        }
        if provenance["schemaVersion"] as? String != "writing-evaluation-v1" { errors.insert("invalidProvenance") }
        if provenance["promptVersion"] as? String != "writing-rubric-v1" { errors.insert("invalidProvenance") }

        let approval = output["approvalPolicy"] as? String
        if !["autoApproveAllowed", "humanReviewRequired"].contains(approval ?? "") { errors.insert("invalidApprovalPolicy") }
        if meaningStatus == "changed" && approval != "humanReviewRequired" { errors.insert("meaningChangeMustBeReviewed") }
        if outcome == "correct", optionalString(output["minimalCorrection"]) != nil { errors.insert("unnecessaryCorrection") }
        if output["canonicalContentAction"] as? String != "none" { errors.insert("canonicalMutation") }
        if output["masterySchedulingMutation"] as? Bool != false { errors.insert("learningMutation") }

        return errors
    }

    private static func requiredString(_ dictionary: [String: Any], _ key: String, errors: inout Set<String>) {
        guard let value = dictionary[key] as? String, !value.isEmpty else { errors.insert("missing\(key)") ; return }
    }

    private static func optionalString(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return value as? String
    }

    private static func optionalNumber(_ value: Any?) -> Double? {
        guard let value, !(value is NSNull), let number = value as? NSNumber,
              String(cString: number.objCType) != "c" else { return nil }
        return number.doubleValue
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let value, !(value is NSNull), let number = value as? NSNumber,
              String(cString: number.objCType) != "c" else { return nil }
        return number.doubleValue.rounded() == number.doubleValue ? number.intValue : nil
    }

    private static func isUnit(_ value: Double) -> Bool { value.isFinite && (0...1).contains(value) }
    private static func isNull(_ value: Any?) -> Bool { value == nil || value is NSNull }
}
