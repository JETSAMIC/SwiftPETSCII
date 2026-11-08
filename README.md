# SwiftPETSCII

Decode, render and convert Commodore 64 PETSCII streams in pure Swift.

SwiftPETSCII plays a raw PETSCII byte stream — a C64 `SEQ` file, a BBS
capture, an animation — through a model of the C64 KERNAL screen editor and
returns the resulting 40×25 screens as frames. Frames render to 320×200
`CGImage`s with the real C64 character ROM, and text converts to and from
Unicode, including the Unicode 13 *Symbols for Legacy Computing* block.

## Requirements

- iOS 17+, iPadOS 17+, macOS 14+, tvOS 17+, watchOS 10+, visionOS 1+
- Swift 6.0+ / Xcode 16+
- No dependencies beyond Foundation and CoreGraphics (UIKit/AppKit only for
  the `uiImage`/`nsImage` conveniences)

## Installation

Add SwiftPETSCII to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/JETSAMIC/SwiftPETSCII.git", from: "0.1.0"),
],
```

and to the targets that use it:

```swift
.target(
    name: "MyApp",
    dependencies: ["SwiftPETSCII"]
)
```

## Quick start

```swift
import Foundation
import SwiftPETSCII

let data = try Data(contentsOf: URL(fileURLWithPath: "art.seq"))
let doc = try PETSCIIDocument(data: data)
print(doc.frames.count, doc.isAnimated, doc.totalDuration)

// 320×200 image of the first frame (C64-Wiki palette by default).
let image = doc.frames.first?.cgImage
let peptoImage = doc.frames.first?.cgImage(palette: .pepto)

// Plain text, using Unicode legacy-computing characters for graphics.
let text = PETSCIIToUnicode.string(from: doc.frames[0].screen)

// And back: encode text as PETSCII for the lowercase character set.
let bytes = try PETSCIIToUnicode.petsciiBytes(for: "Hello!", charset: .uppercaseLowercase)
```

`PETSCIIParser.Options` sets the initial colors and character set, the
per-frame duration, quote-mode emulation, strict mode (throw on control
codes the C64 does not define) and the frame limit.

## Format coverage

The supported machine is the **Commodore 64** (and a C128 in 40-column
mode for the codes it shares with the C64). See
[Reference/PETSCII-Format.md](Reference/PETSCII-Format.md) for the full
format specification, code tables and implementation notes.

| Feature | Status |
|---|---|
| Raw PETSCII streams / extracted `SEQ` files | Supported |
| PETSCII → screen codes, aliases `60–7F`, `E0–FE`, `FF` → π | Supported |
| Screen code → canonical PETSCII | Supported |
| Set 1 (uppercase/graphics) and set 2 (lowercase/uppercase), `0E`/`8E` | Supported (screen-wide, as on the VIC-II; per-cell rendering optional) |
| `08`/`09` charset lock/unlock | Supported (no visible effect, as on a C64) |
| 16 color codes | Supported |
| Palettes | Supported: C64-Wiki (default), Pepto; custom via `C64Palette(colors:)` |
| RVS ON/OFF; RETURN/SHIFT-RETURN reset RVS, quote and insert mode | Supported |
| Cursor up/down/left/right, HOME, CLR | Supported |
| Line wrap and scrolling | Supported (moves below the last row are deferred, see Limitations) |
| INST / DEL | Partial: act on the 40-column row; DEL at column 0 backs onto the previous row |
| Logical (80-column) lines | Not supported |
| Quote mode and insert mode, in KERNAL test order | Supported (optional) |
| Echoed control codes and reverse video via ROM reverse glyphs | Supported |
| Color of blank cells | Partial: stored as light blue (invisible) |
| CLR as animation frame boundary | Supported |
| Frame timing | Not part of the format; fixed per-frame duration |
| Undefined control codes | Ignored (strict mode throws, including `0A`) |
| PETSCII/screen code → Unicode (incl. Symbols for Legacy Computing) | Supported, both sets |
| Unicode → PETSCII | Supported (canonical codes) |
| C128-only codes, VIC-20, PET, TED machines | Not supported |
| PC64 `S00`/`P00`, PRG screen dumps, `.d64`, editor project files | Not supported |
| Background/border color changes | Not part of PETSCII; set via `Options` |

## Limitations

- Any move below the last row — printing the bottom-right cell, RETURN or
  cursor down/right on row 24 — scrolls only when more output needs the
  new row, so full 1000-character screens are captured intact; a real
  C64 scrolls immediately.
- The screen editor's 80-column logical lines are not modelled: INST and
  DEL act on one 40-column row (INST drops the row's last character
  instead of extending the line), RETURN always moves to the next row,
  and wrapping never opens a blank line below.
- PETSCII carries no timing; every frame gets
  `Options.defaultFrameDuration`.
- Unicode output loses reverse video, colors and (unless you track it) the
  character set; see the round-trip notes in the reference.
- Decoding stops with `PETSCIIError.frameLimitExceeded` after
  `Options.maxFrames` (10,000) frames.
- Container headers (PC64 `S00`) are not stripped; pass the raw stream.

## Character ROM

`C64CharROM.swift` embeds the 4,096-byte C64 character generator ROM
(part 901225-01) as dumped by the VICE project (MD5
`12a4202f5331d45af846af6c58fba946`). The ROM is Commodore's work; this
package does not establish that it may be redistributed under the MIT
license, and users with distribution concerns should review its status.

## References

- *Commodore 64 Programmer's Reference Guide* and *User's Guide*
- C64 KERNAL screen editor (901227-03); Sheldon Leemon, *Mapping the
  Commodore 64*
- KreativeKorp, PETSCII to Unicode mapping; Unicode L2/19-025, *Symbols for
  Legacy Computing*
- style64.org PETSCII reference
- Philip "Pepto" Timmermann, VIC-II color analysis; C64-Wiki color table

## License

MIT — see [LICENSE](LICENSE). The license covers the Swift source; see
"Character ROM" above for the embedded ROM data.
