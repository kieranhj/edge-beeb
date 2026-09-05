#!/usr/bin/env python3
"""Export the C64 status bar to a ready-to-copy MODE 2 panel image.

The C64's status bar is five rows of 40 characters at the top of the screen,
drawn once and never redrawn: the character codes are assembled straight into
the screen buffer (`* = buffer_1` at the end of edge_grinder.asm) and the
colour RAM is filled from `status_cols` by `status_init`. Only three fields
move afterwards - the score, the high score and the lives bars - and
`status_decode` pokes those characters back into the same buffer.

The charset is `source_c64/data/status.chr` read as MULTICOLOUR, which is what
it is: four double-width pixels a character. That is one of our 4-fat-pixel
cells exactly, so 40 characters is 160 pixels and the original's layout
transcribes at 1:1 - the same 1:1 that `export_title.py` found for the credits,
which use the same charset.

Colour (decision 34). The C64 multicolour bit pairs take:
    00  $d021 = 0  black
    01  $d022 = 6  blue
    10  $d023 = 1  white
    11  colour RAM, from status_cols: $0b dark grey, $0d light green,
        $0f light grey, $00 black
MODE 2 has no greys, so the mapping is faithful-as-possible: the two greys go
to the colours they are standing in for in a 16-colour picture - dark grey to
blue and light grey to white, which is what the surrounding pairs already use -
and light green keeps its hue. The distinction between dark grey and blue is
the one thing that is lost.

The bar is CENTRED here, which on the C64 the border did for it. rout1 sets
$d016 = $17 for the panel raster: 38-column mode, x-scroll 7. The map is 40
columns wide but columns 38 and 39 are blank, and the art is exactly mirror-
symmetric about columns 0..37 - the pair the side borders eat. On our 40-column
MODE 2 row nothing is eaten, so the art landed four pixels left of centre.
Rotating every row right by one column fixes it: columns 38, 39 blank become
columns 39, 0, and the art sits at 1..38, centred. Row 4 is $ff in all forty
columns, so the rotation leaves the bar under the panel edge to edge.
PANEL_SHIFT is that rotation, and `hud_cell_lo/hi` in src/bank3.asm carries the
same +1 on the score, high-score and lives columns.

Output, both into sideways bank 3:

src/data/panel.bin, 3200 bytes
    The panel image: 5 rows x 640 bytes, a straight copy to &3000. A cell is
    16 contiguous bytes (byte column 0's eight scanlines then byte column 1's)
    because our byte columns are eight bytes apart and consecutive.

src/data/hud.bin, 208 bytes
    Thirteen glyphs, 16 bytes each, all at colour RAM $0b - which is what
    every cell status_decode writes into carries:
        0       blank
        1-10    digits '0' to '9'   (C64 characters $21-$2a)
        11, 12  the lives bar pair  (C64 characters $8f, $90)

With --cpc (decision 56) the panel and the HUD come from the Amstrad port's own
art instead - `PanelBlock0-7` in EG_Panel.asm and `gamefont0-9` / `playerlife`
in EG_GameFont.ASM, read through tools/cpc/paneldata.py - and are written to
panel-cpc.bin and hud-cpc.bin. Colour goes through the dither pairs of decision
55 like the rest of the CPC art, so nothing here consults C64_TO_MODE2 or the
HUD_PAIR_3 brightening: the CPC draws its digits bright cyan on blue, which
needs no help.

The CPC's panel is FOUR character rows to the C64's five, so it lands in rows
0-3 and row 4 is left black. Its HUD is in the same cells as ours to the
column: the score at row 1 column 7, the high score at row 1 column 27 and the
three life markers at row 2 columns 17-22, which is exactly what
export_panel.py's PANEL_SHIFT of 1 puts the C64's at. The CPC port copied the
C64's layout including the two blank columns the 38-column border ate, so
src/bank3.asm's hud_cell tables need no change at all.
"""

import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHARSET = os.path.join(ROOT, 'source_c64', 'data', 'status.chr')
SOURCE = os.path.join(ROOT, 'source_c64', 'edge_grinder.asm')
OUT = os.path.join(ROOT, 'src', 'data', 'panel.bin')
OUT_HUD = os.path.join(ROOT, 'src', 'data', 'hud.bin')
OUT_CPC = os.path.join(ROOT, 'src', 'data', 'panel-cpc.bin')
OUT_HUD_CPC = os.path.join(ROOT, 'src', 'data', 'hud-cpc.bin')

PANEL_ROWS = 5
PANEL_COLS = 40
PANEL_CELLS = PANEL_ROWS * PANEL_COLS
PANEL_SHIFT = 1         # columns right, to centre the bar - see above

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

# The characters the HUD writes, in the order the runtime indexes them.
HUD_CHARS = [0x00] + list(range(0x21, 0x2b)) + [0x8f, 0x90]
HUD_COLOUR = 0x0b       # every cell status_decode writes into carries this

# ...but the HUD's glyphs get a brighter body than the ornament does (KC:
# "a bit dark and hard to read"). A digit is bit pair 3 for the body, with one
# pair-2 highlight pixel and one pair-1 shadow pixel, so on the C64 it is dark
# grey lit by white and shaded by blue. Our mapping collapses dark grey AND
# blue to the same blue, which leaves a four-pixel-wide digit almost entirely
# blue on black - legible on a 16-colour screen, not on this one. So for these
# thirteen glyphs only, the colour-RAM body is white: the shadow pixel stays
# blue, so the shape the artist drew survives, and the digit reads at a glance.
# The panel's own artwork is untouched.
HUD_PAIR_3 = 7          # white, where the ornament's $0b would give blue


