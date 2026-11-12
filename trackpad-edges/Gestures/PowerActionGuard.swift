import Foundation

/// Blocks sleep and lock actions just after a wake or unlock, so a resting finger cannot undo the
/// wake.
nonisolated struct PowerActionGuard: Equatable, Sendable {
    /// Seconds after a wake or unlock during which these actions are ignored.
    static let quietPeriod: TimeInterval = 3

    private var lastWake: TimeInterval?

    mutating func recordWake(at time: TimeInterval) {
        lastWake = time
    }

    func allows(_ action: SystemAction, at time: TimeInterval) -> Bool {
        guard action.pausesAfterWake, let lastWake else { return true }
        return time - lastWake >= Self.quietPeriod
    }
}
