#!/usr/bin/env python3
"""Export the CPC port's TWO tunes as Arkos "lightweight" (AKL) tracker data.

The alternative to tools/export_music.py. That one runs the tune through
SongToYm -> ym2sn -> vgipacker and ships a compressed SN76489 register log,
which is 23.5 KB for the whole tune and does not fit. This one ships the
TRACKER data - patterns and instruments - which src/aklplayer.asm replays and
src/ay2sn.asm converts to the SN76489 at run time. The whole 349 seconds is
under 5 KB.

    source_cpc/Music/EDGEA.SKS   -> src/data/music_akl.bin      (in game)
    source_cpc/Music/WON4.SKS    -> src/data/music_akl_win.bin  (the finale)

The CPC has two tunes and re-inits the replay with the second one when the end
sequence starts - `ld (ChangeMusic),a` in Compiled_Main3.asm. This port does the
same thing with music_change, acted on in rupt_vsync.

The address matters: the format holds absolute pointers, so the binary must be
exported at the address it will be played from. MUSIC_AKL_SONG in main.asm is
that address and --addr must match it; main.asm ASSERTs the size.

Two things this export loses, both documented in the AKL format spec:

  * Hardware envelope shapes: AKL encodes only 8 and 0xa, and EDGEA uses 12
    throughout. src/aklplayer.asm's ENV_BASE compensates - if the tune is ever
    changed to use a different shape, that constant has to change with it.
  * Arpeggio and pitch TABLES are exported, but EDGEA uses neither, so those
    paths of the player have never run. WON4 DOES use the instrument pitch,
    which EDGEA never does.
  * TRANSPOSITIONS AT POSITION 0. AKL's linker encodes a transposition only
    when it CHANGES and the player starts at zero, so a song whose first
    position is transposed depends on the exporter writing it there - and for
    WON4 it does not. WON4 needs (0, -3, -7) and the export carries nothing,
    which is 216 frames in the wrong key. main.asm sets it into t_transp after
    akl_init; --check reads the true triple out of Arkos's own AKM export and
    fails if it has moved. See ../arkos-player-bbc/docs/format-akl.md.

Usage:
    python tools/export_music_akl.py [--addr 0xCC00] [--win-addr 0x9100] [--check]

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
WIN_SKS = os.path.join(ROOT, 'source_cpc', 'Music', 'WON4.SKS')
WIN_OUT = os.path.join(ROOT, 'src', 'data', 'music_akl_win.bin')

# Arkos Tracker 3, for SongToAkm.exe - the only place the true position-0
# transpositions are written down. AT2 cannot be asked: its AKL exporter is
# the thing that loses them.
AT3 = os.path.join(os.path.expanduser('~'), 'OneDrive', 'Trackers',
                   'ArkosTracker3')
AKM_EXPORTER = os.path.join(AT3, 'tools', 'SongToAkm.exe')

# What main.asm sets into t_transp after akl_init for the win tune. --check
# proves it against the song rather than trusting this comment.
WIN_TRANSPOSE = (0, -3, -7)

# &CC00 to &E000: what is left of HAZEL once the player and converter are in.
DEFAULT_ADDR = 0xCC00
HAZEL_TOP = 0xE000

# The win tune does not fit in what is left of HAZEL - 379 bytes free against
# its 695 - so it lives in sideways bank 3, which has 12,280 free in this
# build and which rupt_vsync already pages in for the music every field.
WIN_ADDR = 0x9100
BANK3_TOP = 0xC000


def export(sks, out, addr, top, what):
    """One tune, at the address it will be played from."""
    r = subprocess.run([EXPORTER, '-bin', '-adr', hex(addr), sks, out],
                       capture_output=True, text=True)
    if r.returncode != 0:
        sys.stderr.write(r.stdout + r.stderr)
        raise SystemExit('SongToLightweight failed (%d)' % r.returncode)
    n = os.path.getsize(out)
    print('%s: %d bytes at &%04X (%s)' % (out, n, addr, what))
    if addr + n > top:
        raise SystemExit('the song runs past &%04X by %d bytes'
                         % (top, addr + n - top))
    print('  room left below &%04X: %d bytes' % (top, top - addr - n))
    return n


def initial_transpositions(sks):
    """The per-channel transposition at position 0, or None if unknowable.

    AKL cannot be asked - losing this is the fault being worked around - so it
    comes out of SongToAkm's annotated source export, which names each one and
    the channel it belongs to.
    """
    if not os.path.exists(AKM_EXPORTER):
        return None
    import re
    import tempfile
    fd, tmp = tempfile.mkstemp(suffix='.asm')
    os.close(fd)
    try:
        r = subprocess.run([AKM_EXPORTER, sks, tmp], capture_output=True, text=True)
        if r.returncode != 0:
            return None
        text = open(tmp, encoding='utf-8', errors='replace').read()
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass
    start = text.find('; Position 0')
    if start < 0:
        return None
    end = text.find('; Position 1', start)
    block = text[start:end if end > 0 else len(text)]
    tr = [0, 0, 0]
    for val, ch in re.findall(
            r'db\s+(-?\d+)\s*;\s*New transposition on channel (\d)', block):
        i = int(ch) - 1
        if 0 <= i < 3:
            tr[i] = int(val)
    return tuple(tr)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--addr', default=hex(DEFAULT_ADDR),
                    help='where the in-game tune is played from '
                         '(must match MUSIC_AKL_SONG in main.asm)')
    ap.add_argument('--win-addr', default=hex(WIN_ADDR),
                    help='where the win tune is played from '
                         '(must match MUSIC_AKL_WIN in main.asm)')
    ap.add_argument('--check', action='store_true',
                    help='report which player features the songs use, and '
                         "prove the win tune's transposition")
    ap.add_argument('-o', '--out', default=OUT,
                    help='write somewhere other than src/data/music_akl.bin '
                         '(the simulator harness exports its own copy at its '
                         'own address, and must not clobber the committed one)')
    ap.add_argument('--no-win', action='store_true',
                    help='the in-game tune only, for the harness')
    args = ap.parse_args()
    addr = int(args.addr, 0)
    win_addr = int(args.win_addr, 0)

    if not os.path.exists(EXPORTER):
        raise SystemExit('SongToLightweight.exe not found at %s' % EXPORTER)

    out = args.out
    export(SKS, out, addr, HAZEL_TOP, 'in game, HAZEL')
    if args.check:
        check(out, addr)

    if args.no_win:
        return 0

    if not os.path.exists(WIN_SKS):
        raise SystemExit('%s not found' % WIN_SKS)
    print()
    export(WIN_SKS, WIN_OUT, win_addr, BANK3_TOP, 'the finale, bank 3')
    if args.check:
        check(WIN_OUT, win_addr)
        want = initial_transpositions(WIN_SKS)
        if want is None:
            print()
            print('  transposition NOT CHECKED: no SongToAkm.exe at %s'
                  % AKM_EXPORTER)
        elif want != WIN_TRANSPOSE:
            raise SystemExit(
                'position 0 transposes %s, but main.asm sets %s into t_transp. '
                'The tune has changed: fix WIN_TRANSP0..2 in src/main.asm.'
                % (list(want), list(WIN_TRANSPOSE)))
        else:
            print()
            print('  position 0 transposes %s, which the AKL export does not'
                  % list(want))
            print('  carry and main.asm sets into t_transp after akl_init. OK.')
    return 0


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
