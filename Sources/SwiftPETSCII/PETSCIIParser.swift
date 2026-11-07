import Foundation

/// Interprets a raw PETSCII byte stream (a C64 `SEQ` file, a BBS capture, or
/// anything else written with `PRINT`/`CHROUT`) the way the C64 KERNAL
/// screen editor would, and captures the resulting screens as
/// ``PETSCIIFrame``s.
///
/// ## Emulated behaviour
///
/// - Printable bytes are converted to screen codes
///   (``screenCode(forPETSCII:)``) and written at the cursor with the
///   current color and reverse state; the cursor wraps at column 40.
/// - All C64 screen control codes in ``PETSCIIControlCode`` are executed.
///   `RETURN` (`0x0D`/`0x8D`) also turns reverse video and quote mode off.
/// - Output past the bottom row scrolls the screen up. The scroll caused by
///   writing the bottom-right cell is deferred until more output needs the
///   new line, so a full 1000-character screen is captured intact (a real
///   C64 scrolls immediately).
/// - Quote mode and insert mode: after an odd number of `"` characters, or
///   while inserted blanks remain, control codes are *displayed* as
///   reverse-video glyphs instead of executed — exactly as on a C64.
///   Disable with ``Options/emulateQuoteMode``.
/// - The character set is a property of the whole screen
///   (``PETSCIIScreen/charset``); each cell additionally records the set
///   active when it was written.
/// - `CLR` (`0x93`) ends the current frame (if it has content) and starts a
///   new, blank one. The final screen is emitted at the end of the input.
///
/// Insert and delete act on the 40-column physical line; the C64's 80-column
/// logical-line linking is not modelled.
public struct PETSCIIParser: Sendable {

    /// Parser configuration.
    public struct Options: Sendable, Equatable {
        /// Background color of every cell. C64 default: blue.
        public var background: C64Color
        /// Text color before any color code. C64 default: light blue.
        public var foreground: C64Color
        /// Character set before any `0x0E`/`0x8E`. C64 default: uppercase/graphics.
        public var charset: PETSCIICharset
        /// Duration assigned to every frame, in seconds. PETSCII streams
        /// carry no timing information.
        public var defaultFrameDuration: TimeInterval
        /// Emulate the screen editor's quote and insert modes (default
        /// `true`). When `false`, control codes are always executed.
        public var emulateQuoteMode: Bool
        /// Throw ``PETSCIIError/unsupportedControlCode(_:offset:)`` for
        /// control bytes with no C64 meaning instead of ignoring them
        /// (default `false`).
        public var strict: Bool
        /// Maximum number of frames to decode before throwing
        /// ``PETSCIIError/frameLimitExceeded(limit:)``. Each frame holds 1000
        /// cells, so this bounds memory use on hostile input. Default 10,000.
        public var maxFrames: Int

        /// Creates parser options.
        ///
        /// - Parameters:
        ///   - background: Background color of every cell.
        ///   - foreground: Initial text color.
        ///   - charset: Initial character set.
        ///   - defaultFrameDuration: Duration of every frame, in seconds.
        ///   - emulateQuoteMode: Whether to emulate quote and insert modes.
        ///   - strict: Whether unknown control bytes throw.
        ///   - maxFrames: Maximum number of frames to decode.
        public init(
            background: C64Color = .blue,
            foreground: C64Color = .lightBlue,
            charset: PETSCIICharset = .uppercaseGraphics,
            defaultFrameDuration: TimeInterval = 0.1,
            emulateQuoteMode: Bool = true,
            strict: Bool = false,
            maxFrames: Int = 10_000
        ) {
            self.background = background
            self.foreground = foreground
            self.charset = charset
            self.defaultFrameDuration = defaultFrameDuration
            self.emulateQuoteMode = emulateQuoteMode
            self.strict = strict
            self.maxFrames = maxFrames
        }
    }

    /// The configuration used by ``parse(_:)``.
    public let options: Options

    /// Creates a parser.
    ///
    /// - Parameter options: Parser configuration.
    public init(options: Options = Options()) {
        self.options = options
    }

    /// Parses a complete PETSCII byte stream.
    ///
    /// - Parameter bytes: The stream. Any byte sequence is accepted.
    /// - Returns: One frame per non-empty screen, in order. Empty input
    ///   yields no frames.
    /// - Throws: ``PETSCIIError/frameLimitExceeded(limit:)`` when the
    ///   stream holds more than ``Options/maxFrames`` frames, and — in
    ///   strict mode — ``PETSCIIError/unsupportedControlCode(_:offset:)``.
    public func parse(_ bytes: [UInt8]) throws -> [PETSCIIFrame] {
        var machine = ScreenEditor(options: options)
        for (offset, byte) in bytes.enumerated() {
            try machine.output(byte, at: offset)
        }
        try machine.flushFrame()
        return machine.frames
    }

