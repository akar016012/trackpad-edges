import AppKit

/// Holds the first-run steps, the Accessibility permission, launch at login, and updates.
final class GeneralPane: SettingsPane {
    private let permissionLabel = NSTextField(labelWithString: "")
    private var statusForm: NSGridView?
    private var loginCheckbox: NSButton?
    private var updatesCheckbox: NSButton?
    private var checkNowButton: NSButton?
    private var permissionTimer: Timer?
    private static let grantRow = 1

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
}
