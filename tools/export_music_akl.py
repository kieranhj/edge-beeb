#!/usr/bin/env python3
"""Export the CPC port's tune as Arkos "lightweight" (AKL) tracker data.

The alternative to tools/export_music.py. That one runs the tune through
SongToYm -> ym2sn -> vgipacker and ships a compressed SN76489 register log,
which is 23.5 KB for the whole tune and does not fit. This one ships the
TRACKER data - patterns and instruments - which src/aklplayer.asm replays and
src/ay2sn.asm converts to the SN76489 at run time. The whole 349 seconds is
under 5 KB.

    source_cpc/Music/EDGEA.SKS
      SongToLightweight.exe -bin -adr <address>     src/data/music_akl.bin

The address matters: the format holds absolute pointers, so the binary must be
exported at the address it will be played from. MUSIC_AKL_SONG in main.asm is
that address and --addr must match it; main.asm ASSERTs the size.

Two things this export loses, both documented in the AKL format spec:

  * Hardware envelope shapes: AKL encodes only 8 and 0xa, and EDGEA uses 12
    throughout. src/aklplayer.asm's ENV_BASE compensates - if the tune is ever
    changed to use a different shape, that constant has to change with it.
  * Arpeggio and pitch TABLES are exported, but EDGEA uses neither, so those
    paths of the player have never run.

Usage:
    python tools/export_music_akl.py [--addr 0xCC00] [--check]

--check re-reads the result and reports what the song uses, which is the quick
way to see whether a tune has strayed into a path the player has not exercised.
"""

import argparse
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
TRACKERS = os.path.join(os.path.expanduser('~'), 'OneDrive', 'Trackers',
                        'Arkos Tracker 2')
EXPORTER = os.path.join(TRACKERS, 'tools', 'SongToLightweight.exe')
SKS = os.path.join(ROOT, 'source_cpc', 'Music', 'EDGEA.SKS')
OUT = os.path.join(ROOT, 'src', 'data', 'music_akl.bin')

# &CC00 to &E000: what is left of HAZEL once the player and converter are in.
DEFAULT_ADDR = 0xCC00
HAZEL_TOP = 0xE000


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--addr', default=hex(DEFAULT_ADDR),
                    help='the address the song will be played from '
                         '(must match MUSIC_AKL_SONG in main.asm)')
    ap.add_argument('--check', action='store_true',
                    help='report which player features the song uses')
    args = ap.parse_args()
    addr = int(args.addr, 0)

    if not os.path.exists(EXPORTER):
        raise SystemExit('SongToLightweight.exe not found at %s' % EXPORTER)

    r = subprocess.run([EXPORTER, '-bin', '-adr', hex(addr), SKS, OUT],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + r.stderr)
        raise SystemExit('SongToLightweight failed (%d)' % r.returncode)

    n = os.path.getsize(OUT)
    print('%s: %d bytes, to be played from &%04X' % (OUT, n, addr))
    if addr + n > HAZEL_TOP:
        raise SystemExit('the song runs past &%04X by %d bytes'
                         % (HAZEL_TOP, addr + n - HAZEL_TOP))
    print('room left in HAZEL above it: %d bytes' % (HAZEL_TOP - addr - n))

    if args.check:
        check(OUT, addr)


def check(path, base):
    """Walk the tables and report what the song actually contains."""
    d = open(path, 'rb').read()

    def w(a):
        o = a - base
        return d[o] | (d[o + 1] << 8)

    inst, arp, pit = w(base + 5), w(base + 7), w(base + 9)
    n_arp = (pit - arp) // 2 - 1
    n_pit = (inst - pit) // 2 - 1
    first = min(w(inst + 2 * i) for i in range(1))
    n_inst = 0
    while inst + 2 * n_inst < w(inst):
        n_inst += 1
    print()
    print('arpeggio tables: %d   pitch tables: %d   instruments: %d'
          % (max(n_arp, 0), max(n_pit, 0), n_inst))
    if n_arp > 0 or n_pit > 0:
        print('  NOTE: EDGEA used neither. Those paths of src/aklplayer.asm')
        print('        have never been exercised - test before trusting them.')


if __name__ == '__main__':
    sys.exit(main())
