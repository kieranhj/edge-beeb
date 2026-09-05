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
| [`docs/layer-history.md`](docs/layer-history.md) | **What each finished layer did and what it cost** - the detail this file used to carry |
| `docs/layer-*.md` | One per layer, linked from the layer table at the end |

## Where we are

**Layers 0 to 5, 6a-6e, 7, 8a, 9a-9f are done (2026-09-05). One defect is open: `BUGS.md` #14.**

The game assembles from `src/` through `build.ps1` — beebasm, then `tools/make_disc.py` — into
`build/EDGE.SSD`, and boots in jsbeeb and b-em as a Master. It is a complete game: a
1-pixel-per-frame 25 Hz scroller in MODE 2 under the C64's own status panel, held by a two-cycle
CRTC rupture with IRQ1V owned; eight software sprites; the player, his bullet and the original's
201 attack waves; three lives, the six-piece explosion, game over and the completion sequence; the
HUD; the whole 349-second tune on the SN76489; a parallax starfield; a loading screen with every
data file ZX0-compressed; a memorial to T.M.R. between the two; and a titles page with the zoom
scroller running across it twice over and the credits cross-fading between the C64's and this
port's.

**What each finished layer did, and what it cost, is in**
[**`docs/layer-history.md`**](docs/layer-history.md), with the per-layer documents behind it.
This file carries only what is still live.

### The frame budget

79,872 cycles at 25 Hz, measured with the frame meter (`src/timing.asm`, `DEBUG_TIMING`) rather
than estimated. **Ordinary play peaks at 90%, plus 4.3% for the music and 1.7% for the starfield.**
The stress test — fire held, the ship parked so it dies over and over — reaches 105% and misses
seven flips in 2,500 frames. The costed options for buying margin back are in `BUGS.md` #9 and in
the Blitter Anatomy artifact: per-row spans recover a quarter of the bytes the blitter touches, and
compiling the densest explosion frames recovers half the cycles but does not all fit. The starfield
is the cheapest lever if it is ever needed — the cost is linear in the star count.

### Memory

**Main RAM** (Layer 9f build, DEV, C64 artwork; take live figures from the listing, not from
here). Code, boot-only data, the boot loader, the memorial's own half and the ZX0 depacker run
`&0E00-&2222`, with **478 bytes** free below `LOAD_STREAM` = `&2400` - but that is not the number
that matters. **The ceiling for anything read in play is `SPR_SAVE` = `&2000`, and `code_end` is
`&1FD3`: 45 bytes under it in a DEV build, 74 in a RELEASE one.** Nothing was checking once, and
`explosion_dirs` drifted over the line into the blitter's save area and the player's explosion
pieces stopped flying (`BUGS.md` #13, fixed; `main.asm` asserts the ceiling now and the listing
prints CODE CEILING beside it).

**Layer 9d is where the boot loader moved out**, which is what this file and the memory map both
said the next thing to want main-RAM code would have to do: `load_stream`, `unpack_to`,
`panel_init`, `load_bank`, `unpack_andy` and `load_hazel` are dead before the first sprite is drawn
and sit above `code_end` now, with `!BOOT` and the depacker. That took the ceiling from 7 bytes
free to 153, and 9d, 9e and 9f have since spent 108 of them. `LOAD_STREAM` went from `&2200` to
`&2400` with it, which costs the loading screen headroom: `LOADSC2`'s stream has 252 bytes to
`&3000` rather than 764, and `tools/make_disc.py` refuses an image that overruns it.

**Where the room is now**, largest first, and the CPC-artwork figure where it differs:

| | DEV, C64 art | `-Cpc` |
|---|---|---|
| `&3C80-&3FFF`, in each bank (decision 53, proved by sentinel) | **706** | 706 |
| the `&0800` game-state block | ~610 | ~610 |
| bank 1, the hole below the tune | **475** | 469 |
| bank 2, the hole below the tune | 220 | **38** |
| bank 3, below the tune | 251 | **43** |
| `&0C00`, the MOS user-font page | 160 | 160 |
| bank 2, the tail above the tune | 106 | 106 |
| ANDY | 98 | 98 |
| bank 1, the tail above the tune | 86 | 86 |
| **main RAM below `SPR_SAVE`** | **45** | 45 |
| HAZEL, above the music player | 38 | 38 |
| region A of the tune | 32 | 32 |
| **bank 0** | **9** (175 in RELEASE) | 9 |

