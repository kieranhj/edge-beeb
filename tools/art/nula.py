"""nula.py - the two VideoNuLA test palettes, and the art at its own colours.

A NuLA build is not the artist's pipeline; it is the ORIGINAL artwork shown at
the palette it was drawn for. So this module deliberately bypasses the PNG
sheets and reads the mechanical conversions in a mode where a colour does not
have to be squeezed into MODE 2's eight:

  GFX_NULA=1              the C64 art at the sixteen Pepto colours
  GFX_NULA=1, GFX_CPC=1   the Amstrad art at its own sixteen mode 0 pens,
                          with the dither of decision 55 GONE - a pen is one
                          colour again, which is the whole point

In both, **logical colour n IS source colour n**. Sixteen logical colours and
sixteen source colours, so the mapping is the identity and nothing has to be
chosen, collapsed or approximated anywhere. That is what makes these two builds
worth having as a reference: whatever they show is what the original showed,
and any difference is ours.

Two constraints survive from the eight-colour build and are checked here:

  * **Logical 0 is the sprite engine's transparency key** (mask_table keys on a
    zero nibble), so no sprite pixel may resolve to 0. The C64 is safe by
    construction - its bit pair 00 IS the transparency and no sprite carries
    colour 0. The CPC is not: it masks per BYTE, so a pen 0 pixel beside a lit
    one is drawn black. Pen 15 is ALSO black in the in-game palette (measured -
    see PEN_ALIASES), so a drawn black becomes logical 15 and looks identical.
  * **Two flash targets, because there are two flash LUTs** (&8200 and &8300 of
    each sprite bank). Measured: sprite_col_dcd's high nibble takes only two
    values that ever differ from the low one, C64 1 and 4. Under GFX_CPC those
    two have no meaning, so they are given the nearest thing the Amstrad's
    palette has.

What a NuLA build does NOT do, and the honest limits, are in
docs/layer-8b-nula.md.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bbc         # noqa: E402
import mechanical  # noqa: E402

ENTRIES = 16

# The C64's sixteen, Pepto, which bbc.py already carries for the reference
# renders. Under NuLA they stop being "for the renders only" and become the
# palette the machine is actually programmed with.
C64_PALETTE = list(bbc.C64_RGB)

# The C64 colours the title font's three inks take. The eight-colour build
# picked blue/cyan/white by eye (export_title.py) and there is no reason to
# choose differently: 6, 14 and 1 are the C64's own blue, light blue and white,
# which is that same shadow -> mid -> highlight ramp in the original's palette.
C64_TITLE_INK = (6, 14, 1)

# The two flash targets, as C64 colours. Measured, not chosen: these are the
# only two values sprite_col_dcd's high nibble ever takes that differ from its
# low nibble (white, and the purple the player's grind flash uses).
C64_FLASH = (1, 4)


def cpc_palette():
    """The sixteen in-game mode 0 pens as RGB. cpcscr.mode0_rgb() is the
    reversed Mode0Pal of decision 41 - the in-game list, not the .PAL beside
    the art on the work disc."""
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "cpc"))
    import cpcscr
    return [tuple(c) for c in cpcscr.mode0_rgb()]


def pen_aliases(pal):
    """pen -> another pen of the same RGB, where one exists. Pens 0 and 15 are
    both black and pens 10 and 12 both cyan in the in-game palette, which is
    what gives a CPC sprite a black it can DRAW: logical 0 is the transparency
    key, so pen 0 inside a sprite becomes its alias."""
    out = {}
    for a in range(ENTRIES):
        for b in range(ENTRIES):
            if a != b and pal[a] == pal[b]:
                out.setdefault(a, b)
    return out


def cpc_title_ink(pal):
    """Three pens for the title font's shadow, mid and highlight. The Amstrad
    shares the C64's title page, so the font is the same and only the colours
    can differ; these are its blue, cyan and white."""
    want = [(0, 0, 255), (0, 255, 255), (255, 255, 255)]
    return tuple(next(n for n, c in enumerate(pal) if c == w) for w in want)


def cpc_flash(pal):
    """The two flash targets in the Amstrad's palette: its white, and the
    nearest thing it has to the purple the C64's grind flash uses."""
    white = next(n for n, c in enumerate(pal) if c == (255, 255, 255))
    violet = next(n for n, c in enumerate(pal) if c == (128, 0, 255))
    return (white, violet)


def palette(cpc=False):
    return cpc_palette() if cpc else list(C64_PALETTE)


def title_ink(cpc=False):
    return cpc_title_ink(cpc_palette()) if cpc else C64_TITLE_INK


def flash(cpc=False):
    return cpc_flash(cpc_palette()) if cpc else C64_FLASH


# --- the art, at source colours ------------------------------------------

def characters(cpc=False):
    """256 characters, each 8 rows of 4 logical colours = source colours."""
    if cpc:
        return _cpc_chars()
    col_decode = bbc.parse_c64_table(mechanical.C64_ASM, "col_decode", 256)
    out = []
    for n, char in enumerate(bbc.load_chars()):
        cd = col_decode[n] & 7
        lut = {0: bbc.C64_BG, 1: bbc.C64_MC1, 2: bbc.C64_MC2, 3: cd}
        out.append([[lut[v] for v in bbc.c64_pixels(row)] for row in char])
    return out


