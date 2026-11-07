import AppKit

extension RequiredModifier {
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
