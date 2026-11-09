/// Turns a position measured in steps into a whole step count that holds steady.
///
/// A finger that rests on the line between two steps wobbles across it, and a plain count would
/// flip back and forth with it. A step in the direction of the last one still counts at the line,
/// so a slide feels the same, and a step that turns back must pass the line by a margin.
nonisolated enum StepCount {
    /// How far past the line a step that turns back must go, as a share of one step.
    static let reverseMargin: Float = 0.25

    /// Returns the count for a position.
    ///
    /// - Parameters:
    ///   - position: The travel divided by the travel of one step.
    ///   - current: The count before this position.
    ///   - direction: The sign of the last change, or zero if nothing has changed yet.
    static func count(at position: Float, from current: Int, direction: Int) -> Int {
        let count = Int(position)
        let change = (count - current).signum()
        guard change != 0, direction != 0, change != direction else { return count }
        let confirmed = Int(position - Float(change) * reverseMargin)
        return (confirmed - current).signum() == change ? count : current
    }
}
