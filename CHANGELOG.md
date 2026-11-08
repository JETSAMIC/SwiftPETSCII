# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - Unreleased (proposed initial release)

### Added
- C64 screen-editor model: scrolling, quote and insert mode, charset
  lock/unlock (`0x08`/`0x09`) and shifted RETURN (`0x8D`).
- Screen-wide character set (`PETSCIIScreen.charset`) and
  `PETSCIIRenderer.CharsetMode`.
- `C64Palette` with the C64-Wiki (default) and Pepto palettes;
  `PETSCIIRenderer.pixels(_:)`; `PETSCIIFrame.cgImage(palette:)`.
- Complete PETSCII/screen code ↔ Unicode tables for both sets, using the
  Unicode 13 Symbols for Legacy Computing block; Unicode → PETSCII encoding.
- `PETSCIIParser.petsciiByte(forScreenCode:)`, `PETSCIIControlCode.byte`.
- Strict mode, frame limit and their errors.
- `Reference/PETSCII-Format.md` format specification, DocC catalog, Swift Package Index configuration,
  CI workflow; tvOS, watchOS and visionOS support.

### Changed
- `PETSCIIError.unsupportedControlCode` carries the byte offset;
  `PETSCIIError.truncated` (never thrown) is removed.
- `PETSCIIParser.screenCode(forPETSCII:)` maps control codes to the reverse
  glyphs shown in quote mode instead of a space.
- `PETSCIIScreen.cells` is no longer externally settable; use the subscript.

### Fixed
- RETURN turns reverse video off; LF is ignored as on the C64; DEL deletes
  the character left of the cursor.
- Output past the bottom row scrolls instead of overwriting the last row.
- Quote and insert mode follow the KERNAL's test order: INST is executed
  (not echoed) in insert mode, and pending inserts cancel quote mode.
- DEL at the start of a line blanks the last cell of the previous line.
- Strict mode rejects the C128 line feed (`0x0A`).
- Reverse video uses the ROM's reverse glyphs.
- The palette is correctly documented as the C64-Wiki palette (it was
  described as Pepto's).
- The README no longer claims support for `.c`/`.pet` editor exports.
