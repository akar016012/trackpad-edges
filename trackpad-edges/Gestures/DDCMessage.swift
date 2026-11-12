import Foundation

/// Builds and reads the DDC messages that control a monitor's brightness.
nonisolated enum DDCMessage {
    struct Reading: Sendable, Equatable {
        let current: Int
        let maximum: Int
    }

    private static let brightnessCode: UInt8 = 0x10
    private static let displayAddress: UInt8 = 0x6E
    private static let hostAddress: UInt8 = 0x51

    /// Every message ends with a checksum of the two addresses and the bytes before it.
    private static func withChecksum(_ bytes: [UInt8], seed: UInt8) -> [UInt8] {
        bytes + [bytes.reduce(seed) { $0 ^ $1 }]
    }

    static func write(value: Int) -> [UInt8] {
        let clamped = UInt16(clamping: value)
        // 0x84 is the length byte (0x80 plus four bytes), and 0x03 is the Set VCP Feature opcode.
        let body: [UInt8] = [
            0x84, 0x03, brightnessCode, UInt8(clamped >> 8), UInt8(clamped & 0xFF),
        ]
        return withChecksum(body, seed: displayAddress ^ hostAddress)
    }

    /**
     The forms of the read request, with the standard form first. Some monitors answer only the
     second form, which leaves the host address out of the checksum.
     */
    static let readRequests: [[UInt8]] = [
        withChecksum([0x82, 0x01, brightnessCode], seed: displayAddress ^ hostAddress),
        withChecksum([0x82, 0x01, brightnessCode], seed: displayAddress),
    ]

    /**
     Returns the reading in a reply, or nil if the monitor did not answer the request.

     A reply's shape is checked rather than its checksum, because the reply's first byte can
     differ between connections, and a shape check already rejects an empty or garbled reply.
     */
    static func reading(from reply: [UInt8]) -> Reading? {
        // Byte 2 is the Get VCP Feature reply opcode, and byte 3 is the result code for success.
        guard reply.count >= 10, reply[2] == 0x02, reply[3] == 0x00, reply[4] == brightnessCode
        else { return nil }
        let maximum = Int(reply[6]) << 8 | Int(reply[7])
        let current = Int(reply[8]) << 8 | Int(reply[9])
        guard maximum > 0, current <= maximum else { return nil }
        return Reading(current: current, maximum: maximum)
    }
}
