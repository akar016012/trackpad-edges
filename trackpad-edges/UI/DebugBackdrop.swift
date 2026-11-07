#if DEBUG
    import AppKit

    /// A window behind the seek preview, because glass can only be judged against real content.
    final class DebugBackdrop {
        private final class Pattern: NSView {
            var kind = "white"

            override func draw(_ dirtyRect: NSRect) {
                (kind == "black" ? NSColor.black : NSColor.white).setFill()
                bounds.fill()
                guard kind == "stripes" else { return }
                for (index, color) in [NSColor.black, .systemRed, .systemBlue, .white].enumerated()
                {
                    color.setFill()
                    var x = CGFloat(index) * 24
                    while x < bounds.width {
                        NSRect(x: x, y: 0, width: 24, height: bounds.height).fill()
                        x += 96
                    }
                }
            }
        }

        private let window: NSWindow

        init(kind: String) {
            let size = NSSize(width: 440, height: 210)
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless,
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.level = .floating
            let pattern = Pattern()
            pattern.kind = kind
            window.contentView = pattern
            if let area = NSScreen.main?.visibleFrame {
                window.setFrameOrigin(
                    NSPoint(x: area.midX - size.width / 2, y: area.midY - size.height / 2))
            }
            window.orderFrontRegardless()
        }
    }
#endif
