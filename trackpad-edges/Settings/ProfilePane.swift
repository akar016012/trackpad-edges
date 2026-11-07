import AppKit

/// The base class of panes that edit one profile at a time. The picker row appears only once an
/// app has a profile, so that the pane stays simple until then.
class ProfilePane: SettingsPane {
    /// The app being edited, where nil is the default settings for all apps.
    private(set) var bundleID: String?
    /// Called when you pick a profile, so that the other panes can follow.
    var onSelectProfile: ((String?) -> Void)?
    /// Called when the picker row appears or disappears, so that the window can fit the pane.
    var onLayoutChange: (() -> Void)?

    private let picker = NSPopUpButton()
    private let scopeLabel = NSTextField(labelWithString: "")
    private var pickerRow: NSView?

    override var settings: AppSettings {
        get { SettingsStore.shared.settings.resolved(for: bundleID) }
        set { SettingsStore.shared.settings.apply(newValue, toProfile: bundleID) }
    }

    func makePickerRow() -> NSView {
        scopeLabel.textColor = .secondaryLabelColor
        bind(picker) { [weak self] in self?.pickerChanged() }
        let row = wideForm([[("Applies to:", picker), ("", scopeLabel)]])
        row.isHidden = SettingsStore.shared.settings.profiles.isEmpty
        pickerRow = row
        refreshProfiles()
        return row
    }

    private func pickerChanged() {
        let index = picker.indexOfSelectedItem
        let profiles = SettingsStore.shared.settings.profiles
        onSelectProfile?(index == 0 ? nil : profiles[index - 1].bundleID)
    }

    /// Shows a profile. A text field commits when it loses focus, so that happens first, or its
    /// text would land in the newly selected profile.
    func select(_ bundleID: String?) {
        guard bundleID != self.bundleID else { return }
        if isViewLoaded { view.window?.makeFirstResponder(nil) }
        self.bundleID = bundleID
        guard isViewLoaded else { return }
        refreshProfiles()
        profileChanged()
    }

    /// Brings the picker in step with the saved profiles.
    func refreshProfiles() {
        let profiles = SettingsStore.shared.settings.profiles
        if bundleID != nil, !profiles.contains(where: { $0.bundleID == bundleID }) {
            bundleID = nil
            // A pane that is still loading shows the right values by itself, and asking it to
            // show them here would load it a second time.
            if isViewLoaded { profileChanged() }
        }
        let titles = ["All Apps"] + profiles.map(\.name)
        if picker.itemTitles != titles {
            picker.removeAllItems()
            // This adds items one at a time, because two apps can share a name.
            for title in titles {
                picker.menu?.addItem(withTitle: title, action: nil, keyEquivalent: "")
            }
        }
        let index = profiles.firstIndex { $0.bundleID == bundleID }
        picker.selectItem(at: index.map { $0 + 1 } ?? 0)
        scopeLabel.stringValue =
            index == nil
            ? "Used by every other app." : "Used when this app is in front."
        let shouldHide = profiles.isEmpty
        if pickerRow?.isHidden != shouldHide {
            pickerRow?.isHidden = shouldHide
            if isViewLoaded { onLayoutChange?() }
        }
    }

    /// Shows the values of the selected profile.
    func profileChanged() {}
}
