#!/usr/bin/env python3
"""Verify and measure src/aklplayer.asm + src/ay2sn.asm, the Arkos music build.

This is how the player was proved correct in the first place, kept so it can be
re-run after any change to it. Everything it checks, it checks against something
independent - never against itself:

  1. akl_reference.py, a Python transcription of Arkos's own Z80 player, is
     checked against edgea.ym: the AY register log SongToYm.exe produces by
     running Arkos's FULL player over the same song. This is the oracle, and it
     is outside this project entirely.
  2. The 6502 player is run in py65 and its ay_regs compared to the reference,
     frame for frame.
  3. The per-frame cost is reported, both per 50 Hz field and per 25 Hz game
     frame, against the 79,872-cycle budget.
  4. Optionally the SN76489 writes are captured to an .snf for tools/sn2wav.py,
     which is the only way to judge the part that is not a correctness question.

Run it from the PROJECT ROOT (beebasm resolves INCLUDEs from the working
directory, and the players' own INCLUDEs are written relative to it):

    python tools/akl/verify_akl.py
    python tools/akl/verify_akl.py --snf build/runtime.snf   # and capture

Needs: beebasm, `pip install py65 numpy`, and Arkos Tracker 2 + SongToYm.exe
for the oracle. Without the oracle it still does 2 and 3 and says so.
"""

import argparse
import os
import re
import struct
import subprocess
import sys

import numpy as np
from py65.devices.mpu6502 import MPU
from py65.memory import ObservableMemory

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(HERE, 'build')
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import akl_reference                                            # noqa: E402
import sn2wav                                                   # noqa: E402

BEEB = os.path.dirname(os.path.dirname(ROOT))
TRACKERS = os.path.join(os.path.expanduser('~'), 'OneDrive', 'Trackers',
                        'Arkos Tracker 2')
SONG_TO_YM = os.path.join(BEEB, 'Repos', 'nova-invite', 'bin', 'SongToYm.exe')
SKS = os.path.join(ROOT, 'source_cpc', 'Music', 'EDGEA.SKS')

SIM_SONG = 0x4000           # where the sim plays the song from
LOAD = 0x1100               # the sim image's ORG
RET = 0x9000                # sentinel return address
FRAME_BUDGET = 79872        # a 25 Hz game frame, 2 MHz cycles


def beebasm():
    for c in (os.path.join(ROOT, 'bin', 'beebasm.exe'),
              os.path.join(BEEB, 'Bin', 'beebasm.exe')):
        if os.path.exists(c):
            return c
    return 'beebasm'


