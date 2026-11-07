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

    func testUnknownLevelIsNotALimit() {
        XCTAssertFalse(BrightnessLimit.isReached(level: nil, up: true, pointerOnBuiltIn: true))
    }
}
