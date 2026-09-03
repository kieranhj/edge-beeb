#!/usr/bin/env python3
"""Export the C64 status bar to a ready-to-copy MODE 2 panel image.

The C64's status bar is five rows of 40 characters at the top of the screen,
drawn once and never redrawn: the character codes are assembled straight into
the screen buffer (`* = buffer_1` at the end of edge_grinder.asm) and the
colour RAM is filled from `status_cols` by `status_init`. Only three fields
move afterwards - the score, the high score and the lives bars - and
`status_decode` pokes those characters back into the same buffer.

The charset is `source_c64/data/status.chr` read as MULTICOLOUR, which is what
it is: four double-width pixels a character. That is one of our 4-fat-pixel
cells exactly, so 40 characters is 160 pixels and the original's layout
transcribes at 1:1 - the same 1:1 that `export_title.py` found for the credits,
which use the same charset.

Colour (decision 34). The C64 multicolour bit pairs take:
    00  $d021 = 0  black
    01  $d022 = 6  blue
    10  $d023 = 1  white
    11  colour RAM, from status_cols: $0b dark grey, $0d light green,
        $0f light grey, $00 black
MODE 2 has no greys, so the mapping is faithful-as-possible: the two greys go
to the colours they are standing in for in a 16-colour picture - dark grey to
blue and light grey to white, which is what the surrounding pairs already use -
and light green keeps its hue. The distinction between dark grey and blue is
the one thing that is lost.

Output, both into sideways bank 3:

src/data/panel.bin, 3200 bytes
    The panel image: 5 rows x 640 bytes, a straight copy to &3000. A cell is
    16 contiguous bytes (byte column 0's eight scanlines then byte column 1's)
    because our byte columns are eight bytes apart and consecutive.

src/data/hud.bin, 208 bytes
    Thirteen glyphs, 16 bytes each, all at colour RAM $0b - which is what
    every cell status_decode writes into carries:
        0       blank
        1-10    digits '0' to '9'   (C64 characters $21-$2a)
        11, 12  the lives bar pair  (C64 characters $8f, $90)
"""

import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CHARSET = os.path.join(ROOT, 'source_c64', 'data', 'status.chr')
SOURCE = os.path.join(ROOT, 'source_c64', 'edge_grinder.asm')
OUT = os.path.join(ROOT, 'src', 'data', 'panel.bin')
OUT_HUD = os.path.join(ROOT, 'src', 'data', 'hud.bin')

PANEL_ROWS = 5
PANEL_COLS = 40
PANEL_CELLS = PANEL_ROWS * PANEL_COLS

# $d021, $d022, $d023 as rout1 sets them for the panel's raster.
D021, D022, D023 = 0x00, 0x06, 0x01

# C64 colour -> our MODE 2 logical colour. Decision 34.
C64_TO_MODE2 = {
    0x00: 0,        # black
    0x01: 7,        # white
    0x06: 4,        # blue
    0x0b: 4,        # dark grey   -> blue
    0x0d: 2,        # light green -> green
    0x0f: 7,        # light grey  -> white
}

# The characters the HUD writes, in the order the runtime indexes them.
HUD_CHARS = [0x00] + list(range(0x21, 0x2b)) + [0x8f, 0x90]
HUD_COLOUR = 0x0b       # every cell status_decode writes into carries this


def mode2_pixel(colour, left):
    """MODE 2 encodes a pixel's four bits at 7,5,3,1 (left) or 6,4,2,0 (right)."""
    b = ((colour & 1) << 0) | ((colour & 2) << 1) | ((colour & 4) << 2) | ((colour & 8) << 3)
    return b << 1 if left else b


def byte_list(text, want):
    """The first `want` !byte operands after the start of `text`, in order.
    Stops at the first operand that is not a literal, which is where the
    tables we read run out and the original's symbolic wave data begins."""
    out = []
    for line in text.splitlines():
        line = line.split(';')[0]
        m = re.search(r'!byte\s+(.*)', line)
        if not m:
            continue
        for term in m.group(1).split(','):
            term = term.strip()
            try:
                out.append(int(term[1:], 16) if term.startswith('$') else int(term))
            except ValueError:
                return out
            if len(out) == want:
                return out
    return out


def block_after(source, marker, count):
    """The first `count` !byte values following `marker`."""
    i = source.index(marker)
    got = byte_list(source[i:], count)
    assert len(got) >= count, '%s: found %d of %d' % (marker, len(got), count)
    return got[:count]


def render(chars, code, colour_ram):
    """One character as 16 MODE 2 bytes: column 0's scanlines then column 1's."""
    pair_colour = [
        C64_TO_MODE2[D021],
        C64_TO_MODE2[D022],
        C64_TO_MODE2[D023],
        C64_TO_MODE2[colour_ram & 0x0f],
    ]
    cols = [bytearray(8), bytearray(8)]
    for y in range(8):
        b = chars[code * 8 + y]
        for p in range(4):
            colour = pair_colour[(b >> (6 - 2 * p)) & 3]
            if colour == 0:
                continue
            cols[p // 2][y] |= mode2_pixel(colour, left=(p % 2 == 0))
    return bytes(cols[0] + cols[1])


def main():
    raw = open(CHARSET, 'rb').read()
    assert len(raw) == 2 + 2048, 'status.chr should be a load address and 256 chars'
    chars = raw[2:]

    source = open(SOURCE, 'r', encoding='latin-1').read()
    screen = block_after(source, '; Add in the status bar character data', PANEL_CELLS)
    cols = block_after(source, '; Status bar colour data', PANEL_CELLS)

    out = bytearray()
    for cell in range(PANEL_CELLS):
        out += render(chars, screen[cell], cols[cell])
    assert len(out) == PANEL_ROWS * 640

    hud = bytearray()
    for code in HUD_CHARS:
        hud += render(chars, code, HUD_COLOUR)

    with open(OUT, 'wb') as f:
        f.write(out)
    with open(OUT_HUD, 'wb') as f:
        f.write(hud)
    print('%s: %d bytes (%d cells)' % (OUT, len(out), PANEL_CELLS))
    print('%s: %d bytes (%d glyphs)' % (OUT_HUD, len(hud), len(HUD_CHARS)))


if __name__ == '__main__':
    main()
