# Layer 6e — the title screen: the zoom scroller and the raster colours

**Done 2026-09-04.** The titles page moves: a six-row zoom scroller across the bottom, the same
message rotated 180 degrees across the top, and the C64's colour pulse on the first and last credit
lines. Four CRTC cycles, both zoom bands hardware-scrolled, and the display bank switched inside the
frame. Decisions [44](decisions.md), [45](decisions.md) and [46](decisions.md).

## 1. What the original does

`source_c64/edge_grinder.asm`, `ttl_loop` then `zoom_mover`, `ttl_pulse`, and the `ttl_clear` /
`ttl_init` block above them. The C64's titles page is four bands of a 25-row screen:

| C64 rows | what |
|---|---|
| 0-4 | the status bar |
| 5-10 | the **mirror band**: the zoom scroller, rotated 180 degrees |
| 11 | blank |
| 12-17 | the credits, five lines on rows 12, 14, 15, 16, 17 |
| 18 | blank |
| 19-24 | the **zoom band**: a six-row-high scrolling message |

**The zoom scroller is a bitmap of character cells.** `zoom_mover` shifts rows 19-24 left by one
whole character per frame (`lda buffer_1+$2f9,x : sta buffer_1+$2f8,x`, 37 columns, six rows), then
writes a new column at column 37 out of `zoom_buffer+$01` to `+$06`: one `asl` per row, and the carry
picks `$8e` (a block) or `$00` (blank). So a zoom pixel is one 8x8 character and it moves 8 screen
pixels a frame at 50 Hz.

`zoom_buffer` is eight bytes of an 8x8 **1bpp font**, refetched every eighth frame from
`$4d00 + glyph*8`. That address is inside `status.chr`, which the C64 loads at `$4800`: `$4d00` is
**character `$a0`**, and `$a0`-`$bf` are a 32-glyph hires alphabet with rows 0 and 7 blank — which is
why the scroller uses bytes 1-6 and is six rows high. The exporter asserts that emptiness rather than
trusting the reading of it.

**The mirror band is a 180-degree rotation, recopied every frame**: `zoom_mirror` walks `y` down from
`$25` and `x` up to `$26`, reversing both axes, 228 character copies a frame.

**The C64's colour effect is horizontal.** `ttl_pulse` shifts colour RAM one cell to the right along
the last credit line and writes the same byte leftwards along the first, pushing a new colour in from
`status_pulse` every two frames. MODE 2 has no colour RAM; section 5 is what replaces it.

`scrolltext` is 468 characters and ends in `$00`.

**Since Layer 9f the message is `assets/scrolltext.txt` and is meant to be edited** (decision 54).
`tools/export_zoom.py` reads it — lines joined end to end with nothing added, `#` and blank lines
dropped — and refuses a character the font has not got, naming the line. It is seeded with the
C64's own text, verbatim. **It also moved**: behind the font in bank 1 it had eleven bytes of
headroom, which is no use for a file a person is supposed to change, so it rides in the `PANEL`
disc file at `TTL_SCROLL` with the second credit set and has 237 characters to grow into. The build
prints `SCROLLTEXT HEADROOM`, and bank 1's hole went from 11 bytes to 475.

## 2. What the CPC does, and what of it ports

`source_cpc/Source/EG_Zoom.asm` and the `int_rout*title` chain in `EG_Interrupts2.asm`. The CPC has
the same 6845 and its title screen is **four CRTC cycles** — top band, credits, bottom band, panel —
with **both bands hardware-scrolled**: `WriteZSColumn` decrements `HighZoomScrlOffset`, increments
`LowZoomScrlOffset`, and draws one new column at the incoming edge. The C64's copy loop and its
`zoom_mirror` are replaced by two register writes.

It can give each band a ring because of a CPC-only property its own source states — *"this offset is
the crtc offset, so should be 0-&3ff"*. The CPC video address is
`((R12 AND &30) << 10) OR (RA << 11) OR ((MA AND &3ff) << 1)`: the address counter is masked to ten
bits, so every scanline wraps inside its own 2K block.

Its colour effect is `TitleRaster` — nine scanlines of writes to pens 13 and 14 from a cycling list,
called twice a frame, the second line indexing the list from the other end. Axelay met the same wall
we do and turned the C64's horizontal cycle through ninety degrees. Both of those are what we port.

## 3. The mechanism: hardware scroll, two rings, two banks

