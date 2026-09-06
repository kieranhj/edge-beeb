# Layer 9h — CTRL+R on the titles: redefine the five keys

2026-09-06. Decisions 71 and 72. The titles page takes CTRL+R and replaces the credits with a
heading and five lines of key bindings; the five play controls are `joy_keys` in zero page,
defaulted from the `KEY_*` constants at boot and written here.

**Pause and mute became CTRL+P and CTRL+Q with it** (decision 72), which is what makes P and Q
bindable — and the three CTRL+letter keys are now the whole of the game's non-play keyboard.

The C64 reads a joystick and has nothing of the kind, so all of it is the port's own. **The
Paradroid port built it first** — `Paradroid/src/keyredef.asm`, its 11f decision 15 — and the
refusals, the wait-for-a-clear-keyboard and the message hold are that file's, with its reasons.
What is different here is the screen it draws on, the naming scheme, and where it all had to go.

---

## What the player sees

On the titles, with the zoom scroller running and the tune playing:

```
              REDEFINE KEYS
 LEFT                       PRESS A KEY
 RIGHT                                X
 UP                                   K
 DOWN                                 M
 FIRE                                 L
```

Press a key and it is taken, the line shows it, and the prompt moves down one. A key already taken
this run gives `ALREADY USED`; ESCAPE puts all five back. Either ending — finished or cancelled —
shows all five bindings with no prompt on any line, holds for 40 fields, and goes back to the
credits, which resume crossfading from the C64 set.

**The prompt is on the line it concerns**, unlike Paradroid's, which has a message row of its own.
The eye is on that line anyway, and it is what let the block stay one line shorter than a separate
message row would have made it.

---

## The screen is a third credit set

`title_text` (`src/bank3.asm`) draws **lines of 38 glyph numbers** into the credits block, reading
them through `ttl_cred_ptr` — which Layer 9e already made a variable so the crossfade could point
it at a second set at `&3C80` (decision 53).

Point it at a block composed in main RAM and the redefine screen costs:

