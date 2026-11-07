import AppKit

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

extension SlideKind {
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
enum SeekStepType: String, Codable, CaseIterable {
    case percent, seconds

    var title: String { self == .percent ? "Percent of Track" : "Seconds" }
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
    var topEdge: SlideKind?
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
        config.stepSize = 0.035 / sensitivity
        config.bottomQuarterOnly = bottomQuarterOnly
        config.requireClick = requireClick
        config.leftAction = leftEdge
        config.rightAction = rightEdge
        config.bottomAction = bottomEdge
        config.topAction = topEdge
        config.unavailableKinds = unavailable
        config.cornerCounts = [
            .topLeft: topLeft.configuredClicks, .topRight: topRight.configuredClicks,
            .bottomLeft: bottomLeft.configuredClicks, .bottomRight: bottomRight.configuredClicks,
        ]
        config.pressThreshold = pressThreshold
        return config
    }
}

/// Keeps the settings in user defaults and tells the app when they change.
final class SettingsStore {
    static let shared = SettingsStore()
    private static let key = "settings"
    private static let backupKey = "settings.unreadable"

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
        guard let data = UserDefaults.standard.data(forKey: Self.key) else {
            settings = AppSettings()
            return
        }
        if let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved
        } else {
            // The next save would overwrite these bytes, so they are kept for recovery.
            UserDefaults.standard.set(data, forKey: Self.backupKey)
            settings = AppSettings()
        }
    }
}
