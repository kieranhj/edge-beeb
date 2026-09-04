# Layer 6c — the state machine

**Done 2026-09-03.** The game has a shape around it now: titles, a game, a life lost, game over or
completion, and back to the titles. Pause and abort go in with it, and `comp_flag` — set by the wave
manager since Layer 5 and read by nothing — finally ends the game.

Transcribed from the C64's `master_loop`, `main_init`, `main_dropin`, the pause block at the top of
`main_loop`, `main_abort`, `game_over_loop`, `comp_loop`, `comp_mess` and `cm_splode_wait`. Two
decisions, [32](decisions.md) and [33](decisions.md).

## One loop, not five

The C64 has a loop per state, each built on `sync_wait`. Ours cannot copy that: a frame here is
`spr_restore_all`, `scroll_frame`, `spr_draw_all` and the handover, and writing that out five times
would cost more than the layer.

So: **only the titles are a loop of their own**, because only they hold a still picture. Playing,
game over and both halves of the completion differ in what the *tick* does and not in what the
*frame* does, so they share the main loop and are told apart by `game_mode`:

| `game_mode` | the C64's | what the tick does |
|---|---|---|
| `MODE_PLAY` | `main_loop_2` | everything |
| `MODE_OVER` | `game_over_loop` | no `player_manage`; `coll_flag` counts &c8 down |
| `MODE_COMP` | `comp_loop` | no `player_manage`; the player flies off to the right |
| `MODE_FINALE` | `cm_splode_wait` | bangs and animation only — no pool, no waves, no scroll |

`game_mode` replaces Layer 6b's `player_live`, which was the same idea with one bit.

Two routines came out of the old inline loop so the still states can use them: **`frame_wait`** is
the handover, and **`field_wait`** waits a field *without* handing anything over. The distinction
matters — the flip only happens when `frame_ready` is set, so leaving it alone keeps the displayed
bank displayed. A paused screen is genuinely still, rather than the last two frames alternating at
25 Hz.

`anim_step` came out of `multimate` for the same reason: the finale wants the frame stepping and
none of the rest, and the C64 writes it out a second time there under the comment "a shortened
version of multimate".

## The titles

The zoom scroller is Layer 6e. What is here is the rest of the original's page, and it is the
original's: **the C64's own credits, in the C64's own font**, taken from `source_c64/data/status.chr`
and `ttl_credits`, exported by `tools/export_title.py`.

The fit is exact and worth recording, because it is why this was worth doing properly rather than
inventing a placeholder. `status.chr` is a **multicolour** character set — four double-width pixels
per character, not eight — and four double-width pixels is one of our 4-fat-pixel character cells.
So a character maps to a character, and the original's 38-column line lands in 152 of the play
area's 160 pixels with a byte column of margin either side. No rescaling anywhere.

- The glyph numbers are the original's `scroll_decode`: `$00` blank, `$01`-`$1a` A-Z, then `! . , - ?`
- The three ink bit-pairs become blue, cyan and white, which is the scenery's own palette
- A glyph is 16 bytes and our byte columns are 8 bytes apart and consecutive, so **plotting one is a
  straight 16-byte copy**
- The five lines sit on play rows 8, 10, 11, 12 and 13. The C64 uses rows 12, 14, 15, 16 and 17 of
  25; ours is a 20-row area, so the gaps are kept and the block re-centred

The page is a still picture, so it is drawn once into **both** banks and then nothing is handed
over. It is blanked while it draws, as the original blanks `$d011` across the same transition,
because the second of the two draws goes into the bank the display is showing.

**It lives in bank 3.** 702 bytes of font and text did not fit bank 0's 358, and bank 3 (the
compiled bodies) had 13.7K. That needs `title_text_call`, a trampoline in **main RAM**, because
nothing in a sideways bank can page its own bank out from under itself. Note the asymmetry that
makes bank 0 the easy place and bank 3 the awkward one: the sprite engine restores `SWRAM_DATA`
when it is done, so bank 0 code may call into main RAM and be returned to, and bank 3 code may not.

## Pause and abort

`P` pauses, `ESCAPE` from inside the pause gives up (decision 32). Both key numbers **measured**
with OSBYTE 121 in a BASIC session holding the key, as every other key in this port has been: P is
55, ESCAPE is 112. ESCAPE is an ordinary key here — the MOS interrupt is gone and the keyboard is
read straight off the VIA — but `*FX229,1` was needed to measure it, or BASIC ate it.

The C64's shape is kept exactly: the pause key is tested at the top of the loop, fire comes back
out and is debounced so its release does not fire the bullet, and the abort is `main_abort` — one
life left and then lose it, so the game-over sequence runs as it always does rather than being a
second way out. P is debounced on the way in too, which the original does not need because its
pause key is read differently.

