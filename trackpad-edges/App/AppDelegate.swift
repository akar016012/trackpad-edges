import AppKit

/// Starts the app, and owns its window and its menu bar item.
@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let edgeChoices: [(title: String, kind: SlideKind?)] = [
        ("Volume", .volume), ("Brightness", .brightness), ("Media Seek", .seek), ("Off", nil),
    ]
    private static let edges: [(title: String, path: WritableKeyPath<AppSettings, SlideKind?>)] = [
        ("Left Edge", \.leftEdge), ("Right Edge", \.rightEdge), ("Bottom Edge", \.bottomEdge),
    ]

    private let controller = GestureController()
    private var mainWindow: MainWindowController?
    private var statusItem: NSStatusItem?
    private var edgeMenus: [(menu: NSMenu, path: WritableKeyPath<AppSettings, SlideKind?>)] = []
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
        NSApp.mainMenu = MainMenu.make()
        SettingsStore.shared.onChange = { [weak self] in
            self?.controller.applySettings()
            self?.mainWindow?.settingsChanged()
        }
        controller.onTouches = { [weak self] touches in
            guard let window = self?.mainWindow, window.isOpen else { return }
            window.updateTouches(touches)
        }
        controller.start()
        setUpStatusItem()
        if !launchedAtLogin { openWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        openWindow()
        return true
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
        let settings = SettingsStore.shared.settings
        for (edgeMenu, path) in edgeMenus {
            for (index, item) in edgeMenu.items.enumerated() {
                item.state = Self.edgeChoices[index].kind == settings[keyPath: path] ? .on : .off
            }
        }
    }

    private var launchedAtLogin: Bool {
        let event = NSAppleEventManager.shared().currentAppleEvent
        return event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
            == keyAELaunchedAsLogInItem
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let glyph = NSImage(named: "GlyphMenuBar")
        glyph?.size = NSSize(width: 18, height: 18)
        glyph?.isTemplate = true
        glyph?.accessibilityDescription = "Trackpad Edges"
        item.button?.image = glyph

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        trackpadsItem.isEnabled = false
        accessibilityItem.target = self
        pauseItem.target = self
        menu.addItem(trackpadsItem)
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        for (index, edge) in Self.edges.enumerated() {
            menu.addItem(makeEdgeItem(title: edge.title, edgeIndex: index, path: edge.path))
        }
        menu.addItem(.separator())
        menu.addItem(pauseItem)
        let open = NSMenuItem(
            title: "Open Trackpad Edges…", action: #selector(openWindow), keyEquivalent: ",")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit Trackpad Edges", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func makeEdgeItem(
        title: String, edgeIndex: Int, path: WritableKeyPath<AppSettings, SlideKind?>
    ) -> NSMenuItem {
        let submenu = NSMenu()
        for (choiceIndex, choice) in Self.edgeChoices.enumerated() {
            let item = NSMenuItem(
                title: choice.title, action: #selector(chooseEdgeAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = edgeIndex * 10 + choiceIndex
            submenu.addItem(item)
        }
        edgeMenus.append((submenu, path))
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    @objc private func chooseEdgeAction(_ sender: NSMenuItem) {
        let path = Self.edges[sender.tag / 10].path
        SettingsStore.shared.settings[keyPath: path] = Self.edgeChoices[sender.tag % 10].kind
    }

    @objc private func openWindow() {
        if mainWindow == nil {
            mainWindow = MainWindowController(
                actions: WindowActions(
                    testHaptic: { [weak self] in self?.controller.testHaptic() },
                    hapticStatus: { [weak self] in self?.controller.hapticStatus ?? "" },
                    requestAccessibility: { [weak self] in self?.requestAccessibility() }))
        }
        mainWindow?.show()
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
