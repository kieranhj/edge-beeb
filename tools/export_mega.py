"""export_mega.py - the completion sequence's "MEGA HERO" message.

`comp_mess` in the C64 original writes character $80 into buffer_2 wherever
`mega_hero_txt` holds $20, one cell a field: 6 rows of 40 cells at screen row
8, then a second block of the same shape at row 16, revealed backwards. It is
NOT a font - it is two 240-cell on/off bitmaps and one repeated character - so
nothing here needs drawing, only converting.

A C64 character is four multicolour pixels, which is four of our fat pixels,
which is two MODE 2 byte columns: 40 cells across is our full 160-pixel width
and the cell transcribes 1:1 into 16 bytes, exactly as the zoom scroller's
block does. The colour is the original's own: `comp_mess` writes $0d, light
green, into colour RAM for every cell of the message, over whatever
`col_decode` would have given character $80 (cyan, and the character appears
in no tile, so the override is the only colour it ever has).

Output: src/data/mega.bin, 77 bytes
      0..15   the block cell - byte column 0's eight scanlines, then column 1's
        16    the index of the cell's first NON-ZERO byte. The original asks
              the screen "is a letter here already?" before it blanks the cell
              behind one, and comparing the whole cell would cost sixteen
              reads; this says which single byte to compare, and picking a
              byte that is not blank is what keeps the answer meaningful when
              the artwork changes.
     17..46   "MEGA": 240 bits, 5 bytes a row x 6 rows, bit 7 the leftmost cell
     47..76   "HERO", REVERSED: the second block is revealed from its last cell
              backwards, so byte j holds cells 239-8j down to 232-8j and one
              ASL a step serves both blocks

With --cpc the block cell comes from the Amstrad port's character set instead
and is written to mega-cpc.bin; the two bitmaps are the message itself and are
the same in both builds.

Run from the project root: python tools/export_mega.py [--cpc]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bbc  # noqa: E402

OUT = "src/data"
C64_ASM = "source_c64/edge_grinder.asm"

BLOCK_CHAR = 0x80       # what comp_mess writes where the bitmap is set
BLOCK_COLOUR = 0x0d     # ...and what it writes into colour RAM for it
CELLS = 240             # 6 rows of 40
SET = 0x20              # a set cell in mega_hero_txt


def block_cell(cpc):
    """Character $80 as one 16-byte MODE 2 cell, two byte columns of eight."""
    if cpc:
        sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "cpc"))
        import bbcart
        px = bbcart.characters()[BLOCK_CHAR]
    else:
        char = bbc.load_chars()[BLOCK_CHAR]
        px = [[bbc.C64_TO_BBC[{0: bbc.C64_BG, 1: bbc.C64_MC1, 2: bbc.C64_MC2}[v]
                              if v < 3 else BLOCK_COLOUR]
               for v in bbc.c64_pixels(row)] for row in char]
    out = bytearray()
    for col in (0, 1):
        for row in range(8):
            out.append(bbc.mode2_byte(px[row][2 * col], px[row][2 * col + 1]))
    return out


def bitmaps():
    """The two 240-cell blocks, as bits; the second one back to front."""
    txt = bbc.parse_c64_table(C64_ASM, "mega_hero_txt", 512)
    assert set(txt) <= {0, SET}, "mega_hero_txt should be $00 or $20 throughout"
    out = bytearray()
    for base, reverse in ((0x000, False), (0x100, True)):
        cells = [txt[base + i] for i in range(CELLS)]
        if reverse:
            cells.reverse()
        for j in range(CELLS // 8):
            b = 0
            for k in range(8):
                if cells[j * 8 + k]:
                    b |= 0x80 >> k
            out.append(b)
    return out


def main(cpc=False):
    os.makedirs(OUT, exist_ok=True)
    cell = block_cell(cpc)
    key = next(i for i, b in enumerate(cell) if b)
    data = cell + bytes([key]) + bitmaps()
    name = "mega-cpc.bin" if cpc else "mega.bin"
    open(f"{OUT}/{name}", "wb").write(data)
    print(f"{name} {len(data)} B (block cell, key byte {key}, "
          f"two {CELLS}-cell bitmaps)")


if __name__ == "__main__":
    main("--cpc" in sys.argv)
