import AppKit

/**
 Changes the keyboard backlight by pressing its media keys, which also shows the system slider.

 No public API can read the backlight, so this reads its state from the private CoreBrightness
 client. It never sets the level through that client, and without it the keys still work.
 */
final class KeyboardBacklightController {
    private typealias GetFloat = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias GetBool = @convention(c) (AnyObject, Selector, UInt64) -> Bool

    private static let brightnessSelector = NSSelectorFromString("brightnessForKeyboard:")
    private static let saturatedSelector = NSSelectorFromString("isBacklightSaturatedOnKeyboard:")
    private static let automaticSelector = NSSelectorFromString(
        "isAutoBrightnessEnabledForKeyboard:")
    private static let listSelector = NSSelectorFromString("copyKeyboardBacklightIDs")

    private let client: NSObject?
    /// This is looked up when it is needed, because it may not exist yet during an early launch.
    private var keyboard: UInt64?

    init() {
        let path = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
        guard dlopen(path, RTLD_NOW) != nil,
            let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
        else {
            client = nil
            return
        }
        let client = type.init()
        let selectors = [Self.brightnessSelector, Self.saturatedSelector, Self.listSelector]
        self.client = selectors.allSatisfy(client.responds(to:)) ? client : nil
    }

    private func currentKeyboard() -> UInt64? {
        if keyboard == nil, let client {
            let list = client.perform(Self.listSelector)?.takeRetainedValue() as? [NSNumber]
            keyboard = list?.first?.uint64Value
        }
        return keyboard
    }

    private func flag(_ selector: Selector, on client: NSObject, keyboard: UInt64) -> Bool {
        let get = unsafeBitCast(client.method(for: selector), to: GetBool.self)
        return get(client, selector, keyboard)
    }

    /// A failed read returns a negative level, which must not look like the bottom of the range.
    private var level: Float? {
        guard let client, let keyboard = currentKeyboard() else { return nil }
        let method = client.method(for: Self.brightnessSelector)
        let value = unsafeBitCast(method, to: GetFloat.self)(
            client, Self.brightnessSelector, keyboard)
        return value < 0 ? nil : value
    }

    /**
     Whether macOS is holding the backlight off because the room is bright. The sensor can stay
     saturated with automatic brightness off, and the keys are free to move the light then.
     */
    var isLocked: Bool {
        guard let client, let keyboard = currentKeyboard(),
            flag(Self.saturatedSelector, on: client, keyboard: keyboard)
        else { return false }
        guard client.responds(to: Self.automaticSelector) else { return true }
        return flag(Self.automaticSelector, on: client, keyboard: keyboard)
    }

    /**
     Moves one step, and returns false if nothing can change. The key is always pressed, because
     that is what shows the system slider, including when macOS has it locked.
     */
    func step(up: Bool, fine: Bool) -> Bool {
        let reachedLimit = BrightnessLimit.isKeyboardStopped(level: level, isLocked: isLocked, up: up)
        MediaKeys.press(up ? MediaKeys.illuminationUp : MediaKeys.illuminationDown, fine: fine)
        return !reachedLimit
    }
}
