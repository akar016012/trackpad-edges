import XCTest

@testable import EdgeGestures

final class SettingsModelTests: XCTestCase {
    /// Settings as the first release saved them, before later keys existed.
    private let oldSettings = Data(
        """
        {
          "leftEdge": "volume", "rightEdge": "seek", "bottomEdge": "brightness",
          "topLeft": {"action": {"mute": {}}, "clicks": 2},
          "topRight": {"action": {"none": {}}, "clicks": 1},
          "bottomQuarterOnly": true, "requireClick": true, "requiredModifier": "shift",
          "edgeWidth": 0.12, "sensitivity": 1.5,
          "haptics": {
            "enabled": false, "strength": 1.2, "pattern": "soft", "onStep": true,
            "onLimit": false, "onCorner": true, "onSeek": true
          }
        }
        """.utf8)

    func testOldSettingsLoadUnchangedAsTheDefaultProfile() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: oldSettings)
        XCTAssertEqual(settings.leftEdge, .volume)
        XCTAssertEqual(settings.rightEdge, .seek)
        XCTAssertEqual(settings.bottomEdge, .brightness)
        XCTAssertEqual(settings.requiredModifier, .shift)
        XCTAssertEqual(settings.edgeWidth, 0.12)
        XCTAssertFalse(settings.haptics.enabled)
        XCTAssertEqual(settings.topLeft[2], .mute)
        XCTAssertEqual(settings.topLeft.configuredClicks, [2])
    }

    func testKeysAddedLaterUseTheirDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: oldSettings)
        XCTAssertNil(settings.topEdge)
        XCTAssertNil(settings.twoFingerRight)
        XCTAssertEqual(settings.profiles, [])
        XCTAssertEqual(settings.overlayStyle, .glass)
    }

    func testSettingsWithProfilesSurviveSaving() throws {
        var settings = AppSettings()
        var profile = AppProfile(bundleID: "com.example.app", name: "Example")
        profile.edges[.right] = EdgeChoice(kind: nil)
        profile.edges[.twoFingerLeft] = EdgeChoice(kind: .zoom)
        profile.corners[.topRight] = CornerSetting(action: .playPause, clicks: 1)
        settings.profiles = [profile]
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: data), settings)
    }

    private func settingsWithProfile() -> AppSettings {
        var settings = AppSettings()
        settings.profiles = [AppProfile(bundleID: "app", name: "App")]
        return settings
    }

    func testAppWithoutAProfileUsesTheDefaults() {
        let settings = settingsWithProfile()
        XCTAssertEqual(settings.resolved(for: "other"), settings)
        XCTAssertEqual(settings.resolved(for: nil), settings)
    }

    func testProfileChangesOnlyWhatItSets() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.right] = EdgeChoice(kind: .scroll)
        let resolved = settings.resolved(for: "app")
        XCTAssertEqual(resolved.rightEdge, .scroll)
        XCTAssertEqual(resolved.leftEdge, settings.leftEdge)
        XCTAssertEqual(resolved.topLeft, settings.topLeft)
    }

    func testProfileCanTurnAnEdgeOff() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.right] = EdgeChoice(kind: nil)
        XCTAssertNil(settings.resolved(for: "app").rightEdge)
    }

    func testUnchangedSlotFollowsLaterDefaults() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.right] = EdgeChoice(kind: .scroll)
        settings.leftEdge = .zoom
        XCTAssertEqual(settings.resolved(for: "app").leftEdge, .zoom)
    }

    func testEditingAProfileStoresOnlyTheDifference() {
        var settings = settingsWithProfile()
        var edited = settings.resolved(for: "app")
        edited.rightEdge = .scroll
        edited.topRight = CornerSetting(action: .playPause, clicks: 1)
        settings.apply(edited, toProfile: "app")
        XCTAssertEqual(settings.profiles[0].edges, [.right: EdgeChoice(kind: .scroll)])
        XCTAssertEqual(settings.profiles[0].corners.count, 1)
        XCTAssertEqual(settings.rightEdge, .volume)
        XCTAssertEqual(settings.resolved(for: "app").rightEdge, .scroll)
    }

    func testSettingAProfileBackToTheDefaultClearsTheOverride() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.right] = EdgeChoice(kind: .scroll)
        var edited = settings.resolved(for: "app")
        edited.rightEdge = settings.rightEdge
        settings.apply(edited, toProfile: "app")
        XCTAssertEqual(settings.profiles[0].edges, [:])
    }

    func testSettingsOutsideAProfileApplyToEveryApp() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.right] = EdgeChoice(kind: nil)
        var edited = settings.resolved(for: "app")
        edited.edgeWidth = 0.15
        settings.apply(edited, toProfile: "app")
        XCTAssertEqual(settings.edgeWidth, 0.15)
        XCTAssertEqual(settings.profiles[0].edges, [.right: EdgeChoice(kind: nil)])
    }

    func testUnrelatedEditKeepsAnOverrideThatMatchesTheDefault() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.right] = EdgeChoice(kind: .scroll)
        settings.rightEdge = .scroll
        var edited = settings.resolved(for: "app")
        edited.edgeWidth = 0.15
        settings.apply(edited, toProfile: "app")
        XCTAssertEqual(settings.profiles[0].edges, [.right: EdgeChoice(kind: .scroll)])
        settings.rightEdge = .volume
        XCTAssertEqual(settings.resolved(for: "app").rightEdge, .scroll)
    }

    func testEditingOneCornerClickKeepsTheRestOfTheCorner() {
        var settings = settingsWithProfile()
        var edited = settings.resolved(for: "app")
        edited.topLeft[2] = .playPause
        settings.apply(edited, toProfile: "app")
        XCTAssertEqual(settings.topLeft[2], .none)
        let resolved = settings.resolved(for: "app")
        XCTAssertEqual(resolved.topLeft[1], .mute)
        XCTAssertEqual(resolved.topLeft[2], .playPause)
    }

    func testEditingWithoutAProfileChangesTheDefaults() {
        var settings = settingsWithProfile()
        var edited = settings
        edited.rightEdge = .zoom
        settings.apply(edited, toProfile: nil)
        XCTAssertEqual(settings.rightEdge, .zoom)
        XCTAssertEqual(settings.profiles[0].edges, [:])
    }

    func testResolvedProfileReachesTheGestureConfig() {
        var settings = settingsWithProfile()
        settings.profiles[0].edges[.twoFingerRight] = EdgeChoice(kind: .zoom)
        let config = settings.resolved(for: "app").gestureConfig(unavailable: [])
        XCTAssertEqual(config.twoFingerActions, [.right: .zoom])
    }

    func testSummaryDescribesEachDifference() {
        var profile = AppProfile(bundleID: "app", name: "App")
        XCTAssertEqual(profile.summary, [])
        profile.edges[.right] = EdgeChoice(kind: nil)
        profile.corners[.topLeft] = CornerSetting(action: .mute, clicks: 1)
        XCTAssertEqual(
            profile.summary,
            ["The right edge uses nothing.", "The top-left corner has its own actions."])
    }
}
