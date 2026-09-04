# Layer 9d — the memorial

2026-09-04. Decision 52. The one sequence on the disc that is nobody's port of anything: between
the loading picture and the titles, the picture fades out, **IN MEMORY OF T.M.R.** fades up in the
middle of the screen, holds, and fades out again.

Jason "T.M.R." Kelk wrote *Edge Grinder*, and his name is already in the credits the titles page
draws — `coding                jason t.m.r kelk`, the C64's own `ttl_credits` line 2. This says it
once more, on its own, in the same font.

## The fade is the palette and nothing else

MODE 2's eight colours sit on **one brightness ladder**, and that is the whole trick:

| rung | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| colour | black | blue | red | magenta | green | cyan | yellow | white |

A step down the ladder is the whole picture one step darker — white → yellow → cyan → green →
magenta → red → blue → black, which is KC's own sequence and is exactly what the ladder gives when
each colour is moved one rung towards black. Sixteen writes to `&FE21` a rung, eight rungs, six
fields a rung: about a second, and **not one byte of the picture is touched**.

`fade_ramp` is rung → physical colour and `fade_idx` is its inverse. Both are needed and both are
eight bytes; the pair is also a three-bit rotate of each other (rung = `ROL3(colour)`), which costs
more code than the sixteen bytes it would save, so the tables stay.

**Down and up are not the same operation.** Fading down subtracts the step from every colour's rung
and clamps at black — everything moves together and everything arrives at black at a different
time, which is what makes a picture dim rather than dissolve. Fading up **caps** every colour's
rung at the step instead, so each colour stops when it reaches the one it is actually meant to be:
the credits font is blue, cyan and white, so its blue arrives at rung 1, its cyan at 5 and its
white at 7, and the message **assembles itself** — outline first, then body — rather than coming up
as one flat wash. Measured in jsbeeb: at up-step 3 the message is entirely magenta (white and cyan
both capped at rung 3, blue already home), and at down-step 4 the picture is magenta, red and blue
and nothing else.

The MOS's default MODE 2 palette is logical *n* → physical *n*, which is what the loading picture
was drawn against and what `setup_display` programs, so a logical colour's own rung is `fade_idx`
of itself and no target table is needed. All sixteen logical colours are written, because 8–15 are
the second black the sprite engine uses and have to track 0–7.

## The timing, and why interrupts go down

`install_irq` has not run. The MOS still owns IRQ1V, and its VSync handler would take the System
VIA's CA1 flag before a polling loop could ever see it — so the sequence does `SEI` first and
polls `&FE4D` bit 1 itself. **Interrupts stay off from there until `install_irq`'s own `CLI`.**
Nothing in between wants one: `setup_display`, `panel_init`, `score_boot` and `music_init` are all
straight-line boot code, and the disc is finished with.

Six fields a rung, eight rungs, three fades and a 150-field hold: about six seconds in total.

## Where it lives, and what it cost to put it there

It is **in two halves**, and the reason is the `GFX_CPC` build. The whole thing is 275 bytes; bank
3 — where the font is — had 370 bytes below the tune in the default build but **162** with the CPC
artwork, whose compiled sprite bodies are larger. So it is split on the one line that matters:

- **`mem_page`, in `src/bank3.asm`** — the half that needs `title_font`. Clear the 20K picture, draw
  the nineteen glyphs. One call, made with the palette already black, so neither the wipe nor the
  draw is ever seen happening. 123 bytes, which leaves the CPC build 45.
- **`memorial`, `mem_ramp`, `mem_field`, `fade_pal` and the two tables, in `src/main.asm`** — the
  half that needs nothing but hardware. Above `code_end` with the loader, because it is boot code.

Main RAM had **seven** bytes under `SPR_SAVE` when this started, and the sequencer alone is more
than that. Two things paid for it, both of which the memory map had already named as the next
moves:

1. **The boot loader moved above `code_end`.** `load_stream`, `unpack_to`, `panel_init`,
   `load_bank`, `unpack_andy` and `load_hazel` are all dead before the first sprite is drawn, and
   were sitting in the one region of the build that anything read in play has to fit into. Moving
   them past `code_end`, where `src/zx0depack.asm` already was, took the ceiling from **7 bytes
   free to 153**.
2. **`LOAD_STREAM` moved from `&2200` to `&2400`.** That is the top of the code image, and the
   image had nine bytes left under it. What it costs is the loading screen's own headroom:
   `LOADSC2`'s ZX0 stream is 2,820 bytes and the gap to `&3000` is now 3,072, so **252 bytes** of
   slack rather than 764. `tools/make_disc.py` refuses to write an image that has overrun it, so it
   cannot go wrong quietly. `BOOT_STAGE` went with it, `&2400` → `&2600`.

The figures after, from the listing (DEV, C64 artwork):

| | before | after |
|---|---|---|
| `code_end` under `SPR_SAVE` | 7 | 153 |
| image free to `LOAD_STREAM` | 187 | 521 |
| bank 3 below the tune | 370 | 253 |
| bank 3 below the tune, `-Cpc` | 162 | 45 |

## The message

`IN MEMORY OF T.M.R.`, nineteen characters, in the credits' own glyph numbers — 0 blank, 1–26 A–Z,
`&1c` full stop, which is the original's `scroll_decode` mapping and what `tools/export_title.py`
writes. It is data in `src/bank3.asm` and not an exported file: nineteen bytes did not need a tool.

A glyph is one 4-fat-pixel cell, two byte columns, sixteen bytes, and our byte columns are eight
bytes apart and consecutive — so a character is one straight sixteen-byte copy, exactly as
`title_text` does it. Nineteen of forty cells across puts it at column 10, centred bar half a
character; row 15 of 32 puts it half a row above the middle. Both are the loading screen's own
geometry (`&3000`, 640 bytes a row, 32 rows), not the game's.

## What was checked

In jsbeeb, booting `build/EDGE-200K.SSD` as a Master:

- the picture fades down through the ladder — at rung 4 the screen is magenta, red and blue and
  nothing else, which is white−4, yellow−4 and cyan−4 with everything below cyan already at black;
- the message comes up capped — at rung 3 it is entirely magenta, at rung 7 white with blue and
  cyan shading, centred;
- it fades out and `title_page` comes up with its zoom bands, credits and scroller intact, which is
  the check that `&FE34` and the paged bank were both put back.

All eight flag combinations (`RELEASE` × `MUSIC_AKL` × `GFX_CPC`) assemble.
