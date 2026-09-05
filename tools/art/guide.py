"""guide.py - the guide layer: a transparent overlay the same size as a piece
of art, carrying the grid the artist cannot see and the numbers he needs.

One module because there are two callers and they want the same thing at two
scales: tools/paint_map.py draws the character and tile grid over the level,
tools/art_grid.py draws the cell grid over the five sheets in assets/art.

It is always a SEPARATE FILE and never drawn into the picture. The picture is
read back as art, so a line drawn into it becomes art; a layer is turned off to
paint and turned on to look. Both importers refuse a file with any
transparency in it for exactly that reason.

Three things learned by building it wrong and looking at it:

  * solid against dotted separates two grids at one pixel where two alphas do
    not. The heavier grid is solid;
  * a number on artwork needs its own dark halo. The first ruler was white
    numerals on the top of the level, which is as often bright scenery as it is
    sky, and they were invisible;
  * and a number only belongs where the cell has room to spare for it. A
    character cell is 8 image pixels across; `FF` is 7 of them. Every fourth
    grid line brighter is a ruler that costs no pixels at all, and counting
    four at a time to the cell you want is quicker than reading a numeral that
    has buried the art underneath it.
"""

# A 3 x 5 digit. The tool's own, deliberately not the game's HUD font, which is
# the artist's to repaint and may stop being legible at any time.
GLYPHS = {
    "0": "###/#.#/#.#/#.#/###", "1": "..#/..#/..#/..#/..#",
    "2": "###/..#/###/#../###", "3": "###/..#/###/..#/###",
    "4": "#.#/#.#/###/..#/..#", "5": "###/#../###/..#/###",
    "6": "###/#../###/#.#/###", "7": "###/..#/..#/..#/..#",
    "8": "###/#.#/###/#.#/###", "9": "###/#.#/###/..#/###",
    "A": "###/#.#/###/#.#/#.#", "B": "##./#.#/##./#.#/##.",
    "C": "###/#../#../#../###", "D": "##./#.#/#.#/#.#/##.",
    "E": "###/#../###/#../###", "F": "###/#../###/#../#..",
    "$": ".#./###/##./.##/###",
}
GLYPH_W, GLYPH_H = 3, 5

MINOR = (255, 255, 255, 44)      # dotted: the finer grid
MAJOR = (255, 255, 255, 120)     # solid: the coarser one
EVERY4 = (255, 255, 255, 225)    # solid and bright: every fourth of those
LABEL = (255, 255, 255, 230)
HALO = (0, 0, 0, 230)


def text_width(text, scale_x):
    return (len(text) * (GLYPH_W + 1) - 1) * scale_x


def text(px, size, x0, y0, s, scale_x=1):
    """`s` at (x0, y0), each pixel `scale_x` wide so the label is in proportion
    with a 2:1 picture, haloed so it reads on anything."""
    w, h = size
    ink = set()
    x = x0
    for ch in s:
        for r, line in enumerate(GLYPHS[ch].split("/")):
            for c, v in enumerate(line):
                if v == "#":
                    ink |= {(x + c * scale_x + dx, y0 + r)
                            for dx in range(scale_x)}
        x += (GLYPH_W + 1) * scale_x
    halo = {(x + dx, y + dy) for x, y in ink
            for dx in (-1, 0, 1) for dy in (-1, 0, 1)} - ink
    for x, y in halo:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = HALO
    for x, y in ink:
        if 0 <= x < w and 0 <= y < h:
            px[x, y] = LABEL


def vrule(px, size, x, colour, dotted=False):
    w, h = size
    x = min(x, w - 1)
    for y in range(0, h, 2 if dotted else 1):
        px[x, y] = colour


def hrule(px, size, y, colour, dotted=False):
    w, h = size
    y = min(y, h - 1)
    for x in range(0, w, 2 if dotted else 1):
        px[x, y] = colour


def new(width, height):
    from PIL import Image
    im = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    return im, im.load(), (width, height)
