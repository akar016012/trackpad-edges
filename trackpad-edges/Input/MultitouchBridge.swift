import Foundation

/// Loads the private MultitouchSupport framework at runtime, so that a missing symbol disables
/// the feature instead of stopping the app from launching.
final class MultitouchBridge {
    static let shared = MultitouchBridge()

    typealias ContactFrameCallback =
        @convention(c) (UnsafeRawPointer?, UnsafeRawPointer?, Int32, Double, Int32) -> Int32
    private typealias CreateList = @convention(c) () -> UnsafeRawPointer?
    private typealias Register = @convention(c) (UnsafeRawPointer, ContactFrameCallback) -> Bool
    private typealias Unregister = @convention(c) (UnsafeRawPointer, ContactFrameCallback) -> Bool
    private typealias Start = @convention(c) (UnsafeRawPointer, Int32) -> Int32
    private typealias Stop = @convention(c) (UnsafeRawPointer) -> Int32
    private typealias GetFamilyID =
        @convention(c) (UnsafeRawPointer, UnsafeMutablePointer<Int32>) -> Int32

    /// The family IDs of Apple's touch mice, which also report touches but are not trackpads.
    private static let mouseFamilies: Set<Int32> = [112, 113]

    /// Receives the active touches of one device on the main thread.
    var onFrame: ((_ device: UnsafeRawPointer, _ touches: [TouchPoint]) -> Void)?

    private(set) var devices: [UnsafeRawPointer] = []
    private var deviceList: CFArray?

    private let unregister: Unregister? = MultitouchFramework.symbol(
        "MTUnregisterContactFrameCallback")
    private let stopDevice: Stop? = MultitouchFramework.symbol("MTDeviceStop")

    /// Starts every trackpad and returns how many were found.
    @discardableResult
    func start() -> Int {
        guard let createList: CreateList = MultitouchFramework.symbol("MTDeviceCreateList"),
            let register: Register = MultitouchFramework.symbol("MTRegisterContactFrameCallback"),
            let startDevice: Start = MultitouchFramework.symbol("MTDeviceStart"),
            let list = createList()
        else { return 0 }
        let getFamilyID: GetFamilyID? = MultitouchFramework.symbol("MTDeviceGetFamilyID")

        // The list owns the devices, so it must stay alive for as long as they are in use.
        let array = Unmanaged<CFArray>.fromOpaque(list).takeRetainedValue()
        deviceList = array
        for index in 0..<CFArrayGetCount(array) {
            guard let device = CFArrayGetValueAtIndex(array, index) else { continue }
            var family: Int32 = 0
            if getFamilyID?(device, &family) == 0, Self.mouseFamilies.contains(family) { continue }
            _ = register(device, contactFrameCallback)
            _ = startDevice(device, 0)
            devices.append(device)
        }
        return devices.count
    }

    /// Unregisters from every device, because each device has only four callback slots.
    func stop() {
        for device in devices {
            _ = unregister?(device, contactFrameCallback)
            _ = stopDevice?(device)
        }
        devices = []
        deviceList = nil
    }
}

/// Resolves symbols from the private framework, whose code lives in the dyld shared cache.
nonisolated enum MultitouchFramework {
    private static let path =
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    nonisolated(unsafe) private static let handle = dlopen(path, RTLD_NOW)

    static func symbol<T>(_ name: String) -> T? {
        guard let handle, let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}

/// The byte layout of the framework's touch record, read from the macOS 27.2 binary.
private nonisolated enum TouchLayout {
    static let stride = 96
    static let identifier = 16
    static let state = 20
    static let normalizedX = 32
    static let normalizedY = 36
    static let size = 48
    static let pressure = 52
    static let majorAxis = 60
    static let makeTouch: Int32 = 3
    static let touching: Int32 = 4
}

/// Runs on a framework thread, so it only copies the touches and hands them to the main thread.
private nonisolated func contactFrameCallback(
    device: UnsafeRawPointer?, touches: UnsafeRawPointer?, count: Int32, timestamp: Double,
    frame: Int32
) -> Int32 {
    guard let device else { return 0 }
    var points: [TouchPoint] = []
    if let touches {
        for index in 0..<Int(count) {
            let base = index * TouchLayout.stride
            let state = touches.loadUnaligned(
                fromByteOffset: base + TouchLayout.state, as: Int32.self)
            guard state == TouchLayout.makeTouch || state == TouchLayout.touching else { continue }
            let x = touches.loadUnaligned(
                fromByteOffset: base + TouchLayout.normalizedX, as: Float.self)
            let y = touches.loadUnaligned(
                fromByteOffset: base + TouchLayout.normalizedY, as: Float.self)
            // Values outside this range mean that a macOS update changed the record's layout.
            guard (-0.5...1.5).contains(x), (-0.5...1.5).contains(y) else { continue }
            let id = touches.loadUnaligned(
                fromByteOffset: base + TouchLayout.identifier, as: Int32.self)
            points.append(
                TouchPoint(
                    id: id, x: x, y: y,
                    pressure: touches.loadUnaligned(
                        fromByteOffset: base + TouchLayout.pressure, as: Float.self),
                    size: touches.loadUnaligned(
                        fromByteOffset: base + TouchLayout.size, as: Float.self),
                    majorAxis: touches.loadUnaligned(
                        fromByteOffset: base + TouchLayout.majorAxis, as: Float.self)))
        }
    }
    let deviceAddress = UInt(bitPattern: device)
    let snapshot = points
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            guard let device = UnsafeRawPointer(bitPattern: deviceAddress) else { return }
            MultitouchBridge.shared.onFrame?(device, snapshot)
        }
    }
    return 0
}
