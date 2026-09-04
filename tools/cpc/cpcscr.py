"""CPC screen (.SCR) + OCP Art Studio (.PAL) -> PIL image."""
from PIL import Image

# Gate Array hardware colour (&40-&5F) -> RGB. The 27 CPC colours; each
# component is 0, 128 or 255.
_L = (0, 128, 255)
FIRMWARE_RGB = [
    (0,0,0),(0,0,128),(0,0,255),(128,0,0),(128,0,128),(128,0,255),(255,0,0),
    (255,0,128),(255,0,255),(0,128,0),(0,128,128),(0,128,255),(128,128,0),
    (128,128,128),(128,128,255),(255,128,0),(255,128,128),(255,128,255),
    (0,255,0),(0,255,128),(0,255,255),(128,255,0),(128,255,128),(128,255,255),
    (255,255,0),(255,255,128),(255,255,255),
]
# Gate Array value -> firmware colour index (the standard hardware table).
GA_TO_FW = [
    13,13,19,25,1,7,10,16,7,25,24,26,6,8,15,17,
    1,19,18,20,0,2,9,11,2,20,21,23,3,5,12,14,
]

def ga_rgb(v):
    return FIRMWARE_RGB[GA_TO_FW[v & 0x1f]]

def strip_amsdos(d):
    if len(d) > 128 and sum(d[:67]) == d[67] | (d[68] << 8):
        return d[128:]
    return d

def read_pal(path):
    b = strip_amsdos(open(path, 'rb').read())
    mode = b[0]
    pens = [b[3 + i * 12] for i in range(16)]
    border = b[3 + 16 * 12]
    return mode, pens, border

# Mode 0: two pixels per byte; mode 1: four; each pen's bits are scattered.
def _decode(byte, mode):
    b = byte
    if mode == 0:
        p0 = ((b>>7)&1) | ((b>>2)&2) | ((b>>3)&4) | ((b<<2)&8)
        p1 = ((b>>6)&1) | ((b>>1)&2) | ((b>>2)&4) | ((b<<3)&8)
        return [p0, p1]
    if mode == 1:
        return [((b >> (7-i)) & 1) | (((b >> (3-i)) & 1) << 1) for i in range(4)]
    return [(b >> (7-i)) & 1 for i in range(8)]

def screen_pixels(scr, mode, width_bytes=80, lines=200):
    """Return a list of `lines` rows of pen indices, CPC interleave undone."""
    d = strip_amsdos(scr)
    ppb = (2, 4, 8)[mode]
    rows = []
    for y in range(lines):
        off = (y % 8) * 0x800 + (y // 8) * width_bytes
        row = []
        for x in range(width_bytes):
            row += _decode(d[off + x], mode)
        rows.append(row)
    return rows

def render(scr_path, pal_path, scale=1):
    mode, pens, _ = read_pal(pal_path)
    rows = screen_pixels(open(scr_path, 'rb').read(), mode)
    ppb = (2, 4, 8)[mode]
    w, h = 80 * ppb, len(rows)
    im = Image.new('RGB', (w, h))
    px = im.load()
    for y, row in enumerate(rows):
        for x, p in enumerate(row):
            px[x, y] = ga_rgb(pens[p])
    if scale != 1:
        im = im.resize((w * scale, h * scale), Image.NEAREST)
    return im, mode, pens, rows


# Compiled_Main3.asm .Mode0Pal, the one in-game palette, reversed: SetColours
# selects pen 15 from the first entry and works down to pen 0, so the table is
# stored backwards. It is NOT the .PAL saved beside the art on the work disc -
# those agree on pens 0-12 and differ on 13-15, and 13 and 14 are both used.
MODE0_PAL = [
    0x54, 0x5D, 0x57, 0x53, 0x5E, 0x59, 0x4B, 0x5F,
    0x58, 0x47, 0x4C, 0x56, 0x44, 0x43, 0x5C, 0x54,
][::-1]


def mode0_rgb():
    """The in-game palette as 16 RGB triples, indexed by pen."""
    return [ga_rgb(p) for p in MODE0_PAL]
