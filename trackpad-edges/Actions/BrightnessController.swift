import CoreGraphics
import Foundation

/**
 Changes brightness by pressing the brightness keys, which act on the built-in display unless
 something such as a monitor utility sends them to the display under the pointer.
 */
final class BrightnessController {
    private typealias GetBrightness =
        @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private let getBrightness: GetBrightness? = {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW),
            let symbol = dlsym(handle, "DisplayServicesGetBrightness")
        else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    /// The active built-in display, which is nil on a desktop Mac or a closed MacBook.
    var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.first { CGDisplayIsBuiltin($0) != 0 }
    }

    var isAvailable: Bool { builtInDisplay != nil }

    private var level: Float? {
        guard let display = builtInDisplay, let getBrightness else { return nil }
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    private var pointerIsOnBuiltIn: Bool {
        guard let display = builtInDisplay, let pointer = CGEvent(source: nil)?.location else {
            return false
        }
        return CGDisplayBounds(display).contains(pointer)
    }

    /**
     Moves one step and returns false if the level is already at a limit. The key is always
     pressed, because a limit on the built-in display may not be a limit where the key lands.
     */
    func step(up: Bool, fine: Bool) -> Bool {
        let reachedLimit = BrightnessLimit.isReached(
            level: level, up: up, pointerOnBuiltIn: pointerIsOnBuiltIn)
        MediaKeys.press(up ? MediaKeys.brightnessUp : MediaKeys.brightnessDown, fine: fine)
        return !reachedLimit
    }
}
