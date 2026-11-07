import CoreGraphics
import Foundation
import OSLog

/// Keeps clicks flowing when the main thread stalls.
///
/// The taps run on the main thread, and every click on this Mac waits for them. If that thread
/// stops answering, this turns the taps off from a background queue, so that clicks go straight to
/// other apps, and it reattaches the pointer in case a slide had frozen it. When the main thread
/// recovers, the health check ends any gesture and turns the click tap back on. This cannot help
/// while a debugger has paused the app, because that stops every thread.
nonisolated final class TapWatchdog: @unchecked Sendable {
    private static let checkInterval: TimeInterval = 0.2

    private let log = Logger(subsystem: "com.adityakar.trackpad-edges", category: "taps")
    private let queue = DispatchQueue(label: "tap-watchdog", qos: .userInteractive)
    private let lock = NSLock()
    private var detector = StallDetector(now: ProcessInfo.processInfo.systemUptime)
    private var ports: [CFMachPort] = []
    private var timer: DispatchSourceTimer?

    func start() {
        // Launch can take longer than the limit, and that is not a stall.
        lock.lock()
        detector = StallDetector(now: ProcessInfo.processInfo.systemUptime)
        lock.unlock()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: Self.checkInterval)
        timer.setEventHandler { [weak self] in self?.check() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Tells the watchdog that the main thread is healthy and which taps to protect, and returns
    /// true if this ends a stall.
    @discardableResult
    func beat(ports: [CFMachPort]) -> Bool {
        lock.lock()
        self.ports = ports
        let recovered = detector.beat(now: ProcessInfo.processInfo.systemUptime)
        lock.unlock()
        if recovered { log.notice("The main thread recovered, so the taps can run again.") }
        return recovered
    }

    private func check() {
        lock.lock()
        let stalled = detector.check(now: ProcessInfo.processInfo.systemUptime)
        let current = ports
        lock.unlock()
        guard stalled else { return }
        log.error("The main thread stalled, so the taps are off until it recovers.")
        for port in current { CGEvent.tapEnable(tap: port, enable: false) }
        CGAssociateMouseAndMouseCursorPosition(1)
    }
}
