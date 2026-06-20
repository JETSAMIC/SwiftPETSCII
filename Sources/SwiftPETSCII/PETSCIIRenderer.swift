import Foundation
import CoreGraphics

/// Pure-CoreGraphics renderer: takes a `PETSCIIScreen` and rasterizes it
/// to a 320x200 RGBA8 `CGImage` using the embedded C64 character ROM
/// and the Pepto palette.
///
/// One cell = 8x8 source pixels. No scaling is applied — callers can scale
/// up with `CGContext.draw(_:in:)` and `.interpolationQuality = .none` for
/// crisp nearest-neighbor zoom.
public enum PETSCIIRenderer {

    /// Native render dimensions: 40 cols * 8 px = 320, 25 rows * 8 px = 200.
    public static let pixelWidth: Int  = PETSCIIScreen.columns * C64CharROM.bytesPerGlyph
    public static let pixelHeight: Int = PETSCIIScreen.rows    * C64CharROM.bytesPerGlyph

    /// Render the given screen to a 320x200 sRGB `CGImage`.
    public static func render(_ screen: PETSCIIScreen) -> CGImage? {
        let width  = pixelWidth
        let height = pixelHeight
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        // RGBA8 buffer, premultiplied-last alpha. Initialize to the border
        // / background color so even a "blank" frame has the right tint.
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Render cell-by-cell.
        for row in 0 ..< PETSCIIScreen.rows {
            for col in 0 ..< PETSCIIScreen.columns {
                let cell = screen[column: col, row: row]
                let glyph = C64CharROM.glyph(charset: cell.charset, codepoint: cell.codepoint)

                let (fgR, fgG, fgB) = cell.reverse
                    ? cell.background.rgb
                    : cell.foreground.rgb
                let (bgR, bgG, bgB) = cell.reverse
                    ? cell.foreground.rgb
                    : cell.background.rgb

                // 8 rows of 8 pixels per glyph.
                let cellPixelX = col * 8
                let cellPixelY = row * 8

                for gy in 0 ..< 8 {
                    let rowByte = glyph[glyph.startIndex + gy]
                    let pixelY = cellPixelY + gy
                    let rowBase = pixelY * bytesPerRow + cellPixelX * bytesPerPixel

                    for gx in 0 ..< 8 {
                        let bit = (rowByte >> (7 - gx)) & 0x01
                        let idx = rowBase + gx * bytesPerPixel
                        if bit == 1 {
                            pixels[idx + 0] = fgR
                            pixels[idx + 1] = fgG
                            pixels[idx + 2] = fgB
                            pixels[idx + 3] = 255
                        } else {
                            pixels[idx + 0] = bgR
                            pixels[idx + 1] = bgG
                            pixels[idx + 2] = bgB
                            pixels[idx + 3] = 255
                        }
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
