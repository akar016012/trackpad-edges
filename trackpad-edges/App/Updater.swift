import AppKit
import Security
import Sparkle

/**
 Owns the app's automatic updates. `Config/Info.plist` holds the feed, the public key, and the
 check interval of 24 hours. A check is due at launch once a day has passed since the last one,
 and again every day while the app runs.
 */
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    /**
     Accepts only this project's Developer ID. A copy built with any other identity must not
     offer to replace itself with the official app, because that would discard its changes.
     */
    private static let officialRequirement =
        "anchor apple generic and certificate leaf[subject.OU] = \"3J6QGH6H9F\" "
        // These fields mark Apple's Developer ID intermediate and a Developer ID Application leaf.
        + "and certificate 1[field.1.2.840.113635.100.6.2.6] exists "
        + "and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

    /// Called when an update session ends, so that the app can leave the Dock if no window is open.
    var onSessionEnded: (() -> Void)?
    /// False in a copy that is not signed with this project's Developer ID.
    let isAvailable = Updater.isOfficialBuild
    /**
     True from the moment an update is shown until its session ends. The app keeps its Dock icon
     during that time, so that an update window can always be reached.
     */
    private(set) var isInSession = false

    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: isAvailable, updaterDelegate: nil, userDriverDelegate: self)
    }

    /// False while a check or an update is already in progress.
    var canCheckForUpdates: Bool {
        isAvailable && (controller?.updater.canCheckForUpdates ?? false)
    }

    var checksAutomatically: Bool {
        get { isAvailable && (controller?.updater.automaticallyChecksForUpdates ?? false) }
        set {
            // Every copy shares one settings domain, so another build must not change this.
            guard isAvailable else { return }
            controller?.updater.automaticallyChecksForUpdates = newValue
        }
    }

    func checkForUpdates() {
        // An app without a Dock icon otherwise opens the update window behind the front app.
        NSApp.bringForward()
        controller?.checkForUpdates(nil)
    }

    private static var isOfficialBuild: Bool {
        var code: SecCode?
        var requirement: SecRequirement?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
            SecRequirementCreateWithString(officialRequirement as CFString, [], &requirement)
                == errSecSuccess,
            let requirement
        else { return false }
        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    // MARK: SPUStandardUserDriverDelegate

    /* The app lives in the menu bar, so an update found by a scheduled check could open behind
       other windows and go unnoticed. While the update window is up, the app has a Dock icon that
       bounces once. */

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        MainActor.assumeIsolated {
            isInSession = true
            _ = NSApp.setActivationPolicy(.regular)
            if !state.userInitiated {
                NSApp.requestUserAttention(.informationalRequest)
            }
        }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated {
            isInSession = false
            onSessionEnded?()
        }
    }
}
