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
| [`docs/layer-history.md`](docs/layer-history.md) | **What each finished layer did and what it cost** — the detail this file used to carry |
| [`docs/memory-map.md`](docs/memory-map.md) | The full memory map and the current free-space figures, per bank and per build |
| `docs/layer-*.md` | One per layer, linked from the layer table at the end |

## Where we are

**Layers 0–5, 6a–6e, 7, 8, 8a, 8b, 9a–9f are done (2026-09-05). One defect is open:
`BUGS.md` #14.**

The game assembles from `src/` through `build.ps1` into `build/EDGE.SSD` and boots in jsbeeb and
b-em as a Master. It is a complete game: a 1-pixel-per-frame 25 Hz scroller in MODE 2 under the
C64's own status panel, held by a two-cycle CRTC rupture with IRQ1V owned; eight software sprites;
the player, his bullet and the original's 201 attack waves; three lives, the six-piece explosion,
game over and the completion sequence; the HUD; the whole 349-second tune on the SN76489; a
parallax starfield; a loading screen with every data file ZX0-compressed; a memorial to T.M.R.
between the two; and a titles page with the zoom scroller running across it twice over and the
credits cross-fading. Four artwork builds exist behind flags, and the artist can repaint any of
it — including the level itself — through `assets/art/`.

**What each finished layer did, and what it cost, is in**
[**`docs/layer-history.md`**](docs/layer-history.md). This file carries only what is still live.

## What is left

Anything that deviates from the C64 original is a numbered decision agreed with KC first.

### The one open defect — 9g, the titles switch flicker

`BUGS.md` #14, measured and diagnosed 2026-09-04. The switch between the game's two-cycle rupture
and the titles' four-cycle one costs **one malformed field** — 272 lines against 312 — every time
a game starts and every time the titles come back. It is sync, not content: both transitions are
already blanked with R8. Three things must change together — R7, the display wrap, and which
handler owns the T1 fires — and `rupt_vsync` schedules those fires from `ttl_active`, so **the
switch has to be made inside the VSync handler**, the only place that owns all three at one
instant. Two placements in `title_page` were tried and both were worse; the numbers and both dead
ends are in the bug. Bank 0 has 9 bytes left, so the pending-shape byte wants main RAM or the
handler's own bank.

### The decision that gates three other things — KC's ear on the `-Akl` tune

`.\build.ps1 -Akl` replays the Arkos tracker data at runtime instead of a pre-converted register
log (decision 40). The replay is proven byte-exact; **what is open is how it sounds**, the offline
chain doing whole-song analysis a per-frame converter cannot. Its size advantage is gone since
decision 48, so the choice is purely the voicing — and it is not only a music decision, because
a `-Akl` build frees the 2,624 bytes of tune stream that sprite banks 1 and 2 carry. **The win
tune and the CPC's grind sparks both need that room.**

**Parked 2026-09-04.** It blocks nothing that cannot wait, and the default build is unchanged.
The next steps are pinned in order at the top of
[`docs/layer-7-music-arkos.md`](docs/layer-7-music-arkos.md) under "PICKING THIS UP AGAIN"; the
first two are noise rate 3 (the tuned noise, 1,701 frames, the likeliest thing still to sound
wrong) and averaging the hardware envelope across the frame rather than sampling it.
`python tools/akl/verify_akl.py` re-proves the whole thing in one command.

### The win tune — measured, and it only fits one way

The CPC has **two** songs and we ship one: `source_cpc/Music/WON4.SKS`, 66.2 seconds, which
`EG_Interrupts2.asm` switches to by re-initing the Arkos replay at a second address the moment the
mega-hero build starts, and switches back on the way out. The C64 has one tune and never changes
it, so this is the CPC's addition — but our music is the CPC's already. Measured 2026-09-05 both
ways; the answer is lopsided, and the working is in the last section of
[`docs/memory-map.md`](docs/memory-map.md):

