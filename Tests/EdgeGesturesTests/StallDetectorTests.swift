import XCTest

@testable import EdgeGestures

final class StallDetectorTests: XCTestCase {
    func testRegularBeatsAreNotAStall() {
        var detector = StallDetector(now: 0)
        XCTAssertFalse(detector.check(now: 0.5))
        XCTAssertFalse(detector.beat(now: 0.5))
        XCTAssertFalse(detector.check(now: 1.1))
    }

    func testSilenceBeyondTheLimitIsAStall() {
        var detector = StallDetector(now: 0)
        XCTAssertTrue(detector.check(now: 0.8))
    }

    func testAStallIsReportedOnce() {
        var detector = StallDetector(now: 0)
        XCTAssertTrue(detector.check(now: 0.8))
        XCTAssertFalse(detector.check(now: 2))
    }

    func testBeatReportsTheEndOfAStall() {
        var detector = StallDetector(now: 0)
        _ = detector.check(now: 0.8)
        XCTAssertTrue(detector.beat(now: 3))
        XCTAssertFalse(detector.beat(now: 3.25))
    }

    func testANewStallCanFollowARecovery() {
        var detector = StallDetector(now: 0)
        _ = detector.check(now: 0.8)
        _ = detector.beat(now: 1)
        XCTAssertFalse(detector.check(now: 1.5))
        XCTAssertTrue(detector.check(now: 1.9))
    }
}
