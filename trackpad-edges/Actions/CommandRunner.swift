import AppKit
import Darwin

/** Runs the commands of Run Command corners through the login shell, in the background. A
    command never gets the app's permissions; if that cannot be ensured, it does not run. Each
    command gets its own process group, so Stop ends everything it started. */
final class CommandRunner {
    /// Makes a child process answer for its own permissions.
    private typealias DisclaimCall =
        @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32

    /// How long a stopped command gets before it is killed.
    private static let stopGrace: TimeInterval = 2

    /// A running command, keyed by its text.
    private final class Job {
        var pid: pid_t?
        var stopped = false
    }

    /// The outcome of starting a command.
    private enum SpawnResult {
        case started(pid: pid_t, errors: Int32)
        /// macOS refused to separate the command from the app's permissions.
        case notSeparated
        case failed
    }

    /// How often to check for processes left running after the shell ends.
    private static let groupCheckInterval: TimeInterval = 1

    private let disclaim: DisclaimCall?
    private let queue = DispatchQueue(label: "commands", qos: .utility)
    private var jobs: [String: Job] = [:]

    /// Runs when a command starts or ends.
    var onChange: (() -> Void)?
    /// Shows a notice with a title and a detail line.
    var showNotice: ((String, String) -> Void)?
    /// Reports a failure with a title, a short summary, and a body with the error output.
    var reportFailure: ((CornerSlot, String, String, String) -> Void)?

    init() {
        // The handle -2 is RTLD_DEFAULT, which Swift does not import, so this searches every image.
        let address = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim")
        disclaim = address.map { unsafeBitCast($0, to: DisclaimCall.self) }
    }

    var runningScripts: Set<String> { Set(jobs.keys) }

    func isRunning(_ script: String) -> Bool { jobs[script] != nil }

