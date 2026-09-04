# Layer 9e — the credits crossfade

2026-09-04. Decision 53. The titles page now carries two sets of credits and fades between them:
the C64's own, which Layer 6e transcribed, and this port's. Five seconds a set, about a second of
fade either side, for as long as the page is up.

```
edge grinder     by     cosine systems        edge grinder bbc master version
coding                jason t.m.r kelk    coding               kieran and claude
graphics           trevor smila storey    graphics          john dethmunk blythe
music by            sean odie connolly    music conversion tooling     simondotm
released by        format war and rgcd    released by                bitshifters
```

The new set is laid out the way the original's block is — a label at the left and its value hard
against the right, the first line centred — so the swap reads as the same five lines changing
rather than as a different page.

## The fade is the palette, and it touches the credits alone

The obvious problem with fading anything on this page is that the palette is global and the page is
four CRTC cycles, three of which must not move: the panel, the top zoom band and the bottom one.
The credits band cannot be given a palette of its own without a seventh T1 fire, and redrawing the
block through a colour map costs 3,040 bytes a step — more than a field, so the scroller would
stutter and the block would tear.

**So the credits were moved out of the way instead.** `tools/export_title.py` draws their font in
logicals **12, 14 and 15** rather than 4, 6 and 7. `setup_display` maps logicals 8–15 back onto 0–7,
so those *are* the same blue, cyan and white and the page looks exactly as it did — but they are
palette entries **nothing else on the titles uses**. The panel and both zoom bands are drawn in
0–7, and no sprite is on screen.

That turns the whole feature into eight writes to `&FE21` a rung:

| rung | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| colour | black | blue | red | magenta | green | cyan | yellow | white |

the same ladder the memorial uses (decision 52), with the same two directions: down subtracts the
rung and clamps at black, up caps it. Not a byte of the screen is touched, so **nothing tears and
the scroller never loses a field**. Measured in jsbeeb at down-rung 3: the credits are green body,
red highlight, no blue shadow — white−3, cyan−3, blue−3 — while the panel and both bands are still
white, cyan and green.

`ttl_c_step` is the whole state machine: 0–7 fade down, 8 swaps the set, 9–15 fade up, 16 is done,
17 is holding. **The swap happens at rung 8, with the palette already black**, so the `bank3_call`
that repaints the block is not seen — and because it runs while everything is black, cells that
were text in one set and blank in the other need no clearing.

## The raster has to stand down

Layer 6e's credit raster (`ttl_raster`, bank 1) writes eight scanlines of `&FE21` on the first and
last credit lines every field, and it now writes logicals **15 and 14** — every byte of `ttl_pal`
is the old one plus `&80`, which is the logical nibble's top bit, and the restore at the end of the
routine goes with it. Left running, it would put those two straight back to full brightness on two
of the five lines while the other three faded.

So `ttl_fade_on` skips it for the duration. Fire 4's CRTC writes still happen — eight scanlines
earlier than usual, which is still comfortably inside cycle C — and fire 5 does nothing but the
raster, so skipping it is free. The pulse comes back with the new text, which reads as intentional:
the line settles, then starts to breathe.

## Where it all went, and what that cost

Two things had to move, and both were things the memory map had already named.

**The 190 bytes of new credits ride on the end of the `PANEL` disc file**, so they land at
`&3C80` — the 896 bytes above the panel and below the play buffer that **neither rupture cycle ever
fetches**. `docs/memory-map.md` listed that region as room going spare, and said a candidate is not
a promise until a sentinel has survived a run of the game. It has: after a full game — three lives,
the blitter writing `SPR_SAVE` every frame, the HUD, the scroll, the starfield — all 190 bytes read
back out of jsbeeb **byte for byte identical to `src/data/title_extra.bin`**. The file is unpacked
into both banks' `&3000` at boot anyway, so the credits arrive in both for nothing.

Bank 3, where the font and `title_text` are, could not have held them: it has 253 bytes below the
tune in the default build and **45** with the CPC artwork.

**`fade_pal` and the crossfade's state machine are in bank 2.** Main RAM below `SPR_SAVE` — the only
ground anything read after a game has started may use — had 68 bytes free and the two of them are
264. Bank 2's tail has 185 and its hole below the tune stream has 373 (191 with the CPC artwork), so
they are split across the two: the ladder and `fade_pal` after the tune, the state machine before
it. Nothing in a sideways bank but bank 0 may call main RAM, so everything there is self-contained,
its arguments arrive through the `&0800` block, and the one thing it cannot do — the bank 3 call
that repaints the credits — is asked for by setting `ttl_redraw` and done by `ttl_cred_tick`.

`fade_pal` moved out of main RAM entirely, and the memorial now reaches it by `bank_call` too.

The figures after, from the listings:

| | before | after |
|---|---|---|
| `code_end` under `SPR_SAVE` | 153 | 58 |
| bank 0 (DEV) | 16 | 7 |
| bank 2, hole below the tune | 373 / 191 `-Cpc` | 220 / 38 `-Cpc` |
| bank 2, tail above the tune | 185 | 106 |
| bank 3, below the tune | 253 / 45 `-Cpc` | unchanged |

`title_text` itself cost **nothing**: it reads its five lines through `ttl_cred_ptr` instead of a
constant, which is the same three instructions.

## No digits

The credits font is the C64's status charset read as multicolour, and `scroll_decode` gives it
A–Z, space and `! . , - ?` — thirty-two glyphs, no numerals. The release line therefore ends at
`bitshifters` with no year. Ten digit glyphs would have been 160 bytes in a bank that has 45 of
them; KC's call was "don't worry about 2026".

## What was checked

In jsbeeb, as a Master, booting `build/EDGE-200K.SSD`:

- the C64 set comes up as Layer 6e drew it, with the raster pulsing on lines 1 and 5 — the move to
  logicals 12/14/15 changed nothing visible;
- it fades down, swaps, and fades up to the new set, and back again, while the panel, both zoom
  bands and the scroller stay at full brightness and keep moving;
- fire starts a game and **the palette is right in it** — `ttl_cred_end` puts logicals 8–15 back on
  the way out, and logical 8 is the second black the sprite engine draws with, so leaving the page
  mid-fade may not leave the palette mid-fade;
- after a full game the titles come back with both sets intact, and `&3C80` reads back byte for
  byte;
- the `-Cpc` build does all of the same.

All eight flag combinations assemble.