**The three tight ones are bank 0's 9 bytes, main RAM's 45, and - in a `-Cpc` build - bank 2's 38
and bank 3's 43.** That is what the next layer will hit first, and it is why 9e's fade went to bank
2 and 9f's scrolltext to `&3C80` rather than staying where they naturally belonged. `&3C80` is the
one big piece left: 706 bytes in each bank, proved by reading the credits back byte for byte after
a full game, and reached by putting data on the end of the `PANEL` file. Per-bank detail is in
[`docs/memory-map.md`](docs/memory-map.md); `&0D00` is still unproved.

Game state `&0800-&0985`; collision character map `&04A0-&07BF`; sprite save area `&2000-&2FFF`;
panel `&3000-&3C7F` in both banks, with the titles' second credit set and the scrolltext just above
it. **All four sideways RAM banks are in use**: 4 data, 5 sprites/zoom scroller/starfield, 6
sprites plus the palette fade and the credit crossfade, 7 compiled bodies plus the titles' font and
the HUD - and all four carry a piece of the tune.
### Two things built and taken out again

Both are worth not rediscovering. **ESCAPE at any time**, rather than only from inside the pause:
it is polled every frame, so holding it re-entered `life_lost` and rebuilt the player's explosion
pieces on the spot. It would want a debounce; abort stays a pause-only key (decision 54). And
**timing the rupture switch to the five rows after VSync**, which is `BUGS.md` #14 below: two
placements were tried and both were worse than doing nothing.

## What is left

Anything that deviates from the C64 original is a numbered decision agreed with KC first.

### 9g — the titles switch flicker — the one open defect

`BUGS.md` #14, measured and diagnosed 2026-09-04. The switch between the game's two-cycle rupture
and the titles' four-cycle one costs **one malformed field** — 272 lines against 312 — every time a
game starts and every time the titles come back. It is sync, not content: both transitions are
already blanked with R8. Three things must change together — R7, the display wrap, and which
handler owns the T1 fires — and `rupt_vsync` schedules those fires from `ttl_active`, so **the
switch has to be made inside the VSync handler**, the only place that owns all three at one
instant. Two placements in `title_page` were tried and both were worse; the numbers and both dead
ends are in the bug. Bank 0 has 9 bytes left, so the pending-shape byte wants main RAM or the
handler's own bank.

### 9c — the features still outstanding

Three of the seven the 2026-09-04 survey found; the other four are built, and the survey itself —
including what was checked and needs nothing — is in
[`docs/layer-history.md`](docs/layer-history.md).

**The win tune.** `source_cpc/Music/` holds **two** songs: `EDGEA.SKS`, which is ours, and
**`WON4.SKS`, 1,536 bytes** — a quarter the size. The CPC switches to it the moment the mega-hero
build starts (`ld a,2 : ld (ChangeMusic),a` in `Compiled_Main3.asm`) and keeps it through the
bonus and the explosion finale, switching back to the main theme on the way out. The C64 has one
tune and never changes it, so this is the CPC's addition — but our music is the CPC's already.
Under `MUSIC_AKL` it is another block of tracker data and a re-init; under VGI it is another set
of eleven streams for `export_music.py` to place, and `verify_vgi.py` to prove.

**Redefinable keys.** Z/X/K/M/L/P/Q/ESCAPE are hardcoded and measured (`CLAUDE.md`). The CPC
reads three schemes at once — joystick, QAOP + space, or the cursor keys — and the standing note
in `CLAUDE.md` is that every `DEBUG_` key will need CTRL once the game has redefinable controls.
Needs a front end to define them in and somewhere to keep them.

**A BBC scroll text — the mechanism is done, the words are not.** Layer 9f made the message
`assets/scrolltext.txt`, seeded with the C64's own 468 characters and with 237 more to grow into;
editing it and re-running `tools/export_zoom.py` is the whole job now. What is missing is the
text: something about this port, appended to the original's or in place of it. **KC's to write.**

### Layer 7, second pass - the Arkos replay - built, and the choice is open

[`docs/layer-7-music-arkos.md`](docs/layer-7-music-arkos.md), decision 40. `.\build.ps1 -Akl`
builds a second disc in which `src/aklplayer.asm` replays the **Arkos tracker data itself** and
`src/ay2sn.asm` converts to the SN76489 every frame, instead of the VGI player decoding a
pre-converted register log. The whole 349-second tune is 4,741 bytes that way, so player, converter
and tune together are 7,640 and **fit in HAZEL alone** - the tune leaves bank 3 and takes 12,288
bytes of it with it. It costs +854 us on the worst frame and nine missed flips against seven, on the
same brutal test. **Its size advantage is gone**: decision 48 got the whole tune into the VGI build
too, so what is left to choose between them is purely how they sound.

