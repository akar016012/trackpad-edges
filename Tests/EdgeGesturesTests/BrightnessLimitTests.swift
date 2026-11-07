import XCTest

@testable import EdgeGestures

final class BrightnessLimitTests: XCTestCase {
    func testBuiltInDisplayStopsAtItsLimits() {
        XCTAssertTrue(BrightnessLimit.isReached(level: 1, up: true, pointerOnBuiltIn: true))
        XCTAssertTrue(BrightnessLimit.isReached(level: 0, up: false, pointerOnBuiltIn: true))
    }

    func testBuiltInDisplayCanLeaveALimit() {
        XCTAssertFalse(BrightnessLimit.isReached(level: 1, up: false, pointerOnBuiltIn: true))
        XCTAssertFalse(BrightnessLimit.isReached(level: 0, up: true, pointerOnBuiltIn: true))
        XCTAssertFalse(BrightnessLimit.isReached(level: 0.5, up: true, pointerOnBuiltIn: true))
    }

    func testBuiltInLevelSaysNothingAboutAnotherDisplay() {
        XCTAssertFalse(BrightnessLimit.isReached(level: 1, up: true, pointerOnBuiltIn: false))
        XCTAssertFalse(BrightnessLimit.isReached(level: 0, up: false, pointerOnBuiltIn: false))
    }

    func testBrightRoomStopsTheKeyboardInBothDirections() {
        XCTAssertTrue(BrightnessLimit.isKeyboardStopped(level: 0, isLocked: true, up: true))
        XCTAssertTrue(BrightnessLimit.isKeyboardStopped(level: 0.5, isLocked: true, up: false))
    }

    func testKeyboardStopsAtItsLimits() {
        XCTAssertTrue(BrightnessLimit.isKeyboardStopped(level: 1, isLocked: false, up: true))
        XCTAssertTrue(BrightnessLimit.isKeyboardStopped(level: 0, isLocked: false, up: false))
    }

    func testKeyboardMovesAwayFromALimit() {
        XCTAssertFalse(BrightnessLimit.isKeyboardStopped(level: 0, isLocked: false, up: true))
        XCTAssertFalse(BrightnessLimit.isKeyboardStopped(level: 1, isLocked: false, up: false))
    }

    func testUnknownKeyboardLevelIsNotALimit() {
        XCTAssertFalse(BrightnessLimit.isKeyboardStopped(level: nil, isLocked: false, up: true))
        XCTAssertFalse(BrightnessLimit.isKeyboardStopped(level: nil, isLocked: false, up: false))
    }

    func testBrightRoomStopsTheKeyboardWithAnUnknownLevel() {
        XCTAssertTrue(BrightnessLimit.isKeyboardStopped(level: nil, isLocked: true, up: true))
    }

    func testUnknownLevelIsNotALimit() {
        XCTAssertFalse(BrightnessLimit.isReached(level: nil, up: true, pointerOnBuiltIn: true))
    }
}
