# The memory map, and what is left in it

Every figure here is **measured from the build**, not from the source by eye: beebasm's `PRINT`
statements write the high-water marks into the assembly listing, and these tables are what the
listings said on **2026-09-05**, after the CPC artwork was recoloured to dither pairs, given the
Amstrad's own panel and HUD, and had its bullet compiled (decisions 55-57), and after Layer 9f
moved the scrolltext out of bank 1 (decision 54). They go stale the moment
anything grows, so **take live numbers from the listing rather than trusting this page**:

```powershell
.\build.ps1                                     # and -Release, -Cpc, -Akl, -Akl -Cpc
Select-String -Path build\EDGE.lst -Pattern "CODE CEILING|HIGH WATERMARK|^FREE|HOLE|SLACK|REGION A|SCROLLTEXT"
```

All eight flag combinations at once, straight from beebasm rather than the listing:

```bash
for R in 0 1; do for A in 0 1; do for C in 0 1; do
  printf "R=%s A=%s C=%s | " $R $A $C
  ../../Bin/beebasm.exe -i src/main.asm -do /tmp/o.ssd -opt 3 \
      -D RELEASE=$R -D MUSIC_AKL=$A -D GFX_CPC=$C 2>/dev/null | tr -d '\r' \
    | grep -E "CODE CEILING|HOLE|SLACK|^FREE|ROOM LEFT" | tr '\n' ' '; echo
done; done; done
```

Unless a column says otherwise the numbers are the **default DEV build**: `RELEASE=0`,
`MUSIC_AKL=0`, `GFX_CPC=0`, so the frame meter is in and the VGI player is the music.

Zero page has no `PRINT` of its own; the two figures below came from a temporary
`PRINT "ZERO PAGE HIGH WATERMARK =", ~P%` above `ORG &E00`, which was not kept.

## Main RAM

| Range | Bytes | Contents | Free |
|---|---|---|---|
| `&0000-&009F` | 160 | zero page, ours, wiped at boot, `GUARD &9F` | **90** — high water `&46`. Under `MUSIC_AKL` the Arkos player's pointers take it to `&57`, **73** free |
| `&00A0-&00FF` | 96 | MOS zero page | — |
| `&0100-&01FF` | 256 | stack | — |
| `&0200-&03FF` | 512 | MOS vectors and workspace. `IRQ1V` (`&0204`) is ours outright | — |
| `&0400-&049F` | 160 | column buffer | 0 |
| `&04A0-&07BF` | 800 | collision character map, 40 × 20 | 0 |
| `&07C0-&07FF` | 64 | the collision map's overrun slack | 64, spent on purpose |
| `&0800-&0991` | 402 | the game state block — the C64's `$0340`. Declared after the SAVEs, so it is not in the image | **623** to `GAME_STATE_TOP` = `&0C00`. A RELEASE build ends 12 lower - the frame meter is the difference. The last two things in it are the starfield's 92 bytes (decisions 50 and 51) - 40 for the stars and 52 for where each bank last plotted them - and the "MEGA HERO" message's 15, which are up here because bank 1, where its code is, had tens of bytes left and this has hundreds |
| `&0C00-&0C5F` | 96 | **`VGI_STATE`**: the VGI player's decode state, eleven streams' worth (decision 49). Not in the image - nothing in it needs initialising | 160 to `&0D00` |
| `&0D00-&0DFF` | 256 | paged-ROM extended vectors. Not claimed, not tested | 256, unverified — see below |
| `&0E00-&2221` | 5,666 | code to `code_end` = `&1FD3`, then the boot-only data, **the loader**, **the memorial's fade** and `src/zx0depack.asm`. `GUARD CODE_TOP` = `LOAD_STREAM` = `&2400` | **478** to `LOAD_STREAM`, of which **45** are usable by anything read in play (74 in a RELEASE build, where `code_end` is `&1FB6`). Layer 9d moved the loader above `code_end` and `LOAD_STREAM` from `&2200` to `&2400` (decision 52); `!BOOT` left in Layer 9 (decision 49) |
| `&2000-&2FFF` | 4,096 | `SPR_SAVE`: 8 slots × 256 B × 2 banks, exactly. At assembly time `&2600` is where `!BOOT` is built, which costs the run nothing: it is a disc file, never loaded here | 0 by construction |
| `&3000-&3C7F` × 2 | 3,200 each | the status panel, in BOTH shadow banks | 0 |
| `&3C80-&3FFF` × 2 | 896 each | above the panel, below the play buffer, fetched by neither rupture cycle. **Layer 9e spends the first 190**: the titles' second credit set (decision 53). **Layer 9f spends 469 more**: `assets/scrolltext.txt`, which had eleven bytes of headroom behind the font in bank 1 and has hundreds here (decision 54). Both ride on the end of the `PANEL` file, which is unpacked into both banks at boot | **237** in each bank — the build prints it as SCROLLTEXT HEADROOM. It was 706 before Layer 9f |
| `&4000-&7FFF` × 2 | 16,384 each | the play buffers, main and shadow, hardware-wrapped at 16K | 0 |
| `&E000-&FFFF` | 8,192 | MOS ROM. `&FFFE` on this Master reads `&E59E` — measured — so paging HAZEL in cannot break IRQ dispatch | — |

