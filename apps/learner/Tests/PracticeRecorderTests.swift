import XCTest
@testable import LinguaBrain

@MainActor
final class PracticeRecorderTests: XCTestCase {
    func testConfigurationClampsDurationAndDefaultsToTemporaryRetention() {
        let short = ApplePracticeRecorder(maximumDuration: 0)
        XCTAssertEqual(short.metadata.maximumDuration, 1)
        XCTAssertFalse(short.metadata.retained)

        let long = ApplePracticeRecorder(maximumDuration: 500, retainRecording: true)
        XCTAssertEqual(long.metadata.maximumDuration, 120)
        XCTAssertTrue(long.metadata.retained)
    }

    func testReplayWithoutRecordingFailsExplicitly() {
        let recorder = ApplePracticeRecorder()
        XCTAssertThrowsError(try recorder.replayLastRecording()) { error in
            XCTAssertEqual(error as? ApplePracticeRecorderError, .recordingFailed)
        }
    }
}
