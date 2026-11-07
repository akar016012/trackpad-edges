import XCTest

@testable import EdgeGestures

final class GestureEngineTests: XCTestCase {
    private func finger(_ x: Float, _ y: Float, id: Int32 = 1) -> [TouchPoint] {
        [TouchPoint(id: id, x: x, y: y)]
    }

    private func pressed(_ x: Float, _ y: Float, config: GestureConfig = GestureConfig())
        -> GestureEngine
    {
        var engine = GestureEngine()
        engine.config = config
        _ = engine.process(finger(x, y))
        _ = engine.mouseDown()
        return engine
    }

    private func lift(_ engine: inout GestureEngine) -> [GestureEngine.Event] {
        engine.process([], now: 0) + engine.tick(now: 1)
    }

    private func touchMode() -> GestureEngine {
        var engine = GestureEngine()
        engine.config.requireClick = false
        return engine
    }

    func testTouchModeStartsASlideOnLanding() {
        var engine = touchMode()
        XCTAssertEqual(engine.process(finger(0.95, 0.5), now: 0), [.slideBegan(.volume)])
        XCTAssertEqual(engine.process(finger(0.95, 0.56), now: 0.1), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.64), now: 0.2), [.stepped(2)])
        XCTAssertEqual(lift(&engine), [.slideEnded(.volume), .pointerReleased])
    }

    func testTapNeverChangesTheLevelEvenIfTheContactWobbles() {
        var engine = touchMode()
        _ = engine.process(finger(0.98, 0.9), now: 0)
        XCTAssertEqual(engine.process(finger(0.98, 0.83), now: 0.03), [])
        XCTAssertEqual(engine.process(finger(0.98, 0.76), now: 0.06), [])
        XCTAssertEqual(lift(&engine), [.slideCanceled(.volume), .pointerReleased])
    }

    func testQuickTapsAtBothEndsOfTheStripDoNotJumpTheLevel() {
        var engine = touchMode()
        _ = engine.process(finger(0.98, 0.2), now: 0)
        _ = engine.process([], now: 0.05)
        XCTAssertEqual(engine.process(finger(0.98, 0.9, id: 2), now: 0.1), [])
        XCTAssertEqual(engine.process(finger(0.98, 0.9, id: 2), now: 0.2), [])
        _ = engine.process([], now: 0.25)
        XCTAssertEqual(engine.tick(now: 1), [.slideCanceled(.volume), .pointerReleased])
    }

    func testCrossingTheDeadZoneDoesNotJumpTheLevel() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        XCTAssertEqual(engine.process(finger(0.95, 0.6), now: 0.2), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.63), now: 0.3), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.64), now: 0.4), [.stepped(1)])
    }

    func testGlitchInASlideDoesNotChangeTheLevel() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(engine.process(finger(0.95, 0.54)), [.stepped(1)])
        XCTAssertEqual(engine.process(finger(0.95, 0.9)), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.94)), [.stepped(1)])
    }

    func testTouchModeIgnoresAFingerThatMovedIntoTheStrip() {
        var engine = touchMode()
        XCTAssertEqual(engine.process(finger(0.5, 0.5)), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.5)), [])
    }

    func testTouchModeDoesNotRestartACanceledSlide() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5))
        XCTAssertEqual(
            engine.process(finger(0.5, 0.5)), [.slideCanceled(.volume), .pointerReleased])
        XCTAssertEqual(engine.process(finger(0.95, 0.5)), [])
    }

    func testTouchModeRespectsTheRequiredModifier() {
        var engine = touchMode()
        XCTAssertEqual(engine.process(finger(0.95, 0.5), modifierSatisfied: false), [])
    }

    func testTouchModeReplaysAClickMadeDuringAnUnmovedSlide() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5))
        XCTAssertTrue(engine.mouseDown().swallow)
        XCTAssertEqual(
            engine.mouseUp(now: 0),
            GestureEngine.ClickResult(
                swallow: false,
                events: [.slideCanceled(.volume), .pointerReleased, .passthroughClick]))
    }

    func testBriefContactLossDoesNotEndASlide() {
        var engine = touchMode()
        _ = engine.process(finger(0.98, 0.9), now: 0)
        _ = engine.process(finger(0.98, 0.8), now: 0.1)
        XCTAssertEqual(engine.process([], now: 0.2), [])
        XCTAssertEqual(engine.tick(now: 0.3), [])
        XCTAssertEqual(engine.process(finger(0.98, 0.73, id: 2), now: 0.3), [])
        XCTAssertTrue(engine.isSliding)
        XCTAssertEqual(engine.process(finger(0.98, 0.65, id: 2), now: 0.4), [.stepped(-2)])
    }

    func testLongContactLossEndsASlide() {
        var engine = touchMode()
        _ = engine.process(finger(0.98, 0.9), now: 0)
        _ = engine.process(finger(0.98, 0.8), now: 0.1)
        XCTAssertEqual(engine.process(finger(0.98, 0.7), now: 0.15), [.stepped(-2)])
        _ = engine.process([], now: 0.2)
        XCTAssertEqual(engine.tick(now: 0.5), [.slideEnded(.volume), .pointerReleased])
    }

    func testClickAfterTheDeadZoneOpensIsStillReplayed() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        XCTAssertTrue(engine.mouseDown(now: 0.05).swallow)
        _ = engine.process(finger(0.95, 0.545), now: 0.1)
        XCTAssertEqual(
            engine.mouseUp(now: 0.2),
            GestureEngine.ClickResult(
                swallow: false,
                events: [.slideCanceled(.volume), .pointerReleased, .passthroughClick]))
    }

    func testDiagonalStrokeOutOfTheStripReleasesThePointerRightAway() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        _ = engine.process(finger(0.91, 0.545), now: 0.1)
        XCTAssertEqual(
            engine.process(finger(0.86, 0.57), now: 0.15),
            [.slideCanceled(.volume), .pointerReleased])
    }

    func testMostlySidewaysMovementNeverSteps() {
        var engine = touchMode()
        _ = engine.process(finger(0.98, 0.5), now: 0)
        XCTAssertEqual(engine.process(finger(0.91, 0.55), now: 0.1), [])
        XCTAssertEqual(engine.process(finger(0.89, 0.56), now: 0.2), [])
    }

    func testFingerLandingMidPadDuringGraceEndsTheSlideAndFreesThePointer() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        _ = engine.process(finger(0.95, 0.56), now: 0.1)
        _ = engine.process(finger(0.95, 0.64), now: 0.15)
        _ = engine.process([], now: 0.2)
        XCTAssertEqual(
            engine.process(finger(0.5, 0.5, id: 2), now: 0.25),
            [.slideEnded(.volume), .pointerReleased])
        XCTAssertFalse(engine.isBusy)
    }

    func testFingerLandingOnTheOtherStripDuringGraceStartsItsOwnSlide() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        _ = engine.process([], now: 0.05)
        XCTAssertEqual(
            engine.process(finger(0.05, 0.5, id: 2), now: 0.1),
            [.slideCanceled(.volume), .pointerReleased, .slideBegan(.brightness)])
    }

    func testTwoFingersDuringGraceEndTheSlide() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), now: 0)
        _ = engine.process([], now: 0.05)
        XCTAssertEqual(
            engine.process(finger(0.95, 0.5, id: 2) + finger(0.5, 0.5, id: 3), now: 0.1),
            [.slideCanceled(.volume), .pointerReleased])
    }

    func testQuickSecondTapMustSettleEvenIfItWobbles() {
        var engine = touchMode()
        _ = engine.process(finger(0.98, 0.9), now: 0)
        _ = engine.process([], now: 0.05)
        XCTAssertEqual(engine.process(finger(0.98, 0.9, id: 2), now: 0.1), [])
        XCTAssertEqual(engine.process(finger(0.98, 0.83, id: 2), now: 0.13), [])
        XCTAssertEqual(engine.process(finger(0.98, 0.76, id: 2), now: 0.16), [])
    }

    func testDrainEndsWhenTheSlidesFingerLiftsEvenIfAnotherRests() {
        var engine = pressed(0.95, 0.5)
        _ = engine.process(finger(0.95, 0.54))
        let thumb = finger(0.5, 0.1, id: 2)
        XCTAssertEqual(engine.process(finger(0.95, 0.54) + thumb), [.slideCanceled(.volume)])
        XCTAssertEqual(engine.process(finger(0.95, 0.54) + thumb), [])
        XCTAssertEqual(engine.process(thumb), [.pointerReleased])
    }

    func testTouchSlideDoesNotStartAfterTheFingerLeftTheZone() {
        var engine = touchMode()
        _ = engine.process(finger(0.95, 0.5), modifierSatisfied: false)
        _ = engine.process(finger(0.5, 0.5), modifierSatisfied: false)
        XCTAssertEqual(engine.process(finger(0.5, 0.5), modifierSatisfied: true), [])
    }

    func testTouchModeSeekReportsFullTravelOnceItEngages() {
        var engine = touchMode()
        XCTAssertEqual(engine.process(finger(0.5, 0.05), now: 0), [.slideBegan(.seek)])
        XCTAssertEqual(engine.process(finger(0.52, 0.05), now: 0.1), [])
        XCTAssertEqual(engine.process(finger(0.56, 0.05), now: 0.2).count, 1)
        XCTAssertEqual(lift(&engine), [.slideEnded(.seek), .pointerReleased])
    }

    func testZonePriorityPutsCornersFirstAndBottomBeforeSides() {
        var config = GestureConfig()
        config.topRightClicks = 2
        XCTAssertEqual(config.zone(x: 0.05, y: 0.95), .topLeft)
        XCTAssertEqual(config.zone(x: 0.95, y: 0.95), .topRight)
        XCTAssertEqual(config.zone(x: 0.05, y: 0.05), .bottom)
        XCTAssertEqual(config.zone(x: 0.95, y: 0.05), .bottom)
        XCTAssertEqual(config.zone(x: 0.05, y: 0.5), .left)
        XCTAssertEqual(config.zone(x: 0.95, y: 0.5), .right)
        XCTAssertNil(config.zone(x: 0.5, y: 0.5))
    }

    func testCornerWithoutActionFallsBackToTheEdgeBelowIt() {
        let config = GestureConfig()
        XCTAssertEqual(config.zone(x: 0.95, y: 0.95), .right)
        XCTAssertNil(config.zone(x: 0.5, y: 0.95))
    }

    func testSeekSurvivesDriftAfterItHasStarted() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        _ = engine.process(finger(0.56, 0.05), now: 0.1)
        XCTAssertEqual(engine.process(finger(0.6, 0.3), now: 0.2).count, 1)
        XCTAssertTrue(engine.isSliding)
    }

    func testDriftedSlideSurvivesBriefContactLoss() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        _ = engine.process(finger(0.56, 0.05), now: 0.1)
        _ = engine.process(finger(0.6, 0.15), now: 0.15)
        _ = engine.process(finger(0.62, 0.25), now: 0.2)
        _ = engine.process([], now: 0.25)
        _ = engine.process(finger(0.63, 0.27, id: 2), now: 0.3)
        XCTAssertTrue(engine.isSliding)
    }

    func testDriftBeforeASlideStartsStillCancels() {
        var engine = touchMode()
        _ = engine.process(finger(0.5, 0.05), now: 0)
        XCTAssertEqual(
            engine.process(finger(0.5, 0.2), now: 0.1), [.slideCanceled(.seek), .pointerReleased])
    }

    func testBottomCornersTakePriorityOnlyWhenTheyHaveAnAction() {
        var config = GestureConfig()
        XCTAssertEqual(config.zone(x: 0.05, y: 0.05), .bottom)
        XCTAssertEqual(config.zone(x: 0.95, y: 0.12), .right)
        config.bottomLeftClicks = 1
        config.bottomRightClicks = 2
        XCTAssertEqual(config.zone(x: 0.05, y: 0.05), .bottomLeft)
        XCTAssertEqual(config.zone(x: 0.95, y: 0.12), .bottomRight)
        XCTAssertEqual(config.zone(x: 0.5, y: 0.05), .bottom)
        XCTAssertEqual(config.clicks(for: .bottomRight), 2)
    }

    func testBottomCornerFiresOnClickEvenInTouchMode() {
        var engine = GestureEngine()
        engine.config.requireClick = false
        engine.config.bottomRightClicks = 1
        XCTAssertEqual(engine.process(finger(0.95, 0.05)), [])
        XCTAssertTrue(engine.mouseDown().swallow)
        XCTAssertEqual(engine.mouseUp(now: 1).events, [.cornerFired(.bottomRight)])
    }

    func testBottomQuarterOnlyLimitsTheSideEdges() {
        var config = GestureConfig()
        config.bottomQuarterOnly = true
        XCTAssertEqual(config.zone(x: 0.95, y: 0.2), .right)
        XCTAssertNil(config.zone(x: 0.95, y: 0.5))
    }

    func testEdgesCanBeReassignedOrTurnedOff() {
        var config = GestureConfig()
        config.rightAction = .brightness
        config.leftAction = nil
        XCTAssertEqual(config.slideKind(for: .right), .brightness)
        XCTAssertNil(config.zone(x: 0.05, y: 0.5))
    }

    func testBottomEdgeCanDriveStepsAlongItsLength() {
        var config = GestureConfig()
        config.bottomAction = .volume
        var engine = pressed(0.5, 0.05, config: config)
        XCTAssertEqual(engine.process(finger(0.58, 0.05)), [.stepped(2)])
    }

    func testDisabledBrightnessLeavesThatEdgeNormal() {
        var config = GestureConfig()
        config.brightnessAvailable = false
        XCTAssertNil(config.zone(x: 0.05, y: 0.5))
        XCTAssertEqual(config.zone(x: 0.95, y: 0.5), .right)
    }

    func testTouchAloneNeverStartsASlide() {
        var engine = GestureEngine()
        XCTAssertEqual(engine.process(finger(0.95, 0.5)), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.8)), [])
        XCTAssertFalse(engine.isSliding)
    }

    func testClickInStripStartsASlideAndStepsFollowTheFinger() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.95, 0.5))
        XCTAssertEqual(
            engine.mouseDown(),
            GestureEngine.ClickResult(swallow: true, events: [.slideBegan(.volume)]))
        XCTAssertEqual(engine.process(finger(0.95, 0.52)), [])
        XCTAssertEqual(engine.process(finger(0.95, 0.58)), [.stepped(2)])
        XCTAssertEqual(engine.process(finger(0.95, 0.5)), [.stepped(-2)])
        XCTAssertEqual(lift(&engine), [.slideEnded(.volume), .pointerReleased])
    }

    func testClickInMiddlePassesThrough() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.5, 0.5))
        XCTAssertFalse(engine.mouseDown().swallow)
        XCTAssertFalse(engine.mouseUp(now: 0).swallow)
    }

    func testFingerThatMovedIntoTheStripDoesNotCount() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.5, 0.5))
        _ = engine.process(finger(0.95, 0.5))
        XCTAssertFalse(engine.mouseDown().swallow)
    }

    func testClickWithoutSlidePassesThroughOnRelease() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(
            engine.mouseUp(now: 0),
            GestureEngine.ClickResult(
                swallow: false,
                events: [.slideCanceled(.volume), .pointerReleased, .passthroughClick]))
        XCTAssertFalse(engine.isSliding)
    }

    func testFingerLiftingBeforeMouseUpStillPassesTheClickThrough() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(
            lift(&engine), [.slideCanceled(.volume), .pointerReleased, .passthroughClick])
        XCTAssertEqual(engine.mouseUp(now: 0), GestureEngine.ClickResult(swallow: false, events: []))
    }

    func testSlideContinuesAfterMouseUpOnceItHasMoved() {
        var engine = pressed(0.95, 0.5)
        _ = engine.process(finger(0.95, 0.54))
        XCTAssertEqual(
            engine.mouseUp(now: 0), GestureEngine.ClickResult(swallow: true, events: []))
        XCTAssertEqual(engine.process(finger(0.95, 0.58)), [.stepped(1)])
        XCTAssertEqual(lift(&engine), [.slideEnded(.volume), .pointerReleased])
    }

    func testLeavingTheStripAfterMovingKeepsThePointerFrozenUntilLift() {
        var engine = pressed(0.95, 0.5)
        _ = engine.process(finger(0.95, 0.54))
        XCTAssertEqual(engine.process(finger(0.5, 0.54)), [.slideCanceled(.volume)])
        XCTAssertEqual(
            engine.mouseUp(now: 0), GestureEngine.ClickResult(swallow: true, events: []))
        XCTAssertEqual(engine.process(finger(0.4, 0.54)), [])
        XCTAssertEqual(engine.process([]), [.pointerReleased])
    }

    func testLeavingTheStripBeforeMovingReplaysTheClick() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(
            engine.process(finger(0.5, 0.5)),
            [.slideCanceled(.volume), .pointerReleased, .passthroughClick])
        XCTAssertEqual(engine.mouseUp(now: 0), GestureEngine.ClickResult(swallow: false, events: []))
    }

    func testSecondPressDuringAMovedSlideStaysInTheSlide() {
        var engine = pressed(0.95, 0.5)
        _ = engine.process(finger(0.95, 0.54))
        _ = engine.mouseUp(now: 0)
        XCTAssertEqual(engine.mouseDown(), GestureEngine.ClickResult(swallow: true, events: []))
        XCTAssertEqual(
            engine.mouseUp(now: 1), GestureEngine.ClickResult(swallow: true, events: []))
        XCTAssertTrue(engine.isSliding)
        XCTAssertEqual(engine.process(finger(0.95, 0.58)), [.stepped(1)])
    }

    func testPressWhileDrainingIsSwallowed() {
        var engine = pressed(0.95, 0.5)
        _ = engine.process(finger(0.95, 0.54))
        _ = engine.process(finger(0.5, 0.54))
        _ = engine.mouseUp(now: 0)
        XCTAssertTrue(engine.mouseDown().swallow)
        XCTAssertTrue(engine.mouseUp(now: 1).swallow)
    }

    func testLostMouseUpEndsAnUnmovedSlideWithoutAReplay() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(engine.mouseUpLost(), [.slideCanceled(.volume), .pointerReleased])
        XCTAssertFalse(engine.isBusy)
    }

    func testLostMouseUpLeavesAMovedSlideRunning() {
        var engine = pressed(0.95, 0.5)
        _ = engine.process(finger(0.95, 0.54))
        XCTAssertEqual(engine.mouseUpLost(), [])
        XCTAssertTrue(engine.isSliding)
    }

    func testLostMouseUpForgetsACornerPress() {
        var engine = pressed(0.05, 0.95)
        _ = engine.mouseUpLost()
        XCTAssertFalse(engine.mouseUp(now: 0).swallow)
    }

    func testStrayJustPastTheLimitCancels() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(
            engine.process(finger(0.86, 0.5)),
            [.slideCanceled(.volume), .pointerReleased, .passthroughClick])
    }

    func testSmallStrayPastTheStripDoesNotCancel() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(engine.process(finger(0.88, 0.5)), [])
        XCTAssertTrue(engine.isSliding)
    }

    func testAbortReleasesThePointerAndForgetsTheClick() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(engine.abort(), [.slideCanceled(.volume), .pointerReleased])
        XCTAssertFalse(engine.mouseUp(now: 0).swallow)
    }

    func testSecondFingerCancelsASlide() {
        var engine = pressed(0.95, 0.5)
        XCTAssertEqual(
            engine.process(finger(0.95, 0.5) + finger(0.5, 0.5, id: 2)),
            [.slideCanceled(.volume), .pointerReleased, .passthroughClick])
    }

    func testMultipleFingersNeverStartAGesture() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.95, 0.5) + finger(0.5, 0.5, id: 2))
        XCTAssertFalse(engine.mouseDown().swallow)
    }

    func testRestingSecondFingerThatLiftsDoesNotReviveTheLanding() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.95, 0.5))
        _ = engine.process(finger(0.95, 0.5) + finger(0.5, 0.5, id: 2))
        _ = engine.process(finger(0.95, 0.5))
        XCTAssertFalse(engine.mouseDown().swallow)
    }

    func testRequiredModifierBlocksSlides() {
        var engine = GestureEngine()
        _ = engine.process(finger(0.95, 0.5))
        XCTAssertFalse(engine.mouseDown(modifierSatisfied: false).swallow)
        XCTAssertFalse(engine.mouseUp(now: 0).swallow)
    }

    func testSeekWaitsForTheDeadZoneAndReportsTheDelta() {
        var engine = pressed(0.5, 0.05)
        XCTAssertEqual(engine.process(finger(0.51, 0.05)), [])
        XCTAssertEqual(engine.process(finger(0.6, 0.05)), [.seekMoved(0.6 - 0.5)])
        XCTAssertEqual(lift(&engine), [.slideEnded(.seek), .pointerReleased])
    }

    func testSingleClickCornerFiresOnRelease() {
        var engine = pressed(0.05, 0.95)
        XCTAssertEqual(
            engine.mouseUp(now: 1),
            GestureEngine.ClickResult(swallow: true, events: [.cornerFired(.topLeft)]))
    }

    func testMultiClickCornerFiresOnlyOnTheLastClick() {
        var config = GestureConfig()
        config.topRightClicks = 3
        var engine = GestureEngine()
        engine.config = config
        for (index, time) in [0.0, 0.3, 0.6].enumerated() {
            _ = engine.process([])
            _ = engine.process(finger(0.95, 0.95))
            XCTAssertTrue(engine.mouseDown().swallow)
            let expected: [GestureEngine.Event] = index == 2 ? [.cornerFired(.topRight)] : []
            XCTAssertEqual(engine.mouseUp(now: time).events, expected)
        }
    }

    func testSlowCornerClicksRestartTheCount() {
        var config = GestureConfig()
        config.topRightClicks = 2
        var engine = GestureEngine()
        engine.config = config
        for time in [0.0, 1.0] {
            _ = engine.process([])
            _ = engine.process(finger(0.95, 0.95))
            _ = engine.mouseDown()
            XCTAssertEqual(engine.mouseUp(now: time).events, [])
        }
    }
}
