# Layer 9i — CTRL+A on the titles: auto-fire

2026-09-06. Decisions 73 and 74. Hold fire and the ship shoots on its own instead of needing a
press per shot — at a floored rate, so a player who taps is still faster. Off by default, toggled
with **CTRL+A on the titles**, and the page says which way it went for three seconds.

KC's ask: *"my friend stew is lazy. would it be feasible to implement an auto-fire option? say
CTRL-A ... the player only has to hold the fire key down, not press it repeatedly, to fire at the
maximum rate. default is OFF"*, then *"do it in titles then with some indicator"*, then — after a
standing label was built and seen — *"change that title screen line so it just says auto fire
on/off in the centre for a few seconds when toggled. it doesn't need to fade, it can just pop
on/off"*.

Then, once it was playable: *"the auto fire is great but makes the game a bit too easy. let's
reduce the rate of fire when auto fire is held (maybe half maximum?) but the player can still
repeatedly press the fire button to shoot faster manually"*, and — the diagnosis that named the
mechanism — *"i guess there just needs to be a minimum number of ticks if you're holding down fire.
this explains why the fire rate increases as you go closer to enemies"*. That is decision 74, below.

The C64 has nothing of the kind, so all of it is the port's own.

---

## What the player sees

The titles are the titles, unchanged, until CTRL+A. Then, for three seconds, in the gap the C64's
own credit spacing leaves:

```
 EDGE GRINDER            BY   COSINE SYSTEMS
                AUTO FIRE ON
 CODING                   JASON T.M.R KELK
 GRAPHICS               TREVOR SMILA STOREY
 MUSIC BY               SEAN ODIE CONNOLLY
 RELEASED BY           FORMAT WAR AND RGCD
```

It pops on, holds `TTL_AUTO_HOLD` = 150 fields, and pops off. No fade in or out — KC's call, and
it is what keeps the page as it was.

**It does not fade with the credits either**, which is a different thing and is the one part of
this layer that took any thought: three seconds of message would otherwise be spent invisible if
you happened to press CTRL+A while the crossfade was in its black. See below.

**The message does not say what key toggles it.** That was KC's call too — a standing
`CTRL A AUTO-FIRE ... OFF` line was built first and read as clutter. If it wants advertising, the
scrolltext (`assets/scrolltext.txt`) is the place and is KC's to write.

---

## `af_latch` is the shape of the latch, not a flag

`player_manage` is the C64's, transcribed, and its fire latch is what stops autorepeat:

```
.player_fire
ldy fire_latch
beq fire_bullet         ; latch clear: allowed to fire
lsr a
bcc fire_out
lda #0                  ; button seen released: arm the next shot
sta fire_latch
...
.fire_bullet
...
lda #1                  ; <- the whole of auto-fire is this instruction
sta fire_latch
```

The `#1` becomes `lda af_latch`, a byte holding **the value to write**. `af_latch` is in **zero
page**, so the replacement is the same two bytes and the same two cycles as the immediate, and the
original's LSR/BCS chain is untouched. What that byte holds is the whole design:

| | | |
|---|---|---|
| `AF_OFF` | `&80` | **negative**, and the C64's latch exactly: only seeing the button released clears it |
| `AF_ON` | 20 | **positive**, and a countdown the held path decrements once a game tick |

So auto-fire on is not "never latch" — it is "latch, but let it time out".

### Why it needed a floor (decision 74)

The first cut had `AF_ON` = 0: the latch never set, so a held button fired the moment the bullet
slot came free, and **that is not a constant rate**. Measured in jsbeeb: the bullet moves 12 a tick
and dies at `ENEMY_X_KILL` = `&d0`, so

- from the drop-in x = `&28`, the flight is **14 ticks** and a held button shot every **15**
- at the right-hand edge, x = `&9b`, every **6**
- and **a bullet that hits something dies where it hit**, so point blank it was faster still

which is exactly what KC noticed from playing it — *"the fire rate increases as you go closer to
enemies"* — and why the game got easy. A rate multiplier would not have fixed it; a **minimum
interval** does, and it is what KC asked for.

`AF_ON` = 20 ticks is 0.4 s, a tick being 1/50 s with `game_tick` running twice per 25 Hz frame:
**2.5 shots a second held**, against 3.3 for a tap at normal range and up to 8 point blank. 30 was
tried first and KC's word for it was *"a bit long"*.

**The useful range is 17 to about 30, and an `ASSERT` says why**: 16 ticks is the longest flight
there is, from `PLY_X_MIN`, so anything below 17 binds nowhere. It is one constant in `main.asm`
and it is the number to turn if the feel is wrong.

### And a tap is not slowed at all

