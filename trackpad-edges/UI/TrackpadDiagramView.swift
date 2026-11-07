import AppKit

/// Draws the trackpad with its configured zones, and shows live fingers while the window is open.
final class TrackpadDiagramView: NSView {
    var touches: [TouchPoint] = [] {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 294, height: 196) }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .image }

    override func accessibilityLabel() -> String? {
        let settings = SettingsStore.shared.settings
        let left = Self.title(for: settings.leftEdge) ?? "Off"
        let right = Self.title(for: settings.rightEdge) ?? "Off"
        let bottom = Self.title(for: settings.bottomEdge) ?? "Off"
        return "Trackpad diagram. The left edge is \(left), the right edge is \(right), and the bottom edge is \(bottom)."
    }

    func settingsChanged() {
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let settings = SettingsStore.shared.settings
        let pad = bounds.insetBy(dx: 1, dy: 1)
        let outline = NSBezierPath(roundedRect: pad, xRadius: 12, yRadius: 12)
        NSColor.controlBackgroundColor.setFill()
        outline.fill()

        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        let width = CGFloat(settings.edgeWidth)
        let quarter = settings.bottomQuarterOnly ? 0.25 : 1.0
        let side = pad.height * quarter
        drawZone(
            NSRect(x: pad.minX, y: pad.minY, width: pad.width * width, height: side),
            title: Self.title(for: settings.leftEdge), rotated: true)
        drawZone(
            NSRect(
                x: pad.maxX - pad.width * width, y: pad.minY, width: pad.width * width, height: side
            ), title: Self.title(for: settings.rightEdge), rotated: true)
        drawZone(
            NSRect(x: pad.minX, y: pad.minY, width: pad.width, height: pad.height * width),
            title: Self.title(for: settings.bottomEdge), rotated: false)
        let cornerSize = NSSize(width: pad.width * 0.20, height: pad.height * 0.17)
        let leftX = pad.minX
        let rightX = pad.maxX - cornerSize.width
        let topY = pad.maxY - cornerSize.height
        let corners = [
            (settings.topLeft, NSPoint(x: leftX, y: topY)),
            (settings.topRight, NSPoint(x: rightX, y: topY)),
            (settings.bottomLeft, NSPoint(x: leftX, y: pad.minY)),
            (settings.bottomRight, NSPoint(x: rightX, y: pad.minY)),
        ]
        for (corner, origin) in corners where corner.action.isConfigured {
            drawZone(
                NSRect(origin: origin, size: cornerSize), title: "\(corner.clicks)×", rotated: false)
        }
        NSGraphicsContext.restoreGraphicsState()

        NSColor.separatorColor.setStroke()
        outline.lineWidth = 1
        outline.stroke()

        NSColor.controlAccentColor.setFill()
        for touch in touches {
            let center = NSPoint(
                x: pad.minX + pad.width * CGFloat(touch.x),
                y: pad.minY + pad.height * CGFloat(touch.y))
            NSBezierPath(
                ovalIn: NSRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)
            ).fill()
        }
    }

    private static func title(for kind: SlideKind?) -> String? {
        switch kind {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .seek: return "Media Seek"
        case nil: return nil
        }
    }

    private func drawZone(_ rect: NSRect, title: String?, rotated: Bool) {
        guard let title else { return }
        NSColor.controlAccentColor.withAlphaComponent(0.22).setFill()
        rect.fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ]
        let text = title as NSString
        let size = text.size(withAttributes: attributes)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: rect.midX, yBy: rect.midY)
        if rotated { transform.rotate(byDegrees: 90) }
        transform.concat()
        text.draw(at: NSPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attributes)
        NSGraphicsContext.restoreGraphicsState()
    }
}
