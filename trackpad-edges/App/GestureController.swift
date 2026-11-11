import AppKit
import OSLog

/// Connects trackpad input to gestures, and gestures to their actions.
final class GestureController {
    /// Touch data older than this cannot be trusted to describe a click.
    private static let staleFrameInterval: TimeInterval = 0.1
    /// A contact with no frames for this long counts as lifted, which starts the slide's grace period.
    private static let lostFingerInterval: TimeInterval = 0.25
    private static let healthCheckInterval: TimeInterval = 0.25
    private static let noticeDuration: TimeInterval = 3
    /// How long Start Screen Saver, Sleep Display, and Sleep wait after the press, so that the
    /// lifting finger does not wake the Mac again.
    private static let liftWait: TimeInterval = 0.5
    /// How many health checks pass between asking the system directly about the permission.
    private static let permissionProbeEvery = 4

    private let log = Logger(subsystem: "com.adityakar.trackpad-edges", category: "gestures")
    private let edgeActions = EdgeActions()
    private let corners = CornerActionRunner()
    private let seek = SeekController()
    private let haptics = HapticEngine()
    private let monitor = DeviceMonitor()
    private let watchdog = TapWatchdog()
    private let failures = FailureNotifier()
    /// Ignores some power actions just after a wake or an unlock.
    private var powerGuard = PowerActionGuard()

    private var engines: [UnsafeRawPointer: GestureEngine] = [:]
    private var lastFrames: [UnsafeRawPointer: TimeInterval] = [:]
    private var clickDevice: UnsafeRawPointer?
    private var swallowedDown: CGEvent?
    private var discardNextUp = false
    private var activeSlide: SlideKind?
    private var reachedLimit = false
    private var locked = false
    private var healthTimer: Timer?
    private var healthChecks = 0
    /// Keeps the system from delaying the timers that protect clicks while the app has no window.
    private var latencyActivity: NSObjectProtocol?
    /// The trackpads with a check already on its way for the end of a slide's grace period.
    private var pendingTicks: Set<UnsafeRawPointer> = []
    /// The trackpads with a check already on its way for the end of a resting finger's wait.
    private var pendingRestTicks: Set<UnsafeRawPointer> = []
    /// Whether the last health check already saw the button up during a swallowed click.
    private var sawButtonUp = false
    /// The availability that the engines last received.
    private var appliedUnavailable: Set<SlideKind> = []
    /// The touch recording in progress, with the time it began and what receives the result.
    private var recording: (data: TouchRecording, start: TimeInterval)?
    private var onRecordingFinished: ((TouchRecording) -> Void)?

    private(set) var trackpadCount = 0
    /// Receives every touch frame, so that the window can show fingers live.
    var onTouches: (([TouchPoint]) -> Void)?
    /// Runs on each step of a slide, which is how the tour knows that you made one.
    var onSlideStep: (() -> Void)?
    /// Runs when an edge action becomes available or stops being available.
    var onAvailabilityChanged: (() -> Void)?
    /// Runs when a command starts or ends, so that the Stop buttons can follow.
    var onCommandsChanged: (() -> Void)?
    /// The app in front, which decides the profile.
    private var frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    /// Whether the user has paused all gestures from the menu.
    var paused = false {
        didSet { if paused { abortAll() } }
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func start() {
        let bridge = MultitouchBridge.shared
        bridge.onFrame = { [weak self] device, touches in
            self?.record(device: device, touches: touches)
            self?.handle(device: device, touches: touches)
        }
        trackpadCount = bridge.start()

        ClickTap.shared.onMouseDown = { [weak self] event in self?.mouseDown(event) ?? false }
        ClickTap.shared.onMouseUp = { [weak self] event, proxy in
            self?.mouseUp(event, proxy: proxy) ?? false
        }

        edgeActions.onAvailabilityChanged = { [weak self] in
            self?.applySettings()
            self?.onAvailabilityChanged?()
        }
        monitor.onDevicesChanged = { [weak self] in self?.rebuildDevices() }
        corners.showNotice = { [weak self] title, detail in
            self?.seek.showNotice(title: title, detail: detail, for: Self.noticeDuration)
        }
        failures.showNotice = { [weak self] title, detail, duration in
            self?.seek.showNotice(title: title, detail: detail, for: duration)
        }
        failures.install()
        corners.commands.reportFailure = { [weak self] corner, title, summary, body in
            self?.failures.report(corner: corner, title: title, summary: summary, body: body)
        }
        corners.commands.onChange = { [weak self] in self?.onCommandsChanged?() }
        monitor.start()
        observeLocking()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(frontAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // The front app can change during launch, before the observer above exists.
        frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        applySettings()

        let timer = Timer(timeInterval: Self.healthCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkHealth() }
        }
        RunLoop.main.add(timer, forMode: .common)
        healthTimer = timer
        latencyActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Trackpad gestures must answer every click at once.")
        watchdog.start()
        checkHealth()
        #if DEBUG
            // Launching with `-debugOverlay frosted -debugDark YES` shows that style for inspection.
            let defaults = UserDefaults.standard
            // Launching with `-debugNotice YES` shows the bright room notice for inspection.
            if defaults.bool(forKey: "debugNotice") { showBrightRoomNotice(for: 30) }
            // Launching with `-debugConfirm YES` shows the confirm box, and confirming it only
            // shows a notice, so that the box can be tried without a trackpad.
            if defaults.bool(forKey: "debugConfirm") {
                let panel = ConfirmationPanel(
                    question: "Restart this Mac?", detail: "The top-left corner asked for this.",
                    actionTitle: "Restart")
                panel.onFinish = { [weak self, panel] confirmed in
                    _ = panel
                    self?.seek.showNotice(
                        title: confirmed ? "Confirmed" : "Canceled", detail: "Nothing was sent.",
                        for: Self.noticeDuration)
                }
                panel.present()
            }
            // Launching with `-debugCommand 'some command'` runs it as the top-left corner would.
            if let script = defaults.string(forKey: "debugCommand") {
                corners.commands.run(script, corner: .topLeft)
            }
            // Adding `-debugStopAfter 3` stops every command after that many seconds, as the
            // Stop button would.
            if defaults.object(forKey: "debugStopAfter") != nil {
                let delay = defaults.double(forKey: "debugStopAfter")
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.stopAllCommands()
                }
            }
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
        // A command that kept running after the app quit could not be stopped from the app, and
        // the next press would start a second copy.
        corners.commands.stopAllForQuit()
        watchdog.stop()
        abortAll()
        ClickTap.shared.uninstall()
        PointerFreeze.shared.uninstall()
        MultitouchBridge.shared.stop()
    }

