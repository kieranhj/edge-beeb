"""paint_map.py - paint the level itself, and import the painting back into
assets/art/chars-bbc.png.

  python tools/paint_map.py export            the whole level, 302 tile columns
  python tools/paint_map.py export 40 60      tile columns 40-59 only
  python tools/paint_map.py import assets/art/map/map_c040-c059.png

  python tools/paint_map.py export --c64      the original, at C64 colours
  python tools/paint_map.py export --cpc      the Amstrad port, at CPC pens
  python tools/paint_map.py export --grid     and a guide layer beside it

`chars-bbc.png` is 256 characters on a grid and is the right thing to EXPORT to the
machine; it is a poor thing to paint on, because a character is 4 fat pixels by
8 rows and means nothing on its own. This is the other direction: the assembled
level as one picture, painted in place, read back into the same 256 characters.

The tile table, the map and the character NUMBERS are untouched - they are the
C64's and are shared with the CPC port (decision 3, decision 58). All this tool
moves is the 8K of character bitmaps. That is what makes it safe: the character
budget cannot be overrun, because there is nowhere for a 257th character to go
and the importer never tries to make one. The artist paints; the picture stays
buildable by construction.

The consequence, and the whole thing the artist has to hold in his head:

  REPAINTING A CHARACTER REPAINTS EVERY USE OF IT. The 232 non-blank characters
  are placed 9,356 times across the level - a reuse factor of forty - so one
  edit lands in about forty places, most of them off the canvas being painted.

Which is why the importer's real work is not reading pixels but reconciling
them. Every instance of a character on the canvas is a vote on what that
character should look like:

  * an instance identical to what it was is not a vote at all;
  * one changed instance wins, however many unchanged ones sit beside it - that
    is "paint one arch and leave its twin alone", which is the normal way to
    work;
  * two instances changed to two DIFFERENT things is a genuine conflict, and it
    is refused with the map columns and rows of both, because there is no
    honest way to choose. Fix one to match the other, or take --vote and let
    the majority have it.

A cell painted entirely in the not-yet-drawn key resets that character to
undrawn, exactly as it means on the sheets: it will fall back to the mechanical
conversion until it is painted again.

Two warnings the canvas can give that chars-bbc.png cannot, both mechanics that
live in the art:

  * BLANK CHARACTERS ARE THE STARFIELD. src/bank1.asm plots a star only where
    the play buffer byte reads exactly zero, so ink added to an all-black
    character puts scenery where stars used to be. Named, per character.
  * COLLISION IS NOT PAINTABLE. It is bit 4 of col_decode per character number
    (docs/layer-1-graphics-pipeline.md), so a fatal character repainted to look
    like empty space is just as fatal, and a harmless one repainted to look
    solid is still flown through. Both directions are named.

--c64 and --cpc are the same level assembled from the same tile table and the
same map, but drawn with the ORIGINALS' charsets at the originals' own colours
- the C64's sixteen through the Pepto palette, the Amstrad's twenty-seven pens
- rather than through decision 11's hue collapse or decision 55's dither. They
go to tools/output/ rather than assets/art/map/ and `import` will not read them
back, because sixteen colours are not eight: they are a REFERENCE, what the
artist is working from, at the same size and the same 2:1 aspect as the canvas
so the two can be laid side by side. tools/art/nula.py is where the source
colours come from, the NuLA builds needing exactly the same thing.

--grid writes a second file beside whichever picture was asked for: a
transparent overlay the same size, with the character grid dotted, the tile
grid solid and the tile column number every four columns. It is a LAYER, put
over the canvas in the paint program and turned off to paint, because anything
drawn INTO the picture would be read straight back as art - and `import`
refuses a file with an alpha channel outright for that reason. It is the one
thing the artist cannot see for himself and needs constantly: reuse follows the
tile boundaries, so where a tile begins is where an edit stops travelling.

Colour rules are the sheets' rules and are not relaxed here: every pixel is
EXACTLY a palette entry or the not-yet-drawn key, every fat pixel is a solid
2 x 1 block, and an unknown colour is an error with coordinates rather than a
nearest match. See tools/art/palette.py.

Run from the project root.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import bbc         # noqa: E402
import guide as art_guide  # noqa: E402
import mechanical  # noqa: E402
import palette     # noqa: E402
import pngart      # noqa: E402
import sheets      # noqa: E402

OUT = os.path.join("assets", "art", "map")
REFERENCE = os.path.join("tools", "output")

SX, SY = sheets.SX, sheets.SY      # image pixels per fat pixel: 2 x 1
CW, CH = 4, 8                      # a character: 4 fat pixels by 8 rows
TILE = 4                           # a tile: 4 x 4 characters
ROWS = bbc.MAP_ROWS                # 5 tile rows
CHAR_ROWS = ROWS * TILE            # 20 character rows


# --- the level as characters ---------------------------------------------

def char_grid(a, b, tiles, mapdata):
    """Tile columns a..b as a grid of character numbers, 20 rows deep."""
    grid = [[0] * ((b - a) * TILE) for _ in range(CHAR_ROWS)]
    for col in range(a, b):
        for row in range(ROWS):
            tile = tiles[mapdata[col][row]]
            for ty in range(TILE):
                for tx in range(TILE):
                    grid[row * TILE + ty][(col - a) * TILE + tx] = tile[ty * TILE + tx]
    return grid


def current_characters():
    """The 256 characters as they stand: the artist's sheet where it is
    painted, the mechanical conversion where it is not. `drawn` says which is
    which, so an untouched fallback cell stays a fallback cell on the way out."""
    fallback = mechanical.characters()
    if not pngart.available():
        print("assets/art is not seeded; using the C64 conversion "
              "(tools/seed_art.py writes the sheets)")
        return fallback, [False] * bbc.CHAR_COUNT
    raw = sheets.read(sheets.CHARS)
    drawn = [c is not None for c in raw]
    return [c if c is not None else f for c, f in zip(raw, fallback)], drawn



# --- the guide layer ------------------------------------------------------

def guide(a, b):
    """A transparent overlay the size of the canvas: the character grid dotted,
    the tile grid solid, and the tile column number every four columns.

    A LAYER, not a canvas. It is drawn beside the picture rather than into it
    because anything drawn into the picture would be read back as art - and
    `import` refuses a file with any transparency for the same reason."""
    im, px, size = art_guide.new((b - a) * TILE * CW * SX, CHAR_ROWS * CH * SY)
    for cx in range((b - a) * TILE + 1):
        art_guide.vrule(px, size, cx * CW * SX, art_guide.MINOR, dotted=True)
    for cy in range(CHAR_ROWS + 1):
        art_guide.hrule(px, size, cy * CH * SY, art_guide.MINOR, dotted=True)
    for col in range(a, b + 1):
        art_guide.vrule(px, size, (col - a) * TILE * CW * SX, art_guide.MAJOR)
    for row in range(ROWS + 1):
        art_guide.hrule(px, size, row * TILE * CH * SY, art_guide.MAJOR)

    for col in range(a, b):
        if col % 4 == 0 or col == a:
            art_guide.text(px, size, (col - a) * TILE * CW * SX + 2, 2,
                           str(col), scale_x=SX)
    return im


# --- export ---------------------------------------------------------------

def render(grid, chars, pal):
    """The character grid as an RGB image at 2:1. `chars` is cells of rows of
    indices into `pal`, which is the artist's palette or an original's."""
    wide = len(grid[0]) * CW                         # fat pixels across
    lut = [bytes(rgb) * SX for rgb in pal]           # one index -> SX pixels
    data = bytearray()
    for y in range(len(grid) * CH):
        row = grid[y // CH]
        line = bytearray()
        for cx in range(len(row)):
            cell = chars[row[cx]][y % CH]
            for x in range(CW):
                line += lut[cell[x]]
        data += line * SY
    return Image.frombytes("RGB", (wide * SX, len(grid) * CH * SY), bytes(data))


def export(a, b, source=None, want_guide=False):
    """source None is the artist's own sheets, painted on and imported back.
    "c64" and "cpc" are the two originals at their OWN colours - sixteen of
    them, so neither is a canvas: they are what the artist is copying from."""
    tiles, mapdata = bbc.load_tiles(), bbc.load_map()
    b = min(b, len(mapdata))
    if not 0 <= a < b:
        raise SystemExit(f"tile columns {a}..{b} are not a range of "
                         f"0..{len(mapdata)}")
    grid = char_grid(a, b, tiles, mapdata)

    if source is None:
        pal = (palette.load() if os.path.exists(palette.PALETTE_PNG)
               else palette.SEED)
        chars, _ = current_characters()
        directory, suffix = OUT, ""
    else:
        import nula                       # the two originals at source colours
        cpc = source == "cpc"
        pal, chars = nula.palette(cpc), nula.characters(cpc)
        directory, suffix = REFERENCE, f"-{source}"

    os.makedirs(directory, exist_ok=True)
    path = os.path.join(directory, f"map_c{a:03d}-c{b - 1:03d}{suffix}.png")
    img = render(grid, chars, pal)
    img.save(path)

    used = sorted({n for row in grid for n in row})
    placements = len(grid) * len(grid[0])
    print(f"{path} {img.size[0]}x{img.size[1]} "
          f"({b - a} tile columns, {img.size[0] // SX} fat pixels)")
    print(f"  {placements} character cells drawn from {len(used)} of the "
          f"{bbc.CHAR_COUNT} characters - reuse factor "
          f"{placements / len(used):.1f}")
    missing = [n for n in range(bbc.CHAR_COUNT) if n not in used]
    if missing:
        print(f"  {len(missing)} characters do not appear here"
              + ("" if source else " and cannot be painted on this canvas")
              + f": {compact(missing)}")
    if want_guide:
        gpath = os.path.join(directory,
                             f"map_c{a:03d}-c{b - 1:03d}{suffix}-grid.png")
        guide(a, b).save(gpath)
        print(f"{gpath} the guide LAYER: character grid dotted, tile grid "
              "solid, tile column numbers every four")
        print("  put it over the canvas as its own layer and turn it off to "
              "paint; import refuses it, alpha channel and all")

    if source:
        inks = sorted({v for n in used for row in chars[n] for v in row})
        print(f"  {len(inks)} of the {source.upper()} colours "
              f"appear here: {inks}")
        print("  a REFERENCE, not a canvas: these are sixteen colours and "
              "MODE 2 has eight, so import will not read it back")
    else:
        print(f"  paint it, then: python tools/paint_map.py import {path}")
    return path


def compact(ns, limit=12):
    """A list of character numbers, as runs, truncated."""
    runs, start, prev = [], None, None
    for n in list(ns) + [None]:
        if prev is not None and n == prev + 1:
            prev = n
            continue
        if start is not None:
            runs.append(f"{start}" if start == prev else f"{start}-{prev}")
        start = prev = n
    return ", ".join(runs[:limit]) + (" ..." if len(runs) > limit else "")


# --- import ---------------------------------------------------------------

def refuse_guide(path):
    """The guide layer is transparent everywhere it is not a line, so an alpha
    channel is proof this is not a painted canvas. Checked before anything
    else, the guide's own filename being the likeliest way to arrive here."""
    im = Image.open(path)
    if im.mode not in ("RGBA", "LA", "P"):
        return
    if im.convert("RGBA").getchannel("A").getextrema()[0] == 255:
        return
    raise SystemExit(f"{path}: this has an alpha channel, so it is the guide "
                     "LAYER (--grid) and not a painted canvas. Turn the guide "
                     "layer off and export the picture underneath it.")


