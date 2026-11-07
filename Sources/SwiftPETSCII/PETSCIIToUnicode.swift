import Foundation

/// PETSCII ↔ Unicode conversion for the C64 character sets.
///
/// Graphics characters map to the Box Drawing, Block Elements, Geometric
/// Shapes and Miscellaneous Symbols blocks and, where nothing older fits, to
/// the Unicode 13 **Symbols for Legacy Computing** block (U+1FB00…U+1FBFF).
/// The table follows the KreativeKorp mapping used by the Unicode legacy
/// computing proposal (L2/19-025), with the C64 variants: `£` at `0x5C`
/// and the inverse checkerboard U+1FB96 in the lowercase set.
///
/// Rendering the legacy-computing characters requires a font that covers
/// them (e.g. recent versions of Apple's system fonts, Iosevka, or
/// "Pet Me 64").
///
/// ## Lossiness
///
/// - Reverse video has no Unicode equivalent: reversed screen codes
///   (`0x80…0xFF`) map to the character of their non-reversed form.
/// - Within one character set every screen code `0x00…0x7F` has a
///   distinct character, so screen code → Unicode → screen code is exact.
///   Some C64 glyphs that are drawn identically (screen codes `0x40`/`0x43`,
///   `0x67`/`0x6A`) still get distinct characters, inherited from the PET
///   font the mapping was designed for.
/// - PETSCII has duplicate codes for the same glyph (`0x60…0x7F` =
///   `0xC0…0xDF`, `0xE0…0xFE` = `0xA0…0xBE`, `0xFF` = `0xDE`); encoding
///   always produces the canonical code (`0xC0…`, `0xA0…`, `0xDE`).
/// - Colors, cursor movement and every other control code are dropped.
public enum PETSCIIToUnicode {

    /// Maps a PETSCII byte to the character it displays.
    ///
    /// - Parameters:
    ///   - b: A PETSCII byte.
    ///   - charset: The character set in effect (default: uppercase/graphics).
    /// - Returns: The character, or `nil` for control codes
    ///   (`0x00…0x1F`, `0x80…0x9F`).
    public static func character(
        forPETSCIIByte b: UInt8,
        charset: PETSCIICharset = .uppercaseGraphics
    ) -> Character? {
        guard PETSCIIControlCode.isPrintable(b) else { return nil }
        return character(forScreenCode: PETSCIIParser.screenCode(forPETSCII: b), charset: charset)
    }

    /// Maps a screen code (the character-ROM index, *not* a PETSCII byte)
    /// to the character it displays.
    ///
    /// - Parameters:
    ///   - s: Screen code. Reverse glyphs `0x80…0xFF` map like `s & 0x7F`.
    ///   - charset: The character set; it decides whether `0x01…0x1A` are
    ///     uppercase (set 1) or lowercase (set 2) letters and whether
    ///     `0x41…0x5A` are graphics or uppercase letters.
    /// - Returns: The mapped character (never `nil` for a valid set).
    public static func character(forScreenCode s: UInt8, charset: PETSCIICharset) -> Character? {
        let table = charset == .uppercaseGraphics ? unshifted : shifted
        guard let scalar = Unicode.Scalar(table[Int(s & 0x7F)]) else { return nil }
        return Character(scalar)
    }

    /// Converts a screen to plain text: 25 lines of 40 characters joined
    /// with `\n`, using the screen's character set.
    ///
    /// - Parameter screen: The screen.
    /// - Returns: The text. Reverse video and colors are lost.
    public static func string(from screen: PETSCIIScreen) -> String {
        var out = ""
        out.reserveCapacity(PETSCIIScreen.rows * (PETSCIIScreen.columns + 1))
        for row in 0 ..< PETSCIIScreen.rows {
            for col in 0 ..< PETSCIIScreen.columns {
                let cell = screen[column: col, row: row]
                out.append(character(forScreenCode: cell.codepoint, charset: screen.charset) ?? " ")
            }
            if row < PETSCIIScreen.rows - 1 { out.append("\n") }
        }
        return out
    }