def sprites(cpc=False, count=mechanical.FRAMES):
    """`count` frames of 21 rows of 12 logical colours, 0 transparent."""
    if cpc:
        return _cpc_sprites(count)
    raw = bbc.load_sprites(count=count)
    colour = mechanical.frame_colours(*mechanical.dp_tables())
    out = []
    for f in range(count):
        lut = {0: 0, 1: bbc.C64_SPR_MC1, 3: bbc.C64_SPR_MC2, 2: colour[f]}
        rows = []
        for r in range(mechanical.ROWS):
            row = []
            for b in raw[f][r * 3:r * 3 + 3]:
                row += [lut[v] for v in bbc.c64_pixels(b)]
            rows.append(row)
        assert all(v != 0 or lut[0] == 0 for row in rows for v in row)
        out.append(rows)
    return out


def panel(cpc=False):
    """200 cells of 8 rows of 4 logical colours. The C64's own colour RAM
    values now mean something: $0b dark grey, $0d light green and $0f light
    grey are three of the sixteen rather than three collapsed onto two."""
    if cpc:
        return _cpc_panel()
    chars = mechanical._status_charset()
    src = open(mechanical.C64_ASM, 'r', encoding='latin-1').read()
    screen = mechanical._block_after(
        src, '; Add in the status bar character data', mechanical.PANEL_CELLS)
    cols = mechanical._block_after(
        src, '; Status bar colour data', mechanical.PANEL_CELLS)
    out = []
    for cell in range(mechanical.PANEL_CELLS):
        row, col = divmod(cell, mechanical.PANEL_COLS)
        n = row * mechanical.PANEL_COLS + (col - mechanical.PANEL_SHIFT) % mechanical.PANEL_COLS
        out.append(_c64_cell(chars, screen[n], cols[n] & 0x0f))
    return out


def hud(cpc=False):
    """The thirteen HUD glyphs. No HUD_PAIR_3 brightening: that existed only
    because MODE 2 collapsed the C64's dark grey onto blue and left a digit
    four pixels of near-invisibility. The grey is a real colour here."""
    if cpc:
        return _cpc_hud()
    chars = mechanical._status_charset()
    return [_c64_cell(chars, code, mechanical.HUD_COLOUR)
            for code in mechanical.HUD_CHARS]


def title_font(cpc=False):
    """The 32 title glyphs in the three inks of `title_ink`."""
    ink = title_ink(cpc)
    pair = {0: 0, 1: ink[0], 2: ink[1], 3: ink[2]}
    chars = mechanical._status_charset()
    return [[[pair[(chars[g * 8 + y] >> (6 - 2 * p)) & 3] for p in range(4)]
             for y in range(8)]
            for g in range(mechanical.TITLE_GLYPHS)]


def _c64_cell(chars, code, colour_ram):
    pair = [bbc.C64_BG, 0x06, 0x01, colour_ram]      # $d021, $d022, $d023, RAM
    return [[pair[(chars[code * 8 + y] >> (6 - 2 * p)) & 3] for p in range(4)]
            for y in range(8)]


# --- the Amstrad's, with no dither ---------------------------------------

def _cpc():
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "cpc"))
    import bgdata
    import cpcscr
    import paneldata
    from dsk import Dsk
    return bgdata, cpcscr, paneldata, Dsk


def _cpc_chars():
    bgdata, cpcscr, _, _ = _cpc()
    chars = bgdata.read_defb(bgdata.CHARS)
    return [[list(row) for row in bgdata.character(chars, n, cpcscr._decode)]
            for n in range(256)]


def _cpc_sprites(count):
    bgdata, cpcscr, _, Dsk = _cpc()
    alias = pen_aliases(cpc_palette())
    dsk = os.path.join('source_cpc', 'Work Disks', 'edge_sprites2.dsk')
    bank = cpcscr.strip_amsdos(Dsk(dsk).catalogue()[(0, 'SPRITES', 'BIN')])
    slot, rows_n, wide = 128, 21, 12
    out = []
    for n in range(count):
        f = bank[n * slot:n * slot + 126]
        rows = [[0] * wide for _ in range(rows_n)]

        def put(row, col, byte):
            if byte:            # transparency is per BYTE on the Amstrad
                rows[row][col * 2:col * 2 + 2] = [
                    alias.get(p, p) if p == 0 else p
                    for p in cpcscr._decode(byte, 0)]

        for pair in range(10):
            for col in range(6):
                put(pair * 2 + 1, col, f[pair * 12 + col * 2])
                put(pair * 2, col, f[pair * 12 + col * 2 + 1])
        for col in range(6):
            put(20, col, f[120 + col])
        out.append(rows)
    return out


def _cpc_panel():
    _, cpcscr, paneldata, _ = _cpc()
    rows = [[p for b in row for p in cpcscr._decode(b, 0)]
            for row in paneldata.panel()]
    out = []
    for row in range(mechanical.PANEL_ROWS):
        for col in range(mechanical.PANEL_COLS):
            if row * 8 < len(rows):
                out.append([r[col * 4:col * 4 + 4]
                            for r in rows[row * 8:row * 8 + 8]])
            else:
                out.append([[0] * 4 for _ in range(8)])
    return out


def _cpc_hud():
    _, cpcscr, paneldata, _ = _cpc()

    def cell(block):
        return [[p for b in row for p in cpcscr._decode(b, 0)] for row in block]

    out = [[[0] * 4 for _ in range(8)]]
    for d in paneldata.digits():
        out.append(cell(d))
    marker = cell(paneldata.life())
    out.append([row[0:4] for row in marker])
    out.append([row[4:8] for row in marker])
    return out
