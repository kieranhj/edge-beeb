# Layer 9c — the "MEGA HERO" message

Done 2026-09-04. The last hole in the completion sequence: what the C64 draws over the play area
once the wave table has run out and the player has flown off the right-hand side.

`src/bank1.asm` (`mega_mess`, `mega_one`, `mega_plot`), `tools/export_mega.py`,
`src/data/mega.bin` and `mega-cpc.bin`, and four lines in `comp_mess` in `src/bank0.asm`.

## It never needed a font

`docs/layer-6c-state-machine.md` parked it in Layer 6c as "written in character codes into a text
screen we do not have… waits for Layer 8 and a font drawn for the job", and `PLAN.md` carried that
for two layers. **That is not what the data is.** `mega_hero_txt` is two 240-byte on/off bitmaps —
6 rows of 40 cells each, every byte `$20` or `$00` — and `comp_mess` writes character `$80` where
one is set and blank where it is clear. One character, repeated. There is no alphabet anywhere in
it.

A second claim in `PLAN.md` was also wrong and is corrected here: the second block is **not** a
180-degree rotated twin. The original reads it with `Y` counting *down* from `$ef` while `X` counts
up, but it writes it at `buffer_2 + $280 + Y` — the same index it read from — so the picture goes on
the right way up and only the *reveal* runs backwards. The two blocks meet in the middle, "MEGA"
filling in from its top left and "HERO" from its bottom right.

## The geometry falls out of the port we already have

| | C64 | here |
|---|---|---|
| a cell | one character: 8 hires pixels, 4 multicolour | 4 fat pixels = 2 byte columns = **16 bytes** |
| the row | 40 cells | 40 × 4 = 160 pixels, which is the play area's whole width |
| block 1 | screen row 8 | play row **3** — the play area is the C64's rows 5-24 |
| block 2 | screen row 16 | play row **11** |

16 bytes is the zoom scroller's cell exactly (`TTL_CELL`), so `mega_plot` copies one the same way
`zm_write_band` does, and 40 cells of 16 bytes is 640 bytes, which is one of our rows. **The cell
offset therefore just increments by 16 from the first cell to the last**, straight through the row
ends, and no divide or row counter is needed anywhere: block 1 walks forward from
`8 + 3*640`, block 2 backward from `8 + 11*640 + 239*16`.

## The colour is the original's override, not `col_decode`'s

`comp_mess` writes `$0d` — light green — into colour RAM for every cell it draws, over whatever
`col_decode` gives character `$80`. `col_decode[$80]` is `$1b`: cyan, and fatal. It is never seen,
because **character `$80` appears in no tile**: checked, all 3,376 bytes of `tiles.til`. The only
colour that character ever has on a C64 screen is the one `comp_mess` gives it. So
`tools/export_mega.py` renders it with `$0d` for bit pair 11 and the playfield's own registers for
the other three, and `C64_TO_BBC` sends `$0d` to green.

## The drop shadow, and the one test it needs

Beside every cell it draws, the original blanks the cell **41 on** — one row down and one to the
right — which punches the scenery out from behind the letters and gives them a shadow. Both blocks
do it and the two need different care:

- **Block 1 runs forwards**, so the cell it blanks has not been drawn yet. No test: the original
  has none either.
- **Block 2 runs backwards**, so the cell it blanks may already carry a letter. The original reads
  the screen — `cmp #$80` — and leaves it alone if it does. Transcribed.

Our cell is 16 bytes rather than one screen code, so "is a letter here already?" has to compare
*one* of them, and comparing byte 0 is only meaningful if byte 0 has ink in it. It does in the C64
artwork (`$3f`) and it does not in the CPC's (`$00`, the cell's top-left two pixels being blank).
So `export_mega.py` writes a **17th byte, `mega_key`: the index of the cell's first non-zero byte**,
and the test compares that one. It is 0 for the C64 build, which is what was measured, and 1 for
`GFX_CPC`.

## Both banks, and the buffer wrap

