import AppKit
import Carbon.HIToolbox

/// Runs the system actions that need no confirmation. Lock Screen and Toggle Dark Mode use a
/// private call when it exists and fall back otherwise.
final class SystemActionRunner {
    private typealias LockCall = @convention(c) () -> Int32
    private typealias ReadThemeCall = @convention(c) () -> Bool
    private typealias SetThemeCall = @convention(c) (Bool) -> Void

    nonisolated private static let finder = "com.apple.finder"
    nonisolated private static let systemEvents = "com.apple.systemevents"
    private static let screenSaver = URL(
        fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
    /// How long an Empty Trash request waits while Finder shows its warning.
    nonisolated private static let emptyTrashTimeout: TimeInterval = 600
    /// The longest that raising Finder may block the main thread.
    private static let raiseTimeout: Float = 0.25

    private let events: AppleEventSender
    private let background = DispatchQueue(label: "system-actions", qos: .userInitiated)
    private let lockCall: LockCall?
    private let readTheme: ReadThemeCall?
    private let setTheme: SetThemeCall?
    /// Shows a notice with a title and a detail line.
    var showNotice: ((String, String) -> Void)?

    init(events: AppleEventSender) {
        self.events = events
        lockCall = Self.symbol(
            "SACLockScreenImmediate",
            in: "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login")
        let skyLight = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        readTheme = Self.symbol("SLSGetAppearanceThemeLegacy", in: skyLight)
        setTheme = Self.symbol("SLSSetAppearanceThemeLegacy", in: skyLight)
    }

    /// Whether each action has its private call, for the diagnostics report.
    var lockUsesSystemCall: Bool { lockCall != nil }
    var darkModeUsesSystemCall: Bool { readTheme != nil && setTheme != nil }

    /// The key assigned to Do Not Disturb, read on each use.
    static var doNotDisturbKey: SymbolicHotKey? {
        let table = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys")
        return SymbolicHotKey(entry: SymbolicHotKey.doNotDisturb, in: table)
    }

    private static func symbol<Call>(_ name: String, in path: String) -> Call? {
        guard let library = dlopen(path, RTLD_LAZY), let address = dlsym(library, name) else {
            return nil
        }
        return unsafeBitCast(address, to: Call.self)
    }

    func run(_ action: SystemAction) {
        switch action {
        case .lockScreen: lockScreen()
        case .startScreenSaver:
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: Self.screenSaver, configuration: configuration)
        case .sleepDisplay: runPowerTool("displaysleepnow")
        case .sleep: runPowerTool("sleepnow")
        case .toggleDarkMode: toggleDarkMode()
        case .toggleDoNotDisturb: toggleDoNotDisturb()
        case .emptyTrash: emptyTrash()
        case .logOut, .restart, .shutDown:
            // These go through SessionActionRunner, which asks first.
            break
        }
    }

    private func lockScreen() {
        guard let lockCall else {
            // This is the system's lock shortcut.
            let flags = CGEventFlags([.maskControl, .maskCommand]).rawValue
            KeyPoster.press(keyCode: UInt16(kVK_ANSI_Q), modifiers: flags, releaseFlags: flags)
            return
        }
        background.async { _ = lockCall() }
    }

    private func runPowerTool(_ argument: String) {
        background.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = [argument]
            try? process.run()
        }
    }

    private func toggleDarkMode() {
        if let readTheme, let setTheme {
            background.async { setTheme(!readTheme()) }
            return
        }
        events.perform(target: Self.systemEvents) {
            AppleEventSender.launchIfNeeded(Self.systemEvents)
            // These codes name the dark mode property of System Events' appearance preferences.
            let darkMode = AppleEventSender.property(
                Self.code("thme"), of: AppleEventSender.property(Self.code("aprp")))
            let current = try AppleEventSender.send(
                eventClass: kAECoreSuite, eventID: kAEGetData, to: Self.systemEvents,
                directObject: darkMode)
            let isDark = current.paramDescriptor(forKeyword: keyDirectObject)?.booleanValue ?? false
            _ = try AppleEventSender.send(
                eventClass: kAECoreSuite, eventID: kAESetData, to: Self.systemEvents,
                directObject: darkMode,
                parameters: [(keyAEData, NSAppleEventDescriptor(boolean: !isDark))])
        } onFailure: { [weak self] failure in
            self?.report(failure, app: "System Events")
        }
    }

    private func toggleDoNotDisturb() {
        guard let key = Self.doNotDisturbKey else {
            showNotice?("Do Not Disturb Has No Key", "Assign one in Keyboard settings.")
            return
        }
        KeyPoster.press(keyCode: key.keyCode, modifiers: key.modifiers, releaseFlags: key.modifiers)
    }

    /// Raises Finder first so its warning opens in front.
    private func emptyTrash() {
        if let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.finder
        ).first {
            // macOS ignores plain activation from a background app.
            let element = AXUIElementCreateApplication(finder.processIdentifier)
            AXUIElementSetMessagingTimeout(element, Self.raiseTimeout)
            AXUIElementSetAttributeValue(
                element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        events.perform(target: Self.finder) {
            // These codes are Finder's own Empty Trash event.
            _ = try AppleEventSender.send(
                eventClass: Self.code("fndr"), eventID: Self.code("empt"), to: Self.finder,
                timeout: Self.emptyTrashTimeout)
        } onFailure: { [weak self] failure in
            self?.report(failure, app: "Finder")
        }
    }

    private func report(_ failure: AppleEventSender.Failure, app: String) {
        switch failure {
        case .notAllowed:
            showNotice?("\(app) Is Not Allowed", "Allow it under Privacy & Security, Automation.")
        case .timedOut:
            // The app is still handling it, often by asking a question.
            break
        case .failed(let code):
            showNotice?("\(app) Did Not Answer", "The request failed with error \(code).")
        }
    }

    /// Converts a four-letter code such as `thme` to its number.
    nonisolated private static func code(_ text: String) -> FourCharCode {
        text.utf8.reduce(0) { $0 << 8 | FourCharCode($1) }
    }
}
