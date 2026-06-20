import XCTest
@testable import SwiftPETSCII

final class CharsetSwitchTests: XCTestCase {

    /// Default charset is set 1 (uppercase / graphics).
    func testDefaultCharset() throws {
        let bytes: [UInt8] = [0x41]   // 'A'
        let doc = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(doc.frames[0].screen[column: 0, row: 0].charset, .uppercaseGraphics)
    }

    /// 0x0E flips to set 2 (uppercase/lowercase) and persists for subsequent cells.
    func testSwitchToLowercase() throws {
        // 'A', 0x0E, 'B'
        let bytes: [UInt8] = [0x41, 0x0E, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].charset, .uppercaseGraphics)
        XCTAssertEqual(s[column: 1, row: 0].charset, .uppercaseLowercase)
    }

    /// 0x8E switches back to set 1 mid-stream.
    func testSwitchBackToUppercase() throws {
        // start in set 1, switch to set 2, write, switch back, write.
        // 'A', 0x0E, 'B', 0x8E, 'C'
        let bytes: [UInt8] = [0x41, 0x0E, 0x42, 0x8E, 0x43]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].charset, .uppercaseGraphics)
        XCTAssertEqual(s[column: 1, row: 0].charset, .uppercaseLowercase)
        XCTAssertEqual(s[column: 2, row: 0].charset, .uppercaseGraphics)
    }

    /// Mid-screen charset switch: each cell remembers which bank it was
    /// written under (this is the test that exercises per-cell attribution).
    func testPerCellCharsetAttribution() throws {
        // Write 5 chars, switch, write 5 more.
        // A B C D E (set 1), switch 0x0E, F G H I J (set 2)
        let bytes: [UInt8] = [0x41, 0x42, 0x43, 0x44, 0x45,
                              0x0E,
                              0x46, 0x47, 0x48, 0x49, 0x4A]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        for col in 0..<5 {
            XCTAssertEqual(s[column: col, row: 0].charset, .uppercaseGraphics,
                           "col \(col) should be set 1")
        }
        for col in 5..<10 {
            XCTAssertEqual(s[column: col, row: 0].charset, .uppercaseLowercase,
                           "col \(col) should be set 2")
        }
    }
}
