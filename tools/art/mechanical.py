"""mechanical.py - the C64 and CPC conversions, in one place.

Layer 1 converted the C64's charset and sprites mechanically and Layer 8a did
the same for the Amstrad's; both used to live inside export_tiles.py and
export_sprites.py. They are here now because three callers want them:

  * the exporters, when the build is asked for those sources directly;
  * tools/seed_art.py, which writes the artist's sheets from one of them;
  * the PNG path's FALLBACK, which is what a cell the artist has not drawn yet
    falls back to, so a partial drop still builds a complete game.

Everything returns the same shape the sheets do, as cells of rows of BBC
logical colours: characters 256 of 8 x 4, sprite frames 119 of 21 x 12, the
status panel 200 of 8 x 4 (5 rows of 40) and the HUD glyphs 13 of 8 x 4. The
panel and the HUD are a character's shape exactly, which is why the sheets and
the packer treat all three the same way.
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


# --- the status panel and the HUD glyphs ---------------------------------
#
# Both are cells of 4 fat pixels by 8 rows - a character's shape - which is
# what src/data/panel.bin and hud.bin hold, sixteen bytes a cell (byte column
# 0's eight scanlines, then byte column 1's). The C64 reading below is
# export_panel.py's, moved here so the seeder and the PNG fallback can call it;
# the decisions it embodies (34, 56) are documented in that file's docstring.

STATUS_CHR = "source_c64/data/status.chr"
PANEL_ROWS, PANEL_COLS = 5, 40
PANEL_CELLS = PANEL_ROWS * PANEL_COLS
PANEL_SHIFT = 1           # columns right, to centre the bar; bank3's HUD_COL_SHIFT

# $d021, $d022, $d023 as rout1 sets them for the panel's raster.
D021, D022, D023 = 0x00, 0x06, 0x01

# C64 colour -> our MODE 2 logical colour. Decision 34.
C64_TO_MODE2 = {
    0x00: 0,        # black
    0x01: 7,        # white
    0x06: 4,        # blue
    0x0b: 4,        # dark grey   -> blue
    0x0d: 2,        # light green -> green
    0x0f: 7,        # light grey  -> white
}

# The characters the HUD writes, in the order the runtime indexes them:
# blank, digits 0-9, then the life marker's two cells.
HUD_CHARS = [0x00] + list(range(0x21, 0x2b)) + [0x8f, 0x90]
HUD_COLOUR = 0x0b         # every cell status_decode writes into carries this
HUD_PAIR_3 = 7            # white body for the glyphs; see export_panel.py


def _byte_list(text, want):
    """The first `want` !byte operands after the start of `text`, in order."""
    import re
    out = []
    for line in text.splitlines():
        line = line.split(';')[0]
        m = re.search(r'!byte\s+(.*)', line)
        if not m:
            continue
        for term in m.group(1).split(','):
            term = term.strip()
            try:
                out.append(int(term[1:], 16) if term.startswith('$') else int(term))
            except ValueError:
                return out
            if len(out) == want:
                return out
    return out


def _block_after(source, marker, count):
    i = source.index(marker)
    got = _byte_list(source[i:], count)
    assert len(got) >= count, '%s: found %d of %d' % (marker, len(got), count)
    return got[:count]


def _c64_cell(chars, code, colour_ram, body=None):
    """One C64 character as 8 rows of 4 BBC logical colours."""
    pair = [C64_TO_MODE2[D021], C64_TO_MODE2[D022], C64_TO_MODE2[D023],
            C64_TO_MODE2[colour_ram & 0x0f] if body is None else body]
    return [[pair[(chars[code * 8 + y] >> (6 - 2 * p)) & 3] for p in range(4)]
            for y in range(8)]


def _status_charset():
    raw = open(STATUS_CHR, 'rb').read()
    assert len(raw) == 2 + 2048, 'status.chr should be a load address and 256 chars'
    return raw[2:]


def panel(cpc=False):
    """The status panel as PANEL_CELLS cells of 8 rows of 4 logical colours,
    row-major over 5 rows of 40."""
    if cpc:
        rows = _cpc().panel()
        out = []
        for row in range(PANEL_ROWS):
            for col in range(PANEL_COLS):
                if row * 8 < len(rows):
                    out.append([r[col * 4:col * 4 + 4]
                                for r in rows[row * 8:row * 8 + 8]])
                else:
                    out.append([[0] * 4 for _ in range(8)])   # the blank fifth row
        return out
    chars = _status_charset()
    src = open(C64_ASM, 'r', encoding='latin-1').read()
    screen = _block_after(src, '; Add in the status bar character data', PANEL_CELLS)
    cols = _block_after(src, '; Status bar colour data', PANEL_CELLS)
    out = []
    for cell in range(PANEL_CELLS):
        row, col = divmod(cell, PANEL_COLS)
        n = row * PANEL_COLS + (col - PANEL_SHIFT) % PANEL_COLS
        out.append(_c64_cell(chars, screen[n], cols[n]))
    return out


def hud(cpc=False):
    """The thirteen HUD glyphs, each 8 rows of 4 logical colours."""
    if cpc:
        return _cpc().hud()
    chars = _status_charset()
    return [_c64_cell(chars, code, HUD_COLOUR, body=HUD_PAIR_3)
            for code in HUD_CHARS]
