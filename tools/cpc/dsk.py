"""Minimal CPC (Extended) DSK reader + AMSDOS catalogue extraction."""
import struct, sys, os

class Dsk:
    def __init__(self, path):
        d = open(path, 'rb').read()
        self.ext = d[:16] == b'EXTENDED CPC DSK'
        ntrk, nsid = d[0x30], d[0x31]
        self.sectors = {}          # (track, sectorid) -> bytes
        off = 0x100
        if self.ext:
            sizes = [d[0x34 + i] * 256 for i in range(ntrk * nsid)]
        else:
            tlen = struct.unpack('<H', d[0x32:0x34])[0]
            sizes = [tlen] * (ntrk * nsid)
        for i, sz in enumerate(sizes):
            if sz == 0:
                continue
            t = d[off:off + sz]
            assert t[:10] == b'Track-Info', t[:16]
            trk, side = t[0x10], t[0x11]
            nsec = t[0x15]
            p = 0x100
            for s in range(nsec):
                e = t[0x18 + s * 8: 0x20 + s * 8]
                slen = struct.unpack('<H', e[6:8])[0] or (128 << e[3])
                self.sectors[(trk, side, e[2])] = t[p:p + slen]
                p += slen
            off += sz

    def catalogue(self):
        """user, name, ext -> file contents. Data-format discs, 1K blocks."""
        cat = b''.join(self.sectors[(0, 0, 0xc1 + s)] for s in range(4))
        extents = {}
        for i in range(0, len(cat), 32):
            e = cat[i:i + 32]
            if e[0] == 0xe5:                       # deleted
                continue
            name = e[1:9].decode('latin1').rstrip()
            ext = bytes(b & 0x7f for b in e[9:12]).decode('latin1').rstrip()
            data = b''
            for block in e[16:32]:
                if not block:
                    continue
                for half in range(2):              # a 1K block is two sectors
                    trk, sec = divmod(block * 2 + half, 9)
                    data += self.sectors[(trk, 0, 0xc1 + sec)]
            key = (e[0], name, ext)
            extents.setdefault(key, {})[e[12] + e[14] * 32] = data[:e[15] * 128]
        return {k: b''.join(v[n] for n in sorted(v)) for k, v in extents.items()}

if __name__ == '__main__':
    dsk = Dsk(sys.argv[1])
    outdir = sys.argv[2] if len(sys.argv) > 2 else None
    for (user, name, ext), data in sorted(dsk.catalogue().items()):
        hdr = ''
        if len(data) >= 128 and sum(data[:67]) & 0xff == data[67] and data[68] == 0 == data[69]:
            typ, ld, ln, ex = data[18], struct.unpack('<H', data[21:23])[0], struct.unpack('<H', data[24:26])[0], struct.unpack('<H', data[26:28])[0]
            hdr = f'  AMSDOS type={typ} load=&{ld:04X} len={ln} exec=&{ex:04X}'
        print(f'{user}:{name}.{ext}  {len(data)} bytes{hdr}')
        if outdir:
            os.makedirs(outdir, exist_ok=True)
            open(os.path.join(outdir, f'{name}.{ext}'.strip('.')), 'wb').write(data)