    // MARK: - PETSCII ↔ screen-code mapping

    /// Translates a PETSCII byte into the screen code the C64 displays for
    /// it (the character-ROM index).
    ///
    /// | PETSCII | Screen code | Notes |
    /// |---|---|---|
    /// | `0x20…0x3F` | `0x20…0x3F` | space, digits, punctuation |
    /// | `0x40…0x5F` | `0x00…0x1F` | `@`, letters, `[ £ ] ↑ ←` |
    /// | `0x60…0x7F` | `0x40…0x5F` | duplicate of `0xC0…0xDF` |
    /// | `0xA0…0xBF` | `0x60…0x7F` | graphics |
    /// | `0xC0…0xDF` | `0x40…0x5F` | graphics (set 1) / uppercase (set 2) |
    /// | `0xE0…0xFE` | `0x60…0x7E` | duplicate of `0xA0…0xBE` |
    /// | `0xFF` | `0x5E` | π in set 1 (duplicate of `0xDE`) |
    /// | `0x00…0x1F` | `0x80…0x9F` | control: reverse glyph shown in quote mode |
    /// | `0x80…0x9F` | `0xC0…0xDF` | control: reverse glyph shown in quote mode |
    ///
    /// - Parameter byte: Any PETSCII byte.
    /// - Returns: The screen code.
    public static func screenCode(forPETSCII byte: UInt8) -> UInt8 {
        switch byte {
        case 0x00...0x1F: return byte | 0x80
        case 0x20...0x3F: return byte
        case 0x40...0x5F: return byte - 0x40
        case 0x60...0x7F: return byte - 0x20
        case 0x80...0x9F: return byte + 0x40
        case 0xA0...0xBF: return byte - 0x40
        case 0xC0...0xFE: return byte - 0x80
        default:          return 0x5E  // 0xFF
        }
    }

    /// Translates a screen code back into the canonical PETSCII byte that
    /// prints it.
    ///
    /// Duplicated ranges are folded onto their canonical codes: screen
    /// codes `0x40…0x5F` give `0xC0…0xDF` (never `0x60…0x7F`), `0x60…0x7F`
    /// give `0xA0…0xBF` (never `0xE0…0xFF`), and π gives `0xDE` (never
    /// `0xFF`). Reverse glyphs (`0x80…0xFF`) give the PETSCII byte of their
    /// non-reversed form; the reverse state must be expressed with
    /// `0x12`/`0x92`.
    ///
    /// - Parameter screenCode: A screen code.
    /// - Returns: The canonical printable PETSCII byte.
    public static func petsciiByte(forScreenCode screenCode: UInt8) -> UInt8 {
        let code = screenCode & 0x7F
        switch code {
        case 0x00...0x1F: return code + 0x40
        case 0x20...0x3F: return code
        case 0x40...0x5F: return code + 0x80
        default:          return code + 0x40  // 0x60...0x7F → 0xA0...0xBF
        }
    }
}

// MARK: - Screen editor state machine

/// The C64 screen editor, reduced to what affects the visible screen.
private struct ScreenEditor {
    let options: PETSCIIParser.Options
    var frames: [PETSCIIFrame] = []

    /// Physical cell storage; logical row `r` lives at physical row
    /// `(top + r) % rows`, so a scroll is O(columns).
    var cells: [PETSCIICell]
    var top = 0
    var col = 0
    /// `0..<rows`, or `rows` when a scroll is pending.
    var row = 0
    var foreground: C64Color
    var charset: PETSCIICharset
    var reverse = false
    var quoteMode = false
    var insertCount = 0

    static let columns = PETSCIIScreen.columns
    static let rows = PETSCIIScreen.rows

    init(options: PETSCIIParser.Options) {
        self.options = options
        self.foreground = options.foreground
        self.charset = options.charset
        self.cells = []
        self.cells = Array(repeating: blank, count: Self.columns * Self.rows)
    }

    var blank: PETSCIICell {
        PETSCIICell(codepoint: 0x20, foreground: .lightBlue, background: options.background,
                    reverse: false, charset: charset)
    }

    func index(_ c: Int, _ r: Int) -> Int {
        ((top + r) % Self.rows) * Self.columns + c
    }

    // MARK: Output

