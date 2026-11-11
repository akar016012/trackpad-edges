import AppKit
import CoreServices

/// Logs out, restarts, or shuts down the Mac, and only after you confirm it.
///
/// The three event codes and the function that sends them are private to this file, and the only
/// way in is `confirm`, which shows the confirm box. No other code can reach those events, so no
/// later change can skip the box by mistake. After you confirm, the event goes straight to the
/// system, with no second dialog. Apps with unsaved work can still stop it, as they can when you
/// choose these from the Apple menu.
final class SessionActionRunner {
    nonisolated private static let loginWindow = "com.apple.loginwindow"

    private let events: AppleEventSender
    private var panel: ConfirmationPanel?
    /// Shows a short notice, with a title and a sentence that says what to do.
    var showNotice: ((String, String) -> Void)?

    init(events: AppleEventSender) {
        self.events = events
    }

    /// Whether the confirm box is open, which ignores further presses.
    var isAsking: Bool { panel != nil }

    /// Shows the confirm box for one of the three session actions. A press while the box is open
    /// is ignored, so that a corner can never answer it.
    func confirm(_ action: SystemAction, corner: CornerSlot) {
        guard panel == nil, let text = action.confirmation, let eventID = Self.eventID(for: action)
        else { return }
        let panel = ConfirmationPanel(
            question: text.question, detail: "\(corner.title) asked for this.",
            actionTitle: text.button)
        panel.onFinish = { [weak self] confirmed in
            self?.panel = nil
            if confirmed { self?.send(eventID) }
        }
        self.panel = panel
        panel.present()
    }

    private static func eventID(for action: SystemAction) -> AEEventID? {
        switch action {
        case .logOut: return AEEventID(kAEReallyLogOut)
        case .restart: return AEEventID(kAERestart)
        case .shutDown: return AEEventID(kAEShutDown)
        default: return nil
        }
    }

    private func send(_ eventID: AEEventID) {
        events.perform(target: Self.loginWindow) {
            _ = try AppleEventSender.send(
                eventClass: AEEventClass(kCoreEventClass), eventID: eventID, to: Self.loginWindow)
        } onFailure: { [weak self] failure in
            switch failure {
            case .notAllowed:
                self?.showNotice?(
                    "macOS Refused the Request", "Check Automation in Privacy & Security.")
            case .timedOut:
                // An app with unsaved work may still be asking you about it.
                break
            case .failed(let code):
                self?.showNotice?(
                    "macOS Refused the Request", "The request failed with error \(code).")
            }
        }
    }
}