**Two deviations, both KC's, added 2026-09-04 (decision 43).**

**P comes back out as well as fire.** The C64 has only its fire button here, having no second key
to spare; P is the one that got the player in, so it is the one they reach for. It needs its own
release debounce on the way out, or the main loop's test at the top of the very next frame finds it
still held and pauses again on the spot.

**The tune stops with the game.** The C64's does not — `jsr $2e03` sits in raster split 2 and runs
every frame whatever the foreground is doing, so the original plays on through `main_pause`. Ours
reuses Q's mechanism whole: `pause_check` sets `music_pause`, and the VSync handler takes its
**muted** path, running `sn_reset` INSTEAD OF `vgm_update`. The player is not stepped at all, so
the tune stands where it is and carries on from there. It has to be that way round rather than
"silence the chip after running the player", for the crackle reason in decision 39 and `BUGS.md`
 #11. The flag is cleared on both ways out — the ESCAPE abort included, which never returns to this
routine. **Q is not read while paused any more**, there being nothing left for it to mute.

Verified in jsbeeb against the SN76489's own registers: all four channels at attenuation 15 while
held, `char_col` frozen, and both keys resuming play. The proof that the tune is genuinely stopped
rather than playing on silently is that **a 120-field pause and a 60-field pause resume at exactly
the same note** — `char_col` 19, `tile_total` 17, channel 2 on tone 212 in both.

## Completion

`comp_flag` is checked where the C64 checks it, at the end of the tick, after the collision and
never before it. Then:

1. **The fly-off** (`comp_loop`): the player moves right a pixel a tick on his own. At `&c0` he
   stops — and waits there for `scroll_x` to come round to `&0c`, because the sequence has to begin
   on a particular scroll step.
2. **The bonus** (`comp_mess`): every sprite hidden, then 5,000 points a remaining life with the
   original's own 50-field pause between them. It **blocks** on `field_wait` exactly as the original
   blocks on `sync_wait`: nothing is moving and nothing is being drawn, so there is no frame to hand
   over.
3. **The finale** (`cm_splode_wait`): one of the eight slots becomes an explosion every four ticks,
   round-robin, at a scattered position, until fire returns to the titles. The background stands
   still — the original calls neither `scroll_manage` nor anything that plots, so the main loop
   skips `scroll_frame` and `scroll_advance` in this mode.

**The "mega hero" message is not built.** It is written as character codes into a text screen we do
not have; it waits for Layer 8 and a font drawn for the job. Everything else in the sequence is here.

### Where the bangs land (decision 33)

The C64 reads `$0900` and `$0a00` for the positions. Those are not tables: the game loads at `$0812`,
so what it is reading is **its own machine code**, used purely as a source of scattered numbers. Two
pages of ours do the same job.

That took two goes. The map was tried first, on the grounds that it was already in the resting bank
— and every bang landed at x = 0, because the level opens on empty tiles and a tile index of 0 is
what `map_data` holds there. The character set is worse: it is MODE 2 pixel patterns, and a page of
it holds four distinct values. Code is the right answer and it is also the original's answer.

## Memory

Main RAM is the constraint now: **`&99` free** below `&2000` in a DEV build (`&1F6B`), `&1F4E` under
`RELEASE`. Bank 0 has `&97`. Bank 3, which used to be almost empty, has `&324E`.

`pause_check`, `comp_mess` and `finale_tick` are all in **bank 0** because main RAM ran out mid-layer
— the build failed on the `GUARD` and they moved. They may live there: the main loop calls them with
`SWRAM_DATA` paged in, which is the resting state.

Anything Layer 6d or 6e needs will have to come out of a bank, or something else will have to move.

## Measured

jsbeeb, Master 128, DEV build.

- Boot lands on the credits page; fire starts a game; three deaths run the game-over count and drop
  back to the credits.
- P freezes everything: the state block was byte-for-byte identical across 200 fields, and the
  picture is genuinely still rather than flickering between two frames.
- ESCAPE from the pause: `lives` 0, `game_mode` 1, `coll_flag` counting down from `&c8`.
- Forcing `comp_flag`: `game_mode` 2, the player flies to `&c0` and holds, then the bonus scores
  exactly 015000 for three lives, then `game_mode` 3 with bangs scattered over a frozen level, then
  fire and the credits are back.

## What this layer does not do

- **The zoom scroller and the credits' movement** are 6e. The page is static.
- **The panel is still the colour-bar placeholder**, so the score and the bonus it just counted are
  invisible; 6d.
- **The "mega hero" message**, above.
