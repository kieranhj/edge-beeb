"""export_sprites.py - C64 multicolour sprites -> MODE 2, pre-shifted, with
bounding boxes.

Writes src/data/sprites.bin. Nothing consumes it until Layer 3 replaces the
plotter; until then the game still reads the raw C64 bytes. The layout here
is the Layer 3 proposal and may change when that layer is measured.

Per frame, in order:
  7 x 21 bytes   shift 0: the 24-px sprite in bytes 0-5 (12 fat pixels), byte 6 clear
  7 x 21 bytes   shift 1: the same moved right one MODE 2 pixel (spills into byte 6)
Then a table of 119 x 4 bytes: first row, row count, first column, column count of
the opaque area at shift 0 (rows and columns of the 7-byte-wide cell).

Colours: bit pair 01 -> blue ($d025), 11 -> white ($d026), 10 -> the frame's
colour from sprite_col_dcd (low nibble) through C64_TO_BBC; 00 -> logical 0
(transparent). Black never occurs inside these sprites; if hand-drawn art
introduces it, it is written as logical 8 (bbc.SPRITE_BLACK).

Run from the project root: python tools/export_sprites.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bbc  # noqa: E402

OUT = "src/data"
C64_ASM = "source_c64/edge_grinder.asm"
FRAMES = 119
CELL_W = 7   # bytes: 6 for the sprite + 1 spill for shift 1
ROWS = 21


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


def pack_rows(rows, shift):
    out = bytearray()
    for row in rows:
        px = [0] * shift + row + [0] * (CELL_W * 2 - len(row) - shift)
        for x in range(0, CELL_W * 2, 2):
            out.append(bbc.mode2_byte(px[x], px[x + 1]))
    return out


def bbox(rows):
    ys = [y for y, row in enumerate(rows) if any(row)]
    xs = [x for row in rows for x, v in enumerate(row) if v]
    if not ys:
        return (0, 0, 0, 0)
    return (ys[0], ys[-1] - ys[0] + 1, xs[0] // 2, (max(xs) // 2) - (xs[0] // 2) + 1)


def main():
    os.makedirs(OUT, exist_ok=True)
    sprites = bbc.load_sprites(count=FRAMES)
    col_dcd = bbc.parse_c64_table(C64_ASM, "sprite_col_dcd", FRAMES)

    data = bytearray()
    boxes = bytearray()
    opaque = 0
    for i, raw in enumerate(sprites):
        rows = frame_pixels(raw, col_dcd[i] & 15)
        data += pack_rows(rows, 0)
        data += pack_rows(rows, 1)
        r0, rn, c0, cn = bbox(rows)
        boxes += bytes((r0, rn, c0, cn))
        opaque += rn * cn
    open(f"{OUT}/sprites.bin", "wb").write(data + boxes)
    full = FRAMES * CELL_W * ROWS
    print(f"sprites.bin {len(data) + len(boxes)} B: {FRAMES} frames x 2 shifts x {CELL_W * ROWS} B "
          f"+ {len(boxes)} B boxes; boxed area {opaque} of {full} bytes per shift "
          f"({100 * opaque // full}%)")


if __name__ == "__main__":
    main()
