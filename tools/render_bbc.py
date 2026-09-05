"""render_bbc.py - render the converted BBC data back to PNG at 2:1 pixel
aspect, so what the machine will show can be checked on the desktop and
diffed against an emulator screenshot.

  python tools/render_bbc.py chars      -> tools/output/chars.png    (16 x 16 characters)
  python tools/render_bbc.py tiles      -> tools/output/tiles.png    (16 per row)
  python tools/render_bbc.py map [a b]  -> tools/output/map.png      (tile columns a..b, default all)
  python tools/render_bbc.py sprites [s] -> tools/output/sprites.png  (8 per row, shift s)
  python tools/render_bbc.py panel      -> tools/output/panel.png    (the status bar as shown)
  python tools/render_bbc.py hud        -> tools/output/hud.png      (the 13 poked glyphs)
  python tools/render_bbc.py title      -> tools/output/title.png    (the 32 credit glyphs)

Add --cpc to read the GFX_CPC build's data instead (src/data/*-cpc.bin) and
write to tools/output/*-cpc.png. tiles and map have no CPC copies of their own
- they are the same numbers either way - so those read the CPC charset through
the shared tile and map tables.

Reads src/data/*.bin, so run the exporters first. Run from the project root.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import bbc  # noqa: E402

DATA = "src/data"
OUT = "tools/output"
SUFFIX = ""               # "-cpc" under --cpc; set by main()
SCALE_X, SCALE_Y = 4, 2   # a fat pixel is 2 hires pixels wide; draw at 2x


# The palette is a file now (Layer 8), so the render shows the colours the
# machine will actually show rather than assuming logical = physical & 7. That
# assumption is exactly what a NULA build breaks: sixteen free 12-bit entries,
# no aliasing, and logical 8-15 stop being second copies of 0-7.
try:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
    import palette as art_palette
    PALETTE = art_palette.load()
except Exception:
    PALETTE = [bbc.BBC_RGB[n & 7] for n in range(16)]


def palette_rgb(logical):
    return PALETTE[logical & 15]


def char_image_rows():
    """256 characters as 8 rows x 4 columns of logical colour, from the planes."""
    planes = open(f"{DATA}/chars{SUFFIX}.bin", "rb").read()
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


def render_sprites(shift=0):
    """Unpack a sprite bank back into a sheet, boxes and all, so what the
    engine will actually read can be looked at. The layout is the one
    export_sprites.py writes and src/sprite.asm reads."""
    d = open(f"{DATA}/sprites{shift}{SUFFIX}.bin", "rb").read()
    frames, per_row, cell_w, cell_h = 119, 8, 7, 21
    tab = {n: 0x400 + k * 0x80 for k, n in enumerate(
        ("lo", "hi", "r0", "rn", "c0", "cn"))}
    img = new_image(per_row * cell_w * 2, ((frames + per_row - 1) // per_row) * cell_h)
    for f in range(frames):
        addr = (d[tab["lo"] + f] | (d[tab["hi"] + f] << 8)) - 0x8000
        r0, rn, c0, cn = (d[tab[k] + f] for k in ("r0", "rn", "c0", "cn"))
        rows = [[0] * (cell_w * 2) for _ in range(cell_h)]
        for r in range(rn):
            for c in range(cn):
                left, right = bbc.mode2_unpack(d[addr + r * cn + c])
                rows[r0 + r][(c0 + c) * 2] = left
                rows[r0 + r][(c0 + c) * 2 + 1] = right
        blit(img, (f % per_row) * cell_w * 2, (f // per_row) * cell_h, rows)
    return img


def render_cells(name, count, per_row, wide, high):
    """panel.bin and hud.bin are cells of 4 fat pixels by 8 rows, sixteen bytes
    each - byte column 0's eight scanlines then column 1's - so one reader does
    both. The panel comes back as the picture the machine shows."""
    d = open(f"{DATA}/{name}{SUFFIX}.bin", "rb").read()
    img = new_image(per_row * wide, ((count + per_row - 1) // per_row) * high)
    for n in range(count):
        cell = d[n * 16:n * 16 + 16]
        rows = [[0] * wide for _ in range(high)]
        for bc in range(2):
            for y in range(8):
                left, right = bbc.mode2_unpack(cell[bc * 8 + y])
                rows[y][bc * 2] = left
                rows[y][bc * 2 + 1] = right
        blit(img, (n % per_row) * wide, (n // per_row) * high, rows)
    return img


def main():
    global SUFFIX
    os.makedirs(OUT, exist_ok=True)
    argv = [a for a in sys.argv[1:] if a != "--cpc"]
    if len(argv) != len(sys.argv) - 1:
        SUFFIX = "-cpc"
    what = argv[0] if argv else "map"
    if what == "chars":
        img = render_chars()
    elif what == "tiles":
        img = render_tiles()
    elif what == "panel":
        img = render_cells("panel", 200, 40, 4, 8)
    elif what == "hud":
        img = render_cells("hud", 13, 13, 4, 8)
    elif what == "title":
        img = render_cells("title", 32, 16, 4, 8)
    elif what == "sprites":
        img = render_sprites(int(argv[1]) if len(argv) > 1 else 0)
    else:
        args = [int(v) for v in argv[1:3]]
        img = render_map(*args)
    path = f"{OUT}/{what}{SUFFIX}.png"
    img.save(path)
    print(path, img.size)


if __name__ == "__main__":
    main()
