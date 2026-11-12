import Foundation

nonisolated enum RequiredModifier: String, Codable, CaseIterable, Sendable {
    case none, command, option, control, shift
}

nonisolated extension SlideKind {
    var title: String {
        switch self {
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        case .seek: return "Media Seek"
        case .scroll: return "Scroll"
        case .zoom: return "Zoom"
        case .switchApps: return "Switch Apps"
        case .switchSpaces: return "Switch Spaces"
        case .keyboardBacklight: return "Keyboard Backlight"
        case .externalBrightness: return "Monitor Brightness"
        }
    }

    /// Explains why this action is dimmed in the edge menus.
    var unavailableReason: String {
        switch self {
        case .brightness: return "This Mac does not allow the app to read its brightness."
        case .seek: return "The media adapter could not start."
        case .switchSpaces:
            return "Turn on the Mission Control shortcuts for moving between Spaces in System Settings."
        case .externalBrightness: return "No external monitor answered the app."
        default: return ""
        }
    }
}

/// Whether a seek step is a share of the track or a fixed time.
nonisolated enum SeekStepType: String, Codable, CaseIterable, Sendable {
    case percent, seconds

    var title: String { self == .percent ? "Percent of Track" : "Seconds" }
}

/// How the seek preview looks.
nonisolated enum OverlayStyle: String, Codable, CaseIterable, Sendable {
    case glass, clearGlass, frosted, solid

    var title: String {
        switch self {
        case .glass: return "Glass"
        case .clearGlass: return "Clear Glass"
        case .frosted: return "Frosted"
        case .solid: return "Solid"
        }
    }
}

/// Where the seek preview appears on the screen.
nonisolated enum OverlayPlacement: String, Codable, CaseIterable, Sendable {
    case bottom, center, top

    var title: String { rawValue.capitalized }
}

nonisolated enum HapticPattern: String, Codable, CaseIterable, Sendable {
    case soft, medium, firm

    /// The pattern ID for the private actuator API. The values were chosen by feel on hardware.
    var actuatorID: Int32 {
        switch self {
        case .soft: return 1
        case .medium: return 2
        case .firm: return 6
        }
    }
}

nonisolated struct HapticSettings: Codable, Equatable, Sendable {
    /// The strengths that the Haptics pane offers.
    static let strengthRange: ClosedRange<Float> = 0.4...2.0

    var enabled = true
    /// A scale from 0.4 to 2.0 that multiplies the pattern's base strength.
    var strength: Float = 1.0
    var pattern = HapticPattern.firm
    var onStep = true
    var onLimit = true
    var onCorner = true
    var onSeek = true
}

nonisolated extension HapticSettings {
    /// Reads each value on its own, so that one this version cannot read keeps its default.
    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.lenient(.enabled) ?? enabled
        strength = Self.strengthRange.holding(container.lenient(.strength)) ?? strength
        pattern = container.lenient(.pattern) ?? pattern
        onStep = container.lenient(.onStep) ?? onStep
        onLimit = container.lenient(.onLimit) ?? onLimit
        onCorner = container.lenient(.onCorner) ?? onCorner
        onSeek = container.lenient(.onSeek) ?? onSeek
    }
}

/// One assignable slide on one edge.
nonisolated enum EdgeSlot: String, Codable, CaseIterable, Sendable {
    case left, right, top, bottom
    case twoFingerLeft, twoFingerRight, twoFingerTop, twoFingerBottom

    var path: WritableKeyPath<AppSettings, SlideKind?> {
        switch self {
        case .left: return \.leftEdge
        case .right: return \.rightEdge
        case .top: return \.topEdge
        case .bottom: return \.bottomEdge
        case .twoFingerLeft: return \.twoFingerLeft
        case .twoFingerRight: return \.twoFingerRight
        case .twoFingerTop: return \.twoFingerTop
        case .twoFingerBottom: return \.twoFingerBottom
        }
    }

    var title: String {
        switch self {
        case .left: return "The left edge"
        case .right: return "The right edge"
        case .top: return "The top edge"
        case .bottom: return "The bottom edge"
        case .twoFingerLeft: return "A two-finger slide on the left edge"
        case .twoFingerRight: return "A two-finger slide on the right edge"
        case .twoFingerTop: return "A two-finger slide on the top edge"
        case .twoFingerBottom: return "A two-finger slide on the bottom edge"
        }
    }
}

