import CoreGraphics
import Foundation

/// Changes the built-in display's brightness by pressing the brightness keys.
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

    /// Moves one step and returns false if the level is already at a limit.
    func step(up: Bool, fine: Bool) -> Bool {
        if let level, up ? level >= 1 : level <= 0 { return false }
        MediaKeys.press(up ? MediaKeys.brightnessUp : MediaKeys.brightnessDown, fine: fine)
        return true
    }
}
