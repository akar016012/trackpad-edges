import Foundation

/// A key from the system shortcut table. Apps cannot change a Focus directly, so Toggle Do Not
/// Disturb presses the key assigned in Keyboard settings.
nonisolated struct SymbolicHotKey: Equatable, Sendable {
    /// The Do Not Disturb entry.
    static let doNotDisturb = "175"
    /// The table's "no key" code.
    private static let noKey = 65535

    let keyCode: UInt16
    /// Modifier flags, in key-event bits.
    let modifiers: UInt64

    /// Reads an entry of `AppleSymbolicHotKeys`, whose `parameters` are the character, the key
    /// code, and the modifiers. Returns nil if it is missing, off, unset, or malformed.
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
