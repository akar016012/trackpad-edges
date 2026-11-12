import AppKit

extension NSApplication {
    /**
     Brings the app in front of other apps. macOS 14 replaced the call that macOS 13 needs, and
     the app still supports macOS 13.
     */
    func bringForward() {
        if #available(macOS 14.0, *) {
            activate()
        } else {
            activate(ignoringOtherApps: true)
        }
    }
}
