"""export_sprites.py - C64 multicolour sprites -> MODE 2 sprite banks for the
Layer 3 engine (src/sprite.asm).

Writes src/data/sprites0.bin and src/data/sprites1.bin: one 16K-bank image per
pixel shift (0 = the sprite starts on a byte boundary, 1 = one MODE 2 pixel
right, which spills into a seventh byte). The engine pages in the bank for the
shift it needs, so each bank is complete on its own. Layout, INCBIN'd at
&8000 (the addresses in the frame table assume it):

  &8000  MASK      256 B  data byte -> AND mask (a nibble of 0 is transparent)
  &8100  LUT_IDENT 256 B  data byte -> itself
  &8200  LUT_WHITE 256 B  pixels that are not 0, blue or white -> white
  &8300  LUT_MAG   256 B  the same -> magenta  (the player's grind flash)
  &8400  frame_lo  119 B  address of each frame's box data in this bank
  &8480  frame_hi  119 B
  &8500  box_r0    119 B  first opaque row of the frame at this shift
  &8580  box_rn    119 B  rows (0 = blank frame, nothing to draw)
  &8600  box_c0    119 B  first opaque byte column
  &8680  box_cn    119 B  byte columns (the row stride of the data)
  &8700  dp_dcd    126 B  sprite_dp_dcd from the C64, rebased to frame 0-118
  &8780  lut_dcd   126 B  high byte of the LUT the hit flash uses, per dp
  &8800  comp_lo   119 B  compiled body descriptor in slot 7, 0 = not compiled
  &8880  comp_hi   119 B
  &8900  data             row-major, box_rn x box_cn bytes per frame

Colours: bit pair 01 -> blue ($d025), 11 -> white ($d026), 10 -> the frame's
colour from sprite_col_dcd (low nibble) through C64_TO_BBC; 00 -> logical 0
(transparent). Black never occurs inside these sprites; if hand-drawn art
introduces it, it is written as logical 8 (bbc.SPRITE_BLACK).

The flash LUTs assume a sprite holds only 0, blue, white and ONE other
colour, which is true of the C64 art (sprite_col_dcd never names blue or
white as the per-sprite colour). Hand-drawn art with more colours needs
per-colour tables instead: see docs/layer-3-sprites.md.

The frames come from assets/art/sprites.png (Layer 8): the artist paints there
and every pixel resolves through assets/art/palette.png. A frame he has not
drawn yet falls back to the C64 mechanical conversion, so a partial drop still
builds a complete game. --c64 bypasses the PNGs and takes the mechanical
conversion outright, which is what the sheet was seeded from and therefore
produces the same bytes.

KEEP is DERIVED FROM THE ART, not from the flag (`derive_keep`). The C64's rule
- a frame is transparent, blue, white and at most one free colour - is what the
two flash LUTs need in order to recolour just that free colour, and hand-drawn
art puts any colour anywhere, so it cannot be assumed. Art that satisfies the
rule keeps blue and white through a flash exactly as the original does; art that
does not gets KEEP = the transparency key alone, and the flash takes the whole
sprite - which is what the GFX_CPC build has done since Layer 8a. So the seeded
sheets reproduce the C64 build byte for byte and the fallback arrives by itself
the first time a frame needs it. dp_dcd and lut_dcd stay the C64's under every
source: which frames flash, and when, is game logic, not art.

With --cpc (decision 41) the frames come from the Amstrad port's sprite bank
instead and are written to sprites0-cpc.bin, sprites1-cpc.bin, compiled-cpc.bin
and compiled_zp-cpc.asm. A CPC frame carries its own fifteen colours and there
is no per-sprite colour, so KEEP shrinks to the transparency key alone and the
hit flash recolours the WHOLE sprite rather than just its one colour - the
nearest thing the CPC art can be given. The bullet is compiled in both builds
(decision 57; it was not, for want of 13 bytes in bank 3, until decisions 47 and
49 made the room). Everything else, dp_dcd and lut_dcd included, is the C64's
and unaltered: which frames flash, and when, is game logic, not art.

tools/verify_compiled.py proves the compiled bodies of either build against the
interpreted path, by simulating the emitted 6502 over a buffer of background.

Run from the project root: python tools/export_sprites.py [--cpc]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "art"))
import bbc              # noqa: E402
import compile_sprites  # noqa: E402
import mechanical       # noqa: E402
import pngart           # noqa: E402

OUT = "src/data"
C64_ASM = "source_c64/edge_grinder.asm"
FRAMES = 119
DP_ENTRIES = 126          # sprite_dp_dcd / sprite_col_dcd length
VIC_BASE = 0x60           # sprite_dp_dcd value of frame 0
CELL_W = 7                # bytes: 6 for the sprite + 1 spill for shift 1
ROWS = 21
BANK = 0x8000
DATA_START = 0x0900       # offset of the frame data within the bank
TABLE_STRIDE = 0x80

C64_KEEP = {0, bbc.C64_TO_BBC[bbc.C64_SPR_MC1], bbc.C64_TO_BBC[bbc.C64_SPR_MC2]}
FLASH_KEEP = {0}        # no shared colours to preserve: the flash takes it all
LUT_PAGES = {None: 0x81, bbc.WHITE: 0x82, bbc.MAGENTA: 0x83}

# Which animations get straight-line code in sideways slot 7 (decision 29).
# By dp range, the same numbers anim_decode uses, so this reads against the
# table in the C64 source. A frame only qualifies if EVERY dp that reaches it
# uses the identity LUT: the colours are baked into compiled code, so anything
# that hit-flashes cannot have any.
COMPILE_DPS = [(0x12, 0x13)]      # the player bullet

# The CPC build compiles the same bullet, and did not always. A compiled body
# costs code per OPAQUE byte of the box, and the CPC's bullet - masked per byte
# on the Amstrad, so it has fewer see-through bytes - compiles to 2,860 against
# the C64's 2,652. When Layer 8a was built that was 13 bytes more than bank 3
# had, and the frames fell back to the interpreted path. Decisions 47 and 49
# then moved the panel image and !BOOT out of the way; bank 3 has 43 bytes of
# slack below music_lo with the bullet compiled now (decision 57), so the two
# builds run the same code path and their frame meters compare.
CPC_COMPILE_DPS = COMPILE_DPS


def derive_keep(pixels):
    """Which colours a hit flash must leave alone, from the art itself.

    The C64's sprites are transparent, blue, white and one free colour per
    frame, and the two flash LUTs exist to recolour that one. Art built the
    same way keeps blue and white; anything else - the CPC's fifteen pens, a
    hand-drawn frame that uses blue as a hull colour - cannot, because holding
    two arbitrary colours back through a flash reads as a fault, not a flash.
    """
    shared = C64_KEEP - {0}
    for rows in pixels:
        free = {v for row in rows for v in row} - {0} - shared
        if len(free) > 1:
            return FLASH_KEEP
    return C64_KEEP


def shifted_bytes(rows, shift):
    """Per row, the CELL_W MODE 2 bytes with the sprite moved right by shift px."""
    out = []
    for row in rows:
        px = [0] * shift + row + [0] * (CELL_W * 2 - len(row) - shift)
        out.append([bbc.mode2_byte(px[x], px[x + 1]) for x in range(0, CELL_W * 2, 2)])
    return out


def box(cells):
    ys = [y for y, row in enumerate(cells) if any(row)]
    if not ys:
        return (0, 0, 0, 0)
    xs = [x for row in cells for x, v in enumerate(row) if v]
    return (ys[0], ys[-1] - ys[0] + 1, min(xs), max(xs) - min(xs) + 1)


def mask_table():
    out = bytearray()
    for b in range(256):
        m = 0
        if b & 0xAA == 0:
            m |= 0xAA
        if b & 0x55 == 0:
            m |= 0x55
        out.append(m)
    return out


def recolour_table(target, keep):
    out = bytearray()
    for b in range(256):
        left, right = bbc.mode2_unpack(b)
        if target is not None:
            left = left if left in keep else target
            right = right if right in keep else target
        out.append(bbc.mode2_byte(left, right))
    return out


def table(values):
    assert len(values) <= TABLE_STRIDE
    return bytes(values) + bytes(TABLE_STRIDE - len(values))


def main(cpc=False, c64=False):
    os.makedirs(OUT, exist_ok=True)
    suffix = "-cpc" if cpc else ""
    col_dcd, dp_dcd = mechanical.dp_tables()

    if cpc:
        pixels = mechanical.sprites(cpc=True, count=FRAMES)
    elif c64:
        pixels = mechanical.sprites(count=FRAMES)
    else:
        pixels = pngart.sprites(FRAMES, fallback=mechanical.sprites(count=FRAMES))
    keep = derive_keep(pixels)
    print("hit flash: " + ("blue and white are held back, as the C64 does"
                           if keep == C64_KEEP else
                           "the whole sprite recolours (this art has no shared colours)"))

    lut_dcd = []
    for dp in range(DP_ENTRIES):
        normal = bbc.C64_TO_BBC[col_dcd[dp] & 15]
        flash = bbc.C64_TO_BBC[col_dcd[dp] >> 4]
        assert normal not in keep - {0} or normal == flash, dp
        lut_dcd.append(LUT_PAGES[None if flash == normal else flash])

    # Everything both banks need, before either is laid out, because the
    # compiled bank is shared between them.
    boxes = {}
    for shift in (0, 1):
        for f in range(FRAMES):
            cells = shifted_bytes(pixels[f], shift)
            r0, rn, c0, cn = box(cells)
            boxes[shift, f] = (r0, rn, c0, cn,
                               [row[c0:c0 + cn] for row in cells[r0:r0 + rn]])

    # The frames to compile, and the check that none of them ever flashes.
    want = set()
    for lo, hi in (CPC_COMPILE_DPS if cpc else COMPILE_DPS):
        for dp in range(lo, hi):
            want.add(dp_dcd[dp] - VIC_BASE)
    for f in sorted(want):
        for dp in range(DP_ENTRIES):
            if dp_dcd[dp] - VIC_BASE == f:
                assert lut_dcd[dp] == LUT_PAGES[None], (
                    f"frame {f} is reached by dp ${dp:02x}, which hit-flashes: "
                    "its colours cannot be baked into compiled code")
    todo = {(shift, f): boxes[shift, f][4] for shift in (0, 1) for f in sorted(want)}
    slot, csize = compile_sprites.build(todo, f"{OUT}/compiled{suffix}.bin",
                                        f"{OUT}/compiled_zp{suffix}.asm")
    print(f"compiled{suffix}.bin {csize} B: {len(todo)} bodies, "
          f"high water &{0x8000 + csize:04X}")

    for shift in (0, 1):
        data = bytearray()
        addr, r0s, rns, c0s, cns = [], [], [], [], []
        for f in range(FRAMES):
            r0, rn, c0, cn, rows = boxes[shift, f]
            addr.append(BANK + DATA_START + len(data))
            r0s.append(r0)
            rns.append(rn)
            c0s.append(c0)
            cns.append(cn)
            for row in rows:
                data += bytes(row)
        comp = [slot.get((shift, f), 0) for f in range(FRAMES)]
        bank = bytearray()
        bank += mask_table()
        bank += recolour_table(None, keep)
        bank += recolour_table(bbc.WHITE, keep)
        bank += recolour_table(bbc.MAGENTA, keep)
        bank += table([a & 0xFF for a in addr])
        bank += table([a >> 8 for a in addr])
        bank += table(r0s)
        bank += table(rns)
        bank += table(c0s)
        bank += table(cns)
        bank += table([v - VIC_BASE for v in dp_dcd])
        bank += table(lut_dcd)
        bank += table([a & 0xFF for a in comp])
        bank += table([a >> 8 for a in comp])
        assert len(bank) == DATA_START, len(bank)
        bank += data
        assert len(bank) <= 0x4000, len(bank)
        open(f"{OUT}/sprites{shift}{suffix}.bin", "wb").write(bank)
        print(f"sprites{shift}{suffix}.bin {len(bank)} B: {len(data)} B of boxed frame data, "
              f"high water &{BANK + len(bank):04X}")


if __name__ == "__main__":
    main(cpc="--cpc" in sys.argv[1:], c64="--c64" in sys.argv[1:])