def mode2_pixel(colour, left):
    """MODE 2 encodes a pixel's four bits at 7,5,3,1 (left) or 6,4,2,0 (right)."""
    b = ((colour & 1) << 0) | ((colour & 2) << 1) | ((colour & 4) << 2) | ((colour & 8) << 3)
    return b << 1 if left else b


def byte_list(text, want):
    """The first `want` !byte operands after the start of `text`, in order.
    Stops at the first operand that is not a literal, which is where the
    tables we read run out and the original's symbolic wave data begins."""
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


def block_after(source, marker, count):
    """The first `count` !byte values following `marker`."""
    i = source.index(marker)
    got = byte_list(source[i:], count)
    assert len(got) >= count, '%s: found %d of %d' % (marker, len(got), count)
    return got[:count]


def render(chars, code, colour_ram, body=None):
    """One character as 16 MODE 2 bytes: column 0's scanlines then column 1's.
    `body` overrides the colour bit pair 3 takes, for the HUD glyphs."""
    pair_colour = [
        C64_TO_MODE2[D021],
        C64_TO_MODE2[D022],
        C64_TO_MODE2[D023],
        C64_TO_MODE2[colour_ram & 0x0f] if body is None else body,
    ]
    cols = [bytearray(8), bytearray(8)]
    for y in range(8):
        b = chars[code * 8 + y]
        for p in range(4):
            colour = pair_colour[(b >> (6 - 2 * p)) & 3]
            if colour == 0:
                continue
            cols[p // 2][y] |= mode2_pixel(colour, left=(p % 2 == 0))
    return bytes(cols[0] + cols[1])


def cpc_cell(rows, x0, y0):
    """One 4-pixel-by-8-row cell of BBC logical colour as our 16 panel bytes:
    byte column 0's eight scanlines, then byte column 1's."""
    out = bytearray()
    for bc in range(2):
        for y in range(8):
            b = 0
            for i in range(2):
                colour = rows[y0 + y][x0 + bc * 2 + i]
                if colour:
                    b |= mode2_pixel(colour, left=(i == 0))
            out.append(b)
    return out


def main_cpc():
    sys.path.insert(0, os.path.join(HERE, 'cpc'))
    import bbcart
    import paneldata

    print('paneldata: verified against the panel image -', paneldata.verify())
    rows = bbcart.panel()
    assert len(rows) == paneldata.HIGH and len(rows[0]) == PANEL_COLS * 4

    # The CPC's four character rows, then a blank fifth: our rupture is five
    # rows and the CPC's panel is four (paneldata.py). Top-aligned, so the
    # score and lives keep the rows src/bank3.asm's hud_cell tables name.
    out = bytearray()
    for row in range(PANEL_ROWS):
        for col in range(PANEL_COLS):
            if row * 8 < paneldata.HIGH:
                out += cpc_cell(rows, col * 4, row * 8)
            else:
                out += bytes(16)
    assert len(out) == PANEL_ROWS * 640

    hud = bytearray()
    for glyph in bbcart.hud():
        hud += cpc_cell(glyph, 0, 0)

    # The glyphs are poked into the panel, so they must land on its dither
    # phase: every cell they go into starts on an even pixel column and an
    # even row, so glyph-local (x + y) parity is the panel's. Prove it by
    # rebuilding the panel's own life markers out of glyphs 11 and 12.
    marker = bytes(hud[11 * 16:13 * 16])
    for i in range(3):
        col = paneldata.LIVES_AT[1] // 2 + i * 2
        at = (paneldata.LIVES_AT[0] * PANEL_COLS + col) * 16
        assert out[at:at + 32] == marker, ('lives glyph phase', i)

    with open(OUT_CPC, 'wb') as f:
        f.write(out)
    with open(OUT_HUD_CPC, 'wb') as f:
        f.write(hud)
    print('%s: %d bytes (%d cells, CPC art, row 4 blank)'
          % (OUT_CPC, len(out), PANEL_CELLS))
    print('%s: %d bytes (%d glyphs)' % (OUT_HUD_CPC, len(hud), len(hud) // 16))


def main():
    raw = open(CHARSET, 'rb').read()
    assert len(raw) == 2 + 2048, 'status.chr should be a load address and 256 chars'
    chars = raw[2:]

    source = open(SOURCE, 'r', encoding='latin-1').read()
    screen = block_after(source, '; Add in the status bar character data', PANEL_CELLS)
    cols = block_after(source, '; Status bar colour data', PANEL_CELLS)

    out = bytearray()
    for cell in range(PANEL_CELLS):
        row, col = divmod(cell, PANEL_COLS)
        src = row * PANEL_COLS + (col - PANEL_SHIFT) % PANEL_COLS
        out += render(chars, screen[src], cols[src])
    assert len(out) == PANEL_ROWS * 640

    hud = bytearray()
    for code in HUD_CHARS:
        hud += render(chars, code, HUD_COLOUR, body=HUD_PAIR_3)

    with open(OUT, 'wb') as f:
        f.write(out)
    with open(OUT_HUD, 'wb') as f:
        f.write(hud)
    print('%s: %d bytes (%d cells)' % (OUT, len(out), PANEL_CELLS))
    print('%s: %d bytes (%d glyphs)' % (OUT_HUD, len(hud), len(HUD_CHARS)))


if __name__ == '__main__':
    if '--cpc' in sys.argv[1:]:
        main_cpc()
    else:
        main()
