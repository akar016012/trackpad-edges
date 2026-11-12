import AppKit

/// A button no key can press, so only a click confirms.
private final class ClickOnlyButton: NSButton {
    override var acceptsFirstResponder: Bool { false }
}

/// The confirm box for Log Out, Restart, and Shut Down. It takes the keyboard without activating
/// the app, has no default button, and only a click confirms. Buttons arm after one second, and
/// the box cancels itself after 30 seconds, on screen lock, or on sleep.
final class ConfirmationPanel: NSPanel {
    private static let width: CGFloat = 340
    private static let margin: CGFloat = 20
    private static let armDelay: TimeInterval = 1
    private static let timeout: TimeInterval = 30

    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let actionButton: ClickOnlyButton
    private let announcement: String
    private var timers: [Timer] = []
    private var finished = false
    /// Runs once; true means the action button was clicked.
    var onFinish: ((Bool) -> Void)?

    init(question: String, detail: String, actionTitle: String) {
        actionButton = ClickOnlyButton(title: actionTitle, target: nil, action: nil)
        announcement = "\(question) \(detail)"
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView], backing: .buffered,
            defer: true)
        // VoiceOver reads the hidden title.
        title = question
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(kind)?.isHidden = true
        }
        buildContent(question: question, detail: detail)
        observeLockAndSleep()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private func buildContent(question: String, detail: String) {
        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        // The icon is decorative.
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let title = NSTextField(wrappingLabelWithString: question)
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        title.alignment = .center
        let body = NSTextField(wrappingLabelWithString: detail)
        body.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        body.alignment = .center
        let textWidth = Self.width - Self.margin * 2
        for label in [title, body] { label.preferredMaxLayoutWidth = textWidth }

        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.hasDestructiveAction = true
        // macOS may draw the destructive style only in its own alerts.
        actionButton.contentTintColor = .systemRed
        for button in [cancelButton, actionButton] {
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.isEnabled = false
        }
        let buttons = NSStackView(views: [cancelButton, actionButton])
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        buttons.widthAnchor.constraint(equalToConstant: textWidth).isActive = true

        let stack = NSStackView(views: [icon, title, body, buttons])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(18, after: body)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.margin + 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.margin),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            container.widthAnchor.constraint(equalToConstant: Self.width),
        ])
        contentView = container
        setContentSize(container.fittingSize)
    }

    /// Shows the box on the pointer's screen and starts the timers.
    func present() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            setFrameOrigin(
                NSPoint(
                    x: area.midX - frame.width / 2,
                    y: area.midY - frame.height / 2 + area.height / 6))
        }
        orderFrontRegardless()
        makeKey()
        NSAccessibility.post(
            element: self, notification: .announcementRequested,
            userInfo: [
                .announcement: announcement,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ])
        let arm = Timer(timeInterval: Self.armDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.arm() }
        }
        let expire = Timer(timeInterval: Self.timeout, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish(confirmed: false) }
        }
        // Common modes keep the timers running during menu tracking.
        for timer in [arm, expire] { RunLoop.main.add(timer, forMode: .common) }
        timers = [arm, expire]
    }

    private func arm() {
        cancelButton.isEnabled = true
        actionButton.isEnabled = true
        makeFirstResponder(cancelButton)
    }

    /// Escape cancels at any time, even before the buttons arm.
    override func cancelOperation(_ sender: Any?) {
        finish(confirmed: false)
    }

    @objc private func cancelClicked() {
        finish(confirmed: false)
    }

    @objc private func actionClicked() {
        finish(confirmed: true)
    }

    private func observeLockAndSleep() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification,
        ] {
            workspace.addObserver(self, selector: #selector(dismiss), name: name, object: nil)
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(dismiss),
            name: Notification.Name("com.apple.screenIsLocked"), object: nil)
    }

    @objc private func dismiss() {
        finish(confirmed: false)
    }

    private func finish(confirmed: Bool) {
        guard !finished else { return }
        finished = true
        for timer in timers { timer.invalidate() }
        timers = []
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default().removeObserver(self)
        orderOut(nil)
        let handler = onFinish
        onFinish = nil
        handler?(confirmed)
    }
}
