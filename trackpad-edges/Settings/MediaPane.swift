import AppKit

/// Lets you choose how far each seek step moves the media, and how the seek preview looks.
final class MediaPane: SettingsPane {
    private let summary = NSTextField(wrappingLabelWithString: "")
    private var amount: NSSlider?

    override func loadView() {
        let slider = slider(
            value: settings.seekStepValue,
            range: AppSettings.seekStepRange(for: settings.seekStepType)
        ) { [weak self] value in
            guard let self else { return }
            self.settings.seekStepValue = Self.rounded(value, for: self.settings.seekStepType)
            self.updateSummary()
        }
        slider.setAccessibilityLabel("Amount for each step")
        amount = slider
        summary.textColor = .secondaryLabelColor
        summary.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summary.preferredMaxLayoutWidth = Self.contentWidth

        let types = SeekStepType.allCases
        let type = popup(
            types.map(\.title), selected: types.firstIndex(of: settings.seekStepType) ?? 0
        ) { [weak self] index in
            self?.settings.seekStepType = types[index]
            self?.updateSlider()
        }
        let styles = OverlayStyle.allCases
        let style = popup(
            styles.map(\.title), selected: styles.firstIndex(of: settings.overlayStyle) ?? 0
        ) { [weak self] index in
            self?.settings.overlayStyle = styles[index]
            self?.actions.previewSeekOverlay()
        }
        let placements = OverlayPlacement.allCases
        let placement = popup(
            placements.map(\.title),
            selected: placements.firstIndex(of: settings.overlayPlacement) ?? 0
        ) { [weak self] index in
            self?.settings.overlayPlacement = placements[index]
            self?.actions.previewSeekOverlay()
        }

        setContent([
            wideForm([
                [("Step type:", type), ("Each step:", slider)],
                [("Style:", style), ("Position:", placement)],
            ]),
            summary,
        ])
        updateSummary()
    }

    /// Half-percent stops and whole seconds keep the amount easy to read and to repeat.
    private static func rounded(_ value: Double, for type: SeekStepType) -> Double {
        type == .percent ? (value * 2).rounded() / 2 : value.rounded()
    }

    private func updateSlider() {
        let range = AppSettings.seekStepRange(for: settings.seekStepType)
        amount?.minValue = range.lowerBound
        amount?.maxValue = range.upperBound
        amount?.doubleValue = settings.seekStepValue
        updateSummary()
    }

    private func updateSummary() {
        let value = settings.seekStepValue
        let text = value == value.rounded() ? "\(Int(value))" : "\(value)"
        switch settings.seekStepType {
        case .percent:
            let seconds = Int((600 * value / 100).rounded())
            let time = "\(seconds / 60):" + String(format: "%02d", seconds % 60)
            summary.stringValue =
                "Each step moves \(text)% of the track and gives one haptic tick. On a 10-minute video, that is \(time)."
        case .seconds:
            summary.stringValue =
                "Each step moves \(text) \(value == 1 ? "second" : "seconds") on any track and gives one haptic tick."
        }
    }
}
