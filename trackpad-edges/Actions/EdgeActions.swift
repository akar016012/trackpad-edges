import AppKit
import Carbon.HIToolbox

/// Carries out one step of whatever an edge controls.
final class EdgeActions {
    private static let scrollPixels: Int32 = 48
    /// How long a frozen app can hold up this thread, which also answers every click.
    private static let switchTimeout: Float = 0.25
    /// The system's identifiers for moving one Space left and right.
    private static let spaceHotKeys = ["79", "81"]

    private let volume = VolumeController()
    private let brightness = BrightnessController()
    private let keyboardBacklight = KeyboardBacklightController()
    private let monitors = ExternalDisplayController()
    /// The apps that a slide moves through, and where it has reached. The list is fixed for one
    /// slide, because the front app takes a moment to change after each step.
    private var switcherApps: [NSRunningApplication] = []
    private var switcherIndex = 0

    /// Runs when an action becomes available or stops being available.
    var onAvailabilityChanged: (() -> Void)? {
        didSet { monitors.onAvailabilityChanged = onAvailabilityChanged }
    }

    /// The actions that cannot work right now, which the settings show as unavailable.
    var unavailable: Set<SlideKind> {
        var kinds: Set<SlideKind> = []
        if !brightness.isAvailable { kinds.insert(.brightness) }
        if !monitors.isAvailable { kinds.insert(.externalBrightness) }
        if !spaceShortcutsAreOn { kinds.insert(.switchSpaces) }
        return kinds
    }

    /// Reads the system's own shortcut list. A shortcut that was never changed is not listed.
    private var spaceShortcutsAreOn: Bool {
        let keys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
            .dictionary(forKey: "AppleSymbolicHotKeys")
        return Self.spaceHotKeys.allSatisfy { key in
            (keys?[key] as? [String: Any])?["enabled"] as? Bool ?? true
        }
    }

    /// Whether macOS is holding the keyboard backlight off because the room is bright.
    var keyboardBacklightIsLocked: Bool { keyboardBacklight.isLocked }

    func refreshDisplays() {
        monitors.refresh()
    }

    func begin(_ kind: SlideKind) {
        switch kind {
        case .externalBrightness:
            monitors.readLevels()
        case .switchApps:
            switcherApps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && !$0.isHidden
            }
            let front = NSWorkspace.shared.frontmostApplication
            switcherIndex = switcherApps.firstIndex { $0 == front } ?? 0
        default:
            break
        }
    }

    /// Moves one step, and returns false if the action is already at a limit.
    func step(_ kind: SlideKind, up: Bool, fine: Bool) -> Bool {
        switch kind {
        case .volume:
            return volume.step(up: up, fine: fine)
        case .brightness:
            return brightness.step(up: up, fine: fine)
        case .keyboardBacklight:
            return keyboardBacklight.step(up: up, fine: fine)
        case .externalBrightness:
            return monitors.step(up: up)
        case .scroll:
            scroll(up: up)
            return true
        case .zoom:
            let key = up ? kVK_ANSI_Equal : kVK_ANSI_Minus
            KeyPoster.press(
                keyCode: UInt16(key), modifiers: CGEventFlags.maskCommand.rawValue,
                releaseFlags: CGEventFlags.maskCommand.rawValue)
            return true
        case .switchApps:
            return switchApp(forward: up)
        case .switchSpaces:
            // Arrow keys carry these extra flags, and the system shortcut needs them to match.
            let flags = CGEventFlags([.maskControl, .maskSecondaryFn, .maskNumericPad]).rawValue
            KeyPoster.press(
                keyCode: UInt16(up ? kVK_RightArrow : kVK_LeftArrow), modifiers: flags,
                releaseFlags: flags)
            return true
        case .seek:
            return false
        }
    }

    /// Scrolls in the direction the system uses, so a slide feels like two-finger scrolling.
    private func scroll(up: Bool) {
        // The key is absent until the setting first changes, and natural scrolling is the default.
        let natural = UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection")
        let distance = up == (natural as? Bool ?? true) ? -Self.scrollPixels : Self.scrollPixels
        let event = CGEvent(
            scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: distance, wheel2: 0,
            wheel3: 0)
        // The mark lets this through the pointer freeze, which drops other scrolling in a slide.
        event?.setIntegerValueField(.eventSourceUserData, value: ClickTap.ownEventMarker)
        event?.post(tap: .cghidEventTap)
    }

    /// Brings the next app forward through Accessibility, because macOS ignores a plain activation
    /// request from an app that is not in front.
    private func switchApp(forward: Bool) -> Bool {
        guard switcherApps.count > 1 else { return false }
        let count = switcherApps.count
        switcherIndex = (switcherIndex + (forward ? 1 : count - 1)) % count
        let app = AXUIElementCreateApplication(switcherApps[switcherIndex].processIdentifier)
        AXUIElementSetMessagingTimeout(app, Self.switchTimeout)
        let result = AXUIElementSetAttributeValue(
            app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        // A slow app can time out and still come forward, and Switch Apps has no limit to report.
        return result == .success || result == .cannotComplete
    }
}
