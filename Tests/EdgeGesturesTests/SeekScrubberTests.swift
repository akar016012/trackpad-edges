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

    func testOvershootPastALimitIsForgottenSoReversingRespondsAtOnce() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0, limits: -2...100)
        _ = scrubber.update(travel: -0.5, limits: -2...100)
        XCTAssertEqual(scrubber.steps, -2)
        XCTAssertTrue(scrubber.update(travel: -0.49, limits: -2...100))
        XCTAssertEqual(scrubber.steps, -1)
    }

    func testNoTickWhilePinnedAtALimit() {
        var scrubber = SeekScrubber()
        _ = scrubber.update(travel: 0, limits: -1...1)
        XCTAssertTrue(scrubber.update(travel: 0.06, limits: -1...1))
        XCTAssertFalse(scrubber.update(travel: 0.5, limits: -1...1))
        XCTAssertFalse(scrubber.update(travel: 0.9, limits: -1...1))
    }
}