nonisolated enum CornerSlot: String, Codable, CaseIterable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight

    var path: WritableKeyPath<AppSettings, CornerSetting> {
        switch self {
        case .topLeft: return \.topLeft
        case .topRight: return \.topRight
        case .bottomLeft: return \.bottomLeft
        case .bottomRight: return \.bottomRight
        }
    }

    /// The corner of a trackpad zone, or nil for an edge.
    init?(zone: Zone) {
        switch zone {
        case .topLeft: self = .topLeft
        case .topRight: self = .topRight
        case .bottomLeft: self = .bottomLeft
        case .bottomRight: self = .bottomRight
        case .left, .right, .bottom, .top: return nil
        }
    }

    /// A short name such as `top-left`, for notices.
    var shortName: String {
        switch self {
        case .topLeft: return "top-left"
        case .topRight: return "top-right"
        case .bottomLeft: return "bottom-left"
        case .bottomRight: return "bottom-right"
        }
    }

    var title: String {
        switch self {
        case .topLeft: return "The top-left corner"
        case .topRight: return "The top-right corner"
        case .bottomLeft: return "The bottom-left corner"
        case .bottomRight: return "The bottom-right corner"
        }
    }
}

/// What a profile sets an edge to. This wraps the value, because Off is a choice of its own and
/// must differ from a slot that the profile leaves alone.
nonisolated struct EdgeChoice: Codable, Equatable, Sendable {
    var kind: SlideKind?
}

/// The edges and corners that differ for one app. Everything else follows the default settings.
nonisolated struct AppProfile: Codable, Equatable, Sendable {
    var bundleID: String
    var name: String
    var edges: [EdgeSlot: EdgeChoice] = [:]
    var corners: [CornerSlot: CornerSetting] = [:]

    /// Describes each difference from the default settings in a full sentence.
    var summary: [String] {
        let edgeLines = EdgeSlot.allCases.compactMap { slot in
            edges[slot].map { "\(slot.title) uses \($0.kind?.title ?? "nothing")." }
        }
        let cornerLines = CornerSlot.allCases.compactMap { slot in
            corners[slot].map { _ in "\(slot.title) has its own actions." }
        }
        return edgeLines + cornerLines
    }
}

nonisolated extension AppProfile {
    /// Reads each edge and corner on its own. One that this version cannot read is left out, so
    /// that slot follows the default settings and the rest of the profile still loads.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            bundleID: try container.decode(String.self, forKey: .bundleID),
            name: try container.decode(String.self, forKey: .name))
        edges = container.lenientPairs(.edges)
        corners = container.lenientPairs(.corners)
    }
}

