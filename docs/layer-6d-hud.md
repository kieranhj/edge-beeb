# Layer 6d — the HUD

Done 2026-09-03. The colour-bar placeholder is gone: the panel is the C64's own status bar, and the
score, the high score and the lives bars are on it.

## What the original does

The C64's status bar is the top five rows of its 40 x 25 screen, and it is **not drawn by code**.
The character codes are assembled straight into the screen buffer at the very end of
`edge_grinder.asm` (`* = buffer_1`, 200 bytes), and `status_init` fills 200 bytes of colour RAM from
`status_cols` once, at `irq_init` time. Nothing ever redraws it.

Three fields move, and `status_decode` — called from the raster interrupt every field — pokes six
characters each into the same buffer:

| | C64 offset | row, column |
|---|---|---|
| score | `buffer_1+$02e` | 1, 6 |
| high score | `buffer_1+$042` | 1, 26 |
| lives bars | `buffer_1+$060` | 2, 16 |

The score and high score are six decimal digits, one to a byte, biggest first — not BCD — and the
character is `digit + $21`, so `$21` is '0'. The lives are `lives_display`, four eight-byte runs
indexed by `lives * 8`, of which six bytes are used: `$8f`,`$90` is one life's icon, so three lives
is that pair three times.

Layer 4 already ported `bump_score_*`, `score_scan` and `hiscore_update` verbatim, so the counters
existed before this layer; what was missing was the drawing.

## What we do

**The whole panel is rendered once, off-line, and copied in.** `tools/export_panel.py` reads
`source_c64/data/status.chr`, parses the 200-byte screen map and the 200-byte `status_cols` out of
the original's own source (rather than transcribing them by hand), and renders every cell with its
own colour-RAM byte applied. The output is `src/data/panel.bin`, 3,200 bytes: five rows of 640,
which is `PANEL_ADDR`'s whole extent, so `panel_draw` is a straight copy and there is nothing to
decode at runtime.

That works because of the same 1:1 the credits page found. `status.chr` is a **multicolour** set — a
character is four double-width pixels — and one of our 4-fat-pixel MODE 2 cells is exactly that. So
40 characters is 160 pixels, our play-area width, and a cell is 16 contiguous bytes (two byte
columns of eight, and our byte columns are consecutive).

**Colour is decision 34.** The bit pairs take `$d021` = black, `$d022` = blue, `$d023` = white and
the per-character colour RAM, which is `$0b` dark grey, `$0d` light green, `$0f` light grey or
`$00`. MODE 2 has no greys: dark grey goes to blue and light grey to white — the colours the
surrounding pairs already use — and light green keeps its hue. What is lost is the distinction
between dark grey and blue, which is most of the ornament.

**The moving cells are eighteen glyphs.** `src/data/hud.bin` holds thirteen 16-byte glyphs, all at
colour `$0b` because that is what every cell `status_decode` writes into carries: blank, '0' to '9',
and the two halves of the lives icon. `status_decode` builds `hud_want`, eighteen glyph indices,
from `score`, `hi_score` and `lives`, then paints.

**Their body is white, not the blue `$0b` gives the ornament.** A digit is bit pair 3 for the body
with a single pair-2 highlight pixel and a single pair-1 shadow pixel — on the C64, dark grey lit by
white and shaded by blue. The mapping above collapses dark grey and blue onto the same blue, so a
digit four pixels wide came out almost entirely blue on black: fine in sixteen colours, not here.
`HUD_PAIR_3` overrides pair 3 to white for these thirteen glyphs only; the shadow pixel stays blue,
so the shape the artist drew survives, and the panel's own artwork is untouched.

**It paints only what changed, per bank.** The C64 writes all eighteen characters every field
because a character there is one byte. Ours is sixteen, in two banks, so `hud_have` tracks what each
bank's panel is already showing — indexed `bank*18 + cell`, the same shape as the sprite engine's
per-bank save state, and for the same reason: a bank is redrawn every other game frame, so a change
has to be written twice, once into each. A still frame costs eighteen compares and nothing else;
scoring costs one or two 16-byte copies. `panel_draw` sets all thirty-six to `$ff`, because nothing
of the HUD survives a repaint.

The panel is also decoded on the **titles page**, once per bank inside `title_page`, because the
C64's `status_decode` keeps running through its titles and the last game's score stays up. That made
`score_boot` necessary: score, lives and high score are initialised data on the C64, sitting in the
file, and ours are in the `&0800` block which is not in the image — so they are set once at boot,
before the first titles page, and `game_init` leaves the high score alone thereafter. It is the
C64's `$00,$01,$02,$03,$04,$05`: 012345.

