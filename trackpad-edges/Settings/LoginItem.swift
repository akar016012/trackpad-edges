import AppKit
import ServiceManagement

/// Starts the app at login. The system owns this setting, so controls always show what it reports.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /**
     Turns the setting on or off. A login item can also wait for your approval in System
     Settings, and that is the only place to give it, so this takes you there.
     */
    static func set(_ isOn: Bool) {
        let service = SMAppService.mainApp
        guard isOn != isEnabled else { return }
        guard !isOn || service.status != .requiresApproval else {
            SMAppService.openSystemSettingsLoginItems()
            return
        }
        do {
            if isOn {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch let error as NSError where error.code == kSMErrorLaunchDeniedByUser {
            // Settings opens below, and that is more use than an alert.
        } catch {
            NSAlert(error: error).runModal()
        }
        if isOn, service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
