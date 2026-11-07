import XCTest
@testable import SwiftPETSCII

/// Hostile-input coverage: every prefix of a valid fixture, a seeded random
/// fuzz, and pathological streams that stress scrolling and frame counts.
final class RobustnessTests: XCTestCase {

    /// A multi-frame fixture touching every control code family.
    private static let fixture: [UInt8] = fixture(fillLength: 1100)

    /// The same fixture with a shorter fill run (still long enough to wrap),
    /// keeping the fuzz loop well under two seconds.
    private static let fuzzSeed: [UInt8] = fixture(fillLength: 90)

    private static func fixture(fillLength: Int) -> [UInt8] {
        var bytes: [UInt8] = [0x93, 0x05, 0x0E, 0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x0D]
        bytes += [0x12, 0x1C, 0xA0, 0xA0, 0x92, 0x9E, 0xC1, 0xDE, 0xFF, 0x8E, 0x0D]
        bytes += [0x11, 0x1D, 0x1D, 0x91, 0x9D, 0x94, 0x14, 0x22, 0x93, 0x22, 0x13, 0x8D]
        bytes += [0x93, 0x08, 0x09, 0x0A, 0x81, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9F, 0x90]
        bytes += [UInt8](repeating: 0xA6, count: fillLength)
        bytes += [0x93, 0x41]
        return bytes
    }

    func testFixtureDecodes() throws {
        let frames = try PETSCIIParser().parse(Self.fixture)
        XCTAssertEqual(frames.count, 3)
    }

    func testEveryPrefixDecodes() {
        let parser = PETSCIIParser()
        for length in 0...Self.fixture.count {
            XCTAssertNoThrow(try parser.parse(Array(Self.fixture.prefix(length))))
        }
    }

    func testSeededRandomFuzz() throws {
        var rng = SplitMix64(seed: 0x5045_5453_4349_4921)  // "PETSCII!"
        let parser = PETSCIIParser(options: .init(maxFrames: 64))
        for iteration in 0..<3_000 {
            var bytes = Self.fuzzSeed
            for _ in 0..<Int.random(in: 1...16, using: &rng) {
                let i = Int.random(in: 0..<bytes.count, using: &rng)
                bytes[i] = UInt8.random(in: 0...255, using: &rng)
            }
            if Bool.random(using: &rng) {
                bytes = Array(bytes.prefix(Int.random(in: 0...bytes.count, using: &rng)))
            }
            do {
                for frame in try parser.parse(bytes) {
                    XCTAssertEqual(frame.screen.cells.count, 1000)
                    if iteration % 100 == 0 { _ = PETSCIIToUnicode.string(from: frame.screen) }
                }
            } catch {
                XCTAssertEqual(error as? PETSCIIError, .frameLimitExceeded(limit: 64))
            }
        }
        // Pure random streams, including every control code.
        for _ in 0..<100 {
            let bytes = (0..<Int.random(in: 0...2_000, using: &rng)).map { _ in UInt8.random(in: 0...255, using: &rng) }
            do {
                let frames = try parser.parse(bytes)
                if let last = frames.last { XCTAssertNotNil(PETSCIIRenderer.render(last.screen)) }
            } catch {
                XCTAssertEqual(error as? PETSCIIError, .frameLimitExceeded(limit: 64))
            }
        }
    }

    func testHeavyScrollingStaysFast() throws {
        // 200,000 RETURNs scroll 200,000 times; scrolling is O(40) per line.
        let start = Date()
        let frames = try PETSCIIParser().parse([0x41] + [UInt8](repeating: 0x0D, count: 200_000) + [0x42])
        XCTAssertEqual(frames.count, 1)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func testFrameFloodIsBounded() {
        XCTAssertEqual(PETSCIIParser.Options().maxFrames, 10_000)
        let flood = [UInt8]([0x41, 0x93]).repeated(50_000)
        XCTAssertThrowsError(try PETSCIIParser(options: .init(maxFrames: 500)).parse(flood)) { error in
            XCTAssertEqual(error as? PETSCIIError, .frameLimitExceeded(limit: 500))
        }
    }

    func testREADMEQuickStart() throws {
        // Mirrors the README "Quick start" snippet.
        let data = Data([0x93, 0x05, 0x48, 0x49, 0x93, 0x1C, 0x42, 0x59, 0x45])
        let doc = try PETSCIIDocument(data: data)
        XCTAssertEqual(doc.frames.count, 2)
        XCTAssertTrue(doc.isAnimated)
        XCTAssertEqual(doc.totalDuration, 0.2, accuracy: 0.0001)
        let image = try XCTUnwrap(doc.frames.first?.cgImage)
        XCTAssertEqual(image.width, 320)
        XCTAssertNotNil(doc.frames.first?.cgImage(palette: .pepto))
        let text = PETSCIIToUnicode.string(from: doc.frames[0].screen)
        XCTAssertTrue(text.hasPrefix("HI"))
    }
}

private extension Array {
    func repeated(_ count: Int) -> [Element] {
        Array([[Element]](repeating: self, count: count).joined())
    }
}

/// Deterministic SplitMix64 generator so fuzz runs are reproducible.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
