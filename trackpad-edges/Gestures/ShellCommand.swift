import Foundation

/// The decisions behind Run Command that need no system, so that unit tests can cover them.
nonisolated enum ShellCommand {
    /// The shell to use when the account names none that can run.
    static let fallbackShell = "/bin/zsh"
    /// A short path for the shell to start from. A login shell adds the rest from your profile.
    static let basePath = "/usr/bin:/bin:/usr/sbin:/sbin"
    /// The values that a command inherits from the app. Everything else is left out, so that
    /// nothing that steers how programs load, such as `DYLD_` values, reaches the command.
    static let inheritedNames: Set<String> = [
        "USER", "LOGNAME", "TMPDIR", "LANG", "SSH_AUTH_SOCK", "__CF_USER_TEXT_ENCODING",
    ]
    /// How much error output is kept, counted from its end.
    static let tailLimit = 4096
    /// How many lines of error output a failure report shows.
    static let reportedLines = 3
    /// The longest error output that a failure report shows, in characters.
    static let reportedLength = 200

    /// A command counts only when it holds something besides spaces.
    static func isConfigured(_ script: String) -> Bool {
        !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Picks the account's own shell, unless it is missing, relative, or one that only refuses.
    static func shell(accountShell: String?, isExecutable: (String) -> Bool) -> String {
        guard let shell = accountShell, shell.hasPrefix("/"),
            !["false", "nologin"].contains((shell as NSString).lastPathComponent),
            isExecutable(shell)
        else { return fallbackShell }
        return shell
    }

    /// The arguments after the shell's own path. A login shell reads your profile file, so the
    /// tools that you installed are on the path, and `-c` keeps it from reading the interactive
    /// setup file, which can be slow and can wait for a terminal that is not there.
    static func arguments(for script: String) -> [String] {
        ["-l", "-c", script]
    }

    /// Builds the command's environment from an allowlist of the app's own values.
    static func environment(
        inherited: [String: String], home: String, shell: String
    ) -> [String: String] {
        var result = inherited.filter { inheritedNames.contains($0.key) || $0.key.hasPrefix("LC_") }
        result["HOME"] = home
        result["SHELL"] = shell
        result["PATH"] = basePath
        return result
    }

    /// How a command ended.
    enum End: Equatable, Sendable {
        case exited(Int32)
        case signaled(Int32)

        /// Reads the status that `waitpid` reports. Swift cannot use the C macros that do this.
        init(waitStatus: Int32) {
            let signal = waitStatus & 0x7f
            self = signal == 0 ? .exited((waitStatus >> 8) & 0xff) : .signaled(signal)
        }
    }

    /// Describes a failure in full sentences, or returns nil for a command that succeeded or that
    /// you stopped yourself. The summary is short enough for the overlay notice, and the body adds
    /// the last lines of error output for a notification. The corner is its short name, such as
    /// `top-left`.
    static func failure(
        _ end: End, stopped: Bool, tail: OutputTail, corner: String
    ) -> (title: String, summary: String, body: String)? {
        guard !stopped else { return nil }
        let ending: String
        switch end {
        case .exited(0): return nil
        case .exited(let code): ending = "ended with status \(code)."
        case .signaled(let signal): ending = "was ended by signal \(signal)."
        }
        var body = "The \(corner) corner's command \(ending)"
        let lines = tail.lastLines(reportedLines).joined(separator: " ")
        if !lines.isEmpty {
            let shown = lines.count > reportedLength ? "…" + lines.suffix(reportedLength) : lines
            body += " Its last error output was: \(shown)"
        }
        return ("Command Failed", "The \(corner) command \(ending)", body)
    }
}

/// Keeps the end of a command's error output, so that a command that prints a lot cannot use up
/// memory.
nonisolated struct OutputTail: Equatable, Sendable {
    private(set) var data = Data()
    let limit: Int

    init(limit: Int = ShellCommand.tailLimit) {
        self.limit = limit
    }

    mutating func append(_ chunk: Data) {
        data.append(chunk)
        if data.count > limit { data = Data(data.suffix(limit)) }
    }

    /// The last lines that hold text, without their surrounding spaces.
    func lastLines(_ count: Int) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }
}
