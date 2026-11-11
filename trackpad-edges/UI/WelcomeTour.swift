import AppKit

/// Decides whether the tour opens by itself. Anyone with saved settings already knows the app.
enum WelcomeProgress {
    private static let key = "welcomeProgress"
    private static let pending = "pending"
    private static let finished = "finished"

    static var shouldShow: Bool {
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: key) {
        case finished: return false
        case pending: return true
        default:
            let isNew = !SettingsStore.hasSavedSettings
            defaults.set(isNew ? pending : finished, forKey: key)
            return isNew
        }
    }

    static func markFinished() {
        UserDefaults.standard.set(finished, forKey: key)
    }
}

/// Shows where the tour has reached.
private final class StepDots: NSView {
    private static let size: CGFloat = 7
    private static let gap: CGFloat = 8

    private let count: Int
    var current = 0 {
        didSet {
            needsDisplay = true
            setAccessibilityValue("Step \(current + 1) of \(count)")
        }
    }

    init(count: Int) {
        self.count = count
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("Tour progress")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The dots are created in code.")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: CGFloat(count) * (Self.size + Self.gap) - Self.gap, height: Self.size)
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<count {
            let origin = NSPoint(x: CGFloat(index) * (Self.size + Self.gap), y: 0)
            let dot = NSRect(origin: origin, size: NSSize(width: Self.size, height: Self.size))
            let color: NSColor = index == current ? .controlAccentColor : .tertiaryLabelColor
            color.setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }
}

/// Walks a new user through the permission, a first slide, and the main settings. Every control
/// here changes the real settings, so the app is set up when the tour ends.
final class WelcomeTour: SettingsPane {
    private struct Preset {
        let title: String
        let left: SlideKind?
        let right: SlideKind?
        let top: SlideKind?
        let bottom: SlideKind?
    }

    private static let presets = [
        Preset(title: "Everyday", left: .brightness, right: .volume, top: nil, bottom: .seek),
        Preset(title: "Browsing", left: .switchApps, right: .scroll, top: .zoom, bottom: .switchSpaces),
        Preset(title: "Volume Only", left: nil, right: .volume, top: nil, bottom: nil),
    ]
    private static let cornerChoices: [(title: String, action: CornerAction)] =
        [CornerAction.none, .mute, .playPause, .nextTrack, .previousTrack].map {
            (CornerActionKind($0).title, $0)
        }
    private static let pageHeight: CGFloat = 330
    private static let iconSize: CGFloat = 128

    /// Called when the tour reaches its end.
    var onFinish: (() -> Void)?

    private var pages: [NSView] = []
    private var titles: [String] = []
    private var pageIndex = 0
    private var dots: StepDots?
    private lazy var skipButton = button("Skip Tour") { [weak self] in self?.onFinish?() }
    private lazy var backButton = button("Back") { [weak self] in self?.goBack() }
    private lazy var nextButton = button("") { [weak self] in self?.goForward() }

    private let permissionLabel = NSTextField(labelWithString: "")
    private var grantButton: NSButton?
    private var permissionTimer: Timer?
    private let slideLabel = NSTextField(labelWithString: "")
    private var tryPageView: NSView?
    private let tryDiagram = TrackpadDiagramView()
    private let edgesDiagram = TrackpadDiagramView()
    private var presetPopup: NSPopUpButton?
    private var edgePopups: [(popup: NSPopUpButton, slot: EdgeSlot)] = []
    private var loginCheckbox: NSButton?

