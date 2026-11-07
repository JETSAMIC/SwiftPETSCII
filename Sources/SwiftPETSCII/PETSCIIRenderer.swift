import Foundation
import CoreGraphics

/// Rasterizes a ``PETSCIIScreen`` to a 320×200 RGBA8 `CGImage` using the
/// embedded C64 character ROM.
///
/// One cell is 8×8 pixels and no scaling is applied; scale up with
/// `interpolationQuality = .none` for crisp nearest-neighbour zoom. The
/// border is not drawn.
///
/// Reverse video is rendered the way the VIC-II does it: by drawing the
/// ROM's reverse glyph (screen code with bit 7 set) in the normal
/// foreground/background colors. This matters for the few glyphs whose ROM
/// reverse form is not an exact inversion (notably reverse `@`).
public enum PETSCIIRenderer {

    /// How the character set of each cell is chosen.
    public enum CharsetMode: Sendable, Equatable {
        /// Every cell uses ``PETSCIIScreen/charset`` — what a C64 displays.
        case screen
        /// Every cell uses its own ``PETSCIICell/charset`` (the set active
        /// when it was written). Not achievable on real hardware, but useful
        /// for editors that mix sets.
        case perCell
    }

    /// Image width in pixels: 40 columns × 8 = 320.
    public static let pixelWidth: Int  = PETSCIIScreen.columns * C64CharROM.bytesPerGlyph
    /// Image height in pixels: 25 rows × 8 = 200.
    public static let pixelHeight: Int = PETSCIIScreen.rows    * C64CharROM.bytesPerGlyph

    /// Renders a screen to RGBA8 pixels.
    ///
    /// - Parameters:
    ///   - screen: The screen to render.
    ///   - palette: RGB palette for the 16 colors.
    ///   - charsetMode: How each cell's character set is chosen.
    /// - Returns: `320 × 200 × 4` bytes, row-major, RGBA with alpha 255.
    public static func pixels(
        _ screen: PETSCIIScreen,
        palette: C64Palette = .c64Wiki,
        charsetMode: CharsetMode = .screen
    ) -> [UInt8] {
        let bytesPerPixel = 4
        let bytesPerRow = pixelWidth * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: pixelWidth * pixelHeight * bytesPerPixel)

        for row in 0 ..< PETSCIIScreen.rows {
            for col in 0 ..< PETSCIIScreen.columns {
                let cell = screen[column: col, row: row]
                let charset = charsetMode == .screen ? screen.charset : cell.charset
                let glyph = C64CharROM.glyph(charset: charset, codepoint: cell.screenRAMValue)
                let fg = palette.rgb(cell.foreground)
                let bg = palette.rgb(cell.background)

                for gy in 0 ..< 8 {
                    let rowByte = glyph[glyph.startIndex + gy]
                    let rowBase = (row * 8 + gy) * bytesPerRow + col * 8 * bytesPerPixel
                    for gx in 0 ..< 8 {
                        let on = (rowByte >> (7 - gx)) & 0x01 == 1
                        let color = on ? fg : bg
                        let idx = rowBase + gx * bytesPerPixel
                        pixels[idx + 0] = color.r
                        pixels[idx + 1] = color.g
                        pixels[idx + 2] = color.b
                        pixels[idx + 3] = 255
                    }
                }
            }
        }
        return pixels
    }

    /// Renders a screen to a 320×200 `CGImage` in the device RGB color space.
    ///
    /// - Parameters:
    ///   - screen: The screen to render.
    ///   - palette: RGB palette for the 16 colors.
    ///   - charsetMode: How each cell's character set is chosen.
    /// - Returns: The image, or `nil` if CoreGraphics cannot create it.
    public static func render(
        _ screen: PETSCIIScreen,
        palette: C64Palette = .c64Wiki,
        charsetMode: CharsetMode = .screen
    ) -> CGImage? {
        let data = pixels(screen, palette: palette, charsetMode: charsetMode)
        guard let provider = CGDataProvider(data: Data(data) as CFData) else {
            return nil
        }
        return CGImage(
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
