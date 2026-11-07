import Foundation

/// What a corner does when it fires.
nonisolated enum CornerAction: Codable, Equatable, Sendable {
    case none
    case mute
    case playPause
    case nextTrack
    case previousTrack
    case openApp(path: String)
    case openLink(url: String, browserPath: String?)
    case openFile(path: String)
    /// A nil key code with modifiers presses those modifiers alone. A nil key code with no
    /// modifiers means that nothing has been recorded yet. The label shows the whole shortcut.
    case keyCombination(keyCode: UInt16?, modifiers: UInt64, label: String)
    case shortcut(name: String)

    /// Whether the action has everything it needs. A corner that is not configured stays a normal
    /// part of the trackpad, so that it never swallows clicks while doing nothing.
    var isConfigured: Bool {
        switch self {
        case .none: return false
        case .mute, .playPause, .nextTrack, .previousTrack: return true
        case .openApp(let path), .openFile(let path): return !path.isEmpty
        case .openLink(let url, _):
            return ["http", "https"].contains(URL(string: url)?.scheme?.lowercased())
        case .keyCombination(let keyCode, let modifiers, _): return keyCode != nil || modifiers != 0
        case .shortcut(let name): return !name.isEmpty && !name.hasPrefix("-")
        }
    }
}

/// The actions of one corner, with one action for each click count from 1 to 4.
nonisolated struct CornerSetting: Codable, Equatable, Sendable {
    static let maxClicks = 4

    private var actions: [CornerAction]

    init(action: CornerAction, clicks: Int) {
        actions = Array(repeating: .none, count: Self.maxClicks)
        self[clicks] = action
    }

    subscript(clicks: Int) -> CornerAction {
        get { actions.indices.contains(clicks - 1) ? actions[clicks - 1] : .none }
        set { if actions.indices.contains(clicks - 1) { actions[clicks - 1] = newValue } }
    }

    /// The click counts that have an action, which are the only ones that can fire.
    var configuredClicks: Set<Int> {
        Set((1...Self.maxClicks).filter { self[$0].isConfigured })
    }

    private enum CodingKeys: String, CodingKey {
        case actions, action, clicks
    }

    /// Settings saved before corners held several actions have one action and one click count.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let saved = try container.decodeIfPresent([CornerAction].self, forKey: .actions) {
            // A list of the wrong length is repaired, so one odd value cannot lose a corner.
            let padding = Array(repeating: CornerAction.none, count: Self.maxClicks)
            actions = Array((saved + padding).prefix(Self.maxClicks))
            return
        }
        let action = try container.decode(CornerAction.self, forKey: .action)
        let clicks = try container.decode(Int.self, forKey: .clicks)
        var migrated = Array(repeating: CornerAction.none, count: Self.maxClicks)
        if migrated.indices.contains(clicks - 1) { migrated[clicks - 1] = action }
        actions = migrated
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actions, forKey: .actions)
    }
}
