# Layer 3 — the sprite engine (2026-09-03)

First pass. Eight software sprites over the scrolling buffer, in both shadow banks, clipped at the
play-area edges, drawn from offline-converted MODE 2 data. The 2019 plotter, its two nibble LUTs
and its two 126-byte stashes are gone.

**Status when written: built, running and measured in jsbeeb, not yet seen in b-em.** KC has since
reviewed it, and two defects in this layer's code were found in Layer 5 - `BUGS.md` #8 and #9. The
open items at the bottom carry their Layer 5 status. Still no buffer oracle.

## What was built

1. **The data is converted offline and bounding-boxed** (`tools/export_sprites.py`, decision 18).
   Each pixel shift gets its **own 16K bank** — `src/data/sprites0.bin` (shift 0, slot 5) and
   `sprites1.bin` (shift 1, slot 6) — because both shifts plus the tables come to ~24K and do not
   fit one. Each bank is self-contained and identical in layout, so the engine pages in the bank a
   sprite's x asks for and every address in the code is the same either way:

   | offset | | |
   |---|---|---|
   | `&8000` | 256 B | data byte → AND mask |
   | `&8100` | 256 B | data byte → itself (the identity ORA table) |
   | `&8200`, `&8300` | 256 B each | recolour to white / to magenta, for the hit flash |
   | `&8400`, `&8480` | 119 B each | address of each frame's box data, low and high |
   | `&8500`-`&8680` | 119 B each | the box: first row, rows, first byte column, byte columns |
   | `&8700` | 126 B | the C64's `sprite_dp_dcd`, rebased to frame 0-118 |
   | `&8780` | 126 B | which flash table this dp uses |
   | `&8800` | | the frames, row-major, box width as the stride |

   The boxes are worth having: 22,750 bytes of box against 34,986 for the full 7 × 21 cells, and
   **30% of what is left inside the boxes is still transparent** and costs the interpreted loop the
   same as an opaque byte. That number is the case for compiling the player later.