    func applySettings() {
        let settings = SettingsStore.shared.settings
        haptics.settings = settings.haptics
        seek.step = settings.seekStep
        seek.sensitivity = settings.sensitivity
        seek.applyOverlay(style: settings.overlayStyle, placement: settings.overlayPlacement)
        appliedUnavailable = unavailableKinds
        let config = currentConfig()
        for device in engines.keys { engines[device]?.config = config }
    }

    /// The edge actions that cannot work right now.
    var unavailableKinds: Set<SlideKind> {
        var kinds = edgeActions.unavailable
        if !seek.isAvailable { kinds.insert(.seek) }
        return kinds
    }

    /// The name of the profile in use, for the menu bar item.
    var activeProfileName: String {
        SettingsStore.shared.settings.profile(for: frontBundleID)?.name ?? "All Apps"
    }

    /// The settings as the app in front sees them.
    private var effectiveSettings: AppSettings {
        SettingsStore.shared.settings.resolved(for: frontBundleID)
    }

    /// Uses the availability that `applySettings` last recorded, so that an engine made later
    /// matches the others. A gesture in progress keeps its action, because the engine holds it
    /// until the gesture ends.
    private func currentConfig() -> GestureConfig {
        effectiveSettings.gestureConfig(unavailable: appliedUnavailable)
    }

    /// Shows a sample of the seek preview, so that a style can be judged as it is chosen.
    func previewSeekOverlay() {
        seek.showSample()
    }

