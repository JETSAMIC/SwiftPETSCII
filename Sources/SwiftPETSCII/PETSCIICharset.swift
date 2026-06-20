import Foundation

/// The C64 supports two distinct 256-glyph character sets, switched at
/// runtime by the user (SHIFT+C= on real hardware) or programmatically by
/// PETSCII control codes 0x0E (lowercase / set 2) and 0x8E (uppercase /
/// graphics / set 1). Each glyph is 8x8 pixels (8 bytes, one byte per row,
/// MSB = leftmost pixel).
public enum PETSCIICharset: UInt8, Sendable, CaseIterable {
    /// Set 1: uppercase letters + graphics characters. Default at boot.
    case uppercaseGraphics = 0
    /// Set 2: uppercase + lowercase letters (graphics chars replaced by
    /// lowercase letters in the 0x01..0x1A range).
    case uppercaseLowercase = 1

    /// Bytes per glyph in the character ROM.
    public static let bytesPerGlyph: Int = 8
}
