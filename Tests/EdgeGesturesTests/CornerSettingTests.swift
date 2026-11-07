import XCTest

@testable import EdgeGestures

final class CornerSettingTests: XCTestCase {
    func testOldSavedCornerLoadsItsActionAtItsClickCount() throws {
        let saved = Data(#"{"action":{"mute":{}},"clicks":2}"#.utf8)
        let corner = try JSONDecoder().decode(CornerSetting.self, from: saved)
        XCTAssertEqual(corner[2], .mute)
        XCTAssertEqual(corner[1], CornerAction.none)
        XCTAssertEqual(corner.configuredClicks, [2])
    }

    func testCornerKeepsEveryActionThroughSaving() throws {
        var corner = CornerSetting(action: .playPause, clicks: 1)
        corner[2] = .nextTrack
        let data = try JSONEncoder().encode(corner)
        XCTAssertEqual(try JSONDecoder().decode(CornerSetting.self, from: data), corner)
    }

    func testSavedListOfTheWrongLengthIsRepaired() throws {
        let saved = Data(#"{"actions":[{"mute":{}}]}"#.utf8)
        let corner = try JSONDecoder().decode(CornerSetting.self, from: saved)
        XCTAssertEqual(corner[1], .mute)
        XCTAssertEqual(corner[4], CornerAction.none)
    }

    func testUnfinishedActionDoesNotCount() {
        var corner = CornerSetting(action: .mute, clicks: 1)
        corner[3] = .openApp(path: "")
        XCTAssertEqual(corner.configuredClicks, [1])
    }

    func testClickCountsOutsideTheRangeAreIgnored() {
        var corner = CornerSetting(action: .mute, clicks: 1)
        corner[9] = .mute
        XCTAssertEqual(corner[9], CornerAction.none)
        XCTAssertEqual(corner.configuredClicks, [1])
    }
}
