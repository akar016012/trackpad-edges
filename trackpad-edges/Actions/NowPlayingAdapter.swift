import Foundation

/// Reads and seeks the system's Now Playing app through the bundled third-party adapter.
///
/// macOS blocks third-party apps from MediaRemote, but the system Perl can still use it. The
/// adapter is a small library that Perl loads, and this type talks to it as a child process. The
/// build skips compiled binaries in resources, so the library ships as base64 text and is unpacked
/// into Application Support at launch.
nonisolated struct NowPlayingAdapter: Sendable {
    struct Playback: Sendable, Equatable {
        let elapsed: Double
        let duration: Double
    }

    private static let timeout: TimeInterval = 2
    /// A longer duration than this is a bad report, and it could overflow later arithmetic.
    private static let longestDuration: Double = 1_000_000

    private let script: URL
    private let framework: URL
    private let library: URL
    private let binary: Data

    /// Returns nil if the bundled files are missing or cannot be unpacked.
    init?() {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let encoded = Bundle.main.url(forResource: "MediaRemoteAdapter", withExtension: "base64"),
            let text = try? Data(contentsOf: encoded),
            let binary = Data(base64Encoded: text, options: .ignoreUnknownCharacters),
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return nil }

        let framework = support.appending(path: "Trackpad Edges/MediaRemoteAdapter.framework")
        let library = framework.appending(path: "MediaRemoteAdapter")
        if (try? Data(contentsOf: library)) != binary {
            do {
                try FileManager.default.createDirectory(
                    at: framework, withIntermediateDirectories: true)
                try binary.write(to: library, options: .atomic)
            } catch {
                return nil
            }
        }
        self.script = script
        self.framework = framework
        self.library = library
        self.binary = binary
    }

    /// Reads the current position. This blocks, so it must not run on the main thread.
    func playback() -> Playback? {
        guard let output = run(["get", "--now", "--no-artwork", "--allow-missing-title"]),
            let object = try? JSONSerialization.jsonObject(with: output) as? [String: Any],
            let duration = object["duration"] as? Double, duration.isFinite, duration > 0,
            duration <= Self.longestDuration,
            let elapsed = object["elapsedTimeNow"] as? Double ?? object["elapsedTime"] as? Double,
            elapsed.isFinite
        else { return nil }
        return Playback(elapsed: min(max(elapsed, 0), duration), duration: duration)
    }

    /// Seeks to a position in seconds. This blocks, so it must not run on the main thread.
    func seek(to seconds: Double) {
        _ = run(["seek", String(Int(max(seconds, 0) * 1_000_000))])
    }

    private func run(_ arguments: [String]) -> Data? {
        // The child inherits this app's Accessibility permission, so it must run only the exact
        // library that shipped with the app. The folder is writable by anything running as you,
        // so the bytes are checked each time. A clean environment stops Perl options such as
        // PERL5OPT from loading other code.
        guard (try? Data(contentsOf: library)) == binary else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.environment = ["PATH": "/usr/bin:/bin"]
        process.arguments = [script.path, framework.path] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        // A stuck adapter must not hold up later reads, so it gets a short time limit.
        let watchdog = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeout, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()
        return process.terminationStatus == 0 ? data : nil
    }
}
