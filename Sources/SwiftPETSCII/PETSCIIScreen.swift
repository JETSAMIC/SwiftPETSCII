import Foundation

/// One cell of a 40x25 PETSCII screen — a single character glyph plus its
/// rendering attributes.
public struct PETSCIICell: Sendable, Equatable {
    /// The raw screen-code (NOT PETSCII byte — the parser translates
    /// PETSCII printable bytes into the character-ROM index using the
    /// standard PETSCII→screencode mapping).
    public var codepoint: UInt8
    /// Foreground color for this cell.
    public var foreground: C64Color
    /// Background color for this cell (typically constant across a frame,
    /// but PETSCII art tools occasionally vary per-cell).
    public var background: C64Color
    /// Whether reverse-video applies (fg/bg swapped at render time).
    public var reverse: Bool
    /// Which character ROM bank to look this glyph up in.
    public var charset: PETSCIICharset

    public init(
        codepoint: UInt8 = 0x20,
        foreground: C64Color = .lightBlue,
        background: C64Color = .blue,
        reverse: Bool = false,
        charset: PETSCIICharset = .uppercaseGraphics
    ) {
        self.codepoint  = codepoint
        self.foreground = foreground
        self.background = background
        self.reverse    = reverse
        self.charset    = charset
    }
}

/// A 40-column by 25-row PETSCII screen — the C64's text-mode framebuffer.
public struct PETSCIIScreen: Sendable, Equatable {
    /// Standard C64 text-mode dimensions.
    public static let columns: Int = 40
    public static let rows: Int = 25

    /// Row-major grid of 1000 cells.
    public var cells: [PETSCIICell]

    /// Border color (typically uniform; tracked separately from any cell).
    public var border: C64Color

    public init(background: C64Color = .blue, border: C64Color = .lightBlue) {
        let blank = PETSCIICell(
            codepoint: 0x20,      // space (screen-code blank)
            foreground: .lightBlue,
            background: background,
            reverse: false,
            charset: .uppercaseGraphics
        )
        self.cells = Array(repeating: blank, count: Self.columns * Self.rows)
        self.border = border
    }

    public subscript(column col: Int, row row: Int) -> PETSCIICell {
        get { cells[row * Self.columns + col] }
        set { cells[row * Self.columns + col] = newValue }
    }

    /// Has any cell been modified from a freshly-initialized blank state?
    /// Used by the parser to decide whether to emit an "empty" frame.
    public var hasContent: Bool {
        // Cheap check: any non-space codepoint, OR any non-default-fg color,
        // OR any reverse cell. We compare codepoint first since it's the
        // cheapest scalar comparison.
        return cells.contains { cell in
            cell.codepoint != 0x20 || cell.reverse
        }
    }
}
