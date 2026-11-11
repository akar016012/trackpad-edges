import AppKit

/// Carries out the action assigned to a corner.
final class CornerActionRunner {
    private let events = AppleEventSender()
    let system: SystemActionRunner
    let session: SessionActionRunner
    let commands = CommandRunner()

    /// Shows a short notice, with a title and a sentence that says what to do.
    var showNotice: ((String, String) -> Void)? {
        didSet {
            system.showNotice = showNotice
            session.showNotice = showNotice
            commands.showNotice = showNotice
        }
    }

    init() {
        system = SystemActionRunner(events: events)
        session = SessionActionRunner(events: events)
    }

    /// Runs one action. The corner names who asked, in the confirm box and in failure reports.
    func run(_ action: CornerAction, corner: CornerSlot) {
        guard action.isConfigured else { return }
        switch action {
        case .none:
            break
        case .system(let action) where action.confirmsFirst:
            session.confirm(action, corner: corner)
        case .system(let action):
            system.run(action)
        case .command(let script):
            commands.run(script, corner: corner)
        case .mute:
            MediaKeys.press(MediaKeys.mute)
        case .playPause:
            MediaKeys.press(MediaKeys.playPause)
        case .nextTrack:
            MediaKeys.press(MediaKeys.nextTrack)
        case .previousTrack:
            MediaKeys.press(MediaKeys.previousTrack)
        case .openApp(let path):
            toggleApp(at: URL(fileURLWithPath: path))
        case .openLink(let link, let browserPath):
            open(link: link, browserPath: browserPath)
        case .openFile(let path):
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        case .keyCombination(let keyCode, let modifiers, _):
            let flags = CGEventFlags(rawValue: modifiers)
            let modifier = KeyModifier.allCases.first { flags.contains($0.eventFlag) }
            if let keyCode {
                KeyPoster.press(keyCode: keyCode, modifiers: modifiers, releaseFlags: modifiers)
            } else if let modifier {
                // The release clears the flags, or the modifier would look stuck down.
                KeyPoster.press(
                    keyCode: modifier.keyCode(in: modifiers), modifiers: modifiers, releaseFlags: 0)
            }
        case .shortcut(let name):
            runShortcut(named: name)
        }
    }

    /// Opens an app, or hides it if it is already in front.
    private func toggleApp(at url: URL) {
        let identifier = Bundle(url: url)?.bundleIdentifier
        if let frontmost = NSWorkspace.shared.frontmostApplication, identifier != nil,
            frontmost.bundleIdentifier == identifier
        {
            frontmost.hide()
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func open(link: String, browserPath: String?) {
        // Only web links are allowed, because other schemes can launch arbitrary handlers.
        guard let url = URL(string: link), ["http", "https"].contains(url.scheme?.lowercased())
        else { return }
        guard let browserPath else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open(
            [url], withApplicationAt: URL(fileURLWithPath: browserPath),
            configuration: NSWorkspace.OpenConfiguration())
    }

    /// Runs in the background so that the shortcut does not open the Shortcuts app.
    private func runShortcut(named name: String) {
        // A leading hyphen would make the tool read the name as an option.
        guard !name.isEmpty, !name.hasPrefix("-") else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name]
        try? process.run()
    }
}
