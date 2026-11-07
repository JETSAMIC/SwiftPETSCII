import Foundation

/// The C64's two 256-glyph character sets.
///
/// The VIC-II displays the *whole screen* in one set at a time; the set is
/// switched by PETSCII `0x0E` (to ``uppercaseLowercase``) and `0x8E` (to
/// ``uppercaseGraphics``), or by SHIFT+Commodore on the keyboard. Each
/// glyph is 8×8 pixels (8 bytes, one per row, MSB = leftmost pixel). Glyphs
/// `0x80…0xFF` of each set are the reverse-video forms of `0x00…0x7F`.
public enum PETSCIICharset: UInt8, Sendable, CaseIterable, Codable {
    /// Set 1, "unshifted": uppercase letters and graphics. Default at boot.
    case uppercaseGraphics = 0
    /// Set 2, "shifted": lowercase letters at screen codes `0x01…0x1A`,
    /// uppercase letters at `0x41…0x5A` (where set 1 has graphics).
    case uppercaseLowercase = 1

    /// Bytes per glyph in the character ROM.
    public static let bytesPerGlyph: Int = 8
}
