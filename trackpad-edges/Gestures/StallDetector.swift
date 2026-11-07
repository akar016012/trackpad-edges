import Foundation

/// Notices when the main thread stops answering, using beats that it sends while it is healthy.
nonisolated struct StallDetector: Sendable {
    /// How long the main thread can stay silent. Its beats normally come every quarter second.
    var limit: TimeInterval = 0.75

    private var lastBeat: TimeInterval
    private var isStalled = false

    init(now: TimeInterval) {
        lastBeat = now
    }

    /// Records a beat, and returns true if this ends a stall.
    mutating func beat(now: TimeInterval) -> Bool {
        lastBeat = now
        defer { isStalled = false }
        return isStalled
    }

    /// Returns true once for each stall, at the moment it passes the limit.
    mutating func check(now: TimeInterval) -> Bool {
        guard !isStalled, now - lastBeat > limit else { return false }
        isStalled = true
        return true
    }
}
