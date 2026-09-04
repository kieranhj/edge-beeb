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

**Layers 0 to 5, 6a-6d and 7 are done (2026-09-04).** The game assembles from `src/` through `build.ps1` into
`build/EDGE.SSD` and boots in jsbeeb and b-em as a Master. What runs: a 1-pixel-per-frame 25 Hz
horizontal scroller in MODE 2 under a 5-row status panel held by a two-cycle CRTC rupture, with
IRQ1V owned and the bank flip done by the VSync handler on a two-field lock; eight software sprites
over it, clipped and redrawn every frame in both shadow banks; a player on Z/X/K/M/L with the C64's
bounds, fire latch, bullet and background collisions; and **the attack waves**, spawning from the
original's own 201-wave table, flying its movement commands, shootable for score, and able to run
into you; and **the life cycle** — three lives, the six-piece player explosion, the drop-in shield,
game over and a new game; and **the state machine** — a titles page carrying the original's own
credits, pause on P, abort on ESCAPE, and the completion sequence the wave table's end triggers;
and **the HUD** - the original's own status bar, rendered whole from its charset and its colour
map, with the score, the high score and the lives bars decoded onto it every frame; and **the
music**, the CPC port's own tune on the SN76489, played from the VSync interrupt out of HAZEL. The
titles are static until 6e gives them the zoom scroller, the completion's "mega hero" message waits
for a font to draw it with, and **the tune is truncated to 203 of its 349 seconds because it does
not fit** - `docs/layer-7-music.md` costs the ways out and wants a decision.

**The frame budget** is 79,872 cycles at 25 Hz. Measured with the frame meter (`src/timing.asm`,
`DEBUG_TIMING`) rather than estimated: **100 seconds of play peaks at 72,106, 90%, with no missed
flips**, and eight explosions on screen at once cost 66,960, 84%. `BUGS.md` #9 - the game dropping
below 25 Hz while shooting - is fixed: the walked path for a sprite crossing the end of the 16K
buffer was 97 cycles a byte against 36, and was being taken on 12% of sprites where 1.4% needed it.

The old estimate of 63,667 was optimistic by 45%, because it was taken while `BUGS.md` #8 was
silently skipping every sprite past x = 140.

**6d turned out to be free**: the HUD paints only the cells that changed, per bank, and costs about
370 cycles on its worst frame - nothing measurable on the total. **The music costs 3,394 cycles a
game frame, 4.3%**, which is the first real bite anything has taken out of the budget since 6a.

The same 100-second stress test - fire held down, the ship parked, so it dies over and over and the
screen is full of explosions - now runs at **105% with seven missed flips in 2,500 frames**, against
101% and four before the music. Ordinary play is the gentler 90% figure plus the same 4.5%. The
costed options for buying margin back are in `BUGS.md` #9 and in the Blitter Anatomy artifact:
per-row spans recover a quarter of the bytes the blitter touches, and compiling the densest
explosion frames recovers half the cycles but does not all fit.

**Main RAM** (Layer 7 build, DEV): code and tables `&0E00-&1FCB`, **`&35` free** below `&2000`.
That is with `DEBUG_TIMING` on; `game_init` moved to bank 0 in Layer 7 to make room for the HAZEL
loader and the IRQ's music call. Bank 0 has `&B2` left; **bank 3 is full** - its code and data end
at `&9C3D` and the tune's low half runs `&9D00-&BFFF` - and **HAZEL** (`&C000-&DFFF`) holds the
tune's high half, the player at `&D200` and its ring workspace at `&D500`, with `&DF` free;
`pause_check`, `comp_mess` and `finale_tick` are up in bank 0 because main RAM ran out mid-layer,
alongside the frame meter, `coll_row_lo/hi` and the boot-time display setup; the multiply tables are
gone entirely, and the titles' font and text, the panel image and the HUD are in bank 3. **All four
sideways RAM banks are now in use**: 4 data, 5 and 6 sprites, 7 compiled bodies plus the titles and
the panel (9.1K free). Game state `&0800-&08E9`; collision character map
`&04A0-&07BF`; sprite save area `&2000-&2FFF`; panel `&3000-&3C7F` in both banks. **Bank 0** (chars,
tiles, map, col_decode, waves) high water `&BEEE`; **banks 1 and 2** (sprites, one per pixel shift)
`&B253` and `&B88B`. Take live figures from the build listing, not from here.

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

### Layer 6 — game flow, in five parts

Split 2026-09-03 because the original layer was four unrelated jobs in a bundle, and because
`BUGS.md` #9 has to be settled before anything else is allowed onto the frame.

#### 6a — the frame budget — done, in two parts

