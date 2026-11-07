# ``SwiftPETSCII``

Decode, render and convert Commodore 64 PETSCII streams.

## Overview

PETSCII is the character encoding of Commodore's 8-bit computers. On the
C64 a PETSCII stream mixes printable characters with control codes for
colors, reverse video, cursor movement and character-set switching; BBS
art, `SEQ` files and PETSCII animations are such streams.

SwiftPETSCII plays a stream through a model of the C64 KERNAL screen
editor (``PETSCIIParser``) and captures each 40×25 screen as a
``PETSCIIFrame``. ``PETSCIIRenderer`` draws screens with the original
character ROM (``C64CharROM``), and ``PETSCIIToUnicode`` converts between
PETSCII and Unicode, including the Unicode 13 Symbols for Legacy Computing
block.

The supported machine is the Commodore 64.

## Topics

### Essentials

- <doc:GettingStarted>
- ``PETSCIIDocument``
- ``PETSCIIFrame``

### Decoding

- ``PETSCIIParser``
- ``PETSCIIControlCode``
- ``PETSCIIError``

### Screen model

- ``PETSCIIScreen``
- ``PETSCIICell``
- ``PETSCIICharset``
- ``C64Color``

### Rendering

- ``PETSCIIRenderer``
- ``C64Palette``
- ``C64CharROM``

### Text conversion

- ``PETSCIIToUnicode``
