"""Shared helpers for the Edge Grinder exporters: palettes, MODE 2 packing,
C64 data formats. Python 3 + Pillow (render only)."""

import struct

# --- C64 ------------------------------------------------------------------

# Pepto palette, for the reference renders only.
C64_RGB = [
    (0x00, 0x00, 0x00), (0xFF, 0xFF, 0xFF), (0x68, 0x37, 0x2B), (0x70, 0xA4, 0xB2),
    (0x6F, 0x3D, 0x86), (0x58, 0x8D, 0x43), (0x35, 0x28, 0x79), (0xB8, 0xC7, 0x6F),
    (0x6F, 0x4F, 0x25), (0x43, 0x39, 0x00), (0x9A, 0x67, 0x59), (0x44, 0x44, 0x44),
    (0x6C, 0x6C, 0x6C), (0x9A, 0xD2, 0x84), (0x6C, 0x5E, 0xB5), (0x95, 0x95, 0x95),
]

# Playfield register values, edge_grinder.asm rout2 ($d021/$d022/$d023).
C64_BG = 0        # bit pair 00
C64_MC1 = 9       # bit pair 01 - brown
C64_MC2 = 1       # bit pair 10 - white
# bit pair 11 - per-character colour, col_decode low 3 bits

# Sprite shared colours, rout1 ($d025/$d026).
C64_SPR_MC1 = 6   # bit pair 01 - blue
C64_SPR_MC2 = 1   # bit pair 11 - white
# bit pair 10 - per-sprite colour, sprite_col_dcd low nibble (high nibble = hit flash)

# --- BBC ------------------------------------------------------------------

BBC_RGB = [
    (0, 0, 0), (255, 0, 0), (0, 255, 0), (255, 255, 0),
    (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
]
BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE = range(8)

# C64 colour index -> BBC physical colour for the mechanical conversion.
# Decision 11 in docs/decisions.md. Brown (the playfield's shared dark colour)
# goes to blue, which is what the 2019 port chose and KC liked; the two greys
# and light blue have no BBC equivalent and are pushed to the nearest hue.
C64_TO_BBC = {
    0: BLACK, 1: WHITE, 2: RED, 3: CYAN, 4: MAGENTA, 5: GREEN, 6: BLUE, 7: YELLOW,
    8: RED,           # orange
    9: BLUE,          # brown - the playfield's $d022 (see above)
    10: MAGENTA,      # light red / pink
    11: BLUE,         # dark grey
    12: WHITE,        # mid grey
    13: GREEN,        # light green
    14: CYAN,         # light blue
    15: WHITE,        # light grey
}

# --- CPC ------------------------------------------------------------------

# Mode 0 gives Smila 27 possible colours against MODE 2's eight, so a CPC
# colour becomes a PAIR of BBC colours checkerboarded together (decision 55).
# The rule is Rich Talbot-Watkins's, and reference/cpc-palette-map-to-bbc-mode2.png
# is his chart of all 27; `dither_pair` reproduces every cell of it exactly:
#
#   of the 36 unordered pairs of the eight MODE 2 colours, take those whose
#   per-channel average is nearest the target, and among those choose the two
#   closest in brightness; then order the pair darkest first.
#
# The two tie-breaks are what stop the flat mapping's damage. Nearest-average
# alone leaves ties everywhere on the middle levels - mid grey is red+cyan as
# readily as magenta+green - and the closest-in-brightness pair is the one that
# reads as a colour rather than as two colours. Brightness is Rec.601 luma.

BBC_LUMA = [0.299 * r + 0.587 * g + 0.114 * b for r, g, b in BBC_RGB]


def dither_pair(rgb):
    """One RGB triple as (dark, light), two BBC physical colours to checkerboard.
    A colour MODE 2 has exactly returns that colour twice."""
    best = None
    for a in range(8):
        for b in range(a, 8):
            err = sum(((BBC_RGB[a][k] + BBC_RGB[b][k]) / 2 - rgb[k]) ** 2
                      for k in range(3))
            key = (err, abs(BBC_LUMA[a] - BBC_LUMA[b]))
            if best is None or key < best[0]:
                best = (key, (a, b))
    a, b = best[1]
    return (a, b) if BBC_LUMA[a] <= BBC_LUMA[b] else (b, a)


# Sprites cannot use logical 0 (it is the transparency key for the mask
# table), so black inside a sprite is written as logical 8, which the
# palette maps back to physical black. Layer 3 sets that palette entry.
SPRITE_BLACK = 8


def mode2_byte(left, right):
    """Pack two 4-bit logical colours into one MODE 2 byte.
    Left pixel takes bits 7,5,3,1; right pixel bits 6,4,2,0."""
    b = 0
    for i in range(4):
        b |= ((left >> i) & 1) << (2 * i + 1)
        b |= ((right >> i) & 1) << (2 * i)
    return b


def mode2_unpack(b):
    left = right = 0
    for i in range(4):
        left |= ((b >> (2 * i + 1)) & 1) << i
        right |= ((b >> (2 * i)) & 1) << i
    return left, right


def c64_pixels(byte):
    """Four multicolour pixel values (0-3) from one C64 bitmap byte, left to right."""
    return [(byte >> (6 - 2 * i)) & 3 for i in range(4)]


# --- C64 data files (data/*.bin, load headers already stripped) -----------

CHAR_COUNT = 256
TILE_COUNT = 211
MAP_ROWS = 5


def load_chars(path="data/tiles.chr.bin"):
    d = open(path, "rb").read()
    assert len(d) == CHAR_COUNT * 8, len(d)
    return [d[i * 8:(i + 1) * 8] for i in range(CHAR_COUNT)]


def load_tiles(path="data/tiles.til.bin"):
    d = open(path, "rb").read()
    assert len(d) == TILE_COUNT * 16, len(d)
    return [list(d[i * 16:(i + 1) * 16]) for i in range(TILE_COUNT)]  # row-major 4x4


def load_map(paths=("data/tiles.map.bin", "data/tiles2.map.bin")):
    d = b"".join(open(p, "rb").read() for p in paths)
    assert len(d) % MAP_ROWS == 0, len(d)
    cols = len(d) // MAP_ROWS
    return [list(d[c * MAP_ROWS:(c + 1) * MAP_ROWS]) for c in range(cols)]  # column-major


def load_sprites(path="data/sprites.spr.bin", count=119):
    d = open(path, "rb").read()
    assert len(d) == count * 64, len(d)
    return [d[i * 64:i * 64 + 63] for i in range(count)]


def parse_c64_table(asm_path, label, count):
    """Pull a `!byte` table out of edge_grinder.asm by its label."""
    out = []
    grab = False
    for line in open(asm_path, encoding="latin-1"):
        s = line.strip()
        if s.startswith(label):
            grab = True
            s = s[len(label):].strip()
        if not grab:
            continue
        if not s.startswith("!byte"):
            if s == "" or s.startswith(";"):
                continue
            break
        body = s[5:].split(";")[0]
        out += [int(v.strip()[1:], 16) for v in body.split(",") if v.strip()]
        if len(out) >= count:
            break
    assert len(out) >= count, (label, len(out))
    return out[:count]
