import AppKit

/// Lets you control how haptics feel and which events fire them.
final class HapticsPane: SettingsPane {
    private var statusLabel: NSTextField?

    override func viewWillAppear() {
        super.viewWillAppear()
        statusLabel?.stringValue = actions.hapticStatus()
    }

    override func loadView() {
        let current = settings.haptics
        let patterns = HapticPattern.allCases
        let controls = form([
            (
                "",
                checkbox("Enable haptics", isOn: current.enabled) { [weak self] isOn in
                    self?.settings.haptics.enabled = isOn
                }
            ),
            (
                "Strength:",
                slider(value: Double(current.strength), range: 0.4...2.0) { [weak self] value in
                    self?.settings.haptics.strength = Float(value)
                }
            ),
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
            ("", button("Test Haptic") { [weak self] in self?.actions.testHaptic() }),
            (
                "Fire on:",
                checkbox("Each volume or brightness step", isOn: current.onStep) {
                    [weak self] isOn in self?.settings.haptics.onStep = isOn
                }
            ),
            (
                "",
                checkbox("Reaching a limit", isOn: current.onLimit) { [weak self] isOn in
                    self?.settings.haptics.onLimit = isOn
                }
            ),
            (
                "",
                checkbox("A corner action", isOn: current.onCorner) { [weak self] isOn in
                    self?.settings.haptics.onCorner = isOn
                }
            ),
            (
                "",
                checkbox("A seek preview appearing", isOn: current.onSeek) { [weak self] isOn in
                    self?.settings.haptics.onSeek = isOn
                }
            ),
        ])
        let status = note(actions.hapticStatus())
        statusLabel = status
        setContent([controls, status])
    }
}