The release path clears the latch **outright**, countdown and all, so the next press fires as early
as the bullet slot allows. Measured: with a bullet already gone, a press after a release reaches
`fire_bullet` inside the same field. That is the trade — the convenience costs you half the rate,
and mashing the button is still worth the effort.

The whole of the new behaviour is three instructions on the held branch:

```
.af_held
lda fire_latch
bmi fire_out            ; AF_OFF: the C64's latch, and nothing ticks
dec fire_latch          ; AF_ON: one tick off auto-fire's floor
```

Zero page is wiped once at boot and never again, so `key_init` setting `af_latch` to `AF_OFF` is
the whole of the default and the choice then survives a game, the finale and the return to the
titles for nothing. That is `joy_keys`' trick from Layer 9h, for the same reason.

`sprite_reset` clears `fire_latch` to 0 on each new life, as it always did; that is correct
whichever value `af_latch` holds.

**`fire_latch` moved to zero page with it** (decision 74), out of the `&0800` block that is
otherwise the C64's `$0340`. Six references in `player_manage`, a byte each, which is most of what
the held path cost.

---

## Where the key test went, and why not where it should have

`ttl_frame_titles` in bank 1 already tests CTRL once a field, for CTRL+R. Hanging CTRL+A off that
test would have made it free, and that is where it was written first. **Bank 1's tail is nine bytes
short of it in a VGI build**, and the hole below the tune stream is no better.

The other candidates were worse: main RAM below `SPR_SAVE` has **14 bytes** in a `-Akl` build and
bank 0 has **nine**. So the test is `ttl_auto_key` in **bank 2**, called from `ttl_cred_step`,
which runs once a field on the titles anyway. Bank 2 is the titles' bank already (decision 53: the
credit crossfade and `fade_pal` are up there because nothing on the titles reads a sprite), and the
price is one extra `keydown` a field — about 69 cycles, on a page whose whole job is to wait for a
key.

**It is split across that bank's two halves**: the key test and the toggle in the tail, the
message's countdown in the hole below the tune stream, because the tail is four bytes short of
both. The two halves are one bank, so the `jsr` costs nothing.

A sideways bank may call main RAM as long as it pages nothing, and `keydown` pages nothing; bank
1's redefine screen calls it the same way. `af_latch`, `auto_was` and `ttl_auto_tmr` are all zero
page and `ttl_redraw` is the `&0800` block, all readable and writable from a bank.

The detector is edge-triggered **on the press and on the combination** — letting go of either key
arms the next press — which is `rupt_vsync`'s CTRL+Q detector exactly, and for the same reason:
holding the two down would otherwise toggle fifty times a second. Confirmed in jsbeeb by holding
CTRL+A for 120 fields: one toggle.

### Three bytes of zero page, and why they are not in the `&0800` block

`auto_was` and `ttl_auto_tmr` look exactly like `mute_was` and belong beside it. They are in zero
page because **bank 2's tail is the tightest ground in the build** — 43 bytes in a DEV `-Nula` one,
and `ttl_auto_key` wanted 45 of them. Every `sta`, `eor` and `dec` being a byte shorter is what made
it fit. Zero page had 66 going spare. Both are wiped to 0 at boot, which is the right start for
each: no key held, no message on the clock.

---

## The message, and why it does not fade with the credits

**Credit row 1 is empty.** `title_rows`' credit list is the C64's own spacing — rows 0, 2, 3, 4, 5,
with a gap — so the plotter never writes row 1 and the message displaces no credit. (The redefine
screen uses all six rows, which is why `kr_blank` exists; see below.)

**The crossfade touches logicals 8-15 only** (`fade_low = TTL_C_LOW` in `src/bank2.asm`), and the
title font is painted in **12, 14 and 15** — which `setup_display` maps to the same RGB as 4, 6
and 7 (decision 53). So drawing the message in **4, 6 and 7** gives a line that is the identical
colour on screen and is outside the range the fade walks. It stays at full brightness for its three
seconds wherever the crossfade happens to be.

That is one instruction in the plotter's inner copy loop:

```
.copy
lda (spr_tmp), y
and ttl_and             ; &FF for everything but this one line
sta (write_ptr), y
```

`TTL_AUTO_MASK = &3F` clears bits 7 and 6, which are a logical colour's bit 3 for the left and the
right fat pixel. **Proved against `tools/bbc.py`'s own `mode2_byte`, not recalled**: 12, 14 and 15
pack to `&A0`, `&A8`, `&AA` on the left and `&50`, `&54`, `&55` on the right, and 4, 6 and 7 to
`&20`, `&28`, `&2A` and `&10`, `&14`, `&15`. Logical 0, the background, stays 0.

**In a NuLA build the mask is `&FF`.** There all sixteen palette entries are real colours of the
source palette, 12/14/15 are not aliases of 4/6/7, and the crossfade does not run at all (decision
63) — no fade to dodge, and dodging it would recolour the message.

