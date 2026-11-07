import AppKit
import UniformTypeIdentifiers

/// Lets you choose an action and a click count for each corner.
final class CornersPane: SettingsPane {
    private enum Choice: Int, CaseIterable {
        case none, mute, playPause, nextTrack, previousTrack, app, link, file, keys, shortcut

        var title: String {
            switch self {
            case .none: return "No Action"
            case .mute: return "Mute"
            case .playPause: return "Play or Pause"
            case .nextTrack: return "Next Track"
            case .previousTrack: return "Previous Track"
            case .app: return "Open App"
            case .link: return "Open Link"
            case .file: return "Open File or Folder"
            case .keys: return "Press Keys"
            case .shortcut: return "Run Shortcut"
            }
        }

        init(_ action: CornerAction) {
            switch action {
            case .none: self = .none
            case .mute: self = .mute
            case .playPause: self = .playPause
            case .nextTrack: self = .nextTrack
            case .previousTrack: self = .previousTrack
            case .openApp: self = .app
            case .openLink: self = .link
            case .openFile: self = .file
            case .keyCombination: self = .keys
            case .shortcut: self = .shortcut
            }
        }
    }

    /// Called when a corner changes, so that the diagram can redraw.
    var onChange: (() -> Void)?

    private var detailStacks: [WritableKeyPath<AppSettings, CornerSetting>: NSStackView] = [:]
    private let strengthLabel = NSTextField(labelWithString: "")

    override func loadView() {
        // The grid matches the trackpad, so each section sits where its corner is.
        setContent([
            columns(
                section("Top left", corner: \.topLeft), section("Top right", corner: \.topRight)),
            columns(
                section("Bottom left", corner: \.bottomLeft),
                section("Bottom right", corner: \.bottomRight)),
            pressControls(),
            note("Press a corner lightly to fire it. A corner with no action stays normal."),
        ])
    }

    private func pressControls() -> NSView {
        strengthLabel.stringValue = Self.strengthName(settings.pressThreshold)
        let strength = slider(value: Double(settings.pressThreshold), range: 70...115) {
            [weak self] value in
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
        _ title: String, corner: WritableKeyPath<AppSettings, CornerSetting>
    ) -> NSView {
        let current = settings[keyPath: corner]
        let action = popup(
            Choice.allCases.map(\.title), selected: Choice(current.action).rawValue
        ) { [weak self] index in
            self?.choose(Choice(rawValue: index) ?? .none, corner: corner)
        }
        let clicks = popup(["1 Click", "2 Clicks", "3 Clicks", "4 Clicks"], selected: current.clicks - 1) {
            [weak self] index in
            self?.settings[keyPath: corner].clicks = index + 1
            self?.onChange?()
        }
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

    private func choose(_ choice: Choice, corner: WritableKeyPath<AppSettings, CornerSetting>) {
        // A text field commits when it loses focus, so that must happen before the new action is
        // stored, or the old text would overwrite it.
        view.window?.makeFirstResponder(nil)
        // AppKit also sends the action for the item that is already selected.
        guard Choice(settings[keyPath: corner].action) != choice else { return }
        switch choice {
        case .none: settings[keyPath: corner].action = .none
        case .mute: settings[keyPath: corner].action = .mute
        case .playPause: settings[keyPath: corner].action = .playPause
        case .nextTrack: settings[keyPath: corner].action = .nextTrack
        case .previousTrack: settings[keyPath: corner].action = .previousTrack
        case .app: settings[keyPath: corner].action = .openApp(path: "")
        case .link: settings[keyPath: corner].action = .openLink(url: "", browserPath: nil)
        case .file: settings[keyPath: corner].action = .openFile(path: "")
        case .keys:
            settings[keyPath: corner].action = .keyCombination(
                keyCode: nil, modifiers: 0, label: "")
        case .shortcut: settings[keyPath: corner].action = .shortcut(name: "")
        }
        rebuildDetails(corner: corner)
        onChange?()
    }

    private func rebuildDetails(corner: WritableKeyPath<AppSettings, CornerSetting>) {
        guard let stack = detailStacks[corner] else { return }
        stack.setViews([], in: .leading)
        for view in detailViews(corner: corner) { stack.addView(view, in: .leading) }
    }

    private func detailViews(corner: WritableKeyPath<AppSettings, CornerSetting>) -> [NSView] {
        switch settings[keyPath: corner].action {
        case .none, .mute, .playPause, .nextTrack, .previousTrack:
            return []
        case .openApp(let path):
            return chooser(path: path, title: "Choose App…", types: [.application]) {
                [weak self] chosen in
                self?.settings[keyPath: corner].action = .openApp(path: chosen)
            }
        case .openFile(let path):
            return chooser(path: path, title: "Choose…", types: nil) { [weak self] chosen in
                self?.settings[keyPath: corner].action = .openFile(path: chosen)
            }
        case .openLink(let url, let browserPath):
            return linkViews(url: url, browserPath: browserPath, corner: corner)
        case .keyCombination(_, _, let label):
            return keyViews(label: label, corner: corner)
        case .shortcut(let name):
            return [
                textField(value: name, placeholder: "Shortcut name") { [weak self] text in
                    self?.settings[keyPath: corner].action = .shortcut(name: text)
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
        url: String, browserPath: String?, corner: WritableKeyPath<AppSettings, CornerSetting>
    ) -> [NSView] {
        var browsers: [URL] = []
        if let sample = URL(string: "https://example.com") {
            browsers = NSWorkspace.shared.urlsForApplications(toOpen: sample)
        }
        var link = url
        var browser = browserPath
        let save: () -> Void = { [weak self] in
            self?.settings[keyPath: corner].action = .openLink(url: link, browserPath: browser)
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
        label: String, corner: WritableKeyPath<AppSettings, CornerSetting>
    ) -> [NSView] {
        let recorder = KeyRecorderButton(title: "", target: nil, action: nil)
        recorder.show(label: label)
        // This width fills the column, so the row lines up with the popups above it.
        recorder.widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true
        recorder.onRecord = { [weak self] code, flags, name in
            self?.settings[keyPath: corner].action = .keyCombination(
                keyCode: code, modifiers: flags, label: name)
            self?.onChange?()
        }
        bind(recorder) { [weak recorder] in recorder?.startRecording() }
        return [recorder]
    }

    private func textField(
        value: String, placeholder: String, _ assign: @escaping (String) -> Void
    ) -> NSTextField {
        let field = NSTextField(string: value)
        field.placeholderString = placeholder
        field.widthAnchor.constraint(equalToConstant: 150).isActive = true
        bind(field) { [weak field] in assign(field?.stringValue ?? "") }
        return field
    }
}
