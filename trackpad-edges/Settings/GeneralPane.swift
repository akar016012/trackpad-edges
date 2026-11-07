import AppKit
import ServiceManagement

/// Holds the first-run steps, the Accessibility permission, and launch at login.
final class GeneralPane: SettingsPane {
    private let permissionLabel = NSTextField(labelWithString: "")
    private var statusForm: NSGridView?
    private var loginCheckbox: NSButton?
    private var permissionTimer: Timer?
    private static let grantRow = 1

    /// Called when a row appears or disappears, so that the window can fit the pane.
    var onLayoutChange: (() -> Void)?

    override func loadView() {
        let login = checkbox("Launch at login", isOn: SMAppService.mainApp.status == .enabled) {
            [weak self] isOn in self?.setLaunchAtLogin(isOn)
        }
        loginCheckbox = login
        let grant = button("Grant Accessibility…") { [weak self] in
            self?.actions.requestAccessibility()
        }
        let status = form([
            ("Accessibility:", permissionLabel), ("", grant), ("Startup:", login),
        ])
        statusForm = status

        setContent([
            columns(
                column([
                    heading("Get started"),
                    paragraph(
                        "Touch the right edge and slide up or down. The Edges pane shows your finger live."
                    ),
                ]),
                status),
            note(
                "Gestures need the Accessibility permission, because the app presses the volume and brightness keys for you and keeps stray clicks out of other apps. Launch at login works best after you move the app to the Applications folder."
            ),
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
        permissionLabel.stringValue = trusted ? "Granted" : "Not Granted"
        guard let row = statusForm?.row(at: Self.grantRow), row.isHidden != trusted else { return }
        row.isHidden = trusted
        onLayoutChange?()
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
