import AppKit
import Carbon.HIToolbox

/// A button that records the next key combination you press.
final class KeyRecorderButton: NSButton {
    var onRecord: ((_ keyCode: UInt16, _ modifiers: UInt64, _ label: String) -> Void)?

    private var monitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var restingTitle = "Record Shortcut"

    /// Shows the recorded combination, or the prompt if the label is empty.
    func show(label: String) {
        restingTitle = label.isEmpty ? "Record Shortcut" : label
        title = restingTitle
    }

    func startRecording() {
        guard monitor == nil else { return }
        title = "Press a Shortcut…"
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            self.finish(event)
            return nil
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopRecording() }
        }
    }

    /// A monitor that outlives this button would swallow every key press in the app.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil { stopRecording() }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        title = restingTitle
    }

    private func finish(_ event: NSEvent) {
        stopRecording()
        guard Int(event.keyCode) != kVK_Escape else { return }

        var flags = CGEventFlags()
        var symbols = ""
        let modifiers = event.modifierFlags
        if modifiers.contains(.control) {
            flags.insert(.maskControl)
            symbols += "⌃"
        }
        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
            symbols += "⌥"
        }
        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
            symbols += "⇧"
        }
        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
            symbols += "⌘"
        }
        let label = symbols + Self.name(of: event)
        show(label: label)
        onRecord?(event.keyCode, flags.rawValue, label)
    }

    private static func name(of event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: break
        }
        let characters = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let isPrintable = characters.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value < 0xF700 }
        return !characters.isEmpty && isPrintable ? characters : "Key \(event.keyCode)"
    }
}
