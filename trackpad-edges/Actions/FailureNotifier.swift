import AppKit
import UserNotifications

/// Reports a command that failed. It uses a notification when you allow them, and the app's own
/// overlay notice otherwise.
///
/// Each corner has one notification, so that a new failure replaces the old one.
final class FailureNotifier: NSObject, UNUserNotificationCenterDelegate {
    /// How long the overlay notice stays when notifications are not allowed.
    private static let noticeDuration: TimeInterval = 5

    /// Shows the overlay notice, with a title and a sentence.
    var showNotice: ((String, String, TimeInterval) -> Void)?

    private var center: UNUserNotificationCenter { .current() }

    /// Makes notifications show even while the app's window is in front.
    func install() {
        center.delegate = self
    }

    /// Asks once for permission to show notifications. The app asks when you first enter a
    /// command, because that is the moment when the reason is clear.
    func requestPermissionIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    /// Reports one failure. A notification shows the body, and the overlay notice, which holds one
    /// short line, shows the summary.
    func report(corner: CornerSlot, title: String, summary: String, body: String) {
        center.getNotificationSettings { [weak self] settings in
            let allowed =
                settings.authorizationStatus == .authorized
                && settings.alertSetting == .enabled
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.deliver(
                        corner: corner, title: title, summary: summary, body: body,
                        allowed: allowed)
                }
            }
        }
    }

    private func deliver(
        corner: CornerSlot, title: String, summary: String, body: String, allowed: Bool
    ) {
        guard allowed else {
            showNotice?(title, summary, Self.noticeDuration)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: "command-\(corner.rawValue)", content: content, trigger: nil)
        center.add(request) { [weak self] error in
            guard error != nil else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.showNotice?(title, summary, Self.noticeDuration)
                }
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