**KC's design.** A CRTC cycle per band, each hardware-scrolled by its own R12/R13, each band's memory
made a ring by the **8K display wrap**, and the two rings kept apart by putting one band in MAIN and
the other in SHADOW with the display bit switched inside the frame.

### The shear, and why we were already paying it

Our CRTC address does not wrap per row. A MODE 2 character row is 640 contiguous bytes and rows
follow one another, so a band whose start address advances by a byte column **shears**: row `r` loses
its leftmost column and gains, at its right edge, the column row `r+1` has just lost.

**The play area has been paying that since Layer 2.** `scroll_advance` advances `crtc_addr` and
`col_copy` writes the incoming byte column into all twenty rows at `corner_addr`, 640 apart. Work the
arithmetic through and the two line up exactly: an address written for row `r` at step `t` is written
again for row `r-1` at step `t+80`, which is the step the display migrates it. So the shear is paid by
writing the incoming cell into **every row** — which is what `zoom_mover` does anyway. A zoom band is
the play area's own trick at six rows instead of twenty, and the whole per-frame cost is the
original's new-column write.

### The ring, and why the bands are in different banks

A band still needs somewhere to slide. The play area sweeps its whole 16K and owns all of it; a band
that swept 16K would trample the credits and the other band. **Measured in jsbeeb, 2026-09-04**: the
display wrap is System VIA addressable latch lines 4 and 5, and the four sizes are **20K, 16K, 10K
and 8K** — not powers of two —

| line 4 | line 5 | wraps `&8000` to | size |
|---|---|---|---|
| 0 | 0 | `&4000` | 16K, what `setup_display` sets |
| **1** | **0** | **`&6000`** | **8K, this layer's ring** |
| 0 | 1 | `&3000` | 20K, the MOS's own for MODE 2 |
| 1 | 1 | `&5800` | 10K |

At 8K the ring is `&6000-&7FFF`: 1,024 byte columns against the 480 a six-row band shows. That is
**one ring per bank, and only one** — the larger sizes contain it and there is nothing smaller — so
two bands need two banks. Also measured: **the display bank can be switched mid-frame**, taking
effect at the next character fetch, and **the wrap stays inside whichever bank is displayed**. All
three are in CLAUDE.md's measured-facts list.

### The map and the cycles

| | MAIN | SHADOW |
|---|---|---|
| `&3000-&3C7F` | panel | panel (drawn into both, decision 17) |
| `&4000-&4EFF` | — | the credits block, 6 rows |
| `&6000-&7FFF` | **top band ring** | **bottom band ring** |

| cycle | abs rows | R4 | R6 | address | display bank |
|---|---|---|---|---|---|
| A | 0-4 | 4 | 5 | `&3000` | MAIN |
| B | 5-11 | 6 | 6 | top band, moving | MAIN |
| C | 12-18 | 6 | 6 | `&4000`, fixed | **SHADOW** |
| D | 19-38 | 19 | 6 | bottom band, moving | SHADOW |

Cycles B and C are seven rows with six displayed, and their blank seventh row is the C64's own blank
row either side of the credits. **B's is where the display bank is switched**: it is fetched by
nobody, so the write has a whole row of slack instead of one line's blanking. R7 is a constant 15, as
it is a constant in the game: it is past the end of A, B and C and can only be reached in D.

Six T1 fires against the game's two:

| fire | abs row | what |
|---|---|---|
| 1 | 2 | R4 for A; R6 and R12/13 for B |
| 2 | 7 | R4 for B, which C inherits unchanged; R6 and R12/13 for C |
| 3 | 11 | display bank → SHADOW |
| 4 | 12 | the first raster, then R6 and R12/13 for D |
| 5 | 17 | the second raster |
| 6 | 20 | R4 for D, and the pulse on a step |

**Fire 6 is not optional, and the first build proved it.** R4 has to be written inside its own cycle,
and every other candidate is outside D: fire 5 is still in C, where R4 = 19 would stretch C to twenty
rows, and the VSync handler is too late in a worse way — with R4 still 6 from cycle C, D never reaches
R7 = 15, so VSync never happens and the handler that was to fix it never runs. Built that way first,
it hung in `field_wait` with `field_count` frozen at 10.

The first two intervals are the game's own, unaltered: cycle A is the same five rows and B starts in
the same place.

### One field, one cell

