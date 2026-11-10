import Foundation

/// A short recording of raw touch data, which helps set thresholds on a trackpad that the
/// project has never tried.
///
/// The file holds each trackpad's family ID and whether it is built in. For each frame, it
/// holds the time since the recording began and every contact's number, position, pressure, and
/// size. It holds nothing else, so it says nothing about what was on the screen.
nonisolated struct TouchRecording: Codable, Equatable, Sendable {
    /// How long a recording runs. It stops by itself, so the file stays small.
    static let duration: TimeInterval = 10
    /// A recording stops taking frames here even if they arrive faster than any trackpad sends.
    static let maxFrames = 5000

    struct Contact: Codable, Equatable, Sendable {
        /// The framework's number for this contact, which stays the same while it is down.
        var id: Int32
        var x: Double
        var y: Double
        var pressure: Double
        var size: Double
        var majorAxis: Double
    }

    struct Frame: Codable, Equatable, Sendable {
        /// Seconds since the recording began.
        var time: Double
        /// The index of the trackpad in `trackpads`.
        var trackpad: Int
        var contacts: [Contact]
    }

    var version = 1
    var trackpads: [TrackpadInfo]
    var frames: [Frame] = []

    init(trackpads: [TrackpadInfo]) {
        self.trackpads = trackpads
    }

    /// Adds one frame. A frame from a trackpad that the recording does not list is left out.
    mutating func add(_ touches: [TouchPoint], trackpad: Int, at time: TimeInterval) {
        guard trackpads.indices.contains(trackpad), frames.count < Self.maxFrames else { return }
        frames.append(
            Frame(
                time: Self.rounded(time, places: 3), trackpad: trackpad,
                contacts: touches.map {
                    Contact(
                        id: $0.id, x: Self.rounded(Double($0.x), places: 4),
                        y: Self.rounded(Double($0.y), places: 4),
                        pressure: Self.rounded(Double($0.pressure), places: 2),
                        size: Self.rounded(Double($0.size), places: 3),
                        majorAxis: Self.rounded(Double($0.majorAxis), places: 3))
                }))
    }

    /// The recording as compact JSON with its keys in a fixed order.
    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Rounding keeps the file small, because a float prints with many more digits than it holds.
    private static func rounded(_ value: Double, places: Int) -> Double {
        guard value.isFinite else { return 0 }
        let scale = pow(10, Double(places))
        return (value * scale).rounded() / scale
    }
}
