import AppKit
import UniformTypeIdentifiers

/// Holds the first-run steps, the Accessibility permission, launch at login, updates, and the
/// diagnostics for a bug report.
final class GeneralPane: SettingsPane {
    private let permissionLabel = NSTextField(labelWithString: "")
    private var statusForm: NSGridView?
    private var loginCheckbox: NSButton?
    private var updatesCheckbox: NSButton?
    private var checkNowButton: NSButton?
    private var permissionTimer: Timer?
    /// The status form's row that holds the Grant button.
    private static let grantRow = 1
    /// What the diagnostics line says until you use one of its buttons.
    private static let diagnosticsHint = "Nothing is sent by the app."
    private let diagnosticsLabel = NSTextField(labelWithString: GeneralPane.diagnosticsHint)
    private var recordButton: NSButton?
    private var countdownTimer: Timer?

    /// Called when a row appears or disappears, so that the window can fit the pane.
    var onLayoutChange: (() -> Void)?

    override func loadView() {
        let login = checkbox("Launch at login", isOn: LoginItem.isEnabled) { [weak self] isOn in
            LoginItem.set(isOn)
            self?.updateLogin()
        }
        loginCheckbox = login
        let grant = button("Grant Accessibility…") { [weak self] in
            self?.actions.requestAccessibility()
        }
        let daily = checkbox("Check daily", isOn: actions.checksForUpdatesAutomatically()) {
            [weak self] isOn in
            self?.actions.setChecksForUpdatesAutomatically(isOn)
        }
        daily.setAccessibilityLabel("Check for updates every day")
        updatesCheckbox = daily
        let checkNow = button("Check Now") { [weak self] in
            self?.actions.checkForUpdates()
        }
        checkNow.setAccessibilityLabel("Check for updates now")
        checkNowButton = checkNow
        // Both controls share one row, so that this column stays as tall as the other one.
        let updates = NSStackView(views: [daily, checkNow])
        updates.spacing = 8
        let status = form([
            ("Accessibility:", permissionLabel), ("", grant), ("Startup:", login),
            ("Updates:", updates),
        ])
        statusForm = status
        let record = button("Record Touches…") { [weak self] in self?.confirmRecording() }
        recordButton = record
        let copy = button("Copy Diagnostics") { [weak self] in
            self?.actions.copyDiagnostics()
            self?.setDiagnosticsStatus("The report is on the clipboard.")
        }
        diagnosticsLabel.textColor = .secondaryLabelColor
        diagnosticsLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        // A long message is cut short, so that it can never push the column wider.
        diagnosticsLabel.lineBreakMode = .byTruncatingTail
        diagnosticsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // The buttons sit one above the other, because the form's column is too narrow for both.
        let diagnostics = form([
            ("Diagnostics:", copy), ("", record), ("", diagnosticsLabel),
        ])

        setContent([
            columns(
                column([
                    heading("Get started"),
                    paragraph(
                        "Touch the right edge and slide up or down. The Edges pane shows your finger live."
                    ),
                    button("Show Welcome Tour…") { [weak self] in
                        self?.actions.showWelcomeTour()
                    },
                ]),
                status),
            columns(
                column([
                    heading("Report a problem"),
                    paragraph(
                        "The report lists your versions, trackpads, and settings for a bug report. It leaves out paths, links, and names."
                    ),
                ]),
                diagnostics),
            note(
                "Gestures need the Accessibility permission, because the app presses the volume and brightness keys for you and keeps stray clicks out of other apps. Launch at login works best after you move the app to the Applications folder."
            ),
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePermission()
        updateLogin()
        updateUpdates()
        permissionTimer?.invalidate()
        // macOS posts no public notice when the permission changes, so the pane checks each second.
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updatePermission()
                // This also catches an approval given in System Settings.
                self?.updateLogin()
                self?.updateUpdates()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        permissionTimer?.invalidate()
        permissionTimer = nil
    }

    private func updatePermission() {
        let trusted = AXIsProcessTrusted()
        permissionLabel.stringValue = trusted ? "Granted" : "Not Granted"
        guard let row = statusForm?.row(at: Self.grantRow), row.isHidden != trusted else { return }
        row.isHidden = trusted
        onLayoutChange?()
    }

    /// A check can also start from the menu bar, so the button follows the updater.
    private func updateUpdates() {
        updatesCheckbox?.state = actions.checksForUpdatesAutomatically() ? .on : .off
        updatesCheckbox?.isEnabled = actions.updatesAreAvailable()
        checkNowButton?.isEnabled = actions.canCheckForUpdates()
    }

    /// The system owns this setting, so the checkbox always shows what the system reports.
    private func updateLogin() {
        loginCheckbox?.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: Diagnostics

    /// Shows what just happened beside the buttons, and tells VoiceOver, which cannot see it.
    private func setDiagnosticsStatus(_ text: String, announce: Bool = true) {
        diagnosticsLabel.stringValue = text
        guard announce else { return }
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [
                .announcement: text, .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ])
    }

    /// Says what a recording holds before it starts, because it is the only raw data that the
    /// app ever writes to a file.
    private func confirmRecording() {
        guard let window = view.window else { return }
        let seconds = Int(TouchRecording.duration)
        let alert = NSAlert()
        alert.messageText = "Record \(seconds) seconds of touches?"
        alert.informativeText =
            "After you click Record, use the trackpad in the way that shows the problem. The file holds the position, pressure, and size of each contact, and nothing about your screen or your apps. Nothing is sent, and you choose where to save the file."
        alert.addButton(withTitle: "Record")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn { self?.startRecording() }
        }
    }

    private func startRecording() {
        recordButton?.isEnabled = false
        let end = ProcessInfo.processInfo.systemUptime + TouchRecording.duration
        setDiagnosticsStatus("Recording for \(Int(TouchRecording.duration)) seconds.")
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] timer in
            let isCounting = MainActor.assumeIsolated { () -> Bool in
                let left = Int((end - ProcessInfo.processInfo.systemUptime).rounded())
                guard let self, left > 0 else { return false }
                // VoiceOver heard the start, and a count every second would talk over the user.
                self.setDiagnosticsStatus(
                    "Recording stops in \(left) \(left == 1 ? "second" : "seconds").",
                    announce: false)
                return true
            }
            // The timer stops itself, because a pane that has gone can no longer stop it.
            if !isCounting { timer.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
        actions.recordTouches { [weak self] recording in self?.save(recording) }
    }

    /// Asks where to put a finished recording. The app may be behind another one by now,
    /// because the recording ran while you used the trackpad.
    private func save(_ recording: TouchRecording) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        recordButton?.isEnabled = true
        guard !recording.frames.isEmpty else {
            setDiagnosticsStatus("No touches were recorded.")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Trackpad Edges touches.json"
        panel.allowedContentTypes = [.json]
        panel.message = "Attach the saved file to your bug report."
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else {
                self?.setDiagnosticsStatus("The recording was not saved.")
                return
            }
            do {
                try recording.encoded().write(to: url, options: .atomic)
                self?.setDiagnosticsStatus("The recording was saved.")
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                self?.setDiagnosticsStatus("The recording could not be saved.")
                NSAlert(error: error).runModal()
            }
        }
        // This says that the recording is over before the panel opens, because the panel can
        // open behind another app, and macOS may refuse to bring this one forward.
        setDiagnosticsStatus("Choose where to save the file.")
        NSApp.requestUserAttention(.informationalRequest)
        NSApp.bringForward()
        if let window = view.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            panel.begin(completionHandler: finish)
        }
    }
}
