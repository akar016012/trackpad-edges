import XCTest

@testable import EdgeGestures

final class DiagnosticsReportTests: XCTestCase {
    /// Every value in the settings that could be personal. None of them may reach a report.
    private let personal = [
        "/Applications/Secret Notes.app", "https://example.com/private/page",
        "/Applications/Other Browser.app", "/Users/someone/Documents/Diary.txt", "Control-Option-K",
        "My Morning Routine", "com.example.secretnotes", "Secret Notes",
        "~/Secret/start-work.sh --token Diary",
    ]

    private func personalSettings() -> AppSettings {
        var settings = AppSettings()
        settings.topLeft[2] = .openApp(path: personal[0])
        settings.topRight[1] = .openLink(url: personal[1], browserPath: personal[2])
        settings.bottomLeft[1] = .openFile(path: personal[3])
        settings.bottomLeft[3] = .keyCombination(keyCode: 40, modifiers: 1, label: personal[4])
        settings.bottomRight[1] = .shortcut(name: personal[5])
        settings.bottomRight[2] = .command(script: personal[8])
        settings.bottomRight[3] = .system(action: .restart)
        var profile = AppProfile(bundleID: personal[6], name: personal[7])
        profile.edges[.left] = EdgeChoice(kind: nil)
        profile.edges[.twoFingerTop] = EdgeChoice(kind: .zoom)
        profile.corners[.topLeft] = CornerSetting(action: .openApp(path: personal[0]), clicks: 1)
        settings.profiles = [profile, AppProfile(bundleID: "com.example.second", name: "Second")]
        return settings
    }

    private func report(
        settings: AppSettings = AppSettings(), unavailable: Set<SlideKind> = []
    ) -> DiagnosticsReport {
        DiagnosticsReport(
            appVersion: "1.3", appBuild: "4", systemVersion: "27.2.0 (26B123)",
            macModel: "MacBookPro18,1",
            trackpads: [
                TrackpadInfo(familyID: 105, isBuiltIn: true),
                TrackpadInfo(familyID: 130, isBuiltIn: false), TrackpadInfo(),
            ], accessibilityGranted: true, clickWatchingOn: true, gesturesPaused: false,
            mediaAdapterLoaded: true, unavailable: unavailable, settings: settings)
    }

    func testReportListsTheVersionsAndTheTrackpads() {
        let text = report().text
        XCTAssertTrue(text.hasPrefix("Trackpad Edges diagnostics\n"))
        for line in [
            "App version: 1.3 (4)", "macOS: 27.2.0 (26B123)",
            "Mac model: MacBookPro18,1", "Accessibility: granted", "Click watching: on",
            "Gestures: active", "Media adapter: loaded", "Trackpads found: 3",
            "- Trackpad 1: family 105, built in", "- Trackpad 2: family 130, external",
            "- Trackpad 3: unknown family",
        ] {
            XCTAssertTrue(text.contains(line + "\n"), "The report is missing: \(line)")
        }
    }

    func testReportShowsWhatIsOffOrMissing() {
        var report = report()
        report.accessibilityGranted = false
        report.clickWatchingOn = false
        report.gesturesPaused = true
        report.mediaAdapterLoaded = false
        report.trackpads = []
        let text = report.text
        for line in [
            "Accessibility: not granted", "Click watching: off", "Gestures: paused",
            "Media adapter: not loaded", "Trackpads found: 0",
        ] {
            XCTAssertTrue(text.contains(line + "\n"), "The report is missing: \(line)")
        }
    }

    func testReportSaysWhichWayTheSystemActionsUse() {
        var report = report()
        for line in [
            "Lock Screen: system call", "Toggle Dark Mode: system call",
            "Do Not Disturb key: not set",
        ] {
            XCTAssertTrue(report.text.contains(line + "\n"), "The report is missing: \(line)")
        }
        report.lockUsesSystemCall = false
        report.darkModeUsesSystemCall = false
        report.doNotDisturbKeySet = true
        for line in [
            "Lock Screen: Control-Command-Q", "Toggle Dark Mode: System Events",
            "Do Not Disturb key: set",
        ] {
            XCTAssertTrue(report.text.contains(line + "\n"), "The report is missing: \(line)")
        }
    }

    func testReportGivesTheReasonForEachDimmedAction() {
        XCTAssertTrue(report().text.contains("Dimmed actions: none\n"))
        let text = report(unavailable: [.switchSpaces, .seek]).text
        XCTAssertTrue(
            text.contains(
                """
                Dimmed actions:
                - Media Seek: The media adapter could not start.
                - Switch Spaces: Turn on the Mission Control shortcuts for moving between Spaces in System Settings.

                """))
    }

