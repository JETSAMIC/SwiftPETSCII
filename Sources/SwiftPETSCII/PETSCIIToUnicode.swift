import Foundation

/// Best-effort PETSCII → Unicode mapping for accessibility labels and
/// text-extraction probes. PETSCII has many graphics characters that have
/// no clean Unicode equivalent; those return `"?"`.
///
/// This mapping operates on the **PETSCII** byte (not the screen-code), so
/// callers feeding raw input bytes can use it directly. Control codes
/// return an empty string (they don't print).
public enum PETSCIIToUnicode {

    /// Map a single PETSCII byte to a Unicode `Character`. Returns
    /// `nil` for control codes and other non-printable bytes.
    public static func character(forPETSCIIByte b: UInt8) -> Character? {
        // Control codes: no glyph.
        if !PETSCIIControlCode.isPrintable(b) {
            return nil
        }

        // Letters (PETSCII 0x41..0x5A uppercase, 0xC1..0xDA mirror).
        if (0x41...0x5A).contains(b) {
            return Character(UnicodeScalar(b))
        }
        if (0xC1...0xDA).contains(b) {
            return Character(UnicodeScalar(b - 0x80))
        }
        // Lowercase letters live at 0x61..0x7A in set-2 mode (in set-1
        // these are graphics chars, but the Unicode best-effort here
        // assumes the writer meant text).
        if (0x61...0x7A).contains(b) {
            return Character(UnicodeScalar(b))
        }

        // Digits, punctuation, ASCII-overlap range.
        if (0x20...0x40).contains(b) {
            return Character(UnicodeScalar(b))
        }
        // Set-1 graphics 0x5B..0x5F: brackets / underscore / etc.
        if (0x5B...0x5F).contains(b) {
            return Character(UnicodeScalar(b))
        }

        // A handful of well-known graphics chars get block-element
        // approximations.
        switch b {
        case 0xA0: return " "                      // shifted-space
        case 0xDC: return Character("\u{2588}")    // full block
        case 0x7E: return Character("\u{03C0}")    // pi (set-1 codepoint $7E)
        case 0xFF: return Character("\u{03C0}")    // pi (alt)
        case 0xA9: return Character("\u{2517}")    // box-drawing
        case 0xAA: return Character("\u{251B}")    // box-drawing
        case 0xAB: return Character("\u{2513}")    // box-drawing
        case 0xB0: return Character("\u{250F}")    // box-drawing
        case 0xC0: return Character("\u{2500}")    // horizontal bar
        case 0xDD: return Character("\u{2502}")    // vertical bar
        default:
            return Character("?")
        }
    }

    /// Convert an entire screen to a best-effort plain-text string,
    /// row-by-row, padded to 40 chars per row and joined with `\n`.
    public static func string(from screen: PETSCIIScreen) -> String {
        var out = ""
        out.reserveCapacity(PETSCIIScreen.rows * (PETSCIIScreen.columns + 1))
        for row in 0 ..< PETSCIIScreen.rows {
            for col in 0 ..< PETSCIIScreen.columns {
                let cell = screen[column: col, row: row]
                out.append(character(forScreenCode: cell.codepoint, charset: cell.charset) ?? "?")
            }
            if row < PETSCIIScreen.rows - 1 { out.append("\n") }
        }
        return out
    }

    /// Map a screen-code (NOT PETSCII byte) to a Unicode character. The
    /// charset informs whether 0x01..0x1A is uppercase A-Z (set 1) or
    /// lowercase a-z (set 2).
    public static func character(forScreenCode s: UInt8, charset: PETSCIICharset) -> Character? {
        switch s {
        case 0x00:
            return Character("@")
        case 0x01...0x1A:
            // set 1: uppercase A-Z; set 2: lowercase a-z
            let base: UInt8 = (charset == .uppercaseGraphics) ? 0x40 : 0x60
            return Character(UnicodeScalar(base + s))
        case 0x1B: return Character("[")
        case 0x1C: return Character("\u{00A3}")  // pound sign
        case 0x1D: return Character("]")
        case 0x1E: return Character("\u{2191}")  // up arrow
        case 0x1F: return Character("\u{2190}")  // left arrow
        case 0x20...0x3F:
            return Character(UnicodeScalar(s))
        default:
            return Character("?")
        }
    }
}
