/// How far one seek step moves the media.
nonisolated enum SeekStep: Equatable, Sendable {
    case percent(Double)
    case seconds(Double)

    func length(duration: Double) -> Double {
        switch self {
        case .percent(let percent): return duration * percent / 100
        case .seconds(let seconds): return seconds
        }
    }
}

/**
 Turns finger travel into whole seek steps, in the same way that a slide changes the volume.

 The distance depends only on how far the finger travels, never on how fast it moves, so the
 same slide always moves the same amount. This type has no system dependencies, so unit tests
 can drive it.
 */
nonisolated struct SeekScrubber {
    /// The finger travel for one step as a fraction of the pad width.
    var stepTravel: Float = 0.05

    private(set) var steps = 0
    private var start: Float?
    /// The sign of the last step, which a step that turns back must overcome by a margin.
    private var direction = 0

    /**
     Adds the movement since the slide began. Returns true when the step count changes.

     Travel past the limits is forgotten, so that the count responds soon after the finger
     turns back. A finger held past a limit can come to rest on a step line, so turning back
     needs the same small margin as any other reversal, or the count could flicker there.
     */
    mutating func update(travel: Float, limits: ClosedRange<Int>? = nil) -> Bool {
        /* The first update only sets the starting point, so that crossing the dead zone cannot
           jump the count. */
        guard let origin = start else {
            start = travel
            return false
        }
        /* The plain count is what measures travel past a limit, and the steady count is what
           is reported. */
        let position = (travel - origin) / stepTravel
        let reached = Int(position)
        var count = StepCount.count(at: position, from: steps, direction: direction)
        // The direction follows the finger, so it is taken before the limits change the count.
        if count != steps { direction = (count - steps).signum() }
        if let limits {
            if !limits.contains(reached) {
                let clamped = min(max(reached, limits.lowerBound), limits.upperBound)
                start = origin + Float(reached - clamped) * stepTravel
            }
            // The limits can arrive after steps were counted, so the steady count is held to them.
            count = min(max(count, limits.lowerBound), limits.upperBound)
        }
        defer { steps = count }
        return count != steps
    }
}
