import Foundation

/// Errors thrown by the SwiftPETSCII parser and renderer.
public enum PETSCIIError: Error, Equatable, Sendable, CustomStringConvertible {
    /// Input bytes are structurally invalid (e.g. empty input where content
    /// was expected).
    case invalidData
    /// The input ended mid-state in a way the parser can't reconcile.
    case truncated
    /// A PETSCII control byte was encountered that this implementation does
    /// not handle. The byte value is included for diagnostics. Callers can
    /// use this to detect tool-specific extensions.
    case unsupportedControlCode(UInt8)

    public var description: String {
        switch self {
        case .invalidData:
            return "PETSCIIError.invalidData: input bytes are structurally invalid"
        case .truncated:
            return "PETSCIIError.truncated: input ended unexpectedly"
        case .unsupportedControlCode(let b):
            return String(format: "PETSCIIError.unsupportedControlCode: byte 0x%02X not handled", b)
        }
    }
}