    mutating func output(_ byte: UInt8, at offset: Int) throws {
        // RETURN is never echoed.
        if byte == 0x0D || byte == 0x8D {
            carriageReturn()
            return
        }

        let printable = PETSCIIControlCode.isPrintable(byte)

        if !printable, options.emulateQuoteMode, quoteMode || insertCount > 0 {
            // DEL still deletes in quote mode, but is echoed in insert mode.
            if !(byte == 0x14 && insertCount == 0) {
                put(PETSCIIParser.screenCode(forPETSCII: byte), reverse: false)
                return
            }
        }

        if printable {
            put(PETSCIIParser.screenCode(forPETSCII: byte), reverse: reverse)
            if byte == 0x22, options.emulateQuoteMode {
                quoteMode.toggle()
            }
            return
        }

        guard let code = PETSCIIControlCode.decode(byte) else {
            if options.strict {
                throw PETSCIIError.unsupportedControlCode(byte, offset: offset)
            }
            return
        }
        try execute(code)
    }

    mutating func execute(_ code: PETSCIIControlCode) throws {
        switch code {
        case .setColor(let color):
            foreground = color
        case .switchToUppercaseGraphics:
            charset = .uppercaseGraphics
        case .switchToUppercaseLowercase:
            charset = .uppercaseLowercase
        case .lockCharset, .unlockCharset, .lineFeed:
            break
        case .reverseOn:
            reverse = true
        case .reverseOff:
            reverse = false
        case .home:
            realizePendingScroll()
            col = 0
            row = 0
        case .clearScreen:
            try flushFrame()
            cells = Array(repeating: blank, count: Self.columns * Self.rows)
            top = 0
            col = 0
            row = 0
        case .cursorUp:
            realizePendingScroll()
            if row > 0 { row -= 1 }
        case .cursorDown:
            realizePendingScroll()
            row += 1
        case .cursorLeft:
            realizePendingScroll()
            if col > 0 {
                col -= 1
            } else if row > 0 {
                col = Self.columns - 1
                row -= 1
            }
        case .cursorRight:
            realizePendingScroll()
            advance()
        case .insert:
            realizePendingScroll()
            var c = Self.columns - 1
            while c > col {
                cells[index(c, row)] = cells[index(c - 1, row)]
                c -= 1
            }
            cells[index(col, row)] = blank
            if options.emulateQuoteMode, insertCount < Self.columns {
                insertCount += 1
            }
        case .delete:
            realizePendingScroll()
            guard col > 0 else { return }
            col -= 1
            for c in col..<(Self.columns - 1) {
                cells[index(c, row)] = cells[index(c + 1, row)]
            }
            cells[index(Self.columns - 1, row)] = blank
        case .newline, .shiftedReturn:
            carriageReturn()
        }
    }

    mutating func carriageReturn() {
        realizePendingScroll()
        col = 0
        row += 1
        reverse = false
        quoteMode = false
        insertCount = 0
    }

    /// Writes one screen code at the cursor and advances.
    mutating func put(_ screenCode: UInt8, reverse: Bool) {
        realizePendingScroll()
        cells[index(col, row)] = PETSCIICell(
            codepoint: screenCode,
            foreground: foreground,
            background: options.background,
            reverse: reverse,
            charset: charset
        )
        if insertCount > 0 { insertCount -= 1 }
        advance()
    }

    mutating func advance() {
        col += 1
        if col >= Self.columns {
            col = 0
            row += 1
        }
    }

    /// Performs the scroll left pending by a cursor below the last row.
    mutating func realizePendingScroll() {
        guard row >= Self.rows else { return }
        // Scroll up one line: the old top row becomes the new bottom row.
        let oldTop = top
        top = (top + 1) % Self.rows
        let blankCell = blank
        for c in 0..<Self.columns {
            cells[oldTop * Self.columns + c] = blankCell
        }
        row = Self.rows - 1
    }

    // MARK: Frames

    mutating func flushFrame() throws {
        var screen = PETSCIIScreen(background: options.background, border: .lightBlue, charset: charset)
        for r in 0..<Self.rows {
            let base = ((top + r) % Self.rows) * Self.columns
            for c in 0..<Self.columns {
                screen.cells[r * Self.columns + c] = cells[base + c]
            }
        }
        guard screen.hasContent else { return }
        guard frames.count < options.maxFrames else {
            throw PETSCIIError.frameLimitExceeded(limit: options.maxFrames)
        }
        frames.append(PETSCIIFrame(screen: screen, duration: options.defaultFrameDuration))
    }
}
