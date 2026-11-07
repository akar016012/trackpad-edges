import AppKit

/// What a corner does when it fires.
enum CornerAction: Codable, Equatable {
    case none
    case mute
    case openApp(path: String)
    case openLink(url: String, browserPath: String?)
    case openFile(path: String)
    case keyCombination(keyCode: UInt16, modifiers: UInt64)
    case shortcut(name: String)
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
    var bottomQuarterOnly = false
    /// Whether a slide needs a physical click. By default, touching a strip starts a slide.
    var requireClick = false
    var requiredModifier = RequiredModifier.none
    /// The width of the strips as a fraction of the pad.
    var edgeWidth: Float = 0.10
    /// A multiplier from 0.5 to 2.0, where higher values need less finger travel for each step.
    var sensitivity: Float = 1.0
    var haptics = HapticSettings()
    var hasFinishedSetup = false

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
        config.topLeftClicks = topLeft.action == .none ? nil : topLeft.clicks
        config.topRightClicks = topRight.action == .none ? nil : topRight.clicks
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
