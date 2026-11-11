import AppKit
import UniformTypeIdentifiers

/// Lets you choose an action for each click count of each corner. The clicks popup picks the
/// count to edit, so a corner with several actions needs no extra rows.
final class CornersPane: ProfilePane {
    private typealias Kind = CornerActionKind

    /// The name of the width constraint that each text field gets.
    private static let fieldWidthID = "fieldWidth"
    /// The width of the Stop button that appears beside a running command.
    private static let stopWidth: CGFloat = 64
    private static let keyboardSettings = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")

    /// The popup's items, grouped as `CornerActionGroup` lists the groups.
    private static var actionGroups: [(header: String?, items: [(title: String, tag: Int)])] {
        CornerActionGroup.allCases.map { group in
            (group.title, Kind.allCases.filter { $0.group == group }.map { ($0.title, $0.tag) })
        }
    }

    /// Called when a corner changes, so that the diagram can redraw.
    var onChange: (() -> Void)?

    private typealias Corner = WritableKeyPath<AppSettings, CornerSetting>

    private var detailStacks: [Corner: NSStackView] = [:]
    private var actionPopups: [Corner: NSPopUpButton] = [:]
    private var clickPopups: [Corner: NSPopUpButton] = [:]
    /// The click count being edited for each corner.
    private var selectedClicks: [Corner: Int] = [:]
    private var sectionTitles: [Corner: String] = [:]
    /// The command field of each corner that shows one, with its Stop button and its width.
    private var commandRows: [Corner: (stop: NSButton, width: NSLayoutConstraint)] = [:]
    private let strengthLabel = NSTextField(labelWithString: "")

    override func loadView() {
        // The grid matches the trackpad, so each section sits where its corner is.
        setContent([
            makePickerRow(),
            columns(
                section("Top left", corner: \.topLeft), section("Top right", corner: \.topRight)),
            columns(
                section("Bottom left", corner: \.bottomLeft),
                section("Bottom right", corner: \.bottomRight)),
            pressControls(),
            note("Press a corner lightly to fire it. A corner with no action stays normal."),
        ])
    }

    override func profileChanged() {
        for (corner, action) in actionPopups {
            selectedClicks[corner] = settings[keyPath: corner].configuredClicks.min() ?? 1
            action.selectItem(withTag: Kind(currentAction(corner)).tag)
            clickPopups[corner]?.selectItem(at: (selectedClicks[corner] ?? 1) - 1)
            refreshClickTitles(corner)
            rebuildDetails(corner: corner)
        }
        onChange?()
    }

    /// Reads the Do Not Disturb key again, so that the pane never shows an old answer.
    override func viewWillAppear() {
        super.viewWillAppear()
        for corner in actionPopups.keys
        where currentAction(corner) == .system(action: .toggleDoNotDisturb) {
            rebuildDetails(corner: corner)
        }
    }

    /// Shows the Stop button beside each command that is running, and hides it beside the rest.
    func commandsChanged() {
        let running = actions.runningCommands()
        for (corner, row) in commandRows {
            guard case .command(let script) = currentAction(corner) else { continue }
            let isRunning = running.contains(script)
            row.stop.isHidden = !isRunning
            row.width.constant =
                isRunning ? Self.columnWidth - Self.stopWidth - 8 : Self.columnWidth
        }
    }

    private func pressControls() -> NSView {
        strengthLabel.stringValue = Self.strengthName(settings.pressThreshold)
        let strength = slider(
            value: Double(settings.pressThreshold),
            range: Self.sliderRange(AppSettings.pressThresholdRange)
        ) { [weak self] value in
            self?.settings.pressThreshold = Float(value.rounded())
            self?.strengthLabel.stringValue = Self.strengthName(Float(value.rounded()))
        }
        strength.setAccessibilityLabel("Corner press strength")
        return wideForm([[("Press:", strength), ("Needs:", strengthLabel)]])
    }

    private static func strengthName(_ threshold: Float) -> String {
        if threshold < 85 { return "A light press" }
        return threshold < 100 ? "A medium press" : "A firm press"
    }

