import Foundation

/// An action that controls the Mac itself. The raw values are saved, so they must never change.
///
/// This type holds only names and rules. How each action is carried out lives in the runners,
/// and the codes for logging out, restarting, and shutting down stay private to the one file
/// that sends them, so that nothing else can reach them without the confirm box.
nonisolated enum SystemAction: String, Codable, CaseIterable, Sendable {
    case lockScreen, startScreenSaver, sleepDisplay, sleep, logOut, restart, shutDown
    case toggleDarkMode, toggleDoNotDisturb, emptyTrash

    /// The name in the action popup. An action that opens the confirm box ends with an ellipsis.
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

    /// Whether the action runs only after you confirm it, because it ends your session.
    var confirmsFirst: Bool {
        switch self {
        case .logOut, .restart, .shutDown: return true
        default: return false
        }
    }

    /// Whether the action waits a moment after the press, so that the lifting finger does not
    /// wake the Mac or end the screen saver at once.
    var waitsForLift: Bool {
        switch self {
        case .startScreenSaver, .sleepDisplay, .sleep: return true
        default: return false
        }
    }

    /// Whether the action is ignored for a moment after the Mac wakes or unlocks. A finger that was
    /// already resting on the corner could otherwise send the Mac straight back to sleep.
    var pausesAfterWake: Bool {
        switch self {
        case .lockScreen, .startScreenSaver, .sleepDisplay, .sleep: return true
        default: return false
        }
    }

    /// The text of the confirm box, for the actions that have one.
    var confirmation: (question: String, button: String)? {
        switch self {
        case .logOut: return ("Log out of this Mac?", "Log Out")
        case .restart: return ("Restart this Mac?", "Restart")
        case .shutDown: return ("Shut down this Mac?", "Shut Down")
        default: return nil
        }
    }
}