    override func loadView() {
        pages = [
            welcomePage(), permissionPage(), tryPage(), edgesPage(), cornersPage(), hapticsPage(),
            finishPage(),
        ]
        let holder = NSView()
        holder.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            holder.heightAnchor.constraint(equalToConstant: Self.pageHeight),
            holder.widthAnchor.constraint(equalToConstant: Self.contentWidth),
        ])
        for page in pages {
            page.translatesAutoresizingMaskIntoConstraints = false
            holder.addSubview(page)
            NSLayoutConstraint.activate([
                page.topAnchor.constraint(equalTo: holder.topAnchor),
                page.leadingAnchor.constraint(equalTo: holder.leadingAnchor),
                page.trailingAnchor.constraint(equalTo: holder.trailingAnchor),
            ])
        }
        setContent([holder, makeBar()])
        show(page: 0)
    }

    private func makeBar() -> NSView {
        let dots = StepDots(count: pages.count)
        self.dots = dots
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nextButton.keyEquivalent = "\r"
        let bar = NSStackView(views: [dots, spacer, skipButton, backButton, nextButton])
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        return bar
    }

    private func show(page index: Int) {
        pageIndex = index
        for (position, page) in pages.enumerated() { page.isHidden = position != index }
        dots?.current = index
        announce("Step \(index + 1) of \(pages.count). \(titles[index])")
        skipButton.isHidden = index == pages.count - 1
        backButton.isHidden = index == 0
        nextButton.title = index == pages.count - 1 ? "Done" : "Continue"
        refreshPermission()
        refreshEdges()
        loginCheckbox?.state = LoginItem.isEnabled ? .on : .off
    }

    private func announce(_ text: String) {
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [
                .announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
    }

    private func goBack() {
        show(page: max(pageIndex - 1, 0))
    }

    private func goForward() {
        if pageIndex == pages.count - 1 {
            onFinish?()
        } else {
            show(page: pageIndex + 1)
        }
    }

    /// Opens the tour at one step, which makes each step easy to inspect.
    func open(page index: Int) {
        _ = view
        show(page: min(max(index, 0), pages.count - 1))
    }

    // MARK: Pages

    private func titleLabel(_ text: String) -> NSTextField {
        titles.append(text)
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }

    private func bodyLabel(_ text: String) -> NSTextField {
        let label = paragraph(text, width: Self.contentWidth)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func page(_ title: String, _ text: String, _ content: [NSView]) -> NSView {
        let header = column([titleLabel(title), bodyLabel(text)], spacing: 6)
        return column([header] + content, spacing: 20)
    }

    private func welcomePage() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        let title = titleLabel("Welcome to Trackpad Edges")
        let text = bodyLabel(
            "The edges and corners of your trackpad become controls, and the middle keeps working as it always has. This short tour sets everything up."
        )
        text.alignment = .center
        let stack = column([icon, title, text], spacing: 12)
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 0, bottom: 0, right: 0)
        return stack
    }

    private func permissionPage() -> NSView {
        let grant = button("Grant Accessibility…") { [weak self] in
            self?.actions.requestAccessibility()
        }
        grantButton = grant
        permissionLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let status = NSStackView(views: [permissionLabel, grant])
        status.orientation = .horizontal
        status.spacing = 12
        return page(
            "Allow the app to help",
            "Gestures need the Accessibility permission, because the app presses the volume and brightness keys for you and keeps stray clicks out of other apps. Your touches stay on this Mac.",
            [status])
    }

    private func tryPage() -> NSView {
        slideLabel.stringValue = "The diagram shows your fingers as you touch the trackpad."
        slideLabel.textColor = .secondaryLabelColor
        slideLabel.lineBreakMode = .byWordWrapping
        slideLabel.preferredMaxLayoutWidth = Self.columnWidth
        slideLabel.maximumNumberOfLines = 3
        let steps = column(
            [
                heading("Touch a strip"),
                paragraph("Rest one finger on a colored strip near the edge of your trackpad."),
                heading("Slide along it"),
                paragraph("Each step gives you a tick that you can feel."),
                slideLabel,
            ], spacing: 6)
        let row = columns(tryDiagram, steps)
        tryDiagram.heightAnchor.constraint(equalToConstant: 196).isActive = true
        let view = page(
            "Try your first slide", "A tap does nothing, so a slide only happens when you mean it.",
            [row])
        tryPageView = view
        return view
    }

    private func edgesPage() -> NSView {
        let titles = Self.presets.map(\.title) + ["Custom"]
        let preset = popup(titles, selected: 0) { [weak self] index in self?.applyPreset(index) }
        presetPopup = preset
        let rows = form([
            ("Start from:", preset), ("Left edge:", edgePopup(.left)),
            ("Right edge:", edgePopup(.right)), ("Top edge:", edgePopup(.top)),
            ("Bottom edge:", edgePopup(.bottom)),
        ])
        let row = columns(edgesDiagram, rows)
        edgesDiagram.heightAnchor.constraint(equalTo: rows.heightAnchor).isActive = true
        return page(
            "Choose your edges", "Pick a starting point, and then change any edge you like.", [row])
    }

    private func edgePopup(_ slot: EdgeSlot) -> NSPopUpButton {
        let choices = EdgesPane.choices
        let edge = popup(choices.map(\.title), selected: 0) { [weak self] index in
            self?.settings[keyPath: slot.path] = choices[index].kind
            self?.refreshEdges()
        }
        edge.autoenablesItems = false
        edgePopups.append((edge, slot))
        return edge
    }

    private func applyPreset(_ index: Int) {
        guard Self.presets.indices.contains(index) else { return }
        let preset = Self.presets[index]
        var edited = settings
        edited.leftEdge = usable(preset.left)
        edited.rightEdge = usable(preset.right)
        edited.topEdge = usable(preset.top)
        edited.bottomEdge = usable(preset.bottom)
        settings = edited
        refreshEdges()
    }

    /// A preset leaves an edge off rather than choosing an action that cannot work here.
    private func usable(_ kind: SlideKind?) -> SlideKind? {
        guard let kind, !actions.unavailableKinds().contains(kind) else { return nil }
        return kind
    }

    private func refreshEdges() {
        let current = settings
        let unavailable = actions.unavailableKinds()
        let choices = EdgesPane.choices
        for (popup, slot) in edgePopups {
            let kind = current[keyPath: slot.path]
            popup.selectItem(at: choices.firstIndex { $0.kind == kind } ?? 0)
            for (item, choice) in zip(popup.itemArray, choices) {
                item.isEnabled = choice.kind.map { !unavailable.contains($0) } ?? true
                item.toolTip = item.isEnabled ? nil : choice.kind?.unavailableReason
            }
        }
        let match = Self.presets.firstIndex {
            $0.left == current.leftEdge && $0.right == current.rightEdge
                && $0.top == current.topEdge && $0.bottom == current.bottomEdge
        }
        presetPopup?.selectItem(at: match ?? Self.presets.count)
        tryDiagram.settingsChanged()
        edgesDiagram.settingsChanged()
    }

    private func cornersPage() -> NSView {
        let top = columns(cornerSection("Top left", .topLeft), cornerSection("Top right", .topRight))
        let bottom = columns(
            cornerSection("Bottom left", .bottomLeft), cornerSection("Bottom right", .bottomRight))
        return page(
            "Choose your corners",
            "Press a corner lightly to fire it. The Corners tab can also open apps, links, and files, press keys, run shortcuts and commands, or lock, sleep, and restart the Mac.",
            [top, bottom])
    }

    private func cornerSection(_ title: String, _ slot: CornerSlot) -> NSView {
        let original = settings[keyPath: slot.path]
        let corner = original
        let choices = Self.cornerChoices
        // A corner set up in more detail keeps its setup until you choose something else here.
        let isSimple = corner.configuredClicks.isSubset(of: [1])
        let match = isSimple ? choices.firstIndex { $0.action == corner[1] } : nil
        let titles = choices.map(\.title) + (match == nil ? ["Keep Current Actions"] : [])
        let picker = popup(titles, selected: match ?? choices.count) { [weak self] index in
            self?.settings[keyPath: slot.path] =
                choices.indices.contains(index)
                ? CornerSetting(action: choices[index].action, clicks: 1) : original
            self?.refreshEdges()
        }
        picker.setAccessibilityLabel("\(title) corner action")
        picker.widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true
        return column([heading(title), picker])
    }

    private func hapticsPage() -> NSView {
        let current = settings.haptics
        let patterns = HapticPattern.allCases
        let enabled = checkbox("Feel a tick on each step", isOn: current.enabled) {
            [weak self] isOn in self?.settings.haptics.enabled = isOn
        }
        let strength = slider(
            value: Double(current.strength), range: Self.sliderRange(HapticSettings.strengthRange)
        ) { [weak self] value in self?.settings.haptics.strength = Float(value) }
        let pattern = popup(
            patterns.map(\.rawValue.capitalized),
            selected: patterns.firstIndex(of: current.pattern) ?? 0
        ) { [weak self] index in self?.settings.haptics.pattern = patterns[index] }
        let test = button("Feel It") { [weak self] in self?.actions.testHaptic() }
        let rows = form([
            ("Haptics:", enabled), ("Strength:", strength), ("Pattern:", pattern), ("", test),
        ])
        return page(
            "Choose how it feels",
            "Your trackpad taps back as you slide. Set how strong that feels, and try it.",
            [columns(rows, NSView())])
    }

    private func finishPage() -> NSView {
        let login = checkbox("Start Trackpad Edges when I log in", isOn: LoginItem.isEnabled) {
            [weak self] isOn in
            LoginItem.set(isOn)
            self?.loginCheckbox?.state = LoginItem.isEnabled ? .on : .off
        }
        loginCheckbox = login
        return page(
            "You are all set",
            "The app stays in your menu bar. Its icon opens these settings at any time, and you can take this tour again from the General tab.",
            [
                login,
                column(
                    [
                        heading("When you want more"),
                        paragraph(
                            "Two fingers can do something different on each edge, and each app can have a profile of its own. Both are in the app window.",
                            width: Self.contentWidth),
                    ], spacing: 6),
                column(
                    [
                        heading("Enjoying it?"),
                        paragraph(
                            "A star on GitHub helps other people find the app.",
                            width: Self.contentWidth),
                        starButton(),
                    ], spacing: 6),
            ])
    }

    /// GitHub cannot star a project from a link, so this opens the page that holds the Star button.
    private func starButton() -> NSButton {
        let star = button("Star on GitHub") { NSWorkspace.shared.open(ProjectLinks.repository) }
        star.toolTip = "Opens the project page in your browser."
        star.setAccessibilityHelp(star.toolTip)
        return star
    }

    // MARK: Live updates

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshPermission()
        permissionTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshPermission()
                // This also catches an approval given in System Settings.
                self?.loginCheckbox?.state = LoginItem.isEnabled ? .on : .off
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func refreshPermission() {
        let trusted = AXIsProcessTrusted()
        permissionLabel.stringValue = trusted ? "Accessibility is on." : "Accessibility is off."
        permissionLabel.textColor = trusted ? .systemGreen : .labelColor
        grantButton?.isHidden = trusted
    }

    func updateTouches(_ touches: [TouchPoint]) {
        tryDiagram.touches = touches
        edgesDiagram.touches = touches
    }

    /// Marks the first slide on its step, which is the moment the app proves that it works.
    func slideHappened() {
        guard pages.indices.contains(pageIndex), pages[pageIndex] === tryPageView,
            slideLabel.textColor != .systemGreen
        else { return }
        slideLabel.stringValue = "That was a slide, so everything works."
        slideLabel.textColor = .systemGreen
        announce(slideLabel.stringValue)
    }

    /// Brings the edge controls in step after the menu bar item changes an edge.
    func settingsChanged() {
        if isViewLoaded { refreshEdges() }
    }
}

