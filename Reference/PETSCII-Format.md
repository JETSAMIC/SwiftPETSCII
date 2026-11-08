# PETSCII Format Reference

The authoritative reference for SwiftPETSCII: the PETSCII character code,
the Commodore 64 screen codes and character ROM, the control codes and how
the C64 KERNAL screen editor acts on them, the Unicode mapping, the colour
palette, the containers PETSCII streams travel in, and exactly which parts
SwiftPETSCII implements.

Contents

1. [Overview](#1-overview)
2. [Conventions](#2-conventions)
3. [Byte-level layouts](#3-byte-level-layouts)
4. [Code tables and enumerations](#4-code-tables-and-enumerations)
5. [Algorithms](#5-algorithms)
6. [Semantics and de-facto behaviour](#6-semantics-and-de-facto-behaviour)
7. [Robustness guidance for readers](#7-robustness-guidance-for-readers)
8. [Errata](#8-errata)
9. [Implementation status](#9-implementation-status)
10. [References and provenance](#10-references-and-provenance)

Appendix A. [Unicode mapping table](#appendix-a-unicode-mapping-table)

---

## 1. Overview

### 1.1 What PETSCII is

PETSCII ("PET Standard Code of Information Interchange"; Commodore's own
manuals say "Commodore ASCII" or "CBM ASCII") is the 8-bit character code
of Commodore's 8-bit computers, from the PET 2001 (1977) to the C128
(1985). It starts from the 1963 version of ASCII — uppercase letters at
`$41`–`$5A`, `↑` and `←` at `$5E`/`$5F` — and adds:

- a second half (`$A0`–`$FF`) of block, line and card-suit graphics
  printed on the fronts of the keys;
- control codes in `$00`–`$1F` and `$80`–`$9F` for cursor movement,
  clearing, insert/delete, reverse video, character-set switching and, from
  the VIC-20 on, text colour.

PETSCII is a *stream* code: it is what `PRINT` and the KERNAL `CHROUT`
routine (`$FFD2`) accept, what `SEQ` files hold, and what a Commodore BBS
sends down the line. PETSCII art and PETSCII animations are such streams
replayed through the screen editor. There is no header, signature or
length field — a stream is just bytes.

What reaches the screen is a different code, the **screen code** (the
index into the character ROM; §4.1). The screen editor converts as it
prints. Most confusion about PETSCII comes from mixing the two codes up.

### 1.2 Machines and variants

| Machine | Year | Text screen | Text colours | Character sets | Notes |
|---|---|---|---|---|---|
| PET 2001 / CBM 3000, 4000 | 1977– | 40 × 25, monochrome | — | graphics / text | earliest (BASIC 1.0) ROMs swap the upper- and lowercase letters of the text set relative to every later machine |
| CBM 8000 | 1980 | 80 × 25, monochrome | — | graphics / text | `$0E`/`$8E` switch sets |
| VIC-20 | 1980 | 22 × 23 | 8 (`0`–`7`) | as C64 | no Commodore-key colours |
| **Commodore 64** | 1982 | 40 × 25 | 16 | set 1 / set 2 | the machine SwiftPETSCII models |
| C16, C116, Plus/4 (TED) | 1984 | 40 × 25 | 121 (16 hues × 8 luminances) | as C64 | hardware flash, ESC sequences |
| C128, 40-column (VIC-II) | 1985 | 40 × 25 | 16 | as C64 | extra control codes (§4.3) |
| C128, 80-column (VDC 8563) | 1985 | 80 × 25 | 16 RGBI | as C64 | underline, flash, different colour hardware |

How to tell the variants apart: a raw stream cannot say which machine it
was written for. In practice the source (a C64 disk, a C64 BBS) decides;
colour codes `$81` and `$95`–`$9B` imply a 16-colour machine, ESC (`$1B`)
sequences imply a C128 or TED machine, and a 22-column layout implies a
VIC-20. SwiftPETSCII always assumes a C64.

### 1.3 Where PETSCII streams come from

- C64 BASIC and machine-language programs (`PRINT`, `CHROUT`).
- `SEQ` files on Commodore disks (§3.2), usually extracted to `.seq` files
  on modern systems.
- Commodore BBS software (Color 64, C-Net, Image BBS and others) and
  modern PETSCII telnet BBSes; captures of these sessions are raw streams.
- PETSCII editors: Marq's PETSCII Editor (Markku "Marq" Reunanen) and
  Petmate (Janne Hellsten) both export `SEQ` streams in addition to their
  own project formats.

### 1.4 File extensions and media types

| Extension | Contents | SwiftPETSCII |
|---|---|---|
| `.seq` | raw PETSCII stream (an extracted CBM `SEQ` file or capture) | decoded |
| `.s00`–`.s99` | PC64 container holding a `SEQ` file (§3.3) | not decoded (header is printed as text) |
| `.prg` | load address + memory image, often a screen dump of *screen codes* (§3.4) | not decoded |
| `.p00`–`.p99` | PC64 container holding a `PRG` file | not decoded |
| `.d64` | 1541 disk image | not decoded |
| `.c`, `.pet`, `.petmate`, `.json` | editor project/export formats | not decoded |

No MIME type or Uniform Type Identifier is registered for PETSCII streams;
treat them as `application/octet-stream` / `public.data`.

---

## 2. Conventions

- **Bytes.** A stream is a sequence of 8-bit bytes with no multi-byte
  integers. `$xx` and `0xXX` both denote hexadecimal; `CHR$(n)` is the
  decimal BASIC spelling of the same byte.
- **PETSCII code vs screen code.** "PETSCII code" or "byte" means the
  stream value; "screen code" means the character-ROM index stored in
  screen RAM. Bit 7 of a screen code selects the reverse-video glyph.
- **Character sets.** *Set 1* ("unshifted", uppercase/graphics) is active
  at power-on; *set 2* ("shifted", lowercase/uppercase) is selected with
  `$0E`. The set is a screen-wide video setting, not a per-character
  attribute (§6.4).
- **Coordinates.** Columns `0`–`39` left to right, rows `0`–`24` top to
  bottom; `(0, 0)` is the top-left cell ("home").
- **Glyphs.** 8 × 8 pixels, one byte per pixel row, top row first; bit 7
  is the leftmost pixel; a set bit is drawn in the cell's foreground
  colour.
- **Logical line.** The screen editor joins one or two physical 40-column
  rows into a *logical line* of up to 80 columns (§6.1).
- **KERNAL addresses.** Routine addresses (`$E716` etc.) refer to the C64
  KERNAL ROM 901227-03, the most common revision. Zero-page and system
  variables used in this document:

  | Address | Name | Meaning |
  |---|---|---|
  | `$C7` | RVS | reverse-video flag (non-zero = on) |
  | `$D3` | PNTR | cursor column within the logical line (`0`–`79`) |
  | `$D4` | QTSW | quote-mode flag (`0`/`1`) |
  | `$D5` | LNMX | last column of the current logical line (`39` or `79`) |
  | `$D6` | TBLX | cursor physical row (`0`–`24`) |
  | `$D8` | INSRT | pending insert count |
  | `$D9`–`$F2` | LDTB1 | line-link table, one byte per row; bit 7 set = row starts a logical line |
  | `$0286` | COLOR | current text colour (`0`–`15`) |
  | `$0291` | MODE | bit 7 set = SHIFT+C= charset toggle disabled |
  | `$0292` | AUTODN | line-insert-on-wrap control (§6.1) |
  | `$0400`–`$07E7` | — | default screen RAM (1000 bytes, row-major) |
  | `$D800`–`$DBE7` | — | colour RAM (low nibble per cell) |
  | `$D018` | — | VIC-II memory pointers; bit 1 selects the character set |
  | `$D020` / `$D021` | — | border / background colour |

---

## 3. Byte-level layouts

### 3.1 Raw PETSCII stream

| Offset | Size | Type | Name | Meaning |
|---|---|---|---|---|
| 0 | *n* | `u8[n]` | bytes | PETSCII codes, processed strictly in order |

There is no header, terminator or checksum. `$00` is not a terminator (it
is an undefined control code with no effect). The stream ends where the
data ends. Every byte sequence is a valid stream.

### 3.2 `SEQ` files on Commodore disks

On a 1541 disk (`.d64`) a sequential file is a directory entry of file
type `SEQ` (type byte `$81` for a closed file) pointing at a chain of
256-byte sectors:

| Offset | Size | Type | Name | Meaning |
|---|---|---|---|---|
| 0 | 1 | `u8` | next track | track of the next sector; `0` in the last sector |
| 1 | 1 | `u8` | next sector / last byte | sector of the next sector; in the last sector, the offset of the last used byte |
| 2 | 254 | `u8[254]` | data | file contents |

Extracting a `SEQ` file concatenates the data bytes (all 254 of every
sector but the last, then bytes `2`…*last* of the last one). The result is
a raw stream (§3.1). SwiftPETSCII does not read disk images.

### 3.3 PC64 `S00` / `P00` containers

Emulators of the PC64 family wrap a single CBM file in a 26-byte header:

| Offset | Size | Type | Name | Meaning |
|---|---|---|---|---|
| 0 | 8 | `char[8]` | signature | `C64File` followed by `$00` |
| 8 | 17 | `u8[17]` | CBM name | original PETSCII file name, padded with `$00`; byte 24 is always `$00` |
| 25 | 1 | `u8` | record size | REL record length; `0` for `SEQ`/`PRG` |
| 26 | *n* | `u8[n]` | data | the file contents (a raw stream for `S00`) |

The extension's letter gives the CBM file type (`S` = `SEQ`, `P` = `PRG`,
`U` = `USR`, `R` = `REL`) and the two digits disambiguate clashing names.
SwiftPETSCII does not strip this header; callers that accept `.s00` files
should check for the signature and pass `data[26...]`.

### 3.4 `PRG` files and screen dumps

| Offset | Size | Type | Name | Meaning |
|---|---|---|---|---|
| 0 | 2 | `u16le` | load address | where the data is loaded in C64 memory |
| 2 | *n* | `u8[n]` | data | memory image |

A "screen dump" `PRG` with load address `$0400` holds 1000 **screen codes**
(not PETSCII), sometimes followed by padding and colour RAM; many PETSCII
editors instead export a `PRG` that is a small viewer program plus data.
Neither is a PETSCII stream, and SwiftPETSCII does not decode them.

### 3.5 The C64 text screen in memory

| Item | Location | Size | Meaning |
|---|---|---|---|
| Screen RAM | `$0400` + `40·row + col` | 1 byte per cell | bits 0–6 glyph, bit 7 reverse (i.e. the full screen code `$00`–`$FF`) |
| Colour RAM | `$D800` + `40·row + col` | low nibble per cell | foreground colour `0`–`15` |
| Character set | `$D018` bit 1 | 1 bit | `0` = set 1 (`$D018` = `$15`), `1` = set 2 (`$D018` = `$17`) |
| Background | `$D021` | low nibble | one colour for the whole screen (standard text mode) |
| Border | `$D020` | low nibble | outside the 320 × 200 display window |

SwiftPETSCII's model: `PETSCIICell.codepoint` is the screen code (normally
`$00`–`$7F`), `PETSCIICell.reverse` is bit 7 kept separately
(`screenRAMValue` recombines them), `foreground` is the colour-RAM nibble,
`background` copies the screen-wide background, and `charset` records the
set active when the cell was written (informational; §6.4).
`PETSCIIScreen.charset` is the screen-wide `$D018` setting and
`PETSCIIScreen.border` the border colour.

### 3.6 Character generator ROM (901225-01)

| Offset | Size | Contents |
|---|---|---|
| `$000` | 1024 | set 1, screen codes `$00`–`$7F` (8 bytes each) |
| `$400` | 1024 | set 1, screen codes `$80`–`$FF` (reverse forms) |
| `$800` | 1024 | set 2, screen codes `$00`–`$7F` |
| `$C00` | 1024 | set 2, screen codes `$80`–`$FF` (reverse forms) |

Glyph address = `set · 2048 + screenCode · 8`. The CPU sees this ROM at
`$D000`–`$DFFF` when it is banked in; the VIC-II sees it at `$1000`–`$1FFF`
in video banks 0 and 2. The reverse half is stored, not computed, and is
not a perfect inversion: the reverse `@` (screen code `$80`, both sets) has
pixel row 5 = `$99`, whereas inverting row 5 of `@` (`$62`) would give
`$9D`. Every other reverse glyph is the bitwise complement of its normal
form. The well-known dump has MD5 `12a4202f5331d45af846af6c58fba946`.

---

## 4. Code tables and enumerations

### 4.1 PETSCII code ranges

| PETSCII | Kind | Screen code printed | Contents |
|---|---|---|---|
| `$00`–`$1F` | control | — (`$80`–`$9F` when echoed, §5.3) | §4.3 |
| `$20`–`$3F` | printable | `$20`–`$3F` | space, punctuation, digits |
| `$40`–`$5F` | printable | `$00`–`$1F` | `@`, `A`–`Z` (set 2: `a`–`z`), `[ £ ] ↑ ←` |
| `$60`–`$7F` | printable, **alias** | `$40`–`$5F` | same glyphs as `$C0`–`$DF` |
| `$80`–`$9F` | control | — (`$C0`–`$DF` when echoed) | §4.3 |
| `$A0`–`$BF` | printable | `$60`–`$7F` | graphics (`$A0` is the shifted space) |
| `$C0`–`$DF` | printable | `$40`–`$5F` | graphics (set 1) / `A`–`Z` (set 2) |
| `$E0`–`$FE` | printable, **alias** | `$60`–`$7E` | same glyphs as `$A0`–`$BE` |
| `$FF` | printable, **alias** | `$5E` | same glyph as `$DE` (π in set 1) |

The canonical codes are `$20`–`$5F`, `$A0`–`$BF` and `$C0`–`$DF`. The
aliases are what the keyboard and `GET` can return; printing an alias
gives exactly the same screen code as printing its canonical code, so a
writer should always emit canonical codes.

### 4.2 Character sets

The two sets differ only in these screen codes; all others are identical.

| Screen code | Set 1 (unshifted, uppercase/graphics) | Set 2 (shifted, lowercase/uppercase) |
|---|---|---|
| `$01`–`$1A` | `A`–`Z` | `a`–`z` |
| `$41`–`$5A` | graphics (♠, line pieces, ♥, ♣, ♦, …) | `A`–`Z` |
| `$5E` | π | inverse checkerboard |
| `$5F` | ◥ (upper-right triangle) | diagonal fill ╲ |
| `$69` | ◤ (upper-left triangle) | diagonal fill ╱ |
| `$7A` | lower-right corner block | ✓ check mark |

| Set | Selected by | `$D018` | Default |
|---|---|---|---|
| 1 | `$8E`, or SHIFT+C= | `$15` | yes, at power-on |
| 2 | `$0E`, or SHIFT+C= | `$17` | — |

### 4.3 Control codes (`$00`–`$1F`, `$80`–`$9F`)

"Echo" is the screen code shown when the code is displayed instead of
executed in quote or insert mode (§5.3). "SwiftPETSCII" gives the
`PETSCIIControlCode` case the parser executes, or "ignored" (no effect;
strict mode throws `unsupportedControlCode`).

| Code | Key (C64) | C64 effect | Other machines | Echo | SwiftPETSCII |
|---|---|---|---|---|---|
| `$00` | — | none | — | `$80` | ignored |
| `$01` | — | none | — | `$81` | ignored |
| `$02` | — | none | C128: underline on (80-col) | `$82` | ignored |
| `$03` | RUN/STOP | none when printed (keyboard code) | — | `$83` | ignored |
| `$04` | — | none | — | `$84` | ignored |
| `$05` | CTRL-2 | text colour white | — | `$85` | `setColor(.white)` |
| `$06` | — | none | — | `$86` | ignored |
| `$07` | — | none | C128: bell | `$87` | ignored |
| `$08` | — | disable SHIFT+C= set toggle | VIC-20 as C64 | `$88` | `lockCharset` (no visible effect) |
| `$09` | — | enable SHIFT+C= set toggle | C128: TAB | `$89` | `unlockCharset` (no visible effect) |
| `$0A` | — | none | C128: line feed | `$8A` | `lineFeed`, treated as no-op (strict mode throws) |
| `$0B` | — | none | C128: disable SHIFT+C= | `$8B` | ignored |
| `$0C` | — | none | C128: enable SHIFT+C= | `$8C` | ignored |
| `$0D` | RETURN | carriage return (§5.4); RVS, quote and insert mode off | all | never echoed | `newline` |
| `$0E` | — | select set 2 | VIC-20, C128, TED as C64; CBM 8000: text mode | `$8E` | `switchToUppercaseLowercase` |
| `$0F` | — | none | C128: flash on (80-col) | `$8F` | ignored |
| `$10` | — | none | — | `$90` | ignored |
| `$11` | CRSR ↓ | cursor down; scrolls on the bottom row | all | `$91` | `cursorDown` |
| `$12` | CTRL-9 | reverse video on | all | `$92` | `reverseOn` |
| `$13` | HOME | cursor home | all | `$93` | `home` |
| `$14` | DEL | delete left of cursor (§5.5) | all | `$94` | `delete` |
| `$15`–`$17` | — | none | — | `$95`–`$97` | ignored |
| `$18` | — | none | C128: TAB set/clear | `$98` | ignored |
| `$19`–`$1A` | — | none | — | `$99`–`$9A` | ignored |
| `$1B` | — | none | C128, TED: ESC (escape sequences) | `$9B` | ignored |
| `$1C` | CTRL-3 | text colour red | VIC-20, TED as C64 | `$9C` | `setColor(.red)` |
| `$1D` | CRSR → | cursor right; wraps; scrolls past the bottom-right cell | all | `$9D` | `cursorRight` |
| `$1E` | CTRL-6 | text colour green | | `$9E` | `setColor(.green)` |
| `$1F` | CTRL-7 | text colour blue | | `$9F` | `setColor(.blue)` |
| `$80` | — | none | — | `$C0` | ignored |
| `$81` | C=-1 | text colour orange | not VIC-20 | `$C1` | `setColor(.orange)` |
| `$82` | — | none | C128: underline off; TED: flash on | `$C2` | ignored |
| `$83` | SHIFT+RUN/STOP | none when printed (keyboard code) | — | `$C3` | ignored |
| `$84` | — | none | TED: flash off | `$C4` | ignored |
| `$85`–`$88` | F1, F3, F5, F7 | none when printed (keyboard codes) | — | `$C5`–`$C8` | ignored |
| `$89`–`$8C` | F2, F4, F6, F8 | none when printed (keyboard codes) | — | `$C9`–`$CC` | ignored |
| `$8D` | SHIFT+RETURN | as `$0D` | all | never echoed | `shiftedReturn` |
| `$8E` | — | select set 1 | as `$0E`; CBM 8000: graphics mode | `$CE` | `switchToUppercaseGraphics` |
| `$8F` | — | none | C128: flash off (80-col) | `$CF` | ignored |
| `$90` | CTRL-1 | text colour black | | `$D0` | `setColor(.black)` |
| `$91` | CRSR ↑ | cursor up; stops on the top row | all | `$D1` | `cursorUp` |
| `$92` | CTRL-0 | reverse video off | all | `$D2` | `reverseOff` |
| `$93` | CLR | clear screen, cursor home | all | `$D3` (reverse ♥) | `clearScreen` (also a frame boundary) |
| `$94` | INST | insert a blank at the cursor (§5.5) | all | `$D4` | `insert` |
| `$95` | C=-2 | text colour brown | not VIC-20 | `$D5` | `setColor(.brown)` |
| `$96` | C=-3 | text colour light red | not VIC-20 | `$D6` | `setColor(.lightRed)` |
| `$97` | C=-4 | text colour dark grey | not VIC-20 | `$D7` | `setColor(.darkGray)` |
| `$98` | C=-5 | text colour medium grey | not VIC-20 | `$D8` | `setColor(.midGray)` |
| `$99` | C=-6 | text colour light green | not VIC-20 | `$D9` | `setColor(.lightGreen)` |
| `$9A` | C=-7 | text colour light blue | not VIC-20 | `$DA` | `setColor(.lightBlue)` |
| `$9B` | C=-8 | text colour light grey | not VIC-20 | `$DB` | `setColor(.lightGray)` |
| `$9C` | CTRL-5 | text colour purple | | `$DC` | `setColor(.purple)` |
| `$9D` | CRSR ← | cursor left; wraps to the previous row; stops at home | all | `$DD` | `cursorLeft` |
| `$9E` | CTRL-8 | text colour yellow | | `$DE` | `setColor(.yellow)` |
| `$9F` | CTRL-4 | text colour cyan | | `$DF` | `setColor(.cyan)` |

Undefined codes ("none") are silently ignored by the C64 KERNAL: they fall
through every comparison in `CHROUT` without effect. Readers should do the
same by default; a strict reader may reject them to detect streams written
for another machine.

### 4.4 Colours

PETSCII sets only the text (foreground) colour. Background and border are
set by `POKE 53281,n` / `POKE 53280,n` (`$D021`/`$D020`) and cannot be
changed by any PETSCII code.

| Index | Colour | PETSCII | Key | Index | Colour | PETSCII | Key |
|---|---|---|---|---|---|---|---|
| 0 | black | `$90` | CTRL-1 | 8 | orange | `$81` | C=-1 |
| 1 | white | `$05` | CTRL-2 | 9 | brown | `$95` | C=-2 |
| 2 | red | `$1C` | CTRL-3 | 10 | light red | `$96` | C=-3 |
| 3 | cyan | `$9F` | CTRL-4 | 11 | dark grey | `$97` | C=-4 |
| 4 | purple | `$9C` | CTRL-5 | 12 | medium grey | `$98` | C=-5 |
| 5 | green | `$1E` | CTRL-6 | 13 | light green | `$99` | C=-6 |
| 6 | blue | `$1F` | CTRL-7 | 14 | light blue | `$9A` | C=-7 |
| 7 | yellow | `$9E` | CTRL-8 | 15 | light grey | `$9B` | C=-8 |

The KERNAL looks the code up in a 16-byte table at `$E8DA` in index order:
`$90 $05 $1C $9F $9C $1E $1F $9E $81 $95 $96 $97 $98 $99 $9A $9B`.

Power-on state: text light blue (14), background blue (6), border light
blue (14).

### 4.5 RGB palettes

The VIC-II produces analog luma/chroma, so RGB values are an
interpretation. SwiftPETSCII ships two (`C64Palette`); any other
16-entry table can be supplied with `C64Palette(colors:)`.

| Index | C64-Wiki (`.c64Wiki`, default) | Pepto PAL 2001 (`.pepto`) | Colodore 2017 (not shipped) |
|---|---|---|---|
| 0 | `#000000` | `#000000` | `#000000` |
| 1 | `#FFFFFF` | `#FFFFFF` | `#FFFFFF` |
| 2 | `#880000` | `#68372B` | `#813338` |
| 3 | `#AAFFEE` | `#70A4B2` | `#75CEC8` |
| 4 | `#CC44CC` | `#6F3D86` | `#8E3C97` |
| 5 | `#00CC55` | `#588D43` | `#56AC4D` |
| 6 | `#0000AA` | `#352879` | `#2E2C9B` |
| 7 | `#EEEE77` | `#B8C76F` | `#EDF171` |
| 8 | `#DD8855` | `#6F4F25` | `#8E5029` |
| 9 | `#664400` | `#433900` | `#553800` |
| 10 | `#FF7777` | `#9A6759` | `#C46C71` |
| 11 | `#333333` | `#444444` | `#4A4A4A` |
| 12 | `#777777` | `#6C6C6C` | `#7B7B7B` |
| 13 | `#AAFF66` | `#9AD284` | `#A9FF9F` |
| 14 | `#0088FF` | `#6C5EB5` | `#706DEB` |
| 15 | `#BBBBBB` | `#959595` | `#B2B2B2` |

- *C64-Wiki*: the bright, saturated table published by the C64-Wiki; the
  library default because it is what most PETSCII art galleries show.
- *Pepto PAL*: Philip "Pepto" Timmermann's 2001 measurement of a PAL C64
  (VICE `pepto-pal`).
- *Colodore*: Pepto's 2017 revision (VICE `colodore`), listed for
  reference only.

### 4.6 SwiftPETSCII enumerations

| Type | Cases | Raw values |
|---|---|---|
| `C64Color` | `black` … `lightGray` | hardware index `0`–`15` (§4.4) |
| `PETSCIICharset` | `uppercaseGraphics`, `uppercaseLowercase` | `0` (set 1), `1` (set 2) = ROM half |
| `PETSCIIControlCode` | one case per row of §4.3 marked with a case name | `byte` gives the code |
| `PETSCIIRenderer.CharsetMode` | `screen` (hardware), `perCell` (editor view) | — |
| `PETSCIIError` | `invalidData`, `unsupportedControlCode(_:offset:)`, `frameLimitExceeded(limit:)`, `unencodableCharacter(_:)` | — |

---

## 5. Algorithms

### 5.1 PETSCII → screen code

Equivalent to the KERNAL's conversion in `CHROUT` (`$E72A`–`$E742` for
`$00`–`$7F`, `$E7D4`–`$E7E0` and `$E691` for `$80`–`$FF`):

```
func screenCode(petscii b):
    switch b:
    case $00...$1F: return b | $80      // only when echoed (§5.3)
    case $20...$3F: return b
    case $40...$5F: return b - $40       // KERNAL: b AND $3F
    case $60...$7F: return b - $20       // KERNAL: b AND $DF
    case $80...$9F: return b + $40       // only when echoed: (b AND $7F) OR $40 OR $80
    case $A0...$BF: return b - $40       // (b AND $7F) OR $40
    case $C0...$FE: return b - $80       // (b AND $7F) OR $40
    case $FF:       return $5E           // KERNAL maps $7F (after AND $7F) to $5E
```

The reverse flag (RVS, `$C7`) then sets bit 7 for printed characters.

### 5.2 Screen code → canonical PETSCII

```
func petscii(screen s):
    c = s & $7F                          // reverse is expressed with $12/$92
    switch c:
    case $00...$1F: return c + $40
    case $20...$3F: return c
    case $40...$5F: return c + $80       // never the $60–$7F alias
    case $60...$7F: return c + $40       // never the $E0–$FF alias
```

For every screen code `s` in `$00`–`$7F`,
`screenCode(petscii(s)) == s`.

### 5.3 `CHROUT` to the screen (one byte)

The KERNAL tests are order-sensitive; this is their order (`$E716`), with
SwiftPETSCII's deviations noted in §9.

```
func chrout(b):
    if b == $0D or b == $8D:                       // $E72A / $E7E3
        carriageReturn(); finish(); return          // RVS, QTSW, INSRT := 0
    if b is printable (§4.1):
        if b == $22: QTSW ^= 1                      // $E684, before printing
        put(screenCode(b) | (RVS ? $80 : 0))
        finish(); return
    if b < $80:                                     // unshifted control
        if INSRT > 0: echo(b); finish(); return     // $E745: even DEL is echoed
        if b == $14: delete(); finish(); return     // $E74C: DEL works in quote mode
        if QTSW:     echo(b); finish(); return      // $E77E
    else:                                           // shifted control
        if QTSW:     echo(b); finish(); return      // $E7EA: even INST is echoed
        if b == $94: insert(); finish(); return     // $E7EE: INST works in insert mode
        if INSRT > 0: echo(b); finish(); return     // $E829
    execute(b)                                      // §4.3; undefined codes do nothing
    finish()

func echo(b):                                       // $E697 / $E82D
    put(screenCode(b))                              // always reverse ($80–$9F / $C0–$DF),
                                                    // regardless of RVS
func put(code):                                     // $E693–$E6A5
    store code at the cursor, colour := COLOR
    if INSRT > 0: INSRT -= 1
    advanceCursor()                                 // §5.4

func finish():                                      // $E6A8
    if INSRT > 0: QTSW := 0                         // insert mode cancels quote mode
```

Consequences worth stating explicitly:

- Quote mode is toggled by every printed `"`; it ends at RETURN.
- In quote mode every control code except RETURN, SHIFT+RETURN and DEL is
  displayed; in insert mode every control code except RETURN,
  SHIFT+RETURN and INST is displayed; with both active, everything except
  RETURN/SHIFT+RETURN is displayed.
- Echoed codes consume an inserted blank just as printed characters do.
- A `"` printed while blanks remain does not leave quote mode on, unless
  it consumed the last blank.

### 5.4 Cursor movement, wrapping and scrolling

```
func advanceCursor():
    col += 1
    if col == 40: col := 0; lineDown()   // the C64 also links the rows (§6.1)

func lineDown():
    row += 1
    if row == 25: scrollUp(); row := 24

func scrollUp():
    rows 1…24 move to rows 0…23; row 24 is cleared to spaces

func carriageReturn():                   // $E891
    INSRT := 0; RVS := 0; QTSW := 0; col := 0
    move to the first row after the current logical line (lineDown on an unlinked row)
```

- CRSR ↓ is `lineDown()`; CRSR ↑ decrements `row` unless it is `0`.
- CRSR → is `advanceCursor()`, so it wraps and scrolls.
- CRSR ← decrements `col`; at column 0 it moves to column 39 of the
  previous row; at home it does nothing.
- HOME sets `(col, row) := (0, 0)`; CLR clears all 1000 cells to spaces,
  resets the line-link table and homes the cursor. Neither changes COLOR,
  RVS or the character set.

### 5.5 INST and DEL

```
func delete():                           // $E74C
    if col == 0:
        if row == 0: return              // $E705: nothing at home
        row -= 1; col := 39              // $E701: back onto the previous line
        cell[col,row] := space           // $E773
        return
    col -= 1
    cells (col+1 … end of logical line) shift one to the left
    last cell of the logical line := space

func insert():                           // $E7EE
    if the last cell of the logical line is not a space:
        if the logical line is already 80 columns: return   // nothing, INSRT unchanged
        extend the logical line by one row (§6.1)
    cells (col … end of logical line − 1) shift one to the right
    cell[col,row] := space
    INSRT += 1
```

Blank cells written by INST, DEL, CLR and scrolling get the current text
colour in colour RAM on KERNAL 901227-03 (earlier revisions differ); the
colour of a non-reverse space is invisible either way.

### 5.6 Rendering a screen

```
for row in 0..<25, col in 0..<40:
    cell  = screen[col,row]
    set   = screen.charset                 // hardware: one set per screen
    glyph = ROM[set·2048 + screenRAM(cell)·8 ..< +8]
    for y in 0..<8, x in 0..<8:
        on = (glyph[y] >> (7 − x)) & 1
        pixel(col·8 + x, row·8 + y) = on ? palette[cell.foreground] : palette[background]
```

Reverse video is rendered by selecting the reverse glyph (screen code with
bit 7 set) from the ROM — never by swapping colours or inverting bits
(§3.6). The image is 320 × 200; the border is outside it.

### 5.7 Unicode conversion

Decoding: `character(screenCode & $7F, set)` from Appendix A; for a
PETSCII byte, first apply §5.1 (control codes have no character).
Encoding: invert the table of the requested set (each set's table is
injective), then apply §5.2; newline becomes `$0D`. A character absent
from the set's table cannot be encoded.

---

## 6. Semantics and de-facto behaviour

### 6.1 Logical lines

The C64 screen editor keeps a line-link table (`$D9`–`$F2`). Initially,
and after CLR, every row starts its own logical line. When output passes
column 39 of a row that starts a logical line, the editor links the next
row to it, making an 80-column logical line (`LNMX` = 79). Before linking,
it may open a blank row below so that the following text is pushed down
instead of joined: *Mapping the Commodore 64* (Leemon) describes AUTODN
(`$0292`) as enabling this scroll-down, temporarily suppressed while keys
are waiting in the keyboard buffer. Passing column 79 starts a new
logical line.

Logical lines affect RETURN (it moves to the row *after* the logical
line, so RETURN typed on the first row of a linked pair skips a row), DEL
and INST (they shift across both rows), and the line-insert behaviour
above. Printing exactly 40 characters and then RETURN leaves the cursor
two rows down — one blank row — on any model, because the 40th character
already wrapped the cursor.

### 6.2 The bottom-right cell

Printing the 1000th cell (column 39, row 24) makes the C64 scroll the
screen up immediately, because the cursor must move below the last row.
Art that fills the whole screen therefore cannot be `PRINT`ed without
losing the top row unless it uses tricks (printing the last cell
elsewhere and inserting it with INST).

### 6.3 What CLR and RETURN reset

| Action | Text colour | RVS | Quote mode | Insert count | Character set | Cursor |
|---|---|---|---|---|---|---|
| RETURN / SHIFT+RETURN | kept | **off** | **off** | **0** | kept | next logical line, column 0 |
| CLR | kept | kept | (echoed in quote mode) | (echoed in insert mode) | kept | home |
| HOME | kept | kept | kept | kept | kept | home |

### 6.4 One character set per screen

The set is a single VIC-II bit; switching it redraws every character
already on screen in the new set. A PETSCII picture that switches sets
half-way therefore shows *entirely* in the last set selected (absent
raster-interrupt tricks, which no stream can express). Editors that mix
sets per cell show something no unmodified C64 can display;
SwiftPETSCII keeps the per-cell set so such editors can be emulated
(`CharsetMode.perCell`), but renders the hardware view by default.

`$08`/`$09` only gate the SHIFT+C= keyboard toggle (bit 7 of `$0291`);
`$0E`/`$8E` always switch.

### 6.5 Timing and animation

A stream carries no timing. On a real C64 the display rate is set by the
source: BASIC printing speed, or the line rate of a BBS connection
(roughly baud/10 characters per second — 240 cps at 2400 baud).
PETSCII animations are streams that clear (`$93`) or home (`$13`) and
redraw. SwiftPETSCII captures a frame at every CLR (when the screen being
cleared has any non-blank or reverse cell) and at the end of input, and
gives each frame `Options.defaultFrameDuration`. Animations that redraw
with HOME instead of CLR come out as a single frame showing the final
state.

### 6.6 Unicode mapping choices

Appendix A follows the mapping that Rebecca Bettencourt (KreativeKorp)
prepared for the Unicode 13.0 *Symbols for Legacy Computing* block (U+1FB00
– U+1FBFF, proposal L2/19-025), as also used by Wikipedia's PETSCII
table, with the C64 variants: `£` at screen code `$1C` and set 2's inverse
checkerboard at `$5E`. Older characters (Box Drawing, Block Elements,
Geometric Shapes, card suits, π, •) are used wherever one fits; the
legacy-computing block fills the gaps (one-eighth blocks, medium-shade
halves, diagonal fills). Glyphs that look identical on the C64 but were
distinct on the PET (screen codes `$40`/`$43`, `$67`/`$6A`) keep distinct
characters, so screen code → Unicode is injective within each set.
Rendering U+1FBxx needs a font that covers the block.

---

## 7. Robustness guidance for readers

- **Every byte sequence is valid.** A reader must accept any bytes; the
  only failure conditions are policy limits (below) and, optionally,
  strict rejection of undefined control codes.
- **Bound output.** Each captured frame is 1000 cells; a hostile stream of
  alternating printable and CLR bytes produces one frame per two bytes.
  Cap the number of frames (SwiftPETSCII: `Options.maxFrames`, default
  10,000, then `PETSCIIError.frameLimitExceeded`).
- **Bound state.** The insert count is bounded by the logical-line length
  (79 on a C64); clamp it rather than letting it grow (SwiftPETSCII clamps
  at 40, its line length). Cursor coordinates must be clamped to
  `0..<40`, `0..<25` after every operation; scrolling must not allocate.
- **No lookahead.** Process strictly byte by byte. A stream truncated at
  any offset is simply a shorter valid stream; the screen shows whatever
  was drawn so far.
- **Containers.** Do not guess: if a file starts with `C64File\0`, strip
  26 bytes (§3.3); a `PRG` with load address `$0400` is screen codes, not
  PETSCII (§3.4). Feeding either to a stream decoder silently produces
  garbage rather than an error.
- **Empty input.** SwiftPETSCII's `PETSCIIDocument` throws
  `PETSCIIError.invalidData` for zero bytes; `PETSCIIParser.parse` returns
  no frames. An input of only control codes yields no frames.
- **Unicode output** may contain U+1FBxx characters and U+00A0; consumers
  that need plain ASCII must substitute.

---

## 8. Errata

### 8.1 Errors in circulating PETSCII documentation

1. **"`$0A` is a line feed."** Only on the C128. The C64
   KERNAL ignores `$0A`; a C64 stream needs `$0D` for a new line.
2. **"`$60`–`$7F` and `$E0`–`$FF` are unused/undefined."** When printed on
   a VIC-20, C64, C16/Plus/4 or C128 they are aliases of `$C0`–`$DF` and
   `$A0`–`$BE`, and `$FF` prints π (§4.1, KERNAL `$E739`, `$E7D6`).
3. **"Reverse glyphs are the bitwise inverse of the normal glyphs."** True
   for 127 of the 128 pairs in each set; reverse `@` differs in pixel row 5 (§3.6).
4. **"`CHR$(8)`/`CHR$(9)` lock the character set on every Commodore."** On
   the C128 `$09` is TAB and the SHIFT+C= toggle is disabled and enabled
   with `$0B`/`$0C`.
5. **"Quote mode echoes every control code."** DEL is still executed in
   quote mode, and RETURN/SHIFT+RETURN always execute (§5.3).
6. **"Insert mode behaves like quote mode."** Insert mode echoes DEL (which
   quote mode executes), executes INST (which quote mode echoes) and
   cancels quote mode while blanks remain (§5.3).
7. **"CLR resets the text colour / reverse video."** It changes neither;
   only RETURN turns reverse video off (§6.3).
8. **"DEL at the start of a line does nothing."** Only at home; elsewhere
   it blanks the last cell of the previous row (KERNAL `$E701`).
9. **"The C64 can show both character sets at once."** Not in a PETSCII
   stream; the set is screen-wide (§6.4).

### 8.2 Errors in this package's earlier documentation

Corrected in the pre-1.0 audit (the README on `main` and the first audit
revision of this reference):

1. The README claimed support for Marq's PETSCII Editor `.c` and `.pet`
   exports; neither was ever decoded (only raw streams are).
2. The palette was described as "Pepto-corrected"; the default table was
   (and is) the C64-Wiki palette. Pepto's is now offered separately.
3. The README said character-set switches were respected "on a per-cell
   basis"; the hardware switches the whole screen (§6.4). Per-cell
   rendering is now an explicit option.
4. The README stated that Commodore's IP had been placed in the public
   domain and that the ROM dump was public domain; no such release is
   established. The README now flags the ROM's status as unverified.
5. The first revision of this reference said only that control codes are
   echoed "while quote mode is on or the insert count is non-zero",
   omitting that INST executes in insert mode, that insert mode cancels
   quote mode, and that DEL at column 0 backs onto the previous row; the
   code had the same gaps (fixed, §9).
6. The first revision called the bottom-right deferral (§9) the only
   deferred scroll; every move below row 24 is deferred the same way.

---

## 9. Implementation status

| Feature | Section | Status |
|---|---|---|
| Raw PETSCII streams / extracted `SEQ` files | §3.1, §3.2 | Supported |
| PETSCII → screen code, aliases `$60`–`$7F`, `$E0`–`$FE`, `$FF` | §4.1, §5.1 | Supported |
| Screen code → canonical PETSCII | §5.2 | Supported |
| Set 1 / set 2, screen-wide switching `$0E`/`$8E` | §4.2, §6.4 | Supported (per-cell rendering optional) |
| `$08`/`$09` lock/unlock | §4.3 | Supported (no visible effect, as on a C64) |
| 16 colour codes | §4.4 | Supported |
| Palettes | §4.5 | Supported: C64-Wiki (default), Pepto; custom via `C64Palette(colors:)` |
| RVS ON/OFF; RETURN/SHIFT+RETURN reset RVS, quote and insert mode | §5.3, §6.3 | Supported |
| Cursor up/down/left/right, HOME, CLR | §5.4 | Supported |
| Wrapping and scrolling | §5.4, §6.2 | Supported; any move below row 24 (bottom-right cell, RETURN, CRSR ↓/→) is deferred until later output needs the new row, so a full 1000-cell screen is captured intact; a C64 scrolls at once |
| INST / DEL | §5.5 | Partial: act on the 40-column physical row (INST drops the row's last cell instead of extending the line); DEL at column 0 backs onto the previous row as on a C64 |
| Logical lines (line linking, RETURN skipping a linked row, AUTODN line insert) | §6.1 | Not supported |
| Quote mode and insert mode, in KERNAL test order | §5.3 | Supported (`Options.emulateQuoteMode`, default on) |
| Echoed control codes as reverse glyphs | §5.3 | Supported |
| Reverse video via ROM reverse glyphs | §3.6, §5.6 | Supported |
| Colour of blank cells (INST/DEL/CLR/scroll) | §5.5 | Partial: blanks are stored with light blue rather than the current colour (invisible in the rendered image) |
| Background/border colour | §4.4 | Not part of PETSCII; fixed per parse via `Options.background`; border light blue |
| CLR as frame boundary; end-of-input frame | §6.5 | Supported (blank screens are skipped) |
| Frame timing | §6.5 | Not in the format; fixed `Options.defaultFrameDuration` |
| Undefined control codes | §4.3 | Ignored; `Options.strict` throws `unsupportedControlCode` (including `$0A`) |
| Unicode decoding, both sets, Symbols for Legacy Computing | §5.7, App. A | Supported |
| Unicode encoding (canonical codes) | §5.7 | Supported; throws `unencodableCharacter` |
| C128, VIC-20, PET, TED-only codes and layouts | §1.2, §4.3 | Not supported (C64 model only) |
| PC64 `S00`/`P00`, `PRG` screen dumps, `.d64`, editor project files | §3.3–§3.4 | Not supported |
| Rendering 320 × 200 RGBA / `CGImage` | §5.6 | Supported |

---

## 10. References and provenance

- Commodore Business Machines, *Commodore 64 Programmer's Reference
  Guide* (1982): Appendix C (character codes), Appendix E (screen codes),
  Appendix G (screen and colour memory maps).
- Commodore Business Machines, *Commodore 64 User's Guide* (1982),
  Appendix E (`CHR$` codes).
- Commodore 64 KERNAL ROM 901227-03, screen editor `CHROUT` path
  (`$E716` onwards), studied in publicly circulated commented
  disassemblies of the KERNAL.
- Sheldon Leemon, *Mapping the Commodore 64* (COMPUTE! Books, 1984):
  zero-page and system variables (`$C7`, `$D3`–`$D8`, `$D9`–`$F2`,
  `$0286`, `$0291`, `$0292`).
- Commodore 128 and Plus/4 system guides for the codes of those machines
  (§4.3).
- Rebecca G. Bettencourt (KreativeKorp), PETSCII ↔ Unicode mappings, and
  the Unicode proposal L2/19-025, *Proposal to add characters from legacy
  computers and teletext to the UCS* (Bettencourt et al., 2019), adopted
  in Unicode 13.0 as *Symbols for Legacy Computing*.
- Wikipedia, "PETSCII" (character table cross-check).
- Philip "Pepto" Timmermann, *Calculating the colour palette of the
  VIC-II* (2001) and the Colodore palette (2017).
- C64-Wiki, "Color" (default palette).
- The VICE emulator project, `chargen-901225-01.bin` (character ROM dump
  embedded by SwiftPETSCII; the ROM itself is Commodore's work).
- Markku "Marq" Reunanen, PETSCII Editor; Janne Hellsten, Petmate.
- PC64 file container description (Wolfgang Lorenz's PC64 emulator).

Provenance: this document was written from the public documents listed
above and from black-box observation of the C64 screen editor's
behaviour. Byte values, addresses and tables are facts taken from those
sources; the prose is original. No third-party source code was copied.

---

## Appendix A. Unicode mapping table

Screen codes `$00`–`$3F` map to ASCII (`@`, `A`–`Z`, `[`, `]`, space,
punctuation, digits) except `$1C` → `£` (U+00A3), `$1E` → `↑` (U+2191),
`$1F` → `←` (U+2190); in set 2, `$01`–`$1A` are `a`–`z`. Screen codes
`$40`–`$7F` (PETSCII column lists the canonical code first):

| Screen | PETSCII | Set 1 (unshifted) | Set 2 (shifted) |
|---|---|---|---|
| `40` | `C0`, `60` | U+2500 ─ | U+2500 ─ |
| `41` | `C1`, `61` | U+2660 ♠ | U+0041 A |
| `42` | `C2`, `62` | U+1FB72 🭲 | U+0042 B |
| `43` | `C3`, `63` | U+1FB78 🭸 | U+0043 C |
| `44` | `C4`, `64` | U+1FB77 🭷 | U+0044 D |
| `45` | `C5`, `65` | U+1FB76 🭶 | U+0045 E |
| `46` | `C6`, `66` | U+1FB7A 🭺 | U+0046 F |
| `47` | `C7`, `67` | U+1FB71 🭱 | U+0047 G |
| `48` | `C8`, `68` | U+1FB74 🭴 | U+0048 H |
| `49` | `C9`, `69` | U+256E ╮ | U+0049 I |
| `4A` | `CA`, `6A` | U+2570 ╰ | U+004A J |
| `4B` | `CB`, `6B` | U+256F ╯ | U+004B K |
| `4C` | `CC`, `6C` | U+1FB7C 🭼 | U+004C L |
| `4D` | `CD`, `6D` | U+2572 ╲ | U+004D M |
| `4E` | `CE`, `6E` | U+2571 ╱ | U+004E N |
| `4F` | `CF`, `6F` | U+1FB7D 🭽 | U+004F O |
| `50` | `D0`, `70` | U+1FB7E 🭾 | U+0050 P |
| `51` | `D1`, `71` | U+2022 • | U+0051 Q |
| `52` | `D2`, `72` | U+1FB7B 🭻 | U+0052 R |
| `53` | `D3`, `73` | U+2665 ♥ | U+0053 S |
| `54` | `D4`, `74` | U+1FB70 🭰 | U+0054 T |
| `55` | `D5`, `75` | U+256D ╭ | U+0055 U |
| `56` | `D6`, `76` | U+2573 ╳ | U+0056 V |
| `57` | `D7`, `77` | U+25CB ○ | U+0057 W |
| `58` | `D8`, `78` | U+2663 ♣ | U+0058 X |
| `59` | `D9`, `79` | U+1FB75 🭵 | U+0059 Y |
| `5A` | `DA`, `7A` | U+2666 ♦ | U+005A Z |
| `5B` | `DB`, `7B` | U+253C ┼ | U+253C ┼ |
| `5C` | `DC`, `7C` | U+1FB8C 🮌 | U+1FB8C 🮌 |
| `5D` | `DD`, `7D` | U+2502 │ | U+2502 │ |
| `5E` | `DE`, `7E`, `FF` | U+03C0 π | U+1FB96 🮖 |
| `5F` | `DF`, `7F` | U+25E5 ◥ | U+1FB98 🮘 |
| `60` | `A0`, `E0` | U+00A0 (no-break space) | U+00A0 (no-break space) |
| `61` | `A1`, `E1` | U+258C ▌ | U+258C ▌ |
| `62` | `A2`, `E2` | U+2584 ▄ | U+2584 ▄ |
| `63` | `A3`, `E3` | U+2594 ▔ | U+2594 ▔ |
| `64` | `A4`, `E4` | U+2581 ▁ | U+2581 ▁ |
| `65` | `A5`, `E5` | U+258F ▏ | U+258F ▏ |
| `66` | `A6`, `E6` | U+2592 ▒ | U+2592 ▒ |
| `67` | `A7`, `E7` | U+2595 ▕ | U+2595 ▕ |
| `68` | `A8`, `E8` | U+1FB8F 🮏 | U+1FB8F 🮏 |
| `69` | `A9`, `E9` | U+25E4 ◤ | U+1FB99 🮙 |
| `6A` | `AA`, `EA` | U+1FB87 🮇 | U+1FB87 🮇 |
| `6B` | `AB`, `EB` | U+251C ├ | U+251C ├ |
| `6C` | `AC`, `EC` | U+2597 ▗ | U+2597 ▗ |
| `6D` | `AD`, `ED` | U+2514 └ | U+2514 └ |
| `6E` | `AE`, `EE` | U+2510 ┐ | U+2510 ┐ |
| `6F` | `AF`, `EF` | U+2582 ▂ | U+2582 ▂ |
| `70` | `B0`, `F0` | U+250C ┌ | U+250C ┌ |
| `71` | `B1`, `F1` | U+2534 ┴ | U+2534 ┴ |
| `72` | `B2`, `F2` | U+252C ┬ | U+252C ┬ |
| `73` | `B3`, `F3` | U+2524 ┤ | U+2524 ┤ |
| `74` | `B4`, `F4` | U+258E ▎ | U+258E ▎ |
| `75` | `B5`, `F5` | U+258D ▍ | U+258D ▍ |
| `76` | `B6`, `F6` | U+1FB88 🮈 | U+1FB88 🮈 |
| `77` | `B7`, `F7` | U+1FB82 🮂 | U+1FB82 🮂 |
| `78` | `B8`, `F8` | U+1FB83 🮃 | U+1FB83 🮃 |
| `79` | `B9`, `F9` | U+2583 ▃ | U+2583 ▃ |
| `7A` | `BA`, `FA` | U+1FB7F 🭿 | U+2713 ✓ |
| `7B` | `BB`, `FB` | U+2596 ▖ | U+2596 ▖ |
| `7C` | `BC`, `FC` | U+259D ▝ | U+259D ▝ |
| `7D` | `BD`, `FD` | U+2518 ┘ | U+2518 ┘ |
| `7E` | `BE`, `FE` | U+2598 ▘ | U+2598 ▘ |
| `7F` | `BF` | U+259A ▚ | U+259A ▚ |

### Round-trip properties

- Within one set, screen code → Unicode → screen code is exact for all
  128 codes.
- PETSCII → Unicode → PETSCII folds aliases onto canonical codes
  (`$60`–`$7F` → `$C0`–`$DF`, `$E0`–`$FE` → `$A0`–`$BE`, `$FF` → `$DE`).
- Reverse video, colours and the character set are not represented in
  Unicode; the set must be known to decode.
- Control codes have no Unicode form. Lowercase letters cannot be encoded
  in set 1; set-1 graphics at `$41`–`$5A`, π, ◥, ◤ and the set-1 corner
  block cannot be encoded in set 2.
