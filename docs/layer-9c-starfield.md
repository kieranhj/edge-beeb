# Layer 9c — the parallax starfield

Ten stars on scanline 0 of every other character row, drifting left more slowly than the level does,
at two speeds: five at half the scroll and five at a quarter. `src/bank1.asm`, decisions 50 and 51.
Done 2026-09-04.

The play area reads as three planes — the scenery in front, then the cyan stars, then the green — and
the two sets alternate rows, so the depth alternates with them.

## The C64's starfield is dead code

`PLAN.md` and `PROPOSAL.md` carried "starfield" from Layer 0 on the strength of the original's
`rout2`:

```
        lda scroll_x
        and #$07
        tay
        ...
        lda star_decode,y
        sta $47f8
```

`star_decode` is eight single-bit bytes, and `$47f8` is row 0 of character `$FF` of `tiles.chr`,
which the game loads at `$4000` and `rout2` selects for the play area. One pixel, stepped right as
the fine scroll steps left, so it stands still: the same idea as everything below.

**Character `$FF` is never displayed.** Measured, not assumed:

- it does not occur in `tiles.til` — all 3,376 bytes checked, zero occurrences, so no tile contains
  it and no map cell can produce it;
- it does not occur in the map either way round — `tiles.map` + `tiles2.map`, 1,510 bytes, max tile
  index 210;
- character `$FF` in `tiles.chr` is eight zero bytes, so even the six rows the poke does not touch
  are blank;
- the one place `$FF` does appear is the status bar's own character map, whose last row is forty of
  them — and `status_cols`' last forty entries are all `$00`, which in multicolour mode means hires
  in colour 0, on a `$d021` that `rout1` sets to 0. Black on black.

So the poke lands on a character that nothing draws, in a row that would be invisible if it did.
Whatever it was for, the released game does not show it.

## So the ten are the CPC's

`source_cpc/Source/EG_Stars3.asm`, `ClearStars` and `PrintStars`, called once each per frame. Ten
stars at fixed screen addresses; the address is incremented every frame so the star moves against
the scroll and appears static; a star is printed only where the background byte is blank and cleared
only where the byte still holds a star; and the two colours are swapped every second frame.

Its ten positions are in `Compiled_Main3.asm` as `defw &10f*2+&8000-400` and so on. They decode to
scanline 0 of alternating character rows at byte columns 62, 38, 58, 18, 10, 8, 28, 66, 44 and 56 —
and since a CPC mode 0 screen row is 80 bytes for 160 pixels, which is ours exactly, they transcribe
unaltered. The table's order matters: the loop inverts the star byte halfway, so the first five take
one colour and the last five the other, which is what puts alternating rows in alternating colours,
and now in alternating speeds with them.

## The drift is ours (decision 51)

The CPC's stars stand still. Ours step one fat pixel left on their own beat,
`frame_count AND star_mask`: mask 1 is every second frame and mask 3 every fourth. The level moves
one fat pixel a frame, so those are a half and a quarter of it — **everything is slower than the
scenery, which is the whole point**. Nearer things move faster, so a star that moves at all has to
move less than the level in front of it, and the two star speeds put two planes behind it.

A step is half a byte, and that is the only fiddly part:

- out of the **left** half of a byte you land in the **right** half of the byte *before* it, so the
  pixel goes down a shift **and** the column goes back one;
- out of the **right** half you land in the **left** half of the *same* byte, so only the pixel
  moves.

MODE 2 puts the left pixel's four bits at 7,5,3,1 and the right pixel's at 6,4,2,0, so the two forms
of a star's colour are exactly one `ASL` apart and `AND #&55` tells them apart — no half-flag needed.
`star_pix` holds the byte to write and is shifted in place; `star_ofs` is the screen offset and moves
by 8 only on the steps that change column. `star_col` exists for one purpose, to notice the column
running off the left edge, where it comes back at column 79 and the offset takes `+632`.

**A star may now stand in the incoming column, 79, and one always will**: they visit every column.
That is safe only because `scroll_frame` runs **before** `star_frame`, so the star goes on top of a
column that has just been written, and by the time this bank comes round again the scroll has moved
on and nothing has repainted it. The static version had an `ASSERT` keeping stars out of column 79;
it is gone, and this paragraph replaces it.

## The wipe, and why it got simpler

A star is plotted **only into a byte that is already blank**, so it never covers the scenery; and it
is wiped by writing that blank back. That is the CPC's pair of rules and it means a star never has to
remember what it covered — what goes back is always zero.

What it does have to remember is **where**, and that is `star_lo`/`star_hi`, per star per bank. Per
bank because a bank is redrawn every other frame and what has to be put back is wherever *that* bank
last left it; a zero high byte means this bank did not plot this star at all, and no address in a
play buffer has one.