    func run(_ script: String, corner: CornerSlot) {
        guard ShellCommand.isConfigured(script) else { return }
        guard let disclaim else {
            // A command must never run with the app's permissions.
            showNotice?("Command Not Run", "macOS cannot keep it apart from this app.")
            return
        }
        guard jobs[script] == nil else {
            showNotice?("Command Still Running", "Stop it from the Corners tab or the menu bar.")
            return
        }
        let job = Job()
        jobs[script] = job
        onChange?()

        let accountShell = getpwuid(getuid())?.pointee.pw_shell.map { String(cString: $0) }
        let shell = ShellCommand.shell(accountShell: accountShell) {
            FileManager.default.isExecutableFile(atPath: $0)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let environment = ShellCommand.environment(
            inherited: ProcessInfo.processInfo.environment, home: home, shell: shell)
        let arguments = [shell] + ShellCommand.arguments(for: script)
        queue.async { [weak self] in
            let started = Self.spawn(
                shell: shell, arguments: arguments, environment: environment, home: home,
                disclaim: disclaim)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.didStart(started, script: script, job: job, corner: corner)
                }
            }
        }
    }

    private func didStart(_ result: SpawnResult, script: String, job: Job, corner: CornerSlot) {
        guard case .started(let pid, let errors) = result else {
            jobs[script] = nil
            onChange?()
            if case .notSeparated = result {
                showNotice?("Command Not Run", "macOS cannot keep it apart from this app.")
            } else {
                showNotice?("Command Not Run", "Your login shell could not start.")
            }
            return
        }
        job.pid = pid
        // Apply a Stop that came during startup.
        if job.stopped { Self.signal(group: pid) }
        watch(pid: pid, errors: errors) { [weak self] end, tail in
            guard let self, self.jobs[script] === job else { return }
            if let failure = ShellCommand.failure(
                end, stopped: job.stopped, tail: tail, corner: corner.shortName)
            {
                self.reportFailure?(corner, failure.title, failure.summary, failure.body)
            }
            self.finishWhenGroupEnds(pid: pid, script: script, job: job)
        }
    }

    /// Keeps a command listed while anything in its process group still runs, such as a
    /// background job.
    private func finishWhenGroupEnds(pid: pid_t, script: String, job: Job) {
        guard jobs[script] === job else { return }
        guard kill(-pid, 0) == -1, errno == ESRCH else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.groupCheckInterval) {
                [weak self] in
                self?.finishWhenGroupEnds(pid: pid, script: script, job: job)
            }
            return
        }
        jobs[script] = nil
        onChange?()
    }

    /// Ends a command and everything it started.
    func stop(_ script: String) {
        guard let job = jobs[script], !job.stopped else { return }
        job.stopped = true
        if let pid = job.pid { Self.signal(group: pid) }
    }

    func stopAll() {
        for script in jobs.keys { stop(script) }
    }

    /// Asks every command to end when the app quits. The app cannot wait, so a command that
    /// ignores this keeps running.
    func stopAllForQuit() {
        for job in jobs.values {
            if let pid = job.pid { kill(-pid, SIGTERM) }
        }
    }

    /** Sends SIGTERM to the process group, then SIGKILL if it remains. A group keeps its ID
        while any member lives, so the kill cannot hit another program. */
    private static func signal(group pid: pid_t) {
        kill(-pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + stopGrace) {
            if kill(-pid, 0) == 0 { kill(-pid, SIGKILL) }
        }
    }

    /// Collects error output and finishes when the process exits, not at end of output, which a
    /// background job can hold open forever.
    private func watch(
        pid: pid_t, errors: Int32,
        _ finished: @escaping @MainActor (ShellCommand.End, OutputTail) -> Void
    ) {
        let queue = DispatchQueue(label: "command-output", qos: .utility)
        /// Only the output queue touches this, so it needs no lock.
        final class Output {
            var tail = OutputTail()
            var isClosed = false
        }
        let output = Output()
        _ = fcntl(errors, F_SETFL, fcntl(errors, F_GETFL) | O_NONBLOCK)
        let reader = DispatchSource.makeReadSource(fileDescriptor: errors, queue: queue)
        // Cancel at end of output: a pipe at EOF always reads as ready, so the source would spin.
        let drain = {
            guard !output.isClosed else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            while true {
                let count = read(errors, &buffer, buffer.count)
                if count > 0 {
                    output.tail.append(Data(buffer[0..<count]))
                    continue
                }
                if count < 0, errno == EINTR { continue }
                // No data has arrived yet.
                if count < 0, errno == EAGAIN { break }
                // EOF or an error keeps the pipe ready forever, so stop reading.
                output.isClosed = true
                reader.cancel()
                break
            }
        }
        reader.setEventHandler(handler: drain)
        reader.setCancelHandler { close(errors) }
        reader.resume()
        // A blocking wait cannot miss an exit, unlike an exit event set up too late.
        Thread.detachNewThread {
            var status: Int32 = 0
            while waitpid(pid, &status, 0) == -1, errno == EINTR {}
            queue.async {
                drain()
                output.isClosed = true
                reader.cancel()
                let end = ShellCommand.End(waitStatus: status)
                let result = output.tail
                DispatchQueue.main.async { MainActor.assumeIsolated { finished(end, result) } }
            }
        }
    }

    /// Starts the shell and returns its PID and error-output pipe, or why it did not start.
    nonisolated private static func spawn(
        shell: String, arguments: [String], environment: [String: String], home: String,
        disclaim: DisclaimCall
    ) -> SpawnResult {
        var pipeEnds: [Int32] = [0, 0]
        guard pipe(&pipeEnds) == 0 else { return .failed }
        defer { close(pipeEnds[1]) }

        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_adddup2(&actions, pipeEnds[1], 2)
        posix_spawn_file_actions_addchdir_np(&actions, home)

        var attributes: posix_spawnattr_t?
        posix_spawnattr_init(&attributes)
        defer { posix_spawnattr_destroy(&attributes) }
        // Pass only the standard streams, reset signals, and start a new process group.
        let flags =
            POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF
            | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))
        posix_spawnattr_setpgroup(&attributes, 0)
        var noSignals = sigset_t()
        var allSignals = ~sigset_t()
        posix_spawnattr_setsigmask(&attributes, &noSignals)
        posix_spawnattr_setsigdefault(&attributes, &allSignals)
        // Without this, the command would inherit the app's permissions.
        guard disclaim(&attributes, 1) == 0 else {
            close(pipeEnds[0])
            return .notSeparated
        }

        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { for pointer in argv + envp { free(pointer) } }
        var pid: pid_t = 0
        guard posix_spawn(&pid, shell, &actions, &attributes, argv, envp) == 0 else {
            close(pipeEnds[0])
            return .failed
        }
        return .started(pid: pid, errors: pipeEnds[0])
    }
}
