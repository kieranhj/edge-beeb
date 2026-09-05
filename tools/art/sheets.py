"""sheets.py - the two sheets the artist paints, and how a PNG becomes BBC
logical colours (and back).

Both sheets are drawn at 2:1, one screen fat pixel being 2 image pixels across
and 1 down, which is the aspect the Beeb shows in MODE 2 and the scale
reference/sprite-sheet.png already uses. Every fat pixel must therefore be a
uniform 2x1 block; validate_art.py is what says so, with coordinates.

  assets/art/chars.png    128 x 128   256 characters, 16 a row.
                          A cell is 8 x 8 image pixels: 4 fat pixels by 8 rows.
                          Fully opaque - the transparency key is illegal here.
  assets/art/sprites.png  192 x 336   128 slots, 8 a row; frames 0-118 are the
                          game's and 119-127 are blank. A cell is 24 x 21:
                          12 fat pixels by 21 rows. The grey key is see-through.
  assets/art/panel.png    320 x 40    the status bar as a PICTURE, 5 character
                          rows of 40 - which is what it is on screen, at the
                          size it appears. Cut into 200 cells on export.
  assets/art/hud.png      128 x 8     16 slots, 13 used: blank, the digits 0-9,
                          then the life marker's two halves. A cell is 8 x 8,
                          the same 4 x 8 fat pixels a character is.

The panel and the HUD are two halves of one thing and have to agree. The panel
is drawn once and never redrawn; the score, the high score and the lives are
the only parts that move, and the runtime pokes HUD glyphs into fixed cells of
it (`hud_cell_lo/hi` in src/bank3.asm): the score at row 1 columns 7-12, the
high score at row 1 columns 27-32, the lives at row 2 columns 17-22. Those
cells must be left free in the panel art, and a digit painted in the HUD sheet
has to sit on whatever background the panel puts behind it.

Frame and character NUMBERS are the C64's and are not ours to change: the tile
table, the map, col_decode, the wave table and sprite_dp_dcd all index into
them, and the CPC port renumbered nothing either. Repainting a cell repaints
every use of it.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import palette  # noqa: E402

ART = os.path.join("assets", "art")
SX, SY = 2, 1                     # image pixels per fat pixel

CHARS_PNG = os.path.join(ART, "chars.png")
SPRITES_PNG = os.path.join(ART, "sprites.png")
PANEL_PNG = os.path.join(ART, "panel.png")
HUD_PNG = os.path.join(ART, "hud.png")


class Sheet:
    """One sheet's geometry: a grid of cells, each a block of fat pixels."""

    def __init__(self, path, count, slots, per_row, wide, high, transparent):
        self.path = path
        self.count = count            # cells the game reads
        self.slots = slots            # cells the sheet has room for
        self.per_row = per_row
        self.wide = wide              # fat pixels across a cell
        self.high = high              # rows down a cell
        self.transparent = transparent
        self.rows = (slots + per_row - 1) // per_row

    @property
    def size(self):
        return (self.per_row * self.wide * SX, self.rows * self.high * SY)

    def origin(self, n):
        return ((n % self.per_row) * self.wide * SX,
                (n // self.per_row) * self.high * SY)


CHARS = Sheet(CHARS_PNG, 256, 256, 16, 4, 8, transparent=False)
SPRITES = Sheet(SPRITES_PNG, 119, 128, 8, 12, 21, transparent=True)
PANEL = Sheet(PANEL_PNG, 200, 200, 40, 4, 8, transparent=False)
HUD = Sheet(HUD_PNG, 13, 16, 16, 4, 8, transparent=False)

ALL = (CHARS, SPRITES, PANEL, HUD)


def pack_cell(cell):
    """One 4-fat-pixel-by-8-row cell as the sixteen bytes panel.bin, hud.bin
    and the runtime all use: byte column 0's eight scanlines, then column 1's.
    Our byte columns are eight bytes apart and consecutive, so a cell is
    sixteen contiguous bytes of screen."""
    import bbc
    return bytes(bbc.mode2_byte(cell[y][bc * 2], cell[y][bc * 2 + 1])
                 for bc in (0, 1) for y in range(8))


def read(sheet, pal=None, strict=True):
    """The sheet as `count` cells of `high` rows of `wide` logical colours.

    A cell drawn entirely in the not-yet-drawn key comes back as None, so the
    caller can fall back to the mechanical conversion for it (partial drops).
    With strict=False, unknown colours are reported rather than raised.
    """
    pal = palette.load() if pal is None else pal
    lut = palette.lookup(pal, sprite=sheet.transparent)
    im = Image.open(sheet.path).convert("RGB")
    if im.size != sheet.size:
        raise SystemExit(f"{sheet.path}: expected {sheet.size[0]}x{sheet.size[1]}, "
                         f"got {im.size[0]}x{im.size[1]}")
    px = im.load()
    cells, errors = [], []
    for n in range(sheet.count):
        ox, oy = sheet.origin(n)
        rows, blanks, drawn = [], 0, 0
        for y in range(sheet.high):
            row = []
            for x in range(sheet.wide):
                block = {px[ox + x * SX + dx, oy + y * SY + dy]
                         for dx in range(SX) for dy in range(SY)}
                if len(block) != 1:
                    errors.append((sheet.path, n, x, y,
                                   f"fat pixel is not one colour: {sorted(block)}"))
                    rgb = sorted(block)[0]
                else:
                    rgb = block.pop()
                if rgb == palette.KEY_FALLBACK:
                    blanks += 1
                    row.append(0)
                    continue
                drawn += 1
                if rgb == palette.KEY_TRANSPARENT:
                    if not sheet.transparent:
                        errors.append((sheet.path, n, x, y,
                                       "the transparency key is not legal on this sheet"))
                    row.append(0)
                elif rgb in lut:
                    row.append(lut[rgb])
                else:
                    errors.append((sheet.path, n, x, y,
                                   f"{rgb} is not in the palette"))
                    row.append(0)
            rows.append(row)
        if drawn == 0:
            cells.append(None)                    # not drawn yet
        else:
            if blanks:
                errors.append((sheet.path, n, -1, -1,
                               f"{blanks} pixels of the not-yet-drawn key in a cell "
                               "that is otherwise painted: a fallback cell must be "
                               "the key and nothing else"))
            cells.append(rows)
    if errors and strict:
        for path, n, x, y, msg in errors[:40]:
            where = f"cell {n}" + (f" pixel ({x},{y})" if x >= 0 else "")
            print(f"{path}: {where}: {msg}", file=sys.stderr)
        raise SystemExit(f"{sheet.path}: {len(errors)} error(s)")
    return (cells, errors) if not strict else cells


def write(sheet, cells, pal, path=None):
    """Cells of logical colours out to a PNG in the sheet's own format.
    A None cell is written in the not-yet-drawn key."""
    path = path or sheet.path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fill = palette.KEY_TRANSPARENT if sheet.transparent else (0, 0, 0)
    im = Image.new("RGB", sheet.size, fill)
    px = im.load()
    for n, rows in enumerate(cells[:sheet.count]):
        ox, oy = sheet.origin(n)
        for y in range(sheet.high):
            for x in range(sheet.wide):
                if rows is None:
                    rgb = palette.KEY_FALLBACK
                elif sheet.transparent and rows[y][x] == 0:
                    rgb = palette.KEY_TRANSPARENT
                else:
                    rgb = tuple(pal[rows[y][x]])
                for dy in range(SY):
                    for dx in range(SX):
                        px[ox + x * SX + dx, oy + y * SY + dy] = rgb
    im.save(path)
    return path
