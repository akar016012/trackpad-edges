import Foundation

/// A key from the system's own shortcut table, which Keyboard settings writes.
///
/// macOS offers apps no way to change a Focus, but Keyboard settings can assign a key to Do Not
/// Disturb. The app reads that key each time and presses it.
nonisolated struct SymbolicHotKey: Equatable, Sendable {
    /// The table entry for turning Do Not Disturb on or off.
    static let doNotDisturb = "175"
    /// The key code that the table uses for no key.
    private static let noKey = 65535

    let keyCode: UInt16
    /// The modifier flags, in the same bits that key events use.
    let modifiers: UInt64

    /// Reads one entry of the table, which is the `AppleSymbolicHotKeys` dictionary of the
    /// `com.apple.symbolichotkeys` domain. An entry holds `enabled` and a `value` whose
    /// `parameters` are the character, the key code, and the modifier flags. Returns nil for an
    /// entry that is missing, turned off, unset, or not in that form.
    init?(entry: String, in table: [String: Any]?) {
        guard let item = table?[entry] as? [String: Any],
            (item["enabled"] as? NSNumber)?.boolValue == true,
            let value = item["value"] as? [String: Any],
            value["type"] as? String == "standard",
            let parameters = value["parameters"] as? [NSNumber], parameters.count >= 3
        else { return nil }
        let code = parameters[1].intValue
        let flags = parameters[2].int64Value
        guard code != Self.noKey, (0..<Int(UInt16.max)).contains(code), flags >= 0 else {
            return nil
        }
        keyCode = UInt16(code)
        modifiers = UInt64(flags)
    }
}
