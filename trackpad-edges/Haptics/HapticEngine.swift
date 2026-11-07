import AppKit

/// Fires trackpad haptics through the private actuator API, which supports strength control.
/// It falls back to the public API when a device has no usable actuator.
final class HapticEngine {
    private typealias GetActuator = @convention(c) (UnsafeRawPointer) -> UnsafeRawPointer?
    private typealias Open = @convention(c) (UnsafeRawPointer, UInt32) -> Int32
    private typealias Close = @convention(c) (UnsafeRawPointer) -> Int32
    private typealias Actuate =
        @convention(c) (UnsafeRawPointer, Int32, UInt32, Float, Float) -> Int32

    private static let minimumInterval: TimeInterval = 0.03

    var settings = HapticSettings()

    private let getActuator: GetActuator? = MultitouchFramework.symbol("MTDeviceGetMTActuator")
    private let open: Open? = MultitouchFramework.symbol("MTActuatorOpen")
    private let close: Close? = MultitouchFramework.symbol("MTActuatorClose")
    private let actuate: Actuate? = MultitouchFramework.symbol("MTActuatorActuate")

    private var device: UnsafeRawPointer?
    private var actuator: UnsafeRawPointer?
    private var lastTick = Date.distantPast

    /// Names the trackpad for a gesture. The actuator stays closed until the first haptic, because
    /// opening it requests control of the trackpad's click, and a touch may turn out to be a click.
    func begin(device: UnsafeRawPointer) {
        self.device = device
    }

    private func openActuatorIfNeeded() {
        guard actuator == nil, let device, let candidate = getActuator?(device),
            open?(candidate, 0) == 0
        else { return }
        actuator = candidate
    }

    func fire() {
        guard settings.enabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastTick) >= Self.minimumInterval else { return }
        lastTick = now
        openActuatorIfNeeded()
        if let actuator,
            actuate?(actuator, settings.pattern.actuatorID, 0, settings.strength, 0) == 0
        {
            return
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    /// Fires one haptic outside a slide, such as when a corner action runs.
    func pulse(device: UnsafeRawPointer) {
        begin(device: device)
        fire()
        end()
    }

    func end() {
        if let actuator { _ = close?(actuator) }
        actuator = nil
        device = nil
    }
}
