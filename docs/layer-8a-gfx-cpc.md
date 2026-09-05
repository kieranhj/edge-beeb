# Layer 8a — the CPC artwork, behind `GFX_CPC`

`.\build.ps1 -Cpc` builds the same game drawn with Trevor "Smila" Storey's Amstrad CPC art
instead of the C64's: all 119 sprite frames and all 256 background characters. It is a
**comparison build**, like `MUSIC_AKL` — a third option beside the C64 conversion and the
hand-authored MODE 2 redraw Layer 8 is for (decision 3) — and the choice between them is
KC's, not made here. Decision 41.

Everything but the pixels is shared. The tile table, the map, `col_decode`, the wave table,
`dp_dcd`, `anim_decode`, the status panel, the HUD, the titles and the loading screen are
the same files in both builds.

## Why the numbering just works

The CPC port took the C64's data and reformatted it, so its frames, characters and tiles
are the C64's, renumbered not at all. That is measured, not assumed:

* **Sprites.** Every one of frames 0–118 was compared against `assets/sprite-sheet.png`'s
  opaque/transparent mask at every offset from −8 to +19. Offset 0 scores 99.9%; the next
  best is 76%. Of the 119, 95 match exactly and 24 differ by one to five pixels, which is
  the CPC masking per byte where the C64 masks per pixel.
* **Characters and tiles.** The CPC tile table is the C64's transposed —
  `C64[row * 4 + col]` is `CPC[col * 4 + row]` — with the same character numbers, and
  rendering the CPC tile sheet puts every shape in the cell `reference/tiles.png` puts it
  in.

So a CPC frame is a drop-in for the C64 frame of the same number, and nothing in `src/`
changes except which file gets `INCBIN`'d.

## Where the art comes from

| | |
|---|---|
| Sprites | `SPRITES.BIN` on `source_cpc/Work Disks/edge_sprites2.dsk` — the "normal" bank the CPC pages into `&4000` as bank 3. 128 slots of 128 bytes, 126 used, 6 bytes × 21 lines; slots 119–127 are empty |
| Characters | `source_cpc/Source/char_graphic5.ASM`, the data half of the CPC's background bank |
| Tile table | `source_cpc/Source/EG_Tiles_Formatted.asm` — read only to check the numbering; the build uses the C64's `tiles.bin` |

`tools/cpc/` holds the readers: `dsk.py` (Extended DSK + AMSDOS catalogue), `cpcscr.py`
(mode 0 decode, the gate-array colour table, the palette), `bgdata.py` (how the background
bank is indexed) and `bbcart.py` (the two of those turned into BBC logical colours, which
is all the exporters see). `tools/rip_cpc_sprites.py` and `tools/rip_cpc_background.py`
write the art back out as sheets in the format of the C64 ones, for looking at.

### Two twists in the character data, from `Block_Writer4.asm`

Both bite hard if missed — the first render came out as stripey noise.

* **The byte index is not the pixel line.** `Copy_Buffer` walks the eight lines of a
  character row by flipping bits 3–5 of the screen address in the cheapest order, and its
  comments name the line it just wrote: 1, 2, 4, 3, 7, 8, 6, 5. The column buffer fills in
  step with the character bytes, so byte *i* lands on line `[0,1,3,2,6,7,5,4][i]`.
* **The two pixels of every odd-numbered byte are stored swapped** — "even bytes stored
  swapped", counting from one. `LowCharWrite` masks with `&55` on even bytes and rotates
  first on odd ones; `HighCharWrite` does the opposite.

Sprites need neither: `PrintSprites` reads them in plain order, ten line-pairs of twelve
bytes — `(col 0 lower, col 0 upper, col 1 lower, …)`, the lower line of an address pair
first — then six bytes for line 20 on its own.

## The palette

`Mode0Pal` in `source_cpc/Source/Compiled_Main3.asm`, the **in-game** palette, not the
`.PAL` saved beside the art on the work disc. `SetColours` is called with A = 15 and walks
the list from pen 15 down to pen 0, so the table is stored **reversed** — its own comment
says so, and reversing is what makes 13 of the 16 pens agree with the art disc. The three
that differ are 13, 14 and 15, and 13 and 14 are both used, so the choice is visible: the
art disc would draw those explosions orange where the game draws them blue and magenta.

### A pen is a dither pair (decision 55)

Mode 0 gives sixteen pens out of 27 possible colours against MODE 2's eight. The first
attempt at this build sent each pen to one BBC colour through a hand-written
`bbc.CPC_TO_BBC` table, by hue rather than by RGB distance, and it flattened the art: pens
8, 10, 12 and 13 all landed on cyan, pens 2 and 11 both on yellow, pens 1 and 5 both on
red. Half-brightness disappeared entirely — the CPC's dark red, dark green, dark blue and
dark yellow came back at full saturation — and Smila's shading with them.

**Rich Talbot-Watkins's scheme replaces it.** Each CPC colour becomes *two* MODE 2 colours
checkerboarded a pixel at a time, so MODE 2's eight corners of the RGB cube reach the
middle levels the CPC has and this machine has not. `reference/cpc-palette-map-to-bbc-mode2.png`
is Rich's chart of all 27, and `bbc.dither_pair` is the rule that generates it — verified
cell for cell against the chart, all 27, no exceptions:

> of the 36 unordered pairs of the eight MODE 2 colours, take those whose per-channel
> average is nearest the target; among those, choose **the two closest in brightness**;
> then order the pair **darkest first**.