    /// Fires one haptic with the current settings.
    func testHaptic() {
        let devices = MultitouchBridge.shared.devices
        guard
            let device = devices.first(where: { haptics.hasActuator(device: $0) }) ?? devices.first
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

    // MARK: Diagnostics

    /// Gathers the facts for a bug report. Nothing here is sent anywhere.
    var diagnosticsReport: DiagnosticsReport {
        let info = Bundle.main.infoDictionary
        return DiagnosticsReport(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: info?["CFBundleVersion"] as? String ?? "unknown",
            systemVersion: Self.systemVersion,
            macModel: Self.systemValue("hw.model"), trackpads: MultitouchBridge.shared.deviceInfo,
            accessibilityGranted: AXIsProcessTrusted(),
            clickWatchingOn: ClickTap.shared.isInstalled, gesturesPaused: paused,
            mediaAdapterLoaded: seek.isAvailable, unavailable: unavailableKinds,
            settings: SettingsStore.shared.settings,
            lockUsesSystemCall: corners.system.lockUsesSystemCall,
            darkModeUsesSystemCall: corners.system.darkModeUsesSystemCall,
            doNotDisturbKeySet: SystemActionRunner.doNotDisturbKey != nil)
    }

    // MARK: Commands

    /// The commands that are running now, by their text.
    var runningCommands: Set<String> { corners.commands.runningScripts }

    func stopCommand(_ script: String) {
        corners.commands.stop(script)
    }

    func stopAllCommands() {
        corners.commands.stopAll()
    }

    /// Asks once for permission to report failed commands in a notification.
    func requestNotificationPermission() {
        failures.requestPermissionIfNeeded()
    }

    /// The macOS version as plain numbers with the build, such as `27.2.0 (26B123)`. The
    /// system's own description is translated, which would make a report harder to read.
    private static var systemVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion) "
            + "(\(systemValue("kern.osversion")))"
    }

    /// Reads one of the system's text values. `hw.model` is the model identifier, such as
    /// `MacBookPro18,1`, which names the hardware and not its owner.
    private static func systemValue(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "unknown" }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return "unknown" }
        return String(cString: buffer)
    }

    /// Copies the raw touch frames of every trackpad for a fixed time, and then hands them back.
    /// Gestures keep working meanwhile, so the recording shows the problem as it happens.
    func recordTouches(completion: @escaping (TouchRecording) -> Void) {
        // A recording that is still running ends here, so that whoever asked for it hears back
        // and the new one gets its full time.
        finishRecording()
        let start = now
        recording = (TouchRecording(trackpads: MultitouchBridge.shared.deviceInfo), start)
        onRecordingFinished = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + TouchRecording.duration) { [weak self] in
            // A recording that ended early must not let this timer end the one after it.
            guard self?.recording?.start == start else { return }
            self?.finishRecording()
        }
    }

    private func record(device: UnsafeRawPointer, touches: [TouchPoint]) {
        guard let start = recording?.start,
            let index = MultitouchBridge.shared.devices.firstIndex(of: device)
        else { return }
        recording?.data.add(touches, trackpad: index, at: now - start)
    }

    private func finishRecording() {
        guard let finished = recording?.data else { return }
        recording = nil
        let completion = onRecordingFinished
        onRecordingFinished = nil
        completion?(finished)
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
        scheduleTickIfAwaitingLift(device: device)
        scheduleTickIfResting(device: device)
    }

    /// Lets one trackpad's engine act on whatever it was waiting for.
    private func runTick(device: UnsafeRawPointer) {
        guard var engine = engines[device] else { return }
        let events = engine.tick(now: now)
        engines[device] = engine
        dispatch(events, device: device)
    }

    /// Checks back once a corner's click window has closed, because no event marks that moment.
    private func scheduleCornerTick(device: UnsafeRawPointer) {
        let delay = engines[device]?.config.multiClickWindow ?? 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.02) { [weak self] in
            self?.runTick(device: device)
        }
    }

    /// Checks back when a resting finger's wait ends. Frames normally keep arriving while a
    /// finger is down, so this only makes sure that the pointer comes back on time. It has its
    /// own list of checks, so that it can never hold up the one for a slide's grace period.
    private func scheduleTickIfResting(device: UnsafeRawPointer) {
        guard let remaining = engines[device]?.restReleaseRemaining(now: now),
            pendingRestTicks.insert(device).inserted
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining + 0.02) { [weak self] in
            guard let self else { return }
            self.pendingRestTicks.remove(device)
            self.runTick(device: device)
            // A new finger can land while a check is on its way, and its wait ends later.
            self.scheduleTickIfResting(device: device)
        }
    }

    /// Checks back after the grace period, because no more frames arrive once a finger lifts.
    /// Each trackpad has its own check. Contact can drop out, return, and leave for good while a
    /// check is on its way, and that check then comes too early, so it sets up the next one.
    private func scheduleTickIfAwaitingLift(device: UnsafeRawPointer) {
        guard let remaining = engines[device]?.liftGraceRemaining(now: now),
            pendingTicks.insert(device).inserted
        else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining + 0.02) { [weak self] in
            guard let self else { return }
            self.pendingTicks.remove(device)
            self.runTick(device: device)
            self.scheduleTickIfAwaitingLift(device: device)
        }
    }

    private func mouseDown(_ event: CGEvent) -> Bool {
        discardNextUp = false
        sawButtonUp = false
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
                edgeActions.begin(kind)
                PointerFreeze.shared.begin()
                haptics.begin(device: device)
            case .stepped(let steps):
                applySteps(steps)
                onSlideStep?()
            case .seekMoved(let travel):
                onSlideStep?()
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
                scheduleCornerTick(device: device)
            case .cornerFired(let zone, let clicks):
                fireCorner(zone, clicks: clicks, device: device, confirm: true)
            case .cornerSettled(let zone, let clicks):
                fireCorner(zone, clicks: clicks, device: device, confirm: false)
            }
        }
    }

    private func applySteps(_ steps: Int) {
        let settings = SettingsStore.shared.settings.haptics
        let modifiers = NSEvent.modifierFlags
        let fine = modifiers.contains(.shift) && modifiers.contains(.option)
        guard let kind = activeSlide else { return }
        for _ in 0..<abs(steps) {
            if edgeActions.step(kind, up: steps > 0, fine: fine) {
                reachedLimit = false
                if settings.onStep { haptics.fire() }
            } else if !reachedLimit {
                reachedLimit = true
                if settings.onLimit { haptics.fire() }
                if kind == .keyboardBacklight, edgeActions.keyboardBacklightIsLocked {
                    showBrightRoomNotice(for: Self.noticeDuration)
                }
            }
        }
    }

    /// Explains a slider that will not move, which would otherwise look like a fault in this app.
    private func showBrightRoomNotice(for duration: TimeInterval) {
        seek.showNotice(
            title: "Keyboard Light Is Off", detail: "macOS turns it off when the room is bright.",
            for: duration)
    }

    /// Runs after the tap callback returns, because an action can take long enough to stall input.
    private func fireCorner(
        _ zone: Zone, clicks: Int, device: UnsafeRawPointer, confirm: Bool
    ) {
        let settings = effectiveSettings
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if confirm, settings.haptics.onCorner,
                MultitouchBridge.shared.devices.contains(device)
            {
                self.haptics.pulse(device: device)
            }
            guard let slot = CornerSlot(zone: zone), let corner = settings.corner(for: zone)
            else { return }
            let action = corner[clicks]
            if case .system(let system) = action {
                guard self.powerGuard.allows(system, at: self.now) else {
                    self.log.debug("Corner: ignored a power action just after a wake")
                    return
                }
                if system.waitsForLift {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Self.liftWait) { [weak self] in
                        self?.corners.run(action, corner: slot)
                    }
                    return
                }
            }
            self.corners.run(action, corner: slot)
        }
    }

    // MARK: Reliability

    /// Keeps the taps in step with the permission, and clears state that lost its finger or click.
    private func checkHealth() {
        let ports = [ClickTap.shared.port, PointerFreeze.shared.port].compactMap { $0 }
        if watchdog.beat(ports: ports) {
            // Clicks bypassed the taps during the stall, so nothing held from before is valid.
            abortAll()
            discardNextUp = false
        }
        healthChecks += 1
        let shouldProbe =
            ClickTap.shared.isInstalled && healthChecks % Self.permissionProbeEvery == 0
        // The second look stops one failed probe from ending a gesture for nothing.
        if AXIsProcessTrusted(), !shouldProbe || ClickTap.isAllowed || ClickTap.isAllowed {
            ClickTap.shared.refresh()
        } else if ClickTap.shared.isInstalled {
            abortAll()
            discardNextUp = false
            ClickTap.shared.uninstall()
            PointerFreeze.shared.uninstall()
            watchdog.beat(ports: [])
        }
        if let device = clickDevice, !CGEventSource.buttonState(.hidSystemState, button: .left) {
            // The button reads as up a moment before its mouse-up reaches the tap, so one look
            // could take a click that is about to end normally for a lost one, and drop it.
            if sawButtonUp {
                sawButtonUp = false
                recoverLostMouseUp(device: device)
                // The real mouse-up may still be on its way, and no app saw this click's
                // mouse-down.
                discardNextUp = true
            } else {
                sawButtonUp = true
            }
        } else {
            sawButtonUp = false
        }
        for device in Array(engines.keys) {
            guard let engine = engines[device],
                engine.hasTouches || engine.isSliding || engine.isDraining,
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
        // The trackpads are about to be listed afresh, so a recording could not tell them apart.
        finishRecording()
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
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspace.addObserver(self, selector: #selector(didWake), name: name, object: nil)
        }
    }

    @objc private func didWake() {
        powerGuard.recordWake(at: now)
    }

    @objc private func screenLocked() {
        locked = true
        abortAll()
    }

    @objc private func screenUnlocked() {
        locked = false
        powerGuard.recordWake(at: now)
        frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        applySettings()
    }

    @objc private func frontAppChanged(_ notification: Notification) {
        let app =
            notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        let wasUsing = SettingsStore.shared.settings.profile(for: frontBundleID)
        frontBundleID = app?.bundleIdentifier
        // Most apps have no profile, so this usually has nothing to change.
        let profileChanged = wasUsing != SettingsStore.shared.settings.profile(for: frontBundleID)
        // Some availability changes send no notice, such as the Spaces shortcuts being turned on
        // in System Settings. Leaving System Settings brings another app to the front, so this
        // is when the app looks.
        let availabilityChanged = unavailableKinds != appliedUnavailable
        if profileChanged || availabilityChanged { applySettings() }
        if availabilityChanged { onAvailabilityChanged?() }
    }

    @objc private func displayOptionsChanged() {
        seek.applyChosenStyle()
    }

    @objc private func screensChanged() {
        edgeActions.refreshDisplays()
        applySettings()
    }
}
