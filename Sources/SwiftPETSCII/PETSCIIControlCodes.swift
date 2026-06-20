import Foundation

/// Catalog of PETSCII control bytes and their interpreted meaning. This is
/// the parser-side dispatch table: given a single non-printable byte, what
/// state change should the renderer apply?
///
/// Sources:
///   - C64 Programmer's Reference Guide, Appendix F (PETSCII tables)
///   - C64 User's Guide, Appendix E (control codes)
///   - https://style64.org/petscii/
///   - https://www.commodore.ca/manuals/c64_users_guide/c64-users_guide-04-appendix_e.pdf
public enum PETSCIIControlCode: Sendable, Equatable {
    /// Set the current text color (one of the 16 C64 palette indices).
    case setColor(C64Color)
    /// Switch character set to set 1 (uppercase / graphics) — code 0x8E.
    case switchToUppercaseGraphics
    /// Switch character set to set 2 (uppercase / lowercase) — code 0x0E.
    case switchToUppercaseLowercase
    /// Reverse-video on (subsequent characters render fg/bg swapped) — 0x12.
    case reverseOn
    /// Reverse-video off — 0x92.
    case reverseOff
    /// Cursor to (0,0). No clear. Code 0x13.
    case home
    /// Clear screen and home cursor. Code 0x93. Also our animation frame
    /// boundary marker.
    case clearScreen
    /// Cursor moves.
    case cursorUp
    case cursorDown
    case cursorLeft
    case cursorRight
    /// Insert a blank cell at the cursor (shifts the rest of the line right)
    /// — code 0x94.
    case insert
    /// Delete cell at cursor (shifts the rest of the line left) — code 0x14.
    case delete
    /// Carriage return / newline. 0x0D advances to start of next row.
    case newline
    /// Line feed (0x0A) — on the C64 this is identical to `newline`.
    case lineFeed

    /// Decode a single PETSCII byte into a control action, or `nil` if the
    /// byte represents printable content rather than a control code.
    ///
    /// Printable ranges are 0x20..0x7F and 0xA0..0xFF — those bytes return
    /// `nil` here and should be written to the current cursor cell by the
    /// parser. Bytes outside those ranges and not in this table fall
    /// through to `nil` as well — the parser surfaces those via
    /// `PETSCIIError.unsupportedControlCode` if strict mode is requested.
    public static func decode(_ byte: UInt8) -> PETSCIIControlCode? {
        switch byte {
        // --- colors ---
        case 0x05: return .setColor(.white)
        case 0x1C: return .setColor(.red)
        case 0x1E: return .setColor(.green)
        case 0x1F: return .setColor(.blue)
        case 0x81: return .setColor(.orange)
        case 0x90: return .setColor(.black)
        case 0x95: return .setColor(.brown)
        case 0x96: return .setColor(.lightRed)
        case 0x97: return .setColor(.darkGray)
        case 0x98: return .setColor(.midGray)
        case 0x99: return .setColor(.lightGreen)
        case 0x9A: return .setColor(.lightBlue)
        case 0x9B: return .setColor(.lightGray)
        case 0x9C: return .setColor(.purple)
        case 0x9E: return .setColor(.yellow)
        case 0x9F: return .setColor(.cyan)

        // --- charset ---
        case 0x0E: return .switchToUppercaseLowercase
        case 0x8E: return .switchToUppercaseGraphics

        // --- reverse-video ---
        case 0x12: return .reverseOn
        case 0x92: return .reverseOff

        // --- screen control ---
        case 0x13: return .home
        case 0x93: return .clearScreen

        // --- cursor moves ---
        case 0x11: return .cursorDown
        case 0x91: return .cursorUp
        case 0x1D: return .cursorRight
        case 0x9D: return .cursorLeft

        // --- editing ---
        case 0x14: return .delete
        case 0x94: return .insert

        // --- line termination ---
        case 0x0D: return .newline
        case 0x0A: return .lineFeed

        default:
            return nil
        }
    }

    /// Is this byte known to be a printable PETSCII codepoint (it occupies
    /// a screen cell rather than mutating parser state)?
    public static func isPrintable(_ byte: UInt8) -> Bool {
        return (byte >= 0x20 && byte <= 0x7F) || (byte >= 0xA0 && byte <= 0xFF)
    }
}
