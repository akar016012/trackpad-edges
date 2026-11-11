import Foundation

/// Decides whether a power action may run, from the time that the Mac last woke or unlocked.
///
/// A finger that was already resting on a corner when the Mac woke could otherwise lock it or put
/// it straight back to sleep. A deliberate press in the quiet period is ignored too.
nonisolated struct PowerActionGuard: Equatable, Sendable {
    /// How long after a wake or an unlock these actions are ignored, in seconds.
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