`BUGS.md` #9 settled. The frame meter (`src/timing.asm`, behind `DEBUG_TIMING`, its code in
sideways bank 0 because main RAM had none to spare) times each phase of the loop off the User VIA's
T2 and counts the frames that miss their flip. It found the overrun, and it found that all of it was
the walked path for a sprite straddling the end of the buffer.

Two changes, both resting on the same observation - **at most one character row of a sprite can
straddle, and within it the split column is the same for all eight scanlines**. First
`spr_straddle_exact`, so only the sprites that really cross take the slow route; then the slow route
itself replaced by `spr_draw_row_split` / `spr_rest_row_split`, which draw that one character row as
two ordinary ladder calls with the same bias on both pointers. `spr_draw_row_slow`,
`spr_rest_row_slow`, `spr_next_col` and `spr_mul8` are gone.

Room for it came from moving `coll_row_lo/hi` to bank 0 and deleting all four multiply tables for
the shifts that were hiding in them - 336 bytes of table for about 60 of code.

Then **the bullet was compiled** (decision 29). Sideways slot 7 - the fourth of the Master's four
sideways RAM banks, measured unused - now holds straight-line 6502 for the frames worth it, both
pixel shifts together, because a compiled body reads no sprite data. The bullet was the best
candidate in the game and the cheapest: 15 x 6 bytes of box holding 40 opaque, one frame, no hit
flash, 2,652 bytes of code. Measured 1,614 cycles against about 4,100 interpreted, and firing no
longer moves the frame's peak at all. `tools/compile_sprites.py` generates it; `compiled_zp.asm`
asserts the zero page it bakes in.

**The explosion is parked.** Same 2.4x ratio and it is what makes the busiest frames, but all eleven
frames are 34 KB; the four or five densest would fit slot 7 alongside the bullet. Revisit when
Layer 6d needs the room, with the Blitter Anatomy artifact's table for which frames earn it.

Room for the dispatch came from moving `setup_display`, `clear_play` and `panel_init` to bank 0:
they run once at boot with bank 0 resting and nothing else calls them. The IRQ handler and
`install_irq` stay in main RAM, where they must be.

#### 6b — the life cycle — done

[`docs/layer-6b-life-cycle.md`](docs/layer-6b-life-cycle.md). `coll_flag` is read: three lives, the
player bursting into six pieces on `explosion_dirs`' own vectors, the drop-in shield, and the
game-over sequence — the player and his bullet gone, the level running out for &c8 ticks, then a
new game. `life_cycle` sits at the end of `game_tick`, where the C64 has it, so its &32 and &c8
transcribe unaltered under decision 23.

It also found `BUGS.md` **#10**, a Layer 5 defect that had never been reachable: `wave_manager`'s
no-free-slot path skipped eight bytes of a nine-byte wave, and nothing had ever filled all six slots
at once until the player explosion did.

Two decisions. **30**: `DEBUG_COLL` becomes the C64's own "patch me out to disable collisions" and
defaults to 0 even in DEV. **31**: at zero lives the game re-inits in place, because there is no
title screen to go back to until 6e; the boot sequence is now `game_init` and the top of the main
loop calls it again on `restart_req`.

#### 6c — the state machine — done

[`docs/layer-6c-state-machine.md`](docs/layer-6c-state-machine.md). `master_loop`: titles →
`game_init` → play → life lost → game over or completion → titles. Only the titles are a loop of
their own; the rest share the main loop and are told apart by `game_mode`, which replaced 6b's
`player_live`. `frame_wait` and `field_wait` came out of the old inline loop — the still states wait
a field WITHOUT handing a frame over, so a paused picture is genuinely still.

**The titles are the original's credits page**, in the original's font: `status.chr` is a multicolour
set, so a character is four double-width pixels, which is one of our 4-fat-pixel cells exactly — the
C64's 38-column layout lands at 1:1 with no rescaling. `tools/export_title.py`; the data and its
plotter are in bank 3, reached through a trampoline in main RAM. The zoom scroller is still 6e.

**Completion** is the fly-off, the 5,000-a-life bonus and the explosion finale, all of it but the
"mega hero" message, which needs a font drawn for the job (Layer 8). Two decisions. **32**: P pauses,
ESCAPE aborts, both key numbers measured. **33**: the finale's positions come out of our own code,
which is what the C64 reads too.

#### 6d — the HUD — done

[`docs/layer-6d-hud.md`](docs/layer-6d-hud.md). The colour-bar placeholder is gone. The C64's status
bar is a fixed 5 x 40 character map assembled straight into its screen buffer in the multicolour
STATUS charset, so it transcribes at 1:1 like the credits page did: `tools/export_panel.py` renders
all 200 cells with their own colour-RAM bytes into a 3,200-byte MODE 2 image, and `panel_draw` is a
straight copy (decision 34, which also fixes the C64 -> MODE 2 colour mapping). `status_decode`
decodes the score, the high score and the lives bars, and paints **only the cells that changed, per
bank**; measured at about 370 cycles on its worst frame.

