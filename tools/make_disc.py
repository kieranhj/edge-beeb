#!/usr/bin/env python3
"""
make_disc.py - post-process beebasm's SSD into the shipping disc image.

beebasm assembles and SAVEs every file uncompressed; this tool rewrites the
image so that everything except the code and !BOOT ships ZX0-compressed,
with the catalogue load address moved to the staging address the boot loader
in src/main.asm expects. It also lays the files out physically in BOOT
ACCESS ORDER, so the head never seeks backwards during a load: DFS files are
contiguous, and beebasm's own order is SAVE-statement order.

THE RAW IMAGE IS NOT BOOTABLE. load_stream/unpack_to run the depacker over
every file it loads, so the loader only works on this tool's output - always
hand build/EDGE.SSD (or the padded copy) to an emulator, never beebasm's
build/EDGE-RAW.SSD.

Lifted from the Paradroid port's tools/make_disc.py, which is where the ZX0
pipeline in this project comes from: the same compressor (bin/zx0.exe, the
reference ZX0 by Einar Saukas), the same round-trip check against
tools/zx0.py, and the same depacker (src/zx0depack.asm).

Usage: python tools/make_disc.py RAW.SSD OUT.SSD [PADDED.SSD]
"""

import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import zx0

# Both must match src/main.asm.
LOAD_STREAM = 0x2400            # the loading screen's halves, in main RAM
DEPK_STREAM = 0x3000            # the banks and the music, in the SHADOW screen
ANDY_STREAM = 0x6800            # ANDY, above them: it is unpacked after MUSIC

# Where each compressed file's stream is loaded, and where it unpacks to.
# The unpack destination is only needed for the check below.
COMPRESSED = {
    "LOADSC1": (LOAD_STREAM, 0x3000),
    "LOADSC2": (LOAD_STREAM, 0x5800),
    "BANK0":   (DEPK_STREAM, 0x8000),
    "BANK1":   (DEPK_STREAM, 0x8000),
    "BANK2":   (DEPK_STREAM, 0x8000),
    "BANK3":   (DEPK_STREAM, 0x8000),
    "PANEL":   (LOAD_STREAM, 0x3000),
    "ANDY":    (ANDY_STREAM, 0x8000),
    "MUSIC":   (DEPK_STREAM, 0xC000),
}

# The ceiling each stream may not reach. The loading screen's two stage below
# their own output, so the ceiling is the screen; the banks stage in the
# shadow screen, whose top is &8000.
STREAM_TOP = {LOAD_STREAM: 0x3000, DEPK_STREAM: ANDY_STREAM,
              ANDY_STREAM: 0x8000}

# Boot access order: !BOOT and the code, then the loading screen, then the
# four banks, then the panel image - whose stream stays at LOAD_STREAM until
# setup_display unpacks it into each bank - then the music, which is last
# because it lands in HAZEL, the filing system's own workspace, and nothing may
# touch the disc after it.
LAYOUT = ["!BOOT", "Edge", "LOADSC1", "LOADSC2",
          "BANK0", "BANK1", "BANK2", "BANK3", "PANEL", "ANDY", "MUSIC"]

SECTOR = 256


