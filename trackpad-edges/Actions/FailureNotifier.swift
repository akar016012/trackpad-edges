import AppKit
import UserNotifications

/**
 Reports failed commands as notifications, or as an overlay notice when notifications are off.
 Each corner has one notification, so a new failure replaces the old one.
 */
final class FailureNotifier: NSObject, UNUserNotificationCenterDelegate {
    /// How long the fallback notice stays.
    private static let noticeDuration: TimeInterval = 5

    /// Shows the overlay notice.
    var showNotice: ((String, String, TimeInterval) -> Void)?

    private var center: UNUserNotificationCenter { .current() }

    /// Shows notifications even while the app is in front.
    func install() {
        center.delegate = self
    }

    /// Asks for notification permission once, when you first enter a command.
    func requestPermissionIfNeeded() {
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
    }

    /// A notification shows the body; the one-line overlay shows the summary.
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
