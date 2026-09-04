#!/usr/bin/env python3
"""Export the CPC port's tune to .vgi streams for the SN76489, in pieces.

The C64's music is a binary blob by Sean Connolly with no source, so the BBC
tune comes from the CPC port's Arkos song instead (decision 5). The chain, all
of it existing tools:

    source_cpc/Music/EDGEA.SKS          Arkos Tracker song, AY-3-8912
      -> SongToYm.exe --psg 1           a YM6 register log, 50 Hz
      -> ym2sn.py --white               AY -> SN76489, as a VGM
      -> vgipacker.py                   the .vgi the player reads

`ym2sn.py` and `SongToYm.exe` come from Repos/nova-invite/bin; `vgipacker.py`
from Repos/vgm-packer.

THE WHOLE TUNE, IN FOUR PLACES (decision 48)
--------------------------------------------
EDGEA is 17,446 frames - 349 seconds - and packs to 23,514 bytes of .vgi.
There is no such contiguous hole on this Master and there never will be: the
largest this port has is the 17K that bank 3's tail and the bottom of HAZEL
make between them. Layer 7 therefore shipped the first 203 seconds and looped
them.

But a .vgi is not one blob. It is ELEVEN INDEPENDENT STREAMS, one per SN76489
register, and the player reads exactly one byte from each per frame through its
own pointer. So the streams can go in DIFFERENT REGIONS of memory - the total
never has to be contiguous, only each stream - and a machine with 17K here and
4K there is exactly what that is good for. This script does the placement: it
packs the whole tune, cuts the .vgi into its eleven streams, best-fit-decreasing
them into the regions below, and writes one binary per region plus the
address/ROMSEL table the player mounts from.

The regions MUST match src/main.asm, which ASSERTs them against the constants
written into src/data/music_map.asm:

  A     &9100-&D2FF   bank 3's tail running on into HAZEL. They are paged by
                      different registers over different windows and are both
                      visible at once, so a stream may cross &C000 without the
                      player knowing the join is there. Two files: the part
                      below &C000 ships in BANK3, the rest in MUSIC.
  ANDY  &8000-&8FFF   the Master's own 4K, ROMSEL bit 7. It overlays the LOW
                      4K of whichever sideways bank is selected, which is the
                      busiest ground we have - so nothing may live here that
                      an inner loop walks, and a music stream read once or
                      twice a frame from an interrupt is exactly the right
                      tenant. Ships as its own disc file, ANDY.
  B1    &B900-&BFFF   the tail of sideways bank 1, above the sprite data
  B2    &BA00-&BFFF   the tail of sideways bank 2 - a page higher than
                      B1's, because the CPC artwork's sprite bank 2 is
                      bigger and reaches &B941

Usage:
    python tools/export_music.py [--frames N] [--keep]

Output: src/data/music_lo.bin, music_hi.bin, music_andy.bin, music_b1.bin,
music_b2.bin and music_map.asm.
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
DATA = os.path.join(ROOT, 'src', 'data')

YM_REGISTERS = 16
NUM_STREAMS = 11

# Region A is split at &C000 because its two halves ship in different disc
# files, not because the player can tell them apart. Every constant here has a
# twin in src/main.asm and music_map.asm ASSERTs the pair together.
A_BASE, A_JOIN, A_TOP = 0x9100, 0xC000, 0xD300
ANDY_BASE, ANDY_TOP = 0x8000, 0x9000
B1_BASE, B2_BASE, BANK_TOP = 0xB900, 0xBA00, 0xC000
SWRAM_COMPILED, SWRAM_SPRITES0, SWRAM_SPRITES1 = 7, 5, 6

REGIONS = [
    ('A',    A_BASE,    A_TOP,    SWRAM_COMPILED),
    ('ANDY', ANDY_BASE, ANDY_TOP, 0x80 | SWRAM_COMPILED),
    ('B1',   B1_BASE,   BANK_TOP, SWRAM_SPRITES0),
    ('B2',   B2_BASE,   BANK_TOP, SWRAM_SPRITES1),
]


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


def pack(tmp, header, nframes, data, keep):
    """The YM -> VGM -> VGI half of the chain, for `keep` frames."""
    ym = os.path.join(tmp, 'cut.ym')
    vgm = os.path.join(tmp, 'cut.vgm')
    vgi = os.path.join(tmp, 'cut.vgi')
    write_ym(ym, header, nframes, data, keep)
    run(sys.executable, YM2SN, '--white', ym, '-o', vgm)
    print(run(sys.executable, VGIPACKER, vgm, '-o', vgi).strip())
    return open(vgi, 'rb').read()


def cut_streams(blob):
    """The .vgi header into (nframes, [11 stream blobs]). The header itself is
    dead weight to us - the player mounts from music_map.asm's table rather
    than biasing eleven file-relative offsets by one base - so it is dropped."""
    assert blob[:3] == b'VGI', 'not a .vgi'
    nframes = blob[4] | (blob[5] << 8)
    offs = [blob[6 + 2 * i] | (blob[7 + 2 * i] << 8) for i in range(NUM_STREAMS)]
    ends = offs[1:] + [len(blob)]
    return nframes, [blob[a:b] for a, b in zip(offs, ends)]


def place(streams):
    """Best-fit decreasing: the biggest stream first, into the region whose
    REMAINING room is smallest of those that still hold it. That keeps the one
    big region for the streams only it can take, which is the whole game -
    seven of the eleven are bigger than either sideways-bank tail, and no two
    of those seven fit in ANDY together."""
    free = [top - base for _, base, top, _ in REGIONS]
    at = [base for _, base, _, _ in REGIONS]
    where = [None] * NUM_STREAMS
    for i in sorted(range(NUM_STREAMS), key=lambda i: -len(streams[i])):
        n = len(streams[i])
        fits = [r for r in range(len(REGIONS)) if free[r] >= n]
        if not fits:
            raise SystemExit(
                'stream %d is %d bytes and nothing has room for it. Free: %s'
                % (i, n, ', '.join('%s %d' % (REGIONS[r][0], free[r])
                                   for r in range(len(REGIONS)))))
        best = min(fits, key=lambda r: free[r])
        where[i] = (best, at[best])
        at[best] += n
        free[best] -= n
    return where, free


def emit(where, streams, nframes):
    """One binary per region, and the table the player mounts from."""
    # IN ADDRESS ORDER, not stream order: place() hands them out biggest
    # first, so a region's streams are not numbered in the order they sit in
    # it. Concatenating by index instead put every stream but the first of
    # each region at the wrong address, which the player cannot tell from
    # right data until one of them runs off the end of what it was given.
    images = {r: bytearray() for r in range(len(REGIONS))}
    for r in range(len(REGIONS)):
        for i in sorted((i for i in range(NUM_STREAMS) if where[i][0] == r),
                        key=lambda i: where[i][1]):
            assert REGIONS[r][1] + len(images[r]) == where[i][1]
            images[r] += streams[i]

    def w(name, data):
        open(os.path.join(DATA, name), 'wb').write(bytes(data))

    a = images[0]
    lo_size = A_JOIN - A_BASE
    # The low part is padded to exactly &C000 so that wherever region A's
    # streams end, the two files still meet at the join and the addresses in
    # the map stay true.
    w('music_lo.bin', bytes(a[:lo_size]).ljust(lo_size, b'\0'))
    # beebasm will not INCBIN an empty file, so nothing is ever written empty.
    w('music_hi.bin', bytes(a[lo_size:]) or b'\0')
    w('music_andy.bin', bytes(images[1]) or b'\0')
    w('music_b1.bin', bytes(images[2]) or b'\0')
    w('music_b2.bin', bytes(images[3]) or b'\0')

    addr = [(where[i][1], REGIONS[where[i][0]][3], REGIONS[where[i][0]][0])
            for i in range(NUM_STREAMS)]
    lines = [
        "\\ GENERATED by tools/export_music.py - do not edit.",
        "\\",
        "\\ Where each of the .vgi's eleven register streams was placed, and",
        "\\ which ROMSEL byte makes it readable. vgm_stream_mount copies these",
        "\\ into the player's per-stream pointers, and fetchbyte writes the",
        "\\ ROMSEL byte to &FE30 before every read. See decision 48.",
        "",
        "ASSERT MUSIC_A_BASE    = &%04X" % A_BASE,
        "ASSERT MUSIC_A_JOIN    = &%04X" % A_JOIN,
        "ASSERT MUSIC_A_TOP     = &%04X" % A_TOP,
        "ASSERT MUSIC_ANDY_BASE = &%04X" % ANDY_BASE,
        "ASSERT MUSIC_ANDY_TOP  = &%04X" % ANDY_TOP,
        "ASSERT MUSIC_B1_BASE   = &%04X" % B1_BASE,
        "ASSERT MUSIC_B2_BASE   = &%04X" % B2_BASE,
        "",
        "VGI_FRAMES = %d" % nframes,
        "",
        ".vgi_map_lo",
        "    EQUB " + ", ".join("&%02X" % (a & 0xff) for a, _, _ in addr),
        ".vgi_map_hi",
        "    EQUB " + ", ".join("&%02X" % (a >> 8) for a, _, _ in addr),
        ".vgi_map_rom",
        "    EQUB " + ", ".join("&%02X" % r for _, r, _ in addr),
        "",
    ]
    for i in range(NUM_STREAMS):
        lines.append("\\ stream %2d: %5d bytes at &%04X, region %s"
                     % (i, len(streams[i]), addr[i][0], addr[i][2]))
    open(os.path.join(DATA, 'music_map.asm'), 'w').write("\n".join(lines) + "\n")
    return images


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--frames', type=int, default=0,
                    help='export only this many frames (50 per second)')
    ap.add_argument('--keep', action='store_true',
                    help='leave the intermediate .ym/.vgm/.vgi files in build/')
    args = ap.parse_args()

    tmp = os.path.join(ROOT, 'build') if args.keep else tempfile.mkdtemp()
    os.makedirs(tmp, exist_ok=True)

    full_ym = os.path.join(tmp, 'edgea.ym')
    run(SONG_TO_YM, '--psg', '1', SKS, full_ym)
    header, nframes, data = read_ym(full_ym)
    print('EDGEA.SKS: %d frames, %.1f s at 50 Hz' % (nframes, nframes / 50.0))

    keep = min(args.frames, nframes) if args.frames else nframes
    blob = pack(tmp, header, nframes, data, keep)
    frames, streams = cut_streams(blob)
    where, free = place(streams)
    images = emit(where, streams, frames)

    print('placement:')
    for r, (name, base, top, rom) in enumerate(REGIONS):
        mine = [i for i in range(NUM_STREAMS) if where[i][0] == r]
        print('  %-4s &%04X-&%04X rom &%02X  %5d of %5d used, %4d free  streams %s'
              % (name, base, top - 1, rom, len(images[r]), top - base, free[r],
                 ' '.join(str(i) for i in mine)))
    print('tune: %d bytes of stream, %d frames (%.1f s), loops'
          % (sum(len(s) for s in streams), frames, frames / 50.0))


if __name__ == '__main__':
    main()
