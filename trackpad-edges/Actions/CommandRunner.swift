import AppKit
import Darwin

/// Runs the shell commands of Run Command corners in the background.
///
/// A command runs through your login shell, with no window, no input, and your home folder as its
/// working folder. It starts in a way that makes it answer for its own permissions, so it never
/// borrows the app's Accessibility or Automation permission. If that cannot be done, the command
/// does not run. Each command runs in its own process group, so that Stop ends the command and
/// everything that it started.
final class CommandRunner {
    /// The private call that makes a child process answer for its own permissions.
    private typealias DisclaimCall =
        @convention(c) (UnsafeMutablePointer<posix_spawnattr_t?>, Int32) -> Int32

    /// How long a stopped command gets to end before it is killed.
    private static let stopGrace: TimeInterval = 2

    /// One command that is running, by its text.
    private final class Job {
        var pid: pid_t?
        var stopped = false
    }

    /// Why a command did not start.
    private enum SpawnResult {
        case started(pid: pid_t, errors: Int32)
        /// macOS refused to keep the command apart from the app's permissions.
        case notSeparated
        case failed
    }

    /// How often the app checks whether anything that a finished shell started is still running.
    private static let groupCheckInterval: TimeInterval = 1

    private let disclaim: DisclaimCall?
    private let queue = DispatchQueue(label: "commands", qos: .utility)
    private var jobs: [String: Job] = [:]

    /// Runs when a command starts or ends, so that the Stop buttons can follow.
    var onChange: (() -> Void)?
    /// Shows a short notice, with a title and a sentence that says what to do.
    var showNotice: ((String, String) -> Void)?
    /// Reports a command that failed, with a title, a short summary, and a longer body that holds
    /// the last lines of error output.
    var reportFailure: ((CornerSlot, String, String, String) -> Void)?

    init() {
        let address = dlsym(
            UnsafeMutableRawPointer(bitPattern: -2), "responsibility_spawnattrs_setdisclaim")
        disclaim = address.map { unsafeBitCast($0, to: DisclaimCall.self) }
    }

    var runningScripts: Set<String> { Set(jobs.keys) }

    func isRunning(_ script: String) -> Bool { jobs[script] != nil }

    func run(_ script: String, corner: CornerSlot) {
        guard ShellCommand.isConfigured(script) else { return }
        guard let disclaim else {
            // A command must never borrow the app's permissions, so it does not run at all.
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
        // A Stop that came while the command was starting applies now.
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

    /// Keeps a command listed, with its Stop button, while anything that it started is still
    /// running in its process group, such as a job that it left in the background.
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

    /// Ends one command and everything that it started.
    func stop(_ script: String) {
        guard let job = jobs[script], !job.stopped else { return }
        job.stopped = true
        if let pid = job.pid { Self.signal(group: pid) }
    }

    func stopAll() {
        for script in jobs.keys { stop(script) }
    }

    /// Asks every command to end when the app quits. The app cannot wait for them, so commands that
    /// ignore the request keep running.
    func stopAllForQuit() {
        for job in jobs.values {
            if let pid = job.pid { kill(-pid, SIGTERM) }
        }
    }

    /// Asks the command's process group to end, and kills it if it is still there a moment later.
    /// A process group keeps its number while any member lives, so the second signal cannot reach
    /// another program.
    private static func signal(group pid: pid_t) {
        kill(-pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + stopGrace) {
            if kill(-pid, 0) == 0 { kill(-pid, SIGKILL) }
        }
    }

    /// Reads the error output as it arrives, and finishes when the process ends. Reading to the end
    /// of the output instead would wait forever on a command that leaves a background job running,
    /// because that job keeps the output open.
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
        // The end of the output must stop the reader, because a pipe at its end always reads as
        // ready, and the reader would otherwise spin until the command ends. A command closes its
        // output early when its last part sends errors elsewhere, such as `tool 2>/dev/null`.
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
                // Nothing more has arrived yet, so the reader waits for the next event.
                if count < 0, errno == EAGAIN { break }
                // The end of the output, or an error that would keep the pipe ready forever.
                output.isClosed = true
                reader.cancel()
                break
            }
        }
        reader.setEventHandler(handler: drain)
        reader.setCancelHandler { close(errors) }
        reader.resume()
        // A thread that waits on the process is simpler and safer than an exit event, which can be
        // missed by a process that ends before the event is set up.
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

    /// Starts the shell, and returns its process number with the read end of its error output, or
    /// why it did not start.
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
        // Only the three standard streams reach the command, and it starts with ordinary signal
        // handling in a process group of its own.
        let flags =
            POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT | POSIX_SPAWN_SETSIGDEF
            | POSIX_SPAWN_SETSIGMASK
        posix_spawnattr_setflags(&attributes, Int16(flags))
        posix_spawnattr_setpgroup(&attributes, 0)
        var noSignals = sigset_t()
        var allSignals = ~sigset_t()
        posix_spawnattr_setsigmask(&attributes, &noSignals)
        posix_spawnattr_setsigdefault(&attributes, &allSignals)
        // Without this, macOS would treat the command as part of the app, and the command would
        // get the app's permissions.
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
