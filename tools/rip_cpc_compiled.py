"""rip_cpc_compiled.py - the Amstrad's COMPILED sprite bodies read back into
frames, and the player's grind sparks in particular.

Most of the CPC's art is data in SPRITES.BIN and comes out through
tools/rip_cpc_sprites.py. Three sets are not: the player, the laser and the
player's GRIND frames exist only as compiled Z80 in
source_cpc/Source/EG_Sprites_Player*.asm and EG_Sprites_Laser.asm, their pixels
baked into `ld (hl),N` stores. The grind frames are the interesting ones,
because the Amstrad does something the C64 does not - see below - and there is
no other copy of them anywhere.

Run from the project root:

    python tools/rip_cpc_compiled.py            check, and report the cost
    python tools/rip_cpc_compiled.py --sheet    also write the PNG

## What the grind frames are for

On the C64 the player flashes when it grinds the scenery: `sprite_pls_tmr` is
set, `xploder_2` swaps sprite_col_dcd's low nibble for its high one, and the
ship's dps ($0B-$11) go cyan -> purple. Our port transcribes that and every
build does it.

The Amstrad instead draws a **different ship**. `PlayerFrameGrindList` is a
second seven-entry frame list, indexed by the same `PlayerFrame` 0-6, and
`PrintSprites` selects it whenever `GrindState` is non-zero (set to 2 on
contact, not 1, because the top and bottom edges are tested on alternate
frames, so the state has to outlive one of them). The ship is replaced, not
recoloured, and it sparks.

**Parked, not built** - see PLAN.md. The frames rip cleanly and this tool
proves it, but they do not fit: 636 bytes in sprite bank 1 and 742 in bank 2,
against 21 and 86 free in a `-Cpc` build.

## How the reader knows it is right

The compiled bodies walk the screen the way `PrintSprites` in EG_Sprites10.asm
does: an address pair loaded from the Y table per LINE PAIR, then six byte
columns, each written twice - once with bit 11 of the address set and once
clear. `res 3,h` clears bit 11, which on the CPC reaches the line ABOVE, so the
RES-state byte is the even row of the pair and the SET-state byte the odd one.
There are ELEVEN address loads, not ten: line 20 is odd and comes on its own,
and only its RES-state stores are used.

None of that is assumed. `EG_Sprites_Player.asm` is the same player whose
frames are already in SPRITES.BIN, so the reader is run over it first and must
reproduce bank frames 11-17 - the player's own dp range - at 126 bytes out of
126, all seven. It does. Getting the pair order upside down scores about 90 and
fails loudly, which is how the mapping above was found rather than guessed.
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "cpc"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import cpcscr                       # noqa: E402
from dsk import Dsk                 # noqa: E402

SRC = os.path.join("source_cpc", "Source")
DSK = os.path.join("source_cpc", "Work Disks", "edge_sprites2.dsk")
SHEET = os.path.join("reference", "grind-sparks-cpc.png")

ROWS, COLS = 21, 6          # lines, and byte columns, per frame
SLOT = 128                  # bytes per SPRITES.BIN slot; 126 used
PLAYER_FRAMES = range(11, 18)   # the player's own frames, dps $0B-$11
TRANSPARENT = (96, 96, 96)      # the sheets' key, as rip_cpc_sprites.py uses

STORE = re.compile(r"^ld \(hl\),(\d+)")


def compiled(path, label):
    """Every `.<label>N` body in `path` as ROWS rows of COLS CPC bytes."""
    text = open(os.path.join(SRC, path), encoding="latin-1").read()
    parts = re.split(r"^\.(%s\d+)\s*$" % label, text, flags=re.M)[1:]
    out = {}
    for name, body in zip(parts[0::2], parts[1::2]):
        rows = [[0] * COLS for _ in range(ROWS)]
        pair, col, upper = -1, 0, True
        for line in body.splitlines():
            s = line.strip()
            if s.startswith("ld l,(ix+0)"):     # a new line pair
                pair, col, upper = pair + 1, 0, True
            elif s.startswith("set 3,h"):
                upper = True
            elif s.startswith("res 3,h"):
                upper = False
            elif s.startswith("inc hl"):
                col, upper = col + 1, True
            else:
                m = STORE.match(s)              # a ';' comment is a zero byte
                if m:
                    r = pair * 2 + (1 if upper else 0)
                    if r < ROWS and col < COLS:
                        rows[r][col] = int(m.group(1))
        out[name] = rows
    return out


def bank():
    """SPRITES.BIN's 119 frames, in the byte order PrintSprites consumes."""
    data = cpcscr.strip_amsdos(Dsk(DSK).catalogue()[(0, "SPRITES", "BIN")])
    out = []
    for n in range(119):
        f = data[n * SLOT:n * SLOT + 126]
        rows = [[0] * COLS for _ in range(ROWS)]
        for pair in range(10):
            for col in range(COLS):
                rows[pair * 2 + 1][col] = f[pair * 12 + col * 2]
                rows[pair * 2][col] = f[pair * 12 + col * 2 + 1]
        for col in range(COLS):
            rows[20][col] = f[120 + col]
        out.append(rows)
    return out