2. **Masks are not stored** (Paradroid's trick, unchanged). A transparent pixel is logical 0, so
   `SPR_MASK,x` recovers the mask from the data byte. Sprites may not use logical 0; black inside a
   sprite is written as logical 8, which Layer 2's palette already maps to physical black. Nothing
   in the C64 art needs it — the exporter asserts the colours it sees.

3. **The save area mirrors screen geometry.** Within a character row a byte is at `col*8 + scan`, so
   a slot's save block is laid out the same way and **one Y addresses both `(bufp),Y` and
   `(svp),Y`**. One page per slot per bank at `SPR_SAVE = &2000` — the 4K freed by decision 17 holds
   `8 slots × 256 B × 2 banks` exactly. 21 scanlines from any alignment reach at most
   `3*56 + 6*8 + 7 = 223 < 256`, so `svp` never leaves its page and never carries; the assert is in
   the file.

4. **`SCANSTEP` with the deferred carry and the wrap inline.** `bufp AND 7` *is* the scanline, so no
   counter is kept; the row crossing (one step in eight) is out of line and finishes the `INC bufp`
   the macro left half done, because a low byte that has just wrapped to zero always takes the
   crossing branch. The 16K wrap is one high-byte `SBC` with the carry known clear: past `&7FFF` is
   bit 7 set.

5. **The restore replays the draw.** The draw stores five bytes per slot per bank — start pointer,
   scanline, rows, columns, and whether it walked — and the restore walks the same path. Nothing
   else is remembered, so the two cannot disagree about anything. `spr_restore_all` runs slot 0 up
   and `spr_draw_all` slot 7 down, so the player (slot 0) is drawn last and on top, which is the
   C64's sprite priority, and overlapping backgrounds come back in the reverse of the order they
   were covered.

6. **Clipping, not culling** (decision 2, now built). The frame's box is clipped to 80 columns ×
   160 scanlines: columns off the left are skipped in the data pointer, columns off the right shorten
   the row, rows off the top skip whole rows of data, rows off the bottom shorten the loop. Only what
   survives is saved, so the restore puts back exactly what the draw covered. The row body is
   **seven fall-through bodies** entered at the column count through a dispatch table — no inner
   loop, no per-column test.

7. **The hit flash is the ORA table** (decision 20). The C64 swaps the sprite's colour register while
   `sprite_pls_tmr` runs; our colours are baked into the pixels, so the `ora SPR_LUT_IDENT,x` in each
   body is repointed at a recolouring table instead. **It costs nothing per byte** — eight patch
   sites, written only when the table changes — where a second inner loop would have cost 6 cycles a
   byte. The tables assume a sprite holds only transparent, blue, white and one other colour, which
   is true of all 119 C64 frames (the exporter asserts it); hand-drawn art with more colours would
   need a table per colour.

8. **The buffer wrap has a fallback.** A play buffer row is 640 bytes and the buffer is 16K, so
   16,384/640 = 25.6 — **the wrap point is not row-aligned and falls in the middle of a character
   row**, which means a sprite's seven columns can straddle `&8000` and stop being 8 bytes apart in
   address order. One test per sprite (`bufp + 3*640 + 48` still under `&8000`) decides it, and if it
   fails every row of that sprite walks `bufp` a column at a time instead. `SPR_REACH` of the buffer
   is 12%, so about one sprite in eight takes it; the save side never wraps, so `Y = col*8` still
   addresses it there.

9. **The C64's own tables.** `sprite_pos`, `sprite_dp` and `sprite_pls_tmr` keep the original's
   layout and meaning (`$0360`-`$037F`), so Layers 4 and 5 can port `xploder_1`, `wave_manager` and
   the collision code without a translation layer. Slot 0 is the player, 1 the bullet, 2-7 the pool —
   the C64's arrangement. `spr_init` is its `cm_hide_sprs`: zero the positions and point every slot
   at dp `$0a`, the explosion's empty last frame.

## Measured, jsbeeb, eight sprites live

Breakpoints on the entry points, clock from `read_registers.elapsed_cycles`:

| | cycles | per sprite |
|---|---|---|
| `spr_restore_all` (8 slots) | 15,093 | 1,887 |
| scroll: map read, 20 × `plot_char_y`, column copy | 11,153 | |
| `spr_draw_all` (8 slots) | 34,143 | 4,268 |
| **total sprite work** | **49,236** | **6,155** |
| the three together | 60,389 of 79,872 | **76% of the frame** |

**These figures are optimistic** and were superseded before Layer 5 shipped: they were taken while
`BUGS.md` #8 was silently skipping every sprite past x = 140, so enemies entering from the right
edge cost nothing at the time. See `BUGS.md` #9.

For comparison: the 2019 plotter was ~17,500 a sprite, and Paradroid finished at 5,814 for the same
7 × 21 footprint with the rotor compiled. So this is a **2.8× improvement, interpreted**, and it
leaves ~19,000 cycles a frame for the player, the waves, collisions and the music — which is roughly
what `PROPOSAL.md` §3.6 budgeted for them (~9,000) plus margin.

The scroll's 11,153 is the first real measurement of it; the plan had estimated 9,000.

## Verified

- Runs 1,400 fields with eight sprites animating, drifting left, wrapping round and clipping through
  both edges: **no trails, no stray pixels, the map and panel intact**. The restore is putting back
  what the draw took, in both banks, including through the buffer wrap.
- Every slot's `spr_sv_on` is set in both banks and every saved pointer is inside `&4000-&7FFF`.
- `tools/render_bbc.py sprites 0|1` unpacks a bank back to a PNG from its own box tables — all 119
  frames, both shifts, round-trip clean. That is the check that the box table and the data agree.
- Memory: code `&0E00-&190x`, high water `&1AEA`, `&516` free below `CODE_TOP`. Bank 0 `&B500`,
  bank 1 `&B153`, bank 2 `&B78B`.

## Open — for KC *(status as of Layer 5, 2026-09-03)*

1. **The bank phase, `SPR_PHASE_MASK` in `main.asm`, is currently 0 and needs an eye on it.**
   The two banks are drawn at the same origin (`corner_addr + 8`) and displayed at the same CRTC
   address — the picture's one-pixel offset lives in the *map content*, not in the window — so a
   sprite is screen-space and the same bytes at the same address should stand still under both.
   `PROPOSAL.md` §3.1 had assumed the opposite (a sprite at fixed x using shift 0 in one bank and
   shift 1 in the other). **If a stationary sprite shimmers one pixel at 50 Hz, set the mask to 1.**
   Both shifts are used either way, because odd and even x still need them.
   **Still 0 and still unconfirmed** after Layer 5, and the 2px rock KC did report turned out to be
   `BUGS.md` #7, an ordering fault, not this.
2. **`SPR_X_OFF` and `SPR_Y_OFF` are derived, not confirmed** (12 and 90). The C64 stores x halved
   and its bitmap starts at raster 50; Layer 4 confirms them against the original's own bounds.
   **Effectively confirmed by Layer 4 and 5**: the collision map, the movement bounds and the wave
   table's spawn positions all line up with the original using these, and `SPR_X_OFF` was
   independently exercised by `BUGS.md` #8.
3. **No buffer oracle yet.** `CLAUDE.md` asks for one and it is the right check for this layer:
   redraw the strip from the map at the current scroll position, with the sprites restored, and diff
   it byte for byte at both bank parities. **Still not built**, and Layer 5 has since put six moving
   enemies in.

**Two defects in this layer's code were found later** and are worth reading with the above:
`BUGS.md` #8, the byte column taken with an arithmetic shift when `x - SPR_X_OFF` does not fit a
signed byte, which hid every sprite past x = 140 from Layer 3 until Layer 5; and `BUGS.md` #9, the
frame overrunning in play, which makes the cycle figures below optimistic.

## Rejected, or deferred

- **Compiling the player and bullet** (`PROPOSAL.md` §3.6). Not done: the interpreted path already
  fits the frame, and compiling is only worth its complexity once Layer 4 and 5 have shown what the
  real load is. The 30% transparent-inside-the-box figure above says what it would buy.
  **Layers 4 and 5 have now shown it**, and `BUGS.md` #9 says it does not always fit: this deferral
  is the thing to revisit first if that turns out to be the budget.
- **A shared inner loop instead of seven fall-through bodies.** The bodies cost 100 bytes of code
  image and save the per-column counter and test — about 8 cycles a byte, a quarter of the cost.
- **Per-row wrap testing** as Paradroid does. One test per sprite that sends the whole sprite down
  the slow path is simpler and, at one sprite in eight, cheaper than 21 tests on all of them.
- **Storing the flash frames** as the CPC does (a whole bank of them). The recolour table is free per
  byte and costs 512 bytes a bank.

## Debug — gone

`DEBUG_SPRITES` filled the pool with the player, his bullet and six enemies, animated them from the
C64's own `anim_decode` ranges, drifted them left and wrapped them round so every frame clipped
something through both edges, and flashed slot 2 every 64 frames; `read_keyboard` moved slot 0 on
Z/X/:/? in the C64's units. **All of it went in Layers 4 and 5**, as planned, when the player and
the waves became real. Neither the flag nor the harness exists now.
