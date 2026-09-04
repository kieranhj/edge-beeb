# Layer 6b — the life cycle

**Done 2026-09-03.** `coll_flag` was set by two Layer 4 collision checks and read by nothing. It is
read now: three lives, the player bursting into six pieces on the C64's own direction vectors, a
drop-in shield, and a game-over sequence that runs the level out with the player gone and then
starts a new game.

Transcription throughout, from the C64's `main_init`, `main_dropin`, the block between
`scroll_manage` and `life_lost_init`, `life_lost_init`, `life_lost_loop`, `game_over_init` and
`game_over_loop`. Two decisions, [30](decisions.md) and [31](decisions.md).

## What runs where

| C64 | here |
|---|---|
| `main_init` | `game_init` (`src/main.asm`) |
| `main_dropin` | `player_dropin` (`src/player.asm`) |
| the shield / `coll_flag` block at the end of `main_loop_2` | `life_cycle` |
| `life_lost_init` + `life_lost_loop` | `life_lost` |
| `game_over_init` | `game_over_init` |
| `game_over_loop` | the main loop, with `player_live` = 0 |
| `explosion_dirs` | the same 16 bytes, in `src/tables.asm` |

New state, all in the `&0800` block: `lives`, `player_shield`, `player_live`, `restart_req`.

## The shape of it

**`life_cycle` runs at the end of `game_tick`**, which is where the C64 has it: after
`player_manage`, `enemy_manage` and `scroll_manage`, once per 50 Hz iteration. Ours is called twice
a display frame (decision 23), so `PLY_SHIELD` = &32 and `GAME_OVER_TICKS` = &c8 last the wall-clock
time the original gives them without being touched.

The shield's decrement is the C64's, quirk included: it runs even when the shield is already zero,
wraps to &ff and is put back to zero. It is not a `beq` and should not become one.

**A life lost is not a state.** `life_lost` fills all six pool slots with the player's position, one
of `explosion_dirs`' movement commands and the explosion animation, decrements `lives`, and drops
the player straight back in with a shield — he keeps the position he died at, and whatever was
flying in the pool is simply overwritten. `enemy_bounds` and `explosion_chk` free the six slots
again as they would any other explosion, so the pieces cost nothing extra and the wave manager gets
its slots back on its own.

**Game over is one flag.** `game_over_init` zeroes the player's and the bullet's positions and
clears `player_live`; `game_tick` then skips `player_manage`, which is exactly how the C64's
`game_over_loop` is built — it calls `enemy_manage` and `scroll_manage` and nothing else. With
`player_manage` gone nothing can set `coll_flag`, so it is free to be the &c8-tick countdown, and
that is what the original uses it for too.

Zeroing the position hides the player for the same reason it does on the C64: `SPR_Y_OFF` is 90, so
y = 0 puts him 90 scanlines above the play area and the clipper draws nothing.

## The restart, and why it is at the top of the loop

The C64's `game_over_loop` ends by jumping back to the title screen's `master_loop`. There is no
title screen yet (Layers 6c and 6e), so the countdown sets `restart_req` and the **main loop** calls
`game_init` — decision 31.

`game_init` is the old boot sequence lifted into a routine and called from both places: scroll
addresses, `spr_init`, `coll_init`, `score_reset`, `sprite_reset`, three lives, `player_dropin`, the
column buffer, `map_read_rst`, and `scroll_prewind` between two writes of R8. It takes about 0.9 s,
all of it behind a blanked display, which is what the C64 does with `$d011` in the same place.

Two things make it safe to call with the IRQ running, and both are why the call is at the **top** of
the loop rather than inside `game_tick`:

- `scroll_prewind` flips `&FE34` itself. The VSync handler only flips when `frame_ready` is set, and
  at the top of the loop it is 0 and stays 0 until the handover at the bottom. The prewind's 160
  flips are even, so the bank parity comes back where it started.
- `spr_init` has to run before the next `spr_restore_all`, because the save areas still hold the
  last game's backgrounds and the restore would put them back over the new screen.

The restart frame is a missed flip and the `DEBUG_TIMING` meter will record it as one. That is
cosmetic: the display is blanked for the whole of it.

## `DEBUG_COLL`

Repurposed (decision 30) and **now defaults to 0 even in a DEV build**, because dying is the normal
case and the layer is not testable with it on. What it does now is the C64 source's own
`jmp life_lost_init ; patch me out to disable collisions!` — patched out. The old meaning, a hit
flashing the player instead of killing him, has nothing left to stand in for.

## Measured

jsbeeb, Master 128, DEV build.

- A hit with the shield down: `lives` 3 → 2, six explosions at the player's position, `player_shield`
  back to &32 and counting.
- A hit with the shield up: absorbed, `lives` unchanged. `coll_flag` is cleared before it is read,
  as the C64 does it.
- The shield counts down at two per display frame, confirming `life_cycle` is on the tick and not on
  the frame: &29 → &09 across 32 fields.
- The third hit: `lives` 0, `player_live` 0, player and bullet gone, `coll_flag` counting down from
  &c8 while the scenery and the waves carry on.
- At the end of it: a new game, `lives` 3, the player back at &28,&a0, the map wound back to the
  start and the screen prefilled.
- Flying into the scenery does the same thing as poking `coll_flag`, which is the whole of the path
  Layer 4 already had.
- After the fix to `BUGS.md` #10: forcing the wave manager's skip path advances the reader by
  exactly 9, and across 3,500 frames of repeated deaths and restarts the read pointer stayed a whole
  multiple of nine bytes from the start of the table.

## The bug the layer found: `BUGS.md` #10

The first build of this layer made enemies stop coming, or arrive as nonsense, after the player
exploded — and which of those you got depended on which wave you died on. It was not in the layer's
own code. `wave_manager`'s no-free-slot path skipped **eight** bytes of a **nine**-byte wave, so the
reader sat one byte inside every wave afterwards and every field came out as the next one along.

That path had never run before. It needs all six pool slots full at once, which ordinary waves never
manage — and `life_lost` filling all six with pieces of the player in a single tick is the first
thing in the game that does. So the layer that read `coll_flag` was also the first thing to reach a
path that had been wrong since Layer 5. `BUGS.md` #10 has the detail.

The lesson for the layers still to come: **a path that has never executed is not a tested path**,
and adding a caller is what tests it.

## Memory

Main RAM after the layer: **`&FC` free** below `&2000` in a DEV build (`&1F04`), `&1EE7` under
`RELEASE`. The layer cost about 120 bytes of code and the 16 bytes of `explosion_dirs`; the boot
sequence becoming `game_init` was free. Take live figures from the listing.

The frame budget is unmoved: `life_cycle` is about 30 cycles a tick.

## What this layer does not do

- **Titles, pause and Q-to-abort** are 6c. `comp_flag` is still set and still not read.
- **`lives` is not displayed.** The panel is still the colour-bar placeholder; 6d.
- The completion sequence and its bonus are 6c; the "mega hero" message is 9c.
