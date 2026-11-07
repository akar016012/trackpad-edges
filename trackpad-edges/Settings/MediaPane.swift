import AppKit

/// Lets you choose how far each step of a seek slide moves the media.
final class MediaPane: SettingsPane {
    private let amountLabel = NSTextField(labelWithString: "")
    private let summary = NSTextField(wrappingLabelWithString: "")

    override func loadView() {
        let amount = slider(value: settings.seekStepPercent, range: 0.5...10) { [weak self] value in
            // Half-percent stops keep the amount easy to read and to repeat.
            self?.settings.seekStepPercent = (value * 2).rounded() / 2
            self?.updateLabels()
        }
        amount.setAccessibilityLabel("Percentage of the track for each step")
        amountLabel.font = .monospacedDigitSystemFont(
            ofSize: NSFont.systemFontSize, weight: .regular)
        summary.textColor = .secondaryLabelColor
        summary.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summary.preferredMaxLayoutWidth = Self.contentWidth

        setContent([
            wideForm([[("Each step:", amount), ("Moves:", amountLabel)]]),
            summary,
        ])
        updateLabels()
    }

    private func updateLabels() {
        let percent = settings.seekStepPercent
        let text = percent == percent.rounded() ? "\(Int(percent))" : "\(percent)"
        amountLabel.stringValue = "\(text)% of the track"
        let seconds = Int((600 * percent / 100).rounded())
        let time = "\(seconds / 60):" + String(format: "%02d", seconds % 60)
        summary.stringValue =
            "Slide along the bottom edge, and each step gives one haptic tick. On a 10-minute video, each step moves \(time)."
    }
}
