"""verify_compiled.py - prove src/data/compiled*.bin draws what the interpreted
path would have drawn.

A compiled body (decision 29) is straight-line 6502 with every pixel baked in as
an immediate, so nothing at build time checks it against the frame it came from;
it either draws the sprite or it draws rubbish, and the only place that shows is
the screen. This runs the emitted bytes on a small simulator of exactly the
sixteen opcodes tools/compile_sprites.py emits, over a buffer of pseudo-random
background, and checks three things per frame and shift:

  draw     every opaque byte of the box became (background AND mask) OR data,
           at the address the interpreted engine's own pointer walk reaches -
           16K wrap and character-row crossings included - and every
           transparent byte is untouched
  save     the save area holds the background those bytes covered
  restore  running the restore body puts the buffer back exactly as it was

The model it is checked against is built here from the frame data in
src/data/sprites{0,1}*.bin and its box tables, read the way src/sprite.asm reads
them - so a wrong box, a wrong stride or a bad crossing tail fails, not just a
wrong pixel.

  python tools/verify_compiled.py [--cpc]

Run from the project root. Raises and says which frame if anything disagrees;
prints what it proved if not.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compile_sprites as cs  # noqa: E402

DATA = 'src/data'
BANK = 0x8000
FRAMES = 119
BOX_RN, BOX_CN = 0x8580, 0x8680
COMP_LO, COMP_HI = 0x8800, 0x8880
FRAME_LO, FRAME_HI = 0x8400, 0x8480

BUF = 0x4000                    # a play buffer to draw into
SAVE = 0x2000                   # a sprite save slot


class Sim:
    """The sixteen opcodes compile_sprites.py emits, and nothing else."""

    def __init__(self, mem):
        self.m = mem
        self.a = self.y = 0
        self.c = self.z = self.n = 0

    def _set(self, v):
        self.a = v & 0xFF
        self.z = self.a == 0
        self.n = self.a >= 0x80
        return self.a

    def _zpw(self, zp):
        return self.m[zp] | (self.m[zp + 1] << 8)

    def run(self, pc, limit=200000):
        stack = []
        for _ in range(limit):
            op = self.m[pc]
            if op == 0xA0:                              # ldy #
                self.y = self.m[pc + 1]
                pc += 2
            elif op == 0xA9:                            # lda #
                self._set(self.m[pc + 1])
                pc += 2
            elif op == 0xA5:                            # lda zp
                self._set(self.m[self.m[pc + 1]])
                pc += 2
            elif op == 0xB1:                            # lda (zp),y
                self._set(self.m[(self._zpw(self.m[pc + 1]) + self.y) & 0xFFFF])
                pc += 2
            elif op == 0x91:                            # sta (zp),y
                self.m[(self._zpw(self.m[pc + 1]) + self.y) & 0xFFFF] = self.a
                pc += 2
            elif op == 0x85:                            # sta zp
                self.m[self.m[pc + 1]] = self.a
                pc += 2
            elif op == 0x29:                            # and #
                self._set(self.a & self.m[pc + 1])
                pc += 2
            elif op == 0x09:                            # ora #
                self._set(self.a | self.m[pc + 1])
                pc += 2
            elif op == 0xE6:                            # inc zp
                z = self.m[pc + 1]
                self.m[z] = (self.m[z] + 1) & 0xFF
                pc += 2
            elif op == 0x18:                            # clc
                self.c = 0
                pc += 1
            elif op == 0x69:                            # adc #
                t = self.a + self.m[pc + 1] + self.c
                self.c = t > 0xFF
                self._set(t)
                pc += 2
            elif op == 0xE9:                            # sbc #
                t = self.a - self.m[pc + 1] - (1 - self.c)
                self.c = t >= 0
                self._set(t)
                pc += 2
            elif op == 0xD0:                            # bne rel
                pc += 2 + (self.m[pc + 1] if not self.z else 0)
            elif op == 0x10:                            # bpl rel
                pc += 2 + (self.m[pc + 1] if not self.n else 0)
            elif op == 0x20:                            # jsr abs
                stack.append(pc + 3)
                pc = self.m[pc + 1] | (self.m[pc + 2] << 8)
            elif op == 0x60:                            # rts
                if not stack:
                    return
                pc = stack.pop()
            else:
                raise AssertionError('opcode &%02X at &%04X' % (op, pc))
        raise AssertionError('ran away')


def walk(rows, cols):
    """The addresses of a box's byte columns, row by row, exactly as
    src/sprite.asm's SCANSTEP and spr_scan_row reach them: +1 a scanline,
    +row_stride-8 across a character row, wrapped in 16K."""
    buf, sav = BUF, SAVE
    for _ in range(rows):
        yield [(buf + c * 8, sav + c * 8) for c in range(cols)]
        buf += 1
        sav += 1
        if buf & 7 == 0:
            buf += cs.ROW_STRIDE - 8
            if buf >= BUF + cs.SCREEN_SIZE:
                buf -= cs.SCREEN_SIZE
            sav = (sav & 0xFF00) | ((sav - 8 + cs.SPR_BLOCK) & 0xFF)


def check(suffix):
    comp = open('%s/compiled%s.bin' % (DATA, suffix), 'rb').read()
    done = 0
    for shift in (0, 1):
        bank = open('%s/sprites%d%s.bin' % (DATA, shift, suffix), 'rb').read()

        def t(base, f):
            return bank[base - BANK + f]

        for f in range(FRAMES):
            slot = t(COMP_LO, f) | (t(COMP_HI, f) << 8)
            if not slot:
                continue
            rn, cn = t(BOX_RN, f), t(BOX_CN, f)
            addr = t(FRAME_LO, f) | (t(FRAME_HI, f) << 8)
            box = [list(bank[addr - BANK + r * cn:addr - BANK + (r + 1) * cn])
                   for r in range(rn)]

            draw = comp[slot - BANK] | (comp[slot - BANK + 1] << 8)
            rest = comp[slot - BANK + 2] | (comp[slot - BANK + 3] << 8)

            mem = bytearray(0x10000)
            mem[BANK:BANK + len(comp)] = comp
            for i in range(cs.SCREEN_SIZE):             # reproducible background
                mem[BUF + i] = (i * 37 + 11) & 0xFF
            before = bytes(mem[BUF:BUF + cs.SCREEN_SIZE])

            # What the interpreted path would leave, from the box and the walk.
            want = bytearray(before)
            saved = {}
            for row, addrs in zip(box, walk(rn, cn)):
                for v, (ba, sa) in zip(row, addrs):
                    if not v:
                        continue
                    bg = before[ba - BUF]
                    saved[sa] = bg
                    m = cs.mask_of(v)
                    want[ba - BUF] = ((bg & m) | v) if m else v

            for pc, expect, what in ((draw, want, 'draw'), (rest, before, 'restore')):
                mem[cs.ZP_BUFP] = BUF & 0xFF
                mem[cs.ZP_BUFP + 1] = BUF >> 8
                mem[cs.ZP_SVP] = SAVE & 0xFF
                mem[cs.ZP_SVP + 1] = SAVE >> 8
                Sim(mem).run(pc)
                got = bytes(mem[BUF:BUF + cs.SCREEN_SIZE])
                bad = [i for i in range(len(got)) if got[i] != expect[i]]
                assert not bad, ('%s: frame %d shift %d differs at %d bytes, '
                                 'first &%04X' % (what, f, shift, len(bad),
                                                  BUF + bad[0]))
                if what == 'draw':
                    for sa, bg in saved.items():
                        assert mem[sa] == bg, ('save: frame %d shift %d &%04X'
                                               % (f, shift, sa))
            done += 1
            print('  frame %3d shift %d: %2d x %2d box, %4d opaque bytes - draw, '
                  'save and restore all exact' % (f, shift, rn, cn, len(saved)))
    assert done, 'nothing is compiled in this build'
    return done


if __name__ == '__main__':
    n = check('-cpc' if '--cpc' in sys.argv[1:] else '')
    print('%d compiled bodies verified against the interpreted path' % n)
