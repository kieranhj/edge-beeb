# Layer 5 — enemies and attack waves (2026-09-03)

The pool is live. `src/enemy.asm` is a transcription of the C64's `wave_manager`, `wave_read`, the
movement half of `enemy_manage`, `emove_*`, `enemy_bounds`, `enemy_colls` and `explosion_chk`;
`player_s_colls` in `player.asm` stops being a stub. The `DEBUG_SPRITES` harness is gone — slots 2-7
now hold real enemies from the real table.

## The wave table

**201 waves, not the 54 `PLAN.md` claimed** — that figure was wrong from the start and is corrected
here. Nine bytes each: start x and y, two movement commands, the timer value the enemy rocks between
them at, the value that timer wraps at, the object, its shielding, and the delay before the next
wave. A record whose first byte is `$ff` ends the table and raises `comp_flag`.

It is written with symbolic constants in the original — `left_1`, `left_1+up_1`, `enemy_10` — so
`tools/export_waves.py` resolves them out of the source rather than anyone hand-copying 1,800 bytes.
It emits `waves.bin` and `anim_decode.bin`, and both live in **bank 0** (decision 28), which had the
room and which is the resting bank the wave manager already runs under. `wave_read` is
self-modifying code over it, exactly as `map_read` is over the map.

`anim_decode` is 19 start/end frame pairs — explosion, player ship, player bullet, then `enemy_1` to
`enemy_16`. `enemy_1` is 3, so a wave's object byte indexes it directly and the C64's `asl : tax`
doubles it into the pair.

## A movement command is four bit pairs

Up, down, left, right, tested low to high, applied **twice** per tick — so `left_1` is one pixel a
tick and `left_2` two. Vertical steps go two at a time because the C64's y is not halved the way its
x is. Each enemy carries two commands and its own timer: below its rocker value it uses the first, at
or above it the second, and the timer wraps at the reset value. That is the whole of the movement
model, and it is why the same six sprites can fly in formations, weave and reverse.

## Slots 2-7 are the pool

Which is the C64's arrangement, and the reason its code is full of `+$02,y` and `+$04,x`: Y walks the
one-byte-per-slot arrays and X the two-byte `sprite_pos`, both starting at slot 2. Our arrays have
the same shape, so those offsets are kept exactly as they are and the transcription stays literal.

A slot is free when its **y is zero** — which is what `enemy_bounds` leaves when an enemy flies off,
and what `explosion_chk` leaves when an explosion finishes. `wave_manager` searches for that, and if
it finds nothing it reads the wave past and throws it away, keeping only the delay to the next.
After a successful spawn it **loops back to itself**, because a wave whose delay is zero means
several enemies in one tick; the C64 calls that "a little messy" and it is, but it is the shape the
table is written against.

`enemy_bounds` runs from the **bullet's** slot up, as the original's does, so it is also what kills a
bullet that leaves the right-hand edge — `bullet_manage` in `player.asm` lost its own copy of that.

## The start-of-game fast winder

**The C64 pre-fills the screen and we have to as well.** `map_read_rst` ends in a loop its author
labels a "Scroll fast winder for the start of game": the whole buffer-swap cycle run 20 times, which
is 40 characters, which is the width of the screen.

Missing it caused both of the faults KC reported: a long blank start while the playfield filled, and
waves that did not line up with the level. The second is the serious one - the wave timings were
authored against a full screen, so with the map a screen behind, every wave spawned a screen ahead of
the scenery it was drawn to fly through, and enemies appeared over empty space rather than entering
from the right edge. `BUGS.md` #6.

`scroll_prewind` runs `scroll_frame` 160 times before the display is unblanked: 40 characters at 4
frames each, since a character is 4 pixels wide and we move a pixel a frame. It flips the shadow bank
itself, because the VSync handler that normally does that is not installed yet, so both banks come up
full and one pixel out of phase exactly as the running loop leaves them. About 0.7 s, inside the
blank the bank loads already sit in.

The per-frame scroll work was factored out of the main loop into `scroll_frame` to make this
possible; that is the only reason the routine exists.

## Two faults the winder uncovered

Both reported by KC after the winder went in, and both worth reading before touching either area.

