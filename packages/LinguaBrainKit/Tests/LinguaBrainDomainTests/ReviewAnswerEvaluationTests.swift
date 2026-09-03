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

    func testMissionPreservesUserDefinedDomainAndClampsWeight() {
        let mission = LearningMission(id: "m1", title: "Embedded German", domain: "Embedded Linux", targetLevel: "B2", weight: 2)
        XCTAssertEqual(mission.domain, "Embedded Linux")
        XCTAssertEqual(mission.weight, 1)
    }
}
