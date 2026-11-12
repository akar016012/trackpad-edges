import AppKit
import UniformTypeIdentifiers

/// Lets you choose an action for each click count of each corner. The clicks popup picks the
/// count to edit, so a corner with several actions needs no extra rows.
final class CornersPane: ProfilePane, NSTextFieldDelegate {
    private typealias Kind = CornerActionKind

    /// The views of one corner's command row. Save and Stop share one slot beside the field.
    private struct CommandRow {
        let field: NSTextField
        let save: NSButton
        let stop: NSButton
    }

    /// The width of the slot that holds Save or Stop beside a command field.
    private static let commandButtonWidth: CGFloat = 64
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
    /// The command field of each corner that shows one, with its Save and Stop buttons.
    private var commandRows: [Corner: CommandRow] = [:]
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

    /// Shows Stop beside each saved command that is running and has no unsaved edit, and Save
    /// beside the rest.
    func commandsChanged() {
        for corner in commandRows.keys { updateCommandButtons(corner) }
    }

    /// Turns Save on while the field differs from the saved command. Stop takes Save's place
    /// while the saved command runs and the field has nothing to save. The two share one slot,
    /// so the field keeps its width and your cursor stays where it is.
    private func updateCommandButtons(_ corner: Corner) {
        guard let row = commandRows[corner], case .command(let saved) = currentAction(corner)
        else { return }
        let isDirty = row.field.stringValue != saved
        let showsStop = !isDirty && actions.runningCommands().contains(saved)
        row.save.isEnabled = isDirty
        guard row.stop.isHidden == showsStop else { return }
        let window = row.field.window
        let hidingFocus = window?.firstResponder === (showsStop ? row.save : row.stop)
        row.save.isHidden = showsStop
        row.stop.isHidden = !showsStop
        // A button that had the keyboard focus is gone now, so the focus returns to the field.
        if hidingFocus { window?.makeFirstResponder(row.field) }
        // VoiceOver hears that the slot now holds the other button, but only while the pane is
        // on screen, because a tab that is not selected has no window.
        if window != nil, let slot = row.save.superview {
            NSAccessibility.post(element: slot, notification: .layoutChanged)
        }
    }

    /// Turns Save on or off as you type in a command field.
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField,
            let corner = commandRows.first(where: { $0.value.field === field })?.key
        else { return }
        updateCommandButtons(corner)
    }

    /// Saves the text in a corner's command field.
    private func saveCommand(_ corner: Corner) {
        guard let row = commandRows[corner] else { return }
        let text = row.field.stringValue
        if currentAction(corner) != .command(script: text) {
            assign(.command(script: text), corner: corner)
            // This is the moment when the reason for notifications is clear.
            if ShellCommand.isConfigured(text) { actions.requestNotificationPermission() }
        }
        updateCommandButtons(corner)
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

    /// A field for one command, in a fixed-width font, with one button slot beside it that
    /// fills the rest of the column. The slot holds Save, which turns on while the field holds
    /// text that is not saved yet, or Stop while the saved command runs. A corner press runs the
    /// saved command, and Return, Save, and leaving the field all save it.
    private func commandViews(script: String, corner: Corner) -> [NSView] {
        let fieldWidth = Self.columnWidth - Self.commandButtonWidth - 8
        let field = textField(value: script, placeholder: "Shell command", width: fieldWidth) {
            [weak self] _ in
            self?.saveCommand(corner)
        }
        field.delegate = self
        field.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.lineBreakMode = .byTruncatingTail
        let name = sectionTitles[corner] ?? ""
        field.setAccessibilityLabel("\(name) corner command")
        let save = button("Save") { [weak self] in self?.saveCommand(corner) }
        save.setAccessibilityLabel("Save the \(name) corner command")
        save.isEnabled = false
        let stop = button("Stop") { [weak self] in
            guard let self, case .command(let script) = self.currentAction(corner) else { return }
            self.actions.stopCommand(script)
        }
        stop.setAccessibilityLabel("Stop the \(name) corner command")
        stop.isHidden = true
        // Both buttons fill the same slot, and the slot keeps its size whichever one shows, so
        // nothing in the row moves when they swap.
        let slot = NSView()
        slot.translatesAutoresizingMaskIntoConstraints = false
        for button in [save, stop] {
            button.translatesAutoresizingMaskIntoConstraints = false
            slot.addSubview(button)
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                button.trailingAnchor.constraint(equalTo: slot.trailingAnchor),
                button.topAnchor.constraint(equalTo: slot.topAnchor),
                button.bottomAnchor.constraint(equalTo: slot.bottomAnchor),
            ])
        }
        slot.widthAnchor.constraint(equalToConstant: Self.commandButtonWidth).isActive = true
        commandRows[corner] = CommandRow(field: field, save: save, stop: stop)
        #if DEBUG
            // Launching with `-debugCommandDraft 'text'` puts unsaved text in each command field,
            // so that the Save button can be inspected without typing. Leaving the field saves
            // that text, as it would save typed text. `rebuildDetails` updates the buttons next.
            if let draft = UserDefaults.standard.string(forKey: "debugCommandDraft") {
                field.stringValue = draft
            }
        #endif
        return [field, slot]
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
        field.widthAnchor.constraint(equalToConstant: width).isActive = true
        bind(field) { [weak field] in assign(field?.stringValue ?? "") }
        return field
    }
}
