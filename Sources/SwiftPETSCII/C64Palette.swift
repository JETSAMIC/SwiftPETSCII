import Foundation

/// Pepto-corrected 16-color C64 palette — the de-facto reference for modern
/// PETSCII rendering. Index values 0..15 match the C64 hardware color
/// register encoding (e.g. POKE 53281,n).
///
/// Source: Philip "Pepto" Timmermann's "Colodore" / VICE PAL defaults.
/// https://www.pepto.de/projects/colorvic/
public enum C64Color: UInt8, Sendable, CaseIterable {
    case black       = 0
    case white       = 1
    case red         = 2
    case cyan        = 3
    case purple      = 4
    case green       = 5
    case blue        = 6
    case yellow      = 7
    case orange      = 8
    case brown       = 9
    case lightRed    = 10
    case darkGray    = 11
    case midGray     = 12
    case lightGreen  = 13
    case lightBlue   = 14
    case lightGray   = 15

    /// RGB tuple (8-bit per channel) for this palette index.
    public var rgb: (r: UInt8, g: UInt8, b: UInt8) {
        switch self {
        case .black:       return (0,   0,   0)
        case .white:       return (255, 255, 255)
        case .red:         return (136, 0,   0)
        case .cyan:        return (170, 255, 238)
        case .purple:      return (204, 68,  204)
        case .green:       return (0,   204, 85)
        case .blue:        return (0,   0,   170)
        case .yellow:      return (238, 238, 119)
        case .orange:      return (221, 136, 85)
        case .brown:       return (102, 68,  0)
        case .lightRed:    return (255, 119, 119)
        case .darkGray:    return (51,  51,  51)
        case .midGray:     return (119, 119, 119)
        case .lightGreen:  return (170, 255, 102)
        case .lightBlue:   return (0,   136, 255)
        case .lightGray:   return (187, 187, 187)
        }
    }

    /// Default screen foreground at C64 boot (light blue).
    public static let defaultForeground: C64Color = .lightBlue
    /// Default screen background at C64 boot (blue).
    public static let defaultBackground: C64Color = .blue
    /// Default screen border (light blue).
    public static let defaultBorder: C64Color = .lightBlue
}
