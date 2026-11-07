import AppKit

/// Presses the keyboard's special keys, which brings up the native volume and brightness
/// indicators. Posting these events needs the Accessibility permission.
enum MediaKeys {
    static let soundUp = 0
    static let soundDown = 1
    static let brightnessUp = 2
    static let brightnessDown = 3
    static let mute = 7
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
