import AppKit

/// Presses the keyboard's special keys, which brings up the native volume and brightness
/// indicators. Posting these events needs the Accessibility permission.
enum MediaKeys {
    static let soundUp = 0
    static let soundDown = 1
    static let brightnessUp = 2
    static let brightnessDown = 3
    static let mute = 7
    static let illuminationUp = 21
    static let illuminationDown = 22
    static let playPause = 16
    static let nextTrack = 17
    static let previousTrack = 18

    /// Sets the modifier flags explicitly, because a held Option key would otherwise open
    /// System Settings. A fine press adds Shift and Option, which gives quarter steps.
    static func press(_ key: Int, fine: Bool = false) {
        let extra = fine ? NSEvent.ModifierFlags([.shift, .option]).rawValue : 0
        for (flags, phase) in [(UInt(0xa00), 0xa), (UInt(0xb00), 0xb)] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: flags | extra), timestamp: 0,
                windowNumber: 0, context: nil, subtype: 8, data1: (key << 16) | (phase << 8),
                data2: -1)
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

/// Presses a key on the user's behalf. The mark tells the app's own taps to ignore the event.
enum KeyPoster {
    static func press(keyCode: UInt16, modifiers: UInt64, releaseFlags: UInt64) {
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isDown)
            event?.flags = CGEventFlags(rawValue: isDown ? modifiers : releaseFlags)
            event?.setIntegerValueField(.eventSourceUserData, value: ClickTap.ownEventMarker)
            event?.post(tap: .cghidEventTap)
        }
    }
}