def read_canvas(path, wide, high, pal):
    """The painted PNG as `high` rows of `wide` logical colours, with the
    not-yet-drawn key coming back as None. Errors carry fat-pixel coordinates."""
    im = Image.open(path).convert("RGB")
    if im.size != (wide * SX, high * SY):
        raise SystemExit(f"{path}: expected {wide * SX}x{high * SY} for this "
                         f"tile range, got {im.size[0]}x{im.size[1]}")
    lut = palette.lookup(pal, sheets.CHARS.allowed)
    raw = im.tobytes()
    stride = wide * SX * 3
    out, errors = [], []
    for y in range(high):
        base = y * SY * stride
        row = []
        for x in range(wide):
            o = base + x * SX * 3
            block = {raw[o + i * 3:o + i * 3 + 3] for i in range(SX)}
            if SY > 1:
                block |= {raw[o + dy * stride + i * 3:o + dy * stride + i * 3 + 3]
                          for dy in range(1, SY) for i in range(SX)}
            if len(block) != 1:
                errors.append((x, y, "fat pixel is not one colour: "
                               f"{sorted(tuple(v) for v in block)}"))
            rgb = tuple(sorted(block)[0])
            if rgb == palette.KEY_FALLBACK:
                row.append(None)
            elif rgb == palette.KEY_TRANSPARENT:
                errors.append((x, y, "the transparency key is not legal here: "
                               "the background is opaque"))
                row.append(0)
            elif rgb in lut:
                row.append(lut[rgb])
            else:
                errors.append((x, y, f"{rgb} is not in the palette"))
                row.append(0)
        out.append(row)
    return out, errors