/// All settings. The stored edges and corners are the default profile, which every app without a
/// profile of its own uses, so settings saved before profiles existed need no conversion.
nonisolated struct AppSettings: Codable, Equatable, Sendable {
    /// The ranges that the window offers. Loaded settings are held to them, because the gesture
    /// and seek arithmetic divides by the sensitivity and the seek step, and the window's controls
    /// can neither show nor produce a value outside its range.
    static let edgeWidthRange: ClosedRange<Float> = 0.05...0.20
    static let sensitivityRange: ClosedRange<Float> = 0.5...2.0
    static let pressThresholdRange: ClosedRange<Float> = 70...115
    static let seekPercentRange: ClosedRange<Double> = 0.5...10
    static let seekSecondsRange: ClosedRange<Double> = 1...60

    var leftEdge: SlideKind? = .brightness
    var rightEdge: SlideKind? = .volume
    var bottomEdge: SlideKind? = .seek
    var topEdge: SlideKind?
    /// What a two-finger slide does on each edge, which is nothing until you assign it.
    var twoFingerLeft: SlideKind?
    var twoFingerRight: SlideKind?
    var twoFingerBottom: SlideKind?
    var twoFingerTop: SlideKind?
    var topLeft = CornerSetting(action: .mute, clicks: 1)
    var topRight = CornerSetting(action: .none, clicks: 1)
    /// These are optional in storage, so that settings saved before they existed still load.
    private var storedBottomLeft: CornerSetting?
    private var storedBottomRight: CornerSetting?
    private var storedSeekStepPercent: Double?
    private var storedSeekStepSeconds: Double?
    private var storedSeekStepType: SeekStepType?
    private var storedPressThreshold: Float?
    private var storedOverlayStyle: OverlayStyle?
    private var storedOverlayPlacement: OverlayPlacement?
    private var storedProfiles: [AppProfile]?
    var bottomQuarterOnly = false
    /// Whether a slide needs a physical click. By default, touching a strip starts a slide.
    var requireClick = false
    var requiredModifier = RequiredModifier.none
    /// The width of the strips as a fraction of the pad.
    var edgeWidth: Float = 0.10
    /// A multiplier from 0.5 to 2.0, where higher values need less finger travel for each step.
    var sensitivity: Float = 1.0
    var haptics = HapticSettings()

    var bottomLeft: CornerSetting {
        get { storedBottomLeft ?? CornerSetting(action: .none, clicks: 1) }
        set { storedBottomLeft = newValue }
    }

    var bottomRight: CornerSetting {
        get { storedBottomRight ?? CornerSetting(action: .none, clicks: 1) }
        set { storedBottomRight = newValue }
    }

    var seekStepType: SeekStepType {
        get { storedSeekStepType ?? .percent }
        set { storedSeekStepType = newValue }
    }

    /// The amount of one seek step: 0.5 to 10 percent, or 1 to 60 seconds.
    var seekStepValue: Double {
        get {
            seekStepType == .percent ? storedSeekStepPercent ?? 1 : storedSeekStepSeconds ?? 5
        }
        set {
            if seekStepType == .percent {
                storedSeekStepPercent = newValue
            } else {
                storedSeekStepSeconds = newValue
            }
        }
    }

    var seekStep: SeekStep {
        seekStepType == .percent ? .percent(seekStepValue) : .seconds(seekStepValue)
    }

    /// The pressure that fires a corner. Lower values need a lighter press.
    var pressThreshold: Float {
        get { storedPressThreshold ?? 90 }
        set { storedPressThreshold = newValue }
    }

    var overlayStyle: OverlayStyle {
        get { storedOverlayStyle ?? .glass }
        set { storedOverlayStyle = newValue }
    }

    var overlayPlacement: OverlayPlacement {
        get { storedOverlayPlacement ?? .bottom }
        set { storedOverlayPlacement = newValue }
    }

    var profiles: [AppProfile] {
        get { storedProfiles ?? [] }
        set { storedProfiles = newValue }
    }

    func profile(for bundleID: String?) -> AppProfile? {
        profiles.first { $0.bundleID == bundleID }
    }

    /// Returns these settings as one app sees them, with its profile laid over the defaults.
    func resolved(for bundleID: String?) -> AppSettings {
        guard let profile = profile(for: bundleID) else { return self }
        var result = self
        for (slot, choice) in profile.edges { result[keyPath: slot.path] = choice.kind }
        for (slot, corner) in profile.corners { result[keyPath: slot.path] = corner }
        return result
    }

    /// Saves settings that were edited for one app. Only slots that changed are touched, and one
    /// set back to its default stops being stored, so it follows the default again. Every setting
    /// outside a profile applies to all apps.
    mutating func apply(_ edited: AppSettings, toProfile bundleID: String?) {
        guard let index = profiles.firstIndex(where: { $0.bundleID == bundleID }) else {
            self = edited
            return
        }
        var profile = profiles[index]
        let before = resolved(for: bundleID)
        var merged = edited
        for slot in EdgeSlot.allCases {
            let value = edited[keyPath: slot.path]
            let fallback = self[keyPath: slot.path]
            merged[keyPath: slot.path] = fallback
            guard value != before[keyPath: slot.path] else { continue }
            profile.edges[slot] = value == fallback ? nil : EdgeChoice(kind: value)
        }
        for slot in CornerSlot.allCases {
            let value = edited[keyPath: slot.path]
            let fallback = self[keyPath: slot.path]
            merged[keyPath: slot.path] = fallback
            guard value != before[keyPath: slot.path] else { continue }
            profile.corners[slot] = value == fallback ? nil : value
        }
        merged.profiles[index] = profile
        self = merged
    }

    func corner(for zone: Zone) -> CornerSetting? {
        switch zone {
        case .topLeft: return topLeft
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        case .left, .right, .bottom, .top: return nil
        }
    }

    func gestureConfig(unavailable: Set<SlideKind>) -> GestureConfig {
        var config = GestureConfig()
        config.edgeWidth = edgeWidth
        // 0.035 is the default step in GestureConfig, so a sensitivity of 1 keeps that step.
        config.stepSize = 0.035 / sensitivity
        config.bottomQuarterOnly = bottomQuarterOnly
        config.requireClick = requireClick
        config.leftAction = leftEdge
        config.rightAction = rightEdge
        config.bottomAction = bottomEdge
        config.topAction = topEdge
        let twoFinger: [(Zone, SlideKind?)] = [
            (.left, twoFingerLeft), (.right, twoFingerRight), (.bottom, twoFingerBottom),
            (.top, twoFingerTop),
        ]
        for case (let zone, let kind?) in twoFinger { config.twoFingerActions[zone] = kind }
        config.unavailableKinds = unavailable
        config.cornerCounts = [
            .topLeft: topLeft.configuredClicks, .topRight: topRight.configuredClicks,
            .bottomLeft: bottomLeft.configuredClicks, .bottomRight: bottomRight.configuredClicks,
        ]
        config.pressThreshold = pressThreshold
        return config
    }
}