    private func section(
        _ title: String, corner: Corner
    ) -> NSView {
        selectedClicks[corner] = settings[keyPath: corner].configuredClicks.min() ?? 1
        sectionTitles[corner] = title
        let action = groupedPopup(
            Self.actionGroups, selectedTag: Kind(currentAction(corner)).tag
        ) { [weak self] tag in
            self?.choose(Kind(tag: tag) ?? .none, corner: corner)
        }
        let clicks = popup(clickTitles(corner), selected: (selectedClicks[corner] ?? 1) - 1) {
            [weak self] index in self?.selectClicks(index + 1, corner: corner)
        }
        actionPopups[corner] = action
        clickPopups[corner] = clicks
        action.setAccessibilityLabel("\(title) corner action")
        clicks.setAccessibilityLabel("\(title) corner clicks")
        // These two fill the column exactly, so all four sections share their edges.
        action.widthAnchor.constraint(equalToConstant: 190).isActive = true
        clicks.widthAnchor.constraint(equalToConstant: 96).isActive = true
        let details = NSStackView()
        details.orientation = .horizontal
        detailStacks[corner] = details
        rebuildDetails(corner: corner)

        let controls = NSStackView(views: [action, clicks])
        controls.orientation = .horizontal
        controls.spacing = 8
        return column([heading(title), controls, details])
    }

    private func choose(_ kind: Kind, corner: Corner) {
        // A text field commits when it loses focus, so that must happen before the new action is
        // stored, or the old text would overwrite it.
        view.window?.makeFirstResponder(nil)
        // AppKit also sends the action for the item that is already selected.
        guard Kind(currentAction(corner)) != kind else { return }
        assign(kind.blankAction, corner: corner)
        rebuildDetails(corner: corner)
        // The window fits the pane, so it must hear about this after the rows have changed.
        onChange?()
    }

    private func currentAction(_ corner: Corner) -> CornerAction {
        settings[keyPath: corner][selectedClicks[corner] ?? 1]
    }

    private func assign(_ action: CornerAction, corner: Corner) {
        settings[keyPath: corner][selectedClicks[corner] ?? 1] = action
        refreshClickTitles(corner)
        onChange?()
    }

    /// A dot marks each click count that has an action.
    private func clickTitles(_ corner: Corner) -> [String] {
        let configured = settings[keyPath: corner].configuredClicks
        return (1...CornerSetting.maxClicks).map { count in
            let title = count == 1 ? "1 Click" : "\(count) Clicks"
            return configured.contains(count) ? "\(title) •" : title
        }
    }

    private func refreshClickTitles(_ corner: Corner) {
        guard let popup = clickPopups[corner] else { return }
        for (item, title) in zip(popup.itemArray, clickTitles(corner)) { item.title = title }
    }

    /// Shows the action of another click count, without changing anything that is saved.
    private func selectClicks(_ count: Int, corner: Corner) {
        view.window?.makeFirstResponder(nil)
        selectedClicks[corner] = count
        actionPopups[corner]?.selectItem(withTag: Kind(currentAction(corner)).tag)
        rebuildDetails(corner: corner)
        onChange?()
    }

    private func rebuildDetails(corner: Corner) {
        guard let stack = detailStacks[corner] else { return }
        commandRows[corner] = nil
        stack.setViews([], in: .leading)
        for view in detailViews(corner: corner) { stack.addView(view, in: .leading) }
        commandsChanged()
    }

    private func detailViews(corner: Corner) -> [NSView] {
        switch currentAction(corner) {
        case .none, .mute, .playPause, .nextTrack, .previousTrack:
            return []
        case .system(let action):
            return action == .toggleDoNotDisturb ? doNotDisturbViews() : []
        case .command(let script):
            return commandViews(script: script, corner: corner)
        case .openApp(let path):
            return chooser(path: path, title: "Choose App…", types: [.application]) {
                [weak self] chosen in
                self?.assign(.openApp(path: chosen), corner: corner)
            }
        case .openFile(let path):
            return chooser(path: path, title: "Choose…", types: nil) { [weak self] chosen in
                self?.assign(.openFile(path: chosen), corner: corner)
            }
        case .openLink(let url, let browserPath):
            return linkViews(url: url, browserPath: browserPath, corner: corner)
        case .keyCombination(_, _, let label):
            return keyViews(label: label, corner: corner)
        case .shortcut(let name):
            return [
                textField(value: name, placeholder: "Shortcut name") { [weak self] text in
                    self?.assign(.shortcut(name: text), corner: corner)
                }
            ]
        }
    }

