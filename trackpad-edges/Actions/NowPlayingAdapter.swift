import Foundation
import Security

/// Reads and seeks the system's Now Playing app through the bundled third-party adapter.
///
/// macOS blocks third-party apps from MediaRemote, but the system Perl can still use it. The
/// adapter is a small library that Perl loads, and this type talks to it as a child process. An
/// installed build holds the library inside the signed app. Xcode skips compiled binaries in
/// resources, so a build run from Xcode has it as base64 text and unpacks it into Application
/// Support at launch.
nonisolated struct NowPlayingAdapter: Sendable {
    struct Playback: Sendable, Equatable {
        let elapsed: Double
        let duration: Double
    }

    private static let timeout: TimeInterval = 2
    /// A longer duration than this is a bad report, and it could overflow later arithmetic.
    private static let longestDuration: Double = 1_000_000
    /// Accepts only code signed through Apple for this developer team.
    private static let signingRequirement =
        "anchor apple generic and certificate leaf[subject.OU] = \"3J6QGH6H9F\""

    private let script: URL
    private let framework: URL
    private let library: URL
    /// The expected bytes of an unpacked library. A library inside the app has no such bytes,
    /// because signing changes them, so the app's signature is checked instead.
    private let binary: Data?

    /// Returns nil if the bundled files are missing or cannot be unpacked.
    init?() {
        guard let script = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first
        else { return nil }
        let unpacked = support.appending(path: "Trackpad Edges/MediaRemoteAdapter.framework")

        if let bundled = Bundle.main.privateFrameworksURL?.appending(
            path: "MediaRemoteAdapter.framework"),
            FileManager.default.fileExists(atPath: bundled.appending(path: "MediaRemoteAdapter").path)
        {
            // A writable copy from an earlier build is no longer needed.
            try? FileManager.default.removeItem(at: unpacked)
            self.script = script
            framework = bundled
            library = bundled.appending(path: "MediaRemoteAdapter")
            binary = nil
            return
        }

        guard
            let encoded = Bundle.main.url(forResource: "MediaRemoteAdapter", withExtension: "base64"),
            let text = try? Data(contentsOf: encoded),
            let binary = Data(base64Encoded: text, options: .ignoreUnknownCharacters)
        else { return nil }
        self.script = script
        framework = unpacked
        library = unpacked.appending(path: "MediaRemoteAdapter")
        self.binary = binary
        guard libraryIsTrusted() else { return nil }
    }

    /// Decides whether the library is safe to load, and restores an unpacked copy if it needs it.
    private func libraryIsTrusted() -> Bool {
        guard let binary else { return Self.appSignatureIsIntact() }
        if (try? Data(contentsOf: library)) == binary { return true }
        // Another copy of the app can remove this file, and these bytes are the known good ones.
        try? FileManager.default.createDirectory(at: framework, withIntermediateDirectories: true)
        try? binary.write(to: library, options: .atomic)
        return (try? Data(contentsOf: library)) == binary
    }

    /// Checks the whole app against its signature, including the library and the Perl script.
    /// Perl does not validate what it loads, so this is what protects a library inside the app.
    private static func appSignatureIsIntact() -> Bool {
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard
            SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess,
            SecRequirementCreateWithString(signingRequirement as CFString, [], &requirement)
                == errSecSuccess,
            let code
        else { return false }
        let flags = SecCSFlags(rawValue: kSecCSCheckNestedCode | kSecCSStrictValidate)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
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
        // library that shipped with the app. Anything running as you can write to both places the
        // library can sit, so it is checked each time. A clean environment stops Perl options such
        // as PERL5OPT from loading other code.
        guard libraryIsTrusted() else { return nil }
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
