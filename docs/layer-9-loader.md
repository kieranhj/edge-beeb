# Layer 9a — the loading screen, and ZX0 on the disc

2026-09-04. Two things that belong together: a picture to look at while the game loads, and the
compression that pays for it.

`assets/TitlescreenBig.png` is Bitshifters' Edge Grinder title art, already drawn as a MODE 2
screen. It goes up as soon as the mode is set and stays up until `setup_display` takes the display
over. Behind it, the four sideways banks and the music load as before — but every file on the disc
except the code and `!BOOT` now ships ZX0-compressed and is unpacked into place.

## The picture

640 × 512 in the PNG, and **every 4 × 2 block is flat**: it is a 160 × 256 MODE 2 screen scaled up,
not a photograph. `tools/export_loading.py` checks that before it reads a pixel out, and refuses
the file if any block is not — a resampled asset would otherwise be quietly averaged into mush.
Fourteen RGB values appear in it, which are the eight BBC colours plus a paint program's rounding;
each maps to its nearest of the eight, and the result uses all eight.

It is displayed under the MOS's default MODE 2 palette (logical *n* → physical *n* for 0–7), which
is what `setup_display` programs anyway, so nothing has to be set up for it.

## Where the streams sit, and why the picture is two files

ZX0 unpacks **forwards**. A stream may share memory with its own output only while the reader stays
ahead of the writer, which means placing it near the *end* of the output buffer. For a full 20K
screen unpacking to `&3000`–`&7FFF` that is impossible: the stream would have to start at `&8000`
minus its own length and its tail would then run past `&8000`, into the sideways ROM window. There
is nowhere for it.

So the loading screen's stream is staged **below** the screen instead, at `LOAD_STREAM = &2200` —
and that is only 3,584 bytes, where the whole picture packs to 4,659. Hence two files, top half and
bottom half, 1,883 and 2,820 bytes, unpacked to `&3000` and `&5800`. Splitting costs 44 bytes over
packing all 20K at once (decision 38).

`&2200` is above the code image, which ends at `&2147` in a DEV build, and the depacker itself is part of that
— it is boot code, so it is allowed to sit above `SPR_SAVE`'s base at `&2000`. Nothing reads
`SPR_SAVE` until the game starts, and by then the depacker and the streams are both dead. This is
the one thing in the image that deliberately overlaps something else.

The **bank** streams have no such problem: they stage at `DEPK_STREAM = &3000` in the **shadow**
screen, which is 20K of RAM nobody is looking at while the picture is up in main, and they unpack
into sideways RAM or HAZEL, which do not overlap it at all. The largest is BANK3 at 7,019 bytes.

## What boot does now

The mode change **moved to the front**. It used to be the last thing before `setup_display`,
because the banks staged through `&4000` and MODE 2 puts that on screen; they stage in the shadow
screen now, so there is nothing left to hide and the picture needs the mode set before it can be
drawn.

1. `OSBYTE 200, 3` — BREAK must clear memory, unchanged (decision 36).
2. Blank the display (R8 = `&30`, R10 = `&20`), wipe zero page.
3. `VDU 22, 2`, blank again — `VDU 22` turns R8 and the cursor back on.
4. `LOADSC1` → `&2200`, unpack to `&3000`. `LOADSC2` → `&2200`, unpack to `&5800`.
5. R8 = 0. **The picture is up.**
6. `&FE34`: display main (D = 0), CPU sees shadow (X = 1) — which is the state the game itself
   runs in. From here every stream stages in the shadow screen.
7. `BANK0`–`BANK3` → `&3000`, each unpacked into its slot at `&8000`; `MUSIC` → `&3000`, unpacked
   into HAZEL with the Y bit set. `MUSIC` is still last, and nothing may touch the disc after it.
8. Blank again, `setup_display`, and the game takes over.

`move_pages` is gone with the staging it served, and so is `load_stage`; `load_stream` and
`unpack_to` replace them.

## The depacker

`src/zx0depack.asm`, **lifted from the Paradroid port** (`src/zx0depack.asm` there), which wrote it
from the reference compressor's source rather than from a recalled depacker. Only the zero page it
borrows and the macro wrapper changed. It decodes what `zx0.exe` emits in its default mode:
forwards, interlaced Elias gamma, inverted new-offset-MSB payload bits. 257 bytes.

Its six zero-page slots are declared in `main.asm` beside the variables they alias — `read_ptr`,
`write_ptr`, `bufp`, `svp`, `spr_slot`, `spr_tmp`, none of them live at boot — **and not in the
depacker**, because beebasm assembles an undefined symbol as an absolute address in pass 1 and then
errors on the size change in pass 2.

Verified in jsbeeb: the 20,480 bytes at `&3000` after the second unpack are **byte-for-byte** the
concatenation of `src/data/loading1.bin` and `loading2.bin`. The banks and the music are verified
by the game: the title page, the scenery, the compiled sprite bodies and the tune all come from
them and all work.

## The build is two passes now

beebasm writes `build/EDGE-RAW.SSD` and **that image is not bootable** — the loader runs the
depacker over everything it loads. `tools/make_disc.py` (lifted from Paradroid, same job) reads the
raw catalogue, compresses the seven data files with `bin/zx0.exe`, round-trips every stream through
`tools/zx0.py` before it will write it, moves each catalogue load address to the staging address
`main.asm` expects, and lays the files out physically in **boot access order** so the head never
seeks backwards. It writes `build/EDGE.SSD` and the padded `build/EDGE-200K.SSD`.

It refuses to write an image where a stream would run past its ceiling (`&3000` for the loading
screen's, `&8000` for the banks') or overlap its own output. Those are the two ways this can be got
wrong silently.

`zx0.exe` is the reference ZX0 by Einar Saukas, from `BEEB/Repos/ZX0/win/`. `bin/` is gitignored,
so a copy also lives in the shared `BEEB/Bin/` and `make_disc.py` looks in both.

| file | raw | packed |
|---|---|---|
| LOADSC1 | 10,240 | 1,883 |
| LOADSC2 | 10,240 | 2,820 |
| BANK0 | 16,206 | 5,498 |
| BANK1 | 12,883 | 5,002 |
| BANK2 | 14,475 | 5,276 |
| BANK3 | 16,384 | 7,019 |
| MUSIC | 5,153 | 3,501 |
| **image** | **91,904** | **37,632** |

## What it cost in time

Measured in jsbeeb, `*RUN Edge` to `install_irq`:

| | cycles | seconds |
|---|---|---|
| before (no picture, uncompressed) | 22,260,598 | 11.1 |
| after (picture + ZX0) | 21,804,920 | 10.9 |

**Compression roughly pays for the loading screen and no more.** Reading 37,632 bytes instead of
91,904 saves about 9 seconds of disc; unpacking 74,752 bytes of output and drawing a 20K picture
costs almost all of it back. The win is not the clock — it is that the disc image drops from 92K of
files to 38K, and that there is now something to look at for eleven seconds instead of a black
screen. Without compression the picture would have cost about 3.4 seconds on top.

## Notes

- **The MOS's default MODE 2 palette is what the picture is drawn for.** If `setup_display` ever
  stops mapping logical *n* → physical *n*, the exporter has to change with it.
- **`&2200` is not slack.** `LOADSC2` packs to 2,820 of the 3,584 available. A busier bottom half —
  or a code image that grows past `&2200` — hits the assert in `make_disc.py`, and the answer is a
  three-way split, not a bigger buffer.
- The `HAZEL_LOAD_PAGES` constant in `music.asm` is now unused: `move_pages` was its only caller.
  Left in place; it is one line and it documents the image's size.
