import Foundation

/// Errors thrown by SwiftPETSCII.
///
/// A raw PETSCII stream has no structure that can be "malformed": every
/// byte sequence is a valid sequence of characters and control codes. The
/// parser therefore only fails on empty input, when a configured resource
/// limit is exceeded, or — in strict mode — on a byte with no C64 meaning.
public enum PETSCIIError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The input was empty. Thrown by ``PETSCIIDocument``.
    case invalidData
    /// Strict mode only (``PETSCIIParser/Options/strict``): the byte at
    /// `offset` is a control code with no C64 screen meaning (for example
    /// a C128-only code such as `0x07` bell or `0x1B` escape).
    case unsupportedControlCode(UInt8, offset: Int)
    /// The stream would produce more than ``PETSCIIParser/Options/maxFrames``
    /// frames.
    case frameLimitExceeded(limit: Int)
    /// A character passed to ``PETSCIIToUnicode/petsciiBytes(for:charset:)``
    /// has no representation in the requested character set.
    case unencodableCharacter(Character)

    /// A human-readable description of the error.
    public var description: String {
        switch self {
        case .invalidData:
            return "PETSCIIError.invalidData: input is empty"
        case .unsupportedControlCode(let byte, let offset):
            let digits = String(byte, radix: 16, uppercase: true)
            return "PETSCIIError.unsupportedControlCode: byte 0x\(digits.count == 1 ? "0" + digits : digits) at offset \(offset) has no C64 screen meaning"
        case .frameLimitExceeded(let limit):
            return "PETSCIIError.frameLimitExceeded: stream holds more than \(limit) frames"
        case .unencodableCharacter(let character):
            return "PETSCIIError.unencodableCharacter: \(String(reflecting: character)) cannot be encoded"
        }
    }
}
