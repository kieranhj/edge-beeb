# Edge Grinder → BBC Master 128: Port Plan

**The live planning document. Read it at the start of a session: it is the state of the port and
the list of what is left, and nothing else.**

Everything *finished* keeps its detail in [`docs/`](docs/): the measurements, the dead ends and the
options that were costed and rejected. When a layer's detail stops being needed to decide what to
do next, it moves there. `CLAUDE.md` holds the standing rules, the build, the hardware facts and the
memory outline, and is loaded every session, so this file does not repeat them.

| | |
|---|---|
| [`PROPOSAL.md`](PROPOSAL.md) | The 2026-09-02 proposal: what Paradroid taught us, the sprite engine design, the artist pipeline, and the five decisions KC took |
| [`BUGS.md`](BUGS.md) | Open defects, indexed in a table at the top. Fixed entries stay for what they ruled out |
| [`docs/decisions.md`](docs/decisions.md) | The decision table of record |
| `docs/layer-*.md` | One per layer, linked from the layer table at the end |

## Where we are

**Layers 0 and 1 are done (2026-09-02).** The scroller assembles from `src/` through `build.ps1`
into `build/EDGE.SSD` and boots in jsbeeb as a Master. What runs: a 1-pixel-per-frame 25 Hz
horizontal scroller in MODE 2 (two phase-offset shadow screens, hardware 16K wrap, one byte column
a frame through a 160-byte column buffer) drawing from an offline-converted charset with the C64's
per-character colours, and one player sprite moved by Z/X/:/? with a background stash. Nothing
else of the game exists yet. The sprite still reads raw C64 data from bank 1; `src/data/sprites.bin`
is exported in the Layer 3 format but unused until then.

**The frame budget** is 79,872 cycles at 25 Hz. The scroll column costs about 9,000 (estimated,
not yet measured). The current sprite plotter is estimated at 17-18,000 per sprite per frame,
which is why Layer 3 replaces it before any second sprite is added.

**Main RAM** (Layer 1 build): code `&0E00-&13C0`, tables to `&1813`, `&27ED` bytes free below the
screen at `&4000`. **Bank 0** (chars, tiles, map, col_decode) high water `&B500`, `&B00` free;
**bank 1** (raw sprites) `&9DC0`. Take live figures from the build listing, not from here.

## What is left

Layers in order. Each is built, seen working in the emulator and written up in `docs/` before the
next starts. Anything that deviates from the C64 original is a numbered decision agreed with KC
first.

### Layer 1 — graphics pipeline A — done

[`docs/layer-1-graphics-pipeline.md`](docs/layer-1-graphics-pipeline.md). Exporters in `tools/`,
committed output in `src/data/`, `render_bbc.py` for desktop checks. Sprite data consumption
deferred to Layer 3.

### Layer 2 — display

CRTC rupture with the status panel at `&2000` (Paradroid's `rupture.asm` and its write-window
rules), IRQ1V taken over with vsync and timer 1, `&FE34` flipped in the vsync handler, keyboard read
direct from the System VIA, a real frame counter (drop `char_col`'s double duty), the palette
written to `&FE21`, both maps wired in and the level end handled. Verify the register windows in
jsbeeb; do not write CRTC code from recalled facts.

### Layer 3 — sprite engine v2

`PROPOSAL.md` §3. Slot table for eight sprites, one save page per slot per bank at `&3000`
(self-selecting via the shadow X bit; verify), mask-from-data table, restore backwards / draw
forwards, `SCANSTEP` with deferred carry and the 16K wrap inline, horizontal and vertical clipping
on the interpreted path, compiled player and bullet, hit-flash recolour table. **Measure** with
jsbeeb and record cycles per sprite in `docs/layer-3-sprites.md`. Target: eight sprites moving at
25 Hz inside budget.

### Layer 4 — player

Movement bounds (C64 x `$10-$9b`, y `$5a-$e5`, converted), fire latch, bullet at 12 px per frame
collision-checked twice a frame as the CPC does, player-to-background collision via the fatal
nibble of `col_decode`, bullet-to-background, grind scoring.

### Layer 5 — enemies

`wave_manager` / `wave_read` and the 54-wave table verbatim, movement commands, rocker timer,
shields, bullet-to-enemy and player-to-enemy collisions, explosion frames.

### Layer 6 — game flow

Lives, respawn shield timer, 6-digit BCD score and hi-score, HUD on the panel, state machine
(titles → init → loop → life lost → game over; completion sequence), title screen with the zoom
scroller, pause and Q-to-abort.

### Layer 7 — sound

CPC `.SKS` tunes through the nova-invite toolchain to a VGC stream, played from the 50 Hz
interrupt; sound effects on the SN76489.

### Layer 8 — graphics pipeline B (the artist)

`PROPOSAL.md` §5.2. Palette file and templates out, `validate_art.py` in (exact palette, pair
doubling, frame count, silhouette check against the mechanical tiles), partial-sheet fallback,
gallery debug build, `publish-wip` links for testing.

### Layer 9 — polish and release

Starfield, ZX0 disc compression if boot time warrants it, real-hardware test, release build,
publish.

## Layer index

| Layer | Doc | State |
|---|---|---|
| 0 — toolchain, source split, docs | [`docs/layer-0-toolchain.md`](docs/layer-0-toolchain.md) | done 2026-09-02 |
| 1 — graphics pipeline A | [`docs/layer-1-graphics-pipeline.md`](docs/layer-1-graphics-pipeline.md) | done 2026-09-02 |
| 2 — display | | next |
| 3 — sprite engine v2 | | |
| 4 — player | | |
| 5 — enemies | | |
| 6 — game flow | | |
| 7 — sound | | |
| 8 — graphics pipeline B | | |
| 9 — polish and release | | |