/// Owns the tour's window, which stays on screen until you finish or close it.
final class WelcomeWindowController: NSWindowController, NSWindowDelegate {
    private let tour: WelcomeTour
    /// Called when the window closes, however that happens.
    var onClose: (() -> Void)?

    init(actions: WindowActions) {
        tour = WelcomeTour(title: "Welcome", actions: actions)
        let window = NSWindow(contentViewController: tour)
        window.title = "Welcome to Trackpad Edges"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.autorecalculatesKeyViewLoop = true
        super.init(window: window)
        window.delegate = self
        tour.onFinish = { [weak self] in self?.close() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("The window is created in code.")
    }

    func show(page: Int = 0) {
        tour.open(page: page)
        NSApp.setActivationPolicy(.regular)
        showWindow(nil)
        window?.centerOnPointerScreen()
        NSApp.bringForward()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Brings an open tour to the front, without moving it or changing its step.
    func bringForward() {
        NSApp.bringForward()
        window?.makeKeyAndOrderFront(nil)
    }

    func settingsChanged() {
        tour.settingsChanged()
    }

    func updateTouches(_ touches: [TouchPoint]) {
        tour.updateTouches(touches)
    }

    func slideHappened() {
        tour.slideHappened()
    }

    func windowWillClose(_ notification: Notification) {
        tour.updateTouches([])
        WelcomeProgress.markFinished()
        onClose?()
    }
}
