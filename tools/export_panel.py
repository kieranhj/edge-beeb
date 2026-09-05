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

The panel and the HUD come from assets/art/panel.png and hud.png (Layer 8,
decision 61): the artist paints the status bar as a picture at the size it
appears on screen, and the exporter cuts it into the 200 cells the runtime
copies. A cell he has not drawn yet falls back to the mechanical conversion.
--c64 bypasses the PNGs and takes that conversion outright, which is what the
sheets were seeded from and therefore produces the same bytes.

The C64 reading below moved to tools/art/mechanical.py, so the seeder and the
fallback path can call it too; everything it embodies - decision 34's colour
mapping, PANEL_SHIFT, HUD_PAIR_3 - is unchanged and still documented here.

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
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'art'))
import mechanical  # noqa: E402
import nula        # noqa: E402
import pngart      # noqa: E402
import sheets      # noqa: E402

OUT = os.path.join(ROOT, 'src', 'data', 'panel.bin')
OUT_HUD = os.path.join(ROOT, 'src', 'data', 'hud.bin')
OUT_CPC = os.path.join(ROOT, 'src', 'data', 'panel-cpc.bin')
OUT_HUD_CPC = os.path.join(ROOT, 'src', 'data', 'hud-cpc.bin')

PANEL_ROWS = mechanical.PANEL_ROWS
PANEL_COLS = mechanical.PANEL_COLS
PANEL_CELLS = mechanical.PANEL_CELLS
PANEL_SHIFT = mechanical.PANEL_SHIFT     # columns right, to centre the bar

# The colour and glyph decisions above are mechanical.py's now: C64_TO_MODE2
# (decision 34), HUD_CHARS, HUD_COLOUR and HUD_PAIR_3, the white body that
# makes a four-pixel digit legible where the ornament's dark grey would not be.


def pack(cells):
    """Cells of logical colour as the bytes the runtime copies: sixteen a cell,
    byte column 0's eight scanlines then byte column 1's."""
    return b''.join(sheets.pack_cell(c) for c in cells)


# The eighteen panel cells the runtime writes over: the score at row 1 columns
# 7-12, the high score at row 1 columns 27-32 and the lives at row 2 columns
# 17-22, all inclusive of PANEL_SHIFT. The same cells src/bank3.asm's
# hud_cell_lo/hi name, and the reason that table needs no change under GFX_CPC:
# the Amstrad port copied the C64's layout to the column (decision 56).
HUD_CELLS = ([1 * PANEL_COLS + c for c in range(6 + PANEL_SHIFT, 12 + PANEL_SHIFT)]
             + [1 * PANEL_COLS + c for c in range(26 + PANEL_SHIFT, 32 + PANEL_SHIFT)]
             + [2 * PANEL_COLS + c for c in range(16 + PANEL_SHIFT, 22 + PANEL_SHIFT)])
LIVES_CELLS = HUD_CELLS[12:]


def check_hud_cells(panel_cells):
    """Warn about ink painted where the HUD will land.

    Those eighteen cells are overwritten the first time the score, the high
    score or the lives are drawn, so anything painted there is seen at boot and
    never again. The C64's own panel leaves all eighteen blank - measured, not
    assumed - and an artist repainting the bar has no way of knowing which cells
    those are from looking at it.

    A warning, not an error: the Amstrad's panel draws its digits and markers
    into the image deliberately (decision 56), so this is a defensible thing to
    do and the game is fine either way.
    """
    ink = [n for n in HUD_CELLS
           if panel_cells[n] is not None
           and any(v for row in panel_cells[n] for v in row)]
    if not ink:
        return None
    return ('%d of the 18 cells the HUD writes into carry ink in panel.png '
            '(cells %s); they are overwritten the first time the score or the '
            'lives are drawn' % (len(ink), ', '.join(str(n) for n in ink[:6])
                                 + (', ...' if len(ink) > 6 else '')))


def check_hud_phase(panel_cells, hud_cells):
    """Under GFX_CPC the life markers ARE drawn into the panel art, and must
    match the two HUD glyphs that replace them EXACTLY, colours included - which
    is what proves the dither phase: every HUD cell starts on an even pixel
    column and an even row, so a glyph's own (x + y) parity is the panel's
    (decision 56). Hard, because nothing else catches a phase error and it is
    not a matter of taste."""
    marker = pack(hud_cells[11:13])
    for i in range(3):
        at = LIVES_CELLS[i * 2]
        assert pack(panel_cells[at:at + 2]) == marker, \
            'lives glyph phase, marker %d' % i


def main(cpc=False, c64=False, use_nula=False):
    if use_nula:
        # No dither to prove the phase of, and the CPC's panel carries its own
        # colours, so neither the paneldata verify nor check_hud_phase applies.
        panel, hud = nula.panel(cpc=cpc), nula.hud(cpc=cpc)
    elif cpc:
        sys.path.insert(0, os.path.join(HERE, 'cpc'))
        import paneldata
        print('paneldata: verified against the panel image -', paneldata.verify())
        panel = mechanical.panel(cpc=True)
        hud = mechanical.hud(cpc=True)
        check_hud_phase(panel, hud)
    elif c64:
        panel, hud = mechanical.panel(), mechanical.hud()
    else:
        panel = pngart.panel(fallback=mechanical.panel())
        hud = pngart.hud(fallback=mechanical.hud())

    if not cpc:
        warn = check_hud_cells(panel)
        if warn:
            print('  warning: ' + warn)

    out, glyphs = pack(panel), pack(hud)
    assert len(out) == PANEL_ROWS * 640
    suffix = ('-nula' if use_nula else '') + ('-cpc' if cpc else '')
    for path, data, what in (
            (os.path.join(ROOT, 'src', 'data', 'panel%s.bin' % suffix), out,
             '%d cells%s' % (PANEL_CELLS, ', CPC art, row 4 blank' if cpc else '')),
            (os.path.join(ROOT, 'src', 'data', 'hud%s.bin' % suffix), glyphs,
             '%d glyphs' % (len(glyphs) // 16))):
        with open(path, 'wb') as f:
            f.write(data)
        print('%s: %d bytes (%s)' % (path, len(data), what))


if __name__ == '__main__':
    main(cpc='--cpc' in sys.argv[1:], c64='--c64' in sys.argv[1:],
         use_nula='--nula' in sys.argv[1:])
