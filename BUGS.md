# Bugs

Open defects, with the evidence and what has been ruled out. Fixed entries stay for what they
ruled out. Index first, detail below.

| # | Status | Summary |
|---|---|---|
| 1 | gone (Layer 3) | "Double-buffer stash restore reads the wrong buffer" (`eor #1` commented out in `sprite.asm`). The routine it was about no longer exists |
| 2 | fixed (Layer 3) | No sprite clipping: `x_pos >= 80` indexed past `mult8_*`. The engine now clips the frame's box to 80 columns x 160 scanlines at all four edges (decision 2) |
| 10 | fixed (Layer 6b) | The wave table went one byte out of step for the rest of the game if the player died at the wrong moment: the wave manager's no-free-slot path skipped eight bytes of a nine-byte wave. Only the player explosion ever fills all six slots at once, so it hid until the life cycle went in |
| 9 | fixed (Layer 6a) | The game dropped below 25 Hz while shooting: the walked path for a sprite crossing the end of the buffer cost 97 cycles a byte and was being taken nine times too often. Split into two ladder calls instead; 100 s of play now peaks at 90% of the frame with no missed flips |
| 3 | fixed (Layer 4) | `read_keyboard` had no movement bounds. `player_manage` clamps x to `$10-$9b` and y to `$5a-$e5`, the C64's own, and `read_joystick` no longer moves the player at all |
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

## 9. The game drops below 25 Hz while shooting, ~50 s in

**Confirmed 2026-09-03, and it is the frame budget.** Reported by KC: the game slows below 25 Hz
when shooting, around 50 seconds into the level.

Measured with the frame meter (`src/timing.asm`, `DEBUG_TIMING`), which times each phase of the
main loop off the User VIA's T2 and counts the frames that miss their flip. All figures below are
**2 MHz cycles against a frame of 79,872**; the meter itself records microseconds, which are half.

| | 14 s in, no firing | 54 s in, no firing | with eight explosions live |
|---|---|---|---|
| `spr_restore_all` | 12,528 | 17,108 | 24,506 |
| `scroll_frame` | 12,532 | 12,710 | 12,710 |
| `spr_draw_all` | 29,906 | 39,320 | **51,842** |
| logic + `scroll_advance` | 5,404 | 8,590 | 8,590 |
| **whole frame, worst** | 58,320 | 71,414 | **92,490** |
| | 73% | 89% | **116%** |
| frames that missed the flip | 0 | 0 | 1 |

So the budget table in `PLAN.md` was optimistic by about 45%, exactly as suspected: `BUGS.md` #8
had been hiding every sprite past x = 140 when the 34,143-cycle draw was measured. Ordinary busy
play at 54 seconds is already at 89% with nothing shot; put eight explosions on the screen and the
frame runs 12,618 cycles over and `FRAME_LOCK` holds it for a third field. That is the drop KC saw,
and it is not a glitch in the rupture: the meter's `tim_over` counts a frame that arrived late,
which is precisely what the symptom is.

The eight-explosion column was produced deterministically rather than by shooting for a minute:
with the game 54 s in, `sprite_pos` and `sprite_dp` for slots 2-7 were poked to explosion frames at
spread on-screen positions and the loop run for three frames. Explosion boxes are 6 columns x 21
rows, the largest in the game, so this is the real worst case and not a contrivance.

**Where the time goes.** The sprites are 76,348 of the 92,490 - 83% of the frame's work. The
interpreted blitter costs **36 cycles for every byte of the bounding box** it draws (data fetch,
background read, save, mask, colour table, store) and the restore another **13** to replay it, and
it pays that whether the byte is opaque or transparent. Across all 119 frames of sprite data,
10,579 bounding-box bytes hold 7,785 opaque ones: **26% of what the blitter draws is nothing at
all**. Tightening each row to its own first and last opaque byte would recover almost all of that -
the per-row spans total 7,976 bytes, only 2% more than the opaque count - because the rows are
essentially contiguous.

### The worst case is worse than that, and it is the walked path

The figures above were sampled from play. Placing six explosions so that their rows **straddle the
end of the 16K buffer** - which the engine handles by walking `bufp` a column at a time - gives the
real ceiling:

| | eight explosions | six of them straddling |
|---|---|---|
| `spr_restore_all` | 24,506 | 56,720 |
| `spr_draw_all` | 51,842 | 93,934 |
| **whole frame** | 92,490 (116%) | **127,368 (159%)** |

`spr_draw_row_slow` costs **97 cycles a byte against 36**, and `spr_rest_row_slow` 58 against 13.

### Fixed, 2026-09-03, in two steps

**Step one: the test that sends sprites to the walked path is now exact.** The engine asked one
cheap question per sprite - does `bufp + SPR_REACH` cross the end? - where `SPR_REACH` is
3 x 640 + 6 x 8 = 1,968, the furthest the walk can reach **vertically**. But a row straddles only if
its own seven columns do, which is a reach of at most 55 bytes. The test flagged **12%** of sprites
where about **1.4%** really straddle: nine sprites in ten were paying 97 cycles a byte for nothing.
`spr_straddle_exact` now asks properly, and it is four compares rather than twenty-one because of
one observation:

> **The split column is the same for all eight scanlines of a character row.** Every term of a
> byte's address except the scanline is a multiple of 8 - the buffer origin, the row offset, the
> column - so within a character row the columns sit at `base + scan + 0, 8, 16 ...` and whether
> the last of them reaches `&8000` does not depend on `scan`. A character row straddles or it does
> not. And consecutive character rows are 640 bytes apart while a sprite is at most 56 wide, so
> **at most one character row of a sprite can straddle at all.**

