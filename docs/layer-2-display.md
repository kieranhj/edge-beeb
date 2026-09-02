# Layer 2 — display: rupture, IRQ, handover, keyboard, palette (2026-09-02)

## What was done

1. **Two-cycle CRTC rupture** (`src/rupture.asm`), cut down from Paradroid's three. Cycle A is
   the status panel: 5 rows (the C64's status bar height) at `PANEL_ADDR = &3000`, **inside the
   shadow-switched region and drawn into both banks** (`panel_init` runs once per X state). Cycle B is everything else: 34 rows
   with the 20-row play area at the top from the scrolling address, VSync at its row 29
   (absolute row 34, where MODE 2 puts it). Total 39 rows = 312 scanlines.

   | when | writes | why there |
   |---|---|---|
   | VSync IRQ (B row 29 + latency) | R6 = 5, R12/13 = panel; bank flip; restart T1 | R6 and R12/13 latch at the next cycle start |
   | fire 1 (A row 2) | R4 = 4; R6 = 20, R12/13 = play; T1 latch = long | R4 inside its own cycle before C4 reaches it; the rest for B |
   | fire 2 (B row 2) | R4 = 33 | inside its own cycle |

   R7 is a constant 29: A is only 5 rows so never reaches it. No R5, no R8: nothing scrolls
   vertically, so there are no partial rows to blank.

2. **Timing, measured in jsbeeb** with breakpoints on the two handlers and `elapsed_cycles`:
   VSync handler → fire 1 = 6,802 cycles = 53.1 scanlines; fire 1 → fire 2 = 5,122 cycles =
   40.0 scanlines. With Paradroid's 4-scanline CA1 service latency that puts fire 1 at A row
   2.1 (window: rows 0-3) and fire 2 at B row 2 (window: rows 0-32). Both have room. A third
   T1 fire never happens: the latch is set to 250 scanlines after fire 1 and VSync restarts T1
   at 216. The panel geometry was confirmed by poking white into panel rows 0 and 4 and
   screenshotting: 32 scanlines apart, play area starting immediately below.

3. **IRQ1V is ours** (`install_irq`): both VIAs silenced, T1 continuous, CA1 + T1 enabled.
   Nothing chains to the MOS, so its 100 Hz tick, OS sound and OSBYTE keyboard are gone.
   All disc loading happens before this.

4. **Frame handover.** The main loop no longer waits on OSBYTE 19 or touches `&FE34`/R12/13.
   It draws into the hidden bank, parks the scroll address in `crtc_park`, sets `frame_ready`
   and spins. The VSync handler flips both shadow bits and copies the park to `crtc_live` only
   when `FRAME_LOCK = 2` fields have passed since the last flip, so the scroll is a 25 Hz floor
   that degrades by whole fields and never tears: flip and address change together in
   vertical blanking, and fire 1 programs the play cycle from `crtc_live`. Confirmed: 10 game
   frames in 20 fields.

5. **Keyboard direct from the System VIA** (`keydown`, Paradroid's routine: X = internal key
   number, N = pressed). Z/X/:/? as before.

6. **Palette written** (`setup_display`): logical 0-7 → physical 0-7, logical 8-15 → 0-7
   again without flash, so logical 8 is the second black that sprites may use.

7. **`frame_count`** (25 Hz) drives animation; `char_col` is only the scroll phase now.

8. **Map wraps at the true end**, 302 columns, in `map_read` (decision 14). The C64 never
   reaches the end of its map: `wm_comp_flag` in the wave manager sets the completion flag
   first, so completion is Layer 5's.

9. **Boot order** (KC, 2026-09-02, after seeing the load on screen and a flickering panel):
   blank the display with R8 skew bits and turn the CRTC cursor off; load both banks in the
   MOS's boot mode (they stage through `&4000`); `VDU 22,2`; blank again (VDU 22 re-enables
   the display); `setup_display` sets the wrap, CRTC shape and palette, clears the 16K play
   buffer **and** draws the panel in **both** banks (`clear_play`, `panel_init` per X state),
   then re-enables the display; `install_irq` last. Stepped in jsbeeb: nothing but black from
   `*RUN` to the first game frame.

## Facts established

- **R8 blanking does not hide the CRTC cursor.** A one-frame white dash appeared during loading
  with R8 = `&30`: the MODE 7 prompt cursor blinking. R10 = `&20` alongside the blank fixes it.
- OSFILE loading 21K on the emulated 1770 DFS takes ~130 fields; the PC sits in the DFS NMI
  routine at `&0D50` for most of that, which is not a crash.

- **A panel at `&2000` (main RAM, below the shadow region) is NOT safe.** jsbeeb displayed it
  under both shadow states; b-em showed garbage on alternate frames (KC, 2026-09-02). The two
  emulators disagree about what the video circuit fetches below `&3000` with the D bit set, so
  the panel moved to `&3000` in both banks (decision 17). Real hardware untested either way.
- The jsbeeb screenshot crops to the active display, so absolute row positions in it move when
  the display start moves. Measure geometry with poked patterns, not by pixel position.
- `run_for_cycles` with a breakpoint set: the call that lands on a breakpoint may report the
  full cycle count, and the next call returns 0 without moving; a second call moves on. Take
  the clock from `read_registers` every time.
- Main RAM after this layer: code `&0E00-&15F5`, data to `&1AB0`; `GUARD CODE_TOP` (`&2000`)
  is the image's ceiling. `&2000-&2FFF` is reserved for the Layer 3 sprite saves (8 slots × 256 B
  × 2 banks fits exactly); `&3C80-&3FFF` in each bank is free.

## Rejected

- Three cycles as in Paradroid: the third exists there to give R5 room around the vertical
  scroll; with nothing to adjust, VSync sits inside the play cycle at the MODE 2 row.
- Writing R7 per cycle: a constant that never falls inside cycle A costs two writes a frame
  less and has no window to miss.

## Left for later

- The panel holds a DEV-only placeholder (`fill_panel_test` in `rupture.asm`): white lines on
  its top and bottom scanlines and sixteen colour bars, logical 0-15, which double as a palette
  check (8-15 show as 0-7, no flash). Release builds get a black panel. The HUD (score,
  hi-score, lives) is Layer 6; the C64 `status.chr` charset is in `source_c64/data`.
- No debug raster tint or buffer oracle yet; add with Layer 3 when there is something to
  measure against.
