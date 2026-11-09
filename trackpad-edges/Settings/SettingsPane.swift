import AppKit

/// The services that the panes need from the rest of the app.
struct WindowActions {
    var testHaptic: () -> Void
    var hapticStatus: () -> String
    var requestAccessibility: () -> Void
    var previewSeekOverlay: () -> Void
    var unavailableKinds: () -> Set<SlideKind>
    var showWelcomeTour: () -> Void
    var checkForUpdates: () -> Void
    var updatesAreAvailable: () -> Bool
    var canCheckForUpdates: () -> Bool
    var checksForUpdatesAutomatically: () -> Bool
    var setChecksForUpdatesAutomatically: (Bool) -> Void
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

/// The base class of the panes in the app window.
///
/// Every pane uses the same layout: one margin on all sides, two equal columns, and one label
/// width. That keeps controls in the same place from tab to tab. The window fits each pane, so
/// a pane never has leftover space.
class SettingsPane: NSViewController {
    static let margin: CGFloat = 24
    static let columnGap: CGFloat = 24
    static let columnWidth: CGFloat = 294
    static let labelWidth: CGFloat = 84
    static let contentWidth = columnWidth * 2 + columnGap
    static let paneWidth = contentWidth + margin * 2

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

    /// A slider works in doubles, and the settings hold some of their ranges as floats.
    static func sliderRange(_ range: ClosedRange<Float>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }

    func slider(
        value: Double, range: ClosedRange<Double>, _ handler: @escaping (Double) -> Void
    ) -> NSSlider {
        let slider = NSSlider(
            value: value, minValue: range.lowerBound, maxValue: range.upperBound, target: nil,
            action: nil)
        slider.isContinuous = true
        bind(slider) { [weak slider] in handler(slider?.doubleValue ?? value) }
        return slider
    }

    func button(_ title: String, _ handler: @escaping () -> Void) -> NSButton {
        let button = NSButton(title: title, target: nil, action: nil)
        bind(button, handler)
        return button
    }

    func heading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        return label
    }

    func note(_ text: String) -> NSTextField {
        let label = paragraph(text, width: Self.contentWidth)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        return label
    }

    func paragraph(_ text: String, width: CGFloat = columnWidth) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.preferredMaxLayoutWidth = width
        return label
    }

    /// Lays out rows of a label and a control that fill one column.
    func form(_ rows: [(String, NSView)]) -> NSGridView {
        let grid = NSGridView(
            views: rows.map { row in
                // An empty cell holds nothing, so that VoiceOver has nothing to stop on.
                guard !row.0.isEmpty else { return [NSGridCell.emptyContentView, row.1] }
                let label = NSTextField(labelWithString: row.0)
                // VoiceOver reads the label with its control.
                row.1.setAccessibilityTitleUIElement(label)
                return [label, row.1]
            })
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = Self.labelWidth
        grid.column(at: 1).xPlacement = .fill
        useEvenRows(grid)
        return grid
    }

    /// Gives every row the same height, so spacing stays even when a popup sits beside a checkbox.
    private func useEvenRows(_ grid: NSGridView) {
        grid.rowSpacing = 6
        grid.rowAlignment = .none
        grid.yPlacement = .center
        for index in 0..<grid.numberOfRows { grid.row(at: index).height = 26 }
    }

    /// Lays out rows that hold a label and a control in each of the two columns.
    func wideForm(_ rows: [[(String, NSView)]]) -> NSGridView {
        let grid = NSGridView(
            views: rows.map { row in
                row.flatMap { cell -> [NSView] in
                    // An empty cell holds nothing, so that VoiceOver has nothing to stop on.
                    guard !cell.0.isEmpty else { return [NSGridCell.emptyContentView, cell.1] }
                    let label = NSTextField(labelWithString: cell.0)
                    cell.1.setAccessibilityTitleUIElement(label)
                    return [label, cell.1]
                }
            })
        let spacing: CGFloat = 10
        grid.columnSpacing = spacing
        useEvenRows(grid)
        for index in [0, 2] {
            grid.column(at: index).xPlacement = .trailing
            grid.column(at: index).width = Self.labelWidth
            grid.column(at: index + 1).xPlacement = .fill
            grid.column(at: index + 1).width = Self.columnWidth - Self.labelWidth - spacing
        }
        grid.column(at: 2).leadingPadding = Self.columnGap - spacing
        return grid
    }

    /// Stacks views along the leading edge of a column.
    func column(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    /// Places two views in the pane's two columns.
    func columns(_ left: NSView, _ right: NSView) -> NSStackView {
        let stack = NSStackView(views: [left, right])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = Self.columnGap
        for view in [left, right] {
            view.widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true
        }
        return stack
    }

    /// Installs views with the same margin on every side.
    func setContent(_ views: [NSView]) {
        let stack = column(views, spacing: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.margin),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.margin),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Self.margin),
            container.widthAnchor.constraint(equalToConstant: Self.paneWidth),
        ])
        view = container
    }
}
