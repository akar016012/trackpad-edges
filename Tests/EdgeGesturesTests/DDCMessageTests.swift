import XCTest

@testable import EdgeGestures

final class DDCMessageTests: XCTestCase {
    func testWriteMessageCarriesTheValueAndChecksum() {
        XCTAssertEqual(DDCMessage.write(value: 50), [0x84, 0x03, 0x10, 0x00, 0x32, 0x9A])
    }

    func testWriteMessageSplitsLargeValues() {
        XCTAssertEqual(Array(DDCMessage.write(value: 300)[3...4]), [0x01, 0x2C])
    }

    func testStandardReadRequestComesFirst() {
        XCTAssertEqual(DDCMessage.readRequests.first, [0x82, 0x01, 0x10, 0xAC])
    }

    private let reply: [UInt8] = [
        0x6E, 0x88, 0x02, 0x00, 0x10, 0x00, 0x00, 0x64, 0x00, 0x32, 0x00, 0x00,
    ]

    func testReplyGivesTheCurrentAndMaximumValues() {
        XCTAssertEqual(
            DDCMessage.reading(from: reply), DDCMessage.Reading(current: 50, maximum: 100))
    }

    func testLargeMaximumUsesBothBytes() {
        var large = reply
        large[6] = 0x01
        XCTAssertEqual(DDCMessage.reading(from: large)?.maximum, 356)
    }

    func testUnsupportedReplyIsRejected() {
        var unsupported = reply
        unsupported[3] = 0x01
        XCTAssertNil(DDCMessage.reading(from: unsupported))
    }

    func testGarbledRepliesAreRejected() {
        XCTAssertNil(DDCMessage.reading(from: [UInt8](repeating: 0xFF, count: 12)))
        XCTAssertNil(DDCMessage.reading(from: [UInt8](repeating: 0, count: 12)))
        XCTAssertNil(DDCMessage.reading(from: [0x6E]))
    }

    func testCurrentAboveMaximumIsRejected() {
        var impossible = reply
        impossible[9] = 0x65
        XCTAssertNil(DDCMessage.reading(from: impossible))
    }
}
