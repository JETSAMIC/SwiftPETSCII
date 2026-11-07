# Getting Started

Decode a PETSCII stream, render its frames, and convert text.

## Decode a stream

``PETSCIIDocument`` decodes a raw PETSCII stream such as a C64 `SEQ` file:

```swift
import SwiftPETSCII

let doc = try PETSCIIDocument(url: seqFileURL)
for frame in doc.frames {
    print(frame.duration)
}
```

Each `CLR` (`0x93`) in the stream ends a frame, so animations decode to
several frames and static art to one. Configure the starting colors,
character set, frame duration and limits with ``PETSCIIParser/Options``:

```swift
var options = PETSCIIParser.Options()
options.background = .black
options.charset = .uppercaseLowercase
options.defaultFrameDuration = 1.0 / 25
let animation = try PETSCIIDocument(data: data, options: options)
```

## Inspect a screen

A ``PETSCIIScreen`` holds 40 × 25 ``PETSCIICell`` values. Each cell stores a
*screen code* (the character-ROM index), its colors, and the reverse
flag. The character set applies to the whole screen
(``PETSCIIScreen/charset``):

```swift
let screen = doc.frames[0].screen
let cell = screen[column: 0, row: 0]
print(cell.codepoint, cell.foreground, screen.charset)
```

## Render

``PETSCIIFrame/cgImage`` renders a frame at 320 × 200 pixels. Pick another
palette or the per-cell character set with
``PETSCIIRenderer/render(_:palette:charsetMode:)``:

```swift
let image = PETSCIIRenderer.render(screen, palette: .pepto)
```

## Convert text

``PETSCIIToUnicode`` maps screen codes and PETSCII bytes to Unicode and
back:

```swift
let text = PETSCIIToUnicode.string(from: screen)
let bytes = try PETSCIIToUnicode.petsciiBytes(for: "READY.", charset: .uppercaseGraphics)
```

Reverse video and colors have no Unicode equivalent and are dropped.
