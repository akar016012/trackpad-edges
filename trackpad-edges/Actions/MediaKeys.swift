import AppKit
import IOKit.hidsystem

/// Presses the keyboard's special keys, which brings up the native volume and brightness
/// indicators. Posting these events needs the Accessibility permission.
enum MediaKeys {
    static let soundUp = Int(NX_KEYTYPE_SOUND_UP)
    static let soundDown = Int(NX_KEYTYPE_SOUND_DOWN)
    static let brightnessUp = Int(NX_KEYTYPE_BRIGHTNESS_UP)
    static let brightnessDown = Int(NX_KEYTYPE_BRIGHTNESS_DOWN)
    static let mute = Int(NX_KEYTYPE_MUTE)
    static let illuminationUp = Int(NX_KEYTYPE_ILLUMINATION_UP)
    static let illuminationDown = Int(NX_KEYTYPE_ILLUMINATION_DOWN)
    static let playPause = Int(NX_KEYTYPE_PLAY)
    static let nextTrack = Int(NX_KEYTYPE_NEXT)
    static let previousTrack = Int(NX_KEYTYPE_PREVIOUS)

    /// Sets the modifier flags explicitly, because a held Option key would otherwise open
    /// System Settings. A fine press adds Shift and Option, which gives quarter steps.
    static func press(_ key: Int, fine: Bool = false) {
        let extra = fine ? NSEvent.ModifierFlags([.shift, .option]).rawValue : 0
        for phase in [Int(NX_KEYDOWN), Int(NX_KEYUP)] {
            let event = NSEvent.otherEvent(
                with: .systemDefined, location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(phase << 8) | extra),
                timestamp: 0, windowNumber: 0, context: nil,
                subtype: Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS),
                data1: (key << 16) | (phase << 8), data2: -1)
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
