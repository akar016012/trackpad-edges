import XCTest

@testable import EdgeGestures

final class SystemActionTests: XCTestCase {
    func testBothNewActionsSurviveSavingInTheirPinnedForm() throws {
        var corner = CornerSetting(action: .system(action: .lockScreen), clicks: 1)
        corner[2] = .command(script: "say hello")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(corner)
        // Older versions read this form, so changing it would lose settings.
        XCTAssertEqual(
            String(decoding: data, as: UTF8.self),
            #"{"actions":[{"system":{"action":"lockScreen"}},{"command":{"script":"say hello"}},"#
                + #"{"none":{}},{"none":{}}]}"#)
        XCTAssertEqual(try JSONDecoder().decode(CornerSetting.self, from: data), corner)
    }

    func testEverySystemActionSurvivesSaving() throws {
        for action in SystemAction.allCases {
            let corner = CornerSetting(action: .system(action: action), clicks: 3)
            let data = try JSONEncoder().encode(corner)
            XCTAssertEqual(try JSONDecoder().decode(CornerSetting.self, from: data), corner)
        }
    }

    func testUnknownSystemActionLoadsAsNoActionAndKeepsTheOtherClicks() throws {
        let saved = Data(
            (#"{"actions":[{"system":{"action":"launchRockets"}},{"mute":{}},"#
                + #"{"command":{"script":"ls"}},{"none":{}}]}"#).utf8)
        let corner = try JSONDecoder().decode(CornerSetting.self, from: saved)
        XCTAssertEqual(corner[1], CornerAction.none)
        XCTAssertEqual(corner[2], .mute)
        XCTAssertEqual(corner[3], .command(script: "ls"))
        XCTAssertEqual(corner.configuredClicks, [2, 3])
    }

    func testBlankCommandDoesNotCount() {
        XCTAssertFalse(CornerAction.command(script: "").isConfigured)
        XCTAssertFalse(CornerAction.command(script: "  \n\t ").isConfigured)
        XCTAssertTrue(CornerAction.command(script: " ls ").isConfigured)
        XCTAssertTrue(CornerAction.system(action: .sleep).isConfigured)
    }

    func testOnlyTheSessionActionsConfirmFirst() {
        let confirming = SystemAction.allCases.filter(\.confirmsFirst)
        XCTAssertEqual(confirming, [.logOut, .restart, .shutDown])
        for action in SystemAction.allCases {
            XCTAssertEqual(action.confirmation != nil, action.confirmsFirst, "\(action)")
            // Only actions that open the box end with an ellipsis.
            XCTAssertEqual(action.title.hasSuffix("…"), action.confirmsFirst, "\(action)")
        }
        XCTAssertEqual(SystemAction.restart.confirmation?.question, "Restart this Mac?")
        XCTAssertEqual(SystemAction.restart.confirmation?.button, "Restart")
        XCTAssertEqual(SystemAction.logOut.confirmation?.button, "Log Out")
        XCTAssertEqual(SystemAction.shutDown.confirmation?.button, "Shut Down")
    }

    func testOnlyTheScreenAndSleepActionsWaitForTheLiftingFinger() {
        XCTAssertEqual(
            SystemAction.allCases.filter(\.waitsForLift),
            [.startScreenSaver, .sleepDisplay, .sleep])
        XCTAssertEqual(
            SystemAction.allCases.filter(\.pausesAfterWake),
            [.lockScreen, .startScreenSaver, .sleepDisplay, .sleep])
    }

    func testPowerActionIsRefusedJustAfterAWakeAndAllowedLater() {
        var guardrail = PowerActionGuard()
        XCTAssertTrue(guardrail.allows(.sleep, at: 10))
        guardrail.recordWake(at: 100)
        XCTAssertFalse(guardrail.allows(.sleep, at: 100))
        XCTAssertFalse(guardrail.allows(.lockScreen, at: 102.9))
        XCTAssertTrue(guardrail.allows(.sleep, at: 103))
        XCTAssertTrue(guardrail.allows(.startScreenSaver, at: 104))
        // Actions that confirm first, or do not sleep or lock, are never held.
        XCTAssertTrue(guardrail.allows(.restart, at: 100.5))
        XCTAssertTrue(guardrail.allows(.toggleDarkMode, at: 100.5))
    }

    func testEveryTitleIsUniqueAndHasNoSlash() {
        let titles = CornerActionKind.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count)
        for title in titles { XCTAssertFalse(title.contains("/"), title) }
        XCTAssertEqual(titles.count, 21)
    }

    func testPopupKindsFollowTheGroupOrderAndMatchTheirActions() {
        let groups = CornerActionKind.allCases.map(\.group)
        XCTAssertEqual(groups, groups.sorted { $0.order < $1.order })
        XCTAssertEqual(Set(groups), Set(CornerActionGroup.allCases))
        // A chosen kind maps back to itself.
        for kind in CornerActionKind.allCases {
            XCTAssertEqual(CornerActionKind(kind.blankAction), kind)
        }
        // Unknown tags map to no kind.
        XCTAssertNil(CornerActionKind(tag: -1))
        XCTAssertNil(CornerActionKind(tag: CornerActionKind.allCases.count))
    }
}

extension CornerActionGroup {
    fileprivate var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

final class ShellCommandTests: XCTestCase {
    func testShellIsTheAccountShellWhenItCanRun() {
        XCTAssertEqual(
            ShellCommand.shell(accountShell: "/opt/homebrew/bin/fish") { _ in true },
            "/opt/homebrew/bin/fish")
    }

    func testShellFallsBackWhenTheAccountShellCannotRunACommand() {
        for shell in [nil, "", "fish", "/usr/bin/false", "/sbin/nologin", "/usr/bin/nologin"] {
            XCTAssertEqual(
                ShellCommand.shell(accountShell: shell) { _ in true }, ShellCommand.fallbackShell,
                shell ?? "nil")
        }
        XCTAssertEqual(
            ShellCommand.shell(accountShell: "/bin/bash") { _ in false }, ShellCommand.fallbackShell
        )
    }

    func testCommandRunsThroughALoginShell() {
        XCTAssertEqual(ShellCommand.arguments(for: "echo hi"), ["-l", "-c", "echo hi"])
    }

    func testEnvironmentKeepsOnlyTheAllowlist() {
        let inherited = [
            "USER": "someone", "LOGNAME": "someone", "TMPDIR": "/tmp/x", "LANG": "en_US.UTF-8",
            "LC_CTYPE": "UTF-8", "SSH_AUTH_SOCK": "/tmp/agent", "__CF_USER_TEXT_ENCODING": "0x1F5",
            "DYLD_INSERT_LIBRARIES": "/tmp/evil.dylib", "PATH": "/tmp/evil", "HOME": "/wrong",
            "SHELL": "/wrong", "XPC_SERVICE_NAME": "app", "SECRET_TOKEN": "abc",
            "PERL5OPT": "-Mevil",
        ]
        let environment = ShellCommand.environment(
            inherited: inherited, home: "/Users/someone", shell: "/bin/zsh")
        XCTAssertEqual(
            environment,
            [
                "USER": "someone", "LOGNAME": "someone", "TMPDIR": "/tmp/x",
                "LANG": "en_US.UTF-8", "LC_CTYPE": "UTF-8", "SSH_AUTH_SOCK": "/tmp/agent",
                "__CF_USER_TEXT_ENCODING": "0x1F5", "HOME": "/Users/someone", "SHELL": "/bin/zsh",
                "PATH": ShellCommand.basePath,
            ])
    }

    func testTailKeepsOnlyTheEndOfTheOutput() {
        var tail = OutputTail(limit: 10)
        tail.append(Data("first line\n".utf8))
        tail.append(Data("second\nthird".utf8))
        XCTAssertEqual(tail.data.count, 10)
        XCTAssertEqual(tail.lastLines(5), ["cond", "third"])
        XCTAssertEqual(tail.lastLines(1), ["third"])
    }

    func testTailSkipsBlankLines() {
        var tail = OutputTail()
        tail.append(Data("  one  \n\n\r\ntwo\n   \nthree\nfour\n".utf8))
        XCTAssertEqual(tail.lastLines(3), ["two", "three", "four"])
        XCTAssertEqual(OutputTail().lastLines(3), [])
    }

    func testWaitStatusIsRead() {
        XCTAssertEqual(ShellCommand.End(waitStatus: 0), .exited(0))
        XCTAssertEqual(ShellCommand.End(waitStatus: 127 << 8), .exited(127))
        XCTAssertEqual(ShellCommand.End(waitStatus: 9), .signaled(9))
        XCTAssertEqual(ShellCommand.End(waitStatus: 15 | 0x80), .signaled(15))
    }

    func testSuccessAndStoppedCommandsAreNotReported() {
        var tail = OutputTail()
        tail.append(Data("noise\n".utf8))
        let corner = "top-left"
        XCTAssertNil(ShellCommand.failure(.exited(0), stopped: false, tail: tail, corner: corner))
        XCTAssertNil(ShellCommand.failure(.signaled(15), stopped: true, tail: tail, corner: corner))
        XCTAssertNil(ShellCommand.failure(.exited(1), stopped: true, tail: tail, corner: corner))
    }

    func testFailureSummaryNamesTheCornerTheStatusAndTheLastLines() throws {
        var tail = OutputTail()
        tail.append(Data("one\ntwo\nthree\nzsh:1: command not found: frob\n".utf8))
        let failure = try XCTUnwrap(
            ShellCommand.failure(.exited(127), stopped: false, tail: tail, corner: "top-left"))
        XCTAssertEqual(failure.title, "Command Failed")
        XCTAssertEqual(failure.summary, "The top-left command ended with status 127.")
        XCTAssertEqual(
            failure.body,
            "The top-left corner's command ended with status 127. Its last error output was: two "
                + "three zsh:1: command not found: frob")
        let quiet = try XCTUnwrap(
            ShellCommand.failure(
                .signaled(9), stopped: false, tail: OutputTail(), corner: "bottom-right"))
        XCTAssertEqual(quiet.summary, "The bottom-right command was ended by signal 9.")
        XCTAssertEqual(quiet.body, "The bottom-right corner's command was ended by signal 9.")
    }

    func testFailureSummaryShortensLongOutput() throws {
        var tail = OutputTail()
        tail.append(Data((String(repeating: "x", count: 500) + "END").utf8))
        let failure = try XCTUnwrap(
            ShellCommand.failure(.exited(1), stopped: false, tail: tail, corner: "top-left"))
        XCTAssertTrue(failure.body.hasSuffix("END"))
        XCTAssertTrue(failure.body.contains("was: …x"))
        XCTAssertLessThan(failure.body.count, ShellCommand.reportedLength + 100)
        XCTAssertFalse(failure.summary.contains("x"))
    }
}

final class SymbolicHotKeyTests: XCTestCase {
    private func table(_ entry: Any) -> [String: Any] {
        [SymbolicHotKey.doNotDisturb: entry]
    }

    func testEnabledEntryGivesItsKey() throws {
        let entry: [String: Any] = [
            "enabled": true, "value": ["type": "standard", "parameters": [100, 2, 786_432]],
        ]
        let key = try XCTUnwrap(
            SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: table(entry)))
        XCTAssertEqual(key.keyCode, 2)
        XCTAssertEqual(key.modifiers, 786_432)
    }

    func testDisabledEntryGivesNoKey() {
        let entry: [String: Any] = [
            "enabled": false, "value": ["type": "standard", "parameters": [100, 2, 786_432]],
        ]
        XCTAssertNil(SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: table(entry)))
    }

    func testUnsetOrMissingKeyGivesNoKey() {
        let unset: [String: Any] = [
            "enabled": true, "value": ["type": "standard", "parameters": [65535, 65535, 0]],
        ]
        XCTAssertNil(SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: table(unset)))
        XCTAssertNil(SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: [:]))
        XCTAssertNil(SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: nil))
        XCTAssertNil(
            SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: table(["enabled": true])))
    }

    func testMalformedEntryGivesNoKey() {
        for entry: Any in [
            "text",
            ["enabled": true, "value": "text"],
            ["enabled": true, "value": ["type": "modifier", "parameters": [262144, 1]]],
            ["enabled": true, "value": ["type": "standard", "parameters": [100, 2]]],
            ["enabled": true, "value": ["type": "standard", "parameters": ["a", "b", "c"]]],
            ["enabled": true, "value": ["type": "standard", "parameters": [100, -1, 0]]],
            ["enabled": true, "value": ["type": "standard", "parameters": [100, 2, -5]]],
            ["enabled": "yes", "value": ["type": "standard", "parameters": [100, 2, 0]]],
        ] as [Any] {
            XCTAssertNil(
                SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: table(entry)), "\(entry)")
        }
    }
}
