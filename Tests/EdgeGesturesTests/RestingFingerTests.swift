import XCTest

@testable import EdgeGestures

/// Covers the wait that gives the pointer back when a finger rests in a strip.
final class RestingFingerTests: XCTestCase {
    private let released: [GestureEngine.Event] = [.slideCanceled(.seek), .pointerReleased]

    private func finger(_ x: Float, _ y: Float, id: Int32 = 1) -> [TouchPoint] {
        [TouchPoint(id: id, x: x, y: y)]
    }

    private func touchMode() -> GestureEngine {
        var engine = GestureEngine()
        engine.config.requireClick = false
        return engine
    }

    /// Lands a thumb on the bottom edge and leaves it there until the pointer comes back.
    private func restedThumb() -> GestureEngine {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        _ = engine.process(finger(0.5, 0.05), now: 0.6)
        return engine
    }

    func testRestingFingerGivesThePointerBack() {
        var engine = touchMode()
        XCTAssertEqual(engine.process(finger(0.5, 0.05), now: 0), [.slideBegan(.seek)])
        XCTAssertEqual(engine.process(finger(0.5, 0.05), now: 0.59), [])
        XCTAssertEqual(engine.process(finger(0.5, 0.05), now: 0.6), released)
        XCTAssertFalse(engine.isSliding)
        XCTAssertFalse(engine.isBusy)
    }

