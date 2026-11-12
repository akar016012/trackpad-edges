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

    /// Reading is written by hand, so a setting left out of it would reset on every launch.
    func testEverySettingSurvivesSaving() throws {
        var settings = AppSettings()
        settings.leftEdge = .zoom
        settings.rightEdge = .scroll
        settings.bottomEdge = .keyboardBacklight
        settings.topEdge = .switchApps
        settings.twoFingerLeft = .volume
        settings.twoFingerRight = .brightness
        settings.twoFingerBottom = .seek
        settings.twoFingerTop = .switchSpaces
        settings.topLeft = CornerSetting(action: .nextTrack, clicks: 2)
        settings.topRight = CornerSetting(
            action: .openApp(path: "/Applications/Notes.app"), clicks: 3)
        settings.bottomLeft = CornerSetting(action: .shortcut(name: "Focus"), clicks: 1)
        settings.bottomRight = CornerSetting(
            action: .keyCombination(keyCode: 12, modifiers: 256, label: "Q"), clicks: 4)
        settings.seekStepType = .seconds
        settings.seekStepValue = 30
        settings.seekStepType = .percent
        settings.seekStepValue = 2.5
        settings.pressThreshold = 100
        settings.overlayStyle = .solid
        settings.overlayPlacement = .top
        settings.profiles = [AppProfile(bundleID: "com.example.app", name: "Example")]
        settings.bottomQuarterOnly = true
        settings.requireClick = true
        settings.requiredModifier = .option
        settings.edgeWidth = 0.15
        settings.sensitivity = 1.25
        settings.haptics = HapticSettings(
            enabled: false, strength: 0.75, pattern: .soft, onStep: false, onLimit: false,
            onCorner: false, onSeek: false)

        let data = try JSONEncoder().encode(settings)
        let loaded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(loaded, settings)
        /* Every stored value differs from its default, so each key must appear in the saved form
           and be read back. A setting added later is missing from the saved form until this test
           sets it too, which the two counts below catch even for an optional setting. */
        let saved = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let defaults = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(AppSettings()))
                as? [String: Any])
        XCTAssertEqual(saved.count, Mirror(reflecting: settings).children.count)
        XCTAssertEqual(
            (saved["haptics"] as? [String: Any])?.count,
            Mirror(reflecting: settings.haptics).children.count)
        for (key, value) in defaults {
            XCTAssertFalse(
                (saved[key] as? NSObject)?.isEqual(value) ?? true, "\(key) kept its default")
        }
        var switched = loaded
        switched.seekStepType = .seconds
        XCTAssertEqual(switched.seekStepValue, 30)
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

    /// Returns the default settings as saved data, after one change to the saved form.
    private func saved(_ edit: (inout [String: Any]) -> Void) throws -> Data {
        let data = try JSONEncoder().encode(AppSettings())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        edit(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testAnEdgeActionFromANewerVersionTurnsOnlyThatEdgeOff() throws {
        let data = try saved {
            $0["leftEdge"] = "somethingNew"
            $0["rightEdge"] = "zoom"
            $0["sensitivity"] = 1.5
        }
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertNil(settings.leftEdge)
        XCTAssertEqual(settings.rightEdge, .zoom)
        XCTAssertEqual(settings.sensitivity, 1.5)
        XCTAssertEqual(settings.bottomEdge, .seek)
    }

    func testAHapticValueFromANewerVersionKeepsTheOtherHaptics() throws {
        let data = try saved {
            $0["haptics"] = ["enabled": false, "pattern": "somethingNew", "strength": 1.5]
        }
        let haptics = try JSONDecoder().decode(AppSettings.self, from: data).haptics
        XCTAssertFalse(haptics.enabled)
        XCTAssertEqual(haptics.strength, 1.5)
        XCTAssertEqual(haptics.pattern, .firm)
        XCTAssertTrue(haptics.onSeek)
    }

    func testACornerActionFromANewerVersionKeepsTheOtherClicks() throws {
        let data = try saved {
            $0["topRight"] = [
                "actions": [
                    ["somethingNew": [:]], ["playPause": [:]], ["none": [:]], ["none": [:]],
                ]
            ]
        }
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.topRight[1], CornerAction.none)
        XCTAssertEqual(settings.topRight[2], .playPause)
        XCTAssertEqual(settings.topLeft[1], .mute)
    }

    func testAProfileKeepsTheSlotsThatCanBeRead() throws {
        let data = try saved {
            $0["storedProfiles"] = [
                [
                    "bundleID": "app", "name": "App",
                    "edges": [
                        "left", ["kind": "somethingNew"], "someNewSlot", ["kind": "zoom"],
                        "right", ["kind": "scroll"], "top", [:],
                    ],
                    "corners": ["topLeft", ["actions": [["playPause": [:]]]]],
                ],
                ["name": "A profile with no app"],
            ]
        }
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.profiles.count, 1)
        let profile = try XCTUnwrap(settings.profiles.first)
        XCTAssertEqual(
            profile.edges, [.right: EdgeChoice(kind: .scroll), .top: EdgeChoice(kind: nil)])
        XCTAssertEqual(profile.corners[.topLeft]?[1], .playPause)
        XCTAssertEqual(settings.resolved(for: "app").leftEdge, .brightness)
    }

    func testNumbersOutsideTheirRangesAreHeldToThem() throws {
        let data = try saved {
            $0["sensitivity"] = 0
            $0["edgeWidth"] = 0.9
            $0["storedPressThreshold"] = 5
            $0["storedSeekStepType"] = "seconds"
            $0["storedSeekStepSeconds"] = 0
            $0["storedSeekStepPercent"] = 500
            $0["haptics"] = ["strength": 40]
        }
        var settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.sensitivity, 0.5)
        XCTAssertEqual(settings.edgeWidth, 0.20)
        XCTAssertEqual(settings.pressThreshold, 70)
        XCTAssertEqual(settings.seekStep, .seconds(1))
        XCTAssertEqual(settings.haptics.strength, 2.0)
        XCTAssertTrue(settings.gestureConfig(unavailable: []).stepSize.isFinite)
        settings.seekStepType = .percent
        XCTAssertEqual(settings.seekStep, .percent(10))
    }

    func testAValueOfTheWrongKindKeepsItsDefault() throws {
        let data = try saved {
            $0["edgeWidth"] = "wide"
            $0["requireClick"] = "yes"
            $0["haptics"] = "strong"
            $0["topLeft"] = 3
        }
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(settings.edgeWidth, 0.10)
        XCTAssertFalse(settings.requireClick)
        XCTAssertEqual(settings.haptics, HapticSettings())
        XCTAssertEqual(settings.topLeft[1], .mute)
    }

    func testSettingsThatAreNotAnObjectAreStillRefused() {
        XCTAssertThrowsError(try JSONDecoder().decode(AppSettings.self, from: Data("[1, 2]".utf8)))
    }
}
