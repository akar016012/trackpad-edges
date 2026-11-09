import XCTest

@testable import EdgeGestures

final class StepCountTests: XCTestCase {
    func testTheFirstStepCountsAtTheLineInEitherDirection() {
        XCTAssertEqual(StepCount.count(at: 0.99, from: 0, direction: 0), 0)
        XCTAssertEqual(StepCount.count(at: 1.0, from: 0, direction: 0), 1)
        XCTAssertEqual(StepCount.count(at: -1.0, from: 0, direction: 0), -1)
    }

    func testAStepInTheSameDirectionCountsAtTheLine() {
        XCTAssertEqual(StepCount.count(at: 2.0, from: 1, direction: 1), 2)
        XCTAssertEqual(StepCount.count(at: 4.6, from: 1, direction: 1), 4)
        XCTAssertEqual(StepCount.count(at: -2.0, from: -1, direction: -1), -2)
    }

    func testTurningBackNeedsAQuarterStepPastTheLine() {
        // The line between 0 and 1 is at 1.0 on the way down.
        XCTAssertEqual(StepCount.count(at: 0.76, from: 1, direction: 1), 1)
        XCTAssertEqual(StepCount.count(at: 0.74, from: 1, direction: 1), 0)
        // Below zero, the line between -1 and 0 is at -1.0 on the way up.
        XCTAssertEqual(StepCount.count(at: -0.76, from: -1, direction: -1), -1)
        XCTAssertEqual(StepCount.count(at: -0.74, from: -1, direction: -1), 0)
        // Turning back up from a step that was reached on the way down.
        XCTAssertEqual(StepCount.count(at: 2.24, from: 1, direction: -1), 1)
        XCTAssertEqual(StepCount.count(at: 2.26, from: 1, direction: -1), 2)
    }

    func testTurningBackByMoreThanOneStepLandsOnThePlainCount() {
        XCTAssertEqual(StepCount.count(at: 0.5, from: 3, direction: 1), 0)
        XCTAssertEqual(StepCount.count(at: -2.5, from: 3, direction: 1), -2)
        XCTAssertEqual(StepCount.count(at: 3.1, from: -1, direction: -1), 3)
    }

    func testTheCountNeverTrailsThePlainCountByMoreThanOneStep() {
        for current in -3...3 {
            for direction in [-1, 0, 1] {
                for tenth in -50...50 {
                    let position = Float(tenth) / 10
                    let count = StepCount.count(at: position, from: current, direction: direction)
                    XCTAssertLessThanOrEqual(abs(count - Int(position)), 1)
                    XCTAssertTrue(count == Int(position) || count == current)
                }
            }
        }
    }
}
