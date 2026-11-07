import XCTest
@testable import SwiftPETSCII

/// One test per rule in Reference/PETSCII.md that was fixed or added during
/// the production audit. Fixtures are hand-built byte streams.
final class SpecConformanceTests: XCTestCase {

    private func screen(_ bytes: [UInt8], options: PETSCIIParser.Options = .init()) throws -> PETSCIIScreen {
        let frames = try PETSCIIParser(options: options).parse(bytes)
        return try XCTUnwrap(frames.last).screen
    }

    // MARK: - PETSCII ↔ screen code

    func testScreenCodeMappingIsTotalAndMatchesTable() {
        for b in 0...255 {
            let byte = UInt8(b)
            let expected: UInt8
            switch byte {
            case 0x00...0x1F: expected = byte + 0x80
            case 0x20...0x3F: expected = byte
            case 0x40...0x5F: expected = byte - 0x40
            case 0x60...0x7F: expected = byte - 0x20
            case 0x80...0x9F: expected = byte + 0x40
            case 0xA0...0xBF: expected = byte - 0x40
            case 0xC0...0xFE: expected = byte - 0x80
            default: expected = 0x5E
            }
            XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: byte), expected, String(format: "0x%02X", b))
        }
    }

    func testDuplicatedRangesShareScreenCodes() {
        for offset: UInt8 in 0..<0x20 {
            XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0x60 + offset),
                           PETSCIIParser.screenCode(forPETSCII: 0xC0 + offset))
        }
        for offset: UInt8 in 0..<0x1F {
            XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0xE0 + offset),
                           PETSCIIParser.screenCode(forPETSCII: 0xA0 + offset))
        }
        XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: 0xFF), PETSCIIParser.screenCode(forPETSCII: 0xDE))
    }

    func testCanonicalPETSCIIForScreenCode() {
        XCTAssertEqual(PETSCIIParser.petsciiByte(forScreenCode: 0x01), 0x41)
        XCTAssertEqual(PETSCIIParser.petsciiByte(forScreenCode: 0x20), 0x20)
        XCTAssertEqual(PETSCIIParser.petsciiByte(forScreenCode: 0x41), 0xC1)
        XCTAssertEqual(PETSCIIParser.petsciiByte(forScreenCode: 0x5E), 0xDE)
        XCTAssertEqual(PETSCIIParser.petsciiByte(forScreenCode: 0x60), 0xA0)
        XCTAssertEqual(PETSCIIParser.petsciiByte(forScreenCode: 0x81), 0x41)
        for code in 0..<0x80 {
            let byte = PETSCIIParser.petsciiByte(forScreenCode: UInt8(code))
            XCTAssertTrue(PETSCIIControlCode.isPrintable(byte))
            XCTAssertEqual(PETSCIIParser.screenCode(forPETSCII: byte), UInt8(code))
        }
    }

    // MARK: - Control codes

    func testControlCodeByteRoundTrips() {
        for b in 0...255 {
            if let code = PETSCIIControlCode.decode(UInt8(b)) {
                XCTAssertEqual(code.byte, UInt8(b))
            }
        }
    }

    func testReturnTurnsReverseOff() throws {
        for ret: UInt8 in [0x0D, 0x8D] {
            let s = try screen([0x12, 0x41, ret, 0x42])
            XCTAssertTrue(s[column: 0, row: 0].reverse)
            XCTAssertFalse(s[column: 0, row: 1].reverse, String(format: "0x%02X", ret))
        }
    }

    func testLineFeedIsIgnoredOnC64() throws {
        let s = try screen([0x41, 0x0A, 0x42])
        XCTAssertEqual(s[column: 1, row: 0].codepoint, 0x02)
        XCTAssertEqual(s[column: 0, row: 1].codepoint, 0x20)
    }

    func testDeleteIsBackspace() throws {
        // "ABC", DEL → "AB" with cursor on C's old cell; "X" lands there.
        let s = try screen([0x41, 0x42, 0x43, 0x14, 0x58])
        XCTAssertEqual((0..<3).map { s[column: $0, row: 0].codepoint }, [0x01, 0x02, 0x18])
        // DEL at column 0 does nothing.
        let t = try screen([0x41, 0x0D, 0x14, 0x42])
        XCTAssertEqual(t[column: 0, row: 0].codepoint, 0x01)
        XCTAssertEqual(t[column: 0, row: 1].codepoint, 0x02)
    }

    func testDeleteShiftsRestOfLineLeft() throws {
        // "ABC", left, left, DEL → "BC" (A deleted).
        let s = try screen([0x41, 0x42, 0x43, 0x9D, 0x9D, 0x14], options: .init(emulateQuoteMode: false))
        XCTAssertEqual((0..<3).map { s[column: $0, row: 0].codepoint }, [0x02, 0x03, 0x20])
    }

    func testInsertOpensGapAtCursor() throws {
        // "AB", left, INST, "X" → "AXB".
        let s = try screen([0x41, 0x42, 0x9D, 0x94, 0x58])
        XCTAssertEqual((0..<3).map { s[column: $0, row: 0].codepoint }, [0x01, 0x18, 0x02])
    }

    // MARK: - Scrolling

    func testOutputPastBottomScrolls() throws {
        // 26 lines "0".."Z": the first scrolls off, line 25 is at the bottom.
        var bytes: [UInt8] = []
        for i in 0..<26 { bytes += [0x41 + UInt8(i), 0x0D] }
        let s = try screen(bytes)
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x02)   // 'B'
        XCTAssertEqual(s[column: 0, row: 24].codepoint, 0x1A)  // 'Z'
    }

    func testFullScreenThenOneMoreCharacterScrolls() throws {
        let bytes = [UInt8](repeating: 0x42, count: 1000) + [0x43]
        let s = try screen(bytes)
        XCTAssertEqual(s[column: 0, row: 24].codepoint, 0x03)
        XCTAssertEqual(s[column: 1, row: 24].codepoint, 0x20)
        XCTAssertEqual(s[column: 39, row: 23].codepoint, 0x02)
    }

    func testCursorDownOnBottomRowScrolls() throws {
        var bytes: [UInt8] = [0x41]
        bytes += [UInt8](repeating: 0x11, count: 25)  // 24 to reach the bottom, 1 to scroll
        bytes += [0x42]
        let s = try screen(bytes)
        XCTAssertEqual(s[column: 1, row: 24].codepoint, 0x02)
        XCTAssertFalse((0..<25).contains { s[column: 0, row: $0].codepoint == 0x01 }, "'A' scrolled off")
    }

    // MARK: - Quote and insert mode

    func testQuoteModeEchoesControlCodes() throws {
        // " CLR " → the CLR shows as reverse heart (screen 0xD3), no new frame.
        let frames = try PETSCIIParser().parse([0x22, 0x93, 0x22, 0x13, 0x41])
        XCTAssertEqual(frames.count, 1)
        let s = frames[0].screen
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x01)   // HOME executed after closing quote
        XCTAssertEqual(s[column: 1, row: 0].codepoint, 0xD3)
        XCTAssertEqual(s[column: 2, row: 0].codepoint, 0x22)
    }

    func testQuoteModeEndsAtReturnAndDeleteStillWorks() throws {
        let s = try screen([0x22, 0x41, 0x14, 0x0D, 0x1C, 0x42])
        XCTAssertEqual(s[column: 1, row: 0].codepoint, 0x20, "DEL executed inside quotes")
        XCTAssertEqual(s[column: 0, row: 1].foreground, .red, "color code executed after RETURN")
    }

    func testQuoteModeCanBeDisabled() throws {
        let frames = try PETSCIIParser(options: .init(emulateQuoteMode: false)).parse([0x22, 0x93, 0x41])
        XCTAssertEqual(frames.count, 2)
    }

    func testInsertModeEchoesControlCodes() throws {
        // INST then RED: RED shows as reverse £ (0x1C → screen 0x9C).
        let s = try screen([0x94, 0x1C])
        XCTAssertEqual(s[column: 0, row: 0].codepoint, 0x9C)
        XCTAssertEqual(s[column: 0, row: 0].foreground, .lightBlue)
    }

    // MARK: - Character sets

    func testCharsetIsScreenWide() throws {
        let s = try screen([0x41, 0x0E, 0x42])
        XCTAssertEqual(s.charset, .uppercaseLowercase)
        // Both cells render from set 2 in hardware mode.
        let hw = PETSCIIRenderer.pixels(s)
        let mixed = PETSCIIRenderer.pixels(s, charsetMode: .perCell)
        XCTAssertNotEqual(hw, mixed)
        var lower = s
        lower[column: 0, row: 0].charset = .uppercaseLowercase
        XCTAssertEqual(PETSCIIRenderer.pixels(lower, charsetMode: .perCell), hw)
    }

    func testLockCodesDoNotBlockSwitching() throws {
        XCTAssertEqual(try screen([0x08, 0x0E, 0x41]).charset, .uppercaseLowercase)
    }

    // MARK: - Rendering

    func testReverseUsesROMReverseGlyph() throws {
        // The ROM's reverse '@' (0x80) is not a bitwise inversion of '@':
        // row 5 is 0x99 rather than 0x9D, so pixel (5,5) is background.
        var s = PETSCIIScreen()
        s[column: 0, row: 0] = PETSCIICell(codepoint: 0x00, foreground: .white, background: .blue, reverse: true)
        let px = PETSCIIRenderer.pixels(s)
        let i = (5 * PETSCIIRenderer.pixelWidth + 5) * 4
        XCTAssertEqual(Array(px[i..<(i + 3)]), [0, 0, 170])
    }

    func testPalettes() {
        XCTAssertEqual(C64Palette.pepto.rgb(.blue).r, 0x35)
        XCTAssertEqual(C64Palette.pepto.rgb(.lightBlue).b, 0xB5)
        XCTAssertEqual(C64Palette.c64Wiki.colors.count, 16)
        XCTAssertNil(C64Palette(colors: [0]))
        let s = try? screen([0x05, 0x41])
        XCTAssertNotNil(s.flatMap { PETSCIIRenderer.render($0, palette: .pepto) })
    }

    // MARK: - Unicode

    func testUnicodeGraphicsUseLegacyComputingBlock() {
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xC1), "\u{2660}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0x61), "\u{2660}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xC2), "\u{1FB72}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xA6), "\u{2592}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xDE), "\u{03C0}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xFF), "\u{03C0}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0x5C), "£")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0x5E), "↑")
        XCTAssertNil(PETSCIIToUnicode.character(forPETSCIIByte: 0x93))
    }

    func testUnicodeShiftedSet() {
        let set2 = PETSCIICharset.uppercaseLowercase
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0x41, charset: set2), "a")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xC1, charset: set2), "A")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0x61, charset: set2), "A")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xDE, charset: set2), "\u{1FB96}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xBA, charset: set2), "\u{2713}")
        XCTAssertEqual(PETSCIIToUnicode.character(forPETSCIIByte: 0xA9, charset: set2), "\u{1FB99}")
    }

    func testScreenCodesRoundTripThroughUnicode() {
        for charset in PETSCIICharset.allCases {
            var seen = Set<Character>()
            for code in UInt8(0)..<0x80 {
                let ch = try! XCTUnwrap(PETSCIIToUnicode.character(forScreenCode: code, charset: charset))
                XCTAssertTrue(seen.insert(ch).inserted, "duplicate \(ch) in \(charset)")
                XCTAssertEqual(PETSCIIToUnicode.screenCode(for: ch, charset: charset), code)
                // Reverse glyphs map like their base glyph.
                XCTAssertEqual(PETSCIIToUnicode.character(forScreenCode: code | 0x80, charset: charset), ch)
            }
        }
    }

    func testStringEncoding() throws {
        XCTAssertEqual(try PETSCIIToUnicode.petsciiBytes(for: "HI!\n", charset: .uppercaseGraphics),
                       [0x48, 0x49, 0x21, 0x0D])
        XCTAssertEqual(try PETSCIIToUnicode.petsciiBytes(for: "Hi", charset: .uppercaseLowercase), [0xC8, 0x49])
        XCTAssertThrowsError(try PETSCIIToUnicode.petsciiBytes(for: "hi", charset: .uppercaseGraphics)) { error in
            XCTAssertEqual(error as? PETSCIIError, .unencodableCharacter("h"))
        }
        // Encode → parse → text reproduces the input.
        let bytes = try PETSCIIToUnicode.petsciiBytes(for: "Hello, World", charset: .uppercaseLowercase)
        let s = try screen([0x0E] + bytes)
        XCTAssertTrue(PETSCIIToUnicode.string(from: s).hasPrefix("Hello, World "))
    }

    // MARK: - Errors and limits

    func testStrictModeRejectsUnknownControlCodes() {
        let parser = PETSCIIParser(options: .init(strict: true))
        XCTAssertThrowsError(try parser.parse([0x41, 0x07])) { error in
            XCTAssertEqual(error as? PETSCIIError, .unsupportedControlCode(0x07, offset: 1))
        }
        XCTAssertNoThrow(try PETSCIIParser().parse([0x41, 0x07]))
    }

    func testFrameLimit() {
        let parser = PETSCIIParser(options: .init(maxFrames: 2))
        XCTAssertThrowsError(try parser.parse([0x41, 0x93, 0x42, 0x93, 0x43])) { error in
            XCTAssertEqual(error as? PETSCIIError, .frameLimitExceeded(limit: 2))
        }
        XCTAssertEqual(try parser.parse([0x41, 0x93, 0x42]).count, 2)
    }
}
