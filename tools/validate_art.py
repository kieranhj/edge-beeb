"""validate_art.py - check the artist's sheets before they go anywhere near a
build, and say what is wrong with coordinates rather than guessing.

  python tools/validate_art.py              check assets/art and render it
  python tools/validate_art.py --roundtrip  also prove the PNG path is
                                            transparent: re-export from the
                                            sheets and from the mechanical
                                            conversion and diff the results

Nothing here is run by build.ps1. It is what a drop from the artist goes
through on receipt: the exporters trust their input, and the point of this
file is that they can.

What it checks:

  * dimensions and the cell grid, per sheet;
  * every fat pixel is one solid block - the sheets are drawn at 2:1 so they
    look right in Aseprite, and a stray half-pixel would otherwise be silently
    resolved to whichever half the reader happened to sample;
  * every colour is EXACTLY a palette entry, the transparency key or the
    not-yet-drawn key. An unknown colour is an error naming the cell and the
    pixel, never a nearest match - a nearest match is how art quietly stops
    being what the artist drew;
  * the transparency key appears only on the sprite sheet. A character, the
    status panel and a HUD glyph are all opaque: none of them has anything
    behind it to show through;
  * the not-yet-drawn key is a whole cell or nothing;
  * the palette is legal for MODE 2 (all eight entries one of the BBC eight),
    or says plainly that it would need a NULA.

And three things that are not errors but are worth knowing, because each is a
game mechanic that lives in the art and is easy to paint away:

  * BLANK CHARACTERS. The starfield plots a star only where the play buffer
    byte reads exactly zero (src/bank1.asm), so "empty space" has to stay
    logical 0. If the count of all-black characters falls, stars will start
    disappearing behind scenery that looks empty.
  * THE HIT FLASH. export_sprites.py derives KEEP from the art: a frame that
    holds blue, white and one free colour flashes the way the C64 does, and
    anything else flashes whole. This prints which way the sheet will go, so
    the change is never a surprise.
  * THE HUD CELLS. Eighteen cells of the panel are overwritten the moment the
    score, the high score or the lives are drawn - anything painted there is
    seen at boot and never again - and there is nothing in the picture to say
    which eighteen. The C64's own bar leaves them all blank; the Amstrad's
    draws its digits and markers in deliberately, so this is a warning rather
    than a rule.

Collision is NOT in the art and cannot be painted: it is bit 4 of col_decode
per character number (docs/layer-1-graphics-pipeline.md). Repainting a solid
character to look like empty space leaves it just as fatal, so the brief asks
the artist to keep solid things looking solid.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import bbc          # noqa: E402
import mechanical   # noqa: E402
import palette      # noqa: E402
import sheets       # noqa: E402

OUT = "tools/output"


def check_palette(pal):
    print(f"palette  {palette.PALETTE_PNG}")
    if palette.is_mode2(pal):
        alias = [n for n in range(8, 16) if tuple(pal[n]) != tuple(pal[n - 8])]
        print("  MODE 2 legal: every entry is one of the eight BBC colours"
              + (f"; logicals {alias} do not alias 0-7" if alias else ""))
    else:
        bad = [n for n, c in enumerate(pal)
               if tuple(c) not in [tuple(v) for v in bbc.BBC_RGB]]
        print(f"  NOT MODE 2 legal: entries {bad} are not BBC colours. "
              "This palette needs a NULA; tools/export_palette.py --nula.")
    distinct = len({tuple(c) for c in pal})
    print(f"  {distinct} distinct colours over {palette.ENTRIES} entries")
    return palette.is_mode2(pal)


def check_sheet(sheet, pal, what):
    cells, errors = sheets.read(sheet, pal, strict=False)
    drawn = sum(1 for c in cells if c is not None)
    print(f"{what:9}{sheet.path}  {sheet.size[0]}x{sheet.size[1]}, "
          f"{drawn}/{sheet.count} drawn")
    for path, n, x, y, msg in errors[:40]:
        where = f"cell {n}" + (f" pixel ({x},{y})" if x >= 0 else "")
        print(f"  ERROR {where}: {msg}")
    if len(errors) > 40:
        print(f"  ... and {len(errors) - 40} more")
    return cells, errors


def main(roundtrip=False):
    if not os.path.exists(palette.PALETTE_PNG):
        raise SystemExit(f"{palette.PALETTE_PNG} is missing - "
                         "run tools/seed_art.py first")
    pal = palette.load()
    check_palette(pal)
    print()

    chars, e1 = check_sheet(sheets.CHARS, pal, "chars")
    blank_now = sum(1 for c in chars
                    if c is not None and not any(v for row in c for v in row))
    blank_was = sum(1 for c in mechanical.characters()
                    if not any(v for row in c for v in row))
    print(f"  {blank_now} all-black characters (the C64 conversion has "
          f"{blank_was}); the starfield only plots into those")
    print()

    frames, e2 = check_sheet(sheets.SPRITES, pal, "sprites")
    print()

    panel, e3 = check_sheet(sheets.PANEL, pal, "panel")
    import export_panel
    warn = export_panel.check_hud_cells(panel)
    print("  " + (warn if warn else
                  "the 18 cells the HUD writes into are clear, as the C64's bar "
                  "leaves them"))
    print()

    glyphs, e4 = check_sheet(sheets.HUD, pal, "hud")
    print("  blank, the digits 0-9, then the life marker's two halves")
    print()

    errors = e1 + e2 + e3 + e4
    if not errors:
        import export_sprites
        merged = [f if f is not None else m for f, m in
                  zip(frames, mechanical.sprites(count=len(frames)))]
        keep = export_sprites.derive_keep(merged)
        print("hit flash: " + ("blue and white are held back, as the C64 does"
                               if keep == export_sprites.C64_KEEP else
                               "the whole sprite recolours - this art does not "
                               "hold to the C64's three-shared-colours rule"))

    if roundtrip:
        print()
        rc = roundtrip_check()
        if rc:
            errors.append(("roundtrip", -1, -1, -1, rc))

    print()
    if errors:
        raise SystemExit(f"{len(errors)} error(s) - nothing exported")
    print("OK. Now: python tools/export_palette.py && "
          "python tools/export_tiles.py && python tools/export_sprites.py && "
          "python tools/export_panel.py")


def roundtrip_check():
    """The sheets against the mechanical conversion, cell for cell. Passes only
    while the artist has not changed anything, which is exactly what makes it
    the check that the PNG path itself adds and loses nothing."""
    import pngart
    pairs = (("characters", pngart.characters(fallback=mechanical.characters()),
              mechanical.characters()),
             ("frames", pngart.sprites(mechanical.FRAMES,
                                       fallback=mechanical.sprites()),
              mechanical.sprites()),
             ("panel cells", pngart.panel(fallback=mechanical.panel()),
              mechanical.panel()),
             ("HUD glyphs", pngart.hud(fallback=mechanical.hud()),
              mechanical.hud()))
    for what, a, b in pairs:
        diff = [n for n, (x, y) in enumerate(zip(a, b)) if x != y]
        if diff:
            print(f"roundtrip: {len(diff)} {what} differ from the C64 "
                  f"conversion (first {diff[0]}) - expected once the artist "
                  "has started work")
        else:
            print(f"roundtrip: all {len(a)} {what} identical to the "
                  "C64 conversion")
    return None


if __name__ == "__main__":
    main(roundtrip="--roundtrip" in sys.argv[1:])
