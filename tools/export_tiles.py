"""export_tiles.py - C64 charset -> MODE 2 column planes, plus the tables the
game reads verbatim.

Writes to src/data/:
  chars.bin      8192 B  four planes of 256 chars x 8 rows. Plane p holds pixel
                         column p of every character as a MODE 2 byte with the
                         colour in the RIGHT pixel position (bits 6,4,2,0) and
                         the left pixel clear, which is exactly what the column
                         buffer ORs in after its shift. Address of a byte is
                         plane*2048 + char*8 + row.
  tiles.bin      3376 B  the C64 tile definitions, unchanged (211 x 16, row-major)
  map.bin        1510 B  tiles.map + tiles2.map concatenated (302 columns x 5)
  col_decode.bin  256 B  the C64 col_decode table (low 3 bits colour, bit 4 fatal)

Colours: bit pair 00 -> black, 01 -> brown ($d022), 10 -> white ($d023),
11 -> col_decode low 3 bits; each then through C64_TO_BBC (decision 11).

The charset comes from assets/art/chars.png (Layer 8): the artist paints there
and the exporter resolves every pixel through assets/art/palette.png. A
character he has not drawn yet falls back to the C64 mechanical conversion, so
a partial drop still builds a complete game. --c64 bypasses the PNGs and takes
the mechanical conversion outright, which is what the sheets were seeded from
and therefore produces the same bytes.

With --cpc (decision 41) the charset comes from the Amstrad port's art instead
and is written to chars-cpc.bin; a CPC character carries its own colours, so
col_decode's colour bits are not consulted at all. tiles.bin, map.bin and
col_decode.bin are NOT rewritten - the CPC uses the same tile numbers, the same
map and the same collision table, so all three builds share the one copy, and
repainting a character repaints every tile that uses it.

--nula (decision 63) writes chars-nula.bin instead: the same characters at
the SOURCE palette rather than MODE 2's eight, for the VideoNuLA test builds.
It bypasses the PNG sheets entirely - a NuLA build is the original artwork at
the colours it was drawn for, not the artist's work - and with --cpc it also
drops decision 55's dither, a pen being one colour again.

Run from the project root:
    python tools/export_tiles.py [--cpc] [--c64 | --nula]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import bbc          # noqa: E402
import mechanical   # noqa: E402
import nula         # noqa: E402
import pngart       # noqa: E402

OUT = "src/data"
C64_ASM = "source_c64/edge_grinder.asm"


def main(cpc=False, c64=False, use_nula=False):
    os.makedirs(OUT, exist_ok=True)
    if use_nula:
        pixels = nula.characters(cpc=cpc)
    elif cpc:
        pixels = mechanical.characters(cpc=True)
    elif c64:
        pixels = mechanical.characters()
    else:
        pixels = pngart.characters(fallback=mechanical.characters())

    planes = bytearray(4 * 2048)
    for c, px in enumerate(pixels):
        for row in range(8):
            for p in range(4):
                planes[p * 2048 + c * 8 + row] = bbc.mode2_byte(0, px[row][p])
    name = "chars%s%s.bin" % ("-nula" if use_nula else "",
                              "-cpc" if cpc else "")
    open(f"{OUT}/{name}", "wb").write(planes)
    if cpc or use_nula:
        print(f"{name} {len(planes)} B "
              "(tiles/map/col_decode unchanged - the same numbers in every build)")
        return

    col_decode = bbc.parse_c64_table(C64_ASM, "col_decode", 256)

    tiles = open("data/tiles.til.bin", "rb").read()
    open(f"{OUT}/tiles.bin", "wb").write(tiles)

    m = open("data/tiles.map.bin", "rb").read() + open("data/tiles2.map.bin", "rb").read()
    open(f"{OUT}/map.bin", "wb").write(m)

    open(f"{OUT}/col_decode.bin", "wb").write(bytes(col_decode))

    used = sorted({cd & 7 for cd in col_decode})
    print(f"chars.bin {len(planes)} B, tiles.bin {len(tiles)} B, map.bin {len(m)} B "
          f"({len(m) // 5} columns), col_decode.bin 256 B")
    print("per-char C64 colours used:", used)


if __name__ == "__main__":
    main(cpc="--cpc" in sys.argv[1:], c64="--c64" in sys.argv[1:],
         use_nula="--nula" in sys.argv[1:])