**Every cell is written into main and shadow both**, by flipping `&FE34`'s X bit round each pass.
`field_wait` hands no frame over, so while the message is drawing the display is standing still on
one bank — but the finale that follows starts flipping again, and a message in one bank only would
strobe at 25 Hz from that moment.

The 16 bytes go in as **two byte columns of eight**, not one run of sixteen. The play buffer is 16K
and hardware-wrapped, `corner_addr` is a multiple of 8 and the cell offsets are 8 mod 16, so a cell
can begin at `&7FF8` and a sixteen-byte run would straddle the wrap. An eight-byte column starting
on an eight-byte boundary cannot.

## Where it lives

The whole thing — the 240-field loop as well as the plotting — is in **bank 1**, called once from
`comp_mess` through `bank_call`. `comp_mess` is in bank 0 and bank 0 has 16 bytes left; this is
307 of code and 80 of data. Nothing in a sideways bank may call main RAM, but the only main-RAM
routine it wants is `field_wait`, which is three instructions over a variable and inlines, and for
the five seconds this takes nothing else runs but the music interrupt.

It is in two pieces because bank 1 is in two pieces. `mega_data`, `mega_gd` and `mega_one` are in
the 171-byte hole between the starfield's tables and the tune's B1 stream at `&B900` — the same hole
the starfield's tables went into, and there are 11 bytes of it left. `mega_mess` and `mega_plot` are
in the bank's tail past the stream, where the starfield's code is. **Its state is not in the bank at
all**: the fifteen bytes live in the `&0800` block in main RAM, which has hundreds free where bank 1
has tens.

## Measured

jsbeeb, Master 128, 2026-09-04. Forcing `comp_flag` from the wave table's own address, the message
draws a cell a field over the frozen level, "MEGA" from the top left and "HERO" from the bottom
right, and the bonus counts on behind it.

**The check is the buffer, not the screenshot.** With the run stopped during the bonus — the message
finished, `mega_j` = 30, nothing else drawing — the play buffer was dumped from **both** banks and
every one of the 480 cells compared against `mega.bin`: **0 mismatches in main and 0 in shadow**,
letters where the bitmap is set, no letter where it is clear, and every shadow cell either blank or
occupied by a letter the guard correctly spared.

Taking the dump during the *finale* instead gives 13 mismatches, and they are the point of saying
when: the bangs are being drawn over the message by then, and each mismatch is one byte of one cell
under an explosion. The window is the bonus.

Two consecutive frames of the finale are pixel-identical over the message, which is the bank test:
one bank only would alternate.

`GFX_CPC` was run as well and reads correctly in the CPC's cyan and red.

## Cost

240 fields — 4.8 seconds — and it blocks for all of them, exactly as the original blocks on
`sync_wait`. Nothing is moving and nothing is being drawn, so there is no frame to hand over. Then
the bonus's 50 fields a life, then the finale.

| | |
|---|---|
| bank 1 | 80 bytes of data + 307 of code. **86 free** in the tail, 11 in the hole |
| bank 0 | 12 bytes: the `bank_call`. **16 free** (182 under `RELEASE`) |
| `&0800` block | 15 bytes of state |
| main RAM code | nothing |

## Noticed while measuring, and not fixed here

**The bonus counts up invisibly.** The score does not move on the panel until the finale starts,
because `status_call` is in the main loop and `comp_mess` blocks right through the bonus without
returning to it. The C64 does not have that problem: it runs `status_decode` from its raster
interrupt, so its panel keeps being drawn while `comp_mess` blocks. Ours is one `status_call` away
from the same behaviour, inside `bonus_wait`'s loop - but that is `comp_mess`'s business, not the
message's, and bank 0 has sixteen bytes left. Left as found.

## What is left in the completion sequence

Nothing of the C64's. `PLAN.md` 9c item 3 — the CPC's **win tune**, `WON4.SKS`, which the CPC
switches to the moment the mega-hero build starts — is an addition of Axelay's port and is still
open.
