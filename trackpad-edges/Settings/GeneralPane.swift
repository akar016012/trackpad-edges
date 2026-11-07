import AppKit
import ServiceManagement

/// Holds the first-run steps, the Accessibility permission, and launch at login.
final class GeneralPane: SettingsPane {
    private let permissionLabel = NSTextField(labelWithString: "")
    private var grantButton: NSButton?
    private var loginCheckbox: NSButton?
    private var permissionTimer: Timer?

    override func loadView() {
        let login = checkbox("Launch at login", isOn: SMAppService.mainApp.status == .enabled) {
            [weak self] isOn in self?.setLaunchAtLogin(isOn)
        }
        loginCheckbox = login
        let heading = NSTextField(labelWithString: "Get started")
        heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let grant = button("Grant Accessibility…") { [weak self] in
            self?.actions.requestAccessibility()
        }
        grantButton = grant
        setContent([
            heading,
            paragraph(
                "Gestures need the Accessibility permission, because the app presses the volume and brightness keys for you and keeps stray clicks out of other apps."
            ),
            permissionLabel,
            grant,
            paragraph(
                "To try a gesture, touch the right edge of the trackpad and slide up or down. The diagram in the Edges pane shows your finger live."
            ),
            login,
            note("Launch at login works best after you move the app to the Applications folder."),
        ])
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        updatePermission()
        updateLogin()
        permissionTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePermission() }
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
        permissionLabel.stringValue = trusted ? "Accessibility: Granted" : "Accessibility: Not Granted"
        grantButton?.isHidden = trusted
    }

    private func setLaunchAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
        updateLogin()
    }

    /// The system owns this setting, so the checkbox always shows what the system reports.
    private func updateLogin() {
        loginCheckbox?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
