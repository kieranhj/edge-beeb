"""render_bbc.py - render the converted BBC data back to PNG at 2:1 pixel
aspect, so what the machine will show can be checked on the desktop and
diffed against an emulator screenshot.

  python tools/render_bbc.py chars      -> tools/output/chars.png    (16 x 16 characters)
  python tools/render_bbc.py tiles      -> tools/output/tiles.png    (16 per row)
  python tools/render_bbc.py map [a b]  -> tools/output/map.png      (tile columns a..b, default all)
  python tools/render_bbc.py sprites    -> tools/output/sprites.png  (8 per row, shift 0)

Reads src/data/*.bin, so run the exporters first. Run from the project root.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import bbc  # noqa: E402

DATA = "src/data"
OUT = "tools/output"
SCALE_X, SCALE_Y = 4, 2   # a fat pixel is 2 hires pixels wide; draw at 2x


def palette_rgb(logical):
    return bbc.BBC_RGB[logical & 7]


def char_image_rows():
    """256 characters as 8 rows x 4 columns of logical colour, from the planes."""
    planes = open(f"{DATA}/chars.bin", "rb").read()
    chars = []
    for c in range(256):
        rows = []
        for r in range(8):
            rows.append([bbc.mode2_unpack(planes[p * 2048 + c * 8 + r])[1] for p in range(4)])
        chars.append(rows)
    return chars


def blit(img, x0, y0, rows):
    px = img.load()
    for y, row in enumerate(rows):
        for x, v in enumerate(row):
            rgb = palette_rgb(v)
            for dy in range(SCALE_Y):
                for dx in range(SCALE_X):
                    px[(x0 + x) * SCALE_X + dx, (y0 + y) * SCALE_Y + dy] = rgb


def new_image(w_px, h_px):
    return Image.new("RGB", (w_px * SCALE_X, h_px * SCALE_Y), (0, 0, 0))


def render_chars():
    chars = char_image_rows()
    img = new_image(16 * 4, 16 * 8)
    for c, rows in enumerate(chars):
        blit(img, (c % 16) * 4, (c // 16) * 8, rows)
    return img


def tile_rows(tile, chars):
    rows = [[] for _ in range(32)]
    for ty in range(4):
        for tx in range(4):
            ch = chars[tile[ty * 4 + tx]]
            for r in range(8):
                rows[ty * 8 + r] += ch[r]
    return rows


def render_tiles():
    chars = char_image_rows()
    tiles = bbc.load_tiles()
    per_row = 16
    n_rows = (len(tiles) + per_row - 1) // per_row
    img = new_image(per_row * 16, n_rows * 32)
    for i, t in enumerate(tiles):
        blit(img, (i % per_row) * 16, (i // per_row) * 32, tile_rows(t, chars))
    return img


def render_map(a=0, b=None):
    chars = char_image_rows()
    tiles = bbc.load_tiles()
    m = bbc.load_map()
    b = len(m) if b is None else min(b, len(m))
    img = new_image((b - a) * 16, 5 * 32)
    for col in range(a, b):
        for row in range(5):
            blit(img, (col - a) * 16, row * 32, tile_rows(tiles[m[col][row]], chars))
    return img


def render_sprites():
    d = open(f"{DATA}/sprites.bin", "rb").read()
    frames = 119
    per_row = 8
    n_rows = (frames + per_row - 1) // per_row
    img = new_image(per_row * 14, n_rows * 21)
    for f in range(frames):
        base = f * 2 * 7 * 21
        rows = []
        for r in range(21):
            row = []
            for x in range(7):
                row += bbc.mode2_unpack(d[base + r * 7 + x])
            rows.append(row)
        blit(img, (f % per_row) * 14, (f // per_row) * 21, rows)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    what = sys.argv[1] if len(sys.argv) > 1 else "map"
    if what == "chars":
        img = render_chars()
    elif what == "tiles":
        img = render_tiles()
    elif what == "sprites":
        img = render_sprites()
    else:
        args = [int(v) for v in sys.argv[2:4]]
        img = render_map(*args)
    path = f"{OUT}/{what}.png"
    img.save(path)
    print(path, img.size)


if __name__ == "__main__":
    main()