The static version got away without that: with the star nailed to the screen, `corner_addr` moved
exactly one byte column between a bank's own draws, so the previous address was always the current
one minus 8. **The drift breaks that** — the star moves too — so the address is stored instead. It
costs 52 bytes of the `&0800` block and it is strictly more robust: nothing infers where the star
was, the routine remembers.

We do not follow the CPC's clear, which tests the byte against the star's colour. That is not exact:
a background byte may legitimately hold `&08` or `&28`, and blanking one would leave a black dot on
the scenery for the six seconds it takes the scroll to bring a fresh column round. Our background
uses all eight colours, so there is no value that would make the test safe.

The stored address is also what makes the sprites work out. Order in the frame is `spr_restore_all`,
`scroll_frame`, `star_frame`, `spr_draw_all`: stars go on over the scenery and under everything that
flies. A sprite drawn over a star captures it into that slot's save area, and next frame
`spr_restore_all` puts it back — at the address `star_frame` is about to wipe.

## Why it needs no address of its own

The CPC increments each star's screen address every frame to cancel the scroll. We do not have to:
`corner_addr` already is that address.

A star is a sprite that never moves except when we move it, and `sprite.asm` places a sprite at
`corner_addr + 8 + row * 640 + col * 8 + scan`. `scroll_advance` running **after** the draw is what
makes a stationary sprite stationary — that is `BUGS.md` #7, and the whole of it applies here. So
`star_ofs` is a screen offset, the same in both banks, and the drift is the only thing that changes
it.

### Verified, not assumed

**That the offset really is a screen offset.** Breakpoint on the call site in the main loop, and at
each hit read `char_col`, `corner_addr` and `crtc_addr` out of zero page. The quantity that has to be
constant is the star's offset from the window the display will show for the bank being drawn:

```
S = corner_addr + 8 - 8 * (crtc_addr + 1 if char_col+1 is odd else crtc_addr)
```

— the `+1` because `frame_wait` parks `crtc_addr` *after* `scroll_advance` has run.

| sample | `char_col` | `corner_addr` | `crtc_addr` | S |
|---|---|---|---|---|
| 1 | `&CC` | `&4330` | `&0866` | 0 |
| 2 | `&CD` | `&4330` | `&0867` | 0 |
| 3 | `&CE` | `&4338` | `&0867` | 0 |

Both scroll parities and a `corner_addr` advance, S = 0 every time. Screen column 0 **is**
`corner_addr + 8`, so the tables are the screen offset and nothing else.

**That the drift is the right speed and the right ratio.** `star_col` read out of `&0923` before and
after exactly 100 game passes:

| | before | after | moved |
|---|---|---|---|
| cyan, mask 1 | 59 35 55 15 7 | 36 12 32 **72** **64** | −23 columns each |
| green, mask 3 | 6 26 64 42 54 | **75** 15 53 31 43 | −11 columns each |

Every star in a set moved by the same amount, the two sets are 2:1, and **three of them wrapped round
the left edge and came back at the right** (bold) — so that path is exercised and correct, not
theoretical. In fat pixels the leaders moved 47 and 23 against the level's 100, which is the half and
the quarter with the frame-count phase and the run's missed flips accounted for.

**And the picture.** Ten stars where the table says, in the colours the table says, drifting; the
ones over scenery correctly absent; and after 107 seconds of play the titles page comes back
undamaged, which is the check that nothing has been writing outside the buffer.

## Two things that are not the CPC's

**The colour swap is dropped.** The CPC exchanges its two colours every second frame "in time with
h-sync change, which will reduce visible impact of R3 effect on monitors that do not shift the screen
precisely half a character". We have no R3 and no shear, and at 25 Hz the swap would be a 12.5 Hz
flicker on each star — a defect where on the CPC it is a disguise.

**The colours are ours by the same rule as the artwork.** The CPC's star bytes `&0a` and `&20` are
mode 0 pens 10 and 4, which under the reversed `Mode0Pal` of decision 41 are cyan and green. MODE 2
logical 6 and 2 are the same two hues, so `&28` and `&08` — and they are the near and the far plane
respectively, cyan being the lighter of the two. Both are non-zero, which the blank test relies on.

## What it broke on the way in, and did not cause

The starfield's 18 bytes of main RAM pushed `explosion_dirs` from `&2024` to `&2036`. **Both are
inside `SPR_SAVE`**, the blitter's save area, so the player's explosion pieces had been liable to
lose their movement vectors since long before this layer — but moving the table changed which of the
player's saved bytes landed on it, and that is when it started showing. `BUGS.md` #13 has the
evidence and the fix; the table and the loop that reads it are in bank 1 now, beside this, and
`main.asm` asserts the ceiling that was missing. It is worth reading before adding anything else to
main RAM: `code_end` is seven bytes under `&2000` in a DEV build.

## Where it lives

Bank 1. The tables are in the 247 dead bytes between the zoom scroller and the tune's B1 stream at
`&B900`; the code is past it, in the bank's tail. Reached through `bank_call` like the zoom scroller
above it. Main RAM has 185 bytes free and this is more than half of them: the cost there is the two
call sites, 18 bytes, and main RAM went 185 to 167. Bank 1 has 314 left.

