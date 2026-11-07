import AppKit
import OSLog

/// Connects trackpad input to gestures, and gestures to their actions.
final class GestureController {
    /// Touch data older than this cannot be trusted to describe a click.
    private static let staleFrameInterval: TimeInterval = 0.1
    /// A contact with no frames for this long counts as lifted, which starts the slide's grace period.
    private static let lostFingerInterval: TimeInterval = 0.25
    private static let healthCheckInterval: TimeInterval = 0.25

    private let log = Logger(subsystem: "com.adityakar.trackpad-edges", category: "gestures")
    private let volume = VolumeController()
    private let brightness = BrightnessController()
    private let corners = CornerActionRunner()
    private let seek = SeekController()
    private let haptics = HapticEngine()
    private let monitor = DeviceMonitor()

    private var engines: [UnsafeRawPointer: GestureEngine] = [:]
    private var lastFrames: [UnsafeRawPointer: TimeInterval] = [:]
    private var clickDevice: UnsafeRawPointer?
    private var swallowedDown: CGEvent?
    private var discardNextUp = false
    private var activeSlide: SlideKind?
    private var reachedLimit = false
    private var locked = false
    private var healthTimer: Timer?
    private var tickScheduled = false

    private(set) var trackpadCount = 0
    /// Receives every touch frame, so that the window can show fingers live.
    var onTouches: (([TouchPoint]) -> Void)?
    /// Whether the user has paused all gestures from the menu.
    var paused = false {
        didSet { if paused { abortAll() } }
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func start() {
        let bridge = MultitouchBridge.shared
        bridge.onFrame = { [weak self] device, touches in
            self?.handle(device: device, touches: touches)
        }
        trackpadCount = bridge.start()

        ClickTap.shared.onMouseDown = { [weak self] event in self?.mouseDown(event) ?? false }
        ClickTap.shared.onMouseUp = { [weak self] event, proxy in
            self?.mouseUp(event, proxy: proxy) ?? false
        }

        monitor.onDevicesChanged = { [weak self] in self?.rebuildDevices() }
        monitor.start()
        observeLocking()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        applySettings()

        let timer = Timer(timeInterval: Self.healthCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
        RunLoop.main.add(timer, forMode: .common)
        healthTimer = timer
        checkHealth()
        #if DEBUG
            // Launching with `-debugOverlay frosted -debugDark YES` shows that style for inspection.
            let defaults = UserDefaults.standard
            if let name = defaults.string(forKey: "debugOverlay"),
                let style = OverlayStyle(rawValue: name)
            {
                let dark = defaults.object(forKey: "debugDark") != nil
                seek.debugShow(
                    style: style,
                    appearance: dark && defaults.bool(forKey: "debugDark") ? .darkAqua : .aqua,
                    backdrop: defaults.string(forKey: "debugBackdrop"))
            }
        #endif
    }

    func stop() {
        abortAll()
        ClickTap.shared.uninstall()
        PointerFreeze.shared.uninstall()
        MultitouchBridge.shared.stop()
    }

    func applySettings() {
        let settings = SettingsStore.shared.settings
        haptics.settings = settings.haptics
        seek.stepFraction = settings.seekStepPercent / 100
        seek.sensitivity = settings.sensitivity
        seek.applyOverlay(style: settings.overlayStyle, placement: settings.overlayPlacement)
        let config = currentConfig()
        for device in engines.keys { engines[device]?.config = config }
    }

    private func currentConfig() -> GestureConfig {
        SettingsStore.shared.settings.gestureConfig(
            brightnessAvailable: brightness.isAvailable, seekAvailable: seek.isAvailable)
    }

    /// Shows a sample of the seek preview, so that a style can be judged as it is chosen.
    func previewSeekOverlay() {
        seek.showSample()
    }

    /// Fires one haptic with the current settings.
    func testHaptic() {
        let devices = MultitouchBridge.shared.devices
        guard let device = devices.first(where: { haptics.hasActuator(device: $0) }) ?? devices.first
        else { return }
        haptics.pulse(device: device)
    }

    /// Describes what the connected trackpads can do, for the Haptics pane.
    var hapticStatus: String {
        let devices = MultitouchBridge.shared.devices
        if devices.isEmpty { return "No trackpad was found." }
        if devices.contains(where: { haptics.hasActuator(device: $0) }) {
            return "Strength and pattern control are available on this trackpad."
        }
        return
            "This trackpad has no haptic engine that the app can control, so the strength and pattern settings may have no effect."
    }

    private func newEngine() -> GestureEngine {
        var engine = GestureEngine()
        engine.config = currentConfig()
        return engine
    }

    // MARK: Input

    private func handle(device: UnsafeRawPointer, touches: [TouchPoint]) {
        onTouches?(touches)
        // A frame that was queued before a rebuild can name a device that no longer exists.
        // Without the click tap there is no permission to press keys, so a slide would do nothing.
        guard !paused, !locked, ClickTap.shared.isInstalled,
            MultitouchBridge.shared.devices.contains(device)
        else { return }
        lastFrames[device] = now
        var engine = engines[device] ?? newEngine()
        let required = SettingsStore.shared.settings.requiredModifier.flags
        let events = engine.process(
            touches, now: now, modifierSatisfied: NSEvent.modifierFlags.contains(required))
        engines[device] = engine
        dispatch(events, device: device)
        // This asks the engine, because a palm keeps frames arriving after the finger has lifted.
        if engine.isSliding, !engine.hasTouches, !tickScheduled {
            scheduleTick(device: device, grace: engine.config.liftGrace)
        }
    }

    /// Checks back after the grace period, because no more frames arrive once a finger lifts.
    private func scheduleTick(device: UnsafeRawPointer, grace: TimeInterval) {
        tickScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + grace + 0.02) { [weak self] in
            self?.tickScheduled = false
            guard let self, var engine = self.engines[device] else { return }
            let events = engine.tick(now: self.now)
            self.engines[device] = engine
            self.dispatch(events, device: device)
        }
    }

    private func mouseDown(_ event: CGEvent) -> Bool {
        discardNextUp = false
        guard !paused, !locked else { return false }
        if let device = clickDevice { recoverLostMouseUp(device: device) }

        let required = SettingsStore.shared.settings.requiredModifier.flags
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
        // A trackpad with a gesture in progress owns the click, so that only one is ever active.
        let busy = engines.keys.filter { engines[$0]?.isBusy == true }
        for device in busy.isEmpty ? Array(engines.keys) : busy {
            guard var engine = engines[device] else { continue }
            let age = now - (lastFrames[device] ?? 0)
            log.debug(
                "Click: touches \(engine.touchCount), landed \(engine.hasLanding), frame age \(age, format: .fixed(precision: 3))"
            )
            guard engine.isBusy || age <= Self.staleFrameInterval else { continue }
            let result = engine.mouseDown(now: now, modifierSatisfied: flags.contains(required))
            engines[device] = engine
            guard result.swallow else { continue }
            log.debug("Click: swallowed for a gesture")
            clickDevice = device
            swallowedDown = event.copy()
            dispatch(result.events, device: device)
            return true
        }
        return false
    }

    private func mouseUp(_ event: CGEvent, proxy: CGEventTapProxy) -> Bool {
        if discardNextUp {
            discardNextUp = false
            return true
        }
        guard let device = clickDevice, var engine = engines[device] else { return false }
        clickDevice = nil
        let result = engine.mouseUp(now: now)
        engines[device] = engine
        dispatch(result.events.filter { $0 != .passthroughClick }, device: device)
        if result.events.contains(.passthroughClick), let down = swallowedDown {
            // This posts the mouse-down ahead of the real mouse-up that the tap is returning.
            down.setIntegerValueField(.eventSourceUserData, value: ClickTap.ownEventMarker)
            down.tapPostEvent(proxy)
        }
        swallowedDown = nil
        return result.swallow
    }

    /// Delivers the held mouse-down now, and lets the real mouse-up pass through when it comes.
    private func deliverHeldClick() {
        if let down = swallowedDown {
            down.setIntegerValueField(.eventSourceUserData, value: ClickTap.ownEventMarker)
            down.post(tap: .cgSessionEventTap)
        }
        swallowedDown = nil
        clickDevice = nil
    }

    private func recoverLostMouseUp(device: UnsafeRawPointer) {
        log.debug("Click: recovering from a lost mouse-up")
        clickDevice = nil
        swallowedDown = nil
        guard var engine = engines[device] else { return }
        let events = engine.mouseUpLost()
        engines[device] = engine
        dispatch(events, device: device)
    }

    // MARK: Gesture events

    private func dispatch(_ events: [GestureEngine.Event], device: UnsafeRawPointer) {
        for event in events {
            switch event {
            case .slideBegan(let kind):
                activeSlide = kind
                reachedLimit = false
                PointerFreeze.shared.begin()
                haptics.begin(device: device)
            case .stepped(let steps):
                applySteps(steps)
            case .seekMoved(let travel):
                let tick = seek.preview(travel: travel)
                if tick, SettingsStore.shared.settings.haptics.onSeek { haptics.fire() }
            case .slideEnded(let kind):
                if kind == .seek { seek.commit() }
                activeSlide = nil
                haptics.end()
            case .slideCanceled(let kind):
                if kind == .seek { seek.cancel() }
                activeSlide = nil
                haptics.end()
            case .pointerReleased:
                PointerFreeze.shared.end()
            case .passthroughClick:
                deliverHeldClick()
            case .cornerCounted:
                if SettingsStore.shared.settings.haptics.onCorner { haptics.pulse(device: device) }
            case .cornerFired(let zone):
                fireCorner(zone, device: device)
            }
        }
    }

    private func applySteps(_ steps: Int) {
        let settings = SettingsStore.shared.settings.haptics
        let modifiers = NSEvent.modifierFlags
        let fine = modifiers.contains(.shift) && modifiers.contains(.option)
        for _ in 0..<abs(steps) {
            let moved: Bool
            switch activeSlide {
            case .volume: moved = volume.step(up: steps > 0, fine: fine)
            case .brightness: moved = brightness.step(up: steps > 0, fine: fine)
            case .seek, nil: return
            }
            if moved {
                reachedLimit = false
                if settings.onStep { haptics.fire() }
            } else if !reachedLimit {
                reachedLimit = true
                if settings.onLimit { haptics.fire() }
            }
        }
    }

    /// Runs after the tap callback returns, because an action can take long enough to stall input.
    private func fireCorner(_ zone: Zone, device: UnsafeRawPointer) {
        let settings = SettingsStore.shared.settings
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if settings.haptics.onCorner, MultitouchBridge.shared.devices.contains(device) {
                self.haptics.pulse(device: device)
            }
            if let corner = settings.corner(for: zone) { self.corners.run(corner.action) }
        }
    }