nonisolated extension AppSettings {
    /// The range of one seek step for each step type.
    static func seekStepRange(for type: SeekStepType) -> ClosedRange<Double> {
        type == .percent ? seekPercentRange : seekSecondsRange
    }

    /// Reads each setting on its own. A value that this version cannot read, such as an action
    /// that a newer version added, falls back by itself, where a plain read would refuse every
    /// setting. An edge falls back to Off and a profile slot to the default settings, because
    /// doing nothing is safer than doing something else. Numbers are held to their ranges.
    init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        leftEdge = container.lenient(.leftEdge)
        rightEdge = container.lenient(.rightEdge)
        bottomEdge = container.lenient(.bottomEdge)
        topEdge = container.lenient(.topEdge)
        twoFingerLeft = container.lenient(.twoFingerLeft)
        twoFingerRight = container.lenient(.twoFingerRight)
        twoFingerBottom = container.lenient(.twoFingerBottom)
        twoFingerTop = container.lenient(.twoFingerTop)
        topLeft = container.lenient(.topLeft) ?? topLeft
        topRight = container.lenient(.topRight) ?? topRight
        storedBottomLeft = container.lenient(.storedBottomLeft)
        storedBottomRight = container.lenient(.storedBottomRight)
        storedSeekStepPercent = Self.seekPercentRange.holding(
            container.lenient(.storedSeekStepPercent))
        storedSeekStepSeconds = Self.seekSecondsRange.holding(
            container.lenient(.storedSeekStepSeconds))
        storedSeekStepType = container.lenient(.storedSeekStepType)
        storedPressThreshold = Self.pressThresholdRange.holding(
            container.lenient(.storedPressThreshold))
        storedOverlayStyle = container.lenient(.storedOverlayStyle)
        storedOverlayPlacement = container.lenient(.storedOverlayPlacement)
        storedProfiles = container.lenientList(.storedProfiles)
        bottomQuarterOnly = container.lenient(.bottomQuarterOnly) ?? bottomQuarterOnly
        requireClick = container.lenient(.requireClick) ?? requireClick
        requiredModifier = container.lenient(.requiredModifier) ?? requiredModifier
        edgeWidth = Self.edgeWidthRange.holding(container.lenient(.edgeWidth)) ?? edgeWidth
        sensitivity = Self.sensitivityRange.holding(container.lenient(.sensitivity)) ?? sensitivity
        haptics = container.lenient(.haptics) ?? haptics
    }
}
