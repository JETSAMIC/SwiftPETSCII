import Foundation

/// The 16 colors of the C64's VIC-II chip.
///
/// Raw values `0...15` are the hardware color indices (as used by color RAM
/// and `POKE 53281,n`). PETSCII selects the eight colors `0...7` with the
/// control codes printed on the number keys with CTRL, and colors `8...15`
/// with the Commodore key (`0x81`, `0x95`…`0x9B`); see
/// ``PETSCIIControlCode/setColor(_:)``.
public enum C64Color: UInt8, Sendable, CaseIterable, Codable {
    /// Black (0).
    case black       = 0
    /// White (1).
    case white       = 1
    /// Red (2).
    case red         = 2
    /// Cyan (3).
    case cyan        = 3
    /// Purple (4).
    case purple      = 4
    /// Green (5).
    case green       = 5
    /// Blue (6).
    case blue        = 6
    /// Yellow (7).
    case yellow      = 7
    /// Orange (8).
    case orange      = 8
    /// Brown (9).
    case brown       = 9
    /// Light red / pink (10).
    case lightRed    = 10
    /// Dark gray, "gray 1" (11).
    case darkGray    = 11
    /// Medium gray, "gray 2" (12).
    case midGray     = 12
    /// Light green (13).
    case lightGreen  = 13
    /// Light blue (14).
    case lightBlue   = 14
    /// Light gray, "gray 3" (15).
    case lightGray   = 15

    /// 8-bit-per-channel RGB for this color in the default palette,
    /// ``C64Palette/c64Wiki``.
    ///
    /// Use ``C64Palette/rgb(_:)`` to look a color up in another palette.
    public var rgb: (r: UInt8, g: UInt8, b: UInt8) {
        C64Palette.c64Wiki.rgb(self)
    }

    /// Default screen foreground at C64 boot (light blue).
    public static let defaultForeground: C64Color = .lightBlue
    /// Default screen background at C64 boot (blue).
    public static let defaultBackground: C64Color = .blue
    /// Default screen border at C64 boot (light blue).
    public static let defaultBorder: C64Color = .lightBlue
}

/// An RGB rendition of the 16 VIC-II colors.
///
/// The VIC-II outputs analog luma/chroma, so there is no single "correct"
/// RGB palette; emulators ship several. Two are provided:
///
/// - ``c64Wiki``: the bright, saturated table published on the C64-Wiki
///   (`#000000`, `#FFFFFF`, `#880000`, `#AAFFEE`, …). This is the library
///   default and what ``C64Color/rgb`` returns.
/// - ``pepto``: Philip "Pepto" Timmermann's measured PAL palette (2001),
///   VICE's `pepto-pal`, which is closer to a real PAL C64.
public struct C64Palette: Sendable, Hashable {
    /// The 16 entries, indexed by ``C64Color/rawValue``, as `0xRRGGBB`.
    public let colors: [UInt32]

    /// Creates a palette from 16 `0xRRGGBB` values.
    ///
    /// - Parameter colors: Exactly 16 entries, indexed by hardware color.
    /// - Returns: `nil` if `colors` does not hold exactly 16 entries.
    public init?(colors: [UInt32]) {
        guard colors.count == 16 else { return nil }
        self.colors = colors
    }

    private init(unchecked colors: [UInt32]) {
        self.colors = colors
    }

    /// Looks up a color.
    ///
    /// - Parameter color: The VIC-II color.
    /// - Returns: The 8-bit red, green and blue components.
    public func rgb(_ color: C64Color) -> (r: UInt8, g: UInt8, b: UInt8) {
        let value = colors[Int(color.rawValue)]
        return (UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF))
    }

    /// The C64-Wiki palette (library default).
    public static let c64Wiki = C64Palette(unchecked: [
        0x000000, 0xFFFFFF, 0x880000, 0xAAFFEE, 0xCC44CC, 0x00CC55, 0x0000AA, 0xEEEE77,
        0xDD8855, 0x664400, 0xFF7777, 0x333333, 0x777777, 0xAAFF66, 0x0088FF, 0xBBBBBB,
    ])

    /// Pepto's measured PAL palette (VICE `pepto-pal`).
    public static let pepto = C64Palette(unchecked: [
        0x000000, 0xFFFFFF, 0x68372B, 0x70A4B2, 0x6F3D86, 0x588D43, 0x352879, 0xB8C76F,
        0x6F4F25, 0x433900, 0x9A6759, 0x444444, 0x6C6C6C, 0x9AD284, 0x6C5EB5, 0x959595,
    ])
}
