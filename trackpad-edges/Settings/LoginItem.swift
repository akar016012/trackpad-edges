import AppKit
import ServiceManagement

/// Starts the app at login. The system owns this setting, so controls always show what it reports.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
