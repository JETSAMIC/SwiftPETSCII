import XCTest
import CoreGraphics
@testable import SwiftPETSCII

final class RendererTests: XCTestCase {

    func testRendererProducesImageOfExpectedSize() {
        var screen = PETSCIIScreen()
        // Put a single non-blank cell so the image isn't pure-blank background.
        var cell = screen[column: 0, row: 0]
        cell.codepoint = 0x01   // 'A' in set 1 (screen-code 1)
        cell.foreground = .white
        cell.background = .blue
        screen[column: 0, row: 0] = cell

        let image = PETSCIIRenderer.render(screen)
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 320)
        XCTAssertEqual(image?.height, 200)
    }

    func testRendererRendersDocumentFrame() throws {
        let bytes: [UInt8] = [0x48, 0x49]  // "HI"
        let doc = try PETSCIIDocument(bytes: bytes)
        let image = doc.frames[0].cgImage
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.width, 320)
        XCTAssertEqual(image?.height, 200)
    }

    /// A reverse-video cell with white-on-blue should yield a blue glyph
    /// on a white background — i.e. cell-relative pixel (0,0) for an 'A'
    /// (which has a clear pixel at its top-left corner) should be WHITE
    /// when rendered normally and BLUE when rendered reverse.
    func testReverseVideoSwapsForegroundBackground() throws {
        var s1 = PETSCIIScreen()
        var c1 = s1[column: 0, row: 0]
        c1.codepoint = 0x01    // 'A' screen-code, first byte 0x18 (some pixels set, edges clear)
        c1.foreground = .white
        c1.background = .blue
        c1.reverse = false
        s1[column: 0, row: 0] = c1
        guard let img1 = PETSCIIRenderer.render(s1) else { return XCTFail("img1 nil") }

        var s2 = PETSCIIScreen()
        var c2 = s2[column: 0, row: 0]
        c2.codepoint = 0x01
        c2.foreground = .white
        c2.background = .blue
        c2.reverse = true
        s2[column: 0, row: 0] = c2
        guard let img2 = PETSCIIRenderer.render(s2) else { return XCTFail("img2 nil") }

        // Sample top-left pixel of cell (0,0) — for glyph 0x01 ('A') row 0
        // byte is 0x18 = 00011000, so leftmost pixel (bit 7) is CLEAR.
        // Normal render: clear bit → background (blue).
        // Reverse render: clear bit → foreground (white).
        let p1 = topLeftPixel(of: img1)
        let p2 = topLeftPixel(of: img2)
        // Blue (Pepto): (0, 0, 170)
        XCTAssertEqual(p1.0, 0)
        XCTAssertEqual(p1.1, 0)
        XCTAssertEqual(p1.2, 170)
        // White: (255, 255, 255)
        XCTAssertEqual(p2.0, 255)
        XCTAssertEqual(p2.1, 255)
        XCTAssertEqual(p2.2, 255)
    }

    /// Sample pixel (0,0) of a CGImage as an RGB triple.
    private func topLeftPixel(of image: CGImage) -> (UInt8, UInt8, UInt8) {
        let cs = CGColorSpaceCreateDeviceRGB()
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(
            data: &px,
            width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.draw(image, in: CGRect(x: 0, y: -(image.height - 1),
                                   width: image.width, height: image.height))
        return (px[0], px[1], px[2])
    }
}
