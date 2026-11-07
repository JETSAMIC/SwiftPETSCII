import Foundation
import CoreGraphics

/// Top-level entry point: decodes a raw PETSCII byte stream — typically a
/// C64 `SEQ` file or a BBS capture — into frames.
///
/// Static streams yield a single frame; streams that clear the screen
/// (`CLR`, `0x93`) between screens yield one frame per screen. Container
/// formats that are *not* raw PETSCII streams (PRG screen dumps, Marq's
/// PETSCII Editor `.c`/`.pet` exports, Petmate `.petmate`, `.d64` disk
/// images) are not decoded.
public struct PETSCIIDocument: Sendable {

    /// Every decoded frame, in source order.
    public let frames: [PETSCIIFrame]

    /// `true` when this document has more than one frame.
    public var isAnimated: Bool { frames.count > 1 }

    /// Sum of every frame's ``PETSCIIFrame/duration``, in seconds.
    public var totalDuration: TimeInterval {
        frames.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Init

    /// Decodes raw PETSCII bytes.
    ///
    /// - Parameters:
    ///   - data: The PETSCII stream.
    ///   - options: Parser configuration.
    /// - Throws: ``PETSCIIError/invalidData`` for empty input, or any error
    ///   from ``PETSCIIParser/parse(_:)``.
    public init(
        data: Data,
        options: PETSCIIParser.Options = PETSCIIParser.Options()
    ) throws {
        guard !data.isEmpty else { throw PETSCIIError.invalidData }
        let parser = PETSCIIParser(options: options)
        let bytes = [UInt8](data)
        self.frames = try parser.parse(bytes)
    }

    /// Loads and decodes a file.
    ///
    /// - Parameters:
    ///   - url: File URL of a raw PETSCII stream (e.g. a `SEQ` file).
    ///   - options: Parser configuration.
    /// - Throws: Any error from `Data(contentsOf:)`, ``PETSCIIError/invalidData``
    ///   for an empty file, or any error from ``PETSCIIParser/parse(_:)``.
    public init(
        url: URL,
        options: PETSCIIParser.Options = PETSCIIParser.Options()
    ) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: data, options: options)
    }

    /// Decodes raw PETSCII bytes.
    ///
    /// - Parameters:
    ///   - bytes: The PETSCII stream.
    ///   - options: Parser configuration.
    /// - Throws: ``PETSCIIError/invalidData`` for empty input, or any error
    ///   from ``PETSCIIParser/parse(_:)``.
    public init(
        bytes: [UInt8],
        options: PETSCIIParser.Options = PETSCIIParser.Options()
    ) throws {
        guard !bytes.isEmpty else { throw PETSCIIError.invalidData }
        let parser = PETSCIIParser(options: options)
        self.frames = try parser.parse(bytes)
    }
}
