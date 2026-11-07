import AppKit

/// Carries out the action assigned to a corner.
final class CornerActionRunner {
    func run(_ action: CornerAction) {
        guard action.isConfigured else { return }
        switch action {
        case .none:
            break
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
            if let keyCode { press(keyCode: keyCode, modifiers: modifiers) }
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

    private func press(keyCode: UInt16, modifiers: UInt64) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            let event = CGEvent(
                keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = CGEventFlags(rawValue: modifiers)
            event?.setIntegerValueField(.eventSourceUserData, value: ClickTap.ownEventMarker)
            event?.post(tap: .cghidEventTap)
        }
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
