import Foundation

/// Run Command logic that needs no system calls, so it can be unit tested.
nonisolated enum ShellCommand {
    /// Used when the account's shell is unusable.
    static let fallbackShell = "/bin/zsh"
    /// The starting path. The login shell adds the rest from your profile.
    static let basePath = "/usr/bin:/bin:/usr/sbin:/sbin"
    /// The only variables passed on from the app, so nothing like `DYLD_` reaches the command.
    static let inheritedNames: Set<String> = [
        "USER", "LOGNAME", "TMPDIR", "LANG", "SSH_AUTH_SOCK", "__CF_USER_TEXT_ENCODING",
    ]
    /// Bytes of error output kept, from the end.
    static let tailLimit = 4096
    /// Lines of error output in a failure report.
    static let reportedLines = 3
    /// Maximum characters of error output in a failure report.
    static let reportedLength = 200

    /// A command counts only if it is not blank.
    static func isConfigured(_ script: String) -> Bool {
        !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The account's shell, unless it is missing, relative, or a refusing shell like `nologin`.
    static func shell(accountShell: String?, isExecutable: (String) -> Bool) -> String {
        guard let shell = accountShell, shell.hasPrefix("/"),
            !["false", "nologin"].contains((shell as NSString).lastPathComponent),
            isExecutable(shell)
        else { return fallbackShell }
        return shell
    }

    /**
     `-l` loads your profile so your tools are on the path; `-c` skips the interactive setup,
     which can hang without a terminal.
     */
    static func arguments(for script: String) -> [String] {
        ["-l", "-c", script]
    }

    /// Builds the command's environment from an allowlist.
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

        /// Decodes a `waitpid` status, since Swift cannot use the C macros.
        init(waitStatus: Int32) {
            let signal = waitStatus & 0x7f
            self = signal == 0 ? .exited((waitStatus >> 8) & 0xff) : .signaled(signal)
        }
    }

    /**
     Describes a failure, or returns nil for success or a command you stopped. The summary fits
     the overlay, and the body adds error output. `corner` is a short name such as `top-left`.
     */
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

/// Keeps only the end of a command's error output, to bound memory.
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

    /// The last non-blank lines, trimmed.
    func lastLines(_ count: Int) -> [String] {
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(lines.suffix(count))
    }
}