def read_catalogue(img):
    files = {}
    for i in range(img[0x105] // 8):
        e = 8 * (i + 1)
        name = img[e:e + 7].decode("ascii").rstrip()
        dirc = chr(img[e + 7] & 0x7F)
        a = 0x100 + e
        load = img[a] | (img[a + 1] << 8)
        exe = img[a + 2] | (img[a + 3] << 8)
        extra = img[a + 6]
        length = (img[a + 4] | (img[a + 5] << 8)) | (((extra >> 4) & 3) << 16)
        load |= (((extra >> 2) & 3) << 16)
        exe |= (((extra >> 6) & 3) << 16)
        start = (img[a + 7] | ((extra & 3) << 8)) * SECTOR
        files[name] = {"dir": dirc, "load": load, "exec": exe,
                       "data": bytes(img[start:start + length])}
    return files


def compress(zx0_exe, raw, name):
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "in.bin"
        dst = Path(td) / "out.zx0"
        src.write_bytes(raw)
        subprocess.run([str(zx0_exe), "-f", str(src), str(dst)],
                       check=True, capture_output=True)
        packed = dst.read_bytes()
    if zx0.decompress(packed) != raw:
        raise SystemExit(f"{name}: zx0.exe stream fails zx0.py round-trip")
    return packed


def build_image(files, title, cycle, opt):
    order = [n for n in LAYOUT if n in files]
    order += [n for n in files if n not in order]   # anything unexpected
    if len(order) > 31:
        raise SystemExit("more than 31 files - a DFS catalogue holds 31")

    sector = 2
    placed = []                                     # (name, start_sector)
    data = bytearray()
    for name in order:
        f = files[name]
        placed.append((name, sector))
        data += f["data"]
        data += bytes(-len(f["data"]) % SECTOR)
        sector += (len(f["data"]) + SECTOR - 1) // SECTOR

    img = bytearray(2 * SECTOR + len(data))
    img[0:8] = title[:8].ljust(8, b"\0")
    img[0x100:0x104] = title[8:12].ljust(4, b"\0")
    img[0x104] = cycle
    img[0x105] = len(placed) * 8
    total = 800                                     # 80 tracks, as beebasm
    img[0x106] = (opt & 3) << 4 | (total >> 8)
    img[0x107] = total & 0xFF

    # catalogue entries in descending start-sector order, as DFS keeps them
    for i, (name, start) in enumerate(reversed(placed)):
        f = files[name]
        e = 8 * (i + 1)
        img[e:e + 7] = name.encode("ascii").ljust(7)
        img[e + 7] = ord(f["dir"])
        a = 0x100 + e
        length = len(f["data"])
        img[a + 0] = f["load"] & 0xFF
        img[a + 1] = (f["load"] >> 8) & 0xFF
        img[a + 2] = f["exec"] & 0xFF
        img[a + 3] = (f["exec"] >> 8) & 0xFF
        img[a + 4] = length & 0xFF
        img[a + 5] = (length >> 8) & 0xFF
        img[a + 6] = (((f["exec"] >> 16) & 3) << 6 | ((length >> 16) & 3) << 4
                      | ((f["load"] >> 16) & 3) << 2 | (start >> 8) & 3)
        img[a + 7] = start & 0xFF

    if sector > total:
        raise SystemExit(f"{sector} sectors of {total} - the disc is full")
    img[2 * SECTOR:] = data
    return img


def main():
    argv = sys.argv[1:]
    if len(argv) < 2:
        raise SystemExit(__doc__)
    raw_path, out_path = Path(argv[0]), Path(argv[1])
    padded_path = Path(argv[2]) if len(argv) > 2 else None

    root = Path(__file__).parent.parent
    for cand in (root / "bin" / "zx0.exe", root / ".." / ".." / "Bin" / "zx0.exe"):
        if cand.exists():
            zx0_exe = cand
            break
    else:
        raise SystemExit("zx0.exe not found in bin\\ or ..\\..\\Bin - it is the "
                         "reference ZX0 by Einar Saukas, built from "
                         "BEEB/Repos/ZX0 (win/zx0.exe ships prebuilt)")

    img = raw_path.read_bytes()
    files = read_catalogue(img)
    # ANDY only exists in a VGI build: MUSIC_AKL keeps the whole tune in
    # HAZEL and has nothing to put there.
    missing = [n for n in LAYOUT if n not in files and n != "ANDY"]
    if missing:
        raise SystemExit(f"{raw_path} lacks {missing} - the loader and the "
                         "disc would disagree")

    report = []
    for name, (stream, dest) in COMPRESSED.items():
        if name not in files:
            continue
        raw = files[name]["data"]
        packed = compress(zx0_exe, raw, name)
        top = STREAM_TOP[stream]
        if stream + len(packed) > top:
            raise SystemExit(
                f"{name}: {len(packed)} bytes at {stream:#06x} runs past "
                f"{top:#06x}. Split the file, or move its staging address in "
                "main.asm AND here.")
        # A stream is only safe sharing memory with its output if it stays
        # ahead of the writer; none of ours shares any, so simply insist.
        if not (stream + len(packed) <= dest or dest + len(raw) <= stream):
            raise SystemExit(
                f"{name}: the stream at {stream:#06x} overlaps its own "
                f"output at {dest:#06x} - ZX0 unpacks forwards and would eat "
                "itself.")
        files[name]["data"] = packed
        files[name]["load"] = stream
        files[name]["exec"] = stream
        report.append("  %-7s %6d -> %6d  stream %#06x, %d B of headroom"
                      % (name, len(raw), len(packed), stream,
                         top - stream - len(packed)))

    out = build_image(files, img[0:8] + img[0x100:0x104], img[0x104],
                      (img[0x106] >> 4) & 3)
    out_path.write_bytes(out)
    if padded_path:
        padded_path.write_bytes(out.ljust(200 * 1024, b"\0"))

    print("make_disc: ZX0")
    print("\n".join(sorted(report)))
    print("  image   %6d -> %6d" % (len(img), len(out)))


if __name__ == "__main__":
    main()
