import XCTest
@testable import SwiftPETSCII

final class CharROMTests: XCTestCase {

    /// The embedded chargen must be exactly 4096 bytes (2x 2048-byte banks).
    func testTotalSize() {
        XCTAssertEqual(C64CharROM.chargen.count, 4096)
        XCTAssertEqual(C64CharROM.bytesPerCharset, 2048)
        XCTAssertEqual(C64CharROM.bytesPerGlyph, 8)
        XCTAssertEqual(C64CharROM.glyphsPerCharset, 256)
    }

    /// SHA-256 of the embedded array, verified against the upstream
    /// chargen-901225-01.bin file documented in C64CharROM.swift.
    func testEmbeddedSHA256() {
        let expected = "fd0d53b8480e86163ac98998976c72cc58d5dd8eb824ed7b829774e74213b420"
        let actual = sha256Hex(C64CharROM.chargen)
        XCTAssertEqual(actual, expected, "Embedded chargen SHA-256 drift — array was modified")
    }

    /// Set 1 char 0x01 = 'A'. Standard C64 'A' is `18 3C 66 7E 66 66 66 00`.
    func testSet1ABitmap() {
        let glyph = C64CharROM.glyph(charset: .uppercaseGraphics, codepoint: 0x01)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x18, 0x3C, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00])
    }

    /// Set 2 char 0x01 = lowercase 'a'. Standard C64 'a' (set 2) is
    /// `00 00 3C 06 3E 66 3E 00`.
    func testSet2ABitmap() {
        let glyph = C64CharROM.glyph(charset: .uppercaseLowercase, codepoint: 0x01)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x00, 0x00, 0x3C, 0x06, 0x3E, 0x66, 0x3E, 0x00])
    }

    /// Set 1 char 0x00 = '@' — first glyph in the ROM. Bitmap is
    /// `3C 66 6E 6E 60 62 3C 00`.
    func testSet1AtSignBitmap() {
        let glyph = C64CharROM.glyph(charset: .uppercaseGraphics, codepoint: 0x00)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x3C, 0x66, 0x6E, 0x6E, 0x60, 0x62, 0x3C, 0x00])
    }

    /// Spot-check set-1 char 0x51 = filled circle / "ball". The C64 ball
    /// is `3C 7E 7E 7E 7E 3C 00 00` shifted to start at row offset 1
    /// (the standard glyph is `00 3C 7E 7E 7E 7E 3C 00`).
    func testSet1BallGlyph() {
        let glyph = C64CharROM.glyph(charset: .uppercaseGraphics, codepoint: 0x51)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x00, 0x3C, 0x7E, 0x7E, 0x7E, 0x7E, 0x3C, 0x00])
    }

    /// Set 1 char 0x53 = heart (♥). Bytes match VICE's chargen-901225-01.
    func testSet1HeartGlyph() {
        let glyph = C64CharROM.glyph(charset: .uppercaseGraphics, codepoint: 0x53)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x36, 0x7F, 0x7F, 0x7F, 0x3E, 0x1C, 0x08, 0x00])
    }

    /// Set 1 char 0x58 = club (♣). Bytes match VICE's chargen-901225-01.
    func testSet1ClubGlyph() {
        let glyph = C64CharROM.glyph(charset: .uppercaseGraphics, codepoint: 0x58)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x18, 0x18, 0x66, 0x66, 0x18, 0x18, 0x3C, 0x00])
    }

    /// Set 1 char 0x41 = spade (♠). Bytes match VICE's chargen-901225-01.
    func testSet1SpadeGlyph() {
        let glyph = C64CharROM.glyph(charset: .uppercaseGraphics, codepoint: 0x41)
        let bytes = Array(glyph)
        XCTAssertEqual(bytes, [0x08, 0x1C, 0x3E, 0x7F, 0x7F, 0x1C, 0x3E, 0x00])
    }

    // MARK: - small SHA-256 implementation (test target dependency-free)

    private func sha256Hex(_ bytes: [UInt8]) -> String {
        var hash = Self.sha256Initial
        var msg = bytes
        // Append 0x80
        msg.append(0x80)
        // Pad with zeros until len % 64 == 56
        while msg.count % 64 != 56 {
            msg.append(0x00)
        }
        // Append length in bits as 64-bit big-endian
        let bitLen = UInt64(bytes.count) * 8
        for i in stride(from: 56, through: 0, by: -8) {
            msg.append(UInt8((bitLen >> i) & 0xFF))
        }

        for block in stride(from: 0, to: msg.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let off = block + i * 4
                w[i] = UInt32(msg[off]) << 24
                     | UInt32(msg[off + 1]) << 16
                     | UInt32(msg[off + 2]) << 8
                     | UInt32(msg[off + 3])
            }
            for i in 16..<64 {
                let s0 = rotr(w[i-15], 7) ^ rotr(w[i-15], 18) ^ (w[i-15] >> 3)
                let s1 = rotr(w[i-2], 17) ^ rotr(w[i-2], 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }
            var a = hash[0], b = hash[1], c = hash[2], d = hash[3]
            var e = hash[4], f = hash[5], g = hash[6], h = hash[7]
            for i in 0..<64 {
                let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = h &+ S1 &+ ch &+ Self.sha256K[i] &+ w[i]
                let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let mj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = S0 &+ mj
                h = g; g = f; f = e; e = d &+ t1
                d = c; c = b; b = a; a = t1 &+ t2
            }
            hash[0] = hash[0] &+ a
            hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c
            hash[3] = hash[3] &+ d
            hash[4] = hash[4] &+ e
            hash[5] = hash[5] &+ f
            hash[6] = hash[6] &+ g
            hash[7] = hash[7] &+ h
        }
        return hash.map { String(format: "%08x", $0) }.joined()
    }

    @inline(__always)
    private func rotr(_ v: UInt32, _ n: UInt32) -> UInt32 {
        return (v >> n) | (v << (32 - n))
    }

    private static let sha256Initial: [UInt32] = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ]
    private static let sha256K: [UInt32] = [
        0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
        0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
        0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
        0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
        0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
        0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
        0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
        0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
    ]
}