    func testTickReleasesARestingFingerWhenNoFrameArrives() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertEqual(engine.restReleaseRemaining(now: 0.2) ?? 0, 0.4, accuracy: 0.001)
        XCTAssertEqual(engine.tick(now: 0.5), [])
        XCTAssertEqual(engine.tick(now: 0.62), released)
        XCTAssertNil(engine.restReleaseRemaining(now: 0.62))
        XCTAssertEqual(engine.tick(now: 0.7), [])
    }

    func testSlowDriftBelowTheDeadZoneCountsAsResting() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertEqual(engine.process(finger(0.515, 0.05), now: 0.3), [])
        XCTAssertEqual(engine.process(finger(0.53, 0.05), now: 0.6), released)
    }

    func testSlowSlideThatHasStartedIsNeverReleased() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        // This passes the dead zone, so the slide has started, although no step has counted yet.
        XCTAssertEqual(engine.process(finger(0.95, 0.55), now: 0.3), [])
        XCTAssertNil(engine.restReleaseRemaining(now: 0.3))
        XCTAssertEqual(engine.process(finger(0.95, 0.56), now: 1), [])
        XCTAssertEqual(engine.tick(now: 2), [])
        XCTAssertTrue(engine.isSliding)
        XCTAssertEqual(engine.process(finger(0.95, 0.59), now: 3), [.stepped(1)])
    }

    func testFingerThatRestedCannotSlideUntilItLiftsAndLandsAgain() {
        var engine = restedThumb()
        XCTAssertEqual(engine.process(finger(0.6, 0.05), now: 0.8), [])
        XCTAssertEqual(engine.process(finger(0.7, 0.05), now: 1), [])
        XCTAssertFalse(engine.isSliding)
        // The same finger is not held back from an ordinary click either.
        XCTAssertFalse(engine.mouseDown(now: 1.1).swallow)
        _ = engine.process([], now: 1.2)
        XCTAssertEqual(engine.process(finger(0.5, 0.05, id: 2), now: 2), [.slideBegan(.seek)])
    }

    func testClickDuringTheWaitStillGoesThrough() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertTrue(engine.mouseDown(now: 0.2).swallow)
        XCTAssertEqual(
            engine.mouseUp(now: 0.3),
            GestureEngine.ClickResult(swallow: false, events: released + [.passthroughClick]))
        XCTAssertEqual(engine.process(finger(0.5, 0.05), now: 0.7), [])
    }

    func testClickStillHeldWhenTheWaitEndsIsDeliveredThen() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertTrue(engine.mouseDown(now: 0.2).swallow)
        XCTAssertEqual(engine.process(finger(0.5, 0.05), now: 0.6), released + [.passthroughClick])
        // The mouse-down has been delivered, so its mouse-up must reach other apps too.
        XCTAssertEqual(
            engine.mouseUp(now: 0.9), GestureEngine.ClickResult(swallow: false, events: []))
    }

    func testTickDeliversAHeldClickWhenTheWaitEnds() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertTrue(engine.mouseDown(now: 0.2).swallow)
        XCTAssertEqual(engine.tick(now: 0.62), released + [.passthroughClick])
        XCTAssertFalse(engine.isBusy)
    }

    func testReleasedSlideThatAClickStartedDoesNotStartAgain() {
        var engine = touchMode()
        /* The required key is up at landing, so the landing waits, and a click with the key
           down then starts the slide and leaves that landing in place. */
        XCTAssertEqual(engine.process(finger(0.95, 0.5), now: 0, modifierSatisfied: false), [])
        XCTAssertTrue(engine.mouseDown(now: 0.1).swallow)
        XCTAssertEqual(
            engine.process(finger(0.95, 0.5), now: 0.7),
            [.slideCanceled(.volume), .pointerReleased, .passthroughClick])
        XCTAssertEqual(engine.process(finger(0.95, 0.5), now: 0.71), [])
        XCTAssertFalse(engine.isSliding)
    }

    func testRestedFingerThatLosesContactBesideAPalmIsStillRested() {
        var engine = restedThumb()
        let palm = TouchPoint(id: 9, x: 0.3, y: 0.5, size: 2)
        XCTAssertEqual(engine.process(finger(0.5, 0.05) + [palm], now: 0.7), [])
        XCTAssertEqual(engine.process([palm], now: 0.8), [])
        XCTAssertEqual(engine.process(finger(0.5, 0.05, id: 2) + [palm], now: 0.9), [])
        XCTAssertFalse(engine.isSliding)
    }

    func testSlideThatStartedWithAClickIsNotReleased() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        XCTAssertTrue(engine.mouseDown(now: 0.1).swallow)
        XCTAssertNil(engine.restReleaseRemaining(now: 0.2))
        XCTAssertEqual(engine.process(finger(0.95, 0.5), now: 1), [])
        XCTAssertEqual(engine.tick(now: 2), [])
        XCTAssertTrue(engine.isSliding)
    }

    func testRestingPairGivesThePointerBack() {
        var engine = touchMode()
        engine.config.cornerCounts = [:]
        engine.config.rightAction = nil
        engine.config.twoFingerActions = [.right: .brightness]
        let pair = [TouchPoint(id: 1, x: 0.95, y: 0.4), TouchPoint(id: 2, x: 0.95, y: 0.55)]
        XCTAssertEqual(engine.process(pair, now: 0), [.slideBegan(.brightness)])
        XCTAssertEqual(
            engine.process(pair, now: 0.6), [.slideCanceled(.brightness), .pointerReleased])
        let moved = [TouchPoint(id: 1, x: 0.95, y: 0.6), TouchPoint(id: 2, x: 0.95, y: 0.75)]
        XCTAssertEqual(engine.process(moved, now: 0.8), [])
        XCTAssertFalse(engine.isSliding)
    }

    func testContactThatDropsOutDoesNotStartTheWaitOver() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertEqual(engine.process([], now: 0.3), [])
        XCTAssertEqual(engine.process(finger(0.5, 0.05, id: 2), now: 0.4), [])
        XCTAssertEqual(engine.process(finger(0.5, 0.05, id: 2), now: 0.6), released)
    }

    func testRestedFingerThatLosesContactDoesNotFreezeThePointerAgain() {
        var engine = restedThumb()
        XCTAssertEqual(engine.process([], now: 0.7), [])
        XCTAssertEqual(engine.process(finger(0.52, 0.05, id: 2), now: 0.8), [])
        XCTAssertFalse(engine.isSliding)
        // The contact that returned is still the rested finger, so moving it does nothing.
        XCTAssertEqual(engine.process(finger(0.7, 0.05, id: 2), now: 1.2), [])
    }

    func testAnotherFingerCanSlideRightAfterARestedFingerLifts() {
        var engine = restedThumb()
        _ = engine.process([], now: 0.7)
        XCTAssertEqual(engine.process(finger(0.95, 0.5, id: 2), now: 0.8), [.slideBegan(.volume)])
    }

    func testRestedFingerCanSlideAgainOnceItHasStayedAway() {
        var engine = restedThumb()
        _ = engine.process([], now: 0.7)
        XCTAssertEqual(engine.process(finger(0.5, 0.05, id: 2), now: 0.9), [.slideBegan(.seek)])
    }
}
