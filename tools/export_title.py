#!/usr/bin/env python3
"""Export the C64 title page's font and credits to MODE 2.

The C64 titles page draws five lines of credits in the STATUS character set
(`source_c64/data/status.chr`), which is a multicolour set: each character is
four double-width pixels, not eight. That is exactly one of our 4-fat-pixel
character cells, and 38 of them is 152 of the play area's 160 pixels - so the
original's layout transcribes at 1:1 with no rescaling at all.

Glyphs $00-$1f are all the title needs: $00 blank, $01-$1a A-Z, then ! . , - ?
The mapping is the original's own `scroll_decode`, which turns a C64 screen
code into one of those.

Output: src/data/title.bin
    0..511    32 glyphs, 16 bytes each: byte column 0's eight scanlines, then
              byte column 1's. A glyph is therefore a straight 16-byte copy to
              the screen, because our byte columns are 8 bytes apart and
              consecutive.
    512..701  five lines of 38 glyph numbers, the C64's ttl_credits.
"""

import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHARSET = os.path.join(ROOT, 'source_c64', 'data', 'status.chr')
OUT = os.path.join(ROOT, 'src', 'data', 'title.bin')

GLYPHS = 32

# ttl_credits, verbatim from source_c64/edge_grinder.asm. Each is 38 characters,
# which is what the original's `cpx #$26` loop copies.
CREDITS = [
    "edge grinder     by     cosine systems",
    "coding                jason t.m.r kelk",
    "graphics           trevor smila storey",
    "music by            sean odie connolly",
    "released by        format war and rgcd",
]
LINE_LEN = 38

# The multicolour bit pair -> our MODE 2 logical colour. Pair 0 is the
# background and stays black; the glyphs use 3 for the body and 1 and 2 for the
# shadow and highlight they are drawn with. Blue/cyan/white is the scenery's
# own palette, so the page sits with the rest of the game.
PAIR_COLOUR = {0: 0, 1: 4, 2: 6, 3: 7}


def mode2_pixel(colour, left):
    """MODE 2 encodes a pixel's four bits at 7,5,3,1 (left) or 6,4,2,0 (right)."""
    b = ((colour & 1) << 0) | ((colour & 2) << 1) | ((colour & 4) << 2) | ((colour & 8) << 3)
    return b << 1 if left else b


def scroll_decode():
    """The original's table: C64 screen code -> glyph. Everything it does not
    name is the blank."""
    t = [0] * 64
    for i in range(27):            # '@' and A-Z at screen codes 0-26
        t[i] = i
    t[33] = 0x1b                   # !
    t[44] = 0x1d                   # ,
    t[45] = 0x1e                   # -
    t[46] = 0x1c                   # .
    t[63] = 0x1f                   # ?
    return t


def screen_code(ch):
    if ch == ' ':
        return 32
    if 'a' <= ch <= 'z':
        return ord(ch) - ord('a') + 1
    return ord(ch)                 # punctuation is its ASCII code in this range


def main():
    raw = open(CHARSET, 'rb').read()
    assert len(raw) == 2 + 2048, 'status.chr should be a load address and 256 chars'
    chars = raw[2:]

    out = bytearray()
    for g in range(GLYPHS):
        cols = [bytearray(8), bytearray(8)]
        for y in range(8):
            b = chars[g * 8 + y]
            for p in range(4):                     # four multicolour pixels
                colour = PAIR_COLOUR[(b >> (6 - 2 * p)) & 3]
                if colour == 0:
                    continue
                cols[p // 2][y] |= mode2_pixel(colour, left=(p % 2 == 0))
        out += cols[0] + cols[1]

    dec = scroll_decode()
    for line in CREDITS:
        assert len(line) == LINE_LEN, '%r is %d characters, not %d' % (
            line, len(line), LINE_LEN)
        for ch in line:
            out.append(dec[screen_code(ch) & 63])

    with open(OUT, 'wb') as f:
        f.write(out)
    print('%s: %d bytes (%d glyphs, %d lines of %d)'
          % (OUT, len(out), GLYPHS, len(CREDITS), LINE_LEN))


if __name__ == '__main__':
    main()