* no new plotter, no new font path, no new palette work, no sixth T1 fire;
* **not a byte of bank 3**, which has 43 free in a `-Cpc` build and is the tightest bank we have;
* no change to the rupture's shape, so the page **cannot pick up another switch flicker**
  (`BUGS.md` #14) — that is the cost of moving between the two-cycle and four-cycle ruptures, and
  this moves between neither.

Everything below follows from staying at 38 columns and reusing that one plotter.

**The block is SIX lines** (decision 72): a `REDEFINE KEYS` heading on credit row 0 and the five
controls together on rows 1–5, where the credits keep the C64's own spacing with a gap at row 1.
`title_rows` in bank 3 holds **both row lists end to end** — `0,2,3,4,5` then `0,1,2,3,4,5` —
and `ttl_rows_ofs` in main RAM picks one while `ttl_lines` says how many. That is **fourteen bytes
of bank 3**, the bank with 43 free in a `-Cpc` build. The alternative was to give the credits a
blank second line so one list served both, and that costs 38 bytes of bank 3 *and* 38 at `&3C80`
for the second credit set: nearly six times as much, in the two tightest places.

A line is built as three fixed-width copies — 38 blanks, an 8-glyph label at column 1, and a value
at column 26, eight glyphs for a key name and twelve for a message — so there is no length
arithmetic and there are no terminators anywhere in the layer.

---

## The thirty-five bindable keys, and every number measured

The credits font is thirty-two glyphs — blank, A–Z, then `! . , - ?` — with **no digits**. A key
the screen cannot name cannot be offered, which is Paradroid's rule too; the difference is that its
briefing font is full ASCII and ours is not.

So: **the 26 letters, the four cursor keys, SHIFT, RETURN, SPACE, `/` and `:`** — thirty-five. A
letter needs no name at all — its glyph *is* its index in `kr_keys` plus one — and only the other
nine cost a word, which is what keeps the whole naming scheme to seventy-two bytes. A letters-only
version was cheaper still and would have refused the cursor keys and SHIFT, which on this machine
is most of what a player reaches for after Z/X; the nine extras buy `Z X : /`, the cursor keys and
SPACE for about ninety bytes.

**SPACE is one of them** (KC asked, and it had looked impossible because SPACE starts a game from
the titles). The two never meet: while the screen is up it owns the keyboard and `title_page`'s
`key_start` is not running, and `kr_wait_up` will not let the screen exit until SPACE is up again,
so a game cannot start on the way out either. Checked both ways on the machine.

**The candidate table is also the scan.** Paradroid tests all 112 matrix keys and then asks a
112-byte table what came back; a table of the *candidates* in naming order is both. Thirty-five
`keydown` calls is **~2,700 cycles a field** against its ~6,200, on a page whose foreground does
one `ttl_frame` and nothing else, and the 112-byte lookup disappears.

### The measurement

jsbeeb, Master 128, 2026-09-06. `A%=121:X%=16:Y%=0` — OSBYTE 121 scanning **from key 16** — polled
in a BASIC loop with each key held down through the emulator, printing the internal number on every
change. The scan form was proved before it was trusted: with Z held it returns 97, which is what
`IKN_z` in `src/main.asm` has said since 2026-09-04.

| | | | | | | | | | |
|---|---|---|---|---|---|---|---|---|---|
| A 65 | B 100 | C 82 | D 50 | E 34 | F 67 | G 83 | H 84 | I 37 | J 69 |
| K 70 | L 86 | M 101 | N 85 | O 54 | P 55 | Q 16 | R 51 | S 81 | T 35 |
| U 53 | V 99 | W 33 | X 66 | Y 68 | Z 97 | UP 57 | DOWN 41 | LEFT 25 | RIGHT 121 |
| SHIFT 0 | RETURN 73 | SPACE 98 | `/` 104 | `:` 72 | ESCAPE 112 | CTRL 1 | | | |

**Eight of them cross-check exactly** against numbers this repo already carried from 2026-09-04 —
Z 97, X 66, K 70, M 101, L 86, P 55, Q 16 and ESCAPE 112 — which is what says the method was right
rather than merely repeatable. Paradroid's `bmKeyChar` agrees with all of them; it is the
cross-check, not the source.

**SHIFT and CTRL are below the scan's floor and had to be measured another way.** The MOS scan will
not report keys 0–2 — Paradroid's file says the same, and OSBYTE `&7A` starts at 16 for the same
reason — so `A%=121:X%=0` with SHIFT held returns nothing at all. They were measured through INKEY
instead and calibrated on a known key: SHIFT is INKEY −1, CTRL is INKEY −2, Z is INKEY −98, and
Z's internal number is 97, so **internal = the INKEY index less one**, giving SHIFT 0 and CTRL 1.

### Nothing is refused

Decision 71 refused P and Q, because a control bound to either would have paused or muted the game
every time it was used. **Decision 72 made pause CTRL+P and mute CTRL+Q, and the reason went** —
CTRL is never held in play — so both are bindable and the `RESERVED` message was deleted. Its
sixteen bytes are exactly what the `REDEFINE KEYS` heading is stored in, so the text block did not
grow by a byte.

The only keys still out of reach are the two that are not candidates and never were: **ESCAPE**,
which is this screen's own cancel, and **CTRL**, which is never scanned because it is the trigger.

If pause ever goes back to plain P, the reservation has to come back with it — the machinery is
gone, not merely disabled.

---

## `joy_keys` is in zero page, and that is the load-bearing choice

It was an `EQUB` table in `src/keyboard.asm`, and `KEY_FIRE` was *also* four immediate operands:
`finale_tick` and the two `pause_check` sites in bank 0, and `key_start` in main RAM. Five bytes of
zero page instead:

1. `read_joystick`'s `ldx joy_keys, y` becomes **zero-page,Y — a legal 6502 mode for LDX** — so it
   is one byte shorter and a cycle cheaper than the absolute,Y it was. The layer makes the play
   loop very slightly *faster*.
2. `ldx #KEY_FIRE` becomes `ldx joy_keys + JOY_FIRE`, which in zero page is **also two bytes**. So
   the four sites cost nothing and **bank 0 does not grow** — it has nine bytes, and `BUGS.md` #14
   already wants some of them.
3. Zero page is wiped at boot and never again, so a redefinition survives a game, the finale and
   the return to the titles for free.

`ASSERT joy_keys + JOY_COUNT <= &100` holds the line, because the failure it prevents is silent: if
one of those `ldx` ever sized as absolute, bank 0 would overflow by a byte a site in a build that
still looked right in main RAM.

`key_init` fills it after the ZP wipe, from `joy_defaults` beside `joy_mask`. A wiped `joy_keys` is
not merely wrong — key 0 is SHIFT — it is five controls bound to one key.

**Not saved to disc.** The disc may be write-protected, the loader is a boot-time thing, and
Paradroid does not either. A redefinition lasts until the machine is reset.

---

## Pause and mute are CTRL+P and CTRL+Q

Three CTRL+letter keys now — CTRL+P pause, CTRL+Q mute, CTRL+R redefine — and the point of it is
not symmetry, it is that **P and Q became bindable**. Decision 71 refused them because a control
bound to either would have paused or muted the game every time it was used; CTRL is never held in
play, so the reason went.

**The CTRL test goes first, and that is what makes it free.** `pause_check` runs once a game frame
and the VSync handler's mute test once a field; CTRL is up in all but a handful of them, so the
common path is one `keydown` — exactly what the single P or Q test cost — and only the frame
someone is actually pausing pays for two. `keydown` returns A = 0 when the key is up, which is
already the "not pressed" the mute's edge detector wants, so the CTRL branch needs no `lda #0`.

The mute's edge is now on the **combination**: letting go of either key arms the next press.

`key_pause` is **in main RAM, not in bank 0 beside `pause_check`**, and that way round is cheaper
for both. Bank 0 has four sites — the entry test, the release wait, the come-back-out test and its
release wait — and each drops from `ldx #KEY_PAUSE : jsr keydown` to `jsr key_pause`, so bank 0
*gains* eight bytes while main RAM pays thirteen.

---

## Where it all went, and what the spec got wrong

The spec estimated ~330 bytes of code and said "the ~330 is the number to distrust". It was right:
the code came in at **488**, which is 69 more than bank 1's hole has.

Three things moved, in this order:

* **The three tables (44 bytes) went to `&3C80`**, in `src/panel.asm`, beside the text they index.
  They would rather be next to the code, and they are assembled rather than generated because a
  measured internal key number is a hardware fact and belongs where a person reads it.
* **Two leaf routines (57 bytes) went to bank 1's tail**, past the tune stream at `MUSIC_B1_BASE`.
  The two halves of that bank are one bank — only the stream is between them — so a `jsr` from the
  hole reaches them with nothing paged.
* **Four repeated call pairs were folded into routines** (`kr_show`, `kr_draw`, `kr_hold_msg`), the
  duplicated column arithmetic in `kr_build` computed once, and `kr_wait_up`'s CTRL test dropped —
  CTRL is not a candidate, holding it changes nothing, and `key_start` is not reached while the
  screen is up anyway.

### And the trigger moved, which was the sharper lesson

It was written into `key_start`, in main RAM below `SPR_SAVE`, which had 45 bytes. Twenty-four of
them **broke `ASSERT code_end <= SPR_SAVE` in all four DEV `-Akl` builds** — where the Arkos
player's own zero page and code leave the least of it, and where the margin was 7 bytes before this
layer started. The four C64-artwork builds assembled cleanly and said nothing.

It is now `ttl_frame_titles` in bank 1. `title_page` was already `bank_call`ing into that bank once
a field for `ttl_frame`, so the test rides on a call that was already being made: main RAM pays
nothing, bank 0 pays nothing, and `kr_run` is a plain `jsr` from there because they are in the same
bank. `ttl_frame` keeps its own entry, which is the whole reason there are two — the redefine
screen's own field loop calls it, and a test inside it would have had the screen re-enter itself
once a field.

It also runs **before** `key_start` does, which is what stops a fire bound to R from starting a
game on the way in: by the time `key_start` is reached the screen has been and gone and
`kr_wait_up` has left the keyboard clear.

### `bank_call` grew a restore byte

The one main-RAM change left. `bank_call` restored `SWRAM_DATA` unconditionally, which would
orphan a bank-1 caller; it now restores `bank_restore`, five bytes of main RAM, and with it bank 1
can have its block painted out of bank 3 and come back.

The rule in `CLAUDE.md` — "nothing in a sideways bank but bank 0 may call main RAM" — is wider than
the truth, and the truth is what makes this layer fit:

> A sideways bank may `jsr` main-RAM code freely; `field_wait` and `keydown` touch no bank and are
> called from bank 1 all day. What it may not do is call main-RAM code that pages a **different**
> bank in and then restores somebody else's.

`bank_call` is now nested — `title_page`'s outer call into bank 1, `kr_run`'s inner call into bank
3 — and that is safe because the inner call only clobbers `bank_call_t`, which the outer no longer
needs, and leaves `bank_restore` back at `SWRAM_DATA`. It is still not re-entrant in the sense that
matters (nothing calls it from an interrupt) and that assumption is now load-bearing.

### The figures

DEV builds, from the listings, C64 artwork then `-Cpc` where they differ. **Before** is the state
before Layer 9h began:

| where | before | after | notes |
|---|---|---|---|
| bank 1's hole below `&B900` | 475 / 469 | **23 / 17** | the screen itself |
| bank 1's tail | 86 | **16** | four leaf routines that would not fit in the hole |
| `&3C80` (`SCROLLTEXT HEADROOM`) | 237 | **32** | 160 of text, 45 of tables |
| bank 2's tail | 106 | **56** | `ttl_cred_init`, moved out of main RAM |
| bank 3 below the tune | 251 / 43 | **237 / 29** | the two row lists and the code that picks one |
| the `&0800` game-state block | 623 | **378** | the 228-byte block and its state |
| zero page | 90 / 73 `-Akl` | **85 / 68** | `joy_keys` |
| **main RAM below `SPR_SAVE`** | **45 / 7 `-Akl`** | **52 / 14** | *better than it started* |
| **bank 0** | **21 / 11 `-Akl`** | **29 / 19** | *better than it started* |

The last two rows are the point. The layer twice ran out of the ground it was standing on, and both
times the fix was to move something that had no business being there in the first place —
`ttl_cred_start`'s body out of main RAM into bank 2's tail, `key_pause` into main RAM rather than
beside its callers. **The two tightest regions in the build ended with more room than they had
before any of this was written.**

---|---|---|---|
| bank 1's hole below `&B900` | 475 / 469 | **44 / 38** | 431 |
| bank 1's tail | 86 | **29** | 57 |
| `&3C80` (`SCROLLTEXT HEADROOM`) | 237 | **41** | 196 — 152 of text, 44 of tables |
| main RAM below `SPR_SAVE` | 45 (7 in a DEV `-Akl` build) | **41 / 3** | 4 |
| the `&0800` game-state block | 623 | **433** | 190, the block itself |
| zero page | 90 (73 `-Akl`) | **85 / 68** | 5 |
| bank 0 | 9 | **9** | 0 |
| bank 3 | 251 / 43 | **251 / 43** | 0 |

**Three bytes under `SPR_SAVE` in a DEV `-Akl` build is the tightest thing this layer leaves
behind**, and the next person to want main RAM should know it was 7 before. A RELEASE build has 32
there; the frame meter is the difference.

---

## What was checked

jsbeeb, Master 128, `build/EDGE-200K.SSD`, 2026-09-06. The first run is decision 71's; the second,
after the layout, CTRL+P, CTRL+Q and SPACE went in, is decision 72's and repeats the ones that
could have broken.

### Decision 71

1. **The key numbers were measured before the table was written**, and the scan form proved against
   Z = 97 first. Table and method above.
2. **The screen comes up on CTRL+R**, the panel unchanged and both zoom bands still moving —
   successive screenshots show the bands in different positions.
3. **`joy_keys` at `&2C` reads `70 101 97 66 86`** at the titles — K, M, Z, X, L in UP DOWN LEFT
   RIGHT FIRE order, which is `key_init` having run over the wiped zero page.
4. **All five bind, including both awkward paths.** LEFT←A (a letter), RIGHT←the RIGHT cursor key
   (a *named* key, drawn as the word `RIGHT`), UP←SHIFT (**internal key number 0**, the one the
   OSBYTE scan cannot see), DOWN←the DOWN cursor key, FIRE←RETURN. `joy_keys` = `0 41 65 121 73`.
5. **The game obeys them, read out of memory rather than looked at.** RETURN started a game;
   holding A took `sprite_pos` x from 40 to 16; holding SHIFT took y from 160 to 100; **holding Z
   moved nothing at all**, which is the half of the test that says the old binding is gone rather
   than merely joined.
6. **`ALREADY USED`** on a duplicate, and `joy_keys` unchanged by it.
7. **ESCAPE restores.** LEFT rebound to B (`0 41 100 121 73`), ESCAPE, back to `0 41 65 121 73`.
8. **It survives a game.** A game played and aborted; the titles came back with `joy_keys` intact
   and CTRL+R drew the screen again. This is what proves nothing the layer owns is inside
   `SPR_SAVE` — `BUGS.md` #13 is what happens when that goes unchecked.
9. **The credits come back and the crossfade resumes**, from the C64 set, raster pulsing again.
10. **The tune never stops** — `read_sound_state` shows CH2 changing volume between reads.
11. **The `-Cpc` build** assembled *and booted*, screen up over the Amstrad's four-row panel.

### Decision 72

12. **The credits are untouched by the row-list change** — five lines, the C64's gap at row 1,
    screenshotted before CTRL+R was pressed.
13. **The heading and the layout**: `REDEFINE KEYS` centred on row 0, the five controls together on
    rows 1–5.
14. **P is bindable and no longer pauses.** LEFT←P; `joy_keys` = `70 101 55 66 86`. Then in a game,
    **P held for 30 fields with `music_pause` still 0**, and holding it took `sprite_pos` x from 40
    to 16.
15. **CTRL+P pauses and unpauses**, read as `music_pause` = `&FF` then 0. It arms on the release,
    which is `p_release` doing its job.
16. **Q alone does not mute** — `music_mute` = 0 after 20 fields held. **CTRL+Q does**, and the
    chip agrees: all four SN76489 channels at attenuation 15. CTRL+Q again brings it back (CH0
    vol 11, CH3 vol 3).
17. **SPACE binds and flies.** LEFT←SPACE, and neither pressing it on the screen nor leaving the
    screen with it bound started a game; in play it took x from 40 to 16.
18. **ESCAPE straight out leaves the credits clean** — this is the test that found the row-1 bug,
    and now shows no leftover.
19. **All eight flag combinations assemble**, twice over. The four DEV `-Akl` ones are the reason
    the trigger moved and then moved back; they are the test that caught both.
20. **`tools/export_title.py` refuses** a message that will not fit the twelve drawn glyphs and a
    word the font cannot draw, through the same assertion the credits already had.

### The two bugs the emulator caught, both worth not rediscovering

**A routine that started paging.** `ttl_cred_start` moved into bank 2 and became a `bank_call`
shim, and `kr_cred_back` in bank 1 went on calling it as though it still only stored — so it
returned to bank 1's addresses with **bank 0 paged underneath them**. The symptom was mild and
misleading: the screen stayed up, the credits never came back, and fire did nothing afterwards.
This is decision 71's own narrow rule — a sideways bank may not call main-RAM code that pages a
different bank — broken within the day of writing it down, and broken by changing what a routine
*does* rather than who calls it. `kr_cred_back` calls bank 2 through `kr_bank` now.

**The credits cannot clear credit row 1.** Their row list is `0,2,3,4,5`, so `title_text` never
writes row 1 at all, and the redefine screen's second line sat on top of the credits after every
exit. The way out paints all six rows blank first (`kr_blank`), which costs a second full paint on
a page that is about to change anyway.

### Not checked, and worth knowing

* **The dropped field on a key press was accepted by eye, not counted.** A repaint is 228 glyphs ×
  16 bytes = 3,648 against a field's ~40,000 cycles, so a key press costs the scroller one field of
  travel, and the exit costs two. Looked at in jsbeeb and it does not read badly — the zoom band is
  40 cells wide — but `ttl_top` was not sampled across a press to put a number on it. The fix, if
  it ever needs one, is a per-line entry in bank 3 at about 40 bytes; `-Cpc`'s bank 3 has 29 now,
  so that fix has got tighter.
* **A NuLA build was assembled but not booted.** The screen inherits whatever the credits do under
  NuLA, where the crossfade is a cut (decision 63); nothing here touches the palette except through
  `ttl_cred_off`, which that build already uses.
* **Real hardware.** Everything above is jsbeeb.

---

## What changed against the spec

Written down because the spec is in this file's history and a reader may have the earlier version:

* **"KEYS SET" is gone.** Both endings — finished, and ESCAPE-cancelled — show the five bindings
  with no prompt on any line and hold. What they stand at *is* the difference between the two, so
  neither needs a word saying so, and it saved a sixteen-byte message record in a layer that was 69
  bytes over.
* **The tables are in `&3C80`, not bank 1.**
* **The trigger is in bank 1**, in `ttl_frame_titles` — but `key_start` stayed in main RAM. It was
  moved out for an hour when main RAM was the region in trouble, and moved back when
  `ttl_cred_start` freed 26 bytes there and left bank 1 as the tight one instead.
* **`kr_wait_up` does not wait for CTRL**, only for a clear candidate keyboard and ESCAPE.
* **The block is six lines, not five** (decision 72), and the spec's reason for refusing a sixth —
  that `title_rows` and `TITLE_LINES` would have to become variables in bank 3 — turned out to cost
  fourteen bytes rather than the thirty-eight it feared, because both row lists share one table.
