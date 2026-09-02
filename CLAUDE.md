# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project Overview

A port of the C64 game *Edge Grinder* (Cosine, Format War contest) to the **BBC Master 128**, in
6502 assembly for the **BeebASM** assembler. A horizontal scrolling shooter: 1-pixel-per-frame
scroll at 25 Hz, a five-tile-high tile map 302 tiles long, player, bullet and up to six enemies
from a 54-wave table.

**`PLAN.md` is the live planning document.** Read it before starting work: it records the state of
the port, what is left, and one paragraph per layer. **`PROPOSAL.md`** (2026-09-02) is the design
rationale: what the Paradroid port taught us, the sprite engine design, the artist pipeline, and the
decisions KC took. Completed layers keep their working notes in `docs/`, one file per layer, plus
`docs/decisions.md`. Read the relevant one before optimising or re-litigating anything.

## Working approach

**The C64 original is the specification.** `source_c64/edge_grinder.asm` is 5,000 lines of clean,
commented source. Every feature starts by finding what the original does, and the port reproduces
it, taking code, constants and tables **verbatim** where the hardware allows. When the BBC forces a
change, port the *decision* the original made, not just the effect.

**Rewrites and deviations must be agreed with KC before they are built, and written down after**,
as numbered rows in `docs/decisions.md` and in the layer's `docs/` file. Do not quietly substitute
a design of your own.

**No hardware abstraction layer.** One layer at a time, working and visible in the emulator before
the next starts; revise `PLAN.md` as you go.

**Do not write hardware code from recalled facts.** The jsbeeb MCP is configured for this project:
set the registers, look at the screen, read memory back, confirm, then build on it. Boot it as a
**Master 128** (the game uses shadow RAM and Master ROM paging).

**Verify against the buffer, not the screenshot.** Once the oracle exists (Layer 2): redraw the
whole strip from the map at the current scroll position and diff it byte for byte against what the
game drew, at both bank parities.

**The Paradroid port is the reference for process and for code to lift.**
`C:\Users\khcon\OneDrive\Projects\Paradroid` (its `CLAUDE.md`, `docs/`, `src/sprite.asm`,
`src/rupture.asm`, `tools/`). Do not adopt its RAM contortions: it fought a Model B's memory all
month and this is a Master.

## Target

| | |
|---|---|
| Machine | **BBC Master 128** (decision 1). Shadow RAM double buffer via `&FE34`; sideways RAM via `&FE30`/`&F4` |
| CPU | Plain 6502 (`CPU 0`); no 65C12 opcodes yet, decide before using any |
| Display | MODE 2, 8 colours, 2:1 pixels, 640 bytes per character row (R1 = 80) |
| Play area | 20 rows × 160 px, in **two** 16K buffers at `&4000-&7FFF` (main and shadow), both hardware-wrapped at 16K, under the 5-row status panel |
| Scroll | 1 px per 25 Hz frame. A CRTC unit is 2 px; the odd pixel is the other bank, whose picture is half a byte out of phase |
| Game loop | 25 Hz: the VSync IRQ flips the banks every `FRAME_LOCK` = 2 fields once the loop has parked a frame; a slow frame costs whole fields, never a tear |
| Display split | Two CRTC cycles: 5-row panel at `&3000` **in both shadow banks** (every panel write goes to both), then 34 rows with the 20-row play area and VSync at absolute row 34. `src/rupture.asm` |
| Interrupts | IRQ1V owned outright (VSync + System VIA T1); no MOS tick, no OS sound, keyboard read direct from the VIA (`keydown`) |

## Build

```powershell
.\build.ps1           # assemble into build/
.\build.ps1 -Run      # assemble and launch b-em as a Master 128
.\build.ps1 -Release  # the build for other people: every DEBUG_ flag off
make                  # wrappers: make, make run, make -Release
```

**`RELEASE` is a beebasm command-line symbol and every build passes it** (`-D RELEASE=0` or `1`).
beebasm has no `IFDEF`, so `main.asm` cannot carry a default; a bare invocation must pass it too:

```
..\..\Bin\beebasm.exe -i src\main.asm -do build\EDGE.SSD -opt 3 -D RELEASE=0 -v
```

beebasm is `..\..\Bin\beebasm.exe` (1.11); a local `bin\beebasm.exe` wins if present. It resolves
`INCLUDE`/`INCBIN` from the working directory, so the build runs from the project root.

Everything the build produces goes in `build/` (gitignored): `EDGE.SSD`, `EDGE-200K.SSD` (padded;
hand this one to jsbeeb and publish this one), `EDGE.lst` (the `-v` listing). beebasm writes its
progress to stderr; in PowerShell do not redirect that stream or `$ErrorActionPreference = 'Stop'`
throws on a successful build. Check the exit code.

`!BOOT` is assembled by `main.asm` and says `DEV build` unless `RELEASE`. Add any new `DEBUG_`
flag to `DEBUG_ANY` and to that stamp so a build cannot lie about itself.

There are no automated tests. The check for a change meant to be mechanical is: extract `Edge`
and `BANK0` from the old and new SSD catalogues and compare (see `docs/layer-0-toolchain.md`).

## Source organisation (`src/`)

Single-pass flat build, everything included from `main.asm`, labels global.