    // MARK: Reliability

    /// Keeps the taps in step with the permission, and clears state that lost its finger or click.
    private func checkHealth() {
        if AXIsProcessTrusted() {
            ClickTap.shared.refresh()
        } else if ClickTap.shared.isInstalled {
            abortAll()
            discardNextUp = false
            ClickTap.shared.uninstall()
            PointerFreeze.shared.uninstall()
        }
        if let device = clickDevice, !CGEventSource.buttonState(.hidSystemState, button: .left) {
            recoverLostMouseUp(device: device)
            // The real mouse-up may still be on its way, and no app saw this click's mouse-down.
            discardNextUp = true
        }
        for device in Array(engines.keys) {
            guard let engine = engines[device], engine.hasTouches || engine.isSliding,
                now - (lastFrames[device] ?? 0) > Self.lostFingerInterval
            else { continue }
            handle(device: device, touches: [])
        }
    }

    private func abortAll() {
        for device in Array(engines.keys) {
            guard var engine = engines[device] else { continue }
            let events = engine.abort()
            engines[device] = engine
            dispatch(events, device: device)
        }
        // Other apps never saw this click's mouse-down, so they must not see its mouse-up.
        if swallowedDown != nil { discardNextUp = true }
        clickDevice = nil
        swallowedDown = nil
    }

    private func rebuildDevices() {
        abortAll()
        haptics.end()
        engines = [:]
        lastFrames = [:]
        MultitouchBridge.shared.stop()
        trackpadCount = MultitouchBridge.shared.start()
        applySettings()
    }

    private func observeLocking() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self, selector: #selector(screenLocked),
            name: Notification.Name("com.apple.screenIsLocked"), object: nil)
        center.addObserver(
            self, selector: #selector(screenUnlocked),
            name: Notification.Name("com.apple.screenIsUnlocked"), object: nil)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(
            self, selector: #selector(screenLocked),
            name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        workspace.addObserver(
            self, selector: #selector(screenUnlocked),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    @objc private func screenLocked() {
        locked = true
        abortAll()
    }

    @objc private func screenUnlocked() {
        locked = false
    }

    @objc private func screensChanged() {
        applySettings()
    }
}
