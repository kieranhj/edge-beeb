# Where the frame goes

Measured 2026-09-04, at commit `da2ce05` plus the frame-meter fix below. The unit throughout is
**2 MHz cycles**, because that is what the rest of `docs/` counts in. **A 25 Hz frame is 79,872
cycles** (39,936 us). The meter reports microseconds; double them.

It also revisits `BUGS.md` #9 - "the game drops below 25 Hz while shooting" - which Layer 6a closed
and which this measurement finds has partly come back.

## How it was measured

`src/timing.asm`, the frame meter, is the instrument, and `DEBUG_TIMING` is on in every DEV build.
It splits the frame four ways. For this exercise it was **temporarily** widened to nine phases -
marks added inside `game_tick`, which is called twice a frame, so those slots read PER TICK - the
game was run in jsbeeb, and the widening was then reverted. Only the fix below was kept. To
repeat the exercise, add `TIM_` slots beside the existing ones and put `TIMMARK` calls where the
boundaries need to be; the slots live in the `&0800` block, which has room.

Read the slots straight out of memory rather than adding a display: they sit at the top of the game
state block, ending at `game_state_end`, which the build prints (`GAME STATE = &800 to &91B`, so
`tim_slots_start` = `&90F` today).

**Three traps, all of which caught this measurement before the numbers came good:**

1. **T2's two bytes are read one after the other and the counter can roll between them**, so
   elapsed can come out 256 us SMALLER than the mark before it. `tim_keep` compares unsigned, so
   one bad read is stored as a ~65,000 us maximum and poisons that slot for the whole run. Three
   readings out of three were junk this way. Fixed - see below.
2. **A frame longer than 65.5 ms wraps the counter outright.** Deaths, the titles and mode changes
   all do it; one frame was measured at 234 fields, which is 4.7 seconds. `tim_fields` is the tell.
   Fixed for the total, and the fix in (1) happens to reject the phases too.
3. **A phase maximum includes any INTERRUPT that landed inside it**, and there are six a frame.
   On the short phases that is most of the figure - `read_joystick`'s maximum is 3,632 cycles
   against a true cost near 644, the difference being one music interrupt. **Take worst cases from
   the maxima and typical costs from a single-frame sample**: zero the slots, run four fields, read.

The music figure is not from the meter. It is the VGI player's own measured cost from
`BEEB/Repos/vgm-player-bbc/docs/vgi-player.md`, which is legitimate because `lib/vgiplayer.asm` is
copied here unaltered. The rupture handler is a static cycle count off `build/EDGE.lst`.

The play sample is continuous fire (L held) in the opening minute of the map.

## The frame, phase by phase

| Phase | Typical busy frame | Lighter frame | Worst in 2,000 frames |
|---|--:|--:|--:|
| `spr_restore_all` | 11,988 | 8,806 | 19,224 |
| `scroll_frame` - the level plot | 11,784 | 11,902 | 12,392 |
| `spr_draw_all` - includes the background save | 32,066 | 23,136 | 46,866 |
| `read_joystick` + `pause_check` | 644 | 644 | 3,632 |
| `player_manage` + `bullet_manage`, x2 ticks | 1,016 | 1,016 | 5,748 |
| `enemy_manage` + `multimate`, x2 ticks | 3,332 | 4,452 | 8,432 |
| `life_cycle`, x2 ticks | 452 | 432 | 4,552 |
| `scroll_advance` | 270 | 210 | 2,558 |
| `status_call` - the HUD | 1,046 | 1,046 | 3,498 |
| **the whole frame** | **62,130** | **49,546** | **85,754** |
| | **78%** of budget | 62% | **107%** |

The worst-case column cannot be summed: those maxima are from different frames, and the short ones
are mostly trap 3.

Rolled up, the typical busy frame:

| | share |
|---|--:|
| **Sprites** - draw 40%, restore 15% | **71%** |
| **Level plotting** | **15%** |
| **Game logic** - enemies 5.4%, player 1.6%, life cycle 0.7% | **8%** |
| HUD 1.7%, scroll advance 0.4% | 2% |
| **IRQ and music**, spread through all of the above | **~5%** |

## Interrupts and music

Per 50 Hz field, from a static count of the listing except where noted:

| | cycles |
|---|--:|
| `irq_handler` dispatch, x3 fires (T1 twice, VSync once) | ~140 |
| `rupt_timer`, x2 | ~110 |
| `rupt_vsync`, its own code | ~150 |
| `keydown` (the Q mute test) | 45 |
| **the VGI player**, mean / max - measured, not counted | **1,569 / 2,674** |

**~4,030 cycles a game frame typical, ~6,240 worst: 5% to 7.8%**, and the music is nine tenths of
it. All of this is already inside the phase figures above, which is why a short phase's maximum is
so much larger than its real cost.

## BUGS.md #9, and the headroom that has gone since

**#9's fix stands, but the room it bought has been spent.** Layer 6a closed it with a measurement
of *no missed flips in ~2,500 game frames* and a worst frame of 72,106 cycles - 90% of budget.
This measurement, over 2,000 frames of continuous fire:

| | Layer 6a, when #9 was closed | now |
|---|--:|--:|
| worst frame | 72,106 (90%) | **85,754 (107%)** |
| frames that missed their flip | **none** in ~2,500 | **7** in 2,000 (0.35%) |

