import AppKit
import UniformTypeIdentifiers

/// Lists the apps that have their own edges and corners.
final class ProfilesPane: SettingsPane, NSTableViewDataSource, NSTableViewDelegate {
    private static let listHeight: CGFloat = 186
    private static let rowHeight: CGFloat = 30
    private static let iconSize: CGFloat = 20

    /// Called when you ask to edit a profile, with the tab to open.
    var onEdit: ((String, MainWindowController.Tab) -> Void)?

    private let table = NSTableView()
    private let detailTitle = NSTextField(labelWithString: "")
    private let detailText = NSTextField(wrappingLabelWithString: "")
    private lazy var removeButton = button("Remove") { [weak self] in self?.removeSelected() }
    private lazy var edgesButton = button("Edit Edges") { [weak self] in self?.edit(.edges) }
    private lazy var cornersButton = button("Edit Corners") { [weak self] in self?.edit(.corners) }

    private var profiles: [AppProfile] { SettingsStore.shared.settings.profiles }

    private var selected: AppProfile? {
        profiles.indices.contains(table.selectedRow) ? profiles[table.selectedRow] : nil
    }

    override func loadView() {
        setContent([
            columns(makeList(), makeDetails()),
            note(
                "A profile takes over as soon as its app comes to the front. Anything it does not change follows All Apps."
            ),
        ])
        selectFirstAppIfNeeded()
        updateDetails()
    }

    /// Keeps the details column useful, because it says nothing while no app is selected.
    private func selectFirstAppIfNeeded() {
        if table.selectedRow < 0, !profiles.isEmpty {
            table.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    private func makeList() -> NSView {
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        table.addTableColumn(tableColumn)
        table.headerView = nil
        table.rowHeight = Self.rowHeight
        table.style = .plain
        table.dataSource = self
        table.delegate = self
        table.setAccessibilityLabel("Apps with a profile")

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .lineBorder
        scroll.heightAnchor.constraint(equalToConstant: Self.listHeight).isActive = true
        scroll.widthAnchor.constraint(equalToConstant: Self.columnWidth).isActive = true

        let add = button("Add App…") { [weak self] in self?.addApp() }
        let buttons = NSStackView(views: [add, removeButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        return column([scroll, buttons])
    }

    private func makeDetails() -> NSView {
        detailTitle.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        detailText.preferredMaxLayoutWidth = Self.columnWidth
        let buttons = NSStackView(views: [edgesButton, cornersButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        return column([detailTitle, detailText, buttons])
    }

    private func addApp() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.add(url)
        }
    }

    private func add(_ url: URL) {
        guard let identifier = Bundle(url: url)?.bundleIdentifier else {
            let alert = NSAlert()
            alert.messageText = "This app cannot have a profile."
            alert.informativeText = "The app does not say which app it is, so it cannot be matched."
            alert.runModal()
            return
        }
        if !profiles.contains(where: { $0.bundleID == identifier }) {
            var name = FileManager.default.displayName(atPath: url.path)
            // Only this suffix goes, because a name such as draw.io has a dot of its own.
            if name.hasSuffix(".app") { name.removeLast(4) }
            let profile = AppProfile(bundleID: identifier, name: name)
            SettingsStore.shared.settings.profiles.append(profile)
        }
        table.reloadData()
        let row = profiles.firstIndex { $0.bundleID == identifier } ?? 0
        table.selectRowIndexes([row], byExtendingSelection: false)
    }

    private func removeSelected() {
        guard let profile = selected else { return }
        SettingsStore.shared.settings.profiles.removeAll { $0.bundleID == profile.bundleID }
        table.reloadData()
        selectFirstAppIfNeeded()
        updateDetails()
    }

    private func edit(_ tab: MainWindowController.Tab) {
        if let profile = selected { onEdit?(profile.bundleID, tab) }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    /// Brings the list and its details in step with what is saved. A hidden pane waits until it
    /// appears, because this runs on every settings change.
    func refresh() {
        guard isViewLoaded, view.window != nil else { return }
        let row = table.selectedRow
        table.reloadData()
        if profiles.indices.contains(row) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
        selectFirstAppIfNeeded()
        updateDetails()
    }

    private func updateDetails() {
        let profile = selected
        removeButton.isEnabled = profile != nil
        edgesButton.isHidden = profile == nil
        cornersButton.isHidden = profile == nil
        if let profile {
            detailTitle.stringValue = profile.name
            let lines = profile.summary
            detailText.stringValue =
                lines.isEmpty
                ? "This app follows All Apps until you change something for it."
                : lines.joined(separator: "\n")
        } else if profiles.isEmpty {
            detailTitle.stringValue = "No profiles yet"
            detailText.stringValue =
                "Add an app to give it its own edges and corners. For example, the bottom edge could seek in a video app and zoom in a design app."
        } else {
            detailTitle.stringValue = "No app selected"
            detailText.stringValue = "Select an app to see what its profile changes."
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        profiles.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetails()
    }

    func tableView(
        _ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int
    ) -> NSView? {
        let profile = profiles[row]
        let icon = NSImageView()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.bundleID) {
            icon.image = NSWorkspace.shared.icon(forFile: url.path)
        }
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        icon.heightAnchor.constraint(equalToConstant: Self.iconSize).isActive = true
        let name = NSTextField(labelWithString: profile.name)
        name.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [icon, name])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // A table cell view lets VoiceOver read the row as one item.
        let cell = NSTableCellView()
        cell.imageView = icon
        cell.textField = name
        cell.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
