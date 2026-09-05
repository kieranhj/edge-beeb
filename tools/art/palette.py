"""palette.py - the game palette as a file, and the mapping between the RGB an
artist paints and the MODE 2 logical colour the hardware shows.

`assets/art/palette.png` is the authoritative palette: 16 pixels wide, 1 tall,
pixel n being the RGB of MODE 2 logical colour n. Everything that reads the
artist's sheets resolves colour through this file and nothing else - an RGB
that is not in it is an error with coordinates, never a nearest match.

Today entries 0-7 are the eight BBC colours, 8 is a second black (the sprite
engine's, because logical 0 is its transparency key) and 9-15 alias 1-7, which
is exactly what setup_display's old palette loop did. That aliasing is why the
RGB -> logical direction needs a rule:

  * background art takes the LOWEST index with that RGB, so black is 0 and the
    starfield still sees an empty byte as empty (src/bank1.asm plots a star
    only where the buffer byte reads exactly 0);
  * sprite art takes the lowest index ABOVE 0, so black inside a sprite is 8
    and is drawn rather than seen through.

Under NULA the sixteen entries stop aliasing and become sixteen free 12-bit
colours; both rules still hold, index 0 stays the transparency key, and the
only thing that changes here is that `write_asm` emits &FE23 pairs instead of
&FE21 bytes. Nothing in the exported data formats changes at all: chars.bin and
the sprite banks already store a full 4-bit logical per fat pixel.
"""

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import bbc  # noqa: E402

PALETTE_PNG = os.path.join("assets", "art", "palette.png")
ENTRIES = 16

# Not colours. The grey is the sheets' transparency key and is already what
# reference/sprite-sheet.png uses; the orange marks a cell the artist has not
# done yet, which falls back to the mechanical conversion (partial drops).
KEY_TRANSPARENT = (96, 96, 96)
KEY_FALLBACK = (255, 128, 0)
RESERVED = {KEY_TRANSPARENT: "transparency key", KEY_FALLBACK: "not-yet-drawn key"}

# The palette the mechanical conversion has always run under, and what
# seed_art.py writes if there is no palette.png yet: logical n -> physical n
# for 0-7, then 8 as a second black and 9-15 aliasing 1-7.
SEED = [bbc.BBC_RGB[n] for n in range(8)] + [bbc.BBC_RGB[0]] + \
       [bbc.BBC_RGB[n] for n in range(1, 8)]


def load(path=PALETTE_PNG):
    """The sixteen entries as RGB triples."""
    im = Image.open(path).convert("RGB")
    if im.size != (ENTRIES, 1):
        raise SystemExit(f"{path}: expected {ENTRIES}x1, got {im.size[0]}x{im.size[1]}")
    pal = [im.getpixel((n, 0)) for n in range(ENTRIES)]
    for n, rgb in enumerate(pal):
        if rgb in RESERVED:
            raise SystemExit(f"{path}: entry {n} is the {RESERVED[rgb]} {rgb}, "
                             "which may not be a palette colour")
    return pal


def save(pal, path=PALETTE_PNG):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = Image.new("RGB", (ENTRIES, 1))
    for n, rgb in enumerate(pal):
        im.putpixel((n, 0), tuple(rgb))
    im.save(path)


def lookup(pal, sprite=False):
    """RGB -> logical colour. See the module docstring for the two rules."""
    out = {}
    for n in reversed(range(ENTRIES)):        # lowest index wins
        if sprite and n == 0:
            continue                          # 0 is the transparency key
        out[tuple(pal[n])] = n
    return out


def is_mode2(pal):
    """True if this palette is legal without a NULA: every entry one of the
    eight BBC colours, and 8-15 aliasing 0-7 so the &FE21 write is meaningful."""
    return all(tuple(c) in [tuple(v) for v in bbc.BBC_RGB] for c in pal)


def gpl(pal, name="Edge Grinder"):
    lines = ["GIMP Palette", f"Name: {name}", "Columns: 8", "#"]
    for n, (r, g, b) in enumerate(pal):
        lines.append(f"{r:3d} {g:3d} {b:3d}\tlogical {n}")
    for rgb, what in RESERVED.items():
        lines.append(f"{rgb[0]:3d} {rgb[1]:3d} {rgb[2]:3d}\t{what} (NOT a colour)")
    return "\n".join(lines) + "\n"


def act(pal):
    """Adobe colour table: 256 RGB triples, which Aseprite and GIMP both read."""
    out = bytearray()
    for r, g, b in pal:
        out += bytes((r, g, b))
    return bytes(out) + bytes(3 * (256 - ENTRIES))
