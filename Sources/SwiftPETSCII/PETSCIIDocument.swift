import Foundation
import CoreGraphics

/// Top-level public entry point. Load a PETSCII file (`.c`, `.pet`, `.seq`,
/// or any raw PETSCII byte stream) and read out its decoded frames.
///
/// Static files contain a single frame; animated files (the parser detects
/// these by the presence of one or more `CHR$(147)` clear-screen control
/// codes) contain multiple.
public struct PETSCIIDocument: Sendable {

    /// Every decoded frame, in source order.
    public let frames: [PETSCIIFrame]

    /// `true` when this document has more than one frame — i.e. there was
    /// at least one frame-boundary clear-screen in the source.
    public var isAnimated: Bool { frames.count > 1 }

    /// Sum of `.duration` across every frame. Useful for driving a UI
    /// timer that loops the whole animation.
    public var totalDuration: TimeInterval {
        frames.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Init

    /// Decode from raw PETSCII bytes.
    /// - Parameters:
    ///   - data: a buffer of PETSCII bytes.
    ///   - options: parser configuration (initial fg/bg, default frame duration).
    /// - Throws: `PETSCIIError` if the input cannot be parsed.
    public init(
        data: Data,
        options: PETSCIIParser.Options = PETSCIIParser.Options()
    ) throws {
        guard !data.isEmpty else { throw PETSCIIError.invalidData }
        let parser = PETSCIIParser(options: options)
        let bytes = [UInt8](data)
        self.frames = try parser.parse(bytes)
    }

    /// Convenience: load from a file URL.
    public init(
        url: URL,
        options: PETSCIIParser.Options = PETSCIIParser.Options()
    ) throws {
        let data = try Data(contentsOf: url)
        try self.init(data: data, options: options)
    }

    /// Convenience for callers that already have a `[UInt8]`.
    public init(
        bytes: [UInt8],
        options: PETSCIIParser.Options = PETSCIIParser.Options()
    ) throws {
        guard !bytes.isEmpty else { throw PETSCIIError.invalidData }
        let parser = PETSCIIParser(options: options)
        self.frames = try parser.parse(bytes)
    }
}
