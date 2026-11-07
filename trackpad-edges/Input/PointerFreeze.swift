import CoreGraphics

/// Holds the pointer still during a slide and leaves it exactly where it was.
///
/// Detaching the pointer from the mouse needs no permission. The event tap needs the Accessibility
/// permission, and it is enabled only during a slide because an always-active tap on pointer
/// movement can slow the cursor.
final class PointerFreeze {
    static let shared = PointerFreeze()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var frozenPoint: CGPoint?

    func begin() {
        guard frozenPoint == nil, let location = CGEvent(source: nil)?.location else { return }
        installTapIfPossible()
        frozenPoint = location
        CGAssociateMouseAndMouseCursorPosition(0)
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    func end() {
        guard let point = frozenPoint else { return }
        frozenPoint = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    /// Removes the tap, because a tap can stall input after the permission is revoked.
    func uninstall() {
        end()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    /// Creating the tap fails until the permission is granted, so each slide tries again.
    private func installTapIfPossible() {
        guard tap == nil else { return }
        let types: [CGEventType] = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask, callback: pointerTapCallback, userInfo: nil),
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: false)
        tap = port
        source = runLoopSource
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if frozenPoint != nil, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard let point = frozenPoint else { return Unmanaged.passUnretained(event) }
        CGWarpMouseCursorPosition(point)
        return nil
    }
}

/// The tap's run loop source is on the main run loop, so this always runs on the main thread.
private nonisolated func pointerTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    MainActor.assumeIsolated {
        PointerFreeze.shared.handle(type: type, event: event)
    }
}
