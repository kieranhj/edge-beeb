"""mechanical.py - the C64 and CPC conversions, in one place.

Layer 1 converted the C64's charset and sprites mechanically and Layer 8a did
the same for the Amstrad's; both used to live inside export_tiles.py and
export_sprites.py. They are here now because three callers want them:

  * the exporters, when the build is asked for those sources directly;
  * tools/seed_art.py, which writes the artist's sheets from one of them;
  * the PNG path's FALLBACK, which is what a cell the artist has not drawn yet
    falls back to, so a partial drop still builds a complete game.

Everything returns the same shape the sheets do: characters as 256 cells of 8
rows of 4 BBC logical colours, sprite frames as 119 cells of 21 rows of 12.
"""

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bbc  # noqa: E402

C64_ASM = "source_c64/edge_grinder.asm"

FRAMES = 119
DP_ENTRIES = 126          # sprite_dp_dcd / sprite_col_dcd length
VIC_BASE = 0x60           # sprite_dp_dcd value of frame 0
ROWS, WIDE = 21, 12


def _cpc():
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "cpc"))
    import bbcart
    return bbcart


# --- characters -----------------------------------------------------------

def char_colour(value, col_decode_entry):
    if value == 0:
        c64 = bbc.C64_BG
    elif value == 1:
        c64 = bbc.C64_MC1
    elif value == 2:
        c64 = bbc.C64_MC2
    else:
        c64 = col_decode_entry & 7
    return bbc.C64_TO_BBC[c64]


def characters(cpc=False):
    """256 characters, each 8 rows of 4 BBC logical colours."""
    if cpc:
        return _cpc().characters()
    col_decode = bbc.parse_c64_table(C64_ASM, "col_decode", 256)
    return [[[char_colour(v, col_decode[n]) for v in bbc.c64_pixels(row)]
             for row in char]
            for n, char in enumerate(bbc.load_chars())]


# --- sprite frames --------------------------------------------------------

def dp_tables():
    """sprite_col_dcd and sprite_dp_dcd from the C64 source. Game logic, not
    art: which frames flash and when is the same under every art source."""
    return (bbc.parse_c64_table(C64_ASM, "sprite_col_dcd", DP_ENTRIES),
            bbc.parse_c64_table(C64_ASM, "sprite_dp_dcd", DP_ENTRIES))


def frame_colours(col_dcd, dp_dcd):
    """Frame -> C64 colour. Every dp that maps to a frame names the same one."""
    out = {}
    for dp in range(DP_ENTRIES):
        f = dp_dcd[dp] - VIC_BASE
        assert 0 <= f < FRAMES, (dp, dp_dcd[dp])
        c = col_dcd[dp] & 15
        assert out.setdefault(f, c) == c, f
    assert len(out) == FRAMES
    return out


def frame_pixels(raw, colour_c64):
    """21 rows x 12 fat pixels of BBC logical colour (0 = transparent)."""
    lut = {0: 0, 1: bbc.C64_TO_BBC[bbc.C64_SPR_MC1], 3: bbc.C64_TO_BBC[bbc.C64_SPR_MC2],
           2: bbc.C64_TO_BBC[colour_c64]}
    rows = []
    for r in range(ROWS):
        row = []
        for b in raw[r * 3:r * 3 + 3]:
            row += [lut[v] for v in bbc.c64_pixels(b)]
        rows.append(row)
    return rows


def sprites(cpc=False, count=FRAMES):
    """`count` frames, each 21 rows of 12 BBC logical colours, 0 transparent."""
    if cpc:
        return _cpc().sprites(count)
    raw = bbc.load_sprites(count=count)
    colour = frame_colours(*dp_tables())
    return [frame_pixels(raw[f], colour[f]) for f in range(count)]
