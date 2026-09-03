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

**Layers 0 to 5 are done (2026-09-03).** The game assembles from `src/` through `build.ps1` into
`build/EDGE.SSD` and boots in jsbeeb and b-em as a Master. What runs: a 1-pixel-per-frame 25 Hz
horizontal scroller in MODE 2 under a 5-row status panel held by a two-cycle CRTC rupture, with
IRQ1V owned and the bank flip done by the VSync handler on a two-field lock; eight software sprites
over it, clipped and redrawn every frame in both shadow banks; a player on Z/X/K/M/L with the C64's
bounds, fire latch, bullet and background collisions; and **the attack waves**, spawning from the
original's own 201-wave table, flying its movement commands, shootable for score, and able to run
into you. What is missing is the game *around* it: `coll_flag` and `comp_flag` are set and nothing
reads them, so there are no lives, no respawn and no end. The panel still shows a colour-bar
placeholder and `DEBUG_COLL` makes a fatal hit flash rather than kill.

**The frame budget** is 79,872 cycles at 25 Hz. Measured, worst case with eight sprites live: scroll
11,153, sprite restore 15,093, sprite draw 34,143, and the two logic ticks 3,278 — **63,667, or
80%**. The pool is often not full, and an empty slot costs the blitter nothing.

**That figure is now known to be optimistic and the frame does overrun.** `BUGS.md` #9: the game
drops below 25 Hz while shooting, about 50 s in. The draw was measured while `BUGS.md` #8 was
silently skipping every sprite past x = 140, so enemies entering from the right cost nothing then
and cost full price now; explosion frames are the densest artwork in the game and shooting is what
makes them. **Settle this before Layer 6 puts a HUD on every frame** — if it is the budget, the
answer is the compiled blitter deferred in decision 19.

**Main RAM** (Layer 5 build): code and tables `&0E00-&1F88`, **`&78` free** below `&2000` — Layer 6
will not fit without moving something else out. Game state `&0800-&08E9`; collision character map
`&04A0-&07BF`; sprite save area `&2000-&2FFF`; panel `&3000-&3C7F` in both banks. **Bank 0** (chars,
tiles, map, col_decode, waves) high water `&BC38`; **banks 1 and 2** (sprites, one per pixel shift)
`&B153` and `&B78B`. Take live figures from the build listing, not from here.

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

### Layer 5 — enemies — done

[`docs/layer-5-enemies.md`](docs/layer-5-enemies.md). `wave_manager`, `wave_read` and the **201-wave**
table (not 54, as this file used to say), the two-command movement model with its rocker timer,
shields, bullet-to-enemy and player-to-enemy collisions, and the explosion frames. The wave table and
`anim_decode` are exported to bank 0 (decision 28) and the whole game-state block moved to `&0800`
(decision 27), because the image no longer had room for the layer.

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
| 5 — enemies | [`docs/layer-5-enemies.md`](docs/layer-5-enemies.md) | done 2026-09-03 |
| 6 — game flow | | next |
| 7 — sound | | |
| 8 — graphics pipeline B | | |
| 9 — polish and release | | |
