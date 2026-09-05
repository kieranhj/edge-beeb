"""seed_art.py - write the artist's sheets and palette from the conversion the
game runs on today, so he starts from a working picture rather than blank.

  python tools/seed_art.py           the C64 conversion (the default build)
  python tools/seed_art.py --cpc     the Amstrad port's art instead

Writes assets/art/palette.png, chars.png, sprites.png, panel.png, hud.png and
titlefont.png, plus palette.gpl and palette.act for Aseprite and GIMP.

--cpc seeds the four sheets the Amstrad port has its own art for; the title
font is not one of them, the two ports sharing the title page, so it is always
the C64's. Because it goes through the same bbc.py
colour path the exporters do, re-exporting the seeded sheets reproduces
src/data/*.bin byte for byte - which is the check that the whole PNG path is
transparent (tools/validate_art.py --roundtrip).

--blank writes the sheets in the not-yet-drawn key instead, for a redraw from
nothing; every cell then falls back to the mechanical conversion until it is
painted.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import bbc        # noqa: E402
import palette    # noqa: E402
import sheets     # noqa: E402
import mechanical  # noqa: E402


def main(cpc=False, blank=False):
    pal = palette.SEED
    palette.save(pal)
    open(os.path.join(sheets.ART, "palette.gpl"), "w").write(palette.gpl(pal))
    open(os.path.join(sheets.ART, "palette.act"), "wb").write(palette.act(pal))
    print(f"{palette.PALETTE_PNG} {palette.ENTRIES} entries"
          f"{'' if palette.is_mode2(pal) else ' (NOT MODE 2 legal: needs a NULA)'}")

    art = ((sheets.CHARS, mechanical.characters(cpc)),
           (sheets.SPRITES, mechanical.sprites(cpc)),
           (sheets.PANEL, mechanical.panel(cpc)),
           (sheets.HUD, mechanical.hud(cpc)),
           (sheets.TITLE, mechanical.title_font()))
    if blank:
        art = tuple((sheet, [None] * len(cells)) for sheet, cells in art)
    for sheet, cells in art:
        path = sheets.write(sheet, cells, pal)
        print(f"{path} {sheet.size[0]}x{sheet.size[1]}, "
              f"{sheet.count} cells of {sheet.wide}x{sheet.high} fat pixels")


if __name__ == "__main__":
    main(cpc="--cpc" in sys.argv[1:], blank="--blank" in sys.argv[1:])
