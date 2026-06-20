import XCTest
@testable import SwiftPETSCII

final class PaletteTests: XCTestCase {

    /// All 16 indices must map to the Pepto-corrected reference values.
    func testAllPepptoRGBValues() {
        let expected: [(C64Color, UInt8, UInt8, UInt8)] = [
            (.black,       0,   0,   0),
            (.white,       255, 255, 255),
            (.red,         136, 0,   0),
            (.cyan,        170, 255, 238),
            (.purple,      204, 68,  204),
            (.green,       0,   204, 85),
            (.blue,        0,   0,   170),
            (.yellow,      238, 238, 119),
            (.orange,      221, 136, 85),
            (.brown,       102, 68,  0),
            (.lightRed,    255, 119, 119),
            (.darkGray,    51,  51,  51),
            (.midGray,     119, 119, 119),
            (.lightGreen,  170, 255, 102),
            (.lightBlue,   0,   136, 255),
            (.lightGray,   187, 187, 187),
        ]

        for (color, r, g, b) in expected {
            let rgb = color.rgb
            XCTAssertEqual(rgb.r, r, "red mismatch for \(color)")
            XCTAssertEqual(rgb.g, g, "green mismatch for \(color)")
            XCTAssertEqual(rgb.b, b, "blue mismatch for \(color)")
        }
    }

    /// Hardware color indices 0..15 round-trip via the rawValue.
    func testAllIndicesRoundTrip() {
        for i: UInt8 in 0...15 {
            XCTAssertNotNil(C64Color(rawValue: i), "missing C64Color for index \(i)")
        }
    }

    /// Default screen state matches a freshly-booted C64.
    func testBootDefaults() {
        XCTAssertEqual(C64Color.defaultForeground, .lightBlue)
        XCTAssertEqual(C64Color.defaultBackground, .blue)
        XCTAssertEqual(C64Color.defaultBorder, .lightBlue)
    }
}
