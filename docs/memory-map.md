# The memory map, and what is left in it

Every figure here is **measured from the build**, not from the source by eye: beebasm's `PRINT`
statements write the high-water marks into the assembly listing, and these tables are what the
listings said after Layer 6e (2026-09-04, decisions 44-46). They go stale the moment
anything grows, so **take live numbers from the listing rather than trusting this page**:

```powershell
.\build.ps1                                     # and -Release, -Akl, -Akl -Cpc
Select-String -Path build\EDGE.lst -Pattern "HIGH WATERMARK|^FREE|BANK 3 code"
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
| `&0800-&091B` | 284 | the game state block — the C64's `$0340`. Declared after the SAVEs, so it is not in the image | **740** to `GAME_STATE_TOP` = `&0C00` |
| `&0C00-&0CFF` | 256 | MOS user-font page. **Free** (KC, 2026-09-04) | 256 |
| `&0D00-&0DFF` | 256 | paged-ROM extended vectors. Not claimed, not tested | 256, unverified — see below |
| `&0E00-&2191` | 5,522 | code, then the initialised tables, then `src/zx0depack.asm`. `GUARD CODE_TOP` = `LOAD_STREAM` = `&2200` | **111**. A RELEASE build ends at `&213D`: **195** |
| `&2000-&2FFF` | 4,096 | `SPR_SAVE`: 8 slots × 256 B × 2 banks, exactly | 0 by construction |
| `&3000-&3C7F` × 2 | 3,200 each | the status panel, in BOTH shadow banks | 0 |
| `&3C80-&3FFF` × 2 | 896 each | **nobody's**: above the panel, below the play buffer, fetched by neither rupture cycle | 896 main + 896 shadow, unclaimed — see below |
| `&4000-&7FFF` × 2 | 16,384 each | the play buffers, main and shadow, hardware-wrapped at 16K | 0 |
| `&E000-&FFFF` | 8,192 | MOS ROM. `&FFFE` on this Master reads `&E59E` — measured — so paging HAZEL in cannot break IRQ dispatch | — |

**Bank 0's 18 bytes are now the tightest thing in the build**, and main RAM's 111 the next: Layer 6e's `title_page` has to be in bank 0, because bank 0 code may call into main RAM and be returned to and bank 1 code may not. A RELEASE build has 184 and 195, the frame meter being the difference.

**The code's own ceiling.** The depacker already sits above
`SPR_SAVE`'s base (`&1F05-&2147`) to buy some of them, which is safe only because it is dead before
anything reads there.

**At boot the map is a different shape.** `&2200` upwards is the loading screen's ZX0 stream
(`LOAD_STREAM`), `&3000-&7FFF` in MAIN is the loading picture itself, and `&3000-&7FFF` in SHADOW is
`DEPK_STREAM`, where the four bank streams and the music stage before they are unpacked. None of
that survives into the game.

## Sideways RAM — the Master's four banks, slots 4-7

| Slot | Bank | Contents | High water | Free | `-Akl` | `-Akl -Cpc` |
|---|---|---|---|---|---|---|
| — | ANDY | the Master's own 4K, `&8000-&8FFF`, ROMSEL bit 7. **Unused by this port** — see below, the window overlays the low 4K of the selected bank | — | **4,096** | 4,096 | 4,096 |
| 4 | `BANK0` | `char_data`, `tile_data`, `map_data`, `col_decode`, `wave_data`, `anim_decode`, and the run-once and out-of-room code | `&BFEE` | **18** | 18 | 18 |
| 5 | `BANK1` | sprite data, pixel shift 0, then the titles' zoom scroller (Layer 6e) | `&B80A` | **2,038** | 2,038 | 2,032 |
| 6 | `BANK2` | the same, shift 1 | `&B88B` | **1,909** | 1,909 | 1,727 |
| 7 | `BANK3` | compiled sprite bodies, the titles' font, credits and plotter, the panel image, the HUD glyphs and `status_decode`; then `music_lo` | `&9C3D`, then `music_lo` fills `&9D00-&BFFF` | **195**, all below `music_lo`, and **0** above it | **9,156** | **8,948** |

A RELEASE build takes bank 0 to `&BF48`: **184** free, the frame meter (`src/timing.asm`) being the
difference.

**Bank 3 is where the music decision is really argued.** With the VGI player `music_lo` takes
`&9D00-&BFFF` — 8,960 bytes, and the tune is still cut to 203 of its 349 seconds (decision 37) —
leaving a 195-byte hole below it. Under `MUSIC_AKL` that block is gone entirely and 9,156 bytes come
free, with the whole tune in HAZEL. It is also why **plain `-Cpc` does not assemble**: the CPC art
pushes bank 3 to `&9D0C`, twelve bytes past `music_lo`'s base. Parked, 2026-09-04, pending the
artwork decision; `-Akl -Cpc` builds because it has no `music_lo` to collide with.

## HAZEL `&C000-&DFFF`

The Master's 8K of filing-system RAM, paged by ACCCON bit 3. `MUSIC` is loaded LAST and nothing
touches the disc after it.

**Default, the VGI player:**

| Range | Bytes | Contents | Free |
|---|---|---|---|
| `&C000-&D1F9` | 4,602 | the tune's high half — one block with `music_lo` below `&C000`, because bank 3 and HAZEL are visible at the same time | **6** to `&D200` |
| `&D200-&D420` | 545 | `lib/vgiplayer.asm` | **223** to `&D500` |
| `&D500-&DFFF` | 2,816 | the player's 11 × 256 ring workspace | 0, exact |

**`-Akl`, the Arkos replay:**

| Range | Bytes | Contents | Free |
|---|---|---|---|
| `&C000-&CB71` | 2,930 | `src/aklplayer.asm` + `src/ay2sn.asm`, tables and register file | **142** to `&CC00` |
| `&CC00-&DE84` | 4,741 | the whole 349-second tune as tracker data, untruncated | **379** to `&E000` |

## Room that is going spare

Four regions are real RAM that nothing in the game uses. The first two are KC's (2026-09-04); the
rest are candidates, and a candidate is not a promise until a jsbeeb sentinel has survived a run of
the game, the way `&04A0-&07FF` and `&0800-&0BFF` were cleared.

- **ANDY, `&8000-&8FFF`, 4K** (KC). The Master's own 4K of private RAM, paged in by **bit 7 of
  ROMSEL** (`&FE30`, and the `&F4` copy with it) rather than by ACCCON. Untouched by this port so
  far. **The catch is where its window is**: ANDY overlays the LOW 4K of whichever sideways bank is
  selected, and that is the busiest ground we have — bank 0's `char_data` starts at `&8000` and the
  scroll reads it every frame, and banks 1 and 2 start their sprite data there too. So ANDY is not
  4K beside the banks, it is 4K *instead of* the first 4K of one of them, and every routine that
  touches it must put the bank back exactly as `sprite.asm` already does for slots 5, 6 and 7.
  Best suited to something read in one place under its own paging, not to anything the inner loops
  walk. **Not yet measured here**, and the obvious test does not work: BASIC is itself the ROM at
  `&8000`, so paging ANDY in from a BASIC session removes the interpreter mid-statement and the
  machine hangs — which it did. The test has to be 6502 running from main RAM.
- **Page `&0C00`, 256 bytes** (KC): usable without trouble. The MOS user-font page.
- **`&0D00-&0DFF`, 256 bytes.** The paged-ROM extended-vector space, and NOT covered by KC's note
  above. Boot still uses OSFILE, and extended vectors are how a sideways ROM's service calls are
  dispatched, so this one needs proving after the load rather than assuming.
- **`&3C80-&3FFF`, 896 bytes in each of the two shadow banks.** It sits between the panel's last
  byte and `screen_start`, and neither rupture cycle ever fetches it. The main-bank copy is
  directly addressable; the shadow copy needs the ACCCON X bit, the way `panel_init` reaches the
  panel. Both are stamped over at boot — main by the loading picture, shadow by `DEPK_STREAM` — so
  anything living there has to be built after the load.

## Where the room actually is

ANDY's 4K is the largest single piece, with the paging caveat above; then 9,156 bytes in bank 3, but
only if the Arkos build wins the comparison; 2,038 in bank 1 and 1,909 in bank 2; 740 in the `&0800`
block; 256 at `&0C00`; 111 in main RAM code and **18 in bank 0**. Everything else is inside 250 bytes
of its ceiling, and `&0D00` and the 1,792 bytes at `&3C80` are worth another 2K if they survive a
sentinel.

The disc is not short of anything by comparison: the packed image is 37,632 bytes of a 200K disc.

## See also

- `CLAUDE.md` — the standing memory table, which says what each region is *for*; this page says how
  much of it is gone
- [`docs/layer-2-display.md`](layer-2-display.md) — why the panel is at `&3000` and in both banks
- [`docs/layer-7-music.md`](layer-7-music.md) — the bank 3 / HAZEL budget and the ways out of the
  truncated tune, costed
- [`docs/layer-9-loader.md`](layer-9-loader.md) — the boot-time shape of the map, and the ZX0 rule
  that a stream may not be overtaken by its own output
- [`docs/layer-6e-titles.md`](layer-6e-titles.md) — the titles page's own shape: the 8K display wrap,
  a ring in each bank, and why bank 0 got so tight
