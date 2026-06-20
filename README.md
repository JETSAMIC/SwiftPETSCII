# SwiftPETSCII

Pure-Swift decoder and renderer for **PETSCII** (Commodore 64) art files —
the screen-art format used by the C64 demo scene, BBS art packs, and modern
retro tools like PETSCII Editor and Marq's PETSCII Editor.

No C dependencies, no external Swift packages. Supports both static (`.c`,
`.pet`, `.seq`) and animated PETSCII streams (frame boundaries detected on
`CHR$(147)` clear-screen). Outputs `CGImage` (cross-platform), `UIImage` on
iOS, `NSImage` on macOS.

## Requirements

- Swift 6.0+
- iOS 17+
- macOS 14+

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/prestige-exe/SwiftPETSCII.git", from: "0.1.0")
```

## Usage

```swift
import SwiftPETSCII

let doc = try PETSCIIDocument(url: someURL)
print(doc.frames.count, doc.isAnimated, doc.totalDuration)

// Render the first frame
if let cg = doc.frames.first?.cgImage {
    // 320x200 CGImage (40x25 cells, 8x8 each)
}

#if canImport(UIKit)
let images = doc.frames.compactMap(\.uiImage)
#elseif canImport(AppKit)
let images = doc.frames.compactMap(\.nsImage)
#endif
```

## What's supported

- All 16 PETSCII color control codes (with Pepto-corrected RGB palette)
- Both character sets: uppercase/graphics (set 1) and uppercase/lowercase
  (set 2), with mid-stream switches respected on a per-cell basis
- Reverse-video on/off
- Cursor positioning (home, up/down/left/right, newline)
- Insert / delete
- Clear-screen as animation frame boundary (`CHR$(147)`, 0x93)
- Both printable ranges 0x20–0x7F and 0xA0–0xFF (graphics half)

## What's deferred

- `.d64` disk-image browsing is out of scope; this package only decodes raw
  PETSCII byte streams (`.c`, `.pet`, `.seq`).
- Sprite data, SID music, and any non-screen C64 binary formats.
- Explicit per-frame duration encoding from third-party tools (PETMATE
  custom timing chunks etc.) — frames default to 100ms each.

## Character ROM

The embedded `C64CharROM.swift` is the canonical 4096-byte VICE
`chargen-901225-01.bin`, the public-domain dump of Commodore's character
generator ROM. Commodore released its IP into the public domain in 2025;
only Cloanto's Amiga ROMs remain proprietary. See the source-file header
for the upstream URL and SHA-256.

## License

MIT — see [LICENSE](LICENSE).