* **VGI build (the default): it does not fit.** 2,889 bytes of `.vgi` against 1,757 free, and its
  largest single stream (494 bytes) is bigger than the largest hole in the machine (bank 1's 475),
  so **no placement exists at all**. Truncated to ~20 s it fits with a margin; 30 s would leave a
  `-Cpc` build 192 bytes for everything, ever.
* **`-Akl` build: 695 bytes, whole and untruncated.** Bank 3 alone has 12,280 free there, and
  `akl_init` already takes a song address in A/X.

So it is a reason to prefer `MUSIC_AKL`, not something to squeeze into the VGI build, and it is
gated on the decision above. No decision taken.

### The CPC's grind sparks — parked for the same reason

**KC, 2026-09-05, playing the `-Cpc` build:** *"the player has a custom spark effect when grinding
the walls — it doesn't turn to a solid colour as we have it today."* Correct, and a real
difference between the originals. The C64 flashes the ship (`xploder_2` swaps `sprite_col_dcd`'s
nibbles, dps `$0B-$11` cyan → purple) and we transcribe that in every build. **The Amstrad draws a
different ship instead**: `PlayerFrameGrindList` is a second seven-entry frame list indexed by the
same `PlayerFrame`, picked whenever `GrindState` is non-zero.

**The frames rip cleanly and the ripper is committed** — `tools/rip_cpc_compiled.py`, which reads
them out of the compiled Z80 and proves itself on the way past against SPRITES.BIN's own player
frames. `reference/grind-sparks-cpc.png` is what they look like.

**It does not fit.** Boxed at both shifts they want **636 bytes in sprite bank 1 and 742 in bank
2**, and a `-Cpc` build has **21 and 86** free. The frame tables have room and no new `dp_dcd`
entries are needed — it is purely pixels, and the only room anywhere near those two banks is the
VGI tune streams they carry. Beyond the bytes it needs seven frames appended to the CPC sprite
banks and one test in the draw path: slot 0 with its pulse timer running takes `frame + offset`
and the identity LUT. `sprite_pls_tmr` is already exactly the CPC's `GrindState`, the 2 included.

### Redefinable keys

Z/X/K/M/L/P/Q/ESCAPE are hardcoded and measured (`CLAUDE.md`). The CPC reads three schemes at once
— joystick, QAOP + space, or the cursor keys. Needs a front end to define them in and somewhere to
keep them, and every `DEBUG_` key will need CTRL once it exists.

### A BBC scroll text — the mechanism is done, the words are not

Layer 9f made the message `assets/scrolltext.txt`, seeded with the C64's own 468 characters and
with 237 more to grow into; editing it and re-running `tools/export_zoom.py` is the whole job.
What is missing is the text: something about this port, appended to the original's or in place of
it. **KC's to write.**

### The NuLA builds — three jobs, none started

KC, 2026-09-05. `-Nula` and `-Nula -Cpc` are built and verified in jsbeeb (decision 67); these are
what they still lack.

1. **Fade the loading screen out.** `fade_pal` is a cut under `GFX_NULA`: the memorial's fade down
   from the loading picture, its fade up and the fade back out are all thresholded rather than
   walked. A real one means scaling sixteen 12-bit colours towards black, which wants 128–256
   bytes of ramp table against bank 2's 86 free — **a memory-map job first and a code job
   second**.
2. **Correct the title screen palette, rasters included.** Two halves. The credits' three inks are
   logicals 12/14/15 by decision 53, which the eight-colour build needs and NuLA does not; and
   `ttl_raster` writes `&FE21` every scanline to cycle the zoom bands, which under logical colour
   mapping (decision 64) is simply ignored, so the bands do not pulse at all. Both want the title
   page to program its own NuLA entries — **which is also the shape of the answer to decision 53's
   three-colour limit, so the two should be done together.**
3. **The C64's and the CPC's own intro screens, at their own palettes.** The loading picture is
   `assets/TitlescreenBig.png` in every build. A NuLA build could show the original's instead.
   Neither has been located or ripped yet, so that is the first step, and decision 38's
   two-halves-and-a-ZX0-stream constraint applies to whatever comes back.

### Flagged for revisiting — the title font's three colours

KC. Decision 53 gives the credit font logicals 12/14/15 so the crossfade can own three palette
entries nothing else on the titles uses; `TITLE_FADE` in `tools/art/palette.py` enforces it and a
fourth ink is refused. The palette can be reprogrammed per CRTC cycle and the titles already take
an interrupt at each of their four, so the credits could have a palette of their own — or the
titles and the game need not share one at all. The write-up, with the two things to weigh first
(`&FE21` is on the 1 MHz bus, and the memorial draws through this font with interrupts off), is
the last section of [`docs/layer-9e-credits.md`](docs/layer-9e-credits.md). It is the same job as
NuLA item 2 above.

### The artist pipeline — what is left of it

The tools are done ([`docs/layer-8-art-pipeline.md`](docs/layer-8-art-pipeline.md)); these are not.

* **The transport question** (`PROPOSAL.md` §5.2, decision 4): a mirrored shared folder, or the
  artist committing to `assets/` himself. Still open, and it is the thing that has to be settled
  before any of the rest of it matters.
* **A `-Gallery` debug build** that pages through every sprite and tile on the machine itself
  (`PROPOSAL.md` §5.2.4). Worth an hour when there is art to look at.
* The zoom scroller's font and the loading screen stay as they are, KC explicitly; `mega.bin` is
  not a font either.

### Which artwork ships

Four builds exist — the C64 conversion, `-Cpc`, the artist's PNGs, and the two `-Nula` references
— and **the choice is KC's**, not a technical question. Nothing else waits on it.

### Release

Real-hardware test, a `-Release` build, publish. `publish-wip` puts the current disc on
bitshifters.github.io for testing. `-Cpc` needs the same three.

## What the next job is working against

### The frame budget

79,872 cycles at 25 Hz, measured with the frame meter (`src/timing.asm`, `DEBUG_TIMING`) rather
than estimated. **Ordinary play peaks at 90%, plus 4.3% for the music and 1.7% for the
starfield.** The stress test — fire held, the ship parked so it dies over and over — reaches 105%
and misses seven flips in 2,500 frames. The costed options for buying margin back are in
`BUGS.md` #9: per-row spans recover a quarter of the bytes the blitter touches, and compiling the
densest explosion frames recovers half the cycles but does not all fit. The starfield is the
cheapest lever if it is ever needed — the cost is linear in the star count.

### Memory

**Take live figures from the listing, and the full picture from
[`docs/memory-map.md`](docs/memory-map.md).** Three numbers decide where the next thing goes:

| | DEV, C64 art | `-Cpc` |
|---|---|---|
| **main RAM below `SPR_SAVE` = `&2000`** — the ceiling for anything read in play | **45** | 45 |
| **bank 0** | **9** (175 in RELEASE) | 9 |
| **banks 2 and 3, below the tune** | 220 / 251 | **38 / 43** |

Those are what the next layer will hit first, and they are why 9e's fade went to bank 2 and 9f's
scrolltext to `&3C80` rather than staying where they belonged. **The room that is left**, largest
first: the `&0800` game-state block, **623** to `GAME_STATE_TOP`; bank 1's hole below the tune,
**475** (**469** with the CPC art), which Layer 9f opened by moving the scrolltext out; `&3C80` in
*each* bank, **237** apiece now that 9e and 9f have spent 659 of the 896 — the build prints it as
SCROLLTEXT HEADROOM — reached by putting data on the end of the `PANEL` file (decision 53); then
`&0C00`'s 160 and the two bank tails at 86 and 106. `&0D00` is still unproved.

**All four sideways RAM banks are in use** — 4 data, 5 sprites/zoom scroller/starfield, 6 sprites
plus the palette fade and the credit crossfade, 7 compiled bodies plus the titles' font and the
HUD — and all four carry a piece of the tune, which is what a `-Akl` build would give back.

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
| 6e — title screen | [`docs/layer-6e-titles.md`](docs/layer-6e-titles.md) | done 2026-09-04 |
| 7 — music | [`docs/layer-7-music.md`](docs/layer-7-music.md) | done 2026-09-04, the whole 349 s tune in four regions |
| 7b — the Arkos replay | [`docs/layer-7-music-arkos.md`](docs/layer-7-music-arkos.md) | **parked**, behind `MUSIC_AKL`. Works; gated on KC's ear, and it gates the win tune and the grind sparks |
| 8 — the artist's PNGs | [`docs/layer-8-art-pipeline.md`](docs/layer-8-art-pipeline.md) | done 2026-09-05, decisions 58-62 and 68. Five sheets, the palette, and the level itself paintable |
| 8a — the CPC artwork | [`docs/layer-8a-gfx-cpc.md`](docs/layer-8a-gfx-cpc.md) | done 2026-09-05, behind `GFX_CPC`, decisions 41, 55-57 |
| 8b — the NuLA test builds | [`docs/layer-8b-nula.md`](docs/layer-8b-nula.md) | done 2026-09-05, decisions 63, 64, 67. **Three jobs outstanding**, above |
| 9a — loading screen, ZX0 disc | [`docs/layer-9-loader.md`](docs/layer-9-loader.md) | done 2026-09-04 |
| 9b — Q mutes the tune | [`docs/layer-7-music.md`](docs/layer-7-music.md) | done 2026-09-04 |
| 9c.1 — the parallax starfield | [`docs/layer-9c-starfield.md`](docs/layer-9c-starfield.md) | done 2026-09-04, decisions 50 and 51 |
| 9c.2 — the "MEGA HERO" message | [`docs/layer-9c-mega-hero.md`](docs/layer-9c-mega-hero.md) | done 2026-09-04 |
| 9c.3 — the win tune | | **open**, and it only fits a `-Akl` build |
| 9c.4 — redefinable keys | | **open**: needs a front end and somewhere to keep them |
| 9c.7 — a BBC scroll text | [`docs/layer-6e-titles.md`](docs/layer-6e-titles.md) | **half open**: the mechanism is 9f, the words are KC's |
| 9d — the memorial | [`docs/layer-9d-memorial.md`](docs/layer-9d-memorial.md) | done 2026-09-04, decision 52 |
| 9e — the credits crossfade | [`docs/layer-9e-credits.md`](docs/layer-9e-credits.md) | done 2026-09-04, decision 53. Its three-colour limit is flagged for revisiting |
| 9f — SPACE starts, an editable scrolltext | [`docs/layer-6e-titles.md`](docs/layer-6e-titles.md) | done 2026-09-04, decision 54 |
| 9g — the titles switch flicker | [`BUGS.md`](BUGS.md) #14 | **open 2026-09-05**: measured and diagnosed, not fixed |
| 9 — polish and release | | real-hardware test, a `-Release` build, publish |

*9c.5 and 9c.6 were built as 9d and 9e. The 2026-09-04 survey that found the seven 9c features is
in [`docs/layer-history.md`](docs/layer-history.md).*
