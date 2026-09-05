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

The GLYPHS come from assets/art/titlefont.png (Layer 8, decision 62); the
credit TEXT below does not, because it is not art - it is five lines that have
to be 38 characters and to say true things, and it lives here where the
assertion that checks both can see it. --c64 bypasses the PNG and takes the
status charset outright, which is what the sheet was seeded from and therefore
produces the same bytes.

The font is restricted to logicals 12, 14 and 15 and the reader enforces it
(palette.TITLE_FADE): see PAIR_COLOUR below for why.

Output: src/data/title.bin
    0..511    32 glyphs, 16 bytes each: byte column 0's eight scanlines, then
              byte column 1's. A glyph is therefore a straight 16-byte copy to
              the screen, because our byte columns are 8 bytes apart and
              consecutive.
    512..701  five lines of 38 glyph numbers, the C64's ttl_credits.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'art'))
import mechanical  # noqa: E402
import pngart      # noqa: E402
import sheets      # noqa: E402

OUT = os.path.join(ROOT, 'src', 'data', 'title.bin')
OUT_EXTRA = os.path.join(ROOT, 'src', 'data', 'title_extra.bin')

GLYPHS = mechanical.TITLE_GLYPHS

# ttl_credits, verbatim from source_c64/edge_grinder.asm. Each is 38 characters,
# which is what the original's `cpx #$26` loop copies.
CREDITS = [
    "edge grinder     by     cosine systems",
    "coding                jason t.m.r kelk",
    "graphics           trevor smila storey",
    "music by            sean odie connolly",
    "released by        format war and rgcd",
]

# And this port's own, which the titles cross-fade to and back (Layer 9e,
# decision 53). Laid out the way the original's block is - a label at the left
# and its value hard against the right, line 1 included - so the swap reads as
# the same five lines changing rather than as a different page.
#
# The font is the C64 status charset and has no digits: A-Z, space and
# ! . , - ? are all of it. So no year, which is KC's call and costs nothing -
# ten more glyphs would have been 160 bytes.
CREDITS_BBC = [
    "edge grinder        bbc master version",
    "coding               kieran and claude",
    "graphics          john dethmunk blythe",
    "arkos music              tom and jerry",
    "released by                bitshifters",
]
LINE_LEN = 38

# The multicolour bit pair -> our MODE 2 logical colour. Pair 0 is the
# background and stays black; the glyphs use 3 for the body and 1 and 2 for the
# shadow and highlight they are drawn with. Blue/cyan/white is the scenery's
# own palette, so the page sits with the rest of the game.
# **Logicals 12, 14 and 15, not 4, 6 and 7** (Layer 9e, decision 53).
# setup_display maps 8-15 back onto 0-7, so these ARE blue, cyan and white
# and the page looks exactly as it did - but they are palette entries
# nothing else on the titles uses, so the credits can be faded on the
# palette alone while the panel and both zoom bands stay at full
# brightness. ttl_pal in src/bank1.asm pulses 15 and 14 to match.
PAIR_COLOUR = mechanical.TITLE_PAIR


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


def main(c64=False):
    glyphs = (mechanical.title_font() if c64 else
              pngart.title_font(fallback=mechanical.title_font()))
    out = bytearray(b''.join(sheets.pack_cell(g) for g in glyphs))

    dec = scroll_decode()

    def encode(lines):
        block = bytearray()
        for line in lines:
            assert len(line) == LINE_LEN, '%r is %d characters, not %d' % (
                line, len(line), LINE_LEN)
            for ch in line:
                g = dec[screen_code(ch) & 63]
                assert g or ch == ' ', '%r has no glyph in this font' % ch
                block.append(g)
        return block

    out += encode(CREDITS)

    # The second set goes in its own file, which src/panel.asm puts on the end
    # of the PANEL image so that it lands at &3C80 - the 896 bytes above the
    # panel that neither rupture cycle ever fetches. Bank 3, where the font and
    # the plotter are, has 45 bytes left in a -Cpc build and this is 190.
    extra = encode(CREDITS_BBC)

    with open(OUT, 'wb') as f:
        f.write(out)
    with open(OUT_EXTRA, 'wb') as f:
        f.write(extra)
    print('%s: %d bytes (%d glyphs, %d lines of %d)'
          % (OUT, len(out), GLYPHS, len(CREDITS), LINE_LEN))
    print('%s: %d bytes (%d lines of %d)'
          % (OUT_EXTRA, len(extra), len(CREDITS_BBC), LINE_LEN))


if __name__ == '__main__':
    main(c64='--c64' in sys.argv[1:])
