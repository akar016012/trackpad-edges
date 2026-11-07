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

/// Turns finger travel into whole seek steps, in the same way that a slide changes the volume.
///
/// The distance depends only on how far the finger travels, never on how fast it moves, so the
/// same slide always moves the same amount. This type has no system dependencies, so unit tests
/// can drive it.
nonisolated struct SeekScrubber {
    /// The finger travel for one step as a fraction of the pad width.
    var stepTravel: Float = 0.05

    private(set) var steps = 0
    private var start: Float?

    /// Adds the movement since the slide began. Returns true when the step count changes.
    ///
    /// Travel past the limits is forgotten, so that the count responds as soon as the finger
    /// turns back.
    mutating func update(travel: Float, limits: ClosedRange<Int>? = nil) -> Bool {
        // The first update only sets the starting point, so that crossing the dead zone cannot
        // jump the count.
        guard let origin = start else {
            start = travel
            return false
        }
        var count = Int((travel - origin) / stepTravel)
        if let limits, !limits.contains(count) {
            let clamped = min(max(count, limits.lowerBound), limits.upperBound)
            start = origin + Float(count - clamped) * stepTravel
            count = clamped
        }
        defer { steps = count }
        return count != steps
    }
}
