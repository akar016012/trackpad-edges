import Foundation

/// The groups of the corner action popup, in the order that it shows them.
nonisolated enum CornerActionGroup: String, CaseIterable, Sendable {
    case none, media, open, automation, system, power

    /// The header above the group. The first group holds only No Action, so it has none.
    var title: String? {
        switch self {
        case .none: return nil
        case .media: return "Media"
        case .open: return "Open"
        case .automation: return "Automation"
        case .system: return "System"
        case .power: return "Power"
        }
    }
}

/// The kind of a corner action, without its details. This is the one place that names each
/// action, so that the Corners pane, the welcome tour, and the diagnostics report agree.
nonisolated enum CornerActionKind: Hashable, Sendable {
    case none, mute, playPause, nextTrack, previousTrack
    case app, link, file
    case keys, shortcut, command
    case system(SystemAction)

    /// Every kind in popup order, grouped as `CornerActionGroup` lists the groups.
    static let allCases: [CornerActionKind] =
        [
            .none, .mute, .playPause, .nextTrack, .previousTrack, .app, .link, .file, .keys,
            .shortcut,
            .command,
        ]
        + CornerActionGroup.allCases.flatMap { group in
            SystemAction.allCases.filter { $0.group == group }.map(CornerActionKind.system)
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
        case .command: self = .command
        case .system(let action): self = .system(action)
        }
    }

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
        case .command: return "Run Command"
        case .system(let action): return action.title
        }
    }

    var group: CornerActionGroup {
        switch self {
        case .none: return .none
        case .mute, .playPause, .nextTrack, .previousTrack: return .media
        case .app, .link, .file: return .open
        case .keys, .shortcut, .command: return .automation
        case .system(let action): return action.group
        }
    }

    /// A stable number for this kind, which the popup uses as each item's tag. A menu with
    /// headers and separators has more items than kinds, so its positions cannot stand in.
    var tag: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    init?(tag: Int) {
        guard Self.allCases.indices.contains(tag) else { return nil }
        self = Self.allCases[tag]
    }

    /// The action that choosing this kind assigns, before you fill in its details.
    var blankAction: CornerAction {
        switch self {
        case .none: return .none
        case .mute: return .mute
        case .playPause: return .playPause
        case .nextTrack: return .nextTrack
        case .previousTrack: return .previousTrack
        case .app: return .openApp(path: "")
        case .link: return .openLink(url: "", browserPath: nil)
        case .file: return .openFile(path: "")
        case .keys: return .keyCombination(keyCode: nil, modifiers: 0, label: "")
        case .shortcut: return .shortcut(name: "")
        case .command: return .command(script: "")
        case .system(let action): return .system(action: action)
        }
    }
}
