import AppKit

/// Lets you choose what each edge does, and shows the result on a live trackpad diagram.
final class EdgesPane: SettingsPane {
    private static let choices: [(title: String, kind: SlideKind?)] =
        SlideKind.allCases.map { ($0.title, $0) } + [("Off", nil)]

    let diagram = TrackpadDiagramView()
    private var edgePopups: [(popup: NSPopUpButton, path: KeyPath<AppSettings, SlideKind?>)] = []

    override func loadView() {
        let current = settings
        let form = form([
            ("Left edge:", edgePopup(\.leftEdge)),
            ("Right edge:", edgePopup(\.rightEdge)),
            ("Top edge:", edgePopup(\.topEdge)),
            ("Bottom edge:", edgePopup(\.bottomEdge)),
            (
                "Edge width:",
                slider(value: Double(current.edgeWidth), range: 0.05...0.20) { [weak self] value in
                    self?.settings.edgeWidth = Float(value)
                    self?.diagram.settingsChanged()
                }
            ),
            (
                "Sensitivity:",
                slider(value: Double(current.sensitivity), range: 0.5...2.0) { [weak self] value in
                    self?.settings.sensitivity = Float(value)
                }
            ),
        ])
        let options = wideForm([
            [
                ("Require key:", modifierPopup(current.requiredModifier)),
                (
                    "Options:",
                    checkbox("Require a click to start", isOn: current.requireClick) {
                        [weak self] isOn in self?.settings.requireClick = isOn
                    }
                ),
            ],
            [
                ("", NSGridCell.emptyContentView),
                (
                    "",
                    checkbox("Sides: bottom quarter only", isOn: current.bottomQuarterOnly) {
                        [weak self] isOn in
                        self?.settings.bottomQuarterOnly = isOn
                        self?.diagram.settingsChanged()
                    }
                ),
            ],
        ])
        setContent([
            columns(diagram, form),
            options,
            note("Touch a strip and slide. A click without a slide stays a normal click."),
        ])
        // The diagram matches the controls beside it, so both columns end on the same line.
        diagram.heightAnchor.constraint(equalTo: form.heightAnchor).isActive = true
    }

    /// Brings the pane back in step after the menu bar item changes an edge.
    func refresh() {
        let unavailable = actions.unavailableKinds()
        for (popup, path) in edgePopups {
            popup.selectItem(at: Self.index(of: settings[keyPath: path]))
            for (item, choice) in zip(popup.itemArray, Self.choices) {
                item.isEnabled = choice.kind.map { !unavailable.contains($0) } ?? true
                item.toolTip = item.isEnabled ? nil : choice.kind?.unavailableReason
            }
        }
        diagram.settingsChanged()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    private static func index(of kind: SlideKind?) -> Int {
        choices.firstIndex { $0.kind == kind } ?? 0
    }

    private func edgePopup(_ path: WritableKeyPath<AppSettings, SlideKind?>) -> NSPopUpButton {
        let edge = popup(
            Self.choices.map(\.title), selected: Self.index(of: settings[keyPath: path])
        ) { [weak self] index in
            self?.settings[keyPath: path] = Self.choices[index].kind
            self?.diagram.settingsChanged()
        }
        edge.autoenablesItems = false
        edgePopups.append((edge, path))
        return edge
    }

    private func modifierPopup(_ current: RequiredModifier) -> NSPopUpButton {
        let all = RequiredModifier.allCases
        let titles = all.map { $0 == .none ? "None" : $0.rawValue.capitalized }
        return popup(titles, selected: all.firstIndex(of: current) ?? 0) { [weak self] index in
            self?.settings.requiredModifier = all[index]
        }
    }
}
