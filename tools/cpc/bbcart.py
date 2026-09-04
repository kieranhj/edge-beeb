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
So a pen goes straight through bbc.CPC_TO_BBC and the flash tables keep only
the transparency key (export_sprites.py's KEEP).

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


def _pen(p, transparent_black):
    """One CPC pen as a BBC logical colour."""
    c = bbc.CPC_TO_BBC[p]
    if c == bbc.BLACK and not transparent_black:
        return bbc.SPRITE_BLACK      # 0 is the sprite engine's transparency key
    return c


def characters():
    """256 characters, each 8 rows of 4 BBC logical colours. Black is black:
    a character is opaque, so logical 0 is free to mean it."""
    chars = bgdata.read_defb(bgdata.CHARS)
    return [[[_pen(p, True) for p in row]
             for row in bgdata.character(chars, n, cpcscr._decode)]
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
                    _pen(p, False) for p in cpcscr._decode(byte, 0)]

        for pair in range(10):
            for col in range(6):
                put(pair * 2 + 1, col, f[pair * 12 + col * 2])
                put(pair * 2, col, f[pair * 12 + col * 2 + 1])
        for col in range(6):
            put(20, col, f[120 + col])
        out.append(rows)
    return out
