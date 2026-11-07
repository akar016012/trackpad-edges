import AppKit

/// Owns the app window. The app appears in the Dock only while this window is open.
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let edges: EdgesPane
    private let tabs = NSTabViewController()
    private static let generalTab = 3

    init(actions: WindowActions) {
        edges = EdgesPane(title: "Edges", actions: actions)
        let corners = CornersPane(title: "Corners", actions: actions)
        let haptics = HapticsPane(title: "Haptics", actions: actions)
        let general = GeneralPane(title: "General", actions: actions)

        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = false
        let symbols = [
            (edges as SettingsPane, "rectangle.dashed"), (corners, "square.grid.2x2"),
            (haptics, "hand.tap"), (general, "gearshape"),
        ]
        for (pane, symbol) in symbols {
            let item = NSTabViewItem(viewController: pane)
            item.label = pane.title ?? ""
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: pane.title)
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.title = "Trackpad Edges"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        window.delegate = self
        corners.onChange = { [weak self] in self?.edges.diagram.settingsChanged() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The window is created in code.")
    }

    var isOpen: Bool { window?.isVisible == true }

    /// Puts the window in the exact center of the screen under the pointer. The system's own
    /// `center()` deliberately sits above the middle.
    private func centerOnScreen() {
        guard let window else { return }
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        window.setFrameOrigin(
            NSPoint(
                x: area.midX - window.frame.width / 2, y: area.midY - window.frame.height / 2))
    }

    func show() {
        let wasOpen = isOpen
        // The General pane explains the permission, and gestures do nothing without it.
        if !AXIsProcessTrusted() { tabs.selectedTabViewItemIndex = Self.generalTab }
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        // The window only reaches its final size once it is on screen with its toolbar.
        if !wasOpen { centerOnScreen() }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        #if DEBUG
            // Launching with `-debugTab 2` opens that pane, which makes each pane easy to inspect.
            let tab = UserDefaults.standard.integer(forKey: "debugTab")
            if tab > 0 { tabs.selectedTabViewItemIndex = tab }
        #endif
    }

    func updateTouches(_ touches: [TouchPoint]) {
        edges.diagram.touches = touches
    }

    func settingsChanged() {
        if edges.isViewLoaded { edges.refresh() }
    }

    func windowWillClose(_ notification: Notification) {
        // The frame for the finger lifting never arrives while the window is closed.
        edges.diagram.touches = []
        NSApp.setActivationPolicy(.accessory)
    }
}
