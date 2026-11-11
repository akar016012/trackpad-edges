import AppKit
import Carbon.HIToolbox

/// Carries out the system actions that need no confirmation. Log Out, Restart, and Shut Down go
/// through `SessionActionRunner` instead, which is the only code that can send them.
///
/// Lock Screen and Toggle Dark Mode each have two ways to work. The first is a private system call,
/// which is looked up once at launch, and the second is used when that call is missing.
final class SystemActionRunner {
    private typealias LockCall = @convention(c) () -> Int32
    private typealias ReadThemeCall = @convention(c) () -> Bool
    private typealias SetThemeCall = @convention(c) (Bool) -> Void

    nonisolated private static let finder = "com.apple.finder"
    nonisolated private static let systemEvents = "com.apple.systemevents"
    private static let screenSaver = URL(
        fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
    /// How long Finder may show its own warning before an Empty Trash request gives up waiting.
    nonisolated private static let emptyTrashTimeout: TimeInterval = 600
    /// How long Finder can hold up this thread while it comes forward.
    private static let raiseTimeout: Float = 0.25

    private let events: AppleEventSender
    private let background = DispatchQueue(label: "system-actions", qos: .userInitiated)
    private let lockCall: LockCall?
    private let readTheme: ReadThemeCall?
    private let setTheme: SetThemeCall?
    /// Shows a short notice, with a title and a sentence that says what to do.
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

    /// Whether each action uses its first way, for the diagnostics report.
    var lockUsesSystemCall: Bool { lockCall != nil }
    var darkModeUsesSystemCall: Bool { readTheme != nil && setTheme != nil }

    /// The key assigned to Do Not Disturb, which is read afresh each time.
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
            // These never run from here, because they must ask first.
            break
        }
    }

    private func lockScreen() {
        guard let lockCall else {
            // This is the system's own shortcut for locking the screen.
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

    /// Brings Finder forward first, so that its own warning opens in front.
    private func emptyTrash() {
        if let finder = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.finder
        ).first {
            // macOS ignores a plain activation request from an app that is not in front.
            let element = AXUIElementCreateApplication(finder.processIdentifier)
            AXUIElementSetMessagingTimeout(element, Self.raiseTimeout)
            AXUIElementSetAttributeValue(
                element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
        events.perform(target: Self.finder) {
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
            // The app is still busy with the request, often with its own question.
            break
        case .failed(let code):
            showNotice?("\(app) Did Not Answer", "The request failed with error \(code).")
        }
    }

    /// Turns a four-letter code, such as `thme`, into the number that Apple events use.
    nonisolated private static func code(_ text: String) -> FourCharCode {
        text.utf8.reduce(0) { $0 << 8 | FourCharCode($1) }
    }
}
