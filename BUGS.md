# Bugs

Open defects, with the evidence and what has been ruled out. Fixed entries stay for what they
ruled out. Index first, detail below.

| # | Status | Summary |
|---|---|---|
| 1 | gone (Layer 3) | "Double-buffer stash restore reads the wrong buffer" (`eor #1` commented out in `sprite.asm`). The routine it was about no longer exists |
| 2 | fixed (Layer 3) | No sprite clipping: `x_pos >= 80` indexed past `mult8_*`. The engine now clips the frame's box to 80 columns x 160 scanlines at all four edges (decision 2) |
| 3 | open | `read_keyboard` has no bounds; the C64 clamps x to `$10-$9b` and y to `$5a-$e5`. Harmless now that sprites clip, but the player will run off the edge until Layer 4 ports the bounds |
| 8 | fixed (Layer 5) | Sprites at x >= 140 were never drawn: the byte column was halved with an arithmetic shift, but the value does not fit a signed byte |
| 7 | fixed (Layer 5) | A stationary sprite rocked two pixels back and forth with the scroll: `scroll_advance` ran before the sprite draw |
| 6 | fixed (Layer 5) | The game opened on an empty playfield and the waves did not line up with the level: the C64's start-of-game fast winder was missing |
| 5 | fixed (Layer 4) | `coll_advance` counted in X and broke the scroll outright: the scroll's tail keeps `char_col + 1` there |
| 4 | fixed (Layer 2) | The map looped after 256 tiles; `map_read` now wraps at the 302-column end (decision 14) |

## 1. The `eor #1` that TODO.md wanted re-enabled — gone with the plotter

**Closed 2026-09-03, unverified and now unverifiable**: Layer 3 replaced `restore_background` and
`stash_background` outright. The engine that took their place keeps per-bank save state indexed
`bank*8 + slot` and the restore replays the draw's own recorded walk, so there is no parity to get
wrong. The analysis below is kept only for what it ruled out.


`src/sprite.asm`, `restore_background`, two commented-out `eor #1` lines. The 2026-03 TODO said the
restore "reads the wrong stash buffer half the time" and should have the `eor` put back.

Reading the loop: `&FE34` flips every iteration, so the bank being *drawn* in iteration *n* has
parity `char_col AND 1`. The sprite in that bank was last drawn in iteration *n-2*, and
`stash_background` in *n-2* wrote stash `[(n-2) AND 1] = [n AND 1]`. So restore and stash in
iteration *n* both address stash `[n AND 1]` and the code as it stands is consistent. Re-enabling the
`eor` would restore from the *other* bank's stash.

**Not yet verified in the emulator.** Do that (move the sprite to the screen edge and look for
trails in both banks) before touching it. The whole routine is replaced in Layer 3 anyway.

## 5. The scroll came apart when the collision map went in

Reported by KC in b-em, 2026-09-03: "scrolling is very broken", immediately after Layer 4 landed.

`coll_advance`, called from the scroll's tail beside `tile_cnt_bump`, counted the map's ring index in
**X**. That run of code keeps `char_col + 1` in X from the increment at the top of the tail, through
the `AND 3` test that bumps the tile and the `AND 1` test that moves `crtc_addr`, down to the
`corner_addr` update at the bottom. `tile_cnt_bump` counts in Y precisely so it can sit in the middle
of that and not disturb it; the new routine did not.

The effect was `crtc_addr` and `corner_addr` advancing on the wrong frames, so the scroll address and
the buffer the column was written into disagreed. It also produced a vertical smear of sprite-coloured
pixels, which is the column copy landing in the wrong place, not a sprite fault.

`coll_advance` counts in Y now and says why in a comment. **Anything else added to that tail must
leave X alone.**

## 6. No fast winder, so the waves did not line up with the level

Reported by KC, 2026-09-03: "the enemies don't seem to line up with the level. we get quite a long
blank period before the background scroll appears... some of the enemies appear more towards the
middle of the screen, not from the far right edge."

Two symptoms, one cause. The C64's `map_read_rst` does not just reset the map pointer; it ends with
what its author labels a **"Scroll fast winder for the start of game"** - the whole buffer-swap cycle
run 20 times, which is 40 characters, which is exactly the width of the screen. The port reset the
pointer and started playing.

So the playfield began empty and took a screen's worth of scrolling to fill, which is the blank
period. Worse, the wave table's timings were authored against a full screen: with the map a screen
behind where the original would have it, **every wave spawned a screen ahead of the scenery it was
drawn to fly through**, and enemies that should have entered from the right edge appeared over
whatever empty space was there instead.

`scroll_prewind` in `main.asm` now runs `scroll_frame` 160 times before the display is unblanked -
40 characters at 4 frames each - flipping the shadow bank itself each time, because the VSync
handler that normally does it is not installed yet. Both banks come up full and one pixel out of
phase, as the running loop leaves them.

The main loop's scroll work was factored into `scroll_frame` to make this possible, which is why
that routine exists at all.

## 7. A stationary sprite rocked back and forth with the scroll

Reported by KC, 2026-09-03: "the player sprite is jerking back & forward with the scroll."

Factoring the per-frame scroll into `scroll_frame` for the fast winder (#6) put the *advance* -
`char_col`, `tile_cnt`, the collision ring, `crtc_addr`, `corner_addr` - inside the same routine as
the plot. The loop then drew the sprites afterwards, so they were placed from an already-advanced
`corner_addr`.

Sprites are positioned as `corner_addr + 8 + ...`, and the frame's parked CRTC address is what the
display uses. Working it through: on frames where `char_col` is even the advance moves `crtc_addr`
and not `corner_addr`, and the screen position comes out right; on odd frames it moves
`corner_addr` and not `crtc_addr`, and the sprite lands **one byte column - two pixels - further
right**. Alternating every frame, in step with the scroll, which is exactly what it looked like.

Split into `scroll_frame` (plot) and `scroll_advance` (advance), with the loop back in its original
order: restore, plot, draw sprites, game logic, **then** advance. The winder calls both.

## 8. Sprites at x >= 140 were never drawn

Reported by KC, 2026-09-03: "the enemy sprites are still appearing about 2/3 of the way across the
screen rather than from the far right hand side."

A **Layer 3 defect**, not a Layer 5 one - it had been there since the engine was written and only
became obvious once the waves started spawning enemies at the right edge for real. The fast winder
(#6) fixed the level alignment and the blank start, but not this.

`spr_draw_slot` turned the C64's halved x into a byte column with `CMP #&80 : ROR`, an arithmetic
shift that reads bit 7 as a sign. But `x - SPR_X_OFF` runs **-12 to 243** and does not fit a signed
byte: every sprite with x of 140 or more came out with a large negative column, was taken to be off
the left edge, and was skipped. The 149 waves that spawn at x = 172 - the far right edge - stayed
invisible until they had crossed a third of the screen and x fell below 140.

The sign now comes from the subtraction's carry rather than bit 7, with the bank phase folded into
the subtracted constant so that carry stays meaningful, and the halving is a plain `LSR` when the
value is non-negative. Verified: a sprite poked to x = 168 is drawn with `spr_sv_cols` = 2, the two
columns that fit before the right edge, where before it was not drawn at all.

It bit the player too, silently: `PLY_X_MAX` is `$9b` = 155, so the ship would have vanished
anywhere past x = 139.