**The titles are not on the game's 25 Hz lock** (decision 46). There is no double buffer here — both
banks are on screen inside the same frame — so `field_wait` and one zoom cell a field give the C64's
own rate and granularity: 4 pixels of a 160-pixel screen is the 2.5% its 8 pixels of 320 is, at the
same 50 Hz. Decision 23's doubling has nothing to do.

The writes go into memory that is displayed, so they are scheduled rather than incidental. Each band
is fetched only during its own cycle, so the top band must be finished by absolute row 5 and the
bottom by row 19; `ttl_frame` runs straight after the VSync handler returns and does the top band
first for that reason. 96 bytes a band, about 1,700 cycles each.

## 4. Layout — the C64's rows land on ours exactly

The C64's 5-row status bar and 20 rows of titles are our panel and our play area, so its rows 5-24
are our play rows 0-19 and the page transcribes 1:1 with nothing re-centred:

| C64 row | our play row | what |
|---|---|---|
| 5-10 | 0-5 | mirror band |
| 11 | 6 | blank |
| 12, 14-17 | 7, 9-12 | the five credit lines |
| 13, 18 | 8, 13 | blank |
| 19-24 | 14-19 | zoom band |

That moves the credits **up one row** from where 6c put them (`title_rows` 8, 10, 11, 12, 13 becomes
0, 2, 3, 4, 5 — and they are now rows of the credits block, not of the play area). 6c re-centred them
because there was nothing else on the page. It was listed as an open question in the plan and is not
one: 6 + 1 + 6 + 1 + 6 is exactly 20, so with the bands in there is nowhere else for them to go.

A zoom cell is 2 byte columns = 4 MODE 2 pixels, and the band is the full 40 cells of the screen
rather than the C64's 38 — its two spare columns were an artefact of a 37-wide copy loop, and a
hardware-scrolled band has no reason to stop short.

The C64's block character is `$8e`, and it is **not solid**: read as multicolour it is a
three-colour texture, and `ttl_clear` gives the whole band colour RAM `$0d`, light green. Four
multicolour pixels is one of our cells, so it transcribes into 16 bytes with pair 1 blue, pair 2 cyan
(the colours `export_title.py` already gives the credits) and pair 3 the C64's own light green.

## 5. The colour effect

Ported from the CPC's `TitleRaster`, **with the CPC's own colours** (decision 45): eight scanlines of
`&FE21` writes on each of the two credit lines, the same list indexed from opposite ends, stepping
once every two fields as `ttl_pulse_tmr` does.

`RasterPal` is 48 bytes — sixteen steps of two Gate Array colours, then the first eight repeated so an
eight-step window starting at step 15 can run off the end. `TitleRaster` reads each pair backwards
from how it is written (`ld d,(hl)` then `ld e,(hl)`, and `e` goes to pen 13, `d` to pen 14), so the
first byte is the **body** and the second the **trailing** colour, four steps behind it. Decoded
through `tools/cpc/cpcscr.py`'s Gate Array table it is a heat pulse, and collapsed to MODE 2's eight
by hue exactly as decision 41 collapses the artwork:

| step | CPC body | ours | CPC trailing | ours |
|---|---|---|---|---|
| 0 | `&5c` red | red | `&54` black | black |
| 1 | `&58` bright blue | blue | `&54` black | black |
| 2 | `&4c` bright red | red | `&5c` red | red |
| 3 | `&45` purple | magenta | `&5c` red | red |
| 4 | `&4e` orange | red | `&58` bright blue | blue |
| 5 | `&47` pink | magenta | `&58` bright blue | blue |
| 6 | `&4a` bright yellow | yellow | `&4c` bright red | red |
| 7 | `&43` pastel yellow | yellow | `&4c` bright red | red |
| 8 | `&4b` bright white | white | `&4e` orange | red |
| 9-15 | steps 7 down to 1 | | | |

**The collapse doubles three of the nine steps** — bright red and orange land on red with plain red,
pastel yellow on yellow with bright yellow, pink on magenta with purple — so nine colours become six
and the ramp has flat spots the CPC's has not. Faithful is what is built; KC's eye has the last word.

**Since Layer 9e these are logicals 15, 14 and 12, not 7, 6 and 4** (decision 53): the credits'
font was moved onto the top half of the palette, which `setup_display` maps back onto the same
colours but which nothing else on this page uses, so the credits can be faded on the palette alone.
Every byte of `ttl_pal` is the old one plus `&80`, the restore at the end of `ttl_raster` goes with
it, and `ttl_fade_on` skips the whole routine while a crossfade is running. Nothing else here
changed.

