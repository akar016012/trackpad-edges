import AppKit
import Carbon.HIToolbox
import IOKit.hidsystem

/// The modifier keys that a shortcut can use, in the order that macOS shows them.
enum KeyModifier: CaseIterable {
    case control, option, shift, command, function

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        case .function: return "fn"
        }
    }

    var eventFlag: CGEventFlags {
        switch self {
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .shift: return .maskShift
        case .command: return .maskCommand
        case .function: return .maskSecondaryFn
        }
    }

    /// The bits that say which physical key is down. The system's event flags carry these
    /// alongside the general flag.
    private var sideBits: (left: UInt64, right: UInt64)? {
        switch self {
        case .control: return (UInt64(NX_DEVICELCTLKEYMASK), UInt64(NX_DEVICERCTLKEYMASK))
        case .shift: return (UInt64(NX_DEVICELSHIFTKEYMASK), UInt64(NX_DEVICERSHIFTKEYMASK))
        case .command: return (UInt64(NX_DEVICELCMDKEYMASK), UInt64(NX_DEVICERCMDKEYMASK))
        case .option: return (UInt64(NX_DEVICELALTKEYMASK), UInt64(NX_DEVICERALTKEYMASK))
        case .function: return nil
        }
    }

    private func isRight(in flags: UInt64) -> Bool {
        guard let sideBits else { return false }
        return flags & sideBits.right != 0 && flags & sideBits.left == 0
    }

    /// The key code of the modifier itself, for a shortcut that is only a modifier. It uses the
    /// left key unless the flags say the right one.
    func keyCode(in flags: UInt64) -> UInt16 {
        let right = isRight(in: flags)
        switch self {
        case .control: return UInt16(right ? kVK_RightControl : kVK_Control)
        case .option: return UInt16(right ? kVK_RightOption : kVK_Option)
        case .shift: return UInt16(right ? kVK_RightShift : kVK_Shift)
        case .command: return UInt16(right ? kVK_RightCommand : kVK_Command)
        case .function: return UInt16(kVK_Function)
        }
    }

    /// Keeps only the modifier flags, including which side is down, and names them for display.
    static func parts(of flags: CGEventFlags) -> (flags: UInt64, symbols: String) {
        let held = allCases.filter { flags.contains($0.eventFlag) }
        var raw = held.reduce(CGEventFlags()) { $0.union($1.eventFlag) }.rawValue
        var names: [String] = []
        for modifier in held {
            guard let sides = modifier.sideBits else {
                names.append(modifier.symbol)
                continue
            }
            let chosen = flags.rawValue & (sides.left | sides.right)
            raw |= chosen
            let side = modifier.isRight(in: chosen) ? "Right" : "Left"
            names.append("\(side) \(modifier.symbol)")
        }
        return (raw, names.joined(separator: " "))
    }
}

/// A button that records the next key combination you press, or modifiers on their own.
///
/// macOS handles shortcuts such as Command-Space and Command-Tab before an app can see them, so
/// recording uses an event tap at the hardware level, which sees every key first. The tap holds
/// keys back only while recording, so that the shortcut being recorded does not also run.
final class KeyRecorderButton: NSButton {
    /// Reports a key, or nil for a shortcut that is only modifiers.
    var onRecord: ((_ keyCode: UInt16?, _ modifiers: UInt64, _ label: String) -> Void)?

    fileprivate static weak var recording: KeyRecorderButton?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var resignObserver: NSObjectProtocol?
    private var restingTitle = "Record Shortcut"
    private var peakFlags = CGEventFlags()
    private var startFlags: UInt64 = 0

    /// Shows the recorded shortcut, or the prompt if the label is empty.
    func show(label: String) {
        restingTitle = label.isEmpty ? "Record Shortcut" : label
        title = restingTitle
    }