### Three lines, and the blank is one of them

`src/data/title_auto.bin` is **blank, OFF, ON**, three whole 38-glyph lines from
`tools/export_title.py`, each centred by the exporter. The plotter draws a fixed 38 glyphs from one
pointer and nothing else, so three lines makes both the draw **and the erase** a pointer choice
rather than a special case. `ttl_auto_tmr` is what picks: 0 means the blank.

### Nothing in main RAM changed

`title_text` is now `title_body` followed by `title_auto`, both in bank 3. Every existing repaint
of the block therefore redraws row 1, and the callers — `title_page` in bank 0, `ttl_cred_tick` in
main RAM, `kr_draw` in bank 1 — are untouched. Bank 2 asks for a repaint by setting `ttl_redraw`,
which is the signal the crossfade already had: once when CTRL+A is pressed, and once more on the
tick that takes the timer to 0.

`title_auto` refuses to draw when `ttl_rows_ofs` is not 0: that is the redefine screen, which owns
row 1 for LEFT. `kr_cred_back` paints all six rows blank on the way out and comes back through
`ttl_cred_init`, which clears `ttl_auto_tmr` — so a message that was still on the clock when the
player pressed CTRL+R, or pressed fire and played a game, is not still on it when the titles come
back.

---

## What it cost, and the one build that does without it

| Region | Before | After | Note |
|---|---|---|---|
| Main RAM under `SPR_SAVE` | 14 (`-Akl`) | **9** | decision 73 cost nothing; decision 74's held path cost 11 and `fire_latch` in zero page gave 6 back |
| Zero page | 66 free | 62 free | `af_latch`, `auto_was`, `ttl_auto_tmr`, and `fire_latch` moved in |
| `&0800` block | 418 | 419 | `fire_latch` moved out |
| Bank 0 | 19 (`-Akl`) | **19** | nothing |
| Bank 1 | — | — | nothing |
| Bank 2 tail | 56 / 43 (`-Nula`) | **16 / 3** | `ttl_auto_key`, 42 bytes. **3 bytes left in a DEV VGI `-Nula` build — the tightest region in the machine now** |
| Bank 2 hole | 220 | 202 | the message's countdown, 18 bytes |
| Bank 3 | 237 (VGI), 29 (VGI `-Cpc`) | 21 / — | 174 bytes: 114 data, 60 code |

**VGI + `-Cpc` cannot have the message.** Bank 3's tail there is region A of the tune (decision
48), the Amstrad's compiled sprite bodies are bigger than the C64's, and the whole VGI music layout
has **32 bytes of slack in it** — measured across all four regions, there is nothing to reclaim
anywhere. VGI is retired from the configuration set (KC, 2026-09-06), so rather than hold the
feature back for it, `TTL_AUTO_SHOW` in `src/main.asm` builds the message wherever bank 3 has the
room. **The toggle itself is in every build**: `af_latch` and `player.asm` never see that switch.

**The `-Akl` builds needed the tunes moved up a page**, from `&9100`/`&A400` to `&9200`/`&A500`.
Bank 3's code and data ends at `&9190` in an `-Akl -Cpc` build, and there are 6,217 bytes above the
two tunes, so the page came from there. AKL data is absolute, so `tools/export_music_akl.py`
carries the same two numbers and re-exported both tunes at the new addresses; its `--check` passes.

---

## Verified

jsbeeb, Master 128, 2026-09-06, `-Akl` and `-Akl -Cpc`:

- the titles come up with credit row 1 blank, exactly as they did before this layer
- CTRL+A puts `AUTO FIRE ON` up centred within a field, at full brightness while the credit lines
  above and below it are mid-fade; it is gone again after 150 fields, and row 1 is blank
- pressing it again gives `AUTO FIRE OFF` the same way; holding both keys 120 fields does not
  toggle a second time
- `af_latch` (`&31`) reads 0 with it on and 1 with it off; `ttl_auto_tmr` (`&33`) counts down and
  stops at 0; `joy_keys` at `&2C-&30` is 70, 101, 97, 66, 86 as expected
- with auto-fire on and the button **held**, a breakpoint on `fire_bullet` fires every **19, 22 and
  20 fields** — the 20-tick floor, against 13-14 before decision 74 at the same position
- **releasing and pressing again reaches `fire_bullet` inside the same field**, so a tap is not
  slowed at all
- with auto-fire off, `af_latch` is `AF_OFF` and a held button never fires twice, which is the
  C64's behaviour exactly
- CTRL+R still gives a clean redefine screen with LEFT on row 1 and no message over it; ESCAPE
  brings the credits back with row 1 blank even though a message was on the clock when it was
  pressed

All ten flag combinations assemble.