    /// Finds the screen code that displays a character.
    ///
    /// - Parameters:
    ///   - character: The character to look up.
    ///   - charset: The character set to encode for.
    /// - Returns: The screen code (`0x00…0x7F`), or `nil` if the set has no
    ///   glyph for the character. U+00A0 maps to the shifted space `0x60`.
    public static func screenCode(for character: Character, charset: PETSCIICharset) -> UInt8? {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
            return nil
        }
        let reverse = charset == .uppercaseGraphics ? unshiftedReverse : shiftedReverse
        return reverse[scalar.value]
    }

    /// Encodes a string as printable PETSCII bytes.
    ///
    /// Each character becomes its canonical PETSCII code
    /// (``PETSCIIParser/petsciiByte(forScreenCode:)``); `"\n"` becomes
    /// `RETURN` (`0x0D`). No control codes are emitted for color, reverse
    /// video or the character set — the caller selects the set.
    ///
    /// - Parameters:
    ///   - string: The text to encode.
    ///   - charset: The character set the bytes will be displayed in.
    /// - Returns: The PETSCII bytes.
    /// - Throws: ``PETSCIIError/unencodableCharacter(_:)`` for the first
    ///   character that has no glyph in `charset`.
    public static func petsciiBytes(for string: String, charset: PETSCIICharset) throws -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(string.count)
        for character in string {
            if character == "\n" || character == "\r\n" || character == "\r" {
                out.append(0x0D)
                continue
            }
            guard let code = screenCode(for: character, charset: charset) else {
                throw PETSCIIError.unencodableCharacter(character)
            }
            out.append(PETSCIIParser.petsciiByte(forScreenCode: code))
        }
        return out
    }

    // MARK: - Tables (screen codes 0x00…0x7F)

    /// Set 1 (uppercase / graphics).
    static let unshifted: [UInt32] = {
        var t = commonLow
        t += [
            // 0x40…0x5F graphics
            0x2500, 0x2660, 0x1FB72, 0x1FB78, 0x1FB77, 0x1FB76, 0x1FB7A, 0x1FB71,
            0x1FB74, 0x256E, 0x2570, 0x256F, 0x1FB7C, 0x2572, 0x2571, 0x1FB7D,
            0x1FB7E, 0x2022, 0x1FB7B, 0x2665, 0x1FB70, 0x256D, 0x2573, 0x25CB,
            0x2663, 0x1FB75, 0x2666, 0x253C, 0x1FB8C, 0x2502, 0x03C0, 0x25E5,
        ]
        t += commonHigh
        return t
    }()

    /// Set 2 (lowercase / uppercase).
    static let shifted: [UInt32] = {
        var t = commonLow
        for i in 0x01...0x1A { t[i] = UInt32(0x60 + i) }  // a…z
        t += [0x2500]
        t += (0x41...0x5A).map { UInt32($0) }            // A…Z
        t += [0x253C, 0x1FB8C, 0x2502, 0x1FB96, 0x1FB98]
        t += commonHigh
        t[0x69] = 0x1FB99
        t[0x7A] = 0x2713
        return t
    }()

    /// Screen codes 0x00…0x3F as in set 1.
    private static let commonLow: [UInt32] = {
        var t: [UInt32] = [0x40]                         // @
        t += (0x41...0x5A).map { UInt32($0) }            // A…Z
        t += [0x5B, 0x00A3, 0x5D, 0x2191, 0x2190]        // [ £ ] ↑ ←
        t += (0x20...0x3F).map { UInt32($0) }            // space … ?
        return t
    }()

    /// Screen codes 0x60…0x7F (shared except 0x69 and 0x7A).
    private static let commonHigh: [UInt32] = [
        0x00A0, 0x258C, 0x2584, 0x2594, 0x2581, 0x258F, 0x2592, 0x2595,
        0x1FB8F, 0x25E4, 0x1FB87, 0x251C, 0x2597, 0x2514, 0x2510, 0x2582,
        0x250C, 0x2534, 0x252C, 0x2524, 0x258E, 0x258D, 0x1FB88, 0x1FB82,
        0x1FB83, 0x2583, 0x1FB7F, 0x2596, 0x259D, 0x2518, 0x2598, 0x259A,
    ]

    private static func reverseTable(_ table: [UInt32]) -> [UInt32: UInt8] {
        var map: [UInt32: UInt8] = [:]
        for (code, scalar) in table.enumerated() where map[scalar] == nil {
            map[scalar] = UInt8(code)
        }
        return map
    }

    private static let unshiftedReverse = reverseTable(unshifted)
    private static let shiftedReverse = reverseTable(shifted)
}
