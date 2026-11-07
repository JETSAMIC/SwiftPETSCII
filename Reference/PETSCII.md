# PETSCII on the Commodore 64

Reference for SwiftPETSCII. It covers the C64's character sets, the
mapping between PETSCII codes and screen codes, the control codes the C64
screen editor acts on, the Unicode mapping, and what SwiftPETSCII does and
does not emulate.

Sources: *Commodore 64 Programmer's Reference Guide* (Appendices C, E, G),
*Commodore 64 User's Guide* (Appendix E), the C64 KERNAL screen editor
(CHROUT at `$FFD2` → `$E716`), the VICE `chargen-901225-01.bin` ROM dump,
KreativeKorp's PETSCII-to-Unicode mapping and Unicode proposal L2/19-025
("Symbols for Legacy Computing", Unicode 13.0), and style64.org's PETSCII
reference.

## 1. Supported machine

SwiftPETSCII models a **Commodore 64** (PAL or NTSC — text mode is
identical): a 40 × 25 screen, the 901225-01 character ROM, and the 16
VIC-II colors. A C128 in 40-column mode shares everything below except the
C128-only control codes (§5.3), which SwiftPETSCII ignores.

Not supported (§8): the VIC-20 (22 × 23 screen, 8 text colors), the PET
family (no color, different font, 40/80 columns), the C128's 80-column VDC
mode, and the Plus/4 and C16 (TED: 121 colors, flash).

## 2. Two codes for every character

The C64 uses two different byte encodings:

- **PETSCII** — what programs `PRINT`, what is stored in `SEQ` files and
  sent over BBS connections. It contains control codes.
- **Screen codes** — what is stored in screen RAM (`$0400`…) and used as the
  index into the character ROM. Bit 7 selects the reverse-video glyph.

The KERNAL converts PETSCII to screen codes as it prints:

| PETSCII | Screen code | Contents |
|---|---|---|
| `00`–`1F` | — | control codes (`80`–`9F` reverse glyph shown in quote mode) |
| `20`–`3F` | `20`–`3F` | space, punctuation, digits |
| `40`–`5F` | `00`–`1F` | `@`, letters, `[ £ ] ↑ ←` |
| `60`–`7F` | `40`–`5F` | **duplicate** of `C0`–`DF` |
| `80`–`9F` | — | control codes (`C0`–`DF` reverse glyph shown in quote mode) |
| `A0`–`BF` | `60`–`7F` | graphics |
| `C0`–`DF` | `40`–`5F` | graphics (set 1) / uppercase letters (set 2) |
| `E0`–`FE` | `60`–`7E` | **duplicate** of `A0`–`BE` |
| `FF` | `5E` | **duplicate** of `DE` (π in set 1) |

The canonical codes are `C0`–`DF` and `A0`–`BF`; `60`–`7F`, `E0`–`FE` and
`FF` are what the keyboard / `GET` may return and print the same glyphs.
Converting screen code → PETSCII therefore always yields the canonical code.

## 3. Character sets

The character ROM holds two 256-glyph sets of 8 × 8 pixels. In each set,
glyphs `80`–`FF` are the reverse-video forms of `00`–`7F` (the ROM's
reverse `@` is not an exact inversion — renderers must use the ROM glyph,
not invert bits).

| | Set 1 — "unshifted", uppercase/graphics | Set 2 — "shifted", lowercase/uppercase |
|---|---|---|
| Default | yes, at power-on | — |
| Selected by | PETSCII `8E` | PETSCII `0E` |
| Screen `01`–`1A` | `A`–`Z` | `a`–`z` |
| Screen `41`–`5A` | graphics (♠, lines, ♥, …) | `A`–`Z` |
| Screen `5E` | π | inverse checkerboard |
| Screen `5F` | ◥ | diagonal fill ╲ |
| Screen `69` | ◤ | diagonal fill ╱ |
| Screen `7A` | corner piece | ✓ check mark |

All other screen codes are identical in both sets.

The set is a VIC-II setting and applies to the **whole screen at once**;
switching it changes every character already on screen. SHIFT+Commodore
toggles the set from the keyboard; `08` disables and `09` re-enables that
key combination (the codes `0E`/`8E` work regardless).

## 4. Colors

PETSCII selects the text color; the background and border are set with
`POKE 53281`/`53280` and cannot be changed by PETSCII codes.

| Index | Color | PETSCII | | Index | Color | PETSCII |
|---|---|---|---|---|---|---|
| 0 | black | `90` | | 8 | orange | `81` |
| 1 | white | `05` | | 9 | brown | `95` |
| 2 | red | `1C` | | 10 | light red | `96` |
| 3 | cyan | `9F` | | 11 | dark gray | `97` |
| 4 | purple | `9C` | | 12 | medium gray | `98` |
| 5 | green | `1E` | | 13 | light green | `99` |
| 6 | blue | `1F` | | 14 | light blue | `9A` |
| 7 | yellow | `9E` | | 15 | light gray | `9B` |

Boot defaults: light blue text on a blue background with a light blue
border. The VIC-II outputs analog video, so RGB values are a choice;
SwiftPETSCII ships the C64-Wiki table (default) and Pepto's measured PAL
palette.

## 5. Control codes

### 5.1 C64 screen controls

