"""rip_cpc_sprites.py - Amstrad CPC sprite bank -> a sheet in the C64 sheet's format.

Writes assets/sprite-sheet-cpc.png: 192 x 315, an 8 x 15 grid of 24 x 21 cells,
frames 0-118 in row-major order with cell 119 blank - byte for byte the layout
of assets/sprite-sheet.png, so the two can be flicked between cell for cell.

Source: SPRITES.BIN off Smila's work disc `source_cpc/Work Disks/edge_sprites2.dsk`
(the "normal" sprite bank the CPC pages into &4000 as bank 3). 128 slots of 128
bytes; 126 are used, 6 bytes x 21 lines, and the last nine slots are empty.

The CPC bank is indexed by the SAME frame numbers as the C64 - measured, not
assumed: every one of frames 0-118 matches the C64 sheet's opaque/transparent
mask, 24 of them by 1-5 pixels and the rest exactly. The stragglers are the
CPC's byte-level masking, which cannot make a single pixel transparent.

Byte order is the one `PrintSprites` in source_cpc/Source/EG_Sprites10.asm
consumes: ten line pairs of twelve bytes, each pair reading
(col 0 lower, col 0 upper, col 1 lower, ...) because the CPC writes the lower
line of an address pair first and then clears bit 11 to reach the line above;
then six bytes for line 20 on its own, C64 sprites being an odd 21 lines high.

Palette: `Mode0Pal` in source_cpc/Source/Compiled_Main3.asm - the in-game one,
NOT the .PAL beside the art on the work disc. `SetColours` walks the list from
pen 15 down to pen 0, so the table is stored in reverse. The two agree on pens
0-12 and differ on 13-15, which the art disc predates.

A CPC mode 0 pixel is 2:1 like a C64 multicolour pixel, so each is written to
the sheet twice across. A source byte of zero is what the CPC treats as
transparent (it masks per byte, never per pixel), and becomes the C64 sheet's
grey; every other byte is drawn, pen 0 included, and pen 0 is black.

Run from the project root: python tools/rip_cpc_sprites.py
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "cpc"))
import cpcscr  # noqa: E402
from dsk import Dsk  # noqa: E402

DSK = os.path.join("source_cpc", "Work Disks", "edge_sprites2.dsk")
BANK = "SPRITES.BIN"
OUT = os.path.join("assets", "sprite-sheet-cpc.png")

FRAMES = 119              # frames 0-118; slot 119 is blank in both sheets
COLS, CELL_W, CELL_H = 8, 24, 21
SLOT = 128                # bytes per bank slot; 126 used
WIDE, HIGH = 12, 21       # mode 0 pixels per frame
TRANSPARENT = (96, 96, 96, 255)

def frame_pixels(bank, n):
    """Frame n as 21 rows of 12 pen indices, or None where the byte was zero."""
    f = bank[n * SLOT:n * SLOT + 126]
    rows = [[None] * WIDE for _ in range(HIGH)]

    def put(row, col, byte):
        pens = cpcscr._decode(byte, 0) if byte else (None, None)
        rows[row][col * 2:col * 2 + 2] = pens

    for pair in range(10):
        for col in range(6):
            put(pair * 2 + 1, col, f[pair * 12 + col * 2])      # lower line
            put(pair * 2, col, f[pair * 12 + col * 2 + 1])      # line above
    for col in range(6):
        put(20, col, f[120 + col])
    return rows


def main():
    bank = cpcscr.strip_amsdos(Dsk(DSK).catalogue()[(0, "SPRITES", "BIN")])
    rgb = [c + (255,) for c in cpcscr.mode0_rgb()]

    sheet = Image.new("RGBA", (COLS * CELL_W, ((FRAMES + COLS) // COLS) * CELL_H),
                      TRANSPARENT)
    px = sheet.load()
    for n in range(FRAMES):
        ox, oy = (n % COLS) * CELL_W, (n // COLS) * CELL_H
        for y, row in enumerate(frame_pixels(bank, n)):
            for x, pen in enumerate(row):
                if pen is None:
                    continue
                px[ox + x * 2, oy + y] = px[ox + x * 2 + 1, oy + y] = rgb[pen]
    sheet.save(OUT)
    print(f"{OUT}: {sheet.size[0]}x{sheet.size[1]}, {FRAMES} frames from {BANK}")


if __name__ == "__main__":
    main()
