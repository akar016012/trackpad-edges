import Foundation

/// Decides when a brightness slide has reached a limit.
nonisolated enum BrightnessLimit {
    /// The app can read only the built-in display's level. The brightness keys can act on the
    /// display under the pointer instead, such as through a monitor utility, so that level says
    /// nothing about a slide made with the pointer on another display.
    static func isReached(level: Float?, up: Bool, pointerOnBuiltIn: Bool) -> Bool {
        guard pointerOnBuiltIn, let level else { return false }
        return up ? level >= 1 : level <= 0
    }
}
