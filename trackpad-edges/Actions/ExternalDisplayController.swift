import Foundation
import IOKit

/// Changes the brightness of external displays over DDC, the control channel in a display cable.
///
/// This uses private IOKit functions, because no public API can reach an external display's
/// brightness. Not every monitor or port answers, so a display counts only after it has answered a
/// read. All display traffic runs on one background queue, because each transfer blocks.
final class ExternalDisplayController {
    private static let stepSize = 6
    /// A display can appear a moment after the system reports the change, so this looks again.
    private static let secondLook: TimeInterval = 2

    private let queue = DispatchQueue(label: "ddc", qos: .userInitiated)
    private var displays: [ExternalDisplay] = []
    /// Runs when displays that answer come or go.
    var onAvailabilityChanged: (() -> Void)?

    init() {
        refresh()
    }

    var isAvailable: Bool { !displays.isEmpty }

    /// Finds the external displays that answer, which change as cables come and go.
    func refresh() {
        look()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.secondLook) { [weak self] in
            self?.look()
        }
    }

    private func look() {
        queue.async { [weak self] in
            let found = ExternalService.findAll().compactMap { service -> ExternalDisplay? in
                guard let reading = service.readBrightness() else { return nil }
                return ExternalDisplay(service: service, reading: reading)
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.publish(found) }
            }
        }
    }

    private func publish(_ found: [ExternalDisplay]) {
        let changed = found.count != displays.count
        displays = found
        if changed { onAvailabilityChanged?() }
    }

    /// Reads each display again, in case its own buttons changed it since the last slide.
    func readLevels() {
        for display in displays {
            let generation = display.generation
            queue.async {
                guard let reading = display.service.readBrightness() else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        // A step taken since this read began is newer than what it found.
                        if display.generation == generation { display.level = reading.percent }
                    }
                }
            }
        }
    }

    /// Moves one step, and returns false if every display is already at a limit.
    func step(up: Bool) -> Bool {
        var moved = false
        for display in displays {
            let next = min(max(display.level + (up ? Self.stepSize : -Self.stepSize), 0), 100)
            guard next != display.level else { continue }
            display.level = next
            display.generation += 1
            display.send(next, on: queue)
            moved = true
        }
        return moved
    }
}

extension DDCMessage.Reading {
    fileprivate nonisolated var percent: Int { current * 100 / maximum }
}

/// One display that answers, with the level that a slide moves from.
private nonisolated final class ExternalDisplay: @unchecked Sendable {
    let service: ExternalService
    private let maximum: Int
    private let lock = NSLock()
    private var pending: Int?
    private var isDraining = false

    /// These two change only on the main thread.
    var level: Int
    var generation = 0

    init(service: ExternalService, reading: DDCMessage.Reading) {
        self.service = service
        maximum = reading.maximum
        level = reading.percent
    }

    /// Keeps only the newest level, so that a fast slide cannot leave a backlog of writes.
    func send(_ percent: Int, on queue: DispatchQueue) {
        lock.lock()
        pending = percent
        let shouldStart = !isDraining
        isDraining = true
        lock.unlock()
        guard shouldStart else { return }
        queue.async { [self] in drain() }
    }

    private func drain() {
        while true {
            lock.lock()
            guard let percent = pending else {
                isDraining = false
                lock.unlock()
                return
            }
            pending = nil
            lock.unlock()
            service.writeBrightness(percent * maximum / 100)
        }
    }
}

/// One external display's control channel. Its calls block, so they run on a background queue.
private nonisolated final class ExternalService: @unchecked Sendable {
    private typealias CreateService =
        @convention(c) (CFAllocator?, io_service_t) -> Unmanaged<CFTypeRef>?
    private typealias TransferI2C =
        @convention(c) (CFTypeRef, UInt32, UInt32, UnsafeMutablePointer<UInt8>, UInt32) -> Int32

    /// The I2C address that DDC/CI assigns to a display.
    private static let chipAddress: UInt32 = 0x37
    /// The source address that DDC/CI expects at the start of each message from the host.
    private static let dataAddress: UInt32 = 0x51
    /// Monitors need this long between commands, and they ignore requests that come faster.
    private static let settleTime: useconds_t = 50_000
    private static let attempts = 3

    private static let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    private let service: CFTypeRef
    private let write: TransferI2C
    private let read: TransferI2C

    private init(service: CFTypeRef, write: TransferI2C, read: TransferI2C) {
        self.service = service
        self.write = write
        self.read = read
    }

    static func findAll() -> [ExternalService] {
        guard let create: CreateService = symbol("IOAVServiceCreateWithService"),
            let write: TransferI2C = symbol("IOAVServiceWriteI2C"),
            let read: TransferI2C = symbol("IOAVServiceReadI2C")
        else { return [] }
        var iterator: io_iterator_t = 0
        // This service exists only on Apple silicon, so an Intel Mac finds no displays.
        guard
            IOServiceGetMatchingServices(
                kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &iterator)
                == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }

        var found: [ExternalService] = []
        while case let entry = IOIteratorNext(iterator), entry != 0 {
            defer { IOObjectRelease(entry) }
            let location = IORegistryEntryCreateCFProperty(
                entry, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            guard location as? String == "External",
                let service = create(kCFAllocatorDefault, entry)?.takeRetainedValue()
            else { continue }
            found.append(ExternalService(service: service, write: write, read: read))
        }
        return found
    }

    private func send(_ message: [UInt8]) -> Bool {
        var bytes = message
        return write(service, Self.chipAddress, Self.dataAddress, &bytes, UInt32(bytes.count)) == 0
    }

    func writeBrightness(_ value: Int) {
        let message = DDCMessage.write(value: value)
        for _ in 0..<Self.attempts {
            let sent = send(message)
            usleep(Self.settleTime)
            if sent { return }
        }
    }

    func readBrightness() -> DDCMessage.Reading? {
        for _ in 0..<Self.attempts {
            for request in DDCMessage.readRequests {
                guard send(request) else { continue }
                usleep(Self.settleTime)
                var reply = [UInt8](repeating: 0, count: 12)
                let status = read(
                    service, Self.chipAddress, Self.dataAddress, &reply, UInt32(reply.count))
                usleep(Self.settleTime)
                if status == 0, let reading = DDCMessage.reading(from: reply) { return reading }
            }
        }
        return nil
    }
}
