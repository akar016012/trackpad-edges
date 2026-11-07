import AppKit

extension NSWindow {
    /// Puts the window in the exact center of the screen under the pointer. The system's own
    /// `center()` deliberately sits above the middle.
    func centerOnPointerScreen() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.midY - frame.height / 2))
    }
}

/// Reports tab changes, so that the window can fit the newly selected pane.
private final class PaneTabViewController: NSTabViewController {
    var onSelect: (() -> Void)?

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        onSelect?()
    }
}

/// Owns the app window. The app appears in the Dock only while it has a window open.
final class MainWindowController: NSWindowController, NSWindowDelegate {
    /// The tabs in window order.
    enum Tab: Int {
        case edges, corners, media, haptics, profiles, general
    }

    private let edges: EdgesPane
    private let corners: CornersPane
    private let profiles: ProfilesPane
    private let tabs = PaneTabViewController()
    /// Called when the window closes.
    var onClose: (() -> Void)?

    init(actions: WindowActions) {
        edges = EdgesPane(title: "Edges", actions: actions)
        corners = CornersPane(title: "Corners", actions: actions)
        profiles = ProfilesPane(title: "Profiles", actions: actions)
        let media = MediaPane(title: "Media", actions: actions)
        let haptics = HapticsPane(title: "Haptics", actions: actions)
        let general = GeneralPane(title: "General", actions: actions)

        tabs.tabStyle = .toolbar
        tabs.transitionOptions = []
        tabs.canPropagateSelectedChildViewControllerTitle = false
        let glyphs = [
            (edges as SettingsPane, "GlyphEdges"), (corners, "GlyphCorners"),
            (media, "GlyphMedia"), (haptics, "GlyphHaptics"), (profiles, "GlyphProfiles"),
            (general, "GlyphGeneral"),
        ]
        for (pane, glyph) in glyphs {
            let item = NSTabViewItem(viewController: pane)
            item.label = pane.title ?? ""
            item.image = NSImage(named: glyph)
            item.image?.size = NSSize(width: 24, height: 24)
            item.image?.isTemplate = true
            tabs.addTabViewItem(item)
        }

        let window = NSWindow(contentViewController: tabs)
        window.title = "Trackpad Edges"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        window.delegate = self
        tabs.onSelect = { [weak self] in self?.fitPane() }
        corners.onChange = { [weak self] in
            self?.edges.diagram.settingsChanged()
            self?.fitPane()
        }
        general.onLayoutChange = { [weak self] in self?.fitPane() }
        for pane in [edges as ProfilePane, corners] {
            pane.onLayoutChange = { [weak self] in self?.fitPane() }
            pane.onSelectProfile = { [weak self] bundleID in self?.selectProfile(bundleID) }
        }
        profiles.onEdit = { [weak self] bundleID, tab in
            self?.selectProfile(bundleID)
            self?.tabs.selectedTabViewItemIndex = tab.rawValue
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The window is created in code.")
    }

    var isOpen: Bool { window?.isVisible == true || window?.isMiniaturized == true }

    /// Sizes the window to the selected pane around its current center, so that every pane has
    /// the same margins and the window stays where it is.
    private func fitPane() {
        let index = tabs.selectedTabViewItemIndex
        guard let window, tabs.tabViewItems.indices.contains(index),
            let pane = tabs.tabViewItems[index].viewController
        else { return }
        pane.view.layoutSubtreeIfNeeded()
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        window.setContentSize(pane.view.fittingSize)
        var frame = window.frame
        frame.origin = NSPoint(x: center.x - frame.width / 2, y: center.y - frame.height / 2)
        // Growing around the center must not push the title bar under the menu bar.
        window.setFrame(window.constrainFrameRect(frame, to: window.screen), display: true)
    }

    func show() {
        let wasOpen = isOpen
        // The General pane explains the permission, and gestures do nothing without it.
        if !AXIsProcessTrusted() { tabs.selectedTabViewItemIndex = Tab.general.rawValue }
        #if DEBUG
            // Launching with `-debugTab 2` opens that pane, which makes each pane easy to inspect.
            let defaults = UserDefaults.standard
            if defaults.object(forKey: "debugTab") != nil {
                tabs.selectedTabViewItemIndex = defaults.integer(forKey: "debugTab")
            }
        #endif
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        // The window only reaches its final size once it is on screen with its toolbar.
        fitPane()
        if !wasOpen { window?.centerOnPointerScreen() }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    func updateTouches(_ touches: [TouchPoint]) {
        edges.diagram.touches = touches
    }

    func settingsChanged() {
        if edges.isViewLoaded {
            edges.refreshProfiles()
            edges.refresh()
        }
        corners.refreshProfiles()
        profiles.refresh()
    }

    /// Shows one profile on both panes that edit a profile.
    private func selectProfile(_ bundleID: String?) {
        edges.select(bundleID)
        corners.select(bundleID)
        fitPane()
    }

    func windowWillClose(_ notification: Notification) {
        // The frame for the finger lifting never arrives while the window is closed.
        edges.diagram.touches = []
        onClose?()
    }
}
