"""art_grid.py - a guide layer for the sheets in assets/art, the way
tools/paint_map.py --grid makes one for the level.

  python tools/art_grid.py            all five sheets
  python tools/art_grid.py chars      just that one

Writes assets/art/<sheet>-grid.png beside each sheet: the same size, and
transparent everywhere it is not a line. Put it over the sheet as its own
layer, turn it on to find something, turn it off to paint.

`chars-bbc.png` is 256 characters in a 128 x 128 square with nothing between them,
and which cell is which is countable but tiring. So each cell carries:

  * its boundary, solid;
  * the FAT PIXEL grid inside it, dotted - a character is 4 fat pixels by 8
    rows and every pixel of the art is 2 image pixels wide, which is a rule the
    validator enforces and the artist has to hold to by eye;
  * every FOURTH cell boundary brighter than the rest, which is the ruler: on
    a 16-wide sheet you count four at a time to the cell you want;
  * its number, haloed - but ONLY where the cell has room to spare, which the
    test puts at half the cell's width. The sprite sheet has it, at 24 pixels
    across; a character cell is 8 and `FF` is 7 of them, so a numbered charset
    is a sheet of numerals with the art buried underneath. That was built and
    is why the rule is what it is (KC: "it's just too dense"). An earlier
    version was worse still and let the label overrun into its neighbour.

These are guides, not art: they are gitignored, they are never read back, and
tools/validate_art.py does not look at them. Regenerate rather than keep.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import guide    # noqa: E402
import sheets   # noqa: E402

SUFFIX = "-grid"

NAMES = {"chars": sheets.CHARS, "sprites": sheets.SPRITES,
         "panel": sheets.PANEL, "hud": sheets.HUD, "titlefont": sheets.TITLE}


def numbered(sheet):
    """Whether this sheet's cells get their index written in them.

    The test is HALF the cell's width, not all of it. Two earlier versions got
    this wrong in opposite directions: `$FF` overran an 8-pixel character cell
    and made every row of the charset one stripe, and `FF` fitted it exactly
    and buried the character underneath. A number belongs on a cell with room
    to spare for it - the sprite sheet, at 24 across - and nowhere else. What
    the small sheets get instead is the every-fourth rule below, which is a
    ruler that costs no pixels."""
    return guide.text_width(str(sheet.count - 1), 1) * 2 <= sheet.wide * sheets.SX


def build(sheet):
    w, h = sheet.size
    im, px, size = guide.new(w, h)

    # The fat pixel grid: dotted, and the reason it is here is that a fat pixel
    # is 2 image pixels wide and a half-pixel is an error the artist can only
    # avoid by seeing where the pairs begin.
    for x in range(0, w + 1, sheets.SX):
        guide.vrule(px, size, x, guide.MINOR, dotted=True)
    for y in range(0, h + 1, sheets.SY):
        guide.hrule(px, size, y, guide.MINOR, dotted=True)

    # Cell boundaries, and every fourth one brighter. That is the ruler on a
    # sheet too small to carry numerals: count four at a time.
    for cx in range(sheet.per_row + 1):
        guide.vrule(px, size, cx * sheet.wide * sheets.SX,
                    guide.EVERY4 if cx % 4 == 0 else guide.MAJOR)
    for cy in range(sheet.rows + 1):
        guide.hrule(px, size, cy * sheet.high * sheets.SY,
                    guide.EVERY4 if cy % 4 == 0 else guide.MAJOR)

    if numbered(sheet):
        for n in range(sheet.count):
            ox, oy = sheet.origin(n)
            guide.text(px, size, ox + 1, oy + 1, str(n))
    return im, numbered(sheet)


def main(which):
    todo = NAMES if not which else {k: NAMES[k] for k in which}
    for name, sheet in todo.items():
        im, nums = build(sheet)
        # Named after the SHEET's own file, not after the command-line word, so
        # a sheet that gets renamed takes its guide with it.
        stem = os.path.splitext(sheet.path)[0]
        path = f"{stem}{SUFFIX}.png"
        im.save(path)
        how = (f"numbered 0-{sheet.count - 1}" if nums else
               f"not numbered - a {sheet.wide * sheets.SX}-pixel cell has no "
               "room to spare; every fourth grid line is brighter instead")
        print(f"{path} {im.size[0]}x{im.size[1]}, {sheet.count} cells of "
              f"{sheet.wide}x{sheet.high} fat pixels, {how}")
    print("  a LAYER over the sheet, not part of it: nothing reads these back")


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    bad = [a for a in args if a not in NAMES]
    if bad:
        raise SystemExit(f"no such sheet: {', '.join(bad)}. "
                         f"One of {', '.join(NAMES)}, or none for all five.")
    main(args)
