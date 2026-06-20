import Foundation

/// Walks a raw PETSCII byte stream and produces zero or more
/// `PETSCIIFrame`s. The parser maintains a screen-state machine (cursor
/// position, foreground color, charset, reverse-video flag) and dispatches
/// control codes through `PETSCIIControlCode.decode`.
///
/// Frame boundaries are emitted on `CHR$(147)` (0x93, clear-screen). The
/// implicit final frame is emitted at EOF if the screen has any content.
public struct PETSCIIParser: Sendable {

    /// Parser configuration.
    public struct Options: Sendable {
        /// Background color to seed each new frame with. C64 default = blue.
        public var background: C64Color
        /// Initial foreground color before any control code sets one.
        /// C64 default = light blue.
        public var foreground: C64Color
        /// Initial charset before any switch. C64 default = uppercase / graphics.
        public var charset: PETSCIICharset
        /// Default per-frame duration when no explicit timing is present
        /// in the source. 100ms is a common animation cadence.
        public var defaultFrameDuration: TimeInterval

        public init(
            background: C64Color = .blue,
            foreground: C64Color = .lightBlue,
            charset: PETSCIICharset = .uppercaseGraphics,
            defaultFrameDuration: TimeInterval = 0.1
        ) {
            self.background = background
            self.foreground = foreground
            self.charset = charset
            self.defaultFrameDuration = defaultFrameDuration
        }
    }

    public let options: Options

    public init(options: Options = Options()) {
        self.options = options
    }

    /// Parse a complete PETSCII byte stream into one or more frames.
    public func parse(_ bytes: [UInt8]) throws -> [PETSCIIFrame] {
        guard !bytes.isEmpty else { return [] }

        var frames: [PETSCIIFrame] = []
        var screen = PETSCIIScreen(background: options.background, border: .lightBlue)
        var cursorCol = 0
        var cursorRow = 0
        var fg = options.foreground
        var charset = options.charset
        var reverse = false

        // Helper: finalize current frame (if it has content) and reset state.
        func flushFrame() {
            if screen.hasContent {
                frames.append(PETSCIIFrame(
                    screen: screen,
                    duration: options.defaultFrameDuration
                ))
            }
            screen = PETSCIIScreen(background: options.background, border: .lightBlue)
            cursorCol = 0
            cursorRow = 0
            // NB: C64 hardware DOES clear color on CHR$(147) but does NOT
            // reset the currently-selected text-color register. We mirror
            // that — fg/charset/reverse persist across clears.
        }

        // Helper: write a single printable PETSCII byte at the cursor and
        // advance.
        func writePrintable(_ b: UInt8) {
            guard cursorRow < PETSCIIScreen.rows else { return }
            let screenCode = PETSCIIParser.petsciiToScreenCode(b)
            var cell = screen[column: cursorCol, row: cursorRow]
            cell.codepoint  = screenCode
            cell.foreground = fg
            cell.background = options.background
            cell.reverse    = reverse
            cell.charset    = charset
            screen[column: cursorCol, row: cursorRow] = cell
            advanceCursor()
        }

        func advanceCursor() {
            cursorCol += 1
            if cursorCol >= PETSCIIScreen.columns {
                cursorCol = 0
                cursorRow += 1
                // Past the bottom: stay clamped (no auto-scroll for art).
                // The next clear-screen will start a fresh frame.
                if cursorRow >= PETSCIIScreen.rows {
                    cursorRow = PETSCIIScreen.rows - 1
                }
            }
        }

        for byte in bytes {
            if let code = PETSCIIControlCode.decode(byte) {
                switch code {
                case .setColor(let c):
                    fg = c
                case .switchToUppercaseGraphics:
                    charset = .uppercaseGraphics
                case .switchToUppercaseLowercase:
                    charset = .uppercaseLowercase
                case .reverseOn:
                    reverse = true
                case .reverseOff:
                    reverse = false
                case .home:
                    cursorCol = 0
                    cursorRow = 0
                case .clearScreen:
                    flushFrame()
                case .cursorUp:
                    if cursorRow > 0 { cursorRow -= 1 }
                case .cursorDown:
                    if cursorRow < PETSCIIScreen.rows - 1 { cursorRow += 1 }
                case .cursorLeft:
                    if cursorCol > 0 {
                        cursorCol -= 1
                    } else if cursorRow > 0 {
                        cursorCol = PETSCIIScreen.columns - 1
                        cursorRow -= 1
                    }
                case .cursorRight:
                    advanceCursor()
                case .insert:
                    // Shift the rest of the current row right; blank the
                    // cursor cell.
                    if cursorRow < PETSCIIScreen.rows {
                        let rowStart = cursorRow * PETSCIIScreen.columns
                        let lastIdx = rowStart + PETSCIIScreen.columns - 1
                        let curIdx = rowStart + cursorCol
                        if curIdx < lastIdx {
                            for i in stride(from: lastIdx, to: curIdx, by: -1) {
                                screen.cells[i] = screen.cells[i - 1]
                            }
                        }
                        var blank = PETSCIICell()
                        blank.background = options.background
                        screen.cells[curIdx] = blank
                    }
                case .delete:
                    // Shift the rest of the current row left; blank last
                    // cell.
                    if cursorRow < PETSCIIScreen.rows {
                        let rowStart = cursorRow * PETSCIIScreen.columns
                        let lastIdx = rowStart + PETSCIIScreen.columns - 1
                        let curIdx = rowStart + cursorCol
                        if curIdx < lastIdx {
                            for i in curIdx ..< lastIdx {
                                screen.cells[i] = screen.cells[i + 1]
                            }
                        }
                        var blank = PETSCIICell()
                        blank.background = options.background
                        screen.cells[lastIdx] = blank
                    }
                case .newline, .lineFeed:
                    cursorCol = 0
                    if cursorRow < PETSCIIScreen.rows - 1 {
                        cursorRow += 1
                    }
                }
            } else if PETSCIIControlCode.isPrintable(byte) {
                writePrintable(byte)
            } else {
                // Unknown control byte. Per the spec we treat unknown
                // control codes as no-ops (lots of files in the wild have
                // padding / stray bytes); strict callers can still inspect
                // the input themselves.
                continue
            }
        }

        // EOF: finalize last frame if non-empty.
        if screen.hasContent {
            frames.append(PETSCIIFrame(
                screen: screen,
                duration: options.defaultFrameDuration
            ))
        }

        return frames
    }

