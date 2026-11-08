import Foundation

/// The C64 PETSCII control codes that affect screen output.
///
/// These are the codes the C64 KERNAL screen editor acts on when a byte is
/// printed with `CHROUT`. Codes defined only on other Commodore machines
/// (for example the C128's underline `0x02`, bell `0x07`, tab `0x09`,
/// line feed `0x0A` and escape `0x1B`) are not C64 screen controls and
/// ``decode(_:)`` returns `nil` for them. See `Reference/PETSCII-Format.md` for the
/// full table and the machine differences.
///
/// Sources: C64 Programmer's Reference Guide, Appendix C/E; C64 User's
/// Guide, Appendix E; the KERNAL screen editor (`$E716`).
public enum PETSCIIControlCode: Sendable, Equatable {
    /// Set the current text color. Codes `0x05`, `0x1C`, `0x1E`, `0x1F`,
    /// `0x81`, `0x90`, `0x95`…`0x9C`, `0x9E`, `0x9F`.
    case setColor(C64Color)
    /// Switch the whole screen to the uppercase/graphics set — `0x8E`.
    case switchToUppercaseGraphics
    /// Switch the whole screen to the lowercase/uppercase set — `0x0E`.
    case switchToUppercaseLowercase
    /// Disable the SHIFT+Commodore charset toggle on the keyboard — `0x08`.
    /// Has no visible effect on output; `0x0E`/`0x8E` still switch.
    case lockCharset
    /// Re-enable the SHIFT+Commodore charset toggle — `0x09`.
    case unlockCharset
    /// Reverse video on — `0x12`.
    case reverseOn
    /// Reverse video off — `0x92`.
    case reverseOff
    /// Cursor to the top-left corner without clearing — `0x13`.
    case home
    /// Clear the screen and home the cursor — `0x93`. SwiftPETSCII also
    /// treats this as an animation frame boundary.
    case clearScreen
    /// Cursor up — `0x91`.
    case cursorUp
    /// Cursor down — `0x11`. Scrolls the screen on the bottom row.
    case cursorDown
    /// Cursor left — `0x9D`.
    case cursorLeft
    /// Cursor right — `0x1D`.
    case cursorRight
    /// Insert a blank at the cursor, shifting the rest of the line right — `0x94`.
    case insert
    /// Delete the character left of the cursor, shifting the rest of the
    /// line left (backspace) — `0x14`. At the start of a line it blanks the
    /// last cell of the previous line.
    case delete
    /// Carriage return — `0x0D`. Moves to the start of the next line and
    /// also turns reverse video and quote mode off.
    case newline
    /// Shifted carriage return — `0x8D`. Same screen effect as ``newline``.
    case shiftedReturn
    /// Line feed — `0x0A`. Not a C64 screen control: the C64 ignores it
    /// (it is a line feed on the C128). Kept for API compatibility;
    /// ``decode(_:)`` returns it for `0x0A` and the parser treats it as a
    /// no-op (or, in strict mode, as an unsupported control code).
    case lineFeed

    /// Decodes a single PETSCII byte into a control action.
    ///
    /// - Parameter byte: A PETSCII byte.
    /// - Returns: The control action, or `nil` if the byte is printable
    ///   (`0x20…0x7F`, `0xA0…0xFF`) or has no C64 screen meaning.
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
        case 0x08: return .lockCharset
        case 0x09: return .unlockCharset

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
        case 0x8D: return .shiftedReturn
        case 0x0A: return .lineFeed

        default:
            return nil
        }
    }

    /// The PETSCII byte that encodes this control action.
    public var byte: UInt8 {
        switch self {
        case .setColor(let color): return Self.colorCodes[Int(color.rawValue)]
        case .switchToUppercaseGraphics: return 0x8E
        case .switchToUppercaseLowercase: return 0x0E
        case .lockCharset: return 0x08
        case .unlockCharset: return 0x09
        case .reverseOn: return 0x12
        case .reverseOff: return 0x92
        case .home: return 0x13
        case .clearScreen: return 0x93
        case .cursorUp: return 0x91
        case .cursorDown: return 0x11
        case .cursorLeft: return 0x9D
        case .cursorRight: return 0x1D
        case .insert: return 0x94
        case .delete: return 0x14
        case .newline: return 0x0D
        case .shiftedReturn: return 0x8D
        case .lineFeed: return 0x0A
        }
    }

    /// PETSCII color code per hardware color index.
    private static let colorCodes: [UInt8] = [
        0x90, 0x05, 0x1C, 0x9F, 0x9C, 0x1E, 0x1F, 0x9E,
        0x81, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B,
    ]

    /// Returns `true` if the byte is a printable PETSCII code — one that
    /// occupies a screen cell (`0x20…0x7F` or `0xA0…0xFF`).
    ///
    /// - Parameter byte: A PETSCII byte.
    public static func isPrintable(_ byte: UInt8) -> Bool {
        (byte >= 0x20 && byte <= 0x7F) || byte >= 0xA0
    }
}