    func startRecording() {
        guard tap == nil else { return }
        // Only one recorder can run, because the tap callback serves one at a time.
        Self.recording?.stopRecording()
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << CGEventMask($1.rawValue)) }
        guard
            let port = CGEvent.tapCreate(
                tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask, callback: recorderTapCallback, userInfo: nil),
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        else {
            title = "Needs Accessibility"
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        tap = port
        source = runLoopSource
        Self.recording = self
        peakFlags = []
        // A modifier that is already down when recording starts is not part of the shortcut.
        startFlags = KeyModifier.parts(of: CGEventSource.flagsState(.hidSystemState)).flags
        title = "Press Keys…"
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.stopRecording() }
        }
    }

    /// A tap that outlives this button would hold back every key on the Mac.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil { stopRecording() }
    }

    private func stopRecording() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        self.tap = nil
        source = nil
        resignObserver = nil
        if Self.recording === self { Self.recording = nil }
        title = restingTitle
    }

    /// Returns nil to hold the event back from macOS.
    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // A corner action can post keys during recording, and those are not the user's.
        guard event.getIntegerValueField(.eventSourceUserData) != ClickTap.ownEventMarker else {
            return Unmanaged.passUnretained(event)
        }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            stopRecording()
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            modifiersChanged(event)
        case .keyDown:
            finish(event)
        default:
            break
        }
        return nil
    }

    /// Releasing every modifier with no other key records those modifiers alone.
    private func modifiersChanged(_ event: CGEvent) {
        let held = KeyModifier.parts(of: event.flags)
        startFlags &= held.flags
        peakFlags.formUnion(CGEventFlags(rawValue: held.flags & ~startFlags))
        guard held.flags == 0 else {
            title = held.symbols + "…"
            return
        }
        // Keys such as Caps Lock also report here with no modifier, so recording carries on.
        let peak = KeyModifier.parts(of: peakFlags)
        guard peak.flags != 0 else {
            title = "Press Keys…"
            return
        }
        stopRecording()
        show(label: peak.symbols)
        onRecord?(nil, peak.flags, peak.symbols)
    }

    private func finish(_ event: CGEvent) {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        stopRecording()
        guard Int(keyCode) != kVK_Escape else { return }
        var flags = event.flags
        // Function and arrow keys always report the fn flag, whether or not fn is held.
        if Self.alwaysReportsFn(keyCode) { flags.remove(.maskSecondaryFn) }
        let held = KeyModifier.parts(of: flags)
        let name = Self.name(of: event, keyCode: keyCode)
        let label = held.symbols.isEmpty ? name : "\(held.symbols) \(name)"
        show(label: label)
        onRecord?(keyCode, held.flags, label)
    }

    private static func alwaysReportsFn(_ keyCode: UInt16) -> Bool {
        // Codes 96 to 126 hold F1 to F16, the arrows, and keys such as Home and Page Up.
        (96...126).contains(Int(keyCode))
    }

    private static let namedKeys: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_Tab: "Tab", kVK_Delete: "Delete",
        kVK_ForwardDelete: "Forward Delete", kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "Home", kVK_End: "End",
        kVK_PageUp: "Page Up", kVK_PageDown: "Page Down", kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3",
        kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9",
        kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func name(of event: CGEvent, keyCode: UInt16) -> String {
        if let name = namedKeys[Int(keyCode)] { return name }
        let characters = NSEvent(cgEvent: event)?.charactersIgnoringModifiers?.uppercased() ?? ""
        // AppKit gives function and arrow keys private-use characters from U+F700 up.
        let isPrintable = characters.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value < 0xF700 }
        return !characters.isEmpty && isPrintable ? characters : "Key \(keyCode)"
    }
}

/// The tap's run loop source is on the main run loop, so this always runs on the main thread.
private nonisolated func recorderTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    MainActor.assumeIsolated {
        guard let recorder = KeyRecorderButton.recording else {
            return Unmanaged.passUnretained(event)
        }
        return recorder.handle(type: type, event: event)
    }
}
