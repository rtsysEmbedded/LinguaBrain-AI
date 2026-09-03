import XCTest
@testable import LinguaBrainDomain

final class ReviewAnswerEvaluationTests: XCTestCase {
    func testRecognitionAcceptsAnyApprovedMeaning() {
        XCTAssertTrue(ReviewAnswerEvaluator.recognition(answer: "کار کردن", acceptedMeanings: ["کار کردن", "شاغل بودن"]).correct)
    }

    func testReverseRecallIgnoresCasePunctuationAndWhitespace() {
        XCTAssertTrue(ReviewAnswerEvaluator.reverseRecall(answer: "  Arbeiten! ", acceptedForms: ["arbeiten"]).correct)
    }

    func testWrongAnswerIsRejected() {
        XCTAssertFalse(ReviewAnswerEvaluator.reverseRecall(answer: "gehen", acceptedForms: ["arbeiten"]).correct)
    }
}
