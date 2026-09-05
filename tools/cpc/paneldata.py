"""paneldata.py - the CPC port's status panel and HUD font, as pen grids.

Two files off `source_cpc/Source/`, and both are stored in the shape the Z80
writes them rather than in any tidy left-to-right order, so this is where the
orders live.

**EG_Panel.asm** holds the panel as eight `PanelBlockN` tables of 320 bytes.
They are not eight frames: `N` is the SCANLINE. A CPC screen interleaves
`(line % 8) * &800 + (line / 8) * 80`, so block N sits at `&4000 + N * &800`
(which is what the `defs` padding between the blocks adds up to) and its 320
bytes are scanline N of four consecutive character rows, 80 bytes each. The
panel is therefore **4 character rows by 8 scanlines = 32 pixel rows**, 80
bytes = 160 mode 0 pixels wide - the same 160 as ours, and one row SHORTER
than the C64's five. `EG_Interrupts2.asm` confirms the geometry: `int_rout4`
sets R12/R13 to `&10, &00` for base &4000 and `int_rout5` sets R6 = 4.

**EG_GameFont.ASM** holds the ten digits and the life marker. `PrintScoreChar`
and `PrintLife` in `EG_Display3.asm` are unrolled copies that walk the CPC's
scanline bits with `set`/`res` on D and zig-zag along E, so the source bytes
come out in an order that is neither row-major nor column-major. `DIGIT_ORDER`
and `LIFE_ORDER` below are those two routines read off instruction by
instruction, and both are **proved** rather than assumed: the panel image
already has "000000", "012345" and three life markers drawn into it, and
`verify()` checks every byte of all seven against what these orders produce.

A digit is 2 bytes by 6 scanlines (lines 1-6 of its character row, 0 and 7
blank) inside a 16-byte slot; a life marker is 4 bytes by all 8.
"""

import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PANEL_ASM = os.path.join(ROOT, 'source_cpc', 'Source', 'EG_Panel.asm')
FONT_ASM = os.path.join(ROOT, 'source_cpc', 'Source', 'EG_GameFont.ASM')

ROWS, SCANLINES, WIDE = 4, 8, 80      # character rows, lines each, bytes across
HIGH = ROWS * SCANLINES               # 32 pixel rows

# PrintScoreChar, EG_Display3.asm: source byte -> (scanline, byte column).
# D starts on scanline 1 and is walked set 4 / res 3 / set 5 / (set 3, res 4) /
# res 3, which is scanlines 1, 3, 2, 6, 5, 4; E steps +1 then -1 alternately.
DIGIT_ORDER = [(1, 0), (1, 1), (3, 1), (3, 0), (2, 0), (2, 1),
               (6, 1), (6, 0), (5, 0), (5, 1), (4, 1), (4, 0)]
DIGIT_SLOT = 16                       # `rlca` x4 off the code: a 16-byte stride

# PrintLife, same file: scanlines 0, 1, 3, 2, 6, 7, 5, 4, four bytes each,
# left to right on the way out and right to left on the way back.
LIFE_ORDER = [(sl, c)
              for sl in (0, 1, 3, 2, 6, 7, 5, 4)
              for c in (range(4) if sl in (0, 3, 6, 5) else range(3, -1, -1))]
LIFE_WIDE = 4

# Where the runtime pokes each field, from EG_Display3.asm's screen addresses,
# as (character row, byte column). &485E, &4886 and &40C2 less base &4000 and
# less scanline * &800, divided by the 80-byte row.
SCORE_AT = (1, 14)                    # six digits, 2 bytes each
HISCORE_AT = (1, 54)
LIVES_AT = (2, 34)                    # three markers, 4 bytes each


def _defbs(path):
    """Every `.label` in the file with the `defb` bytes that follow it."""
    out, cur = {}, None
    for line in open(path, encoding='latin-1'):
        s = line.split(';')[0].strip()
        m = re.match(r'\.(\w+)', s)
        if m:
            cur = m.group(1)
            out[cur] = []
            continue
        if cur is None:
            continue
        if s.startswith('defb'):
            out[cur] += [int(v) for v in s[4:].split(',')]
        elif s:
            cur = None
    return out


def panel():
    """The panel as HIGH rows of WIDE bytes, the CPC interleave undone."""
    blocks = _defbs(PANEL_ASM)
    rows = [None] * HIGH
    for sl in range(SCANLINES):
        b = blocks['PanelBlock%d' % sl]
        assert len(b) == ROWS * WIDE, (sl, len(b))
        for r in range(ROWS):
            rows[r * SCANLINES + sl] = b[r * WIDE:(r + 1) * WIDE]
    return rows


def _cell(data, order, wide):
    grid = [[0] * wide for _ in range(SCANLINES)]
    for i, (sl, c) in enumerate(order):
        grid[sl][c] = data[i]
    return grid


def digits():
    """The ten digits, each SCANLINES rows of 2 bytes."""
    f = _defbs(FONT_ASM)
    return [_cell(f['gamefont%d' % n], DIGIT_ORDER, 2) for n in range(10)]


def life():
    """The life marker, SCANLINES rows of LIFE_WIDE bytes."""
    return _cell(_defbs(FONT_ASM)['playerlife'], LIFE_ORDER, LIFE_WIDE)


def verify():
    """The panel image ships with the score, high score and lives already drawn
    into it, so it is the check on DIGIT_ORDER and LIFE_ORDER. Raises if either
    is wrong; returns what it proved."""
    p, dig, li = panel(), digits(), life()

    def at(row, col, glyph, wide):
        for y in range(SCANLINES):
            got = p[row * SCANLINES + y][col:col + wide]
            assert got == glyph[y], (row, col, y, got, glyph[y])

    for i in range(6):                                  # score reads 000000
        at(SCORE_AT[0], SCORE_AT[1] + i * 2, dig[0], 2)
    for i in range(6):                                  # high score, 012345
        at(HISCORE_AT[0], HISCORE_AT[1] + i * 2, dig[i], 2)
    for i in range(3):                                  # three life markers
        at(LIVES_AT[0], LIVES_AT[1] + i * LIFE_WIDE, li, LIFE_WIDE)
    return '6 score digits, 6 high-score digits, 3 life markers'
