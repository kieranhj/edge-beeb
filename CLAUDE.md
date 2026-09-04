# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project Overview

A port of the C64 game *Edge Grinder* (Cosine, Format War contest) to the **BBC Master 128**, in
6502 assembly for the **BeebASM** assembler. A horizontal scrolling shooter: 1-pixel-per-frame
scroll at 25 Hz, a five-tile-high tile map 302 tiles long, player, bullet and up to six enemies
from the original's 201-wave table.

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
| Sprites | Eight slots, the C64's arrangement (0 player, 1 bullet, 2-7 pool). Interpreted, bounding-boxed, clipped; ~6,155 cycles a sprite for restore + draw, **a figure now known to be optimistic** (`BUGS.md` #9). `src/sprite.asm`, `docs/layer-3-sprites.md` |
| Game logic | **Ticks twice per display frame** (decision 23): the C64's loop is 50 Hz and ours 25, so its per-frame constants transcribe unaltered. `game_tick` in `src/player.asm` |
| Controls | Z/X left/right, K/M up/down, L fire, P pause, ESCAPE abort (only while paused), Q mute. Internal key numbers are **measured** (OSBYTE 121 in a BASIC session holding the key), never recalled - Z 97, X 66, K 70, M 101, L 86, P 55, Q 16, ESCAPE 112. `*FX229,1` first, or BASIC eats ESCAPE. **Q is read in the VSync handler**, so it works while paused and on the titles too (decision 39) |

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
..\..\Bin\beebasm.exe -i src\main.asm -do build\EDGE-RAW.SSD -opt 3 -D RELEASE=0 -v
python tools\make_disc.py build\EDGE-RAW.SSD build\EDGE.SSD build\EDGE-200K.SSD
```

**The build is two passes, and beebasm's own image is NOT bootable.** Every data file on the disc
ships ZX0-compressed (decision 38) and the boot loader runs the depacker over everything it loads.
`tools/make_disc.py` is what compresses them: it rewrites each catalogue load address to the
staging address `main.asm` expects, round-trips every stream through `tools/zx0.py` before it will
write it, and lays the files out in boot access order. Hand `build/EDGE.SSD` (or the padded copy)
to an emulator, never `build/EDGE-RAW.SSD`. The compressor is `bin/zx0.exe`, the reference ZX0 by
Einar Saukas from `BEEB/Repos/ZX0/win/`; `bin/` is gitignored, so a copy lives in the shared
`BEEB/Bin/` too and `make_disc.py` looks in both.

beebasm is `..\..\Bin\beebasm.exe` (1.11); a local `bin\beebasm.exe` wins if present. It resolves
`INCLUDE`/`INCBIN` from the working directory, so the build runs from the project root.

Everything the build produces goes in `build/` (gitignored): `EDGE-RAW.SSD` (beebasm's, not
bootable), `EDGE.SSD`, `EDGE-200K.SSD` (padded; hand this one to jsbeeb and publish this one),
`EDGE.lst` (the `-v` listing). beebasm writes its
progress to stderr; in PowerShell do not redirect that stream or `$ErrorActionPreference = 'Stop'`
throws on a successful build. Check the exit code.

`!BOOT` is assembled by `main.asm`, stamps the assembly time with beebasm's `TIME$` so any disc
image can be dated, and says `DEV build` unless `RELEASE`. Add any new `DEBUG_`
flag to `DEBUG_ANY` and to that stamp so a build cannot lie about itself.

There are no automated tests. The check for a change meant to be mechanical is: extract `Edge`
and `BANK0` from the old and new SSD catalogues and compare (see `docs/layer-0-toolchain.md`).

## Source organisation (`src/`)

Single-pass flat build, everything included from `main.asm`, labels global.

| File | Contents |
|---|---|
| `main.asm` | constants, zero page map, boot, `game_init`, main loop, `scroll_frame` / `scroll_advance` / `scroll_prewind`, `move_pages`, SAVEs, `!BOOT`, the `&0800` game-state block, includes |
| `scroll.asm` | map reader, tile readers, column buffer, column copy |
| `sprite.asm` | the sprite engine: `SCANSTEP`, `spr_restore_all`, `spr_draw_all`, clipping, the hit-flash tables |
| `keyboard.asm` | `keydown` (direct VIA matrix read) and `read_joystick`, which packs the five keys into the C64's `$dc00` byte |
| `player.asm` | movement, fire latch, bullet, background collisions, grind scoring, score, `game_tick`, and the life cycle: `life_cycle`, `life_lost`, `game_over_init`, `player_dropin`, `comp_tick` |
| `enemy.asm` | the wave manager and reader, enemy movement, bounds, the two enemy collision passes, explosions |
| `rupture.asm` | the two-cycle rupture, IRQ handler and install, and the VSync-side call into the music player |
| `tables.asm` | initialised main-RAM tables only; the mutable state lives at `&0800` (see `main.asm`) |
| `zx0depack.asm` | the ZX0 depacker, lifted from Paradroid. Boot code, called only by the loader; the last thing in the image and the one part allowed above `SPR_SAVE`'s base |
| `loading.asm` | the loading screen's two disc files, `LOADSC1` and `LOADSC2` |
| `bank0.asm` | the SWRAM data bank, plus the run-once and out-of-room code: `setup_display`, `clear_play`, `panel_init`, `score_boot`, `status_call`, `title_page`, `pause_check`, `comp_mess`, `finale_tick`, the frame meter |
| `bank1.asm`, `bank2.asm` | the two SWRAM sprite banks, one per pixel shift |
| `music.asm` | the HAZEL image (`&C000-&DFFF`, ACCCON bit 3): the tune's high half at `&C000`, `lib/vgiplayer.asm` at `&D200`, its 11-page ring workspace at `&D500`. SAVEd as `MUSIC` and loaded LAST, because HAZEL is the filing system's own workspace |
| `bank3.asm` | compiled sprite bodies; the titles' font, credits and text plotter; the status panel image, the HUD glyphs and `status_decode`. Reached from main RAM through `bank3_call` |

`src/data/` (from Layer 1) is generated by the exporters in `tools/` and **is committed**;
regenerate with the tool rather than editing it. `build.ps1` does not run the exporters.

## Confirmed hardware facts (measured, not assumed)

- CRTC write windows (Paradroid, reconfirmed here): R4 inside its own cycle before C4 reaches
  it; R6 and R12/R13 inside the previous cycle; R7 can stay constant if only one cycle reaches it.
- VSync handler → fire 1 = 53 scanlines with `T1_I1 = 56*SL - 4*SL - 2`; fire 1 → fire 2 =
  40.0 scanlines with `T1_I2 = 40*SL - 2`. T1 ticks at 1 MHz, SL = 64. Measured 2026-09-02.
- OSFILE writes a file's catalogue addresses back into its parameter block after a load.
- **We take HAZEL, so BREAK must clear memory.** HAZEL (`&C000-&DFFF`, ACCCON bit 3) is the filing
  system's workspace; `MUSIC` overwrites it, so `MUSIC` is loaded LAST and nothing touches the disc
  after it. A SOFT break would leave the wreckage in place - measured: no DFS banner and `*CAT`
  returns nothing. `OSBYTE 200, 3` at the top of `main` makes BREAK a power-on reset (bit 1) and
  disables ESCAPE with it (bit 0). Do not remove it, and do not add a disc access after the load.
- The shadow display bit flips cleanly inside the VSync handler. **Nothing displayed may live
  below `&3000`**: jsbeeb and b-em disagree about what the video fetches there with D set (b-em:
  garbage on alternate frames). Decision 17.
- jsbeeb's screenshot crops to the active display area: judge geometry by poked patterns.
- **The mode change is the FIRST thing boot does** (it was the last until Layer 9a): the loading
  screen is a MODE 2 picture and has to be up before the banks come in. The banks stage in the
  SHADOW screen now, so there is nothing left to hide from `&4000`. R8 = `&30` blanks the display
  from `*RUN` until the picture is unpacked, and again from there until both banks are cleared and
  the panel drawn; R8 does NOT hide the CRTC cursor, so R10 = `&20` goes with it. `VDU 22` resets
  both.
- **A ZX0 stream may not be overtaken by its own output.** ZX0 unpacks forwards, so a stream that
  shares memory with its output is safe only while the reader stays ahead of the writer - which
  means placing it near the END of the output buffer. For a 20K screen at `&3000` that puts its
  tail past `&8000`, so the loading screen stages below the screen instead and is split in two.
  `tools/make_disc.py` refuses to write an image where any stream overlaps its output.

## Memory (Layer 6b build; take live figures from the listing)

| Region | Contents |
|---|---|
| ZP `&00-&9F` | variables, guarded; wiped at boot |
| `&0400-&049F` | column buffer, 160 B |
| `&04A0-&07BF` | collision character map, 40 × 20; `&07C0-&07FF` is its overrun slack. The language workspace - ours once `*RUN` has handed over, verified by sentinel |
| `&0800-&08E9` | game state: the C64's `$0340` block - `sprite_pos`, `sprite_dp`, the `enemy_*` arrays, the score, and what each bank's last sprite draw did. Declared after the SAVEs, so it is not in the image. `&0800-&0BFF` is MOS sound/serial/soft-key workspace, ours with the MOS interrupt gone - verified by sentinel |
| `&0E00-&1EC9` | code (`GUARD CODE_TOP` = `LOAD_STREAM` = `&2200`) |
| to `&1F04` | initialised tables: the sprite row-body dispatch tables, `explosion_dirs`, the OSFILE block |
| to `&2121` | `src/zx0depack.asm`, boot code. **Deliberately above `SPR_SAVE`'s base**: it is dead before anything reads there. `&DF` free in a DEV build |
| `&2000-&2FFF` | `SPR_SAVE`: saved background, 8 slots × 256 B × 2 banks, exactly. At boot it holds the depacker and, from `LOAD_STREAM` = `&2200`, the loading screen's streams |
| `&3000-&7FFF` (main) | at boot only: the **loading screen**, a whole MODE 2 picture, displayed while the banks load |
| `&3000-&7FFF` (shadow) | at boot only: `DEPK_STREAM`, where the bank and music streams stage. Nothing is displaying it - the picture is in main |
| `&3000-&3C7F` × 2 | status panel, 5 rows × 640, in BOTH banks, displayed by rupture cycle A |
| `&4000-&7FFF` × 2 | play buffers, main and shadow |
| SWRAM slot 4 (`SWRAM_DATA`, resting state) | `BANK0`: `char_data &8000` (8K, four MODE 2 column planes), `tile_data` (211 × 16), `map_data` (302 × 5), `col_decode`, `wave_data` (201 × 9) and `anim_decode`. High water `&BC38` |
| SWRAM slot 5 (`SWRAM_SPRITES0`) | `BANK1`: sprite data, pixel shift 0. High water `&B153` |
| SWRAM slot 6 (`SWRAM_SPRITES1`) | `BANK2`: the same, shift 1. High water `&B78B`. The two are identical in layout and **must stay adjacent**: the engine adds the shift to `SWRAM_SPRITES0` |
| HAZEL `&C000-&DFFF` | `MUSIC`: the tune's high half at `&C000`, the VGI player at `&D200`, its 11 x 256 ring workspace at `&D500`. ACCCON bit 3 (Y). Loaded LAST - it is the filing system's workspace - and nothing may touch the disc after it. **The tune's low half is at `&9D00-&BFFF` in bank 3 and the two are one block**: the bank and HAZEL are visible at the same time, so a pointer walking off `&BFFF` lands in `&C000` |

Banks are loaded by `load_bank` (OSFILE the ZX0 stream to `DEPK_STREAM` in the shadow screen,
unpack straight into the paged-in slot) at boot, **after** the mode change, with the loading screen
up in main. **OSFILE overwrites its parameter block's addresses after a load**, so `load_stream`
resets load/exec before every call; without that the second file lands wherever the first said.

`src/data/` is generated by `tools/export_tiles.py`, `tools/export_sprites.py`,
`tools/export_waves.py`, `tools/export_title.py`, `tools/export_panel.py`,
`tools/export_loading.py` and
`tools/compile_sprites.py` from `assets/`, `data/`, `source_c64/data/`
and the C64 source itself, and is committed. `tools/render_bbc.py` renders it back to PNG for checking -
`render_bbc.py sprites 0|1` unpacks a whole sprite bank from its own box tables, which is the check
that the tables and the data agree.

## Facts about the current code that the old docs got wrong

- The 2019 plotter, its nibble LUTs and its two 126-byte stashes are **gone** (Layer 3), and with
  them `BUGS.md` #1. Sprites read pre-converted MODE 2 data from banks 1 and 2.
- `src/data/sprites.bin` is gone too; the exporter now writes `sprites0.bin` and `sprites1.bin`,
  one complete bank image per pixel shift.
- **A play buffer row is 640 bytes and the buffer is 16K, so the wrap point is not row-aligned**:
  a sprite's seven columns can straddle `&8000`. `sprite.asm` tests for it once per sprite and walks
  the pointer per column when it might (decision 21).
- **A local label inside `{}` shadows a global of the same name**, silently: `wave_manager` had a
  `.comp_flag` label beside the `comp_flag` variable it sets, and `sta comp_flag` would have stored
  into code. Assembles cleanly, fails quietly. Do not name a local label after anything it is used
  next to.
- **Bank 0 code may call into main RAM; bank 3 code may not.** The sprite engine pages banks 5, 6
  and 7 in as it needs them and puts `SWRAM_DATA` back when it is done, so a routine in bank 0 is
  still there when a main-RAM call returns to it. Anything in bank 3 needs a trampoline in main
  RAM, and nothing anywhere can page its own bank out from under itself.
- **`wave_manager`'s skip path must consume all nine bytes of a wave.** It only runs when all six
  pool slots are full, which nothing did until the player explosion in Layer 6b, so it was wrong
  from Layer 5 and unreachable. One byte short leaves the reader inside every later wave and
  every field reads as the next one along. `BUGS.md` #10. The general form: **a path nothing has
  ever called is not a tested path**, and the layer that first calls it will be blamed for it.
- **Sprite x does not fit a signed byte.** `x - SPR_X_OFF` runs -12 to 243, so the byte column
  cannot be taken with an arithmetic shift; the sign comes from the subtraction's carry. Getting
  this wrong hid every sprite past x = 140. `BUGS.md` #8.
- **`scroll_advance` runs AFTER the sprites are drawn.** Sprites are placed from `corner_addr`, so
  advancing first makes a stationary sprite rock two pixels in step with the scroll. `BUGS.md` #7.
- **The scroll's tail keeps `char_col + 1` in X**, from the increment at the top down to the
  `corner_addr` update. Anything called from in there - `tile_cnt_bump`, `coll_advance` - must count
  in Y. Getting this wrong breaks the scroll outright; `BUGS.md` #5.
- **Sprites do not take the scroll's bank phase** (`SPR_PHASE_MASK = 0`, decision 22), which
  reverses `PROPOSAL.md` §3.1. Now supported by observation: with `BUGS.md` #7 fixed a stationary
  ship is steady with the mask at 0. See `docs/layer-3-sprites.md`.
- **The scroll is wound a whole screen before play starts** (`scroll_prewind`), because the C64's
  `map_read_rst` ends in its own fast winder and the wave table's timings are authored against a
  full screen. Anything that resets the map must wind it too, or every wave spawns a screen ahead
  of the scenery it was drawn for; `BUGS.md` #6.
- The C64 music is a binary by Sean Connolly, so the BBC tune is converted from the CPC's Arkos
  song (decision 5): `tools/export_music.py`, SKS -> YM -> VGM -> VGI. **`&FFFE` on this Master
  reads `&E59E`** - measured - so the MOS's IRQ entry is above HAZEL and paging HAZEL in cannot
  break interrupt dispatch. The C64 has **no sound effects at all**; do not add any.

## Reference material

- `source_c64/edge_grinder.asm` — the original; authoritative for all game logic and data
- `source_cpc/` — Axelay's Amstrad CPC port (128K, Z80). Closest architecture to ours: same tile
  writer, byte-transparent sprites, compiled player and bullet. `Source/` and `README.txt`
- `notes/` — KC's own notes, RTW's advice, and Axelay's forum post on the CPC internals
- `reference/` — the C64 map, tiles, characters and sprites rendered as PNG;
  `beeb-artwork-example.jpg` is the target look for the hand-authored MODE 2 art
- `data/` — the C64 binaries the port reads today (`tiles.chr/til/map`, `tiles2.map`, `sprites.spr`)
- `lib/disksys.asm` — DFS loading routines (not currently used; boot uses OSFILE).
  `lib/vgiplayer.asm` and `lib/vgiplayer.h.asm` are the music player, copied unaltered
- `C:\Users\khcon\OneDrive\BEEB\Projects\llm-beeb-wiki` — BBC hardware knowledge base
- `C:\Users\khcon\OneDrive\BEEB\Repos\nova-invite` — `bin/SongToYm.exe` and `bin/ym2sn.py`, the
  first half of the music chain
- `C:\Users\khcon\OneDrive\BEEB\Repos\vgm-packer` — `vgipacker.py`, the second half
- `C:\Users\khcon\OneDrive\BEEB\Repos\vgm-player-bbc` — the VGI and VGC players and their measured
  comparison (`docs/vgi-player.md`); `lib/vgiplayer.asm` is copied into `lib/` here **unaltered**

## Assembly conventions

- BeebASM syntax: labels `.name`, comments `\` or `;`, hex `&`
- Keep variable and routine names matching the C64 source where the routine is a transcription
  (`tile_update`, `map_read`, `tile_cnt_bump` already are)
- Debug builds are switched by `DEBUG_` constants at the top of `main.asm`; every debug key will
  need CTRL once the game has redefinable controls