The replay is not in doubt: byte-exact against Arkos's own player over all 17,446 frames, and twelve
fields captured out of the running game match the simulation uniquely. **What is open is how it
sounds.** `ym2sn.py` does whole-song analysis a per-frame converter cannot - a priority bass channel
synthesised with periodic noise, the hardware envelope averaged across each frame - so the Arkos
build is the tune *re-voiced*, not the same tune smaller.

**PARKED 2026-09-04, to come back to.** It blocks nothing; the default build is unchanged. The next
steps are pinned at the top of [`docs/layer-7-music-arkos.md`](docs/layer-7-music-arkos.md) under
"PICKING THIS UP AGAIN", in the order they should be taken:

1. **Noise rate 3, the tuned noise** clocked by tone generator 3. `ym2sn` uses it on 1,701 frames
   and `src/ay2sn.asm` never emits it - the largest remaining difference on percussion, and the
   likeliest thing still to sound wrong. (KC already caught one drum bug by ear; that one was
   `BUGS.md` #12, the white-noise feedback bit, and is fixed.)
2. **Average the hardware envelope across the frame** instead of sampling it once. It drives a
   channel's volume on 33% of the tune and is why envelope frames agree on only 3.6% of tone
   periods. A few hundred cycles a frame.
3. **Listen again, then decide.** `python tools/akl/verify_akl.py --snf build/runtime.snf` then
   `tools/sn2wav.py`. Drums are densest at 49-79 s, envelopes at 33-63 s.
4. If it ships, `MUSIC_AKL` stops being a switch and decision 40 gets rewritten from "open" to a
   decision. If it does not ship, keep it: it is a working Arkos replay for the BBC and the next
   project may want it.
5. If it is to be a tool for other projects, the arpeggio-table, pitch-table, soft-and-hard and
   five of the seven effect paths need a test tune - EDGEA exercises none of them.

`python tools/akl/verify_akl.py` re-proves the whole thing in one command
([`tools/akl/README.md`](tools/akl/README.md)); it should print `IDENTICAL on every frame` and
`{'ch2 period': 11}`, and that 11 is the correct answer, not a defect.

### Layer 8 — graphics pipeline B (the artist) — built

Decisions 58-62, [`docs/layer-8-art-pipeline.md`](docs/layer-8-art-pipeline.md). `PROPOSAL.md`
§5.2's Phase B: the characters, the sprites, **the status panel, the HUD font, the title
page's font** and **the palette** are read from PNGs in `assets/art/` now, seeded from the conversion the game already
ran on, so the artist repaints a working game.

**Five sheets, all at 2:1** — `chars.png` 128x128 (256 characters of 4x8 fat pixels),
`sprites.png` 192x336 (frames 0-118 of 12x21), `panel.png` 320x40 (the status bar as a picture,
at the size it appears), `hud.png` 128x8 (blank, the digits 0-9, the life marker's two halves)
and `titlefont.png` 128x16 (blank, A-Z, `! . , - ?`). The last three cost almost nothing to add:
a panel cell, a HUD glyph, a title glyph and a character are all the same 4x8 shape, so one
reader does all five (decisions 61, 62). **A sheet carries the logical colours it may use**, which
is what keeps the title font on entries 12/14/15 where the credit crossfade needs it - they are
the same RGB as 4/6/7, so the obvious rule would have looked right and faded the panel too. Characters are the
paintable surface and tiles are not: the tile definitions and the map are index tables shared verbatim with the C64 and CPC
ports, and the charset is reused about thirteen times over them, so `render_bbc.py tiles` and
`map` regenerate the assembled views instead of them being what he edits. Grey `96,96,96` is
see-through (sprites only); orange `255,128,0` marks a cell **not drawn yet** and falls back to
the mechanical conversion, so a partial drop still builds a complete game.

**No new build symbol.** The PNGs feed the same `src/data/*.bin` the build already INCBINs;
`--c64` and `--cpc` on the exporters still reach the two mechanical conversions, and all eight
combinations of `RELEASE` x `MUSIC_AKL` x `GFX_CPC` assemble.

**The palette is a file** (`assets/art/palette.png` -> `src/data/palette.asm`), which is what
makes an eventual NULA cheap: the exported data already stores a full 4-bit logical per fat
pixel, so sixteen colours cost no change to it at all. What a NULA would still need is the
`&FE23` write and, genuinely, new **fades** — the memorial and the credit crossfade both walk
MODE 2's eight-colour brightness ladder and sixteen free colours have no such ladder.

The tools: `tools/seed_art.py` (write the sheets from either conversion), `tools/validate_art.py`
(what a drop goes through on receipt — exact palette with coordinates, fat-pixel doubling,
transparency rules, blank-character count for the starfield, the HUD-cell warning, and
`--roundtrip`), `tools/export_palette.py`, and `tools/art/` behind them.

**Still to do on the NuLA builds** (KC, 2026-09-05), none of them started:

1. **Fade the loading screen out.** `fade_pal` is a cut under `GFX_NULA` (see the layer doc):
   the memorial's fade down from the loading picture, its fade up, and the fade back out are all
   thresholded rather than walked. A real one means scaling sixteen 12-bit colours towards
   black, which wants 128-256 bytes of ramp table against bank 2's 86 free — so it is a memory
   map job first and a code job second.
2. **Correct the title screen palette for both NuLA builds, rasters included.** Two halves.
   The credits' three inks are logicals 12/14/15 by decision 53, which the eight-colour build
   needs and NuLA does not; and `ttl_raster` writes `&FE21` every scanline to cycle the zoom
   bands, which under logical colour mapping (decision 64) is simply ignored, so the bands do
   not pulse at all. Both want the title page to program its own NuLA entries instead — which
   is also the shape of the answer to decision 53's three-colour limit
   ([`docs/layer-9e-credits.md`](docs/layer-9e-credits.md)), so the two should be done together.
3. **The C64's and the CPC's own intro screens, at their own palettes.** The loading picture is
   `assets/TitlescreenBig.png`, hand-drawn in the BBC's eight, and it is the same picture in
   every build. A NuLA build could show the original's instead, matching its artwork — the C64's
   for `-Nula` and the Amstrad's for `-Nula -Cpc`. Neither has been located or ripped yet, so
   that is the first step, and the loader's two-halves-and-a-ZX0-stream constraint (decision 38)
   applies to whatever comes back.

The zoom scroller's font and the loading screen stay as they are, KC explicitly; `mega.bin` is
not a font either. Still to do: a `-Gallery` debug build, and the transport question
(`PROPOSAL.md` §5.2, decision 4) — a mirrored shared folder or the artist committing to
`assets/` himself.

**And decision 53's three-colour limit on the title font is flagged for revisiting** (KC): the
palette can be reprogrammed per CRTC cycle and the titles already take an interrupt at each of
their four, so the credits could have a palette of their own — or the titles and the game need
not share one at all. The last section of
[`docs/layer-9e-credits.md`](docs/layer-9e-credits.md) is the write-up, with the two things to
weigh first (`&FE21` is on the 1 MHz bus, and the memorial draws through this font with
interrupts off).

### Layer 8a — the CPC artwork, behind `GFX_CPC` — built

Decision 41, [`docs/layer-8a-gfx-cpc.md`](docs/layer-8a-gfx-cpc.md), described in
[`docs/layer-history.md`](docs/layer-history.md). A comparison build like `MUSIC_AKL`, and the
choice between it, the C64 conversion and the hand-authored redraw of Layer 8 is KC's.

**Recoloured 2026-09-05 (decision 55).** A pen is a *dither pair* now, not one BBC colour:
Rich Talbot-Watkins's scheme approximates each of the CPC's 27 colours with two MODE 2
colours checkerboarded a pixel at a time. `reference/cpc-palette-map-to-bbc-mode2.png` is the
chart, `bbc.dither_pair` the rule, and the flat nearest-hue table it replaces is gone.

**Panel and HUD 2026-09-05 (decision 56).** The switch reaches the status bar now: the panel
image, the score font and the life marker are the Amstrad's, out of `EG_Panel.asm` and
`EG_GameFont.ASM` through `tools/cpc/paneldata.py`. Its panel is four character rows to the
C64's five, so it sits in rows 0-3 with row 4 black; its HUD is in the same cells as ours, so
nothing in `src/` changed but two `INCBIN`s.

**The compiled bullet is back 2026-09-05 (decision 57).** The 13 bytes bank 3 was short of in
Layer 8a were found by decisions 47 and 49; it assembles with 43 to spare, so both builds run
the same code path. `python tools/verify_compiled.py [--cpc]` proves the bodies against the
interpreted path by simulating the emitted 6502.

Still to do: real-hardware test, release build, publish. The starfield is 9c above, and is the
CPC's rather than the C64's.

### Layer 8b — two VideoNuLA test builds — built

Decision 63, [`docs/layer-8b-nula.md`](docs/layer-8b-nula.md). `.\build.ps1 -Nula` is the C64
artwork at the C64's own sixteen colours; `-Nula -Cpc` is the Amstrad's at its own sixteen pens.
References rather than candidates: sixteen logical colours and sixteen source colours, so
nothing is approximated, and decision 11's hue collapse and decision 55's dither both go away —
the scenery is brown rather than blue and a CPC pen is one colour again.

**jsbeeb emulates the NuLA palette and both builds are verified in it** (decision 67). That
was not believed when the layer was written, and believing otherwise is what let decision 63's
`&FE21` mistake reach KC's hardware — see the layer doc. `tools/render_bbc.py --nula [--cpc]`
renders the data without booting anything.

The register pair and byte order come from the VideoNuLA User Guide and the encoder reproduces
its worked example. **Decision 64 corrected the one thing decision 63 inferred rather than
measured**: NuLA's default is to MIMIC the Video ULA, composing `&FE21` in front of `&FE23`, so
the titles' `ttl_raster` was leaving logical 15 on physical 7 and the CPC art's background pen
came back blue. `&FE22 = &11` selects logical colour mapping and makes `&FE21` ignored, which
is what this game wants. Found by KC on hardware, from `reference/cpc-nula-bug1.png`.

**The fades are cuts and the credit crossfade does not run** — a real NuLA fade wants 128–256
bytes of ramp table against bank 2's 86 free, and the crossfade needs three spare palette
entries that sixteen real colours do not leave. Both are written up, and the second is decision
53's constraint biting harder rather than differently.

### Polish, parked: the CPC's grind sparks

**KC, 2026-09-05, playing the `-Cpc` build**, alongside the hit-flash bug of decision 65: *"the
player has a custom spark effect when grinding the walls - it doesn't turn to a solid colour as
we have it today."* Correct, and it is a real difference between the two originals.

The C64 flashes the ship: `sprite_pls_tmr` is set, `xploder_2` swaps `sprite_col_dcd`'s low
nibble for its high one, and the player's dps `$0B-$11` go cyan → purple. We transcribe that
and every build does it. **The Amstrad draws a different ship instead.**
`PlayerFrameGrindList` is a second seven-entry frame list indexed by the same `PlayerFrame`
0-6, and `PrintSprites` picks it whenever `GrindState` is non-zero — set to **2** on contact,
not 1, because the top and bottom edges are tested on alternate frames and the state has to
outlive one of them. The ship is replaced, never recoloured, and it sparks.

**The frames rip cleanly and the ripper is committed**: `tools/rip_cpc_compiled.py`, which
reads them back out of the compiled Z80 in `EG_Sprites_Player_Grind.asm` and **proves itself**
on the way past — run over `EG_Sprites_Player.asm` it must reproduce SPRITES.BIN's frames 11-17,
the player's own dp range, at 126 bytes of 126, all seven. `reference/grind-sparks-cpc.png` is
what they look like.

**It does not fit, which is why it is parked.** Boxed at both shifts they want **636 bytes in
sprite bank 1 and 742 in bank 2**, and a `-Cpc` build has **21 and 86** free. The frame tables
have room (seven more sit under the 128 stride) and no new `dp_dcd` entries are needed — it is
purely pixels. The only room that exists anywhere near those two banks is the VGI tune streams
they carry, 1,273 bytes in bank 1 and 1,351 in bank 2, which **a `-Akl` build removes
entirely**. So this joins the win tune as a reason to prefer `MUSIC_AKL`, and it is gated on
the same pending decision — KC's ear.

What it would need beyond the bytes: seven frames appended to the CPC sprite banks, and one
test in the draw path — slot 0 with its pulse timer running takes `frame + offset` and the
identity LUT instead of the flash LUT. The `sprite_pls_tmr` the grind already sets is exactly
the CPC's `GrindState`, including the 2, so no new state is needed.

### Open: the win tune

The CPC has **two** songs and we ship one. `source_cpc/Music/WON4.SKS` is its end-game tune, 66.2
seconds, and `EG_Interrupts2.asm` switches to it by re-initing the Arkos replay at a second address.
Measured 2026-09-05, both ways, and the answer is lopsided — see the last section of
[`docs/memory-map.md`](docs/memory-map.md):

* **VGI build (default): it does not fit.** 2,889 bytes of `.vgi` against 1,757 free, and its
  largest single stream (494 bytes) is bigger than the largest hole in the machine (bank 1's 475),
  so no placement exists at all. Truncated to ~20 seconds it fits with a working margin; 30 would
  leave a `-Cpc` build 192 bytes for everything else, ever.
* **`-Akl` build: 695 bytes, whole, untruncated.** Bank 3 alone has 12,280 free there, `akl_init`
  already takes a song address in A/X, and re-initing at a second one is exactly what the CPC does.

So it is a reason to prefer `MUSIC_AKL`, not something to squeeze into the VGI build. **KC's ear on
the `-Akl` tune is the decision that gates it**, and that is still pending
([`docs/layer-7-music-arkos.md`](docs/layer-7-music-arkos.md)). No decision taken.

### Release

Real-hardware test, a `-Release` build, and publish. `publish-wip` puts the current disc on
bitshifters.github.io for testing.

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
| 7b — the Arkos replay | [`docs/layer-7-music-arkos.md`](docs/layer-7-music-arkos.md) | **parked 2026-09-04**, behind `MUSIC_AKL`. Works; next steps pinned in the doc |
| 8 — graphics pipeline B | | |
| 8 — the artist's PNGs | [`docs/layer-8-art-pipeline.md`](docs/layer-8-art-pipeline.md) | **built 2026-09-05**, decisions 58-62. Characters, sprites, the status panel, the HUD font, the title font and the palette come from `assets/art/*.png`; seeded from the C64 conversion, so the disc is unchanged until the artist starts work. NULA-ready by construction |
| 8b — the NuLA test builds | [`docs/layer-8b-nula.md`](docs/layer-8b-nula.md) | **built 2026-09-05**, decisions 63-64. `-Nula` and `-Nula -Cpc`: the two sources at their own sixteen colours, nothing approximated. Untestable here - jsbeeb has no NuLA - so KC's hardware or b2 is the check |
| 8a — the CPC artwork | [`docs/layer-8a-gfx-cpc.md`](docs/layer-8a-gfx-cpc.md) | **built 2026-09-04**, behind `GFX_CPC`, and all eight flag combinations assemble; **recoloured 2026-09-05** to Rich's MODE 2 dither pairs (decision 55). Which artwork ships is KC's choice |
| 9a — loading screen, ZX0 disc | [`docs/layer-9-loader.md`](docs/layer-9-loader.md) | done 2026-09-04 |
| 9b — Q mutes the tune | [`docs/layer-7-music.md`](docs/layer-7-music.md) | done 2026-09-04 |
| 9c.1 — the parallax starfield | [`docs/layer-9c-starfield.md`](docs/layer-9c-starfield.md) | done 2026-09-04, decisions 50 and 51 |
| 9c.2 — the "MEGA HERO" message | [`docs/layer-9c-mega-hero.md`](docs/layer-9c-mega-hero.md) | done 2026-09-04 |
| 9c.3 — the win tune | | **open**: `WON4.SKS`, the CPC's second song, for the completion sequence |
| 9c.4 — redefinable keys | | **open**: needs a front end and somewhere to keep them |
| 9c.5 — the loading fade and the T.M.R. card | | done as **9d** below |
| 9c.6 — the credits crossfade | | done as **9e** below |
| 9c.7 — a BBC scroll text | [`docs/layer-6e-titles.md`](docs/layer-6e-titles.md) | **half open**: the mechanism is done as 9f (decision 54) and the words are KC's to write |
| 9d — the memorial | [`docs/layer-9d-memorial.md`](docs/layer-9d-memorial.md) | done 2026-09-04, decision 52 |
| 9e — the credits crossfade | [`docs/layer-9e-credits.md`](docs/layer-9e-credits.md) | done 2026-09-04, decision 53 |
| 9f — SPACE starts, and an editable scrolltext | [`docs/layer-6e-titles.md`](docs/layer-6e-titles.md) | done 2026-09-04, decision 54. It is 9c.7's mechanism |
| 9g — the titles switch flicker | [`BUGS.md`](BUGS.md) #14 | **open 2026-09-05**: measured and diagnosed, not fixed. One malformed field, 272 lines against 312, every time the rupture shape changes. The switch has to be made inside `rupt_vsync`, which is the only place that owns the registers and the T1 schedule at once; two placements in `title_page` were tried and both were worse |
| 9 — polish and release | | real-hardware test, a `-Release` build, publish |
