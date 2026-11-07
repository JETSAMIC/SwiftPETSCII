import Foundation

/// One cell of a 40×25 PETSCII screen: a screen code plus its attributes.
///
/// On a real C64 a cell is one byte of screen RAM plus a color-RAM nibble;
/// reverse video is bit 7 of the screen-RAM byte. SwiftPETSCII keeps the
/// reverse flag separately in ``reverse`` so that ``codepoint`` normally
/// stays in `0x00…0x7F`; the hardware screen-RAM value is
/// `codepoint | (reverse ? 0x80 : 0)`.
public struct PETSCIICell: Sendable, Equatable, Hashable {
    /// The screen code (the character-ROM index — *not* the PETSCII byte).
    /// The parser stores `0x00…0x7F` for printed characters; values
    /// `0x80…0xFF` (already-reversed glyphs) appear only for control codes
    /// echoed in quote mode.
    public var codepoint: UInt8
    /// Foreground (character) color.
    public var foreground: C64Color
    /// Background color. The C64 has one background color per screen in
    /// standard text mode; the parser fills every cell with
    /// ``PETSCIIParser/Options/background``.
    public var background: C64Color
    /// Whether reverse video was on when the cell was written.
    public var reverse: Bool
    /// The character set that was active when the cell was written.
    ///
    /// A C64 displays the whole screen in one set (``PETSCIIScreen/charset``);
    /// this per-cell value is informational and is only used for rendering
    /// with ``PETSCIIRenderer/CharsetMode/perCell``.
    public var charset: PETSCIICharset

    /// Creates a cell.
    ///
    /// - Parameters:
    ///   - codepoint: Screen code; `0x20` (space) by default.
    ///   - foreground: Foreground color.
    ///   - background: Background color.
    ///   - reverse: Whether the cell is in reverse video.
    ///   - charset: Character set active when the cell was written.
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

    /// The value the C64 would hold in screen RAM for this cell:
    /// ``codepoint`` with bit 7 set when ``reverse`` is on.
    public var screenRAMValue: UInt8 {
        reverse ? codepoint | 0x80 : codepoint
    }
}

/// A 40-column by 25-row PETSCII screen — the C64's text-mode framebuffer.
public struct PETSCIIScreen: Sendable, Equatable, Hashable {
    /// Number of columns (40).
    public static let columns: Int = 40
    /// Number of rows (25).
    public static let rows: Int = 25

    /// Row-major grid of exactly `columns × rows` (1000) cells. Use the
    /// ``subscript(column:row:)`` accessor to modify cells.
    public internal(set) var cells: [PETSCIICell]

    /// Border color (not part of the 320×200 rendered image).
    public var border: C64Color

    /// The character set the whole screen is displayed in — the set that
    /// was active when the frame was captured.
    public var charset: PETSCIICharset

    /// Creates a blank screen (spaces in light blue on `background`).
    ///
    /// - Parameters:
    ///   - background: Background color of every cell.
    ///   - border: Border color.
    ///   - charset: Character set of the screen.
    public init(
        background: C64Color = .blue,
        border: C64Color = .lightBlue,
        charset: PETSCIICharset = .uppercaseGraphics
    ) {
        let blank = PETSCIICell(
            codepoint: 0x20,
            foreground: .lightBlue,
            background: background,
            reverse: false,
            charset: charset
        )
        self.cells = Array(repeating: blank, count: Self.columns * Self.rows)
        self.border = border
        self.charset = charset
    }

    /// Accesses the cell at a position.
    ///
    /// - Parameters:
    ///   - col: Column, `0..<40`.
    ///   - row: Row, `0..<25`.
    /// - Precondition: Both coordinates are in range (like `Array`
    ///   indexing, out-of-range access traps).
    public subscript(column col: Int, row row: Int) -> PETSCIICell {
        get {
            precondition((0..<Self.columns).contains(col) && (0..<Self.rows).contains(row), "cell out of range")
            return cells[row * Self.columns + col]
        }
        set {
            precondition((0..<Self.columns).contains(col) && (0..<Self.rows).contains(row), "cell out of range")
            cells[row * Self.columns + col] = newValue
        }
    }

    /// `true` if any cell holds a non-space screen code or is in reverse
    /// video. The parser uses this to skip empty frames.
    public var hasContent: Bool {
        cells.contains { cell in
            cell.codepoint != 0x20 || cell.reverse
        }
    }
}