Everything is in bank 3, because main RAM had 36 bytes free and bank 0 had 151. 6c's
`title_text_call` became **`bank3_call`**, taking the target in X and Y - the only main-RAM cost of
the layer.

#### 6e — the title screen

The zoom scroller. Shares almost nothing with the rest, and is the first thing that will want the
`&FC` now free below `&2000`.

### Layer 7 — music — done, with the tune truncated

[`docs/layer-7-music.md`](docs/layer-7-music.md). `tools/export_music.py` runs EDGEA.SKS through
SongToYm, ym2sn and vgipacker; the **VGI** player (decision 35, KC) plays it from the end of
`rupt_vsync` at 50 Hz, where the C64 calls its own. The player and its workspace are in **HAZEL** (decision
36) - the only RAM left, and the only kind that does not collide with the sideways window the sprite
engine is paging while the IRQ fires - and **the tune spans the top of bank 3 and the bottom of
HAZEL as one contiguous block**, because the two are visible at the same time and a pointer walking
off `&BFFF` lands in `&C000`. Verified byte-exact: captured fields of SN76489 writes match VGM
frames 201-212 and nowhere else, and the loop restarts cleanly at 10,173.

**No sound effects, and that is faithful** - the C64 has none at all.

**Open: the tune is 349 seconds and 23,514 bytes of `.vgi`, and there are 13,562.** It ships as the
first 203 seconds, looped (decision 37). The layer doc costs the ways out - move the panel image out
of bank 3 to a boot-time load (71% of the tune, no format work), scatter the format's eleven
independent register streams into ANDY and the bank scraps as well (all of it), or cut the tune
musically - and all of them are KC's call.

### Layer 8 — graphics pipeline B (the artist)

`PROPOSAL.md` §5.2. Palette file and templates out, `validate_art.py` in (exact palette, pair
doubling, frame count, silhouette check against the mechanical tiles), partial-sheet fallback,
gallery debug build, `publish-wip` links for testing.

### Layer 9 — polish and release

**9a — the loading screen and ZX0 on the disc, done 2026-09-04.**
`assets/TitlescreenBig.png` goes up as soon as the mode is set and stays there until
`setup_display` takes over; behind it the four banks and the music load as before, but every data
file on the disc now ships ZX0-compressed and is unpacked into place. The mode change moved to the
front of boot — it was last because the banks staged through `&4000`, and they stage in the shadow
screen now. The picture is **two** disc files because a ZX0 stream cannot be overtaken by its own
output and one for the whole 20K screen would have to end past `&8000`; its halves stage at
`&2200`, below the screen. The depacker is Paradroid's, lifted, and verified byte-exact against the
source image in jsbeeb. 91,904 bytes of files becomes 37,632 — which, measured, pays for the
picture and no more: 11.1 s of loading becomes 10.9 s, with something to look at. Decision 38,
[`docs/layer-9-loader.md`](docs/layer-9-loader.md).

Still to do: starfield, real-hardware test, release build, publish.

## Layer index

| Layer | Doc | State |
|---|---|---|
| 0 — toolchain, source split, docs | [`docs/layer-0-toolchain.md`](docs/layer-0-toolchain.md) | done 2026-09-02 |
| 1 — graphics pipeline A | [`docs/layer-1-graphics-pipeline.md`](docs/layer-1-graphics-pipeline.md) | done 2026-09-02 |
| 2 — display | [`docs/layer-2-display.md`](docs/layer-2-display.md) | done 2026-09-02 |
| 3 — sprite engine v2 | [`docs/layer-3-sprites.md`](docs/layer-3-sprites.md) | done 2026-09-03 |
| 4 — player | [`docs/layer-4-player.md`](docs/layer-4-player.md) | done 2026-09-03 |
| 5 — enemies | [`docs/layer-5-enemies.md`](docs/layer-5-enemies.md) | done 2026-09-03 |
| 6a — frame budget | | done 2026-09-03 |
| 6b — life cycle | [`docs/layer-6b-life-cycle.md`](docs/layer-6b-life-cycle.md) | done 2026-09-03 |
| 6c — state machine | [`docs/layer-6c-state-machine.md`](docs/layer-6c-state-machine.md) | done 2026-09-03 |
| 6d — HUD | [`docs/layer-6d-hud.md`](docs/layer-6d-hud.md) | done 2026-09-03 |
| 6e — title screen | | |
| 7 — music | [`docs/layer-7-music.md`](docs/layer-7-music.md) | done 2026-09-04, tune truncated to 203 s |
| 8 — graphics pipeline B | | |
| 9a — loading screen, ZX0 disc | [`docs/layer-9-loader.md`](docs/layer-9-loader.md) | done 2026-09-04 |
| 9 — polish and release | | |
