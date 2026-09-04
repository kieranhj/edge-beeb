#!/usr/bin/env python3
"""Export the C64 title page's zoom scroller: its font, its block cell and its
message.

The zoom scroller (`zoom_mover` in the original) is a bitmap of character cells
six rows high. Its font is NOT the credits' multicolour set read as multicolour:
it is `$4d00 + glyph*8` read as a plain 8x8 BITMAP, one bit a zoom pixel, and
`$4d00` is character `$a0` of `status.chr` - which the C64 loads at `$4800`.
Characters `$a0`-`$bf` are a 32-glyph hires alphabet with rows 0 and 7 blank,
which is why the scroller uses bytes 1-6 and is six rows high.

A set bit puts character `$8e` on screen and a clear one puts `$00`. `$8e` is
not solid: read as multicolour it is a three-colour texture, and `ttl_clear`
gives the whole band colour RAM `$0d`, light green. Four multicolour pixels is
one of our 4-fat-pixel cells, so it transcribes at 1:1 into 16 bytes.

Output: src/data/zoom.bin, 272 bytes, in sideways bank 1
      0..255    32 font glyphs, 8 bytes each, 1bpp, bit 7 leftmost
    256..271    the block cell: byte column 0's eight scanlines, then column 1's

        src/data/scroll.bin, in the PANEL file at TTL_SCROLL
                the message as glyph numbers, terminated &FF - NOT 0, because 0
                is the blank glyph here where on the C64 it was the unused
                screen code '@'

THE MESSAGE ITSELF IS assets/scrolltext.txt, which is meant to be edited. It
used to be a literal in this file and to live in bank 1 behind the font, where
there were ELEVEN bytes of headroom - no use at all for something a person is
supposed to change. It rides in the PANEL disc file now and lands at &3C80 with
the titles' second credit set, which is 896 bytes of RAM that neither rupture
cycle fetches (decision 53); the build prints what is left of it.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from export_title import mode2_pixel, scroll_decode, screen_code  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHARSET = os.path.join(ROOT, 'source_c64', 'data', 'status.chr')
OUT = os.path.join(ROOT, 'src', 'data', 'zoom.bin')
OUT_MSG = os.path.join(ROOT, 'src', 'data', 'scroll.bin')
TEXT = os.path.join(ROOT, 'assets', 'scrolltext.txt')

ZOOM_FONT_CHAR = 0xa0          # $4d00 - $4800, over 8 bytes a character
GLYPHS = 32
BLOCK_CHAR = 0x8e              # what a set bit writes

# The titles page's own multicolour registers, from rout2_titles: $d021 = $00
# black, $d022 = $09 brown, $d023 = $01 white, and pair 3 is colour RAM, which
# ttl_clear sets to $0d light green across the whole band. Pairs 1 and 2 keep
# the colours export_title.py already gives the credits, so the page sits in
# one palette; pair 3 takes the C64's own light green.
PAIR_COLOUR = {0: 0, 1: 4, 2: 6, 3: 2}

def read_scrolltext():
    """assets/scrolltext.txt: lines joined end to end with NOTHING added, and
    # and blank lines dropped. A line break is not a space - the trailing
    spaces in the file are what pace the scroller, so only the newline itself
    is stripped."""
    dec = scroll_decode()
    out = []
    for n, line in enumerate(open(TEXT, encoding='utf-8'), 1):
        line = line.rstrip('\r\n')
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        # Name the line: this file is meant to be edited by hand, and a
        # character the font has not got would otherwise scroll past as a hole.
        for ch in line.lower():
            assert ch == ' ' or dec[screen_code(ch) & 63], (
                '%s line %d: %r is not in this font, which has A-Z, space and'
                ' ! . , - ? and nothing else'
                % (os.path.basename(TEXT), n, ch))
        out.append(line)
    return ''.join(out).lower()


def main():
    raw = open(CHARSET, 'rb').read()
    assert len(raw) == 2 + 2048, 'status.chr should be a load address and 256 chars'
    chars = raw[2:]

    out = bytearray()

    # The font, as the C64 reads it: eight raw bytes a glyph.
    base = ZOOM_FONT_CHAR * 8
    out += chars[base:base + GLYPHS * 8]

    # Rows 0 and 7 are blank in every glyph - that is what makes the band six
    # rows high rather than eight. Assert it rather than trusting the reading.
    for g in range(GLYPHS):
        assert out[g * 8] == 0 and out[g * 8 + 7] == 0, \
            'zoom glyph %d has ink on row 0 or 7' % g
    assert not any(out[0:8]), 'glyph 0 should be the blank'

    # The block cell, rendered once.
    cols = [bytearray(8), bytearray(8)]
    for y in range(8):
        b = chars[BLOCK_CHAR * 8 + y]
        for p in range(4):
            colour = PAIR_COLOUR[(b >> (6 - 2 * p)) & 3]
            if colour:
                cols[p // 2][y] |= mode2_pixel(colour, left=(p % 2 == 0))
    out += cols[0] + cols[1]

    assert len(out) == 272, 'the font and the block cell are 272 bytes'

    # The message, out of assets/scrolltext.txt and into its own file.
    text = read_scrolltext()
    dec = scroll_decode()
    msg = bytearray()
    for ch in text:
        g = dec[screen_code(ch) & 63]
        # Every character the font has decodes to a glyph, and only the space
        # decodes to the blank. Anything else that comes back 0 is a character
        # this font has not got, and would otherwise scroll past as a hole.
        assert g or ch == ' ', (
            '%r is not in this font: it has A-Z, space and ! . , - ? only' % ch)
        msg.append(g)
    msg.append(0xff)

    with open(OUT, 'wb') as f:
        f.write(out)
    with open(OUT_MSG, 'wb') as f:
        f.write(msg)
    print('%s: %d bytes (%d font glyphs, block cell)' % (OUT, len(out), GLYPHS))
    print('%s: %d bytes (%d characters from %s)'
          % (OUT_MSG, len(msg), len(text), os.path.relpath(TEXT, ROOT)))


if __name__ == '__main__':
    main()