def verify():
    """The reader against SPRITES.BIN, on the player it already has."""
    ref, got = bank(), compiled("EG_Sprites_Player.asm", "PlayerSprite")
    for i, want in enumerate(PLAYER_FRAMES):
        mine = got["PlayerSprite%d" % i]
        same = sum(1 for r in range(ROWS) for c in range(COLS)
                   if mine[r][c] == ref[want][r][c])
        assert same == ROWS * COLS, (
            "PlayerSprite%d does not match bank frame %d (%d/%d bytes) - the "
            "reader is wrong, do not trust the grind frames"
            % (i, want, same, ROWS * COLS))
    return len(list(PLAYER_FRAMES))


def cost(frames):
    """What the frames would add to each sprite bank, boxed as the exporter
    boxes them. Both shifts, because the engine keeps a bank per shift."""
    import export_sprites
    import nula
    pal = nula.cpc_palette()
    alias = nula.pen_aliases(pal)
    total = {0: 0, 1: 0}
    for rows in frames:
        px = [[0] * (COLS * 2) for _ in range(ROWS)]
        for r in range(ROWS):
            for c in range(COLS):
                if rows[r][c]:
                    px[r][c * 2:c * 2 + 2] = [
                        alias.get(p, p) if p == 0 else p
                        for p in cpcscr._decode(rows[r][c], 0)]
        for shift in (0, 1):
            _, rn, _, cn = export_sprites.box(
                export_sprites.shifted_bytes(px, shift))
            total[shift] += rn * cn
    return total


def sheet(frames, path=SHEET):
    """The frames as a PNG in the format of reference/sprite-sheet-cpc.png:
    24 x 21 cells, eight a row, a mode 0 pixel twice across, a zero byte the
    grey key."""
    from PIL import Image
    pal = cpcscr.mode0_rgb()
    im = Image.new("RGB", (8 * 24, ROWS), TRANSPARENT)
    px = im.load()
    for n, rows in enumerate(frames):
        for r in range(ROWS):
            for c in range(COLS):
                if not rows[r][c]:
                    continue
                for i, pen in enumerate(cpcscr._decode(rows[r][c], 0)):
                    for d in range(2):
                        px[n * 24 + (c * 2 + i) * 2 + d, r] = tuple(pal[pen])
    im.save(path)
    return path


def main(write_sheet=False):
    print("reader verified against SPRITES.BIN: %d/%d player frames exact"
          % (verify(), len(list(PLAYER_FRAMES))))
    grind = compiled("EG_Sprites_Player_Grind.asm", "PlayerSpriteGrind")
    frames = [grind["PlayerSpriteGrind%d" % i] for i in range(7)]
    for i, rows in enumerate(frames):
        lit = sum(1 for r in rows for b in r if b)
        print("  PlayerSpriteGrind%d  %3d/126 opaque bytes" % (i, lit))
    c = cost(frames)
    print("cost if adopted: sprite bank 1 (shift 0) +%d B, "
          "bank 2 (shift 1) +%d B" % (c[0], c[1]))
    print("  a -Cpc build has 21 and 86 free, so it does NOT fit; the tune "
          "streams a -Akl build removes from those banks (1,273 and 1,351 B) "
          "are the only room that exists. Parked - see PLAN.md.")
    if write_sheet:
        print(sheet(frames))


if __name__ == "__main__":
    main(write_sheet="--sheet" in sys.argv[1:])
