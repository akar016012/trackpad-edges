import Foundation

/// What the app knows about one trackpad. A value is nil when the system did not answer.
nonisolated struct TrackpadInfo: Codable, Equatable, Sendable {
    var familyID: Int32?
    var isBuiltIn: Bool?

    var summary: String {
        let family = familyID.map { "family \($0)" } ?? "unknown family"
        switch isBuiltIn {
        case true?: return "\(family), built in"
        case false?: return "\(family), external"
        case nil: return family
        }
    }
}

/// The facts that a bug report needs, as plain text for the clipboard.
///
/// The formatting makes no system calls, so unit tests can check what the report includes and
/// what it leaves out. It never prints a file path, a link, an app name, a bundle identifier, a
/// recorded key label, a shortcut name, or a command, because those can be personal.
nonisolated struct DiagnosticsReport: Equatable, Sendable {
    var appVersion: String
    var appBuild: String
    var systemVersion: String
    var macModel: String
    var trackpads: [TrackpadInfo]
    var accessibilityGranted: Bool
    /// Whether the app is watching clicks, which every gesture needs.
    var clickWatchingOn: Bool
    var gesturesPaused: Bool
    var mediaAdapterLoaded: Bool
    /// The edge actions that are dimmed right now.
    var unavailable: Set<SlideKind>
    var settings: AppSettings
    /// Whether Lock Screen and Toggle Dark Mode have their private calls, or use the fallback.
    var lockUsesSystemCall = true
    var darkModeUsesSystemCall = true
    /// Whether Do Not Disturb has a key in Keyboard settings.
    var doNotDisturbKeySet = false

    var text: String {
        var lines = [
            "Trackpad Edges diagnostics",
            "App version: \(appVersion) (\(appBuild))",
            "macOS: \(systemVersion)",
            "Mac model: \(macModel)",
            "Accessibility: \(accessibilityGranted ? "granted" : "not granted")",
            "Click watching: \(clickWatchingOn ? "on" : "off")",
            "Gestures: \(gesturesPaused ? "paused" : "active")",
            "Media adapter: \(mediaAdapterLoaded ? "loaded" : "not loaded")",
            "Lock Screen: \(lockUsesSystemCall ? "system call" : "Control-Command-Q")",
            "Toggle Dark Mode: \(darkModeUsesSystemCall ? "system call" : "System Events")",
            "Do Not Disturb key: \(doNotDisturbKeySet ? "set" : "not set")",
            "",
            "Trackpads found: \(trackpads.count)",
        ]
        lines += trackpads.enumerated().map { "- Trackpad \($0.offset + 1): \($0.element.summary)" }
        lines += ["", unavailable.isEmpty ? "Dimmed actions: none" : "Dimmed actions:"]
        lines += SlideKind.allCases.filter(unavailable.contains).map {
            "- \($0.title): \($0.unavailableReason)"
        }
        lines += ["", "Settings for All Apps"]
        lines += EdgeSlot.allCases.map {
            "\($0.reportName): \(settings[keyPath: $0.path]?.title ?? "Off")"
        }
        lines += CornerSlot.allCases.map {
            "\($0.reportName): \(settings[keyPath: $0.path].reportSummary)"
        }
        lines += generalLines
        lines += ["", "Profiles: \(settings.profiles.count)"]
        for (index, profile) in settings.profiles.enumerated() {
            let edges = EdgeSlot.allCases.compactMap { slot in
                profile.edges[slot].map { "\(slot.reportName): \($0.kind?.title ?? "Off")" }
            }
            let corners = CornerSlot.allCases.compactMap { slot in
                profile.corners[slot].map { "\(slot.reportName): \($0.reportSummary)" }
            }
            let changes = edges + corners
            lines.append("- Profile \(index + 1)\(changes.isEmpty ? ": no changes" : ":")")
            lines += changes.map { "  - \($0)" }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private var generalLines: [String] {
        let haptics = settings.haptics
        let events = [
            ("steps", haptics.onStep), ("limits", haptics.onLimit), ("corners", haptics.onCorner),
            ("seek", haptics.onSeek),
        ].filter(\.1).map(\.0)
        let step =
            settings.seekStepType == .percent
            ? "\(Self.number(settings.seekStepValue))%"
            : "\(Self.number(settings.seekStepValue)) seconds"
        return [
            "Edge width: \(Self.number(Double(settings.edgeWidth) * 100))%",
            "Sensitivity: \(Self.number(Double(settings.sensitivity)))",
            "Require a click to start: \(settings.requireClick ? "on" : "off")",
            "Require key: \(settings.requiredModifier.rawValue)",
            "Sides, bottom quarter only: \(settings.bottomQuarterOnly ? "on" : "off")",
            "Corner press strength: \(Self.number(Double(settings.pressThreshold)))",
            "Seek step: \(step)",
            "Seek preview: \(settings.overlayStyle.title), \(settings.overlayPlacement.title)",
            "Haptics: \(haptics.enabled ? "on" : "off"), \(haptics.pattern.rawValue), strength "
                + "\(Self.number(Double(haptics.strength))), for "
                + (events.isEmpty ? "nothing" : events.joined(separator: ", ")),
        ]
    }

    /// Prints at most two decimals, and none for a whole number.
    private static func number(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}

nonisolated extension EdgeSlot {
    fileprivate var reportName: String {
        switch self {
        case .left: return "Left edge"
        case .right: return "Right edge"
        case .top: return "Top edge"
        case .bottom: return "Bottom edge"
        case .twoFingerLeft: return "Left edge, two fingers"
        case .twoFingerRight: return "Right edge, two fingers"
        case .twoFingerTop: return "Top edge, two fingers"
        case .twoFingerBottom: return "Bottom edge, two fingers"
        }
    }
}

nonisolated extension CornerSlot {
    fileprivate var reportName: String {
        switch self {
        case .topLeft: return "Top-left corner"
        case .topRight: return "Top-right corner"
        case .bottomLeft: return "Bottom-left corner"
        case .bottomRight: return "Bottom-right corner"
        }
    }
}

nonisolated extension CornerSetting {
    /// Lists each click count that can fire with the kind of action it holds.
    fileprivate var reportSummary: String {
        let parts = configuredClicks.sorted().map { count in
            "\(count) \(count == 1 ? "click" : "clicks") \(self[count].reportKind)"
        }
        return parts.isEmpty ? "no action" : parts.joined(separator: ", ")
    }
}

nonisolated extension CornerAction {
    /// The action's kind only, never what it opens, presses, or runs.
    fileprivate var reportKind: String { CornerActionKind(self).title }
}
