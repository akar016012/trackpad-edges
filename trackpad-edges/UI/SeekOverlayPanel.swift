import AppKit

/// A progress bar that snaps to each value. The system bar glides between values, which hides
/// the steps of a seek.
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

/// A small floating preview of a seek. It never takes focus or receives clicks.
final class SeekOverlayPanel: NSPanel {
    private static let size = NSSize(width: 320, height: 92)
    private static let distanceFromBottom: CGFloat = 120

    private let timeLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "Release to apply")
    private let progress = SteppedBarView()
    private var pendingHide: DispatchWorkItem?

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
        hasShadow = true
        isReleasedWhenClosed = false
        buildContent()
    }

    /// Shows the target time. The change is the share of the track that it moves, from -1 to 1.
    func show(position: Double, duration: Double, change: Double) {
        timeLabel.stringValue = "\(Self.format(position)) / \(Self.format(duration))"
        let percent = Int((change * 100).rounded())
        hintLabel.stringValue = "\(percent > 0 ? "+" : "")\(percent)% · Release to apply"
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
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            setFrameOrigin(
                NSPoint(
                    x: area.midX - Self.size.width / 2, y: area.minY + Self.distanceFromBottom))
        }
        orderFrontRegardless()
    }

    private func buildContent() {
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        timeLabel.alignment = .center
        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [timeLabel, progress, hintLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: Self.size.width - 48),
            progress.heightAnchor.constraint(equalToConstant: 6),
        ])
        contentView = background
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
