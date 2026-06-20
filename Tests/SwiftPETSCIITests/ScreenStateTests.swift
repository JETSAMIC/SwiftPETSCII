import XCTest
@testable import SwiftPETSCII

final class ScreenStateTests: XCTestCase {

    /// Plain "HELLO" lands at (0,0)..(4,0) with default foreground.
    func testHelloWritesAtOrigin() throws {
        // PETSCII uppercase letters: H=0x48 E=0x45 L=0x4C L=0x4C O=0x4F
        let bytes: [UInt8] = [0x48, 0x45, 0x4C, 0x4C, 0x4F]
        let doc = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(doc.frames.count, 1)
        let screen = doc.frames[0].screen
        let h = screen[column: 0, row: 0]
        let o = screen[column: 4, row: 0]
        XCTAssertEqual(h.codepoint, 0x08)  // screen-code for 'H' = 0x48 - 0x40
        XCTAssertEqual(o.codepoint, 0x0F)
        XCTAssertEqual(h.foreground, .lightBlue)
        XCTAssertFalse(h.reverse)
        XCTAssertEqual(h.charset, .uppercaseGraphics)
    }

    /// Color change before a glyph is honored on that glyph.
    func testColorChangeAppliesToNextChar() throws {
        // RED (0x1C) then 'A' (0x41)
        let bytes: [UInt8] = [0x1C, 0x41]
        let doc = try PETSCIIDocument(bytes: bytes)
        let cell = doc.frames[0].screen[column: 0, row: 0]
        XCTAssertEqual(cell.foreground, .red)
        XCTAssertEqual(cell.codepoint, 0x01)  // 'A' screen-code
    }

    /// Cursor down + char lands on the second row.
    func testCursorDownAdvancesRow() throws {
        // 'A', cursor-down (0x11), 'B'
        let bytes: [UInt8] = [0x41, 0x11, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x01)  // A
        // After 'A' the cursor is at (1, 0); after 0x11 it's at (1, 1); after 'B'
        // 'B' lands at (1, 1).
        XCTAssertEqual(s[column: 1, row: 1].codepoint, 0x02)  // B
    }

    /// CR/newline resets column to 0 and advances row.
    func testNewlineMovesToNextRowColZero() throws {
        // 'A', 0x0D, 'B'
        let bytes: [UInt8] = [0x41, 0x0D, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x01)
        XCTAssertEqual(s[column: 0, row: 1].codepoint, 0x02)
    }

    /// Reverse-on then a char makes that cell reverse; reverse-off cancels.
    func testReverseToggle() throws {
        // 0x12 (rvs on), 'A', 0x92 (rvs off), 'B'
        let bytes: [UInt8] = [0x12, 0x41, 0x92, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertTrue(s[column: 0, row: 0].reverse)
        XCTAssertFalse(s[column: 1, row: 0].reverse)
    }

    /// Home (0x13) resets cursor to (0,0); overwriting previously-written cells.
    func testHomeResetsCursorWithoutClearing() throws {
        // 'A', 0x13, 'B' → 'B' overwrites cell (0,0); 'A' is replaced.
        let bytes: [UInt8] = [0x41, 0x13, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x02)  // B
    }

    /// Cursor right (0x1D) advances without writing.
    func testCursorRightSkipsCell() throws {
        // 'A', cursor-right, 'B'
        let bytes: [UInt8] = [0x41, 0x1D, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x01)
        XCTAssertEqual(s[column: 2, row: 0].codepoint, 0x02)
        // Cell 1 stays at default (space).
        XCTAssertEqual(s[column: 1, row: 0].codepoint, 0x20)
    }
}
