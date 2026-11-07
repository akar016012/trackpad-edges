import AppKit

/// Lets you control how haptics feel and which events fire them.
final class HapticsPane: SettingsPane {
    private var statusLabel: NSTextField?

    override func viewWillAppear() {
        super.viewWillAppear()
        statusLabel?.stringValue = actions.hapticStatus()
    }

    override func loadView() {
        let status = note(actions.hapticStatus())
        statusLabel = status
        setContent([controls(), status])
    }

    /// Both columns share one grid, so that each row lines up across the pane even though a
    /// popup is taller than a checkbox.
    private func controls() -> NSView {
        let current = settings.haptics
        let patterns = HapticPattern.allCases
        let rows: [[(String, NSView)]] = [
            [
                (
                    "Haptics:",
                    checkbox("Enabled", isOn: current.enabled) { [weak self] isOn in
                        self?.settings.haptics.enabled = isOn
                    }
                ),
                (
                    "Fire on:",
                    checkbox("Each level step", isOn: current.onStep) { [weak self] isOn in
                        self?.settings.haptics.onStep = isOn
                    }
                ),
            ],
            [
                (
                    "Strength:",
                    slider(value: Double(current.strength), range: 0.4...2.0) { [weak self] value in
                        self?.settings.haptics.strength = Float(value)
                    }
                ),
                (
                    "",
                    checkbox("Reaching a limit", isOn: current.onLimit) { [weak self] isOn in
                        self?.settings.haptics.onLimit = isOn
                    }
                ),
            ],
            [
                (
                    "Pattern:",
                    popup(
                        patterns.map(\.rawValue.capitalized),
                        selected: patterns.firstIndex(of: current.pattern) ?? 0
                    ) { [weak self] index in
                        self?.settings.haptics.pattern = patterns[index]
                        self?.actions.testHaptic()
                    }
                ),
                (
                    "",
                    checkbox("A corner action", isOn: current.onCorner) { [weak self] isOn in
                        self?.settings.haptics.onCorner = isOn
                    }
                ),
            ],
            [
                ("", button("Test Haptic") { [weak self] in self?.actions.testHaptic() }),
                (
                    "",
                    checkbox("A seek preview", isOn: current.onSeek) { [weak self] isOn in
                        self?.settings.haptics.onSeek = isOn
                    }
                ),
            ],
        ]
        return wideForm(rows)
    }
}
