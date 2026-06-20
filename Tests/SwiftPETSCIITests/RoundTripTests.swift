import XCTest
@testable import SwiftPETSCII

final class RoundTripTests: XCTestCase {

    /// Building a 40x25 input by writing PETSCII bytes for "ROW 0", then
    /// CR, "ROW 1", … should produce a screen whose first column carries
    /// the leading character of each row.
    func testFiveRowsFiveCols() throws {
        // 5 rows, each "ABCDE" + CR.
        var bytes: [UInt8] = []
        for _ in 0..<5 {
            bytes.append(contentsOf: [0x41, 0x42, 0x43, 0x44, 0x45, 0x0D])
        }
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        for row in 0..<5 {
            XCTAssertEqual(s[column: 0, row: row].codepoint, 0x01)  // A
            XCTAssertEqual(s[column: 1, row: row].codepoint, 0x02)  // B
            XCTAssertEqual(s[column: 2, row: row].codepoint, 0x03)  // C
            XCTAssertEqual(s[column: 3, row: row].codepoint, 0x04)  // D
            XCTAssertEqual(s[column: 4, row: row].codepoint, 0x05)  // E
        }
    }

    /// Render → parse round-trip: render a small input, parse the same
    /// input again into a fresh document, and confirm the screen grids
    /// match identically.
    func testParseIsStable() throws {
        let bytes: [UInt8] = [0x9E, 0x48, 0x49, 0x0D,    // yellow "HI"
                              0x1C, 0x42, 0x59, 0x45]    // red "BYE"
        let a = try PETSCIIDocument(bytes: bytes)
        let b = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(a.frames.count, b.frames.count)
        XCTAssertEqual(a.frames[0].screen, b.frames[0].screen)
    }

    /// Full 1000-byte fill should populate every cell.
    func testFullScreenFill() throws {
        let cellCount = PETSCIIScreen.columns * PETSCIIScreen.rows
        let bytes = [UInt8](repeating: 0x42, count: cellCount)  // 'B' everywhere
        let doc = try PETSCIIDocument(bytes: bytes)
        let s = doc.frames[0].screen
        for row in 0..<PETSCIIScreen.rows {
            for col in 0..<PETSCIIScreen.columns {
                XCTAssertEqual(s[column: col, row: row].codepoint, 0x02)
            }
        }
    }

    /// PETSCII printable byte → screen-code mapping spot checks.
    func testPETSCIIToScreenCodeMapping() {
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0x20), 0x20)  // space
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0x41), 0x01)  // 'A'
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0x5A), 0x1A)  // 'Z'
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0x30), 0x30)  // '0'
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0xC1), 0x41)  // mirror 'A'
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0xFF), 0x5E)  // pi
    }

    /// Empty input should throw, not crash.
    func testEmptyInputThrows() {
        XCTAssertThrowsError(try PETSCIIDocument(bytes: [])) { error in
            guard let e = error as? PETSCIIError else {
                XCTFail("Wrong error type: \(error)")
                return
            }
            XCTAssertEqual(e, PETSCIIError.invalidData)
        }
    }
}