That made it rarer. It did not make it cheaper, and #9 is about the tail: a straddling explosion
still cost what it always had.

**Step two: the walked path is gone.** The same observation is what makes the real fix small. The
one character row that straddles has its eight scanlines drawn as **two ordinary ladder calls** -
columns `0` to `k-1` where the pointers already are, then `k` to `count-1` the same distance along
the save and the data but 16K back round the buffer. `svp` and `bufp` take the **same** bias,
`k*8`, which is the whole trick: the existing unrolled bodies serve the second half unchanged and
there is no second ladder. Every other character row takes the whole-row body, reached by a tail
`JMP` so its own `RTS` returns to the row loop. `spr_split_calc` recomputes `k` at each character
row crossing, from inside `spr_scan_row`, and costs five cycles for the sprites that never straddle.

`spr_draw_row_slow`, `spr_rest_row_slow`, `spr_next_col` and `spr_mul8` are deleted.

### Measured

| | before | after |
|---|---|---|
| 100 s of play, worst frame | - | **72,106 (90%)**, and **no missed flips** in ~2,500 game frames |
| eight explosions, none straddling | - | 66,960 (84%) |
| eight explosions, as sampled | 92,490 (116%), flips missed | - |
| six straddling explosions, `spr_draw_all` | 93,934 | 48,116 |
| six straddling explosions, `spr_restore_all` | 56,720 | 22,296 |
| six straddling explosions, whole frame | **127,368 (159%)** | **85,326 (107%)** |

So the walked path was the whole of the overrun. With it gone the plain eight-explosion frame is
66,960, and the 92,490 measured at the top of this entry was that plus two or three sprites in the
walked path at roughly 9,000 cycles each.

**What is left over.** A frame in which *six* sprites straddle at once is still 107%, and that is
the constructed extreme: it needs six sprites simultaneously inside a 55-byte window of a 16K
buffer, which does not happen by accident. Real margin for the HUD comes from the span and
compiled-blitter work, not from here.

**Verified in jsbeeb**: sprites poked to positions giving every split column k = 1 to 5, confirmed
straddling by reading `spr_sv_wrap`, drawn whole and unbroken, and the background left clean when
they were hidden again - so the restore replays the split correctly in both banks.

**Room it needed.** `coll_row_lo/hi` moved to bank 0 (their only reader runs with bank 0 resting),
and all four multiply tables are gone, replaced by the shifts that were hiding in them: `HI(c*8)`
is `c >> 5` and `LO(c*8)` is `(c AND 31) * 8` for `c` under 80; `HI(n*640)` is `(5n) >> 1` and
`LO(n*640)` is 0 or 128 by the parity of `n`, which that shift hands over in the carry. 336 bytes
of table for about 60 of code.

The deferral in decision 19 was taken on the grounds that "the interpreted path fits the frame".
At 90% with no margin for Layer 6d, it only just does.


## 10. Enemies stopped coming, or arrived as nonsense, after the player exploded

**Found and fixed 2026-09-03, in Layer 6b, by KC.** Reported as: die on the first wave and the
enemies vanish for a moment and come back, which is right; die on the second and **no more enemies
appear at all**; die on the third and **sprites come in at the top left, move diagonally down and
right, and the player is hit again by something invisible**. Reproduced in b2 and in jsbeeb.

Three different symptoms from one cause, and the wave number is the clue: it is the **wave table
reader losing its alignment**.

`wave_manager` has a path for when a wave falls due and no slot is free. It cannot just return -
the wave has to be read past and thrown away, and its last byte is still the delay to the next one.
The C64 writes that out longhand as `wm_fail`'s one `jsr wave_read` plus **eight** more in
`wm_fail_2`: nine bytes, a whole wave. Ours had the eight as a loop, and the loop ran **seven**
times. Eight bytes consumed out of nine.

From that moment the reader sits one byte inside every later wave. Each field then reads as the
next one along: the shield byte becomes the x, x becomes the y, y becomes the first movement
command, and so on. That is exactly what KC saw - enemies placed at the top left because their x
and y are somebody else's shield and start position, flying diagonally because their movement
commands are somebody else's coordinates, and an object byte that lands on a blank frame so the
sprite is invisible while its box still collides.

**Why it hid until Layer 6b.** The skip path only runs when all six pool slots are full at once,
and in ordinary play they never are - the waves are authored not to overfill the pool. The one
thing that fills all six in a single tick is `life_lost`, which turns every slot into a piece of
the exploding player. So the layer that read `coll_flag` was the first thing ever to reach the
path. Whether it bit depended on whether a wave happened to fall due inside the second or so that
the pieces are animating, which is why dying on the first wave looked fine and dying on the second
did not.

**The fix**: `ldx #WAVE_BYTES-1`, with `WAVE_BYTES = 9` named next to the table's description, and
a comment at the site saying what it costs to get wrong.

**Measured after the fix**: forcing the path by filling all six slots and dropping `wave_tmr` to
zero advances the reader by exactly 9. Across 3,500 frames of a parked player dying over and over,
through several game-overs and restarts, the read pointer stayed a whole multiple of nine bytes
from the start of the table, and enemies kept arriving with sane positions and frames.

**What it ruled out**: nothing in the sprite engine. The first suspicion was the seven-way overlap
of six explosion pieces and the player breaking the save-and-restore ordering, and that was checked
and is sound - the restore runs slot 0 up and the draw slot 7 down, which is the correct reverse.
`life_lost` itself is a faithful transcription and corrupts nothing; every array it writes was
checked against its bounds. The layer's own state - `lives`, the shield, `player_live` - was
correct throughout, which is why the state readings looked healthy while the screen did not.
