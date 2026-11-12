import CoreGraphics

/**
 Watches left clicks so that a gesture can hold them back from other apps.

 This tap sees only click events, so it stays on all the time without slowing the pointer. It
 needs the Accessibility permission, and without it every click passes through untouched.
 */
final class ClickTap {
    static let shared = ClickTap()
    /// Marks events that this app posts, so that the tap lets them through.
    nonisolated static let ownEventMarker: Int64 = 0x4544_4745

    /// Returns true to swallow the mouse-down.
    var onMouseDown: ((CGEvent) -> Bool)?
    /// Returns true to swallow the mouse-up. The proxy can post an event ahead of it.
    var onMouseUp: ((CGEvent, CGEventTapProxy) -> Bool)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    var isInstalled: Bool { tap != nil }
    var port: CFMachPort? { tap }

    /**
     Asks the system whether a tap is still allowed, by creating one that does no work, as well
     as through the documented check. A tap whose permission was removed can stop clicks for the
     whole Mac, so this does not rely on any one answer.
     */
    static var isAllowed: Bool {
        guard CGPreflightPostEventAccess() else { return false }
        let mask = CGEventMask(1) << CGEventMask(CGEventType.tabletProximity.rawValue)
        guard
            let probe = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, _, event, _ in Unmanaged.passUnretained(event) }, userInfo: nil)
        else { return false }
        CGEvent.tapEnable(tap: probe, enable: false)
        CFMachPortInvalidate(probe)
        return true
    }

    /// Installs the tap if possible and repairs it if macOS turned it off.
    func refresh() {
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let mask =
            (CGEventMask(1) << CGEventMask(CGEventType.leftMouseDown.rawValue))
            | (CGEventMask(1) << CGEventMask(CGEventType.leftMouseUp.rawValue))
        guard
            let port = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask, callback: clickTapCallback, userInfo: nil),
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        tap = port
        source = runLoopSource
    }

    /// Removes the tap, because a tap can stall input after the permission is revoked.
    func uninstall() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    fileprivate func handle(
        type: CGEventType, event: CGEvent, proxy: CGEventTapProxy
    ) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.ownEventMarker else {
            return Unmanaged.passUnretained(event)
        }
        let swallow: Bool
        switch type {
        case .leftMouseDown: swallow = onMouseDown?(event) ?? false
        case .leftMouseUp: swallow = onMouseUp?(event, proxy) ?? false
        default: swallow = false
        }
        return swallow ? nil : Unmanaged.passUnretained(event)
    }
}

/// The tap's run loop source is on the main run loop, so this always runs on the main thread.
private nonisolated func clickTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    MainActor.assumeIsolated {
        ClickTap.shared.handle(type: type, event: event, proxy: proxy)
    }
}