    // MARK: - PETSCII → screen-code mapping

    /// Translate a printable PETSCII byte into its screen-code (the index
    /// used to look up a glyph in `C64CharROM.chargen`).
    ///
    /// Standard C64 mapping per the Programmer's Reference Guide:
    ///   PETSCII 0x20..0x3F  →  screen 0x20..0x3F   (space, punctuation, digits)
    ///   PETSCII 0x40..0x5F  →  screen 0x00..0x1F   (uppercase letters + a few syms)
    ///   PETSCII 0x60..0x7F  →  screen 0x40..0x5F   (set-2 lowercase area or set-1 graphics)
    ///   PETSCII 0xA0..0xBF  →  screen 0x60..0x7F   (graphics block)
    ///   PETSCII 0xC0..0xFE  →  screen 0x40..0x7E   (alt uppercase / mirror range)
    ///   PETSCII 0xFF        →  screen 0x5E         (pi)
    @inlinable
    static func petsciiToScreenCode(_ b: UInt8) -> UInt8 {
        switch b {
        case 0x20...0x3F:
            return b
        case 0x40...0x5F:
            return b - 0x40
        case 0x60...0x7F:
            return b - 0x20
        case 0xA0...0xBF:
            return b - 0x40
        case 0xC0...0xFE:
            return b - 0x80
        case 0xFF:
            return 0x5E
        default:
            return 0x20  // space; shouldn't be reachable for printable input
        }
    }
}

// MARK: - Free-function alias for tests / direct callers
extension PETSCIIParser {
    /// Static convenience that avoids exposing the file-private `static`
    /// helper to callers needing a quick PETSCII→screencode probe.
    public static func screenCode(forPETSCII byte: UInt8) -> UInt8 {
        return petsciiToScreenCode(byte)
    }
}