Some of that is the sample - this run held fire continuously and included deaths, which #9's did
not say it did - but not all of it, and the arithmetic says where the rest went. **Layer 6a
predates both the HUD and the music.** `status_call` costs about 1,046 cycles a frame and the VGI
player about 4,030, which is ~5,100 of the ~13,600 difference on its own.

So the position is: **the game is marginally over budget on its worst frames again, not chronically
slow.** 0.35% of frames drop, which is a stutter rather than a slowdown. The optimisations below
are sized to put the worst frame back under 79,872.

`tim_over` and `tim_fields` are the definitive readings here, and they need no clock at all: they
count fields. `BUGS.md` #9's "no missed flips" line is now out of date.

## Low-hanging fruit

Ranked by cycles saved per byte of code spent. **Space is the binding constraint on all of it** -
145 bytes free in main RAM, 178 in bank 0 (`docs/memory-map.md`), and the scroll and sprite engine
are both in main RAM.

### 1. Unroll the scroll's three inner loops - the best deal in the build

All three pay `dex`/`bpl` or `inx`/`cpx`/`bcc` on every single byte:

| Loop | now | unrolled x8 | saved |
|---|--:|--:|--:|
| `rotate_column_buffer` - 160 bytes | 20 cyc/byte | 13 | ~1,120 |
| `plot_char_y` inner - 20 x 8 bytes | 18 cyc/byte | 13 | ~800 |
| `copy_column_buffer` inner - 20 x 8 bytes | 14 cyc/byte | 9 | ~800 |

**~2,700 cycles a frame - 23% of the scroll, 3.4% of the frame - for roughly 150-250 bytes.**

A cross-check that the model is sound: statically counting these three plus the tile reads gives
10,000-11,800 cycles against the 11,784 the meter measured.

### 2. Address the sprite save area absolutely, not indirectly

The save page is a FIXED 256-byte page per (bank, slot) - `HI(SPR_SAVE) + bank*8 + slot` - and its
Y offsets already mirror the screen's, which is the whole reason one Y serves both. So the save
side does not need an indirect pointer at all:

| | now | self-modified absolute,Y | |
|---|--:|--:|---|
| draw, per byte | `sta (svp), y` 6 | `sta SAVEPAGE, y` 5 | -1 of 36 |
| restore, per byte | `lda (svp), y` 5 | `lda SAVEPAGE, y` 4 | -1 of 13 |

**~2,000-2,800 cycles a frame (2.5-3.5%)** for one patched byte per slot, and `svp` gives back two
bytes of zero page.

### 3. Blocked on space, but worth more

- **Compiled bodies for more frames.** 36 cycles a byte becomes about 14. This is the only change
  that moves the 40% draw figure materially. The bullet alone compiles to 2,652 bytes and bank 3
  has 195 free, so it needs `MUSIC_AKL` to win and free its 9K first.
- **Unrolling the sprite row loop.** The `jsr &ffff` / `rts` pair costs 12 cycles a scanline, up to
  ~2,000 a frame, but inlining the bodies per row is expensive in bytes.
- **`VGI_UNROLL = 1`.** Measured at 1,149 cycles a field against 1,569, so ~840 a frame (1%), for
  about 512 bytes. HAZEL has 223 free, so it does not fit today.

### 4. Leave the logic alone

Enemies are the largest logic item at 5.4% of the frame, and that code is a verbatim transcription
of the C64's. The cost is in the right place.

### The shape of it

**The sprite engine is the frame**, and the only large win there is compiled bodies, which is a
memory decision rather than a code one. Items 1 and 2 together are worth **5,000-5,500 cycles a
frame, about 7%**, for a few hundred bytes: enough to take the worst frame from 107% of budget to
roughly 100%, and the typical one from 78% to 71%.

## The frame-meter fix that came out of this

Landed with this page, in `src/timing.asm`. Two changes, both in the "do not trust a reading you
have not questioned" spirit:

- **`tim_mark` throws away a sample that comes out going backwards.** The subtraction's carry says
  so; `bcs tim_keep`, else `rts`. This is trap 1, and it also rejects most of trap 2, because a
  wrapped clock reads as running backwards too.
- **`tim_handover` will not keep a total from a frame of four fields or more.** Four fields is
  80 ms and T2 wraps at 65.5, so `tim_val` is a random number there and keeping it would pin
  `tim_max_total` near 65,535 for the rest of the run. Two and three fields are honest overruns and
  are still kept. The field count was already being computed for `tim_over`, so the test is free;
  the routine was reordered to do the clock-free readings first.

**Verified**: 4,000 frames of play including deaths and a 26-field frame - the exact shape that
used to poison the slots - and every reading came back plausible and consistent with the
single-frame samples.

## See also

- [`docs/memory-map.md`](memory-map.md) - what is free, which is what gates every optimisation here
- [`docs/layer-3-sprites.md`](layer-3-sprites.md) - the engine, the 36-cycle body and the compiled bodies
- [`docs/layer-7-music.md`](layer-7-music.md) - the VGI player and the bank 3 / HAZEL budget
- `BUGS.md` #9 - closed in Layer 6a; its "no missed flips" measurement no longer holds
