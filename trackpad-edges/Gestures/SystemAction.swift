import Foundation

/// An action that controls the Mac. The raw values are saved, so never change them.
nonisolated enum SystemAction: String, Codable, CaseIterable, Sendable {
    case lockScreen, startScreenSaver, sleepDisplay, sleep, logOut, restart, shutDown
    case toggleDarkMode, toggleDoNotDisturb, emptyTrash

    /// The popup title. Actions that confirm first end with an ellipsis.
    var title: String {
        switch self {
        case .lockScreen: return "Lock Screen"
        case .startScreenSaver: return "Start Screen Saver"
        case .sleepDisplay: return "Sleep Display"
        case .sleep: return "Sleep"
        case .logOut: return "Log Out…"
        case .restart: return "Restart…"
        case .shutDown: return "Shut Down…"
        case .toggleDarkMode: return "Toggle Dark Mode"
        case .toggleDoNotDisturb: return "Toggle Do Not Disturb"
        case .emptyTrash: return "Empty Trash"
        }
    }

    var group: CornerActionGroup {
        switch self {
        case .lockScreen, .startScreenSaver, .sleepDisplay, .sleep, .logOut, .restart, .shutDown:
            return .power
        case .toggleDarkMode, .toggleDoNotDisturb, .emptyTrash:
            return .system
        }
    }

    /// Whether the action ends the session and needs confirmation.
    var confirmsFirst: Bool {
        switch self {
        case .logOut, .restart, .shutDown: return true
        default: return false
        }
    }

    /// Whether the action waits briefly so the lifting finger does not wake the Mac.
    var waitsForLift: Bool {
        switch self {
        case .startScreenSaver, .sleepDisplay, .sleep: return true
        default: return false
        }
    }

    /**
     Whether the action is ignored just after a wake or unlock, so a resting finger cannot send
     the Mac back to sleep.
     */
    var pausesAfterWake: Bool {
        switch self {
        case .lockScreen, .startScreenSaver, .sleepDisplay, .sleep: return true
        default: return false
        }
    }

    /// The confirm box text, if the action has one.
    var confirmation: (question: String, button: String)? {
        switch self {
        case .logOut: return ("Log out of this Mac?", "Log Out")
        case .restart: return ("Restart this Mac?", "Restart")
        case .shutDown: return ("Shut down this Mac?", "Shut Down")
        default: return nil
        }
    }
}
