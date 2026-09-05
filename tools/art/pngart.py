"""pngart.py - the artist's PNG sheets as BBC logical colours.

The same interface tools/cpc/bbcart.py presents for the Amstrad art, so the
exporters ask for characters or sprite frames here and are otherwise unchanged.
Geometry is identical in all three sources - a character is 4 fat pixels by 8
rows, a sprite frame 12 by 21 - because the character and frame numbers are the
C64's in every port.

`fallback` is the mechanical conversion of the same sheet. A cell the artist
has not drawn yet (painted entirely in the not-yet-drawn key) takes its shape
from there, so a partial drop still builds a complete game and he can hand over
ten sprites at a time.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import palette  # noqa: E402
import sheets   # noqa: E402


def _merge(cells, fallback, what):
    out, missing = [], 0
    for n, c in enumerate(cells):
        if c is None:
            missing += 1
            if fallback is None:
                raise SystemExit(f"{what} {n} is not drawn and there is no fallback")
            out.append(fallback[n])
        else:
            out.append(c)
    if missing:
        print(f"  {missing}/{len(cells)} {what}s not drawn yet: "
              "mechanical conversion used for those")
    return out


def characters(fallback=None):
    """256 characters, each 8 rows of 4 BBC logical colours."""
    return _merge(sheets.read(sheets.CHARS), fallback, "character")


def sprites(count, fallback=None):
    """`count` frames, each 21 rows of 12 BBC logical colours, 0 transparent."""
    cells = sheets.read(sheets.SPRITES)[:count]
    return _merge(cells, fallback, "frame")


def panel(fallback=None):
    """The status panel as 200 cells of 8 rows of 4 BBC logical colours."""
    return _merge(sheets.read(sheets.PANEL), fallback, "panel cell")


def hud(fallback=None):
    """The thirteen HUD glyphs, each 8 rows of 4 BBC logical colours."""
    return _merge(sheets.read(sheets.HUD)[:13], fallback, "HUD glyph")


def game_palette():
    return palette.load()


def available():
    return (os.path.exists(palette.PALETTE_PNG)
            and all(os.path.exists(s.path) for s in sheets.ALL))