    func testReportSummarizesTheSettings() {
        var settings = AppSettings()
        settings.topEdge = .scroll
        settings.twoFingerRight = .brightness
        settings.seekStepType = .seconds
        settings.seekStepValue = 5
        settings.haptics.onSeek = false
        let text = report(settings: settings).text
        for line in [
            "Left edge: Brightness", "Right edge: Volume", "Top edge: Scroll",
            "Bottom edge: Media Seek", "Left edge, two fingers: Off",
            "Right edge, two fingers: Brightness", "Top-left corner: 1 click Mute",
            "Top-right corner: no action", "Edge width: 10%", "Sensitivity: 1",
            "Require a click to start: off", "Require key: none",
            "Sides, bottom quarter only: off", "Corner press strength: 90",
            "Seek step: 5 seconds", "Seek preview: Glass, Bottom",
            "Haptics: on, firm, strength 1, for steps, limits, corners", "Profiles: 0",
        ] {
            XCTAssertTrue(text.contains(line + "\n"), "The report is missing: \(line)")
        }
    }

    func testReportNamesTheKindOfEachCornerActionAndEachProfileChange() {
        let text = report(settings: personalSettings()).text
        for line in [
            "Top-left corner: 1 click Mute, 2 clicks Open App",
            "Top-right corner: 1 click Open Link",
            "Bottom-left corner: 1 click Open File or Folder, 3 clicks Press Keys",
            "Bottom-right corner: 1 click Run Shortcut, 2 clicks Run Command, 3 clicks Restart…",
            "Profiles: 2", "- Profile 1:",
            "  - Left edge: Off", "  - Top edge, two fingers: Zoom",
            "  - Top-left corner: 1 click Open App", "- Profile 2: no changes",
        ] {
            XCTAssertTrue(text.contains(line + "\n"), "The report is missing: \(line)")
        }
    }

    func testReportLeavesOutEveryPathLinkAndName() {
        let text = report(settings: personalSettings()).text
        for value in personal + ["com.example.second", "Second"] {
            XCTAssertFalse(text.contains(value), "The report must not include: \(value)")
        }
        // No part of any of them may appear either, such as a folder or a file name.
        for fragment in [
            "/", "http", "Secret", "Diary", "example", "someone", "Routine", "Option", "token",
            "start-work",
        ] {
            XCTAssertFalse(text.contains(fragment), "The report must not include: \(fragment)")
        }
    }
}

final class TouchRecordingTests: XCTestCase {
    private let trackpads = [TrackpadInfo(familyID: 105, isBuiltIn: true)]

    private func touch(_ id: Int32 = 7) -> TouchPoint {
        TouchPoint(
            id: id, x: 0.123456, y: 0.987654, pressure: 88.126, size: 0.71239, majorAxis: 9.87654)
    }

    func testFrameKeepsTheTimeAndEachContactRounded() {
        var recording = TouchRecording(trackpads: trackpads)
        recording.add([touch()], trackpad: 0, at: 1.23456)
        XCTAssertEqual(
            recording.frames,
            [
                TouchRecording.Frame(
                    time: 1.235, trackpad: 0,
                    contacts: [
                        TouchRecording.Contact(
                            id: 7, x: 0.1235, y: 0.9877, pressure: 88.13, size: 0.712,
                            majorAxis: 9.877)
                    ])
            ])
    }

    func testFrameWithNoContactsIsKeptBecauseItShowsALift() {
        var recording = TouchRecording(trackpads: trackpads)
        recording.add([], trackpad: 0, at: 0.5)
        XCTAssertEqual(recording.frames.count, 1)
        XCTAssertEqual(recording.frames[0].contacts, [])
    }

    func testFrameFromAnUnlistedTrackpadIsLeftOut() {
        var recording = TouchRecording(trackpads: trackpads)
        recording.add([touch()], trackpad: 1, at: 0)
        recording.add([touch()], trackpad: -1, at: 0)
        XCTAssertEqual(recording.frames, [])
    }

    func testRecordingStopsTakingFramesAtItsLimit() {
        var recording = TouchRecording(trackpads: trackpads)
        for index in 0..<(TouchRecording.maxFrames + 10) {
            recording.add([], trackpad: 0, at: Double(index) / 1000)
        }
        XCTAssertEqual(recording.frames.count, TouchRecording.maxFrames)
    }

    func testFileHoldsOnlyTheDocumentedKeysAndReadsBack() throws {
        var recording = TouchRecording(trackpads: trackpads)
        recording.add([touch()], trackpad: 0, at: 0.25)
        let data = try recording.encoded()
        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            """
            {"frames":[{"contacts":[{"id":7,"majorAxis":9.877,"pressure":88.13,"size":0.712,\
            "x":0.1235,"y":0.9877}],"time":0.25,"trackpad":0}],"trackpads":[{"familyID":105,\
            "isBuiltIn":true}],"version":1}
            """)
        XCTAssertEqual(try JSONDecoder().decode(TouchRecording.self, from: data), recording)
    }

    func testValueThatIsNotANumberDoesNotStopTheFileFromBeingWritten() throws {
        var recording = TouchRecording(trackpads: trackpads)
        recording.add(
            [TouchPoint(id: 1, x: 0.5, y: 0.5, pressure: .nan, size: .infinity)], trackpad: 0,
            at: 0)
        XCTAssertEqual(recording.frames[0].contacts[0].pressure, 0)
        XCTAssertEqual(recording.frames[0].contacts[0].size, 0)
        XCTAssertNoThrow(try recording.encoded())
    }
}