It reads `corner_addr` and `frame_count` in zero page and writes the play buffer, none of which is
paged, so being up in a sideways bank costs it nothing but the call.

`X` walks the star and `Y` the same star in the bank being drawn, which is why the screen byte is
reached through self-modified absolute addresses rather than `(zp),Y`: it leaves both index registers
to the loop. The body is past a branch's reach from the top of the loop, so the tail is
`bmi done : jmp loop`.

## The frame budget

**`star_frame` costs 676 µs a frame — 1,352 cycles, 1.7% of the 39,936 µs a 25 Hz frame has.** The
drift is 114 µs of that: the static version was 562. Measured, not counted — `tim_max_scroll` is the
phase `star_frame` sits in.

Three matched runs: same disc, same boot, the same 4,050 frames with the same single keypress, the
game being deterministic with no further input. The static run was repeated from a fresh machine and
gave byte-identical meters.

| µs, worst since boot | no stars | static | parallax |
|---|---|---|---|
| `spr_restore_all` | 8,904 | 9,820 | 9,819 |
| scroll **+ stars** | 5,455 | 6,017 | **6,131** |
| `spr_draw_all` | 21,487 | 23,463 | 23,497 |
| logic | 4,149 | 4,402 | 4,139 |
| **total** | **37,872** | 42,224 | **42,187** |
| missed flips in 2,684 frames | 1 | 18 | **19** |

**The total's jump and the other phases' deltas are not real work.** A frame that crosses from two
fields into three catches one more VSync interrupt, and the music player in it is 3,394 cycles —
1,697 µs. The same effect moves the per-phase maxima about: which phase is running when the interrupt
lands changes when the frame gets longer, and `spr_restore_all` and `spr_draw_all` do not otherwise
care that the stars exist.

**What is real is the missed flips: 1 in 2,684 becomes 19.** Seventeen of those eighteen belong to
the stars existing at all, and one to the drift. The stars did not make the frame expensive; the
frame was already within 1.4% of the line and there were eighteen frames sitting in that gap. For
scale, `PLAN.md`'s accepted figure before this layer was seven missed flips in 2,500 on the
deliberately brutal test — fire held, ship parked, dying over and over — and this measurement is the
gentler no-input version of the same scenario.

The levers, in the order they should be pulled:

1. **Fewer stars.** The cost is linear and the count is the CPC's, not the C64's: five stars is
   338 µs and would still read as a starfield, though it would cost one of the two depth planes
   unless the survivors are split differently. KC's call, being a design choice.
2. **The costed options in `BUGS.md` #9** — per-row spans in the blitter recover a quarter of the
   bytes it touches, and compiling the densest explosion frames recovers half their cycles. Both are
   worth more than the whole of this layer.
3. **Optimising `star_frame` itself is not one of them.** It is about 135 cycles a star to write two
   bytes, and the 16-bit add with the 16K wrap and the drift's read-modify-writes are most of it.
   Sharing one base pointer between the wipe and the plot is not available any more — the two are no
   longer a fixed 8 apart — and the remaining ideas are worth tens of cycles, not hundreds.

## Rejected

- **Testing the byte against the star's colour instead of storing the address**, which is what the
  CPC does. Not exact here; see above.
- **Keeping the static version's "minus one byte column" wipe** and correcting it for the drift. It
  is the same arithmetic as storing the address and it infers rather than remembers, which is the
  wrong way round when the thing it infers from can now change for two different reasons.
- **Deriving the byte and half from a screen-x byte** (`x >> 1`, `x AND 1`) at draw time. It is
  another `c * 8` per star per frame — about 20 cycles — where shifting `star_pix` in place is 7 and
  only on the frames a star actually steps.
- **Stepping every star every frame at different sub-pixel rates.** A fat pixel is the smallest thing
  MODE 2 can move; anything finer is a colour change, not a position.
- **Putting it in main RAM.** It fits — and leaves the build with almost nothing to its name. Bank 1
  had dead space.

## Left for later

- The stars freeze during the finale, because the level does and `star_frame` is inside the same
  `MODE_FINALE` test as `scroll_frame`. That is deliberate: with `corner_addr` standing still the
  stars would drift across a still background, which is worse than not moving. It does mean the
  finale's screen has ten stars nailed to it.
- The blank test is per bank, so a star at the very edge of a piece of scenery can be present in one
  bank and absent in the other, which is a 12.5 Hz flicker for as long as the edge takes to pass. The
  CPC has the same behaviour between its two screens. Not seen in play; noted in case it is.
- All five stars of a set move in lockstep and wrap at 160 pixels, so each plane repeats every 12.8 s
  (near) and 25.6 s (far). Nobody is going to see it, but if a third plane is ever wanted the obvious
  place to take it from is the star count rather than the frame.
