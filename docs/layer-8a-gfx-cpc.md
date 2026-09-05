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

* **Sprites.** Every one of frames 0–118 was compared against `reference/sprite-sheet-c64.png`'s
  opaque/transparent mask at every offset from −8 to +19. Offset 0 scores 99.9%; the next
  best is 76%. Of the 119, 95 match exactly and 24 differ by one to five pixels, which is
  the CPC masking per byte where the C64 masks per pixel.
* **Characters and tiles.** The CPC tile table is the C64's transposed —
  `C64[row * 4 + col]` is `CPC[col * 4 + row]` — with the same character numbers, and
  rendering the CPC tile sheet puts every shape in the cell `reference/tiles-c64.png` puts it
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

## The status panel and the HUD (decision 56)

The artwork switch used to stop at the tiles and the sprites: the panel above the CPC's
scenery was still the C64's, five rows of `status.chr` under decision 34's colour mapping.
The Amstrad has its own, and it is in two places.

**`EG_Panel.asm` holds the image as eight `PanelBlockN` tables of 320 bytes, and `N` is the
SCANLINE, not a frame.** A CPC screen interleaves `(line % 8) * &800 + (line / 8) * 80`, so
block N sits at `&4000 + N * &800` — which is what the `defs` padding between the blocks adds
up to — and its 320 bytes are scanline N of four consecutive character rows of 80 bytes.
`EG_Interrupts2.asm` confirms the geometry from the other end: `int_rout4` sets R12/R13 to
`&10, &00` for base &4000 and `int_rout5` sets R6 = 4. So the panel is **4 character rows by
8 scanlines**, 160 mode 0 pixels wide — our 160 exactly, and one row *shorter* than the C64's
five.

**`EG_GameFont.ASM` holds the ten digits and the life marker**, and neither is stored in any
tidy order. `PrintScoreChar` and `PrintLife` in `EG_Display3.asm` are unrolled copies that
walk the CPC's scanline bits with `set`/`res` on D while zig-zagging along E, so the source
bytes come out neither row-major nor column-major: a digit's twelve bytes are scanlines
1, 3, 2, 6, 5, 4 with the byte pair reversed on alternate lines, and the marker's thirty-two
are scanlines 0, 1, 3, 2, 6, 7, 5, 4 four bytes at a time, left to right on the way out and
right to left on the way back.

**Both orders are proved, not assumed.** The panel image ships with `000000`, `012345` and
three life markers already drawn into it, so it is its own oracle:
`tools/cpc/paneldata.py`'s `verify()` re-derives all fifteen glyphs from the panel bytes and
raises if a single one disagrees. It runs on every export.

Two things fell out of the comparison, and both were luck:

* **The HUD needed no code change at all.** The CPC port copied the C64's panel layout to the
  column — including the two blank columns at the end that the C64's 38-column border ate —
  so its score sits at row 1 column 7, its high score at row 1 column 27 and its three life
  markers at row 2 columns 17-22. That is exactly where `PANEL_SHIFT` = 1 and `bank3.asm`'s
  `hud_cell_lo/hi` already put the C64's. Only the `INCBIN` moves.
* **The dither phase lines up for free.** Decision 55's checkerboard is `(x + y) & 1` in art
  coordinates, and a HUD glyph is poked into a whole cell — 4 pixels wide, 8 rows high, both
  even — so glyph-local parity *is* the panel's. The exporter proves it rather than trusting
  it: it rebuilds the panel's own three life markers out of glyphs 11 and 12 and compares.

The one thing that did not line up is the height. **The CPC's panel is four rows and the
rupture wants five**, so the art lands in rows 0-3 and row 4 is left black. Moving the split
instead would mean re-deriving decision 44's two cycles for one build, and the blank row costs
nothing visible: the play area's scenery never reaches its own top edge.

Colour goes through the same dither pairs as the rest of the CPC art, so nothing here consults
`C64_TO_MODE2`. In particular the `HUD_PAIR_3` brightening is gone — decision 34 had to force
the C64 digits' body to white because dark grey and blue both collapsed to blue and left a
four-pixel digit almost invisible; the CPC draws its digits bright cyan on blue, which needs no
help. It costs 135 packed bytes on `PANEL` and 15 on `BANK3`.

## The compiled bullet, which this build used to give up

**It fits now, and the two builds run the same code path.** A compiled body (decision 29)
costs code per *opaque* byte of the box, and the CPC's bullet - masked per byte on the
Amstrad, so it has fewer see-through bytes - compiles to 2,860 against the C64's 2,652. When
this layer was built that was 13 bytes more than bank 3 had, `CPC_COMPILE_DPS` was left empty
and the bullet took the interpreted path that 117 of the 119 frames take.

The 13 bytes were found by other work rather than gone after. Decision 47 moved the panel
image out of bank 3 into the `PANEL` disc file and decision 49 moved `!BOOT` out of the code
image; with the bullet compiled, bank 3 now assembles with **43 bytes of slack below
`music_lo`** and the disc grows 256 bytes. Frame meters compare across the two builds again
(decision 57).

**`tools/verify_compiled.py` is the check that the bodies are right**, and it did not exist
before. Nothing at build time compares a compiled body against the frame it came from — it
either draws the sprite or it draws rubbish, and the only place that shows is the screen. The
tool runs the emitted bytes on a simulator of exactly the sixteen opcodes
`compile_sprites.py` emits, over a buffer of pseudo-random background, and checks that every
opaque byte became `(background AND mask) OR data` at the address `sprite.asm`'s own pointer
walk reaches — 16K wrap and character-row crossings included — that the save area holds the
background those bytes covered, and that the restore body puts the buffer back byte for byte.
Both builds pass; flipping one baked immediate fails it.

It was worth writing rather than diffing play buffers between the two builds in the emulator,
which is what was tried first: the buffers differ by a sprite's worth of bytes whatever you
do, because the dump reads whichever bank ACCCON has selected and the faster build need not
be in the same bank phase.

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

## Not done: the Amstrad's grind sparks

The `GFX_CPC` build takes the Amstrad's *artwork*; it does not take its
behaviour, and there is one place where that shows. When the player grinds the
scenery the C64 flashes the ship — cyan to purple, dps `$0B-$11`, which we
transcribe — and the Amstrad instead swaps in seven dedicated sparking frames
through a second frame list (`PlayerFrameGrindList`, selected by `GrindState`).
KC spotted it playing the build on 2026-09-05.

`tools/rip_cpc_compiled.py` reads those frames back out of the compiled Z80 and
proves itself against the player frames SPRITES.BIN already holds;
`reference/grind-sparks-cpc.png` is the result. They cost 636 bytes in sprite
bank 1 and 742 in bank 2, which have 21 and 86 free, so it is **parked** — see
PLAN.md, and note that a `-Akl` build is the one place the room exists.