Logical 7 takes the body list and logical 6 the trailing one, and logical 4 is left alone as the
shadow. That is the like-for-like reading of the CPC's two pens and it also keeps the C64's own
choice, because pair 3 — our logical 7 — is the one `ttl_pulse` moves through colour RAM.

**The `&FE21` encoding needed no measuring**: `setup_display` already writes
`(logical << 4) OR (physical EOR 7)` and maps logical 8-15 back onto 0-7 without the flash bit, so
one write changes one colour and the flashing half needs nothing.

The raster block is a loop padded to one scanline rather than eight unrolled ones — 30 bytes against
160. It is stable because every iteration opens with a write to `&FE21`, which is on the 1 MHz bus:
the CPU stalls to the same phase each time, so the loop cannot drift by an odd cycle.
`TTL_RASTER_PAD` is tuned by looking at the screen.

## 6. Where it all lives

| thing | bytes | where |
|---|---|---|
| zoom font, block cell, message (`src/data/zoom.bin`) | 741 | bank 1 |
| the scroller, the ring arithmetic, the raster, the four-cycle rupture | ~700 | bank 1 |
| `ttl_active` | 1 | main RAM, beside `music_mute` |
| the IRQ's dispatch to bank 1 | ~18 | main RAM |
| `title_page` | ~150 | bank 0 |

**Bank 1**, because nothing on the titles page reads a sprite and it had 3,501 bytes free where main
RAM had 145 and bank 0 had 178. `bank3_call` grew a second entry, `bank_call`, taking the bank in A;
that is the only main-RAM cost besides the flag and the dispatch. The title rupture handler is paged
in from the IRQ the way the music player already is, with `&F4` putting back whatever the foreground
had.

**`title_page` stays in bank 0** and cannot move: bank 0 code may call into main RAM and be returned
to, because `bank_call` restores `SWRAM_DATA` — which is exactly why bank 1 code cannot call it.

**Bank 0 is now the tightest thing in the build**: 18 bytes free in a DEV build, 184 in a RELEASE
one, the frame meter being the difference. Take live figures from the listing.

## 7. How it was verified

**The band is checked against a model, not a screenshot** — the same shape of check Layer 2 uses for
the scroll, and for the same reason: the picture can look right while the ring is one column out.

The whole 8K ring is read out of jsbeeb and every 16-byte cell must be exactly the block or exactly
the blank (512 of 512, both bands). The six cells 40 apart that make up a displayed column are
decoded back to six bits and matched against the message rendered through the font in Python:

- **bottom band: 40 of 40 columns, no mismatches**, at message column 185 — the band reading "ED BY"
  out of "developed by cosine"
- **top band: 40 of 40 columns**, matched against the 180-degree rotation (rows reversed, columns
  reversed), **at the same message column 185** — which is the proof that the two bands are in step,
  not merely that each is self-consistent

Reading the shadow ring needs nothing special; reading the main one needs the CPU's X bit cleared,
which `ttl_frame` sets per band anyway.

On top of that: the four cycles land where they should with no overlap, the mid-frame bank switch is
clean, the raster colours the first and last credit lines and leaves the other three, the panel and
the bands are white and green as before, and the round trip works — titles, fire, a game, pause,
ESCAPE, the game-over count, and back to the titles with the message restarted.

## 8. What is left

- **`TTL_RASTER_PAD` is set at 18 and has not been tuned against a scanline count.** It looks right;
  a drift of a scanline either way would land in the blank rows above and below the credit lines and
  would not show. Worth a proper look before release.
- **The raster's own colours**, if KC wants the flat spots in section 5 nudged apart.
- **b-em**, which has not seen any of this. Decision 17 is why that still matters.

## The switch between the two shapes is not clean — 2026-09-04

`BUGS.md` #14. Changing between the game's two-cycle rupture and this four-cycle one costs **one
malformed field** — 272 lines against 312, measured in jsbeeb by stepping fields one at a time —
because R7 and the display wrap are written from main-loop code while `rupt_vsync` schedules the
T1 fire sequence from `ttl_active`, and the three cannot be made to agree from out there. Two
placements were tried and both were worse; the fix is to move the switch into the VSync handler,
which is the one place that owns all three at the same instant. The full measurement, both failed
attempts and the numbers are in the bug.
