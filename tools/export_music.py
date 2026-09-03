#!/usr/bin/env python3
"""Export the CPC port's tune to a .vgi stream for the SN76489.

The C64's music is a binary blob by Sean Connolly with no source, so the BBC
tune comes from the CPC port's Arkos song instead (decision 5). The chain, all
of it existing tools:

    source_cpc/Music/EDGEA.SKS          Arkos Tracker song, AY-3-8912
      -> SongToYm.exe --psg 1           a YM6 register log, 50 Hz
      -> ym2sn.py --white               AY -> SN76489, as a VGM
      -> vgipacker.py                   the .vgi the player reads

`ym2sn.py` and `SongToYm.exe` come from Repos/nova-invite/bin (the toolchain
Layer 7 was always going to use); `vgipacker.py` from Repos/vgm-packer.

**The tune is longer than we have room for.** EDGEA is 17,446 frames - 5m49s -
and packs to 23.5 KB of .vgi, where what is spare is 13.5 KB: the top of
sideways bank 3 and the bottom of HAZEL, which are adjacent in the address map
and visible at the same time, so the tune spans them as one block. This exporter
therefore takes a frame limit and truncates, and the player loops what it gets.
See `docs/layer-7-music.md` for the placement problem and the options for
getting the whole tune in.

Truncation happens at the **YM** stage, before ym2sn, so the VGM the packer sees
is a complete, consistent register log of the first N frames.

Usage:
    python tools/export_music.py [--frames N] [--budget BYTES] [--keep]

`--budget` searches for the largest frame count whose .vgi fits, by bisection;
`--frames` skips the search. Output: src/data/music_lo.bin (the part that lives
below &C000, padded to exactly MUSIC_LO_SIZE so the halves join) and
src/data/music_hi.bin.
"""

import argparse
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BEEB = os.path.dirname(os.path.dirname(ROOT))          # ...\OneDrive\BEEB

SKS = os.path.join(ROOT, 'source_cpc', 'Music', 'EDGEA.SKS')
SONG_TO_YM = os.path.join(BEEB, 'Repos', 'nova-invite', 'bin', 'SongToYm.exe')
YM2SN = os.path.join(BEEB, 'Repos', 'nova-invite', 'bin', 'ym2sn.py')
VGIPACKER = os.path.join(BEEB, 'Repos', 'vgm-packer', 'vgipacker.py')
OUT_LO = os.path.join(ROOT, 'src', 'data', 'music_lo.bin')
OUT_HI = os.path.join(ROOT, 'src', 'data', 'music_hi.bin')

# The tune is ONE address range that happens to span two kinds of RAM. Sideways
# bank 3 ends at &C000 and HAZEL begins there, and both are visible at the same
# time, so a pointer walking off the end of one lands in the other and the
# player needs to know nothing about it. MUSIC_LO_SIZE is how much of the tune
# sits below &C000 - it must match main.asm's constant of the same name, which
# ASSERTs the arithmetic at assembly time.
MUSIC_LO_SIZE = 0x2300      # &9D00-&BFFF in bank 3
MUSIC_HI_SIZE = 0x1200      # &C000-&D1FF in HAZEL, below the player at &D200

YM_REGISTERS = 16


def run(*args):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + r.stderr)
        raise SystemExit('%s failed (%d)' % (args[0], r.returncode))
    return r.stdout


def read_ym(path):
    """A YM6 interleaved log: (header bytes, frame count, per-frame rows)."""
    d = open(path, 'rb').read()
    assert d[:4] in (b'YM5!', b'YM6!'), 'not a YM5/YM6 file'
    o = 12
    nframes, = struct.unpack('>I', d[o:o + 4])
    o += 4 + 4 + 2 + 4 + 2 + 4 + 2      # attrs, digidrums, clock, rate, loop, extra
    for _ in range(3):                  # name, author, comment
        o = d.index(b'\0', o) + 1
    data = d[o:o + YM_REGISTERS * nframes]
    assert len(data) == YM_REGISTERS * nframes, 'truncated YM data'
    return d[:o], nframes, data