**A stationary sprite rocked two pixels with the scroll** (`BUGS.md` #7). Factoring the scroll into
`scroll_frame` put the advance in the same routine as the plot, so sprites were placed from an
already-advanced `corner_addr` - correct on even frames, two pixels right on odd ones. Split into
`scroll_frame` and `scroll_advance`, with the loop back in its original order: plot, draw, advance.

**Sprites at x >= 140 were never drawn at all** (`BUGS.md` #8), a **Layer 3 defect** that only became
visible once waves spawned enemies at the right edge for real. The byte column was derived with
`CMP #&80 : ROR`, an arithmetic shift, but `x - SPR_X_OFF` runs -12 to 243 and does not fit a signed
byte - so anything at x of 140 up looked as though it were off the left edge. The 149 waves that
spawn at x = 172 were invisible for the first third of their flight. The sign now comes from the
subtraction's carry instead. It had been silently capping the player too, whose bound is x = 155.

## Collisions

- **Bullet to enemy** (`enemy_colls`): a box round the bullet, `x-8` to `x+9` and `y-16` to `y+18`,
  against every live enemy. A hit always costs the bullet. Shields decrement; at zero the enemy stops
  dead, runs the explosion animation and pays 400, otherwise it flashes and pays 40.
- **Player to enemy** (`player_s_colls`): a box round the ship, against the same pool, setting
  `coll_flag`. Layer 6 takes the life; `DEBUG_COLL` flashes the ship instead for now.
- Frames below `$0b` are the explosion, and an exploding enemy can neither be shot nor hit you.

## Where the state went

`&1D7` free below `CODE_TOP` was not enough for this layer, so **the whole game-state block moved to
`&0800`** (decision 27). The C64 keeps the same block in its tape buffer at `$0340` for the same
reason: it is RAM that needs no initial value, so it costs nothing to put it where the image is not.
`&0800-&0BFF` is the MOS's sound, serial and soft-key workspace, which is ours with the MOS
interrupt gone — verified in jsbeeb by a sentinel across all four pages surviving 1,500 fields of the
running game. It is declared after the `SAVE`s and outside them, so none of it is written to disc.

233 bytes of it are used, `&0800-&08E9`, and it is where Layer 6's lives and shield timer will go.

## Measured

One `game_tick` is **1,639 cycles**, so the two a frame cost 3,278 — the player, the bullet, six
enemies moving, both collision passes, the animation, the explosion sweep and the wave manager.

| | cycles |
|---|---|
| scroll column | 11,153 |
| sprite restore, 8 slots | 15,093 |
| sprite draw, 8 slots | 34,143 |
| game logic, 2 ticks | 3,278 |
| **total** | **63,667 of 79,872 — 80%** |

That is the worst case: the pool is often not full, and an empty slot costs the blitter nothing.

## Verified in jsbeeb

- Waves spawn on the table's own timings, fly their commands and are decommissioned at the edges;
  six slots live at once with valid frames and animation ranges out of `anim_decode`.
- Shooting an enemy scores 40 and flashes it; with shields down to 1 the next hit scores **400**
  (80 → 480 in the score, exactly) and starts the explosion.
- 1,500 fields with the pool running: no trails, no corruption, scenery and sprites clean.
- Bank 0 now ends at `&BC38` with `&3C8` free; the image at `&1F88` with `&78` free.
- Both banks come up full: the play area is scenery from the first displayed frame, and the first
  wave flies the corridor the table drew it for.

## Caught before it ran

`wave_manager` had a local label `.comp_flag` in the same `{}` scope as the `comp_flag` variable it
sets. beebasm resolves the local one, so `sta comp_flag` would have stored into code rather than the
flag — assembling cleanly and failing silently. The label is `.wm_comp` now. **A local label must not
share a name with a global it is used beside**; noted in `CLAUDE.md`.

## Left for later

- `coll_flag` and `comp_flag` are set and nothing reads them. Lives, the respawn shield timer, the
  life-lost explosion sequence and the completion sequence are Layer 6, along with the HUD that puts
  the score on the panel.
- The player explosion (`explosion_dirs`, the C64's `life_lost_init`) is Layer 6's too.
- **The image has `&78` free.** Layer 6 will not fit without moving something else out; the obvious
  candidates are the multiply tables, which cannot go to a bank because the sprite draw reads them
  with a sprite bank paged in, and the `coll_row` tables, which can.
- Still no buffer oracle.
