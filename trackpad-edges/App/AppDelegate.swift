import AppKit

/// Starts the app and owns its menu bar item.
@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = GestureController()
    private var statusItem: NSStatusItem?
    private let trackpadsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "", action: #selector(requestAccessibility), keyEquivalent: "")
    private let pauseItem = NSMenuItem(
        title: "Pause Gestures", action: #selector(togglePause), keyEquivalent: "")

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // The application holds its delegate weakly, so the delegate must outlive the run loop.
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SettingsStore.shared.onChange = { [weak self] in self?.controller.applySettings() }
        controller.start()
        setUpStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        trackpadsItem.title = "Trackpads Found: \(controller.trackpadCount)"
        let trusted = AXIsProcessTrusted()
        accessibilityItem.title = trusted ? "Accessibility Is On" : "Grant Accessibility…"
        accessibilityItem.isEnabled = !trusted
        pauseItem.state = controller.paused ? .on : .off
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.dashed", accessibilityDescription: "Trackpad Edges")

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        trackpadsItem.isEnabled = false
        accessibilityItem.target = self
        pauseItem.target = self
        menu.addItem(trackpadsItem)
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Trackpad Edges", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    @objc private func togglePause() {
        controller.paused.toggle()
    }

    /// Shows the system prompt for the permission that gestures need.
    @objc private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
