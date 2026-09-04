#!/usr/bin/env python3
"""Check a jsbeeb SN76489 write capture against the tune the build shipped.

The point of the check (decision 48): the .vgi's eleven register streams are
scattered over four regions of memory - bank 3, HAZEL, ANDY and the tails of
banks 1 and 2 - and the player pages each one in for itself. If any of that
placement is a byte out, the tune does not merely sound wrong somewhere: the
streams desynchronise and the chip gets nonsense. So the proof is not "it
plays" but "the bytes the running game wrote to &FE4F are, exactly and in
order, the bytes the reference .vgi says frame N onwards should be".

This rebuilds the reference write stream from the region binaries the build
actually INCBINs and the map it actually assembles - not from build/cut.vgi -
so the placement itself is under test, then searches for the capture in it.

Usage:
    python tools/verify_vgi.py capture.txt

`capture.txt` is stop_sound_capture's output pasted verbatim; only the "0xNN"
column is read.
"""

import re
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, 'src', 'data')

SKIP = 0x0f
NUM_STREAMS = 11
# The high nibble vgm_decode_frame ORs into each stream's byte before writing.
# Stream 6 is the noise control and is written only when it is not SKIP.
LATCH = [0x80, 0x00, 0xa0, 0x00, 0xc0, 0x00, 0xe0, 0x90, 0xb0, 0xd0, 0xf0]


def load_map():
    """The three tables and VGI_FRAMES out of the generated music_map.asm."""
    src = open(os.path.join(DATA, 'music_map.asm')).read()
    frames = int(re.search(r'VGI_FRAMES = (\d+)', src).group(1))

    def row(name):
        m = re.search(r'\.%s\s*\n\s*EQUB ([^\n]+)' % name, src)
        return [int(v.strip().lstrip('&'), 16) for v in m.group(1).split(',')]

    lo, hi, rom = row('vgi_map_lo'), row('vgi_map_hi'), row('vgi_map_rom')
    return frames, [(hi[i] << 8) | lo[i] for i in range(NUM_STREAMS)], rom


def memory():
    """The Master's address space as the player sees it, one image per ROMSEL
    byte the map can name. Region A is bank 3 (music_lo) with HAZEL (music_hi)
    on top of it, which is what makes a stream able to cross &C000."""
    def rd(n):
        return open(os.path.join(DATA, n), 'rb').read()

    a = bytearray(0x10000)
    a[0x9100:0x9100 + len(rd('music_lo.bin'))] = rd('music_lo.bin')
    a[0xC000:0xC000 + len(rd('music_hi.bin'))] = rd('music_hi.bin')
    andy = bytearray(a)
    andy[0x8000:0x8000 + len(rd('music_andy.bin'))] = rd('music_andy.bin')
    b1 = bytearray(0x10000)
    b1[0xB900:0xB900 + len(rd('music_b1.bin'))] = rd('music_b1.bin')
    b2 = bytearray(0x10000)
    b2[0xBA00:0xBA00 + len(rd('music_b2.bin'))] = rd('music_b2.bin')
    return {0x07: a, 0x87: andy, 0x05: b1, 0x06: b2}


class Stream:
    """lib/vgiplayer.asm's per-stream decoder, byte for byte: a 256-byte ring,
    one output byte per call, tokens 0=literal 10=run 11=match."""

    def __init__(self, mem, addr):
        self.mem, self.src = mem, addr
        self.ring = bytearray(256)
        self.rem = self.flag = self.copy = self.head = 0

    def fetch(self):
        b = self.mem[self.src]
        self.src = (self.src + 1) & 0xFFFF
        return b

    def next(self):
        if self.rem == 0:
            c = self.fetch()
            if c < 0x80:                        # literal run
                self.rem, self.flag = (c & 0x7f) + 1, 0
            else:
                n = c & 0x3f
                self.rem = self.fetch() if n == 0x3f else n + 2
                if c < 0xc0:                    # RUN, offset 1
                    self.copy = (self.head - 1) & 0xff
                else:                           # MATCH, offset byte follows
                    self.copy = (self.head - self.fetch()) & 0xff
                self.flag = 0x80
        if self.flag:
            b = self.ring[self.copy]
            self.copy = (self.copy + 1) & 0xff
        else:
            b = self.fetch()
        self.ring[self.head] = b
        self.head = (self.head + 1) & 0xff
        self.rem -= 1
        return b


def reference(nframes):
    """The write stream the player must produce, for `nframes` fields. It
    re-mounts at VGI_FRAMES exactly as vgm_update does with C=1, so a capture
    taken across the loop point is checkable too."""
    frames, addrs, roms = load_map()
    mem = memory()
    st = [Stream(mem[roms[i]], addrs[i]) for i in range(NUM_STREAMS)]
    out = []
    for n in range(nframes):
        if n and n % frames == 0:
            st = [Stream(mem[roms[i]], addrs[i]) for i in range(NUM_STREAMS)]
        v = [s.next() for s in st]
        for i in range(NUM_STREAMS):
            if i == 6 and v[i] == SKIP:
                continue
            out.append(LATCH[i] | v[i] if LATCH[i] else v[i])
    return out


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    cap = [int(m, 16) for m in
           re.findall(r'0x([0-9a-f]{2})\b', open(sys.argv[1]).read())]
    if not cap:
        raise SystemExit('no writes found in ' + sys.argv[1])
    print('capture: %d writes' % len(cap))

    # A capture starts wherever the emulator was told to start, so look for it
    # anywhere in the tune. Decoding all 17,448 frames takes a second or two.
    ref = reference(20000)     # the tune is 17,448, so this crosses the loop
    print('reference: %d writes, the whole tune and past its loop' % len(ref))

    hits = []
    first = cap[0]
    for i in range(len(ref) - len(cap) + 1):
        if ref[i] == first and ref[i:i + len(cap)] == cap:
            hits.append(i)
    if not hits:
        # Say where it first diverges from the best-aligned candidate, which is
        # what a placement bug looks like: right for a while, then rubbish.
        best, run = None, -1
        for i in range(len(ref) - len(cap) + 1):
            n = 0
            while n < len(cap) and ref[i + n] == cap[n]:
                n += 1
            if n > run:
                best, run = i, n
        raise SystemExit(
            'NO MATCH. Best alignment is write %d, where %d of %d writes agree '
            'before they part: reference %s, capture %s'
            % (best, run, len(cap),
               ' '.join('%02x' % b for b in ref[best + run:best + run + 8]),
               ' '.join('%02x' % b for b in cap[run:run + 8])))
    print('MATCH at write %s - and nowhere else'
          % ', '.join(str(h) for h in hits) if len(hits) < 4 else
          'MATCH at %d places' % len(hits))
    print('%d writes, byte for byte, from a tune living in four regions of '
          'memory.' % len(cap))


if __name__ == '__main__':
    main()
