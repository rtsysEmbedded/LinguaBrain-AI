import Foundation

public struct ReviewAnswerEvaluation: Sendable, Equatable {
    public let correct: Bool
    public let normalizedAnswer: String
    public let expectedAnswers: [String]

    public init(correct: Bool, normalizedAnswer: String, expectedAnswers: [String]) {
        self.correct = correct
        self.normalizedAnswer = normalizedAnswer
        self.expectedAnswers = expectedAnswers
    }
}

public enum ReviewAnswerEvaluator {
    /// German → source-language recognition. Matching is exact after safe
    /// whitespace/case normalization and accepts any approved meaning.
    public static func recognition(answer: String, acceptedMeanings: [String]) -> ReviewAnswerEvaluation {
        evaluate(answer: answer, expected: acceptedMeanings, caseSensitive: false)
    }

    /// Source-language → German active recall. Accents and punctuation are
    /// preserved semantically, while case/whitespace/punctuation noise is not.
    public static func reverseRecall(answer: String, acceptedForms: [String]) -> ReviewAnswerEvaluation {
        evaluate(answer: answer, expected: acceptedForms, caseSensitive: false)
    }

    private static func evaluate(answer: String, expected: [String], caseSensitive: Bool) -> ReviewAnswerEvaluation {
        let normalized = normalize(answer, caseSensitive: caseSensitive)
        let candidates = expected.map { normalize($0, caseSensitive: caseSensitive) }.filter { !$0.isEmpty }
        return ReviewAnswerEvaluation(correct: !normalized.isEmpty && candidates.contains(normalized), normalizedAnswer: normalized, expectedAnswers: candidates)
    }

    private static func normalize(_ value: String, caseSensitive: Bool) -> String {
        let folded = caseSensitive ? value : value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return folded.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\\p{Punctuation}]", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