    private func chooser(
        path: String, title: String, types: [UTType]?, _ assign: @escaping (String) -> Void
    ) -> [NSView] {
        let label = NSTextField(
            labelWithString: path.isEmpty ? "Nothing Chosen" : (path as NSString).lastPathComponent)
        // A long file name must not push the pane's content off the sides of the window.
        label.lineBreakMode = .byTruncatingMiddle
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.widthAnchor.constraint(lessThanOrEqualToConstant: 150).isActive = true
        let choose = button(title) { [weak self, weak label] in
            let panel = NSOpenPanel()
            panel.canChooseDirectories = types == nil
            if let types { panel.allowedContentTypes = types }
            guard let window = self?.view.window else { return }
            panel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = panel.url else { return }
                label?.stringValue = url.lastPathComponent
                assign(url.path)
            }
        }
        return [choose, label]
    }

    private func linkViews(
        url: String, browserPath: String?, corner: Corner
    ) -> [NSView] {
        var browsers: [URL] = []
        if let sample = URL(string: "https://example.com") {
            browsers = NSWorkspace.shared.urlsForApplications(toOpen: sample)
        }
        var link = url
        var browser = browserPath
        let save: () -> Void = { [weak self] in
            self?.assign(.openLink(url: link, browserPath: browser), corner: corner)
        }
        let field = textField(value: url, placeholder: "https://") { text in
            link = text
            save()
        }
        let titles =
            ["Default Browser"] + browsers.map { $0.deletingPathExtension().lastPathComponent }
        let selected = browsers.firstIndex { $0.path == browserPath }.map { $0 + 1 } ?? 0
        let picker = popup(titles, selected: selected) { index in
            browser = index == 0 ? nil : browsers[index - 1].path
            save()
        }
        picker.widthAnchor.constraint(equalToConstant: 116).isActive = true
        return [field, picker]
    }

    private func keyViews(
        label: String, corner: Corner
    ) -> [NSView] {
        let recorder = KeyRecorderButton(title: "", target: nil, action: nil)
        recorder.show(label: label)
        // This width fills the column, so the row lines up with the popups above it.
        recorder.widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true
        recorder.onRecord = { [weak self] code, flags, name in
            self?.assign(
                .keyCombination(keyCode: code, modifiers: flags, label: name), corner: corner)
        }
        bind(recorder) { [weak recorder] in recorder?.startRecording() }
        return [recorder]
    }

    /// A field for one command, in a fixed-width font, that fills the column. A Stop button takes
    /// part of the row while the command runs.
    private func commandViews(script: String, corner: Corner) -> [NSView] {
        let field = textField(value: script, placeholder: "Shell command", width: Self.columnWidth)
        {
            [weak self] text in
            self?.assign(.command(script: text), corner: corner)
            // This is the moment when the reason for notifications is clear.
            if ShellCommand.isConfigured(text) { self?.actions.requestNotificationPermission() }
        }
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.lineBreakMode = .byTruncatingTail
        field.setAccessibilityLabel("\(sectionTitles[corner] ?? "") corner command")
        let stop = button("Stop") { [weak self] in
            guard let self, case .command(let script) = self.currentAction(corner) else { return }
            self.actions.stopCommand(script)
        }
        stop.widthAnchor.constraint(equalToConstant: Self.stopWidth).isActive = true
        stop.setAccessibilityLabel("Stop the \(sectionTitles[corner] ?? "") corner command")
        stop.isHidden = true
        if let width = field.constraints.first(where: { $0.identifier == Self.fieldWidthID }) {
            commandRows[corner] = (stop, width)
        }
        return [field, stop]
    }

    /// Says whether Do Not Disturb has a key, and offers Keyboard settings while it has none.
    private func doNotDisturbViews() -> [NSView] {
        guard SystemActionRunner.doNotDisturbKey == nil else {
            let label = NSTextField(labelWithString: "It presses your key for Do Not Disturb.")
            label.textColor = .secondaryLabelColor
            return [label]
        }
        let label = NSTextField(labelWithString: "No key is assigned yet.")
        label.textColor = .secondaryLabelColor
        let open = button("Keyboard Settings…") {
            if let url = Self.keyboardSettings { NSWorkspace.shared.open(url) }
        }
        open.toolTip =
            "Assign a key to Do Not Disturb under Keyboard Shortcuts, in the Mission Control section."
        return [label, open]
    }

    private func textField(
        value: String, placeholder: String, width: CGFloat = 150,
        _ assign: @escaping (String) -> Void
    ) -> NSTextField {
        let field = NSTextField(string: value)
        field.placeholderString = placeholder
        let widthConstraint = field.widthAnchor.constraint(equalToConstant: width)
        // The command row finds this constraint by name, so that it can make room for Stop.
        widthConstraint.identifier = Self.fieldWidthID
        widthConstraint.isActive = true
        bind(field) { [weak field] in assign(field?.stringValue ?? "") }
        return field
    }
}
