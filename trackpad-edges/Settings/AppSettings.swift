import AppKit

/// What a corner does when it fires.
enum CornerAction: Codable, Equatable {
    case none
    case mute
    case playPause
    case nextTrack
    case previousTrack
    case openApp(path: String)
    case openLink(url: String, browserPath: String?)
    case openFile(path: String)
    /// A nil key code means that nothing has been recorded yet. The label is for display.
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
        case .keyCombination(let keyCode, _, _): return keyCode != nil
        case .shortcut(let name): return !name.isEmpty && !name.hasPrefix("-")
        }
    }
}

struct CornerSetting: Codable, Equatable {
    var action: CornerAction
    /// The number of clicks that fires the action, from 1 to 4.
    var clicks: Int
}

enum RequiredModifier: String, Codable, CaseIterable {
    case none, command, option, control, shift

    var flags: NSEvent.ModifierFlags {
        switch self {
        case .none: return []
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }
}

/// How the seek preview looks.
enum OverlayStyle: String, Codable, CaseIterable {
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
enum OverlayPlacement: String, Codable, CaseIterable {
    case bottom, center, top

    var title: String { rawValue.capitalized }
}

enum HapticPattern: String, Codable, CaseIterable {
    case soft, medium, firm

    var actuatorID: Int32 {
        switch self {
        case .soft: return 1
        case .medium: return 2
        case .firm: return 6
        }
    }
}

struct HapticSettings: Codable, Equatable {
    var enabled = true
    /// A scale from 0.4 to 2.0 that multiplies the pattern's base strength.
    var strength: Float = 1.0
    var pattern = HapticPattern.firm
    var onStep = true
    var onLimit = true
    var onCorner = true
    var onSeek = true
}

struct AppSettings: Codable, Equatable {
    var leftEdge: SlideKind? = .brightness
    var rightEdge: SlideKind? = .volume
    var bottomEdge: SlideKind? = .seek
    var topLeft = CornerSetting(action: .mute, clicks: 1)
    var topRight = CornerSetting(action: .none, clicks: 1)
    /// These are optional in storage, so that settings saved before they existed still load.
    private var storedBottomLeft: CornerSetting?
    private var storedBottomRight: CornerSetting?
    private var storedSeekStepPercent: Double?
    private var storedOverlayStyle: OverlayStyle?
    private var storedOverlayPlacement: OverlayPlacement?
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

    /// The percentage of the track that one seek step moves, from 0.5 to 10.
    var seekStepPercent: Double {
        get { storedSeekStepPercent ?? 1 }
        set { storedSeekStepPercent = newValue }
    }

    var overlayStyle: OverlayStyle {
        get { storedOverlayStyle ?? .glass }
        set { storedOverlayStyle = newValue }
    }

    var overlayPlacement: OverlayPlacement {
        get { storedOverlayPlacement ?? .bottom }
        set { storedOverlayPlacement = newValue }
    }

    func corner(for zone: Zone) -> CornerSetting? {
        switch zone {
        case .topLeft: return topLeft
        case .topRight: return topRight
        case .bottomLeft: return bottomLeft
        case .bottomRight: return bottomRight
        case .left, .right, .bottom: return nil
        }
    }

    func gestureConfig(brightnessAvailable: Bool, seekAvailable: Bool) -> GestureConfig {
        var config = GestureConfig()
        config.edgeWidth = edgeWidth
        config.stepSize = 0.035 / sensitivity
        config.bottomQuarterOnly = bottomQuarterOnly
        config.requireClick = requireClick
        config.leftAction = leftEdge
        config.rightAction = rightEdge
        config.bottomAction = bottomEdge
        config.brightnessAvailable = brightnessAvailable
        config.seekAvailable = seekAvailable
        config.topLeftClicks = topLeft.action.isConfigured ? topLeft.clicks : nil
        config.topRightClicks = topRight.action.isConfigured ? topRight.clicks : nil
        config.bottomLeftClicks = bottomLeft.action.isConfigured ? bottomLeft.clicks : nil
        config.bottomRightClicks = bottomRight.action.isConfigured ? bottomRight.clicks : nil
        return config
    }
}

/// Keeps the settings in user defaults and tells the app when they change.
final class SettingsStore {
    static let shared = SettingsStore()
    private static let key = "settings"

    var onChange: (() -> Void)?

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            if let data = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
            onChange?()
        }
    }

    private init() {
        let data = UserDefaults.standard.data(forKey: Self.key)
        settings = data.flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
    }
}
