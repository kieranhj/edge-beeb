# Layer 4 — the player (2026-09-03)

Movement and bounds, the fire latch, the bullet, both background collision checks, grind scoring
and the six-digit score. `src/player.asm` is a transcription of the C64's `player_manage`,
`player_colls`, `bullet_colls`, `player_grinds`, the bullet's share of `enemy_manage`, and
`multimate`'s animation tail.

## The two structural decisions

### 1. The game logic ticks twice per display frame (decision 23)

The C64's `main_loop` waits on `sync_wait`, which the second raster split sets once a field: it runs
at **50 Hz**. Ours runs at 25 (`FRAME_LOCK` = 2). One pass of our loop is therefore two of the
original's iterations, and `game_tick` is called twice.

The alternative was to double every per-frame constant — y by 4 instead of 2, x by 2 instead of 1,
the bullet by 24 instead of 12. Ticking twice is better on three counts: the original's numbers
transcribe **unaltered**, so the source stays a transcription and not a conversion; the bullet is
collision-checked at each 12-pixel step, which is what makes the original's three-cell check
airtight; and the sampling of the scenery happens at the same rate the original samples it.

It cost about 1,600 cycles a frame, which the budget had.

**The scroll already agreed with this.** The C64 advances `scroll_x` 0-15 over two characters, so it
moves half a multicolour pixel a field — 25 px/s. Ours moves one pixel per 25 Hz frame, the same
25 px/s. `scroll_x` is kept as its own 16-step counter, ticked with the logic, purely so the
`scroll_x AND 3 = 3` gate on grind scoring fires at the original's rate.

### 2. The background collision reads a character map we keep ourselves (decision 24)

The C64 is a character-mode game: `coll_read` reads a character code straight out of the screen it
is displaying and puts it through `col_decode`, whose **top nibble is the fatal flag** and whose low
three bits are the colour the tile exporter already uses. We draw pixels, so there is no character
code on screen to read.

So `scroll.asm` keeps one. Every `plot_char_y` already has the code in `Y` — twenty calls a frame,
top to bottom, one per character row — so filing it costs a store and a pointer bump. The map is
**40 columns × 20 rows = 800 bytes**, the same grid the C64's screen has, with the columns as a ring
that `coll_advance` moves on as each character finishes arriving. All four frames of a character
write the same codes to the same slot, which is idempotent, so no test is needed.

`col_decode` itself is untouched in bank 0 and the fatal nibble is read exactly as the original
reads it. Only the array is ours.

**Where it lives: `&04A0`, main RAM** (KC's call). That is the language workspace — BASIC's, and
ours the moment `*RUN` hands over. It was the one option that needed proving, so it was proved:
a sentinel written across the whole of `&04A0-&07FF` survived **3,000 fields** of the running game
byte for byte. The only thing that writes there is the MOS's command-line buffer, which holds the
text of `!BOOT` and is finished with before we take the machine. `&0700` still had that text in it
at boot, which is what the residue is.

The map is 800 bytes and the region is 864, and the slack is deliberate — see the guards below.

## Transcribed unchanged

- **Bounds** `x $10-$9b`, `y $5a-$e5`, and the `LSR`/`BCS` chain that tests them. `joy` is built by
  `read_joystick` with the C64's `$dc00` bit order **and its polarity — a clear bit is pressed** —
  so `player_manage` is the original's code, not a rewrite of it.
- **The fire latch**: set when a bullet goes out, cleared only when the button is seen released, so
  fire does not autorepeat.
- **The bullet**: 12 pixels a tick, `enemy_spds+2`, killed by `enemy_bounds` at `x >= $d0` or
  `y < $40`. It samples three cells side by side, which is 12 pixels — exactly one tick of travel,
  so nothing is tunnelled through and the CPC's split check is not needed.
- **The player's three cells**: the character row the sprite starts in, two below it, and the one
  between. The outer two are the grind, the middle one is fatal. The two-pixel bias in the
  original's `$30` and `$28` offsets is kept, because it is what makes the three rows straddle the
  sprite; our offsets add `PANEL_ROWS * 8` because the play area starts five character rows down.
- **Grind scoring**: 25 points and a four-tick flash per touching edge, gated on
  `scroll_x AND 3 = 3`.
- **The score**: six decimal digits one to a byte, `bump_score_*`, and the high-score compare and
  copy. Layer 6 puts them on the panel.
- **`multimate`**: every fourth tick, step each slot between its `anim_starts` and `anim_ends`; then
  count the hit-flash timers down. The debug sprite harness lost its own copies of both.

## Deviations

- **`bullet_colls` gets two guards the original has not** (decision 25). With no bullet its `y` is 0
  and the C64 indexes 27 rows into a 24-row table; past column 39 it reads into the next row down.
  Both are off-screen nonsense on the C64 and an out-of-range read here, so both return "no
  collision". The 64 bytes of slack past the map absorb the same overrun on the row tables.
- **Fire is RETURN.** Internal key number 73 — **measured** with OSBYTE 121 in a BASIC session
  holding the key, not recalled, after 73 was first written off on a bad test (see below).
- Player-to-enemy collisions (`player_s_colls`) are stubbed: the pool does not move until Layer 5.
  `coll_flag` is set and counted but nothing consumes it; Layer 6 takes the life.

## Verified in jsbeeb

- Player starts at the C64's `spr_defaults` `$28,$a0`, animates `$0b-$11`, and stands still with no
  keys down — so `keydown` is not reporting phantom presses.
- RETURN fires; the bullet spawns at the ship and is at `x + 24` one frame later, which is two ticks
  of 12. Holding RETURN does not re-fire.
- Ship poked to `(100, 229)`, in the floor: `coll_flag` counts up, **both** `coll_grind` cells read
  `$10` (fatal nibble set), `sprite_pls_tmr` runs, and the score reaches 100 — four grinds at 25.
  The high score tracks it.
- The map itself reads back as sensible character codes in a 40-byte row stride.
- Release build assembles with every `DEBUG_` flag off.

## Bug found by KC in b-em: the scroll broke outright

`coll_advance` counted in **X**. The scroll's tail keeps `char_col + 1` in X from the increment at
the top through the `AND 3` and `AND 1` tests down to the `corner_addr` update, and
`tile_cnt_bump` — sitting right beside the new call — counts in Y for exactly that reason. Clobbering
X put `crtc_addr` and `corner_addr` on the wrong frames and the picture came apart. `coll_advance`
counts in Y now, with a comment saying why. `BUGS.md` #5.

The same fault was behind a magenta vertical smear in a jsbeeb screenshot that I had started to
chase as a sprite-engine fault; it was the column copy landing in the wrong place, and one fix
closed both.

## Memory

Code `&0E00-&1BB0`, tables to `&1E29`, **`&1D7` free** below `CODE_TOP`. That is getting tight, and
Layers 5 and 6 are the two that add the most code; the collision map going to `&04A0` rather than
into the image is what bought the room there still is.

`&04A0-&07BF` collision map, `&07C0-&07FF` its overrun slack. Banks unchanged.

## Left for later

- `player_s_colls`, the wave manager and the enemy pool — Layer 5.
- `coll_flag` consuming a life, the shield timer on respawn, and the score on the panel — Layer 6.
- Still no buffer oracle (carried from Layer 3), and it would now also be the way to check the
  collision map against what is actually drawn rather than against a poked position.
