import AppKit

/**
 A progress bar that snaps to each value. The system bar glides between values, which hides
 the steps of a seek.
 */
private final class SteppedBarView: NSView {
    var value: Double = 0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        let track = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor.tertiaryLabelColor.setFill()
        track.fill()
        // The fill is clipped to the track, so even the smallest step shows as movement.
        track.addClip()
        var filled = bounds
        filled.size.width = bounds.width * min(max(value, 0), 1)
        NSColor.controlAccentColor.setFill()
        filled.fill()
    }
}

/**
 A rounded fill. It draws its color each time, so that it follows light and dark mode, which a
 color stored on a layer would not.
 */
private final class SolidBackgroundView: NSView {
    var cornerRadius: CGFloat = 0
    var color = NSColor.windowBackgroundColor

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
    }
}

/**
 A small floating panel that previews a seek or shows a short notice. It never takes focus or
 receives clicks.
 */
final class SeekOverlayPanel: NSPanel {
    private static let size = NSSize(width: 320, height: 92)
    private static let cornerRadius: CGFloat = 22
    private static let screenInset: CGFloat = 120

    private let timeLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "Release to apply")
    private let progress = SteppedBarView()
    private let content = NSView()
    private var pendingHide: DispatchWorkItem?
    private var placement = OverlayPlacement.bottom
    /// The appearance for styles that follow the system. Nil means the system's own.
    var baseAppearance: NSAppearance?

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        isReleasedWhenClosed = false
        buildContent()
        apply(style: .glass, placement: .bottom)
    }

    /// Rebuilds the background, because each style is a different kind of view.
    func apply(style chosen: OverlayStyle, placement: OverlayPlacement) {
        self.placement = placement
        let style = Self.drawnStyle(for: chosen)
        /* Clear glass and the frosted material show whatever is behind them, so they always use a
           dimmed tint with light text, which stays readable over bright and dark content. */
        let alwaysDark = style == .clearGlass || style == .frosted
        appearance = alwaysDark ? NSAppearance(named: .darkAqua) : baseAppearance
        content.removeFromSuperview()
        let background = makeBackground(for: style)
        background.frame = NSRect(origin: .zero, size: Self.size)
        background.autoresizingMask = [.width, .height]

        let root = NSView(frame: NSRect(origin: .zero, size: Self.size))
        root.addSubview(background)
        contentView = root
        hasShadow = style != .clearGlass
        invalidateShadow()
        if isVisible { moveIntoPlace() }
    }

    /**
     Glass arrived in macOS 26, so earlier systems draw the frosted style instead, with its
     colors and shadow as well as its background.
     */
    private static func drawnStyle(for style: OverlayStyle) -> OverlayStyle {
        if #available(macOS 26.0, *) { return style }
        return style == .glass || style == .clearGlass ? .frosted : style
    }

    /// Shows the target time. The change is the share of the track that it moves, from -1 to 1.
    func show(position: Double, duration: Double, change: Double) {
        timeLabel.stringValue = "\(Self.format(position)) / \(Self.format(duration))"
        let percent = Int((change * 100).rounded()).formatted(
            // The rest of this line is English, so the number stays in the same form.
            .percent.sign(strategy: .always(includingZero: false))
                .locale(Locale(identifier: "en_US_POSIX")))
        hintLabel.stringValue = "\(percent) · Release to apply"
        progress.isHidden = false
        hintLabel.isHidden = false
        progress.value = duration > 0 ? position / duration : 0
        present()
    }

    func show(message: String) {
        timeLabel.stringValue = message
        progress.isHidden = true
        hintLabel.isHidden = true
        present()
    }

    /// Shows a short notice, which has a title and one line that explains it.
    func show(title: String, detail: String) {
        timeLabel.stringValue = title
        hintLabel.stringValue = detail
        progress.isHidden = true
        hintLabel.isHidden = false
        present()
    }

    func hide(after delay: TimeInterval) {
        pendingHide?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.orderOut(nil) }
        pendingHide = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func present() {
        pendingHide?.cancel()
        pendingHide = nil
        guard !isVisible else { return }
        moveIntoPlace()
        orderFrontRegardless()
    }

    private func moveIntoPlace() {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        let y: CGFloat
        switch placement {
        case .bottom: y = area.minY + Self.screenInset
        case .center: y = area.midY - Self.size.height / 2
        case .top: y = area.maxY - Self.screenInset - Self.size.height
        }
        setFrameOrigin(NSPoint(x: area.midX - Self.size.width / 2, y: y))
    }

    private func makeBackground(for style: OverlayStyle) -> NSView {
        switch style {
        case .glass, .clearGlass:
            // Glass arrived in macOS 26, so earlier systems show the frosted style instead.
            guard #available(macOS 26.0, *) else { return makeBackground(for: .frosted) }
            let glass = NSGlassEffectView()
            glass.style = style == .glass ? .regular : .clear
            glass.tintColor = style == .glass ? nil : NSColor.black.withAlphaComponent(0.45)
            glass.cornerRadius = Self.cornerRadius
            glass.contentView = content
            return glass
        case .frosted:
            let frosted = NSVisualEffectView()
            frosted.material = .hudWindow
            frosted.blendingMode = .behindWindow
            frosted.state = .active
            /* A mask image is what rounds this view. A layer's corner radius has no effect on
               a material that draws behind the window. */
            frosted.maskImage = Self.roundedMask()
            let dimmer = SolidBackgroundView()
            dimmer.cornerRadius = Self.cornerRadius
            dimmer.color = NSColor.black.withAlphaComponent(0.35)
            install(dimmer, in: frosted)
            install(content, in: dimmer)
            return frosted
        case .solid:
            let solid = SolidBackgroundView()
            solid.cornerRadius = Self.cornerRadius
            install(content, in: solid)
            return solid
        }
    }

    /**
     Pins the content with constraints, because a glass view that held it earlier leaves it
     without any size of its own.
     */
    private func install(_ view: NSView, in parent: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: parent.topAnchor),
            view.bottomAnchor.constraint(equalTo: parent.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
        ])
    }

    private static func roundedMask() -> NSImage {
        // The single point between the corner caps is the part that stretches.
        let side = cornerRadius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        image.resizingMode = .stretch
        return image
    }

    private func buildContent() {
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        timeLabel.alignment = .center
        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        /* Secondary label color is too faint over glass. An alpha variant would stop following
           light and dark mode, so this stays a plain system color. */
        hintLabel.textColor = .labelColor

        let stack = NSStackView(views: [timeLabel, progress, hintLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: Self.size.width - 48),
            progress.heightAnchor.constraint(equalToConstant: 6),
        ])
    }

    private static func format(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let remainder = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }
}
