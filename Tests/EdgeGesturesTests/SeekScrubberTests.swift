import XCTest

@testable import EdgeGestures

final class SeekScrubberTests: XCTestCase {
    func testPercentStepScalesWithTheTrack() {
        XCTAssertEqual(SeekStep.percent(1).length(duration: 600), 6)
        XCTAssertEqual(SeekStep.percent(1).length(duration: 7200), 72)
    }

    func testSecondsStepIgnoresTheTrackLength() {
        XCTAssertEqual(SeekStep.seconds(5).length(duration: 600), 5)
        XCTAssertEqual(SeekStep.seconds(5).length(duration: 7200), 5)
    }

    func testFirstUpdateSetsTheStartWithoutAStep() {
        var scrubber = SeekScrubber()
        XCTAssertFalse(scrubber.update(travel: 0.04))
        XCTAssertEqual(scrubber.steps, 0)
    }

    func testStepsFollowTravelOnly() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0)
        XCTAssertFalse(scrubber.update(travel: 0.04))
        XCTAssertTrue(scrubber.update(travel: 0.06))
        XCTAssertEqual(scrubber.steps, 1)
        XCTAssertTrue(scrubber.update(travel: 0.26))
        XCTAssertEqual(scrubber.steps, 5)
    }

    func testTheSameSlideAlwaysMovesTheSameAmount() {
        var coarse = SeekScrubber()
        var fine = SeekScrubber()
        _ = coarse.update(travel: 0)
        _ = coarse.update(travel: 0.31)
        _ = fine.update(travel: 0)
        for frame in 1...31 { _ = fine.update(travel: Float(frame) * 0.01) }
        XCTAssertEqual(coarse.steps, fine.steps)
    }

    func testSlidingBackwardGivesNegativeSteps() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0.5)
        _ = scrubber.update(travel: 0.39)
        XCTAssertEqual(scrubber.steps, -2)
    }

    func testReversingUndoesSteps() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0)
        _ = scrubber.update(travel: 0.21)
        _ = scrubber.update(travel: 0.01)
        XCTAssertEqual(scrubber.steps, 0)
    }

    func testOvershootPastALimitIsForgottenSoReversingRespondsSoon() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0, limits: -2...100)
        _ = scrubber.update(travel: -0.5, limits: -2...100)
        XCTAssertEqual(scrubber.steps, -2)
        XCTAssertTrue(scrubber.update(travel: -0.48, limits: -2...100))
        XCTAssertEqual(scrubber.steps, -1)
    }

    func testWobbleWhilePinnedAtALimitDoesNotFlicker() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0, limits: -2...100)
        _ = scrubber.update(travel: -0.5, limits: -2...100)
        for frame in 0..<10 {
            let travel: Float = frame % 2 == 0 ? -0.499 : -0.5
            XCTAssertFalse(scrubber.update(travel: travel, limits: -2...100))
        }
        XCTAssertEqual(scrubber.steps, -2)
    }

    func testWobbleOnAStepLineCountsOnce() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0)
        var changes = 0
        for frame in 0..<10 {
            let travel: Float = 0.05 + (frame % 2 == 0 ? 0.0005 : -0.0005)
            if scrubber.update(travel: travel) { changes += 1 }
        }
        XCTAssertEqual(changes, 1)
        XCTAssertEqual(scrubber.steps, 1)
    }

    func testLimitsThatArriveLateKeepTheMarginAgainstTheFinger() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0)
        _ = scrubber.update(travel: -0.16)
        XCTAssertEqual(scrubber.steps, -3)
        // The limits pull the count toward zero, but the finger was still moving away from it.
        XCTAssertTrue(scrubber.update(travel: -0.16, limits: -1...50))
        XCTAssertEqual(scrubber.steps, -1)
        XCTAssertFalse(scrubber.update(travel: -0.1494, limits: -1...50))
        XCTAssertEqual(scrubber.steps, -1)
    }

    func testLimitsThatArriveLateHoldTheCount() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0)
        _ = scrubber.update(travel: 0.52)
        XCTAssertEqual(scrubber.steps, 10)
        _ = scrubber.update(travel: 0.52, limits: -3...4)
        XCTAssertEqual(scrubber.steps, 4)
    }

    func testNoTickWhilePinnedAtALimit() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0, limits: -1...1)
        XCTAssertTrue(scrubber.update(travel: 0.06, limits: -1...1))
        XCTAssertFalse(scrubber.update(travel: 0.5, limits: -1...1))
        XCTAssertFalse(scrubber.update(travel: 0.9, limits: -1...1))
    }
}
