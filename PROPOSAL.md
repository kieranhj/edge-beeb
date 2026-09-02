# Edge Grinder BBC port — proposal (2026-09-02)

How to finish this port, drawing on the Paradroid port (`C:\Users\khcon\OneDrive\Projects\Paradroid`,
2026-08-04 → 2026-09-02, 393 commits). Written after reading both code bases, the three notes files,
the C64 and CPC sources, and Paradroid's `CLAUDE.md`, `PLAN.md`, `docs/` and `BUGS.md`.

Everything below is a proposal. Items marked **[DECISION]** need an answer from KC before they are built,
following the Paradroid rule that deviations from the original are agreed first and written down after.

---

## 1. Where the two projects stand

### Edge Grinder today (`edge-beeb.asm`, 1572 lines, last real commit 2019)

Working: a 1-pixel-per-frame, 25 Hz horizontal scroller in MODE 2 on a **BBC Master 128**, and one
player sprite. Nothing else of the game exists (see `TODO.md`).

The scroll design is good and should be kept:

- **Two screens in shadow and main RAM at `&4000-&7FFF`, both hardware-wrapped at 16K**, holding the
  same picture **half a byte out of phase**. A CRTC step in MODE 2 is 2 pixels; the odd pixel comes from
  showing the other bank. The `&FE34` D/X bits flip every frame so the CPU always writes the hidden bank.
  This is exactly the scheme in `notes/edge-beeb.txt` and what the CPC does (minus the CPC's R3 trick,
  which the Beeb does not need).
- One new byte column per frame through a 160-byte **column buffer** that is shifted left one pixel and
  has the next map pixel ORed in — the CPC's tile writer, transcribed. About 9,000 cycles a frame.
- The tile/map readers are direct transcriptions of the C64 (`tile_update`, `map_read`, `tile_cnt_bump`).

Things the existing docs get wrong, found while reading:

1. **There is no sprite conversion pipeline.** `bin/convert_sprites.py` is an unfinished stub (syntax
   errors at lines 27-30) and `build/` is empty. The game `INCBIN`s the *raw C64* sprite data and converts
   nibbles to MODE 2 at plot time through two lookup tables. `CLAUDE.md` and `progress.md` both say
   otherwise.
2. **The target is a Master 128, not a Model B.** Shadow RAM via `&FE34` and ROM select via `&FE30/&F4`
   are Master idioms. `&8000-&BFFF` is sideways RAM holding data, not "screen buffer 2".
3. **The "double-buffer stash restore is broken" TODO item is probably wrong.** Both stash and restore in
   iteration *n* target the bank being drawn in iteration *n*, which was last drawn in *n-2* into stash
   `[n AND 1]`. The commented-out `eor #1` would make it *wrong*. Verify in the emulator before acting on
   it.