**The tightest things in the build are region A's 32 bytes and bank 0's 9** - the whole tune is
23,486 bytes of stream in 24,320 bytes of region, and Layer 6e's `title_page` has to be in bank 0,
because bank 0 code may call into main RAM and be returned to and bank 1 code may not. A RELEASE
build has 175 in bank 0, the frame meter being the difference. **Bank 1's hole is no longer one of
them**: Layer 9f moved the scrolltext out of it into the `PANEL` file and it went from 11 bytes to
475 (decision 54). With the CPC artwork the tight ones are bank 3's 43 and bank 2's 38.

**THE CEILING THAT MATTERS IS `SPR_SAVE` = `&2000`, NOT `LOAD_STREAM`.** `&2000-&2FFF` is the
blitter's saved-background area, rewritten every frame from the first sprite onwards. Boot code and
boot data may sit in it and do - `src/zx0depack.asm`, the OSFILE block, the disc filenames, and
`!BOOT` assembled at `&2600` - because they are dead before anything reads there. **Anything read or
executed in play may not**, and for two layers nothing was checking: `explosion_dirs` drifted to
`&2024` and the player's explosion pieces stopped flying, because his own saved background was
landing on their movement vectors (`BUGS.md` #13). `main.asm` now carries
`ASSERT code_end <= SPR_SAVE` and the listing prints `CODE CEILING` beside it.

**`code_end` is `&1FD3`: 45 bytes under `SPR_SAVE` in a DEV build**, 74 in a RELEASE one - Layer 9e's
three wrappers took 95 of the 153 Layer 9d had opened up, and the rest of that layer went to bank 2
for exactly this reason. That, and not the 478 the FREE line prints, is what main RAM has left for
anything permanent. **Layer 9d is where the boot loader moved out**, which is what this page said
the next thing to want main-RAM code would have to do: `load_stream`, `unpack_to`, `panel_init`,
`load_bank`, `unpack_andy` and `load_hazel` are all dead before the first sprite is drawn and are
above `code_end` now, with the memorial's fade and the depacker. `LOAD_STREAM` went from `&2200` to
`&2400` with it, for the image as a whole; what that costs is the loading screen's own headroom -
`LOADSC2`'s stream has 252 bytes to `&3000` rather than 764, and `tools/make_disc.py` refuses an
image that overruns it.

**At boot the map is a different shape.** `&2400` upwards is the loading screen's ZX0 stream
(`LOAD_STREAM`), `&3000-&7FFF` in MAIN is the loading picture itself, and `&3000-&7FFF` in SHADOW is
`DEPK_STREAM`, where the four bank streams and the music stage before they are unpacked. None of
that survives into the game.

## Sideways RAM — the Master's four banks, slots 4-7

| Slot | Bank | Contents | High water | Free (DEV, C64 art) | `-Cpc` | `-Akl` | `-Akl -Cpc` |
|---|---|---|---|---|---|---|---|
| — | ANDY | the Master's own 4K, `&8000-&8FFF`, ROMSEL bit 7 — **measured 2026-09-04**, see below. One of the tune's eleven register streams lives here (decision 48) | `&8F9E` | **98** | 98 | 4,096 | 4,096 |
| 4 | `BANK0` | `char_data`, `tile_data`, `map_data`, `col_decode`, `wave_data`, `anim_decode`, and the run-once and out-of-room code | `&BFF7` | **9** | 9 | 9 | 9 |
| 5 | `BANK1` | sprite data, pixel shift 0, the titles' zoom scroller (Layer 6e), then `explosion_dirs`, the starfield's tables and the "MEGA HERO" message's data and `mega_one` (Layer 9c), then a tune stream at `MUSIC_B1_BASE` = `&B900`, then the starfield's and the message's code | `&BFAA` | **86** in the tail, **475** in the hole below `&B900` | 86 / **469** | 1,834 | 1,828 |
| 6 | `BANK2` | the same, shift 1, then the titles' credit crossfade, a tune stream at `MUSIC_B2_BASE` = `&BA00`, and `fade_pal` after it (decision 53) | `&BF96` | **106** in the tail, **220** in the hole below `&BA00` | 106 / **38** | 1,677 | 1,495 |
| 7 | `BANK3` | compiled sprite bodies, the titles' font, credits and plotter, the memorial's message and `mem_page` (Layer 9d), the HUD glyphs and `status_decode`; then region A of the tune | `&9005`, then `music_lo` fills `&9100-&BFFF` | **251** below the tune, **0** above it | **43** / 0 | 12,280 | 12,072 |

**Bank 1's hole opened up in Layer 9f and bank 3's closed a little in Layer 8a's revisit.** The hole
below `&B900` held the zoom scroller's message with eleven bytes to spare; `assets/scrolltext.txt`
moved to the `PANEL` file so a person could edit it (decision 54) and left 475. Bank 3 went the
other way: compiling the CPC bullet (decision 57) put 2,860 bytes of straight-line code back into
it, which is why a `-Cpc` build has 43 bytes below the tune and is the tightest bank in the build.

A RELEASE build takes bank 0 to `&BF51`: **175** free, the frame meter (`src/timing.asm`) being the
difference.

**Bank 1 is in two pieces.** The hole below the tune's B1 stream at `&B900` holds
`explosion_dirs`, the starfield's tables and the "MEGA HERO" data, with **475** to spare since the
scrolltext left; the tail past the stream holds the starfield's and the message's code with **86**.
`ASSERT P% <= MUSIC_B1_BASE` is what catches the first of those overflowing, and the `GUARD` the
second.

**Bank 3 stopped being where the music argument happens.** The panel image left it for a disc file
(decision 47), which is 3,200 bytes, and what took their place is region A of the tune - `&9100`
right through the join at `&C000` and on to `&D2FF` in HAZEL. That, plus ANDY and the two bank
tails, is the whole 349-second tune (decision 48), so the `MUSIC_AKL` comparison is now purely
about how it sounds and not at all about how much of it there is.

It also un-parked `-Cpc`: with the panel out of bank 3 and `!BOOT` out of main RAM, **all eight flag
combinations assemble**, `-Cpc` and `-Release -Cpc` for the first time, and the room it found is
what later paid for the compiled CPC bullet (decision 57). Bank 3 with the CPC artwork now ends at
`&90D5`, which is why region A starts at `&9100` and not `&9000`, and bank 2 reaches `&B9DA`, which
is why `MUSIC_B2_BASE` is a page above `MUSIC_B1_BASE`.

## HAZEL `&C000-&DFFF`

The Master's 8K of filing-system RAM, paged by ACCCON bit 3. `MUSIC` is loaded LAST and nothing
touches the disc after it.

**Default, the VGI player:**

| Range | Bytes | Contents | Free |
|---|---|---|---|
| `&C000-&D2DF` | 4,736 | region A of the tune above the join — one block with `music_lo` below `&C000`, because bank 3 and HAZEL are visible at the same time, and two streams lie across it | **32** to `&D300` |
| `&D300-&D320` | 35 | `src/data/music_map.asm`: eleven stream addresses and eleven ROMSEL bytes | — |
| `&D321-&D4D9` | 441 | `lib/vgiplayer.asm`, code only — its 96 bytes of state are at `VGI_STATE` = `&0C00` | **38** to `&D500` |
| `&D500-&DFFF` | 2,816 | the player's 11 × 256 ring workspace | 0, exact |

**`-Akl`, the Arkos replay:**

| Range | Bytes | Contents | Free |
|---|---|---|---|
| `&C000-&CB71` | 2,930 | `src/aklplayer.asm` + `src/ay2sn.asm`, tables and register file | **142** to `MUSIC_AKL_SONG` = `&CC00` |
| `&CC00-&DE84` | 4,741 | the whole 349-second tune as tracker data, untruncated | **379** to `&E000` |

`akl_init` takes the song address in A/X and a subsong in Y, so a second song is a second call - the
same shape the CPC's own `Ply_INIT` has. That matters for the win tune; see below.

## Room that is going spare

Four regions were real RAM that nothing in the game used. **The first two are spent now** - the
whole tune went into them (decisions 48 and 49) - and are left here for what the measurements say.
The other two are still candidates, and a candidate is not a promise until a jsbeeb sentinel has
survived a run of the game, the way `&04A0-&07FF` and `&0800-&0BFF` were cleared.

- **ANDY, `&8000-&8FFF`, 4K** (KC) — **spent, 2026-09-04.** Measured first, from 6502 in main RAM,
  because the obvious test does not work: BASIC is itself the ROM at `&8000`, so paging ANDY in from
  a BASIC session removes the interpreter mid-statement and the machine hangs, which it did. What
  the measurement says: **bit 7 of ROMSEL selects it, it is 4K at `&8000-&8FFF` only, the selected
  bank keeps its own `&8000` underneath, and `&9000` upwards is untouched.** The catch was always
  where the window is - it overlays the LOW 4K of whichever sideways bank is selected, and that is
  the busiest ground we have - so what went in is the one thing that suits it: a single register
  stream of the tune, read a few times a frame from the music interrupt under its own paging
  (decision 48). 3,998 of the 4,096 bytes are gone; **98 free**.
- **Page `&0C00`, 256 bytes** (KC): usable without trouble. The MOS user-font page. **96 of them are
  spent**: `VGI_STATE`, the music player's decode state (decision 49). 160 left.
- **`&0D00-&0DFF`, 256 bytes.** The paged-ROM extended-vector space, and NOT covered by KC's note
  above. Boot still uses OSFILE, and extended vectors are how a sideways ROM's service calls are
  dispatched, so this one needs proving after the load rather than assuming.
- **`&3C80-&3FFF`, 896 bytes in each bank — PROVED, and 659 of it spent.** It sits between the
  panel's last byte and `screen_start`, and neither rupture cycle ever fetches it. Layer 9e put the
  titles' second credit set there (decision 53) and the sentinel this page asked for is done: after
  a full game — three lives, the blitter writing `SPR_SAVE` every frame, the HUD, the scroll, the
  starfield — all 190 bytes read back out of jsbeeb byte for byte identical to
  `src/data/title_extra.bin`. The main-bank copy is directly addressable; the shadow copy needs the
  ACCCON X bit, the way `panel_init` reaches the panel. Both are stamped over at boot — main by the
  loading picture, shadow by `DEPK_STREAM` — so anything living there has to be built after the
  load, which is exactly what riding on the end of the `PANEL` file does. **Layer 9f then spent 469
  more on the scrolltext** (decision 54), which is what a region that is easy to reach and easy to
  grow into gets used for. **237 free in each bank**, and the build prints the figure.

## Where the room actually is

The tune took the two big pieces, Layers 9d and 9e took most of what was left in main RAM, and
Layer 9f traded bank 1's hole for two thirds of `&3C80`. What remains, largest first
(**DEV, C64 artwork**), with the `-Cpc` figure where it differs:

| Where | Bytes | `-Cpc` | Notes |
|---|---|---|---|
| `&0800` game-state block | **623** | 623 | uninitialised RAM for variables, not for anything loaded |
| bank 1's hole below `&B900` | **475** | 469 | paged, `SWRAM_SPRITES0` |
| bank 3 below the tune | **251** | **43** | paged, `SWRAM_COMPILED`; the tightest bank in a `-Cpc` build |
| `&3C80` in each bank | **237** | 237 | main copy directly addressable, shadow needs ACCCON |
| bank 2's hole below `&BA00` | **220** | **38** | paged, `SWRAM_SPRITES1` |
| page `&0C00` | **160** | 160 | main RAM, no paging |
| bank 2's tail | **106** | 106 | paged |
| ANDY | **98** | 98 | ROMSEL bit 7, overlays the low 4K of the selected bank |
| bank 1's tail | **86** | 86 | paged |
| main RAM below `SPR_SAVE` | **45** | 45 | 74 in a RELEASE build; the only place executable main-RAM code can go |
| HAZEL above the player | **38** | 38 | ACCCON bit 3 |
| region A | **32** | 32 | the tune's own slack |
| bank 0 | **9** | 9 | 175 in a RELEASE build |
| `&0D00-&0DFF` | *256* | *256* | **unproved** — paged-ROM extended vectors, see above |

Excluding the game-state block, which is variable space rather than somewhere loaded data can go,
and excluding the unproved `&0D00`, that is **1,757 bytes with the C64 artwork and 1,361 with the
CPC's** — and spread over twelve holes, none of them larger than 475.

**With the CPC artwork the tight ones are tighter**: bank 3 has 43 below the tune and bank 2's hole
has 38. Those two, and bank 0's 9 in a DEV build, are what the next layer will hit first.

`&0D00` is still unproved. Under `MUSIC_AKL` none of this is the constraint: bank 3 alone has 12,280
bytes free, because region A of the tune is not in it.

The disc is not short of anything by comparison: the packed image is 46,848 bytes of a 200K disc,
48,640 with the CPC artwork.

## The win tune: what it would cost

The CPC port has **two** songs, not one. `int_rout2` in `EG_Interrupts2.asm` re-inits the Arkos
replay from `ChangeMusic` with one of two addresses — `&29c3` for the in-game tune and `&26d7` for
the end-game one — and the second is `source_cpc/Music/WON4.SKS`, beside the `EDGEA.SKS` this port
already converts. We ship only the first.

Measured through the same chain `tools/export_music.py` uses (SongToYm → ym2sn → vgipacker), **WON4
is 3,312 frames — 66.2 seconds — and packs to 2,889 bytes of `.vgi` in eleven streams, the largest
of them 494 bytes.**

**In the default VGI build it does not fit**, and the totals understate the problem. 2,889 against
1,757 free with the C64 artwork is bad enough, but each stream has to be contiguous on its own, and
**the largest stream is 494 bytes while the largest hole in the map is bank 1's 475** — so the
biggest stream of the full tune has nowhere at all to go, whatever the totals say.
Best-fit-decreasing the eleven streams into the twelve holes above:

| Length | `.vgi` bytes | C64 artwork | CPC artwork |
|---|---|---|---|
| 66 s, the whole thing | 2,889 | does not fit | does not fit |
| 40 s | 1,647 | does not fit | does not fit |
| **30 s** | 1,169 | fits, 588 spare | fits, 192 spare |
| 25 s | 1,013 | fits, 744 spare | fits, 348 spare |
| 20 s | 836 | fits, 921 spare | fits, 525 spare |
| 15 s | 640 | fits, 1,117 spare | fits, 721 spare |
| 10 s | 491 | fits, 1,266 spare | fits, 870 spare |

Those "fits" all mean *fits if the win tune gets every hole in the machine*, which is not a decision
anybody should take lightly — 30 seconds of it would leave a `-Cpc` build 192 bytes for everything
else, ever. Twenty seconds is the first row that leaves a working margin.

**In a `-Akl` build it is nearly free.** `SongToLightweight.exe` exports WON4 as **695 bytes** of
tracker data, and bank 3 alone has 12,280 free because region A is not in it. The player is already
there, `akl_init` already takes a song address in A/X, and re-initing it with a second address is
precisely what the CPC does. The whole 66 seconds, untruncated, for 695 bytes and a `jsr`.

So the honest answer is that **the win tune is a reason to prefer `MUSIC_AKL`, not a thing to squeeze
into the VGI build.** The register-log approach buys the offline chain's whole-song analysis
(`ym2sn.py`'s periodic-noise bass and its envelope averaging, which a per-frame converter cannot
reproduce) at roughly forty times the bytes per second — 2,889 against 695 for the same 66 seconds.
That trade was affordable for one tune and is not for two. If the VGI build has to have a win tune,
it has to be about twenty seconds of one.

## See also

- `CLAUDE.md` — the standing memory table, which says what each region is *for*; this page says how
  much of it is gone
- [`docs/layer-2-display.md`](layer-2-display.md) — why the panel is at `&3000` and in both banks
- [`docs/layer-7-music.md`](layer-7-music.md) — the bank 3 / HAZEL budget and the
  four regions the tune is spread over, and what each of them cost
- [`docs/layer-9-loader.md`](layer-9-loader.md) — the boot-time shape of the map, and the ZX0 rule
  that a stream may not be overtaken by its own output
- [`docs/layer-6e-titles.md`](layer-6e-titles.md) — the titles page's own shape: the 8K display wrap,
  a ring in each bank, and why bank 0 got so tight
- [`docs/layer-7-music-arkos.md`](layer-7-music-arkos.md) — the `MUSIC_AKL` build the win-tune
  measurement above argues for, and the next steps pinned at the top of it
