import AppKit

/// Starts the app, and owns its window and its menu bar item.
@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let edgeChoices: [(title: String, kind: SlideKind?)] =
        SlideKind.allCases.map { ($0.title, $0) } + [("Off", nil)]
    private static let edges: [(title: String, path: WritableKeyPath<AppSettings, SlideKind?>)] = [
        ("Left Edge", \.leftEdge), ("Right Edge", \.rightEdge), ("Top Edge", \.topEdge),
        ("Bottom Edge", \.bottomEdge),
    ]

    private let controller = GestureController()
    private var mainWindow: MainWindowController?
    private var welcomeWindow: WelcomeWindowController?
    private var statusItem: NSStatusItem?
    private var edgeMenus: [(menu: NSMenu, path: WritableKeyPath<AppSettings, SlideKind?>)] = []
    private let trackpadsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let profileItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
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
            self?.welcomeWindow?.settingsChanged()
        }
        controller.onAvailabilityChanged = { [weak self] in
            self?.mainWindow?.settingsChanged()
            self?.welcomeWindow?.settingsChanged()
        }
        controller.onTouches = { [weak self] touches in
            self?.welcomeWindow?.updateTouches(touches)
            guard let window = self?.mainWindow, window.isOpen else { return }
            window.updateTouches(touches)
        }
        controller.onSlideStep = { [weak self] in self?.welcomeWindow?.slideHappened() }
        controller.start()
        setUpStatusItem()
        guard !launchedAtLogin else { return }
        #if DEBUG
            // Launching with `-debugWelcome 3` opens the tour at that step for inspection.
            if UserDefaults.standard.object(forKey: "debugWelcome") != nil {
                openWelcomeTour(page: UserDefaults.standard.integer(forKey: "debugWelcome"))
                return
            }
        #endif
        if WelcomeProgress.shouldShow {
            openWelcomeTour()
        } else {
            openWindow()
        }
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
        profileItem.title = "Profile: \(controller.activeProfileName)"
        let trusted = AXIsProcessTrusted()
        accessibilityItem.title = trusted ? "Accessibility Is On" : "Grant Accessibility…"
        accessibilityItem.isEnabled = !trusted
        pauseItem.state = controller.paused ? .on : .off
        let settings = SettingsStore.shared.settings
        let unavailable = controller.unavailableKinds
        for (edgeMenu, path) in edgeMenus {
            for (index, item) in edgeMenu.items.enumerated() {
                let kind = Self.edgeChoices[index].kind
                item.state = kind == settings[keyPath: path] ? .on : .off
                item.isEnabled = kind.map { !unavailable.contains($0) } ?? true
                item.toolTip = item.isEnabled ? nil : kind?.unavailableReason
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
        profileItem.isEnabled = false
        accessibilityItem.target = self
        pauseItem.target = self
        menu.addItem(trackpadsItem)
        menu.addItem(profileItem)
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Edges for All Apps"))
        for (index, edge) in Self.edges.enumerated() {
            menu.addItem(makeEdgeItem(title: edge.title, edgeIndex: index, path: edge.path))
        }
        menu.addItem(.separator())
        menu.addItem(pauseItem)
        let tour = NSMenuItem(
            title: "Welcome Tour…", action: #selector(showWelcomeTour), keyEquivalent: "")
        tour.target = self
        menu.addItem(tour)
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
        submenu.autoenablesItems = false
        for (choiceIndex, choice) in Self.edgeChoices.enumerated() {
            let item = NSMenuItem(
                title: choice.title, action: #selector(chooseEdgeAction(_:)), keyEquivalent: "")
            item.target = self
            item.tag = edgeIndex * 100 + choiceIndex
            submenu.addItem(item)
        }
        edgeMenus.append((submenu, path))
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    @objc private func chooseEdgeAction(_ sender: NSMenuItem) {
        let path = Self.edges[sender.tag / 100].path
        SettingsStore.shared.settings[keyPath: path] = Self.edgeChoices[sender.tag % 100].kind
    }

    private var windowActions: WindowActions {
        WindowActions(
            testHaptic: { [weak self] in self?.controller.testHaptic() },
            hapticStatus: { [weak self] in self?.controller.hapticStatus ?? "" },
            requestAccessibility: { [weak self] in self?.requestAccessibility() },
            previewSeekOverlay: { [weak self] in self?.controller.previewSeekOverlay() },
            unavailableKinds: { [weak self] in self?.controller.unavailableKinds ?? [] },
            showWelcomeTour: { [weak self] in self?.showWelcomeTour() })
    }

    @objc private func openWindow() {
        // The tour edits the same settings, so only one of the two is open at a time.
        if let welcomeWindow {
            welcomeWindow.bringForward()
            return
        }
        if mainWindow == nil {
            mainWindow = MainWindowController(actions: windowActions)
            mainWindow?.onClose = { [weak self] in self?.windowClosed() }
        }
        mainWindow?.show()
    }

    @objc private func showWelcomeTour() {
        openWelcomeTour()
    }

    private func openWelcomeTour(page: Int = 0) {
        if let welcomeWindow {
            welcomeWindow.bringForward()
            return
        }
        // A new window reads the settings afresh after the tour, so this one is let go.
        mainWindow?.close()
        mainWindow = nil
        let window = WelcomeWindowController(actions: windowActions)
        window.onClose = { [weak self] in
            self?.welcomeWindow = nil
            self?.windowClosed()
        }
        welcomeWindow = window
        window.show(page: page)
    }

    /// The app appears in the Dock only while one of its windows is open.
    private func windowClosed() {
        // The closing window still counts as open while its delegate runs.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.welcomeWindow == nil, self.mainWindow?.isOpen != true else {
                return
            }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func togglePause() {
        controller.paused.toggle()
    }

    /// Shows the system prompt for the permission that gestures need.
    @objc private func requestAccessibility() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [prompt: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
