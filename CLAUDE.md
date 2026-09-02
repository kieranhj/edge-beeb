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
| Play area | 20 rows × 160 px, in **two** 16K buffers at `&4000-&7FFF` (main and shadow), both hardware-wrapped at 16K. A status panel above it is planned (Layer 2) |
| Scroll | 1 px per 25 Hz frame. A CRTC unit is 2 px; the odd pixel is the other bank, whose picture is half a byte out of phase |
| Game loop | 25 Hz, two vsyncs per pass (currently via OSBYTE 19; Layer 2 takes over IRQ1V) |

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
| `keyboard.asm` | OSBYTE &79 input (replaced in Layer 2) |
| `tables.asm` | main-RAM data tables |
| `bank0.asm` | the SWRAM data bank |

`src/data/` (from Layer 1) is generated by the exporters in `tools/` and **is committed**;
regenerate with the tool rather than editing it. `build.ps1` does not run the exporters.

## Memory (Layer 0 build; take live figures from the listing)

| Region | Contents |
|---|---|
| ZP `&00-&9F` | variables, guarded; wiped at boot |
| `&0400` | column buffer, 160 B |
| `&0E00-&1396` | code |
| `&1397-&1BEE` | tables, two 126-byte sprite stashes, four page-aligned pixel tables |
| `&4000-&7FFF` × 2 | play buffers, main and shadow |
| SWRAM slot 4 | `BANK0`: `char_data &8000` (2048 B, 256 chars, C64 2 bpp), `tile_data &8800` (211 × 16), `map_data &9600` (1280), `map2_data &9B00` (230), `sprite_data &9C00` (119 × 64, raw C64). High water `&B9C0` |

`BANK0` is loaded by OSFILE to `&4000` and copied up to `&8000` at boot, before the mode is set.

## Facts about the current code that the old docs got wrong

- **There is no sprite conversion pipeline.** Sprites are the raw C64 bytes, converted per nibble
  at plot time through `map_c64_nibble_to_mask` / `_mode2`. Layer 1 builds the real one.
- The commented-out `eor #1` in `restore_background` is probably correct as it is; see `BUGS.md` #1
  before touching it.
- The `PAL_*` constants are never written to `&FE21`; the game runs in the default palette.
- The map loops after 256 tiles; `map2_data` is present but never reached.
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
