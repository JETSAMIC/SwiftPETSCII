import XCTest
@testable import SwiftPETSCII

final class AnimationTests: XCTestCase {

    /// A document with no clear-screen control codes is a single-frame
    /// (static) document.
    func testStaticDocumentIsSingleFrame() throws {
        let bytes: [UInt8] = [0x48, 0x49]  // "HI"
        let doc = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(doc.frames.count, 1)
        XCTAssertFalse(doc.isAnimated)
    }

    /// Two frames separated by CHR$(147) (0x93) yields 2 frames.
    func testTwoFramesSeparatedByClearScreen() throws {
        // Frame 1: 'A'  |  clear-screen  |  Frame 2: 'B'
        let bytes: [UInt8] = [0x41, 0x93, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(doc.frames.count, 2)
        XCTAssertTrue(doc.isAnimated)
        XCTAssertEqual(doc.frames[0].screen[column: 0, row: 0].codepoint, 0x01)
        XCTAssertEqual(doc.frames[1].screen[column: 0, row: 0].codepoint, 0x02)
    }

    /// A leading clear-screen (no content before it) shouldn't emit an
    /// empty frame — only meaningful frames count.
    func testLeadingClearScreenIsIgnored() throws {
        let bytes: [UInt8] = [0x93, 0x41]
        let doc = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(doc.frames.count, 1)
    }

    /// Each frame gets the default duration unless overridden.
    func testDefaultFrameDuration() throws {
        let bytes: [UInt8] = [0x41, 0x93, 0x42, 0x93, 0x43]
        let doc = try PETSCIIDocument(bytes: bytes)
        XCTAssertEqual(doc.frames.count, 3)
        for f in doc.frames {
            XCTAssertEqual(f.duration, 0.1, accuracy: 0.0001)
        }
        XCTAssertEqual(doc.totalDuration, 0.3, accuracy: 0.0001)
    }

    /// Custom default duration via parser options is honored.
    func testCustomFrameDuration() throws {
        let bytes: [UInt8] = [0x41, 0x93, 0x42]
        var opts = PETSCIIParser.Options()
        opts.defaultFrameDuration = 0.5
        let doc = try PETSCIIDocument(bytes: bytes, options: opts)
        XCTAssertEqual(doc.frames.count, 2)
        XCTAssertEqual(doc.frames[0].duration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(doc.totalDuration, 1.0, accuracy: 0.0001)
    }

    /// Each frame in an animated document renders independently.
    func testEachFrameRendersIndependently() throws {
        let bytes: [UInt8] = [0x41, 0x93, 0x42]
        let doc = try PETSCIIDocument(bytes: bytes)
        for frame in doc.frames {
            let img = frame.cgImage
            XCTAssertNotNil(img)
            XCTAssertEqual(img?.width, 320)
            XCTAssertEqual(img?.height, 200)
        }
    }
}