def write_ym(path, header, nframes, data, keep):
    """Rewrite the log with only the first `keep` frames. The data is
    interleaved - register-major - so every register's column is cut."""
    head = bytearray(header)
    struct.pack_into('>I', head, 12, keep)
    struct.pack_into('>I', head, 12 + 4 + 4 + 2 + 4 + 2, 0)     # loop to frame 0
    out = bytearray(head)
    for r in range(YM_REGISTERS):
        out += data[r * nframes:r * nframes + keep]
    out += b'End!'
    open(path, 'wb').write(out)


def pack(tmp, header, nframes, data, keep, verbose=False):
    """The YM -> VGM -> VGI half of the chain, for `keep` frames. Returns the
    .vgi bytes."""
    ym = os.path.join(tmp, 'cut.ym')
    vgm = os.path.join(tmp, 'cut.vgm')
    vgi = os.path.join(tmp, 'cut.vgi')
    write_ym(ym, header, nframes, data, keep)
    run(sys.executable, YM2SN, '--white', ym, '-o', vgm)
    out = run(sys.executable, VGIPACKER, vgm, '-o', vgi)
    if verbose:
        print(out.strip())
    return open(vgi, 'rb').read()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', type=int, default=0,
                    help='export exactly this many frames (50 per second)')
    ap.add_argument('--budget', type=int, default=MUSIC_LO_SIZE + MUSIC_HI_SIZE,
                    help='largest .vgi in bytes to aim for')
    ap.add_argument('--keep', action='store_true',
                    help='leave the intermediate .ym/.vgm files in build/')
    args = ap.parse_args()

    tmp = os.path.join(ROOT, 'build') if args.keep else tempfile.mkdtemp()
    os.makedirs(tmp, exist_ok=True)

    full_ym = os.path.join(tmp, 'edgea.ym')
    run(SONG_TO_YM, '--psg', '1', SKS, full_ym)
    header, nframes, data = read_ym(full_ym)
    print('EDGEA.SKS: %d frames, %.1f s at 50 Hz' % (nframes, nframes / 50.0))

    if args.frames:
        keep = min(args.frames, nframes)
        blob = pack(tmp, header, nframes, data, keep, verbose=True)
    else:
        # Bisect on frame count. The packer is monotonic enough in practice
        # and this is a build-time search, so a dozen packs is fine.
        lo, hi, best, blob = 100, nframes, 100, None
        while lo <= hi:
            mid = (lo + hi) // 2
            got = pack(tmp, header, nframes, data, mid)
            print('  %6d frames -> %6d bytes' % (mid, len(got)))
            if len(got) <= args.budget:
                best, blob, lo = mid, got, mid + 1
            else:
                hi = mid - 1
        keep = best
        if blob is None:
            raise SystemExit('nothing fits %d bytes' % args.budget)

    if len(blob) > MUSIC_LO_SIZE + MUSIC_HI_SIZE:
        raise SystemExit('%d bytes will not fit %d' %
                         (len(blob), MUSIC_LO_SIZE + MUSIC_HI_SIZE))
    # The low half is padded to exactly MUSIC_LO_SIZE, so that wherever the
    # tune ends the two halves still meet at &C000 and the .vgi header's stream
    # offsets, which are relative to the start of the file, stay true.
    pad = bytes(1)
    part_lo = blob[:MUSIC_LO_SIZE].ljust(MUSIC_LO_SIZE, pad)
    part_hi = blob[MUSIC_LO_SIZE:].ljust(1, pad)   # never empty: beebasm INCBIN
    open(OUT_LO, 'wb').write(part_lo)
    open(OUT_HI, 'wb').write(part_hi)
    print('%s: %d bytes (bank 3, &9D00)' % (OUT_LO, len(part_lo)))
    print('%s: %d bytes (HAZEL, &C000)' % (OUT_HI, len(part_hi)))
    print('tune: %d bytes, %d frames (%.1f s), loops' % (len(blob), keep, keep / 50.0))


if __name__ == '__main__':
    main()