| File | Contents |
|---|---|
| `main.asm` | constants, zero page map, boot, main loop, `move_pages`, SAVEs, `!BOOT`, includes |
| `scroll.asm` | map reader, tile readers, column buffer, column copy |
| `sprite.asm` | the 2019 single-sprite plotter and stash (replaced in Layer 3) |
| `keyboard.asm` | `keydown` (direct VIA matrix read) and `read_keyboard` |
| `rupture.asm` | the two-cycle rupture, IRQ handler and install, `setup_display` (wrap, CRTC, palette, panel clear) |
| `tables.asm` | main-RAM data tables |
| `bank0.asm` | the SWRAM data bank |

`src/data/` (from Layer 1) is generated by the exporters in `tools/` and **is committed**;
regenerate with the tool rather than editing it. `build.ps1` does not run the exporters.

## Confirmed hardware facts (measured, not assumed)

- CRTC write windows (Paradroid, reconfirmed here): R4 inside its own cycle before C4 reaches
  it; R6 and R12/R13 inside the previous cycle; R7 can stay constant if only one cycle reaches it.
- VSync handler → fire 1 = 53 scanlines with `T1_I1 = 56*SL - 4*SL - 2`; fire 1 → fire 2 =
  40.0 scanlines with `T1_I2 = 40*SL - 2`. T1 ticks at 1 MHz, SL = 64. Measured 2026-09-02.
- OSFILE writes a file's catalogue addresses back into its parameter block after a load.
- The shadow display bit flips cleanly inside the VSync handler. **Nothing displayed may live
  below `&3000`**: jsbeeb and b-em disagree about what the video fetches there with D set (b-em:
  garbage on alternate frames). Decision 17.
- jsbeeb's screenshot crops to the active display area: judge geometry by poked patterns.
- **The mode change is the last thing boot does before the display setup**: the banks stage
  through `&4000`, which is on screen the moment MODE 2 is selected. R8 = `&30` blanks the
  display from `*RUN` until both banks are cleared and the panel drawn; R8 does NOT hide the
  CRTC cursor, so R10 = `&20` goes with it. `VDU 22` resets both.

## Memory (Layer 2 build; take live figures from the listing)

| Region | Contents |
|---|---|
| ZP `&00-&9F` | variables, guarded; wiped at boot |
| `&0400` | column buffer, 160 B |
| `&0E00-&15F5` | code (`GUARD CODE_TOP` = `&2000`) |
| `&15F6-&1AB0` | tables, two 126-byte sprite stashes, nibble tables for the 2019 plotter |
| `&2000-&2FFF` | reserved: Layer 3 sprite saves, 8 slots × 256 B × 2 banks |
| `&3000-&3C7F` × 2 | status panel, 5 rows × 640, in BOTH banks, displayed by rupture cycle A |
| `&4000-&7FFF` × 2 | play buffers, main and shadow |
| SWRAM slot 4 (`SWRAM_DATA`, resting state) | `BANK0`: `char_data &8000` (8K, four MODE 2 column planes), `tile_data &A000` (211 × 16), `map_data &AE00` (302 × 5), `col_decode &B400`. High water `&B500` |
| SWRAM slot 5 (`SWRAM_SPRITES`) | `BANK1`: `sprite_data &8000` (119 × 64, raw C64 until Layer 3). High water `&9DC0` |

Banks are loaded by `load_bank` (OSFILE to `&4000`, copied up to `&8000`) at boot, in the MOS's
boot mode with the display blanked, before the mode is set. **OSFILE overwrites its parameter block's addresses after a load**, so `load_bank`
resets load/exec before every call; without that the second bank lands in the DFS ROM.

`src/data/` is generated by `tools/export_tiles.py` and `tools/export_sprites.py` from `data/`
and the C64 source, and is committed. `tools/render_bbc.py` renders it back to PNG for checking.

## Facts about the current code that the old docs got wrong

- **The sprite plotter still converts raw C64 bytes per nibble at plot time** through
  `map_c64_nibble_to_mask` / `_mode2`. `src/data/sprites.bin` exists but is unused until Layer 3.
- The commented-out `eor #1` in `restore_background` is probably correct as it is; see `BUGS.md` #1
  before touching it.
- The C64 music is a binary by Sean Connolly. Arkos Tracker is the CPC port's driver, and the BBC
  tune will be converted from the CPC's (decision 5).

## Reference material

- `source_c64/edge_grinder.asm` — the original; authoritative for all game logic and data
- `source_cpc/` — Axelay's Amstrad CPC port (128K, Z80). Closest architecture to ours: same tile
  writer, byte-transparent sprites, compiled player and bullet. `Source/` and `README.txt`
- `notes/` — KC's own notes, RTW's advice, and Axelay's forum post on the CPC internals
- `reference/` — the C64 map, tiles, characters and sprites rendered as PNG;
  `beeb-artwork-example.jpg` is the target look for the hand-authored MODE 2 art
- `data/` — the C64 binaries the port reads today (`tiles.chr/til/map`, `tiles2.map`, `sprites.spr`)
- `lib/disksys.asm` — DFS loading routines (not currently used; boot uses OSFILE)
- `C:\Users\khcon\OneDrive\BEEB\Projects\llm-beeb-wiki` — BBC hardware knowledge base
- `C:\Users\khcon\OneDrive\BEEB\Repos\nova-invite` — the Arkos → SN76489 music toolchain and
  the VGC player to lift for Layer 7

## Assembly conventions

- BeebASM syntax: labels `.name`, comments `\` or `;`, hex `&`
- Keep variable and routine names matching the C64 source where the routine is a transcription
  (`tile_update`, `map_read`, `tile_cnt_bump` already are)
- Debug builds are switched by `DEBUG_` constants at the top of `main.asm`; every debug key will
  need CTRL once the game has redefinable controls
