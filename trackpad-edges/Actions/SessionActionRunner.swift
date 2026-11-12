import AppKit
import CoreServices

/// Logs out, restarts, or shuts down after you confirm. The event codes are private to this file,
/// and `confirm` is the only way in, so nothing can skip the confirm box.
final class SessionActionRunner {
    nonisolated private static let loginWindow = "com.apple.loginwindow"

    private let events: AppleEventSender
    private var panel: ConfirmationPanel?
    /// Shows a notice with a title and a detail line.
    var showNotice: ((String, String) -> Void)?

    init(events: AppleEventSender) {
        self.events = events
    }

    /// Whether the confirm box is open.
    var isAsking: Bool { panel != nil }

    /// Shows the confirm box. A press while it is open is ignored, so a corner cannot answer it.
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
                // An app with unsaved work may still be asking about it.
                break
            case .failed(let code):
                self?.showNotice?(
                    "macOS Refused the Request", "The request failed with error \(code).")
            }
        }
    }
}