Both tie-breaks matter. Nearest-average alone is ambiguous over most of the middle of the
cube — mid grey (128,128,128) is red+cyan as readily as magenta+green, and (255,128,128)
is red+white as readily as yellow+magenta — and in every such case the pair closer in
brightness is the one that reads as a colour rather than as two colours flickering.
Brightness is Rec.601 luma; nothing in the 27 ties on it. "Darkest first" then fixes the
phase, which is what stops two adjacent colours dithering in antiphase and cancelling.

Nine of the game's sixteen pens dither and seven are colours MODE 2 already has:

| pen | CPC | BBC | | pen | CPC | BBC |
|---|---|---|---|---|---|---|
| 0 | black | black | | 8 | pastel blue | magenta + cyan |
| 1 | dark red | black + red | | 9 | bright white | white |
| 2 | pastel yellow | yellow + white | | 10 | bright cyan | cyan |
| 3 | dark blue | black + blue | | 11 | dark yellow | red + green |
| 4 | dark green | black + green | | 12 | bright cyan | cyan |
| 5 | bright red | red | | 13 | sky blue | blue + cyan |
| 6 | pink | magenta + yellow | | 14 | mauve | blue + magenta |
| 7 | bright blue | blue | | 15 | black (unused) | black |

The checkerboard is `(x + y) & 1` in the **art's own** coordinates — the character's, the
sprite frame's — not the screen's, and it is baked into the exported bitmaps. That is the
only phase the hardware will hold: the background scrolls a pixel a frame and a sprite
moves where it likes, so a screen-aligned dither would crawl over both. Art-aligned, the
texture travels with the scenery. A character is 4 pixels by 8 and both are even, so every
character in a tile and every tile on the map share one continuous checkerboard; a sprite
carries its own, and its two pixel-shift banks carry the same one shifted with it.

The cost is compression, and only in the sprite banks: the dither is noise to ZX0, so
`BANK1` goes from 7,137 packed bytes to 7,606 and `BANK2` from 6,793 to 7,301. The
charset is unmoved — `BANK0` 5,756 to 5,708, marginally *better*, the checkerboard being a
regular pattern where the sprites' is broken up by transparency — and `BANK3` is unchanged
at 8,680, holding no art. The disc image grows 1,024 bytes to 48,384; every stream keeps
several kilobytes of headroom and nothing else in the build moves.

Two things fall out of the CPC art being sixteen-colour rather than four:

* **Transparency is per byte**, because `PrintSprites` tests a whole byte for zero and
  skips it. A pen 0 pixel beside a lit one is drawn black — logical 8, the sprite engine's
  black — and only a zero byte is see-through. That costs 6 bytes in bank 1 and 182 in
  bank 2 over the C64 art, both still inside 16K.
* **The hit flash takes the whole sprite.** Decision 20's tables keep the sprite's shared
  blue and white and recolour only its one per-sprite colour; a CPC frame has fifteen
  colours and no per-sprite colour, so `KEEP` shrinks to the transparency key alone and
  everything lit goes white or magenta. Which frames flash, and when, is unchanged: that
  is `dp_dcd` and `lut_dcd`, game logic, not art.

## What this build gives up: the compiled bullet

**Nothing is compiled under `GFX_CPC`, and the reason is 13 bytes.** A compiled body
(decision 29) costs code per *opaque* byte of the box, and the CPC's bullet — masked per
byte, so it has fewer see-through bytes — compiles to 2,860 against the C64's 2,652. Bank 3
has 195 bytes free below `music_lo`, so it lands 13 over, and the only other way to make
room is to cut the tune again (decision 37). `CPC_COMPILE_DPS` is therefore empty and the
bullet takes the interpreted path that 117 of the 119 frames already take.

It means the CPC build is a shade slower than the default one, so **do not compare frame
meters across the two**. It is a comparison of how the game looks. If the CPC art is ever
chosen for real, the 13 bytes are worth going after.

`-Akl -Cpc` is the exception and is not exploited: `MUSIC_AKL` takes `music_lo` out of bank 3
altogether and leaves 8,960 bytes free there, so the compiled bullet fits easily. Putting
`(0x12, 0x13)` back into `CPC_COMPILE_DPS` would do it, but the exporter has no idea which
music build it is being run for, so it stays off in both.

## Building it

```powershell
python tools\export_tiles.py --cpc      # src/data/chars-cpc.bin
python tools\export_sprites.py --cpc    # sprites{0,1}-cpc.bin, compiled-cpc.bin, compiled_zp-cpc.asm
.\build.ps1 -Cpc                        # build/EDGE-CPC.SSD, disc title EDGEC
```

`GFX_CPC` is a beebasm command-line symbol like `RELEASE` and `MUSIC_AKL`, so **every**
build passes it (`-D GFX_CPC=0` or `1`); beebasm has no `IFDEF` and refuses a symbol
defined twice, so `main.asm` cannot carry a default. It is stamped in `!BOOT` outside the
`RELEASE` test, because it is legal under `RELEASE` and changes every pixel on the disc.
`-Akl` and `-Cpc` are independent and compose: the disc title is `EDGE` plus `A` plus `C`
as asked for, and the filename stem `EDGE-AKL-CPC`.

`tools/render_bbc.py --cpc` renders the converted data back to PNG for checking, the same
way it does the C64 build's.

## Verified

Booted in jsbeeb as a Master 128 from `build/EDGE-CPC-200K.SSD`: `!BOOT` reports
`REM GFX_CPC: the Amstrad CPC artwork`, the titles come up, and play shows the CPC scenery
and CPC enemies scrolling. 2026-09-04.