**The bar is centred here; on the C64 the border did that for it** (decision 42, 2026-09-04, KC:
"looks like the HUD panel isn't centred"). The screen map is forty columns wide but the art only
fills columns 0-37, and it is exactly mirror-symmetric about that span — measured, by rendering the
map to pixels and comparing every scanline with its own reverse: symmetric over 0..37, asymmetric
over 1..38, 2..39 and 0..39. The missing pair is eaten by the side borders, because `rout1` sets
`$d016 = $17` for the panel raster — 38-column mode, x-scroll 7. Our MODE 2 row shows all forty
columns and eats nothing, so the bar sat four pixels left of centre. `PANEL_SHIFT` in the exporter
rotates every row right by one column: blank columns 38 and 39 become 39 and 0, the art lands on
1-38, and row 4 — `$ff` in all forty columns — is unchanged by a rotation, so the solid bar under
the panel still runs edge to edge. `HUD_COL_SHIFT` in `bank3.asm` puts the same +1 on the score,
high-score and lives columns below.

## Where it all lives, and why

Main RAM had **36 bytes** free below `&2000` when the layer started and bank 0 had 151, so the
image, the glyphs, the tables and both routines are all in **bank 3**, which had 9K spare.

That needed a way in. `title_text_call` — 6c's one-routine trampoline — became **`bank3_call`**,
which takes the target in X and Y and writes it into a `JMP` it then calls. Self-modifying rather
than one entry per routine because main RAM has tens of bytes left, not hundreds. It must be in main
RAM: nothing in a sideways bank can page its own bank out from under itself, and every caller is in
bank 0, which is a sideways bank too. Bank 0 keeps the three-byte wrappers (`panel_init`,
`status_call`) so the main loop pays three bytes for the HUD rather than seven.

The DEV colour-bar placeholder (`fill_panel_test`) is deleted, and with it `panel_init`'s clear —
the image covers all 3,200 bytes.

Final free space: main RAM `&15`, bank 0 `&112`, bank 3 `&23DE`.

## Measured

Frame meter, `DEBUG_TIMING`, same input to both builds: boot to the titles, then **fire held down
for 5,000 fields** (100 seconds, 2,500 game frames) with the player never moved, so he dies over and
over and the screen is full of explosions. Figures are microseconds; double for 2 MHz cycles.

| worst frame | before 6d | after 6d |
|---|---|---|
| `spr_restore_all` | 9,613 | 9,622 |
| `scroll_frame` | 6,280 | 6,280 |
| `spr_draw_all` | 22,481 | 22,495 |
| logic + `scroll_advance` **+ the HUD** | 4,226 | **4,411** |
| whole frame | 40,827 (102%) | 40,439 (101%) |
| frames that missed their flip | 3 | 4 |

**The HUD costs about 370 cycles on its worst frame** and nothing measurable on the total — the two
whole-frame figures differ by less than the run-to-run noise of where the explosions landed, and the
after figure is the lower of the two. The margin `PLAN.md` worried about was not needed.

The test itself is worth keeping in mind: this is not the 90% of `BUGS.md` #9's "100 s of play". It
is 101-102% with a handful of missed flips in 2,500 frames, in **both** builds, because holding fire
into the scenery with a parked ship makes explosions the whole time. Ordinary play is the gentler
number.

## Verified in jsbeeb

- The panel appears in both banks and under both the titles and the game.
- After decision 42: all forty scanlines of `panel.bin` are their own mirror, and the score, high
  score and lives bars still sit inside their boxes on the titles page and in play.
- Score poked to 987654 and high score to 678901 renders all ten digits correctly at the right
  cells; the panel read back out of screen RAM and rendered to PNG matches the exporter's own render
  of the same data. Re-checked after the glyphs were brightened, reading 138694 off a running game.
- Lives 3, 2, 1 and 0 give three, two, one and no icons, from `lives` alone, through real deaths.
- The high score reads 012345 from boot and survives `game_init`.

## Left over

- The C64's `ttl_pulse` cycles the colour of one panel row on the titles page. Not ported: it is a
  colour-RAM effect on a machine with per-character colour, and it belongs with 6e's zoom scroller.
- `sprite_idx`, `x_count` and `y_count` in zero page were the placeholder's and `sprite_plot`'s; all
  three are now unused. Zero page is not the constraint, so they are left declared.