def build():
    """Export the song at SIM_SONG and assemble the real players around it."""
    os.makedirs(BUILD, exist_ok=True)
    # -o, so this never touches the committed src/data/music_akl.bin: that one
    # is exported at the GAME's address and the sim plays from a different one.
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'export_music_akl.py'),
                    '--addr', hex(SIM_SONG),
                    '-o', os.path.join(BUILD, 'song.akl')],
                   cwd=ROOT, check=True, stdout=subprocess.DEVNULL)

    labels = os.path.join(BUILD, 'labels.txt')
    subprocess.run([beebasm(), '-i', 'tools/akl/sim_akl.asm',
                    '-D', 'SIM_SONG=%d' % SIM_SONG, '-d', '-labels', labels],
                   cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    lab = eval(re.sub(r'(\d+)L', r'\1', open(labels).read()))[0]
    return open(os.path.join(BUILD, 'Akl'), 'rb').read(), lab


def read_ym(path):
    """A YM5/YM6 interleaved log: (frame count, one byte column per register)."""
    d = open(path, 'rb').read()
    assert d[:4] in (b'YM5!', b'YM6!'), 'not a YM5/YM6 file'
    o = 12
    n, = struct.unpack('>I', d[o:o + 4])
    o += 4 + 4 + 2 + 4 + 2 + 4 + 2
    for _ in range(3):
        o = d.index(b'\0', o) + 1
    data = d[o:o + 16 * n]
    return n, [data[r * n:(r + 1) * n] for r in range(16)]


def oracle():
    """The YM register log from Arkos's own player, or None if unavailable."""
    if not (os.path.exists(SONG_TO_YM) and os.path.exists(SKS)):
        return None
    ym = os.path.join(BUILD, 'edgea.ym')
    if not os.path.exists(ym):
        r = subprocess.run([SONG_TO_YM, '--psg', '1', SKS, ym],
                           capture_output=True, text=True)
        if r.returncode != 0:
            return None
    return read_ym(ym)


def check_reference(ref_frames, cols, n):
    """The reference against the YM oracle, comparing only what can be HEARD.

    SongToYm zeroes R6 when nothing has the noise open and R11/R12 when nothing
    uses the envelope, and Arkos's player leaves a silent channel's tone-disable
    bit alone - so a raw register diff reads as badly wrong and is not.
    """
    bad = {}
    for f in range(n):
        ym = [cols[i][f] for i in range(14)]
        us = ref_frames[f]
        for ch in range(3):
            vy, vu = ym[8 + ch], us[8 + ch]
            if vy != vu:
                bad['ch%d volume' % ch] = bad.get('ch%d volume' % ch, 0) + 1
            tone_ym = not (ym[7] >> ch) & 1
            noi_ym = not (ym[7] >> (3 + ch)) & 1
            if not ((vy & 15 or vy & 16) and (tone_ym or noi_ym)):
                continue                                # inaudible either way
            if tone_ym:
                py = ym[2 * ch] | ((ym[2 * ch + 1] & 15) << 8)
                pu = us[2 * ch] | ((us[2 * ch + 1] & 15) << 8)
                if py != pu:
                    bad['ch%d period' % ch] = bad.get('ch%d period' % ch, 0) + 1
            if noi_ym and ym[6] != us[6]:
                bad['noise period'] = bad.get('noise period', 0) + 1
        if any(ym[8 + c] & 16 for c in range(3)):
            if ym[11] != us[11] or ym[12] != us[12]:
                bad['env period'] = bad.get('env period', 0) + 1
            if cols[13][f] != 255 and cols[13][f] != us[13]:
                bad['env shape'] = bad.get('env shape', 0) + 1
    return bad


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', type=int, default=0,
                    help='stop after N frames (default: the whole tune)')
    ap.add_argument('--snf', help='also capture the SN76489 writes to this .snf')
    args = ap.parse_args()

    img, lab = build()
    print('player + converter: %d bytes (&%04X-&%04X)'
          % (lab['all_end'] - lab['start'], lab['start'], lab['all_end']))

    mem = ObservableMemory()
    for i, b in enumerate(img):
        mem[LOAD + i] = b
    writes = []
    mem.subscribe_to_write([0xFE4F], lambda a, v: writes.append(v))
    mpu = MPU(memory=mem)

    def call(addr):
        sp = mpu.sp
        mem[0x100 + sp] = ((RET - 1) >> 8) & 0xFF
        mem[0x100 + ((sp - 1) & 0xFF)] = (RET - 1) & 0xFF
        mpu.sp = (sp - 2) & 0xFF
        mpu.pc = addr
        c0 = mpu.processorCycles
        while mpu.pc != RET:
            mpu.step()
        return mpu.processorCycles - c0

    mpu.a, mpu.x, mpu.y = SIM_SONG & 0xFF, SIM_SONG >> 8, 0
    call(lab['akl_init'])

    ym = oracle()
    n = args.frames or (ym[0] if ym else 17446)
    ref = akl_reference.Player(open(os.path.join(BUILD, 'song.akl'), 'rb').read(),
                               SIM_SONG)
    regs = lab['ay_regs']
    perframe, captured, ref_frames = [], [], []
    mismatch, first = 0, None
    for f in range(n):
        del writes[:]
        perframe.append(call(lab['akl_frame']))
        captured.append(list(writes))
        got = [mem[regs + i] for i in range(14)]
        want = list(ref.play())
        ref_frames.append(list(want))       # raw R13, for the oracle check
        # ...but the 6502 reports 255 on a frame where R13 was not re-sent
        want[13] = ref.r13_sent if ref.r13_sent is not None else 255
        if got != want:
            mismatch += 1
            if first is None:
                first = (f, got, want)

    print()
    print('1. the 6502 player against akl_reference.py, over %d frames:' % n)
    if mismatch:
        print('   *** DIFFERS on %d frames ***' % mismatch)
        print('   first: frame %d\n     6502 %s\n     ref  %s' % first)
    else:
        print('   IDENTICAL on every frame')

    print()
    print('2. akl_reference.py against the YM oracle (Arkos\'s own player):')
    if ym is None:
        print('   SKIPPED - SongToYm.exe or EDGEA.SKS not found')
    else:
        bad = check_reference(ref_frames, ym[1], min(n, ym[0]))
        total = sum(bad.values())
        print('   audible mismatches: %s' % (bad if bad else 'NONE'))
        if total:
            print('   (over the whole tune the known baseline is 11 channel-2')
            print('    periods off by one - anything else is a regression)')

    a = np.array(perframe)
    pair = a[:-1] + a[1:]
    print()
    print('3. cost, cycles @ 2 MHz:')
    print('   per 50 Hz field:   min %d  mean %.0f  p99 %d  max %d'
          % (a.min(), a.mean(), np.percentile(a, 99), a.max()))
    print('   per 25 Hz frame:   min %d  mean %.0f  p99 %d  max %d  (%.1f%% of %d)'
          % (pair.min(), pair.mean(), np.percentile(pair, 99), pair.max(),
             100.0 * pair.max() / FRAME_BUDGET, FRAME_BUDGET))
    print('   SN writes a frame: min %d  mean %.1f  max %d'
          % (min(len(w) for w in captured),
             sum(len(w) for w in captured) / float(len(captured)),
             max(len(w) for w in captured)))

    if args.snf:
        sn2wav.write_snf(args.snf, captured)
        print()
        print('   %s: %d frames - render it with tools/sn2wav.py' % (args.snf, len(captured)))

    return 1 if mismatch else 0


if __name__ == '__main__':
    sys.exit(main())