4. The palette constants `PAL_*` are never written to `&FE21`; the game runs in the default palette.
5. The C64 music is a black-box binary by Sean Connolly, not Arkos Tracker (that is the CPC's).

### Paradroid — what it taught us that transfers

| Paradroid practice | Transfers to Edge Grinder? |
|---|---|
| The original is the specification; port the *decision*, not just the effect; **[DECISION]** lists per layer | Yes, verbatim. The C64 source is 5,000 lines of clean, commented assembly — far easier than a disassembly |
| One layer at a time, visible in the emulator before the next; no HAL | Yes |
| **jsbeeb MCP** for measuring, not recalling, hardware facts | Yes — not yet configured for this repo |
| Verify against the buffer, not the screenshot (`RedrawAll` oracle, CTRL+R) | Yes — a "redraw the whole strip from the map at the current position" oracle is even easier here |
| Circular-strip play buffer, hardware wrap, only the leading edge is ever drawn | Already how Edge Grinder works |
| Three-cycle vertical rupture for a static panel above a scrolling area, with the CRTC write-window rules | Yes — this is how the status bar will be done |
| Own IRQ1V; keyboard direct from the VIA (69 cycles vs OSBYTE's 243) | Yes |
| Sprite slot model, save-area geometry trick, mask-from-data, deferred-carry `SCANSTEP`, restore-replays-the-draw | Yes, this is the core of §3 |
| Tranche split, `sprscan`/`sprsplit`, window A/B scheduling | **No.** That machinery exists only because Paradroid is single-buffered. Edge Grinder is double-buffered and does not need it |
| Four compiled shifts in two banks | Reduced to **two** shifts (0 and 1 px) in MODE 2, and only the player and bullet compiled |
| ZX0 disc compression, `make_disc.py`, padded 200K SSD, `build.ps1 -Release`, debug flags named at boot | Yes, lift the tools |
| Mechanical art conversion with a Python "palette lab" for hand-tuned decisions | Partly — Edge Grinder adds a **PNG import path** for the artist, which Paradroid never had |

Paradroid's binding constraint all month was RAM on a Model B (15 bytes free in the code image at the end).
On a Master with shadow RAM and four sideways banks Edge Grinder does not have that problem, and it
should not adopt Paradroid's contortions (low overlay, stack-page scavenging, bank-packing rules) unless a
measurement says so.

---

## 2. Target machine and memory map

**[DECISION 1] Master 128 only.** The 1-pixel scroll depends on two full 16K screens in a hardware wrap
region, which a Model B cannot provide (one wrap region, no shadow). Paradroid costed sub-4-pixel scrolling
on a B and rejected every option; on the Master it is what we already have. RTW reached the same
conclusion in `notes/rtw tech.txt` ("leave it unpacked if just targeting the Master"). A B+128 has shadow
RAM with different paging and could be a compatibility layer later; it is not in the plan.

Proposed layout (to be confirmed by measurement):

| Region | Contents |
|---|---|
| ZP `&00-&8F` | Variables (Paradroid's map style: scalars only) |
| `&0400-&04FF` | Column buffer (160 B) and small tables |
| `&0E00-&1FFF` | Resident code: main loop, IRQ/rupture, sprite engine core, keyboard |
| `&2000-&29FF` | **Status panel**: 4 rows × 640 B, displayed by rupture cycle 1. Sits below `&3000` so it is in main RAM under both shadow states and never inside the scrolling ring |
| `&2A00-&2FFF` | Lookup tables (mask-from-data, multiply, sprite address) |
| `&3000-&3FFF` × 2 | **Sprite background saves, one page per slot, in *both* shadow states.** The `&FE34` X bit already selects the bank being drawn, so the save area for that bank selects itself. Verify in jsbeeb |
| `&4000-&7FFF` × 2 | Play buffers, 16K hardware wrap, 20 rows × 640 displayed |
| SWRAM bank A | Charset (256 × 32 B at 4 bpp = 8K), tiles (3,376 B), both maps (1,510 B), level-draw code |
| SWRAM banks B, C | Sprite frames, MODE 2, pre-shifted 0 px and 1 px, bounding-box trimmed (~35K untrimmed, less trimmed); flash variants if needed |
| SWRAM bank D | Music driver and tune, title screen, panel font, game-flow code that is not needed every frame |

---

## 3. Sprite engine: what to change and why

First a correction of terms: **neither engine is XOR.** Both do `screen = (screen AND mask) OR pixels`
with a saved background copied back the next frame. What differs is where the mask comes from, how the
data is stored, how the save area is addressed, and how much is unrolled or compiled. The current Edge
Grinder plotter costs an estimated 17-18,000 cycles per sprite per frame (plot ~7,500, stash ~5,000,
restore ~5,000). Eight of those are 140,000 cycles against a 79,872-cycle frame. Paradroid finished at
5,814 per sprite for the same 7 × 21 byte footprint. The proposals below get Edge Grinder into that range.

### 3.1 Convert sprites offline, pre-shifted, bounding-boxed

Today every sprite byte goes through two 16-entry LUTs at plot time (nibble → mask, nibble → MODE 2). Do
this in Python instead. A C64 multicolour pixel is one MODE 2 pixel, so a 24 × 21 sprite is 6 bytes wide
plus one spill byte = 7 × 21 = 147 bytes per shift. Store **two shifts** (0 and 1 px). With the two
buffers half a byte out of phase, a sprite at fixed x uses shift 0 in one bank and shift 1 in the other,
so both are used every frame anyway. Store each frame with its bounding box (first row, height, first
column, width) as `export_effects.py` does in Paradroid — the enemy ships have plenty of empty rows and
columns and this cut Paradroid's explosion data by 40%. 119 frames × 2 shifts × 147 B is 35K untrimmed;
trimmed it should fit in two banks with room for the flash frames.

### 3.2 Mask from the data byte; transparent = logical 0; black = logical 8

Paradroid stores no masks: a 256-byte table maps each pixel byte to its mask, because a transparent pixel
is all-bits-clear. The same works in MODE 2: mask = `&AA` if the left nibble is 0, `&55` if the right is.
The catch is that sprites can then not use logical colour 0. MODE 2 has **16 logical colours**, so map
logical 8 to physical black, non-flashing, and let the converter write black-in-a-sprite as 8. The tile
converter keeps black as 0. This also means the compiled path can drop the AND/OR entirely on bytes where
both nibbles are opaque.

### 3.3 Save area mirrors screen geometry; restore replays the draw

Paradroid's key trick: within a character row a byte is at `col*8 + scan`, so a 56-byte save block per
character row lets the same `Y = col*8` index both `(bufp),Y` and `(svp),Y`. A 21-line sprite spans at
most four character rows and the furthest save byte is at 223, so one page per slot and no carry on the
save pointer. MODE 2 has the same 8-byte columns and 640-byte rows, so it lifts unchanged. The restore
does not store 21 addresses; it stores the draw's start pointer, scanline, shift and frame and walks the
same path. With double buffering each slot needs **two** snapshots and two save pages, one per bank —
the `&3000` proposal in §2 makes that automatic.

### 3.4 `SCANSTEP` with deferred carry and inline wrap

Advance `bufp`/`svp` one scanline per macro; the row crossing and the 16K wrap live in one shared
routine. Paradroid's 2026-09-01 "deferred carry" change (the wrapped low byte always takes the crossing
branch, so the high-byte increment happens once there) is worth ~3 cycles a step and 1,300 bytes of bank
across 335 sites. With the buffer at `&4000` the wrap test is "bit 7 of the high byte set → subtract
`&40`".

### 3.5 Restore in reverse order, draw forwards, restore-all-then-draw-all

Overlapping sprites are put back in reverse order of covering. Any buffer write between a restore and a
draw (the new scroll column) is fine; a draw between another sprite's restore and draw is not, because it
captures that sprite into the save. This is the invariant that made Paradroid's engine correct and it is
free to adopt from day one.

### 3.6 Compile only the player and bullet; interpret the enemies

Compiling all 119 frames × 2 shifts would be ~200K of code. Compile the seven player frames and the
bullet (as the CPC port did — it bought the CPC 50 Hz music), and run enemies and explosions through the
bounding-boxed interpreted path. Paradroid's interpreted cost was ~53 cycles per byte all-in; a trimmed
enemy frame of ~100 opaque bytes is ~5,500 draw + ~2,500 restore.

Budget target per frame (79,872 cycles):

| Item | Estimate |
|---|---|
| Scroll column (rotate, plot, copy) | 9,000 |
| Player + bullet, compiled | 5,000 |
| Six enemies, interpreted, trimmed | 42,000 |
| Game logic (waves, collisions, input) | 6,000 |
| Music tick × 2 | 3,000 |
| **Total** | **~65,000** |

Tight but plausible; the CPC ran the same game at ~75% CPU in sprites. If it does not fit, the fallbacks
in order are: bullet with a reduced save area, a shared explosion save, a Paradroid-style `FRAME_LOCK`
floor that lets a heavy frame overrun rather than tear.

### 3.7 Clipping, not culling **[DECISION 2]**

Paradroid culls: a sprite not wholly inside the play area is not drawn. That was acceptable for droids in
corridors; in a shooter, enemies enter from the right edge and the player's bullet leaves it, so
**horizontal clipping by column range** is needed on the interpreted path (a per-row loop bound, cheap)
and the compiled player gets bounds-clamped instead (the C64 clamps x to `$10-$9b`). The CPC clamped
enemies to x 16-72 and accepted pop-in; I recommend real clipping but it is a fidelity call.

### 3.8 Hit flash

The C64 recolours a sprite while `sprite_pls_tmr` runs. With colours baked into MODE 2 bytes, either
store a flashed copy (the CPC used a whole bank for these) or use a second interpreted inner loop that
passes each byte through a 256-byte recolour LUT (+6 cycles a byte, only while flashing). Recommend the
LUT.

---

## 4. Display: status panel and interrupts

The C64 has a 5-row status bar above a 20-row playfield. Do the same with a **two-cycle rupture** taken
from Paradroid's `rupture.asm`: cycle 1 displays the panel at `&2000` (4 rows, fixed address), cycle 2
the play area from the scrolling start address, then the vertical tail. The rules bought the hard way in
Paradroid all apply: R6/R7/R12/R13 written in the *previous* cycle, R5 never near a boundary, every blank
done with R8 not R6, T1 restarted only at vsync. Take over IRQ1V (all loading is done at boot, so the
"no filing system calls after" rule is free), flip `&FE34` in the vsync handler, latch the play start
address at the cycle boundary, read the keyboard direct from the VIA, and call the music driver at 50 Hz.
Add a proper frame counter and drop `char_col`'s double duty.

The 24 displayed rows leave 120 scanlines of vertical blanking a field, which is more off-display time
than Paradroid had, though with double buffering it only matters for the CRTC latch.

---

## 5. Graphics pipeline and the artist

### 5.1 Phase A — mechanical conversion (needed regardless)

Rewrite `bin/` as a set of exporters in the Paradroid style, committed output in `src/data/`:

- `export_tiles.py`: `tiles.chr.bin` → 4 bpp MODE 2 chars (32 B each) with the C64 colour decode applied
  (per-char colour + shared `$d022/$d023`), `tiles.til.bin` → tile defs, both maps concatenated.
- `export_sprites.py`: `sprites.spr.bin` → MODE 2, per-sprite colour from `sprite_col_dcd`, shared blue
  and white, two shifts, bounding boxes, black → logical 8.
- `render_bbc.py`: the reverse — render any converted sheet, tile set or whole map back to PNG at the
  BBC's 2:1 pixel aspect, so what the machine shows can be checked on the desktop before it is assembled.

The current `bbc.py` nearest-colour matching must go: gamma-2.2 nearest sends the sheet's grey, green and
red-brown to black. Use explicit tables and refuse unknown colours.

### 5.2 Phase B — hand-authored MODE 2 art **[DECISION 3: commission it?]**

What the artist needs to know about the canvas:

- **The palette is fixed and there is no choosing it**: MODE 2 shows all eight BBC colours at once —
  black, red, green, yellow, blue, magenta, cyan, white — all fully saturated. No greys, no dark shades.
  Tiles and sprites share the same eight. This is the whole constraint; there is no per-character colour
  limit as on the C64, which is the win.
- Pixels are 2:1 (160 × 256 in a full screen). Give him canvases at 2× horizontal so they look right in
  Aseprite; the converter asserts each pixel pair is identical.
- Sprites: 12 × 21 fat pixels (24 × 21 on the doubled canvas), any colour anywhere, one designated
  transparency colour (keep the sheet's grey `96,96,96`). 119 frames in the existing 8 × 15 sheet layout,
  so animation counts and frame order stay as the C64 wave data expects them.
- Tiles: 256 characters of 4 × 8 fat pixels, 211 tiles of 4 × 4 characters, a 302-tile-wide map. The
  simplest brief is "repaint `reference/tiles.png` and `reference/characters.png` in the eight colours";
  the map and tile definitions stay the C64's. Redrawing tiles freely (new tile definitions) is possible
  but changes the map tooling — offer it as a later option.
- Also on the table: the title screen (`assets/TitlescreenBig.png` exists), the panel font, and the
  lives icon.

The exchange loop:

1. **Kit out**: a zip (or shared folder) with an Aseprite/GIMP palette file of the eight colours plus the
   transparency key, the template PNGs, the current mechanical conversion of every sheet as a starting
   point, `reference/map.png` for context, and a short README of the rules above.
2. **Validation on receipt**: `tools/validate_art.py` checks dimensions, exact palette membership, pair
   doubling and frame count, and writes a rendered PNG of what the Beeb will show. Unknown colours are
   errors with coordinates, not silent nearest-matches.
3. **Partial sheets**: any cell painted entirely in a second magic colour falls back to the mechanical
   conversion, so he can hand over a few sprites at a time and always see a complete game.
4. **Testing**: every drop goes through `publish-wip` to the Bitshifters wip folder and he gets a
   `bbc.xania.org` link that boots in the browser — no emulator install. A `-Gallery` debug build that
   pages through all sprites and tiles at 1× and 2× is worth an hour to write.
5. **Transport [DECISION 4]**: a shared OneDrive/Dropbox folder that a script mirrors into `assets/`
   (we commit) is the least friction for a non-developer; a GitHub repo with him committing to
   `assets/` is cleaner if he is happy with git.

Do Phase A first and get the whole game playing on converted art before Phase B starts; he then replaces
sheets in a working game rather than designing blind.

---

## 6. Process and tooling to set up first (Layer 0)

- `PLAN.md` (live), `docs/` per layer with **[DECISION]** lists, `BUGS.md`, and a corrected `CLAUDE.md`
  (the five errors in §1 fixed). `TODO.md` and `progress.md` fold into `PLAN.md`.
- Split `edge-beeb.asm` into `src/` (`main`, `scroll`, `sprite`, `rupture`, `player`, `enemy`, `data/`).
- `build.ps1` with `-Run`, `-Release`, `-D RELEASE=` and beebasm's stderr quirk handled, `make.bat`
  kept as a wrapper; `tools/make_disc.py` + ZX0 lifted from Paradroid when boot time matters.
- **Configure the jsbeeb MCP for this project path** (it is set up for Paradroid and six other projects,
  not this one).
- Debug flags named in `!BOOT`; a full-strip redraw oracle on a CTRL key; a `DEBUG_DRAW` raster tint.

---

## 7. Proposed layers

| # | Layer | Done when |
|---|---|---|
| 0 | Repo, docs, build, jsbeeb, source split | Same binary builds from `src/`, docs corrected, `PLAN.md` exists |
| 1 | Graphics pipeline A: offline conversion of chars, tiles, maps, sprites; `render_bbc.py`; data in SWRAM, at-plot LUTs removed | Game looks identical, scroll cost unchanged |
| 2 | Display: rupture + status panel, IRQ1V, direct keyboard, frame counter, `&FE21` palette, both maps, map end | Level scrolls end to end with a panel above |
| 3 | Sprite engine v2 (§3): slots, geometry save, mask table, two shifts, clipping, compiled player/bullet, flash LUT; **measure** | Eight moving sprites at 25 Hz with cycle counts recorded |
| 4 | Player: bounds, fire latch, bullet at 12 px/frame (collision-checked twice like the CPC), background collision via `col_decode`, grind score | Player dies on walls, bullet hits walls |
| 5 | Enemies: wave manager and the 54-wave table verbatim, movement commands, shields, bullet/enemy and player/enemy collisions, explosions | The level is playable |
| 6 | Game flow: lives, shield timer, score/hi-score, HUD, state machine, title with zoom scroller, completion, pause/Q | Full game loop |
| 7 | Sound: CPC Arkos tune converted via the nova-invite toolchain (AT2 → YM → SN76489 → VGC player), SFX | Music at 50 Hz in the IRQ |
| 8 | Art pipeline B and integration of hand-authored art (§5.2) | Artist's sheets in the game via the validated path |
| 9 | Polish and release: starfield, `make_disc`, real hardware, `publish-wip` | Release candidate |

Paradroid took 30 days for a game with a 16-deck ship, AI, a minigame and a console. Edge Grinder's C64
source is a fraction of that, so layers 0-6 are a couple of weeks at the same cadence, with the art and
music layers gated on other people.

---

## Decisions taken (KC, 2026-09-02)

1. **Master 128 only** (§2).
2. **Real horizontal clipping** for enemies and the bullet, for the higher quality bar (§3.7). Edge
   culling stays as the fallback only if clipping cannot be made to fit the budget.
3. **Commission the art as a free redraw within the existing tile boundaries.** The artist adds detail,
   gradients and fat-pixel dithering using all eight colours, but tile outlines, the 4 × 4 character
   grid, the 211 tile definitions and the map stay the C64's. `reference/beeb-artwork-example.jpg` is the
   target look. Consequences for the pipeline: the tile sheet template must show tile boundaries and the
   collision/fatal flags (`col_decode`) so detail is added where the game expects solid; the validator
   compares each redrawn tile's silhouette against the mechanical conversion and warns when it grows.
4. **Exchange by shared folder or email.** A drop folder mirrored into `assets/` by a script; we commit.
   No git on the artist's side.
5. **Music by automatic conversion of the CPC Arkos Tracker tune.** The tools already exist in
   `Repos/nova-invite/bin`: the CPC `.SKS` songs (`source_cpc/Music/EDGEA.SKS`, `WON4.SKS`) load into
   Arkos Tracker 2, export through `SongToYm.exe`, then `ym2sn.py` to SN76489 and `vgmpacker.py`, played
   by `lib/vgcplayer.asm` from the 50 Hz interrupt. Layer 7 becomes a tooling job, not a commission.
