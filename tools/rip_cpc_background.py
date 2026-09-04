"""rip_cpc_background.py - the CPC background art -> sheets in the C64 format.

Writes, in the format of the C64 sheets beside them:

  reference/characters-cpc.png  256 x 256, 16 characters a row, each 16 x 16
                                (a pixel 4 across and 2 down), all 256
  reference/tiles-cpc.png       512 x 448, 16 tiles a row, each 32 x 32 - 4 x 4
                                characters at 8 x 8, a pixel 2 across - with
                                the 211 real tiles and the 13 spare cells grey

Source: source_cpc/Source/char_graphic5.ASM and EG_Tiles_Formatted.asm, the
data halves of the CPC's background bank. tools/cpc/bgdata.py holds how they
are indexed and the two twists in the character data.

The numbering is the C64's, checked rather than assumed: the CPC tile table is
the C64's transposed, character number for character number, and rendering the
tile sheet puts every shape in the cell reference/tiles.png puts it in.

Palette: Mode0Pal from Compiled_Main3.asm, the in-game one - see
tools/cpc/cpcscr.py. The CPC has no colour RAM, so unlike the C64 sheets every
character carries its own colours and nothing here is per-character tinted.

Run from the project root: python tools/rip_cpc_background.py
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "cpc"))
import bgdata  # noqa: E402
import cpcscr  # noqa: E402

CHAR_OUT = os.path.join("reference", "characters-cpc.png")
TILE_OUT = os.path.join("reference", "tiles-cpc.png")

CHARS = 256
TILES = 211               # the C64 tile table's length; the bank has 256 slots
PER_ROW = 16
SPARE = (68, 68, 68)      # reference/tiles.png's colour for a cell with no tile


def characters(chars, rgb):
    """256 x 256: a character 16 x 16, so a pixel is 4 across and 2 down."""
    im = Image.new("P", (PER_ROW * 16, (CHARS // PER_ROW) * 16))
    im.putpalette([v for c in rgb for v in c])
    px = im.load()
    for n in range(CHARS):
        ox, oy = (n % PER_ROW) * 16, (n // PER_ROW) * 16
        for y, row in enumerate(bgdata.character(chars, n, cpcscr._decode)):
            for x, pen in enumerate(row):
                for dx in range(4):
                    for dy in range(2):
                        px[ox + x * 4 + dx, oy + y * 2 + dy] = pen
    return im


def tiles(chars, tiles_, rgb):
    """512 x 448: a tile 4 x 4 characters at 8 x 8, so a pixel is 2 across."""
    rows = -(-TILES // PER_ROW)
    im = Image.new("RGBA", (PER_ROW * 32, rows * 32), SPARE + (255,))
    px = im.load()
    cache = {}
    for t in range(TILES):
        ox, oy = (t % PER_ROW) * 32, (t // PER_ROW) * 32
        for col in range(4):
            for row in range(4):
                n = bgdata.tile_char(tiles_, t, col, row)
                if n not in cache:
                    cache[n] = bgdata.character(chars, n, cpcscr._decode)
                for y, line in enumerate(cache[n]):
                    for x, pen in enumerate(line):
                        c = rgb[pen] + (255,)
                        sx, sy = ox + col * 8 + x * 2, oy + row * 8 + y
                        px[sx, sy] = px[sx + 1, sy] = c
    return im


def main():
    chars = bgdata.read_defb(bgdata.CHARS)
    tiles_ = bgdata.read_defb(bgdata.TILES)
    rgb = cpcscr.mode0_rgb()

    im = characters(chars, rgb)
    im.save(CHAR_OUT)
    print(f"{CHAR_OUT}: {im.size[0]}x{im.size[1]}, {CHARS} characters")
    im = tiles(chars, tiles_, rgb)
    im.save(TILE_OUT)
    print(f"{TILE_OUT}: {im.size[0]}x{im.size[1]}, {TILES} tiles")


if __name__ == "__main__":
    main()
