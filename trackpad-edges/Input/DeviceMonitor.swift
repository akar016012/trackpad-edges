import AppKit
import IOKit

/// Reports when trackpads must be rebuilt: after one connects or disconnects, and after waking.
final class DeviceMonitor {
    private static let debounce: TimeInterval = 0.75
    private static let wakeDelay: TimeInterval = 2

    var onDevicesChanged: (() -> Void)?

    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var pendingRebuild: DispatchWorkItem?

    func start() {
        let port = IONotificationPortCreate(kIOMainPortDefault)
        self.port = port
        IONotificationPortSetDispatchQueue(port, .main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        for type in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let status = IOServiceAddMatchingNotification(
                port, type, IOServiceMatching("AppleMultitouchDevice"), deviceCallback, context,
                &iterator)
            guard status == KERN_SUCCESS else { continue }
            iterators.append(iterator)
            // The notification is armed only after the iterator has been drained once.
            Self.drain(iterator)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }

    fileprivate func deviceChanged() {
        scheduleRebuild(after: Self.debounce)
    }

    @objc private func didWake() {
        scheduleRebuild(after: Self.wakeDelay)
    }

    private func scheduleRebuild(after delay: TimeInterval) {
        pendingRebuild?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.onDevicesChanged?() }
        pendingRebuild = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    fileprivate nonisolated static func drain(_ iterator: io_iterator_t) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            IOObjectRelease(service)
        }
    }
}

/// The notification port uses the main queue, so this always runs on the main thread.
private nonisolated func deviceCallback(context: UnsafeMutableRawPointer?, iterator: io_iterator_t) {
    DeviceMonitor.drain(iterator)
    guard let context else { return }
    MainActor.assumeIsolated {
        Unmanaged<DeviceMonitor>.fromOpaque(context).takeUnretainedValue().deviceChanged()
    }
}
