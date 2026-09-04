"""The CPC background bank: the 256 characters and the 4 x 4 tile table.

BackgroundBank.asm lays the bank out at &4000 - code, the map, the tiles at
&5000, the characters at &6000 - and Block_Writer4.asm's Fill_Buffer says how
both are read. Both are stored TRANSPOSED, tile or character number in the low
byte, so the reader only ever walks the high byte:

  tile:  &5000 + (col * 4 + row) * 256 + tile   -> character number
  char:  &6000 + i * 256 + char                 -> the character's LEFT byte
         &6800 + i * 256 + char                 -> its RIGHT byte

A character is two mode 0 bytes - 4 pixels - by 8 lines, exactly the shape of a
C64 multicolour character; a tile is 4 x 4 characters. The C64's own tile table
is row-major, so C64 tile[row * 4 + col] is CPC tile[col * 4 + row]; the tile
and character NUMBERS are the same in both ports.

Two twists in the character data, both from Block_Writer4:

  * i is not the pixel line. Copy_Buffer walks the eight lines of a character
    row by flipping bits 3-5 of the screen address in the cheapest order and
    its comments name the line it just wrote: 1, 2, 4, 3, 7, 8, 6, 5. The
    column buffer is filled in step with the character bytes, so byte i lands
    on line LINE_ORDER[i].
  * The two pixels of every odd-numbered byte are stored swapped - the source
    says "even bytes stored swapped", counting from one. LowCharWrite masks
    with &55 on even bytes and rotates first on odd ones; HighCharWrite does
    the opposite.
"""
import os

LINE_ORDER = (0, 1, 3, 2, 6, 7, 5, 4)

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
CHARS = os.path.join(ROOT, 'source_cpc', 'Source', 'char_graphic5.ASM')
TILES = os.path.join(ROOT, 'source_cpc', 'Source', 'EG_Tiles_Formatted.asm')


def read_defb(path):
    """The bytes of a source file that is nothing but defb lines."""
    out = bytearray()
    for line in open(path):
        line = line.split(';')[0].strip()
        if line.lower().startswith('defb'):
            out += bytes(int(v, 0) for v in line[4:].split(','))
    return bytes(out)


def character(chars, n, decode):
    """Character n as 8 rows, top first, of 4 pen indices."""
    rows = [None] * 8
    for i in range(8):
        pens = decode(chars[i * 256 + n], 0) + decode(chars[0x800 + i * 256 + n], 0)
        if i & 1:
            pens = [pens[1], pens[0], pens[3], pens[2]]
        rows[LINE_ORDER[i]] = pens
    return rows


def tile_char(tiles, tile, col, row):
    return tiles[(col * 4 + row) * 256 + tile]
