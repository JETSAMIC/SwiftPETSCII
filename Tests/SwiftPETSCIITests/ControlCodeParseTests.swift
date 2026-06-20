import XCTest
@testable import SwiftPETSCII

final class ControlCodeParseTests: XCTestCase {

    // MARK: - 16 colors

    func testAll16ColorControlBytes() {
        let mapping: [(UInt8, C64Color)] = [
            (0x05, .white),
            (0x1C, .red),
            (0x1E, .green),
            (0x1F, .blue),
            (0x81, .orange),
            (0x90, .black),
            (0x95, .brown),
            (0x96, .lightRed),
            (0x97, .darkGray),
            (0x98, .midGray),
            (0x99, .lightGreen),
            (0x9A, .lightBlue),
            (0x9B, .lightGray),
            (0x9C, .purple),
            (0x9E, .yellow),
            (0x9F, .cyan),
        ]
        for (byte, color) in mapping {
            XCTAssertEqual(
                PETSCIIControlCode.decode(byte),
                .setColor(color),
                String(format: "byte 0x%02X should map to %@", byte, String(describing: color))
            )
        }
    }

    // MARK: - charset switches

    func testCharsetSwitchBytes() {
        XCTAssertEqual(PETSCIIControlCode.decode(0x0E), .switchToUppercaseLowercase)
        XCTAssertEqual(PETSCIIControlCode.decode(0x8E), .switchToUppercaseGraphics)
    }

    // MARK: - reverse-video

    func testReverseOnOff() {
        XCTAssertEqual(PETSCIIControlCode.decode(0x12), .reverseOn)
        XCTAssertEqual(PETSCIIControlCode.decode(0x92), .reverseOff)
    }

    // MARK: - screen / cursor control

    func testHomeAndClear() {
        XCTAssertEqual(PETSCIIControlCode.decode(0x13), .home)
        XCTAssertEqual(PETSCIIControlCode.decode(0x93), .clearScreen)
    }

    func testCursorMoves() {
        XCTAssertEqual(PETSCIIControlCode.decode(0x11), .cursorDown)
        XCTAssertEqual(PETSCIIControlCode.decode(0x91), .cursorUp)
        XCTAssertEqual(PETSCIIControlCode.decode(0x1D), .cursorRight)
        XCTAssertEqual(PETSCIIControlCode.decode(0x9D), .cursorLeft)
    }

    func testInsertDelete() {
        XCTAssertEqual(PETSCIIControlCode.decode(0x14), .delete)
        XCTAssertEqual(PETSCIIControlCode.decode(0x94), .insert)
    }

    func testNewlineLineFeed() {
        XCTAssertEqual(PETSCIIControlCode.decode(0x0D), .newline)
        XCTAssertEqual(PETSCIIControlCode.decode(0x0A), .lineFeed)
    }

    // MARK: - printable detection

    func testPrintableRanges() {
        // Lower printable: 0x20..0x7F
        for b: UInt8 in 0x20...0x7F {
            XCTAssertTrue(PETSCIIControlCode.isPrintable(b))
        }
        // Upper printable: 0xA0..0xFF
        for b in 0xA0...0xFF {
            XCTAssertTrue(PETSCIIControlCode.isPrintable(UInt8(b)))
        }
        // Some non-printables
        for b: UInt8 in [0x00, 0x01, 0x05, 0x0A, 0x0D, 0x0E, 0x11, 0x12,
                          0x13, 0x14, 0x1C, 0x1D, 0x1E, 0x1F, 0x80, 0x81,
                          0x8E, 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x9F] {
            XCTAssertFalse(PETSCIIControlCode.isPrintable(b), String(format: "0x%02X should not be printable", b))
        }
    }

    // MARK: - unknown bytes decode to nil

    func testUnknownControlBytesDecodeToNil() {
        // Some bytes in the control range that aren't defined PETSCII control codes.
        for b: UInt8 in [0x00, 0x01, 0x02, 0x03, 0x04, 0x06, 0x07, 0x08,
                          0x09, 0x0B, 0x0C, 0x0F, 0x10, 0x15, 0x16, 0x17,
                          0x18, 0x19, 0x1A, 0x1B] {
            XCTAssertNil(PETSCIIControlCode.decode(b), String(format: "0x%02X should decode to nil", b))
        }
    }
}
