import AppKit

/// A button that no key can press, so that only a deliberate click confirms.
private final class ClickOnlyButton: NSButton {
    override var acceptsFirstResponder: Bool { false }
}

/// The box that asks before Log Out, Restart, or Shut Down.
///
/// It is a floating panel that takes the keyboard without bringing the app to the front, so it
/// never asks macOS for activation, which could be refused. It has no default button, so Return
/// does nothing, and Escape cancels. The focus starts on Cancel and no key reaches the action
/// button, so keys that you were typing when it appeared can only cancel it. Both buttons wait one
/// second before they take clicks, and the box closes without acting after 30 seconds, when the
/// screen locks, or when the Mac sleeps.
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
    /// Runs once, with true only when you clicked the action button.
    var onFinish: ((Bool) -> Void)?

    init(question: String, detail: String, actionTitle: String) {
        actionButton = ClickOnlyButton(title: actionTitle, target: nil, action: nil)
        announcement = "\(question) \(detail)"
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 100),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView], backing: .buffered,
            defer: true)
        // The title stays hidden, but VoiceOver reads it as the name of the box.
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
        // The icon is decoration, and the question already says which app is asking.
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
        // Some versions of macOS draw the destructive style only in their own alerts.
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

    /// Shows the box on the screen under the pointer, in front of other windows, and starts its
    /// timers.
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
        // The common modes keep the timers running while a menu is open.
        for timer in [arm, expire] { RunLoop.main.add(timer, forMode: .common) }
        timers = [arm, expire]
    }

    private func arm() {
        cancelButton.isEnabled = true
        actionButton.isEnabled = true
        makeFirstResponder(cancelButton)
    }

    /// Escape cancels at any time, even before the buttons take clicks.
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
