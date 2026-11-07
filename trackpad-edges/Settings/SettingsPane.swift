import AppKit

/// The services that the panes need from the rest of the app.
struct WindowActions {
    var testHaptic: () -> Void
    var hapticStatus: () -> String
    var requestAccessibility: () -> Void
}

/// Forwards a control's action to a closure.
private final class ClosureTarget: NSObject {
    private let handler: () -> Void

    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func invoke() {
        handler()
    }
}

/// The base class of the panes in the app window, with helpers for building simple forms.
class SettingsPane: NSViewController {
    private var targets: [ClosureTarget] = []
    let actions: WindowActions

    init(title: String, actions: WindowActions) {
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Panes are created in code.")
    }

    var settings: AppSettings {
        get { SettingsStore.shared.settings }
        set { SettingsStore.shared.settings = newValue }
    }

    func bind(_ control: NSControl, _ handler: @escaping () -> Void) {
        let target = ClosureTarget(handler)
        targets.append(target)
        control.target = target
        control.action = #selector(ClosureTarget.invoke)
    }

    func popup(_ titles: [String], selected: Int, _ handler: @escaping (Int) -> Void) -> NSPopUpButton
    {
        let button = NSPopUpButton()
        // This adds items one at a time, because `addItems` removes duplicate titles, which would
        // shift the indexes of the items that follow them.
        for title in titles {
            button.menu?.addItem(withTitle: title, action: nil, keyEquivalent: "")
        }
        button.selectItem(at: selected)
        bind(button) { [weak button] in handler(button?.indexOfSelectedItem ?? 0) }
        return button
    }

    func checkbox(_ title: String, isOn: Bool, _ handler: @escaping (Bool) -> Void) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        button.state = isOn ? .on : .off
        bind(button) { [weak button] in handler(button?.state == .on) }
        return button
    }

    func slider(
        value: Double, range: ClosedRange<Double>, _ handler: @escaping (Double) -> Void
    ) -> NSSlider {
        let slider = NSSlider(
            value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: nil,
            action: nil)
        slider.isContinuous = true
        slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true
        bind(slider) { [weak slider] in handler(slider?.doubleValue ?? value) }
        return slider
    }

    func button(_ title: String, _ handler: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        bind(button, handler)
        return button
    }

    func note(_ text: String) -> NSTextField {
        let label = paragraph(text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    func paragraph(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.alignment = .center
        label.preferredMaxLayoutWidth = 460
        return label
    }

    /// Lays out rows of a label and a control, with the labels aligned to the right.
    func form(_ rows: [(String, NSView)]) -> NSGridView {
        let grid = NSGridView(
            views: rows.map { row in
                let label = NSTextField(labelWithString: row.0)
                // VoiceOver reads the label with its control.
                if !row.0.isEmpty { row.1.setAccessibilityTitleUIElement(label) }
                return [label, row.1]
            })
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        return grid
    }

    /// Centers views in a pane. Every pane has the same size, so the window never jumps.
    func setContent(_ views: [NSView]) {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 540),
            container.heightAnchor.constraint(equalToConstant: 600),
        ])
        view = container
    }
}
