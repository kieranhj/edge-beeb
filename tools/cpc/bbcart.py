"""bbcart.py - the CPC's own artwork as BBC logical colours.

GFX_CPC (decision 41) builds the game from Trevor Storey's Amstrad CPC art
instead of the C64's. This is the one place that reads it: the exporters ask
for characters or sprite frames here and are otherwise unchanged, because the
CPC's geometry is the C64's exactly - a character is 4 fat pixels by 8 rows, a
sprite frame 12 by 21 - and the tile, map, character and frame NUMBERS are the
same in both ports (see tools/rip_cpc_sprites.py and rip_cpc_background.py for
how that was checked).

What is not the same is the colour. The C64 art has three shared colours and
one per-object colour, which is what src/sprite.asm's flash tables assume; CPC
mode 0 art carries fifteen colours per frame and no per-object colour at all.
So the flash tables keep only the transparency key (export_sprites.py's KEEP).

**A pen is a DITHER PAIR, not one colour** (decision 55). It used to be one:
a hand-written bbc.CPC_TO_BBC table sent each pen to its nearest BBC hue, and
that threw away most of what mode 0 is for - pens 8, 10, 12 and 13 all landed
on cyan, pens 2 and 11 both on yellow, and the art flattened. Rich Talbot-
Watkins's scheme instead approximates each of the CPC's 27 colours with two
MODE 2 colours checkerboarded a pixel at a time; `bbc.dither_pair` is the rule
and reference/cpc-palette-map-to-bbc-mode2.png is his chart of the results.
Nine of the game's sixteen pens dither and seven are colours MODE 2 already
has, so those come back unchanged.

The checkerboard is `(x + y) & 1` in the ART's own coordinates, and the pair is
ordered darkest first, so parity 0 takes the darker colour. Art coordinates,
not screen ones, because that is the only phase the hardware will hold: the
dither is baked into the character and sprite bitmaps, so it travels with the
scenery as it scrolls and with a sprite as it moves, instead of crawling
against them. A character is 4 pixels by 8 and both are even, so every
character in a tile and every tile on the map shares one continuous
checkerboard.

Transparency is per BYTE, not per pixel: PrintSprites in EG_Sprites10.asm tests
a whole byte for zero and skips it, so a pen 0 pixel beside a lit one is drawn
black, and only a zero byte is see-through.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
import bbc          # noqa: E402
import bgdata       # noqa: E402
import cpcscr       # noqa: E402
from dsk import Dsk  # noqa: E402

SPRITE_DSK = os.path.join('source_cpc', 'Work Disks', 'edge_sprites2.dsk')
SPRITE_FILE = (0, 'SPRITES', 'BIN')
SLOT = 128                # bytes per sprite slot in the bank; 126 used
ROWS, WIDE = 21, 12

# The sixteen in-game pens as (dark, light) pairs of BBC physical colours.
PEN_DITHER = [bbc.dither_pair(rgb) for rgb in cpcscr.mode0_rgb()]


def _pen(p, x, y, transparent_black):
    """One CPC pen at art position (x, y) as a BBC logical colour: the darker
    half of its dither pair on even parity, the lighter on odd."""
    c = PEN_DITHER[p][(x + y) & 1]
    if c == bbc.BLACK and not transparent_black:
        return bbc.SPRITE_BLACK      # 0 is the sprite engine's transparency key
    return c


def characters():
    """256 characters, each 8 rows of 4 BBC logical colours. Black is black:
    a character is opaque, so logical 0 is free to mean it."""
    chars = bgdata.read_defb(bgdata.CHARS)
    return [[[_pen(p, x, y, True) for x, p in enumerate(row)]
             for y, row in enumerate(bgdata.character(chars, n, cpcscr._decode))]
            for n in range(256)]


def sprites(count):
    """`count` frames, each 21 rows of 12 BBC logical colours, 0 transparent."""
    bank = cpcscr.strip_amsdos(Dsk(SPRITE_DSK).catalogue()[SPRITE_FILE])
    out = []
    for n in range(count):
        f = bank[n * SLOT:n * SLOT + 126]
        rows = [[0] * WIDE for _ in range(ROWS)]

        def put(row, col, byte):
            if byte:
                rows[row][col * 2:col * 2 + 2] = [
                    _pen(p, col * 2 + i, row, False)
                    for i, p in enumerate(cpcscr._decode(byte, 0))]

        for pair in range(10):
            for col in range(6):
                put(pair * 2 + 1, col, f[pair * 12 + col * 2])
                put(pair * 2, col, f[pair * 12 + col * 2 + 1])
        for col in range(6):
            put(20, col, f[120 + col])
        out.append(rows)
    return out
