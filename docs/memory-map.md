# The memory map, and what is left in it

Every figure here is **measured from the build**, not from the source by eye: beebasm's `PRINT`
statements write the high-water marks into the assembly listing, and these tables are what the
listings said after the whole tune went in (2026-09-04, decisions 47-49) and the "MEGA HERO"
message after it. They go stale the moment
anything grows, so **take live numbers from the listing rather than trusting this page**:

```powershell
.\build.ps1                                     # and -Release, -Akl, -Akl -Cpc
Select-String -Path build\EDGE.lst -Pattern "HIGH WATERMARK|^FREE|BANK 3|REGION A"
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
| `&0800-&0985` | 390 | the game state block — the C64's `$0340`. Declared after the SAVEs, so it is not in the image | **634** to `GAME_STATE_TOP` = `&0C00`. A RELEASE build ends 12 lower - the frame meter is the difference. The last two things in it are the starfield's 92 bytes (decisions 50 and 51) - 40 for the stars and 52 for where each bank last plotted them - and the "MEGA HERO" message's 15, which are up here because bank 1, where its code is, had tens of bytes left and this has hundreds |
| `&0C00-&0C5F` | 96 | **`VGI_STATE`**: the VGI player's decode state, eleven streams' worth (decision 49). Not in the image - nothing in it needs initialising | 160 to `&0D00` |
| `&0D00-&0DFF` | 256 | paged-ROM extended vectors. Not claimed, not tested | 256, unverified — see below |
| `&0E00-&21F7` | 5,624 | code to `&1F67`, then the boot-only data, **the loader**, **the memorial's fade** and `src/zx0depack.asm`. `GUARD CODE_TOP` = `LOAD_STREAM` = `&2400` | **521** to `LOAD_STREAM`, of which **153** are usable by anything read in play. Layer 9d moved the loader above `code_end` and `LOAD_STREAM` from `&2200` to `&2400` (decision 52); `!BOOT` left in Layer 9 (decision 49) |
| `&2000-&2FFF` | 4,096 | `SPR_SAVE`: 8 slots × 256 B × 2 banks, exactly. At assembly time `&2600` is where `!BOOT` is built, which costs the run nothing: it is a disc file, never loaded here | 0 by construction |
| `&3000-&3C7F` × 2 | 3,200 each | the status panel, in BOTH shadow banks | 0 |
| `&3C80-&3FFF` × 2 | 896 each | **nobody's**: above the panel, below the play buffer, fetched by neither rupture cycle | 896 main + 896 shadow, unclaimed — see below |
| `&4000-&7FFF` × 2 | 16,384 each | the play buffers, main and shadow, hardware-wrapped at 16K | 0 |
| `&E000-&FFFF` | 8,192 | MOS ROM. `&FFFE` on this Master reads `&E59E` — measured — so paging HAZEL in cannot break IRQ dispatch | — |

**Region A's 32 bytes are the tightest thing in the build now** - the whole tune is 23,486 bytes of
stream in 24,320 bytes of region - and the 11 left in bank 1's hole and bank 0's 16 the next: Layer 6e's `title_page` has to be in
bank 0, because bank 0 code may call into main RAM and be returned to and bank 1 code may not. A
RELEASE build has 191 in bank 0, the frame meter being the difference. Main RAM is no longer the
problem it was: moving `!BOOT` out of the code image's address space (decision 49) took it from 111
free to 185, and the starfield took it back to 167.

**THE CEILING THAT MATTERS IS `SPR_SAVE` = `&2000`, NOT `LOAD_STREAM`.** `&2000-&2FFF` is the
blitter's saved-background area, rewritten every frame from the first sprite onwards. Boot code and
boot data may sit in it and do - `src/zx0depack.asm`, the OSFILE block, the disc filenames, and
`!BOOT` assembled at `&2400` - because they are dead before anything reads there. **Anything read or
executed in play may not**, and for two layers nothing was checking: `explosion_dirs` drifted to
`&2024` and the player's explosion pieces stopped flying, because his own saved background was
landing on their movement vectors (`BUGS.md` #13). `main.asm` now carries
`ASSERT code_end <= SPR_SAVE` and the listing prints `CODE CEILING` beside it.

**`code_end` is `&1F67`: 153 bytes under it in a DEV build.** That, and not the 521 the FREE line
prints, is what main RAM has left for anything permanent. **Layer 9d is where the boot loader
moved out**, which is what this page said the next thing to want main-RAM code would have to do:
`load_stream`, `unpack_to`, `panel_init`, `load_bank`, `unpack_andy` and `load_hazel` are all dead
before the first sprite is drawn and are above `code_end` now, with `!BOOT` and the depacker. That
took the ceiling from 7 free to 153. `LOAD_STREAM` went from `&2200` to `&2400` with it, for the
image as a whole; what that costs is the loading screen's own headroom - `LOADSC2`'s stream has
252 bytes to `&3000` rather than 764, and `tools/make_disc.py` refuses an image that overruns it.

**At boot the map is a different shape.** `&2400` upwards is the loading screen's ZX0 stream
(`LOAD_STREAM`), `&3000-&7FFF` in MAIN is the loading picture itself, and `&3000-&7FFF` in SHADOW is
`DEPK_STREAM`, where the four bank streams and the music stage before they are unpacked. None of
that survives into the game.

## Sideways RAM — the Master's four banks, slots 4-7

| Slot | Bank | Contents | High water | Free | `-Akl` | `-Akl -Cpc` |
|---|---|---|---|---|---|---|
| — | ANDY | the Master's own 4K, `&8000-&8FFF`, ROMSEL bit 7 — **measured 2026-09-04**, see below. One of the tune's eleven register streams lives here (decision 48) | `&8F9E` | **98** | 4,096 | 4,096 |
| 4 | `BANK0` | `char_data`, `tile_data`, `map_data`, `col_decode`, `wave_data`, `anim_decode`, and the run-once and out-of-room code | `&BFF0` | **16** | 16 | 16 |
| 5 | `BANK1` | sprite data, pixel shift 0, the titles' zoom scroller (Layer 6e), then `explosion_dirs`, the starfield's tables and the "MEGA HERO" message's data and `mega_one` (Layer 9c) in what used to be dead space, then a tune stream at `MUSIC_B1_BASE` = `&B900`, then the starfield's and the message's code | `&BFAA` | **86**, and **11** left in the hole below `&B900` | 1,370 | 1,364 |
| 6 | `BANK2` | the same, shift 1, then a tune stream at `MUSIC_B2_BASE` = `&BA00` | `&BF47` | **185** | 1,909 | 1,727 |
| 7 | `BANK3` | compiled sprite bodies, the titles' font, credits and plotter, the memorial's message and `mem_page` (Layer 9d), the HUD glyphs and `status_decode`; then region A of the tune | `&9003`, then `music_lo` fills `&9100-&BFFF` | **253**, all below the tune, and **0** above it — **45** with the CPC artwork, which is the tightest this bank has been | **12,399** | **12,191** |

A RELEASE build takes bank 0 to `&BF4A`: **182** free, the frame meter (`src/timing.asm`) being the
difference.

**Bank 1 is in two pieces and both are nearly full.** The 171 bytes between the starfield's tables
and the tune's B1 stream at `&B900` hold `explosion_dirs`, the starfield's tables and the message's
data with **11** to spare; the tail past the stream holds the starfield's and the message's code
with **86**. `ASSERT P% <= MUSIC_B1_BASE` is what catches the first of those overflowing, and the
`GUARD` the second.

**Bank 3 stopped being where the music argument happens.** The panel image left it for a disc file
(decision 47), which is 3,200 bytes, and what took their place is region A of the tune - `&9100`
right through the join at `&C000` and on to `&D2FF` in HAZEL. That, plus ANDY and the two bank
tails, is the whole 349-second tune (decision 48), so the `MUSIC_AKL` comparison is now purely
about how it sounds and not at all about how much of it there is.

It also un-parked `-Cpc`: with the panel out of bank 3 and `!BOOT` out of main RAM, **all six flag
combinations assemble**, `-Cpc` and `-Release -Cpc` for the first time. Bank 3 with the CPC artwork
ends at `&9061`, which is why region A starts at `&9100` and not `&9000`, and bank 2 reaches `&B941`,
which is why `MUSIC_B2_BASE` is a page above `MUSIC_B1_BASE`.

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
| `&C000-&CB71` | 2,930 | `src/aklplayer.asm` + `src/ay2sn.asm`, tables and register file | **142** to `&CC00` |
| `&CC00-&DE84` | 4,741 | the whole 349-second tune as tracker data, untruncated | **379** to `&E000` |

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
- **`&3C80-&3FFF`, 896 bytes in each of the two shadow banks.** It sits between the panel's last
  byte and `screen_start`, and neither rupture cycle ever fetches it. The main-bank copy is
  directly addressable; the shadow copy needs the ACCCON X bit, the way `panel_init` reaches the
  panel. Both are stamped over at boot — main by the loading picture, shadow by `DEPK_STREAM` — so
  anything living there has to be built after the load.

## Where the room actually is

The tune took the two big pieces. What is left, largest first: **634** in the `&0800` block, **370**
in bank 3 below the tune, **185** in bank 2, **167** in main RAM code, **160**
at `&0C00`, **98** in ANDY, **86** in bank 1's tail, **38** above the music player in HAZEL, **32**
in region A, **16** in bank 0 and **11** in bank 1's hole. Everything is inside a few hundred bytes of its ceiling now.

`&0D00` and the 1,792 bytes at `&3C80` are worth another 2K if they survive a sentinel, and they are
the obvious next place to look; the 896 in the MAIN bank at `&3C80` is directly addressable and
would take another music stream without any paging at all, if the exporter's regions ever need a
fifth.

The disc is not short of anything by comparison: the packed image is 45,824 bytes of a 200K disc.

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