def cell_at(canvas, cx, cy):
    """One character-shaped cell, or None if it is entirely the not-yet-drawn
    key. A cell that is part key and part paint is an error, as on the sheets."""
    rows, keys = [], 0
    for y in range(CH):
        line = canvas[cy * CH + y][cx * CW:(cx + 1) * CW]
        keys += sum(1 for v in line if v is None)
        rows.append([0 if v is None else v for v in line])
    if keys == CW * CH:
        return None
    if keys:
        raise ValueError(f"{keys} pixels of the not-yet-drawn key in a cell "
                         "that is otherwise painted: a fallback cell must be "
                         "the key and nothing else")
    return rows


def range_from_name(path):
    stem = os.path.basename(path).rsplit(".", 1)[0]
    try:
        a, b = stem.split("_")[-1].split("-")
        return int(a[1:]), int(b[1:]) + 1
    except (ValueError, IndexError):
        raise SystemExit(
            f"{path}: cannot read a tile-column range from the name. Keep the "
            "name export gave it (map_c040-c059.png), or pass the range: "
            "paint_map.py import <png> <first> <last+1>")


def do_import(path, a=None, b=None, vote=False, dry_run=False):
    refuse_guide(path)
    tiles, mapdata = bbc.load_tiles(), bbc.load_map()
    if a is None:
        a, b = range_from_name(path)
    b = min(b, len(mapdata))
    if not 0 <= a < b:
        raise SystemExit(f"tile columns {a}..{b} are not a range of "
                         f"0..{len(mapdata)}")
    pal = palette.load()
    before, drawn = current_characters()
    grid = char_grid(a, b, tiles, mapdata)

    canvas, errors = read_canvas(path, (b - a) * TILE * CW, CHAR_ROWS * CH, pal)
    for x, y, msg in errors[:40]:
        print(f"{path}: fat pixel ({x},{y}) "
              f"[map column {a + x // (TILE * CW)}, character row {y // CH}]: "
              f"{msg}", file=sys.stderr)
    if len(errors) > 40:
        print(f"  ... and {len(errors) - 40} more", file=sys.stderr)
    if errors:
        raise SystemExit(f"{path}: {len(errors)} error(s) - nothing imported")

    # Every instance of a character is a vote. An instance that matches what
    # the character already is abstains; that is what lets one edited arch
    # outvote its untouched twin without the tool having to guess.
    votes = {}
    for cy in range(CHAR_ROWS):
        for cx in range((b - a) * TILE):
            n = grid[cy][cx]
            try:
                cell = cell_at(canvas, cx, cy)
            except ValueError as exc:
                raise SystemExit(f"{path}: map column {a + cx // TILE}, tile "
                                 f"row {cy // TILE}, character {n}: {exc}")
            if cell is None:
                if not drawn[n]:
                    continue                       # undrawn and left undrawn
                key = None
            else:
                if cell == before[n] and drawn[n]:
                    continue                       # unchanged
                if cell == before[n] and not drawn[n]:
                    continue                       # still the fallback shape
                key = tuple(tuple(r) for r in cell)
            votes.setdefault(n, {}).setdefault(key, []).append(
                (a + cx // TILE, cy // TILE, cx % TILE, cy % TILE))

    conflicts = {n: v for n, v in votes.items() if len(v) > 1}
    if conflicts and not vote:
        for n in sorted(conflicts)[:20]:
            print(f"{path}: character {n} is painted "
                  f"{len(conflicts[n])} different ways:", file=sys.stderr)
            for k, where in sorted(conflicts[n].items(),
                                   key=lambda kv: -len(kv[1]))[:4]:
                col, row, tx, ty = where[0]
                print(f"    {len(where):4d} x  {sketch(k)}   first at map "
                      f"column {col}, tile row {row}, character ({tx},{ty})",
                      file=sys.stderr)
        if len(conflicts) > 20:
            print(f"  ... and {len(conflicts) - 20} more", file=sys.stderr)
        raise SystemExit(
            f"{path}: {len(conflicts)} character(s) painted two ways - nothing "
            "imported. Make the instances agree, or re-run with --vote to let "
            "the majority win.")

    ties = [n for n, v in conflicts.items()
            if sorted(len(w) for w in v.values())[-2:][0]
            == max(len(w) for w in v.values())]

    after, after_drawn = list(before), list(drawn)
    fallback = mechanical.characters()
    for n, variants in votes.items():
        key = max(variants, key=lambda k: len(variants[k]))
        if key is None:
            after[n], after_drawn[n] = fallback[n], False
        else:
            after[n], after_drawn[n] = [list(r) for r in key], True
    report(before, after, drawn, after_drawn, votes, conflicts, ties, grid)

    if dry_run:
        print("\n--dry-run: assets/art/chars-bbc.png not written")
        return
    cells = [c if d else None for c, d in zip(after, after_drawn)]
    print("\n" + sheets.write(sheets.CHARS, cells, pal) + " written")
    print("Now: python tools/validate_art.py && python tools/export_tiles.py")


def report(before, after, drawn, after_drawn, votes, conflicts, ties, grid):
    changed = [n for n in range(bbc.CHAR_COUNT) if after[n] != before[n]
               or after_drawn[n] != drawn[n]]
    placements = {}
    for row in grid:
        for n in row:
            placements[n] = placements.get(n, 0) + 1
    total = sum(placements.get(n, 0) for n in changed)
    print(f"{len(changed)} character(s) changed, {total} placements on this "
          f"canvas alone")
    if conflicts:
        print(f"  --vote resolved {len(conflicts)} conflict(s) by majority")
        if ties:
            print(f"  {len(ties)} of them had NO majority and were decided by "
                  f"reading order - look at these yourself: {compact(sorted(ties))}")

    full = bbc.load_map()
    everywhere = {}
    tiles = bbc.load_tiles()
    for col in full:
        for t in col:
            for n in tiles[t]:
                everywhere[n] = everywhere.get(n, 0) + 1
    off = sum(everywhere.get(n, 0) for n in changed) - total
    if off:
        print(f"  and {off} placements elsewhere in the level, which is the "
              "point and is easy to forget")

    def blank(cell):
        return not any(v for row in cell for v in row)

    lost = [n for n in changed if blank(before[n]) and not blank(after[n])]
    gained = [n for n in changed if not blank(before[n]) and blank(after[n])]
    if lost:
        print(f"  STARFIELD: {len(lost)} all-black character(s) now carry ink, "
              f"so stars stop appearing there: {compact(lost)}")
    if gained:
        print(f"  STARFIELD: {len(gained)} character(s) went all-black and "
              f"will now show stars: {compact(gained)}")

    col_decode = open("src/data/col_decode.bin", "rb").read()
    fatal = [n for n in changed if col_decode[n] & 0x10]
    looks_empty = [n for n in fatal if blank(after[n])]
    harmless_ink = [n for n in changed
                    if not col_decode[n] & 0x10 and blank(before[n])
                    and not blank(after[n])]
    if looks_empty:
        print(f"  COLLISION: {len(looks_empty)} character(s) are fatal and are "
              f"now all black - they will look like empty space and still kill: "
              f"{compact(looks_empty)}")
    if harmless_ink:
        print(f"  COLLISION: {len(harmless_ink)} character(s) are not fatal and "
              f"are now painted - they will look solid and be flown through: "
              f"{compact(harmless_ink)}")


def main(argv):
    flags = {v for v in argv if v.startswith("--")}
    args = [v for v in argv if not v.startswith("--")]
    what = args[0] if args else "export"
    nums = [int(v) for v in args[1:] if v.lstrip("-").isdigit()]
    if what == "export":
        source = "cpc" if "--cpc" in flags else "c64" if "--c64" in flags else None
        export(nums[0] if nums else 0,
               nums[1] if len(nums) > 1 else len(bbc.load_map()), source,
               "--grid" in flags)
    elif what == "import":
        paths = [v for v in args[1:] if not v.lstrip("-").isdigit()]
        if not paths:
            raise SystemExit("import needs a PNG: paint_map.py import <png>")
        do_import(paths[0],
                  nums[0] if nums else None,
                  nums[1] if len(nums) > 1 else None,
                  vote="--vote" in flags, dry_run="--dry-run" in flags)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
