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
| Display split | In play, two CRTC cycles: 5-row panel at `&3000` **in both shadow banks** (every panel write goes to both), then 34 rows with the 20-row play area and VSync at absolute row 34. **On the titles, four** - panel, top zoom band, credits, bottom zoom band - with the bands hardware-scrolled round an 8K ring, one in each bank, and **the display bank switched inside the frame**. Six T1 fires instead of two, and the handler is in bank 1. `src/rupture.asm`, `src/bank1.asm`, decision 44 |
| Interrupts | IRQ1V owned outright (VSync + System VIA T1); no MOS tick, no OS sound, keyboard read direct from the VIA (`keydown`) |
| Music | The CPC port's Arkos song through `SongToYm`, `ym2sn` and `vgipacker` to a `.vgi`; `lib/vgiplayer.asm` in HAZEL decodes one byte per register stream per field from `rupt_vsync`. **The whole 349 seconds ships, spread over FOUR regions of memory** - a `.vgi` is eleven independent streams and only each stream has to be contiguous (decision 48). `tools/export_music.py` places them and `tools/verify_vgi.py` proves the placement byte for byte against a jsbeeb capture |
| Starfield | Ten stars drifting left at **two speeds**, a half and a quarter of the level's, so the play area reads as three planes; plotted only into blank background so they never cover the scenery. **The ten are the CPC port's, not the C64's** - the original animates a character the released game never displays, measured (decision 50) - and **the drift is ours** (decision 51), both originals' stars being still. `src/bank1.asm`, `docs/layer-9c-starfield.md` |
| Memorial | Between the loading picture and the titles: the picture fades out, "IN MEMORY OF T.M.R." fades up in the credits' own font, holds three seconds, fades out again. **The fade is the palette only** - MODE 2's eight colours on one brightness ladder, white -> yellow -> cyan -> green -> magenta -> red -> blue -> black, sixteen writes to `&FE21` a rung. Interrupts are down and it polls the System VIA's VSync flag itself; `install_irq` is the next CLI. `memorial` in `src/main.asm`, `mem_page` in `src/bank3.asm`, decision 52, `docs/layer-9d-memorial.md` |
| Artwork | The characters, the sprites, **the status panel, the HUD font, the title page's font** and **the palette** are read from PNGs in `assets/art/` (Layer 8, decisions 58-62), seeded from the C64 conversion so the disc is unchanged until the artist starts work. Five sheets at 2:1 - `chars.png` 128x128, `sprites.png` 192x336, `panel.png` 320x40 (the bar as a PICTURE, cut into 200 cells on export), `hud.png` 128x8 (blank, digits 0-9, the life marker's two halves) and `titlefont.png` 128x16 (blank, A-Z, `! . , - ?`; the memorial draws through it too). **A `Sheet` carries the logical colours it may use**: sprites may not use 0 (the transparency key, so black is 8) and the title font may use ONLY 0, 12, 14, 15 - the same RGB as 4, 6, 7, so without that rule a painted font would look right and fade the panel with the credits (decisions 53, 62; flagged for revisiting, see `docs/layer-9e-credits.md`) - plus `palette.png`, sixteen entries, generated to `src/data/palette.asm`. **A panel cell, a HUD glyph and a character are the same 4x8 shape**, which is why one `Sheet` and one `pack_cell` serve all four. **Eighteen panel cells are overwritten by the HUD** (`hud_cell_lo/hi`); `check_hud_cells` warns about ink painted there - a warning, because the C64's bar leaves them blank and the Amstrad's does not. **Characters are the paintable surface; tiles and the map are index tables and stay the C64's**, so `render_bbc.py tiles`/`map` regenerate the assembled views. Grey `96,96,96` is see-through (sprites only), orange `255,128,0` is 'not drawn yet' and falls back to the mechanical conversion. `tools/art/`, `tools/seed_art.py`, `tools/validate_art.py`, `tools/export_palette.py`, `docs/layer-8-art-pipeline.md` |
| Palette | Sixteen bytes from `assets/art/palette.png`, written to `&FE21` by `setup_display`; `pal_data` is in **main RAM** above `code_end`, not bank 0 (which has single-figure bytes and cannot spare sixteen). Logical n -> physical n for 0-7, 8-15 aliasing 0-7, so logical 8 is a second black sprites may use - **logical 0 is the engine's transparency key and stays so under any palette**. A NULA build is `export_palette.py --nula` (16 x 2 bytes to `&FE23`) and changes NO exported data - `chars.bin` and the sprite banks already store a full 4-bit logical per fat pixel - but WOULD need new fades, the memorial and the credit crossfade both walking MODE 2's eight-colour brightness ladder |
| Sprites | Eight slots, the C64's arrangement (0 player, 1 bullet, 2-7 pool). Interpreted, bounding-boxed, clipped; ~6,155 cycles a sprite for restore + draw, **a figure now known to be optimistic** (`BUGS.md` #9). `src/sprite.asm`, `docs/layer-3-sprites.md` |
| Game logic | **Ticks twice per display frame** (decision 23): the C64's loop is 50 Hz and ours 25, so its per-frame constants transcribe unaltered. `game_tick` in `src/player.asm` |
| Controls | Z/X left/right, K/M up/down, L fire, **SPACE also starts a game from the titles** (decision 54), P pause (P or fire unpauses), ESCAPE abort (only while paused - always-on was built and reverted: it is polled every frame and holding it rebuilt the player's explosion pieces every frame), Q mute. Internal key numbers are **measured** (OSBYTE 121, or `INKEY(-n)` in a BASIC session holding the key), never recalled - Z 97, X 66, K 70, M 101, L 86, P 55, Q 16, SPACE 98, ESCAPE 112. `*FX229,1` first, or BASIC eats ESCAPE. **Q is read in the VSync handler**, so it works on the titles and in the finale as well as in play (decision 39). **The tune stops while the game is paused** and Q is not read there at all, there being nothing to mute (decision 43) |

## Build

```powershell
.\build.ps1           # assemble into build/
.\build.ps1 -Run      # assemble and launch b-em as a Master 128
.\build.ps1 -Release  # the build for other people: every DEBUG_ flag off
.\build.ps1 -Cpc      # the same game drawn with the Amstrad CPC's artwork
make                  # wrappers: make, make run, make -Release
```

**`RELEASE`, `MUSIC_AKL` and `GFX_CPC` are beebasm command-line symbols and every build passes
all three** (`-D RELEASE=0` or `1`, and so on for the other two). beebasm has no `IFDEF` and
refuses a symbol defined twice, so `main.asm` cannot carry a default; a bare invocation must
pass them too:

```
..\..\Bin\beebasm.exe -i src\main.asm -do build\EDGE-RAW.SSD -opt 3 -D RELEASE=0 -D MUSIC_AKL=0 -D GFX_CPC=0 -v
python tools\make_disc.py build\EDGE-RAW.SSD build\EDGE.SSD build\EDGE-200K.SSD
```

`GFX_CPC=1` (`.\build.ps1 -Cpc`) draws the same game with the Amstrad CPC port's
artwork - all 119 sprite frames and all 256 characters, from `source_cpc/` and its work discs -
instead of the C64's (decision 41). **A CPC pen is a DITHER PAIR of MODE 2 colours**
(decision 55, Rich Talbot-Watkins's scheme): mode 0 has 27 colours to MODE 2's eight, so each
one is approximated by two checkerboarded a pixel at a time - nearest per-channel average,
tie-broken by closest brightness, ordered darkest first, and `bbc.dither_pair` reproduces
`reference/cpc-palette-map-to-bbc-mode2.png` cell for cell. The checkerboard is `(x + y) & 1`
in the **art's** coordinates, baked into the bitmaps, so it travels with the scenery as it
scrolls instead of crawling over it. **The CPC port renumbered nothing**, so the tile table, the
map, `col_decode`, the waves, `dp_dcd` and the titles are shared and only the
`INCBIN` changes; `tools/export_tiles.py --cpc` and `tools/export_sprites.py --cpc` write the
data and `tools/render_bbc.py --cpc` renders it back. **The status panel and the HUD font are
the CPC's too** (decision 56, `tools/export_panel.py --cpc` through `tools/cpc/paneldata.py`):
the Amstrad's panel is four character rows to the C64's five, so it sits in rows 0-3 with row 4
black, and its score, high score and lives land in the cells `hud_cell_lo/hi` already names,
the CPC port having copied the C64's layout to the column. It writes `build/EDGE-CPC*.SSD` with disc
title `EDGEC`, and composes with `-Akl`. **The compiled bullet is in this build too** since
decision 57 - it needed 13 bytes bank 3 had not got until decisions 47 and 49 made the room -
so the two builds run the same code path and their frame meters compare.
`tools/verify_compiled.py` proves either build's compiled bodies against the interpreted path
by simulating the emitted 6502. `docs/layer-8a-gfx-cpc.md`. It used not to assemble at all without `-Akl`; decisions 47-49 gave
bank 3 and main RAM the room, and **all six flag combinations build now**.

`MUSIC_AKL=1` (`.\build.ps1 -Akl`) swaps the whole music subsystem: `src/aklplayer.asm` replays
the Arkos tracker data and `src/ay2sn.asm` converts to the SN76489 every frame, in place of
`lib/vgiplayer.asm` and a pre-converted register log. The whole 349-second tune then fits in HAZEL
alone and bank 3's copy of the tune disappears. **It does not sound the same** - the offline chain does
whole-song analysis a per-frame converter cannot - so it is a comparison build pending KC's ear,
not a decision. It writes `build/EDGE-AKL*.SSD` with disc title `EDGEAKL`, so it cannot overwrite
or be mistaken for the normal build. **Parked, with the next steps pinned at the top of**
`docs/layer-7-music-arkos.md`; `python tools/akl/verify_akl.py` re-proves the player in one
command (`tools/akl/README.md`).

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

`tools/build.sh` is the same invocation from bash - same names, same disc titles, flags from the
environment (`RELEASE=1 GFX_CPC=1 sh tools/build.sh`). It exists because that stderr behaviour makes
`build.ps1` unusable from a shell that treats a PowerShell error record as a failure. **`build.ps1`
is still the build**; keep the two in step if either changes.

`!BOOT` is assembled by `main.asm` at `BOOT_STAGE` = `&2600` - inside the sprite saves, which do not
exist at assembly time - rather than in the code image's address space, where it was costing 200
bytes of the tightest region in the build for text nothing executes (decision 49). It stamps the
assembly time with beebasm's `TIME$` so any disc
image can be dated, and says `DEV build` unless `RELEASE`. **Every compile flag that changes
what the disc contains is stamped there** (KC), so a build cannot lie about itself: add any
new `DEBUG_` flag to `DEBUG_ANY` and to the stamp, and stamp anything that is legal under
`RELEASE` - like `MUSIC_AKL` - outside the `RELEASE` test rather than with the debug flags.

There are no automated tests. The check for a change meant to be mechanical is: extract `Edge`
and `BANK0` from the old and new SSD catalogues and compare (see `docs/layer-0-toolchain.md`).

## Source organisation (`src/`)

Single-pass flat build, everything included from `main.asm`, labels global.

| File | Contents |
|---|---|
| `main.asm` | constants, zero page map, boot, main loop, `scroll_frame` / `scroll_advance` / `scroll_prewind`, SAVEs, `!BOOT`, the `&0800` game-state block, includes. Then, **above `code_end` and therefore boot-only**: the loader (`load_stream`, `unpack_to`, `panel_init`, `load_bank`, `load_hazel`) and **the memorial's palette fade** (`memorial`, `mem_ramp`, `fade_pal`, Layer 9d). Neither is called once the game is running, and neither has to fit under `SPR_SAVE` |
| `scroll.asm` | map reader, tile readers, column buffer, column copy |
| `sprite.asm` | the sprite engine: `SCANSTEP`, `spr_restore_all`, `spr_draw_all`, clipping, the hit-flash tables |
| `keyboard.asm` | `keydown` (direct VIA matrix read) and `read_joystick`, which packs the five keys into the C64's `$dc00` byte |
| `player.asm` | movement, fire latch, bullet, background collisions, grind scoring, score, `game_tick`, and the life cycle: `life_cycle`, `life_lost`, `game_over_init`, `player_dropin`, `comp_tick` |
| `enemy.asm` | the wave manager and reader, enemy movement, bounds, the two enemy collision passes, explosions |
| `rupture.asm` | the two-cycle rupture, IRQ handler and install, and the VSync-side call into the music player |
| `data/palette.asm` | generated: the sixteen bytes `setup_display` writes to `&FE21`, from `assets/art/palette.png`. INCLUDEd from `main.asm` beside `tables.asm` - **boot-only main RAM, not bank 0**. beebasm will not INCLUDE inside a braced block, which `setup_display` is, and bank 0 has no room anyway |
| `tables.asm` | initialised main-RAM data. It sits ABOVE `SPR_SAVE`'s base and is therefore **boot-only** - the disc filenames and the OSFILE block. Nothing read in play may go here (`BUGS.md` #13); the mutable state lives at `&0800` (see `main.asm`) |
| `zx0depack.asm` | the ZX0 depacker, lifted from Paradroid. Boot code, called only by the loader; the last thing in the image and the one part allowed above `SPR_SAVE`'s base |
| `loading.asm` | the loading screen's two disc files, `LOADSC1` and `LOADSC2` |
| `panel.asm` | the status panel image as the disc file `PANEL` (decision 47), the C64's or - under `GFX_CPC` - the Amstrad's (decision 56). It used to live in bank 3; it is 3,200 bytes read exactly twice, and bank 3's tail is where the tune has to be. **The titles' second credit set rides on the end of it** and lands at `&3C80`, above the panel and below the play buffer, which neither rupture cycle fetches (decision 53) |
| `andy.asm` | ANDY's share of the tune as the disc file `ANDY`: 4K at `&8000-&8FFF`, ROMSEL bit 7 (decision 48). Loaded before `MUSIC` and unpacked after it, because the loader cannot write into ANDY while the filing system is running |
| `bank0.asm` | the SWRAM data bank, plus the run-once and out-of-room code: `setup_display`, `clear_play`, `panel_init`, `score_boot`, `status_call`, `title_page`, `pause_check`, `comp_mess`, `finale_tick`, the frame meter |
| `bank1.asm` | the SWRAM sprite bank for pixel shift 0, and after it **the titles' zoom scroller** (Layer 6e): its font, its message, its four-cycle rupture and the code that drives them. There because nothing on the titles reads a sprite, and reached through `bank_call` in main RAM. Then **the starfield** (Layer 9c, decisions 50 and 51): its tables in what used to be dead space below the tune's B1 stream, its code in the bank's tail. And the completion sequence's **"MEGA HERO" message** (Layer 9c), split the same way: its data and `mega_one` in the same hole, `mega_mess` and `mega_plot` in the tail. The 240-field loop is up here too, because `comp_mess` in bank 0 has sixteen bytes left |
| `bank2.asm` | the SWRAM sprite bank for pixel shift 1; then **`fade_pal` and the titles' credit crossfade** (Layers 9d and 9e), split either side of the tune stream at `&BA00` because neither the hole below it nor the tail above it would take both. Here because main RAM below `SPR_SAVE` had 68 bytes and bank 3 has 45 in a `-Cpc` build, and because nothing on the titles reads a sprite - the same reason bank 1 holds the zoom scroller |
| `music.asm` | the HAZEL image (`&C000-&DFFF`, ACCCON bit 3). Default: region A of the tune from `&C000`, the generated stream map and `lib/vgiplayer.asm` at `&D300`, its 11-page ring workspace at `&D500`. Under `MUSIC_AKL`: `aklplayer.asm` + `ay2sn.asm` at `&C000` and the whole tune as tracker data at `&CC00`. SAVEd as `MUSIC` and loaded LAST, because HAZEL is the filing system's own workspace |
| `aklplayer.asm` | `MUSIC_AKL` only: a 6502 port of Arkos Tracker 2's "lightweight" (AKL) replay, producing the fourteen AY registers a frame. X is the channel throughout, Y the byte offset being read. Byte-exact against Arkos's own player over all 17,446 frames |
| `ay2sn.asm` | `MUSIC_AKL` only: the runtime AY-3-8912 -> SN76489 conversion and `akl_silence`. SN period = 2 x AY period exactly (1 MHz AY, 4 MHz SN), octave-clamped to ten bits; a 32-entry volume LUT; the envelope **sampled**, not averaged |
| `bank3.asm` | compiled sprite bodies; the titles' font, credits and text plotter; **the memorial's message and `mem_page`** (Layer 9d), which is the half of it that needs the font; the HUD glyphs and `status_decode`; then region A of the tune from `&9100` to the join at `&C000`. Reached from main RAM through `bank3_call` |

`src/data/` (from Layer 1) is generated by the exporters in `tools/` and **is committed**;
regenerate with the tool rather than editing it. `build.ps1` does not run the exporters.

## Confirmed hardware facts (measured, not assumed)

- CRTC write windows (Paradroid, reconfirmed here): R4 inside its own cycle before C4 reaches
  it; R6 and R12/R13 inside the previous cycle; R7 can stay constant if only one cycle reaches it.
- VSync handler → fire 1 = 53 scanlines with `T1_I1 = 56*SL - 4*SL - 2`; fire 1 → fire 2 =
  40.0 scanlines with `T1_I2 = 40*SL - 2`. T1 ticks at 1 MHz, SL = 64. Measured 2026-09-02.
- OSFILE writes a file's catalogue addresses back into its parameter block after a load.
- **ANDY is 4K at `&8000-&8FFF`, selected by ROMSEL bit 7, and it overlays ONLY that 4K** - measured
  in jsbeeb 2026-09-04, from 6502 in main RAM. Writing `&AA` to `&8000` with bank 4 selected and
  `&55` to `&8000` with `&84` selected gives back `&55` under `&84` and `&AA` under `4`; `&9000` is
  the selected bank either way. The test has to be machine code: BASIC is itself the ROM at `&8000`,
  so paging ANDY in from a BASIC session removes the interpreter mid-statement and hangs.
- **We take HAZEL, so BREAK must clear memory.** HAZEL (`&C000-&DFFF`, ACCCON bit 3) is the filing
  system's workspace; `MUSIC` overwrites it, so `MUSIC` is loaded LAST and nothing touches the disc
  after it. A SOFT break would leave the wreckage in place - measured: no DFS banner and `*CAT`
  returns nothing. `OSBYTE 200, 3` at the top of `main` makes BREAK a power-on reset (bit 1) and
  disables ESCAPE with it (bit 0). Do not remove it, and do not add a disc access after the load.
- **The display wrap is the System VIA addressable latch, lines 4 and 5, and the four sizes are
  20K, 16K, 10K and 8K** - measured in jsbeeb 2026-09-04, not recalled. They are NOT powers of two,
  and the size is what is added back when the address passes `&8000`: line4/line5 = 0/0 wraps to
  `&4000` (16K, what `setup_display` sets), **1/0 to `&6000` (8K)**, 0/1 to `&3000` (20K, the MOS's
  own setting for MODE 2), 1/1 to `&5800` (10K). Written as `lda #4` / `lda #12` to `&FE40` for
  line 4, `#5` / `#13` for line 5.
- **The display bank can be switched INSIDE a frame**, and the change takes effect at the next
  character fetch - measured 2026-09-04, jsbeeb: ACCCON bit 0 (D) flipped by a VSync-synced delay
  loop puts main RAM above the switch and shadow below it, with a step part way along the scanline
  the write landed in. So a mid-frame flip is legal, and it must be placed in horizontal blanking.
  **jsbeeb only so far - b-em has NOT been checked**, and decision 17 is why that matters.
- **The wrap applies inside whichever bank is displayed.** With D = 1 and the wrap at 8K, a display
  crossing `&8000` lands on SHADOW `&6000`, not main. Measured 2026-09-04. Layer 6e's two zoom
  bands stand on it: one ring per bank, one band in each.
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

**[`docs/memory-map.md`](docs/memory-map.md) is the full map and the current free-space figures**,
per bank and per build, measured from the listings. The table below says what each region is FOR;
that one says how much of it is gone, and where the room that is left actually is.

| Region | Contents |
|---|---|
| ZP `&00-&9F` | variables, guarded; wiped at boot |
| `&0400-&049F` | column buffer, 160 B |
| `&04A0-&07BF` | collision character map, 40 × 20; `&07C0-&07FF` is its overrun slack. The language workspace - ours once `*RUN` has handed over, verified by sentinel |
| `&0800-&08E9` | game state: the C64's `$0340` block - `sprite_pos`, `sprite_dp`, the `enemy_*` arrays, the score, and what each bank's last sprite draw did. Declared after the SAVEs, so it is not in the image. `&0800-&0BFF` is MOS sound/serial/soft-key workspace, ours with the MOS interrupt gone - verified by sentinel |
| `&0C00-&0C5F` | `VGI_STATE`: the VGI player's 96 bytes of decode state, in the MOS user-font page (decision 49) |
| `&0E00-&1F67` | code read in play, and it ends at `code_end`. Above that, still in the image: the boot-only data, **the boot loader** and **the memorial's fade** (Layer 9d), then `src/zx0depack.asm`. `GUARD CODE_TOP` = `LOAD_STREAM` = `&2400`. `!BOOT` is assembled at `&2600`, not here: it is a disc file nothing loads or runs from RAM |
| after the code | initialised data, **boot-only because it is above `SPR_SAVE`**: the disc filenames and the OSFILE block. `explosion_dirs` used to be here and is in bank 1 now (`BUGS.md` #13) |
| to `&21F7` | the loader, the memorial's fade and `src/zx0depack.asm` - all boot code. **Deliberately above `SPR_SAVE`'s base**: they are dead before anything reads there. `&209` free to `LOAD_STREAM` in a DEV build |
| `&2000-&2FFF` | `SPR_SAVE`: saved background, 8 slots × 256 B × 2 banks, exactly. At boot it holds the loader and the depacker and, from `LOAD_STREAM` = `&2400`, the loading screen's streams. **`LOAD_STREAM` moved up from `&2200` in Layer 9d**, which leaves `LOADSC2`'s stream 252 bytes of headroom rather than 764; `tools/make_disc.py` refuses an image that has overrun it |
| `&3000-&7FFF` (main) | at boot only: the **loading screen**, a whole MODE 2 picture, displayed while the banks load |
| `&3000-&7FFF` (shadow) | at boot only: `DEPK_STREAM`, where the bank and music streams stage. Nothing is displaying it - the picture is in main |
| `&3000-&3C7F` × 2 | status panel, 5 rows × 640, in BOTH banks, displayed by rupture cycle A |
| `&4000-&7FFF` × 2 | play buffers, main and shadow |
| on the titles only | the display wrap goes to **8K**, so `&6000-&7FFF` is a ring in each bank: the top zoom band's is in MAIN, the bottom's in SHADOW, and the credits are 6 rows at `&4000` in SHADOW. `title_page` puts the 16K wrap back on the way out |
| ANDY `&8000-&8FFF` | the Master's own 4K, selected by **bit 7 of ROMSEL** and overlaying only the low 4K of whichever bank is paged - measured, see below. One of the tune's eleven streams (decision 48) |
| SWRAM slot 4 (`SWRAM_DATA`, resting state) | `BANK0`: `char_data &8000` (8K, four MODE 2 column planes), `tile_data` (211 × 16), `map_data` (302 × 5), `col_decode`, `wave_data` (201 × 9) and `anim_decode` |
| SWRAM slot 5 (`SWRAM_SPRITES0`) | `BANK1`: sprite data, pixel shift 0, then the titles' zoom scroller and its own rupture handler, then the starfield and the "MEGA HERO" message, then a tune stream at `&B900` |
| SWRAM slot 6 (`SWRAM_SPRITES1`) | `BANK2`: the same, shift 1, then **the titles' credit crossfade and `fade_pal`** (decision 53) either side of a tune stream at `&BA00` - a page higher than bank 1's, because the CPC artwork's sprite bank 2 is bigger. The two banks are identical in sprite layout and **must stay adjacent**: the engine adds the shift to `SWRAM_SPRITES0` |
| HAZEL `&C000-&DFFF` | `MUSIC`: region A of the tune from `&C000`, the stream map and the VGI player at `&D300`, its 11 x 256 ring workspace at `&D500`. ACCCON bit 3 (Y). Loaded LAST - it is the filing system's workspace - and nothing may touch the disc after it. **Region A begins at `&9100` in bank 3 and the two are one block**: the bank and HAZEL are visible at the same time, so a pointer walking off `&BFFF` lands in `&C000`, and two streams do |

Banks are loaded by `load_bank` (OSFILE the ZX0 stream to `DEPK_STREAM` in the shadow screen,
unpack straight into the paged-in slot) at boot, **after** the mode change, with the loading screen
up in main. **OSFILE overwrites its parameter block's addresses after a load**, so `load_stream`
resets load/exec before every call; without that the second file lands wherever the first said.

`src/data/*-cpc.bin` are the `GFX_CPC` build's copies of the same things, from the same
exporters run with `--cpc`; `tools/cpc/` holds the CPC readers (Extended DSK and AMSDOS, mode 0
screens and palettes, the background bank's indexing) and `tools/rip_cpc_sprites.py` and
`tools/rip_cpc_background.py` write that art out as sheets in the format of the C64 ones in
`assets/` and `reference/`.

**`tools/export_tiles.py`, `tools/export_sprites.py`, `tools/export_panel.py` and `tools/export_title.py` read `assets/art/*.png` by default** (Layer 8); `--c64` and `--cpc` reach the two mechanical conversions, which live in `tools/art/mechanical.py` now. A drop from the artist goes through `python tools/validate_art.py` first - it reports an off-palette colour, a half-width pixel or misplaced transparency with sheet, cell and pixel, and refuses rather than guessing - and `--roundtrip` re-proves that the PNG path adds and loses nothing.

`src/data/` is generated by `tools/export_tiles.py`, `tools/export_sprites.py`,
`tools/export_waves.py`, `tools/export_title.py`, `tools/export_panel.py`,
`tools/export_loading.py`, `tools/export_zoom.py` (whose message is **`assets/scrolltext.txt`**, an editable file - decision 54), `tools/export_mega.py`, `tools/export_music.py`,
`tools/export_music_akl.py` and
`tools/compile_sprites.py` from `assets/`, `data/`, `source_c64/data/`
and the C64 source itself, and is committed. `tools/render_bbc.py` renders it back to PNG for checking -
`render_bbc.py sprites 0|1` unpacks a whole sprite bank from its own box tables, which is the check
that the tables and the data agree.

**`tools/export_music.py` also decides where the tune goes** and writes `src/data/music_map.asm`
with it: it cuts the `.vgi` into its eleven register streams and best-fit packs them into the four
regions of decision 48, then generates the eleven addresses and eleven ROMSEL bytes the player
mounts from. The regions are hardcoded in both it and `main.asm`, and `music_map.asm` ASSERTs the
two agree. **`tools/verify_vgi.py` is the check that it worked**: it rebuilds the reference write
stream from the region binaries the build INCBINs and the map it assembles, and searches for a
jsbeeb `stop_sound_capture` log inside it. Nothing else catches a mis-placement - a wrong address
plays happily for thousands of frames before the stream runs off the end of what it was given.

## Facts about the current code that the old docs got wrong

- **Main RAM's real ceiling is `SPR_SAVE` = `&2000`, NOT `LOAD_STREAM` = `&2400`, for anything read
  or executed in play.** `&2000-&2FFF` is the blitter's saved-background area and is rewritten every
  frame from the first sprite onwards. Boot code and boot data may live there and do -
  `src/zx0depack.asm`, the loader, the memorial's fade, the OSFILE block, the disc filenames, and
  `!BOOT` at `&2600` - because they
  are dead before anything reads there. A runtime table drifted over the line unnoticed and the
  player's explosion pieces stopped flying (`BUGS.md` #13). `main.asm` now carries
  `ASSERT code_end <= SPR_SAVE`, and the listing prints CODE CEILING beside it; the build's FREE
  figure is measured to `LOAD_STREAM` and overstates the room for anything permanent.
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
- **The offline chain is not a per-frame register mapping.** `ym2sn.py` does whole-song analysis:
  it picks a priority bass channel and synthesises sub-122 Hz tones with periodic noise, and it
  averages the hardware envelope across each frame. A runtime converter cannot reproduce either,
  so the `MUSIC_AKL` build is the tune *re-voiced*, not the same tune smaller. `tools/sn2wav.py`
  renders a `.vgm` or a captured `.snf` to a WAV so the two can be compared by ear.
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
