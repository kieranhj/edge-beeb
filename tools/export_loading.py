#!/usr/bin/env python3
"""Export assets/TitlescreenBig.png to a MODE 2 screen image for the loader.

The picture is hand-authored at 640 x 512, which is a MODE 2 screen at its
true aspect: 4 x 2 device pixels per logical pixel, so 160 x 256, and every
4 x 2 block is verified uniform before anything is read out of it. Eight
colours, nearest of the BBC's own palette - the artwork is already drawn to
it, and the few off-by-ten RGBs are the paint program's, not a ninth colour.

Output: src/data/loading1.bin and loading2.bin, 10240 bytes each - the top
and bottom halves of the MODE 2 screen, straight copies to &3000 and &5800,
which is where the MOS puts the MODE 2 screen. 32 character rows of 640
bytes; a row is 80 cells of 8 scanlines; a byte is two pixels.

IN TWO HALVES BECAUSE OF WHERE THE COMPRESSED STREAM HAS TO SIT (decision
38). ZX0 unpacks forwards, so a stream may not share memory with its own
output unless it stays ahead of the writer - and one for the whole 20K
screen cannot: it would have to start at &8000 minus its own length,
which puts its tail past the top of the screen. So the stream is staged
BELOW the screen instead, at LOAD_STREAM in main.asm, and that leaves under
4K for it. One half packs to about 2.8K; the pair costs 44 bytes over
packing all 20K at once.

The loader shows this while the sideways banks load, so it is the one screen
drawn before the game owns the display. It uses the MOS's default MODE 2
palette (logical n -> physical n for 0-7), which is what setup_display
programs anyway.
"""

import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SRC = os.path.join(ROOT, 'assets', 'TitlescreenBig.png')
OUT = os.path.join(ROOT, 'src', 'data', 'loading%d.bin')

WIDTH, HEIGHT = 160, 256        # logical MODE 2 pixels
XSCALE, YSCALE = 4, 2
ROW_BYTES = 640
CELLS = 80
SPLIT = 16 * ROW_BYTES          # 16 of the 32 character rows

# The BBC's eight physical colours, RGB. Logical = physical here.
PALETTE = [(0, 0, 0), (255, 0, 0), (0, 255, 0), (255, 255, 0),
           (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]


def nearest(rgb):
    return min(range(8), key=lambda i: sum(
        (a - b) ** 2 for a, b in zip(rgb, PALETTE[i])))


def mode2_pixel(colour, left):
    """MODE 2 puts a pixel's four bits at 7,5,3,1 (left) or 6,4,2,0 (right)."""
    b = ((colour & 1) << 0) | ((colour & 2) << 1) | ((colour & 4) << 2) | \
        ((colour & 8) << 3)
    return b << 1 if left else b


def main():
    im = Image.open(SRC).convert('RGB')
    if im.size != (WIDTH * XSCALE, HEIGHT * YSCALE):
        raise SystemExit('%s is %dx%d, expected %dx%d'
                         % (SRC, im.size[0], im.size[1],
                            WIDTH * XSCALE, HEIGHT * YSCALE))
    src = im.load()

    # Read out one logical pixel per 4x2 block, and insist the block is flat:
    # a scaled-up picture that is not exactly 4x2 would be silently resampled.
    pix = [[0] * WIDTH for _ in range(HEIGHT)]
    seen = {}
    for y in range(HEIGHT):
        for x in range(WIDTH):
            block = {src[x * XSCALE + i, y * YSCALE + j]
                     for i in range(XSCALE) for j in range(YSCALE)}
            if len(block) != 1:
                raise SystemExit('block at logical (%d,%d) is not flat: %r'
                                 % (x, y, sorted(block)))
            rgb = block.pop()
            if rgb not in seen:
                seen[rgb] = nearest(rgb)
            pix[y][x] = seen[rgb]

    out = bytearray(HEIGHT // 8 * ROW_BYTES)
    for y in range(HEIGHT):
        row, line = divmod(y, 8)
        for cell in range(CELLS):
            b = (mode2_pixel(pix[y][cell * 2], True) |
                 mode2_pixel(pix[y][cell * 2 + 1], False))
            out[row * ROW_BYTES + cell * 8 + line] = b

    for i, half in enumerate((out[:SPLIT], out[SPLIT:])):
        with open(OUT % (i + 1), 'wb') as f:
            f.write(half)
        print('%s: %d bytes' % (OUT % (i + 1), len(half)))
    print('%d colours in the source -> logical %s'
          % (len(seen), sorted(set(seen.values()))))


if __name__ == '__main__':
    main()
