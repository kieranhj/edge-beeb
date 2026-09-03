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

**Layers 0 to 4 are done (2026-09-03).** The game assembles from `src/` through `build.ps1` into
`build/EDGE.SSD` and boots in jsbeeb and b-em as a Master. What runs: a 1-pixel-per-frame 25 Hz
horizontal scroller in MODE 2 (two phase-offset shadow screens, hardware 16K wrap, one byte column a
frame through a 160-byte column buffer) drawing from an offline-converted charset with the C64's
per-character colours, under a 5-row status panel held by a two-cycle CRTC rupture, with IRQ1V
owned, the keyboard read direct and the bank flip done by the VSync handler on a two-field lock;
over it eight software sprites, clipped, restored and redrawn every frame in both banks; and a
**playable player** - Z/X/K/M/L, the C64's bounds and fire latch, a bullet, background
collision off our own character map, grinding that scores and flashes. No enemies and no game flow
yet: `DEBUG_SPRITES` still fills slots 2-7 with drifting test enemies and `DEBUG_COLL` makes a fatal
hit flash rather than kill.

**The frame budget** is 79,872 cycles at 25 Hz. Measured with eight sprites live: the scroll column
11,153, the sprite restore 15,093, the draw 34,143, and the two logic ticks about 1,600 - roughly
**62,000, or 78%**, leaving ~18,000 for the waves, collisions and the music.

**Main RAM** (Layer 4 build): code `&0E00-&1BB0`, tables to `&1E29`, **`&1D7` free** below `&2000`
(the code image's ceiling) - tight, and Layers 5 and 6 add the most code. `&04A0-&07BF` is the
collision character map with `&07C0-&07FF` its overrun slack; `&2000-&2FFF` the sprite save area;
the panel `&3000-&3C7F` in both banks. **Bank 0** high water `&B500`; **bank 1** (sprites, shift 0)
`&B153`; **bank 2** (shift 1) `&B78B`. Take live figures from the build listing, not from here.

## What is left

Layers in order. Each is built, seen working in the emulator and written up in `docs/` before the
next starts. Anything that deviates from the C64 original is a numbered decision agreed with KC
first.

### Layer 1 — graphics pipeline A — done

[`docs/layer-1-graphics-pipeline.md`](docs/layer-1-graphics-pipeline.md). Exporters in `tools/`,
committed output in `src/data/`, `render_bbc.py` for desktop checks. Sprite data consumption
deferred to Layer 3.

### Layer 2 — display — done

[`docs/layer-2-display.md`](docs/layer-2-display.md). Two-cycle rupture with the panel at
`&2000`, IRQ1V owned, VSync-side bank flip on `FRAME_LOCK`, direct keyboard, palette, frame
counter, map wrap at 302 columns. Timings measured.

### Layer 3 — sprite engine v2 — done (first pass)

[`docs/layer-3-sprites.md`](docs/layer-3-sprites.md). Eight software sprites in both banks:
bounding-boxed MODE 2 data in two banks (one per pixel shift), mask from the data byte, save area
mirroring screen geometry one page per slot per bank at `&2000`, `SCANSTEP` with the deferred carry
and the 16K wrap inline, restore replaying the draw, clipping at all four edges, hit flash on the
ORA table, and a walked fallback for rows straddling the buffer wrap. **Measured: 6,155 cycles a
sprite**, 49,236 for eight, 60,389 with the scroll — 76% of the frame.

Interpreted throughout: the compiled player and bullet of `PROPOSAL.md` §3.6 are **not** built
(decision 19), because the interpreted path fits. Three things are still open and are listed at the
end of the layer doc: the bank phase wants an eye on it in b-em (decision 22), `SPR_X_OFF`/
`SPR_Y_OFF` are confirmed by Layer 4, and there is still no buffer oracle.

### Layer 4 — player — done

[`docs/layer-4-player.md`](docs/layer-4-player.md). Movement and bounds, the fire latch, the bullet,
both background collision checks, grind scoring and the six-digit score, transcribed from the C64.
Two structural decisions: the **game logic ticks twice per display frame** (decision 23), so the
original's per-frame constants transcribe unaltered; and background collision reads a **character
map we keep ourselves** at `&04A0` (decision 24), since the C64 reads codes out of a screen we do
not have. The keys are Z/X left/right, K/M up/down and L to fire (decision 26).

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
| 2 — display | [`docs/layer-2-display.md`](docs/layer-2-display.md) | done 2026-09-02 |
| 3 — sprite engine v2 | [`docs/layer-3-sprites.md`](docs/layer-3-sprites.md) | done 2026-09-03 |
| 4 — player | [`docs/layer-4-player.md`](docs/layer-4-player.md) | done 2026-09-03 |
| 5 — enemies | | next |
| 6 — game flow | | |
| 7 — sound | | |
| 8 — graphics pipeline B | | |
| 9 — polish and release | | |