| Code | Name | Effect |
|---|---|---|
| `05`, `1C`, `1E`, `1F`, `81`, `90`, `95`–`9C`, `9E`, `9F` | colors | set text color (§4) |
| `08` | lock case | disable SHIFT+C= set toggle (no visible effect) |
| `09` | unlock case | re-enable SHIFT+C= |
| `0D` | RETURN | cursor to column 0 of the next line; **RVS off; quote mode off; insert count 0** |
| `8D` | SHIFT+RETURN | same screen effect as `0D` |
| `0E` | lowercase | switch to set 2 |
| `8E` | uppercase | switch to set 1 |
| `11` | cursor down | scrolls on the bottom line |
| `91` | cursor up | stops at the top line |
| `1D` | cursor right | wraps to the next line; scrolls after the bottom-right cell |
| `9D` | cursor left | wraps to the end of the previous line; stops at home |
| `12` | RVS ON | following characters stored with screen-code bit 7 set |
| `92` | RVS OFF | |
| `13` | HOME | cursor to top left, screen unchanged |
| `93` | CLR | clear screen, cursor home (colors, RVS, set unchanged) |
| `14` | DEL | delete the character **left** of the cursor; rest of the line moves left |
| `94` | INST | insert a blank at the cursor; rest of the line moves right; insert count +1 |

All other codes in `00`–`1F` and `80`–`9F` have no screen effect on a C64
(`03` STOP and `83` RUN are keyboard codes; `85`–`8C` are the function keys
F1–F8).

### 5.2 Printing, wrapping and scrolling

Printing a character stores its screen code and the current color at the
cursor and advances it; after column 39 the cursor wraps to the next line.
Moving below line 24 — by printing, RETURN, or cursor down — scrolls the
screen up one line. Printing the bottom-right cell therefore scrolls the
screen on a real C64.

The screen editor links physical lines into logical lines of up to 80
characters; RETURN after exactly 40 characters therefore leaves a blank
line, and INST/DEL operate on the whole logical line.

### 5.3 Quote mode and insert mode

Printing `"` toggles **quote mode**. While it is on, and while the insert
count from INST is non-zero, control codes are not executed but shown as
reverse-video glyphs: `00`–`1F` → screen `80`–`9F`, `80`–`9F` → screen
`C0`–`DF` (CLR shows as a reverse ♥). RETURN ends both modes. DEL still
deletes in quote mode but is echoed in insert mode. Every printed
character decrements the insert count.

### 5.4 Codes of other machines

| Code | C128 | VIC-20 | PET |
|---|---|---|---|
| `02` / `82` | underline on/off (80-col) | — | — |
| `07` | bell | — | — |
| `09` | TAB (lock/unlock moved to `0B`/`0C`) | unlock case | — |
| `0A` | line feed | — | — |
| `0F` / `8F` | flash on/off (80-col) | — | — |
| `18` | tab set/clear | — | — |
| `1B` | ESC (escape sequences) | — | — |
| `81`, `95`–`9B` | colors as C64 | not colors (only 8 colors) | no colors |
| `0E` / `8E` | as C64 | as C64 | set switch on later PETs |

## 6. Unicode mapping

Screen codes `00`–`3F` map to ASCII except: `1C` → `£` (U+00A3), `1E` →
`↑` (U+2191), `1F` → `←` (U+2190), and in set 2 `01`–`1A` → `a`–`z`.
Screen codes `40`–`7F`:

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

The table is KreativeKorp's mapping, which is the basis of the Unicode 13
"Symbols for Legacy Computing" proposal (L2/19-025). Characters at
U+1FBxx need a font that covers that block.

### Round-trip lossiness

- Within one set, screen code → Unicode → screen code is exact for all 128
  codes.
- PETSCII → Unicode → PETSCII folds the duplicate codes onto the canonical
  ones (`60`–`7F` → `C0`–`DF`, `E0`–`FE` → `A0`–`BE`, `FF` → `DE`).
- Reverse video (screen codes `80`–`FF`), colors, and the character set
  are not represented in Unicode; the set must be known to decode.
- Control codes have no Unicode form. Lowercase letters cannot be encoded
  for set 1, and set-1 graphics at `41`–`5A` cannot be encoded for set 2.
- Glyphs that are pixel-identical on the C64 but distinct on the PET
  (screen `40`/`43`, `67`/`6A`, …) keep distinct Unicode characters.

## 7. SEQ files and other containers

A `SEQ` file is a raw PETSCII stream with no header; a BBS capture is the
same. Such streams are what SwiftPETSCII decodes: it plays the stream
through the screen editor model and captures a frame at every CLR (`93`)
and at the end of input.

Not decoded: `PRG` screen dumps (2-byte load address + screen/color RAM),
Marq's PETSCII Editor `.c` (C source) and `.pet` (binary) exports, Petmate
`.petmate` (JSON), and `.d64` disk images.

## 8. What SwiftPETSCII emulates

| Feature | Status |
|---|---|
| PETSCII → screen code, both duplicate ranges, `FF` → π | Supported |
| Both character sets; screen-wide switching (`0E`/`8E`) | Supported (per-cell rendering optional) |
| `08`/`09` lock/unlock | Supported (no-op, as on the C64) |
| 16 colors | Supported (C64-Wiki and Pepto palettes) |
| RVS ON/OFF; RETURN turns RVS off | Supported |
| Cursor movement, HOME, CLR | Supported |
| Wrapping and scrolling | Supported; the scroll caused by the bottom-right cell is deferred until more output needs it, so a full 1000-character screen is captured intact |
| INST/DEL | Supported on the 40-column physical line; logical-line linking is not modelled |
| Quote mode and insert mode | Supported (can be disabled) |
| ROM reverse glyphs | Supported |
| Background/border colors | Fixed per parse (`Options`); not settable from the stream |
| C128-only codes, VIC-20, PET | Not supported (ignored / out of scope) |
| Frame timing | Not in the format; fixed per-frame duration |
