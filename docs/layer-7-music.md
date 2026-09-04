# Layer 7 — music

Done 2026-09-04. The toolchain, the player, the placement, the IRQ hookup, and all of it verified
byte-exact against the source VGM.

**It shipped truncated to 203 seconds of its 349 at first, and it does not any more.** The whole
tune is in, in four separate regions of memory - see [The whole tune, in four
places](#the-whole-tune-in-four-places-decision-48) at the end, which replaces what used to be a
list of costed options. The rest of this page is the layer as it was built; where it says the tune
is cut, that is the history.

## The chain

The C64's music is a binary blob by Sean Connolly with no source, so the BBC tune comes from the CPC
port's Arkos song (decision 5). `tools/export_music.py` runs the whole chain:

```
source_cpc/Music/EDGEA.SKS      "EDGE GRINDER MAIN CPC", 17,446 frames, 349 s
  SongToYm.exe --psg 1          a YM6 register log at 50 Hz     (nova-invite/bin)
  [truncate to N frames]        here, in the exporter
  ym2sn.py --white              AY-3-8912 -> SN76489, as a VGM  (nova-invite/bin)
  vgipacker.py                  the .vgi the player reads       (Repos/vgm-packer)
```

Truncation happens at the **YM** stage, so what ym2sn sees is a complete, consistent register log of
the first N frames and the VGM is not a doctored one. The exporter will also bisect on frame count
for a byte budget (`--budget`), which is how the 10,173 was arrived at.

`ym2sn.py` reports what the conversion costs: 349 s of AY has 15,856 low-frequency tones the 4 MHz
SN76489 cannot reach and 148 notes lost to the tuned white noise. That is the ordinary AY→SN tax and
the `--bass` software-bass option (and `lib/vgcplayer_bass.asm`) exists for it; not taken, because it
is a second IRQ's worth of CPU on a frame that has none.

## The player: VGI, not VGC (decision 35)

`lib/vgiplayer.asm`, taken **unaltered** from `Repos/vgm-player-bbc`, on KC's instruction. The
choice is about the shape of the cost, not its average:

| player | min | mean | p99 | max | code | workspace |
|---|--:|--:|--:|--:|--:|--:|
| VGC (stock) | 294 | 1,788 | 4,022 | **5,321** | 555 | 2,048 |
| **VGI looped** | 1,480 | 1,569 | 2,216 | **2,674** | 545 | 2,816 |
| VGI unrolled | 1,052 | 1,149 | 1,863 | **2,377** | 1,050 | 2,816 |

(2 MHz cycles a field, over `acid_demo`'s 9,602 frames, from `docs/vgi-player.md` in that repo.)

VGC's RLE+LZ4 is cheap on most frames and spikes when several streams refill at once. VGI drops the
RLE, keeps one small LZSS per register column and decodes **exactly one byte per stream per frame**,
so its cost cannot scale with a match length. A frame already at 90% has to budget for the worst
case, not the mean, and VGI's worst is half VGC's. The price is size — `.vgi` is about 1.4x `.vgc` —
which is the whole of the trouble below.

`VGI_UNROLL` is set to 0 (the compact looped build) in `main.asm` rather than passed on the command
line, so a bare beebasm invocation cannot get it wrong. Going to 1 buys about 300 cycles a field for
half a K of code, and there is no half a K.

## Where it lives: HAZEL, and the top of bank 3 (decision 36)

Main RAM below `&2000` had 53 bytes and every sideways bank was spoken for, so the player and its
workspace are in **HAZEL** - the Master's 8K of filing-system RAM at `&C000-&DFFF`, paged in by
ACCCON bit 3 (Y). `src/music.asm` is that image; it is `SAVE`d as `MUSIC` and loaded at boot.

Four things make HAZEL the right home rather than a desperate one:

- **It does not overlap the sideways window.** The IRQ fires with whatever bank the interrupted code
  had paged in, and the sprite engine pages 5, 6 and 7 as it draws. A player in a sideways bank
  would need the handler to save `&F4`, page, call and restore; a player in HAZEL needs one ACCCON
  bit and nothing else, which is what made it fit in main RAM at all.
- **The MOS's IRQ entry is above it.** `&FFFE` on this Master reads `&E59E` — read out of the
  machine, not recalled — which is above HAZEL's `&DFFF`, so paging HAZEL in cannot break interrupt
  dispatch. We only page it in inside our own handler anyway.
- **Its resident content is the filing system's workspace**, and the filing system is finished the
  moment the banks are loaded. `MUSIC` is therefore the **last** file loaded, and
  nothing may touch the disc afterwards.

  That has a consequence beyond the run (KC): **BREAK must clear memory**, or the machine comes back
  with the DFS workspace still wrecked. Measured before the fix - a soft BREAK out of the game gave
  `Acorn MOS` with no DFS banner, and `*CAT` returned nothing at all. `OSBYTE 200` with X = 3 is the
  first thing `main` does: bit 1 makes BREAK behave as a power-on reset, which re-initialises the
  workspace, and bit 0 disables ESCAPE with it, which is welcome anyway - it cannot abort the bank
  loads, and the ESCAPE key is read straight off the VIA matrix rather than through the MOS.
  Measured after: BREAK gives a clean `Acorn 1770 DFS`, `*.` catalogues the disc, and SHIFT+BREAK
  reloads and runs the game.
- **`&BFFF` and `&C000` are adjacent, and both are visible at once.** Sideways bank 3 and HAZEL are
  paged by different registers over different windows, so a pointer walking off the end of the bank
  lands in HAZEL and the player does not have to know the join is there. That is what lets region A
  be four times the size HAZEL alone could hold, and two of the eleven streams do lie across it.

So the two make one contiguous block - **region A** - and the shape of it now is:

```
bank 3
  &8F8E   bank 3's own code and data end here; 370 bytes of slack, ASSERTed
  &9100   music_lo.bin, region A below the join            12,288 bytes
          ends EXACTLY at &C000 - the exporter pads it to MUSIC_LO_SIZE, so
          the join holds whatever the streams add up to
HAZEL
  &C000   music_hi.bin, the rest of region A                4,736 bytes
  &D2E0   32 free - what is left of the whole tune's budget
  &D300   src/data/music_map.asm: 11 addresses, 11 ROMSEL bytes   35 bytes
          then lib/vgiplayer.asm, code only                      441 bytes
  &D4DA   38 free
  &D500   the 11 x 256 ring workspace, page aligned, reaching exactly to &DFFF
main RAM
  &0C00   VGI_STATE: the player's 96 bytes of decode state (decision 49)
```

The workspace is not in the file - it is scratch, and `vgm_init` sets up what it needs. Neither is
the state: nothing in it needs initialising, because `vgm_init` sets the first three bytes and
`vgm_stream_mount` the rest.

Three of the eleven streams are elsewhere entirely; see [The whole tune, in four
places](#the-whole-tune-in-four-places-decision-48).

OSFILE cannot write into HAZEL (the MOS would be overwriting the filing system's own workspace from
underneath itself), so `MUSIC` stages in RAM exactly as a bank does and is copied up with the Y bit
set. `load_bank`'s OSFILE half is shared by both.

> **Layer 9a changed the mechanism, not the reasoning.** Every file now ships ZX0-compressed:
> `MUSIC` stages at `DEPK_STREAM` in the shadow screen and is *unpacked* into HAZEL rather than
> block-copied from `&4000`, so `move_pages` and `load_stage` are gone and `load_stream` / `unpack_to`
> take their place. It is still the last file loaded, and nothing may touch the disc after it.
> See [`layer-9-loader.md`](layer-9-loader.md).

## The IRQ hookup

`vgm_update` is called from the **end of `rupt_vsync`**, at 50 Hz, which is where the C64 calls its
own player (`jsr $2e03` from the raster interrupt).

It selects **both** HAZEL and bank 3 - the player's code is in one and the tune's low half in the
other - and puts `&FE30` back from `&F4` afterwards, because the IRQ fires with whatever bank the
interrupted code had paged and the sprite engine is paging 5, 6 and 7 as it draws. `&F4` is reliable
for that: every bank switch in the engine writes it alongside `&FE30`.

It must be **after** the T1 restart, not before. The VSync handler reprograms T1 for the fire 1
interval, and anything ahead of that write delays the whole rupture by its own duration. Behind it,
the decode runs inside the 3,326 µs the counter is going to spend getting to fire 1 anyway. The VGI
player is bounded at about 1,340 µs a field, so it has two and a half times the room it needs and
cannot push a CRTC write late.

The keyboard was the other thing to check: `sn_write` drives System VIA port A and the addressable
latch, and so does `keydown`. They do not collide — `keydown` runs inside its own `sei`, and each
sets DDRA and its own latch line (0 for sound enable, 3 for the keyboard scan) before use rather
than assuming a previous state.

## Measured

Frame meter, `DEBUG_TIMING`, the same brutal input as Layer 6d: boot to the titles, then fire held
down for 5,000 fields (100 s, 2,500 game frames) with the ship never moved, so it dies over and over
and the screen is full of explosions. Microseconds; double for 2 MHz cycles.

| worst frame | before 6d | after 6d | with the music |
|---|---|---|---|
| `spr_restore_all` | 9,613 | 9,622 | 9,616 |
| `scroll_frame` | 6,280 | 6,280 | 6,861 |
| `spr_draw_all` | 22,481 | 22,495 | 23,293 |
| logic, `scroll_advance`, HUD | 4,226 | 4,411 | 4,475 |
| whole frame | 40,827 (102%) | 40,439 (101%) | **42,136 (105%)** |
| frames that missed their flip | 3 | 4 | **7** |

**The music costs 1,697 µs = 3,394 cycles a game frame**, which is 4.3% of the 79,872-cycle frame
and about 1,700 cycles a field - inside the 2,674 the library quotes for its worst case. It shows up
spread across all four phases because it is an interrupt: it lands wherever it lands. The bank
select that the split placement added costs nothing measurable: the same test with the tune wholly
inside HAZEL read 42,228.

Nothing else moved. The rupture is unchanged, the picture is unchanged, and the scroll is steady.

## Verified in jsbeeb

The whole chain is verified **byte-exact against the source VGM**, not by ear. (This was the
truncated build; `tools/verify_vgi.py` re-does it in one command against the split placement - see
[the bug this shape makes easy](#the-bug-this-shape-makes-easy-and-what-caught-it).)

- Twenty consecutive fields of SN76489 writes were captured from the running game and the chip state
  reconstructed from them.
- The same reconstruction was done from `build/cut.vgm`, the VGM the `.vgi` was packed from.
- The captured fields match VGM frames **201-212 exactly, and match nowhere else in the 10,173** -
  so the join at `&C000` is invisible to the player, which is the thing that needed proving.

Also measured:

- Writes arrive **39,936 cycles apart**, which is one field exactly.
- Ten writes a field, not eleven, because the noise register carries the format's "unchanged, do not
  rewrite" marker and rewriting it would restart the chip's LFSR.
- **The loop works.** Run past 10,173 fields and the chip state matches VGM frame 470 - the player
  re-mounted the streams at frame 0 and carried on.

## The whole tune, in four places (decision 48)

**EDGEA is 349 seconds and packs to 23,514 bytes of `.vgi`. The largest contiguous hole this machine
has is the 17K that bank 3's tail and the bottom of HAZEL make between them.** So for a day it
shipped the first 203 seconds, looped.

The way out is in the format, and it was written down above without being taken seriously enough:
**a `.vgi` is not one blob. It is eleven independent streams**, one per SN76489 register, and
`vgm_decode_frame` reads exactly one byte from each per frame through its own pointer. Each STREAM
has to be contiguous. The TUNE does not. A machine whose free RAM is 17K here, 4K there and 1.75K
twice over can hold a tune that fits in none of them.

### The four regions

| | | ROMSEL | bytes | free |
|---|---|---|--:|--:|
| A | `&9100-&D2FF`, bank 3's tail running on into HAZEL | 7 | 16,896 | 32 |
| ANDY | `&8000-&8FFF`, the Master's own 4K | `&87` | 4,096 | 98 |
| B1 | `&B900-&BFFF`, the tail of sideways bank 1 | 5 | 1,792 | 519 |
| B2 | `&BA00-&BFFF`, the tail of sideways bank 2 | 6 | 1,536 | 185 |

Region A is the same trick Layer 7 already used and is why the bank-3 half exists at all: bank 3 and
HAZEL are paged by different registers over different windows, are visible at the same time, and are
adjacent in the address map, so a stream may lie across `&C000` and the player never learns the join
is there. Two of them do.

**ANDY had to be measured, not recalled.** It is the Master's 4K of private RAM, and the obvious
test does not work - BASIC is itself the ROM at `&8000`, so paging ANDY in from a BASIC session
removes the interpreter mid-statement and the machine hangs. From 6502 in main RAM, in jsbeeb:

```
&FE30 = 4     write &AA to &8000, &BB to &9000
&FE30 = &84   write &55 to &8000, &CC to &9000
&FE30 = &84   &8000 reads &55    &9000 reads &CC
&FE30 = 4     &8000 reads &AA    &9000 reads &CC
```

So: **bit 7 of ROMSEL selects it, it is 4K at `&8000-&8FFF` only, the selected bank keeps its own
`&8000` underneath it, and `&9000` upwards is unaffected.** That window is the busiest ground in the
game - bank 0's `char_data` starts at `&8000` and the scroll reads it every frame - so ANDY can only
hold something read in one place under its own paging. A music stream fetched a few times a frame
from an interrupt is exactly that.

B1 and B2 are not the same page as each other because the CPC artwork's sprite bank 2 reaches
`&B941`; keeping B2 a page higher is what lets `-Cpc` assemble.

### Where the room came from

Three things, none of them the music:

- **The panel image left bank 3** (decision 47): 3,200 bytes of boot-time data that was sitting on
  the one range the tune needs. It is a disc file now, unpacked straight into each bank's `&3000`.
- **`!BOOT` left the code image's address space** (decision 49): 200 bytes of text nothing executes,
  assembled at `&2400` instead. Main RAM went from 111 bytes free to 185.
- **The player's state left HAZEL** for `&0C00`, the MOS user-font page: 96 bytes back for the tune.

### What changed in the player

`lib/vgiplayer.asm` was taken unaltered from `Repos/vgm-player-bbc` and is not any more. The changes
are behind `-D VGI_SPLIT`, and `VGI_SPLIT=0` is byte-identical to what was there:

- `fetchbyte` writes the stream's ROMSEL byte to `&FE30` before the read. **Eight cycles, and only
  on the path that touches the compressed data at all** - a new token plus its literal bytes, which
  is a handful of reads a frame across all eleven streams, not eleven. `rupt_vsync` already put
  `&FE30` back from `&F4` afterwards, so nothing else had to change.
- `vgm_stream_mount` copies eleven addresses and eleven ROMSEL bytes out of `vgi_map_*` instead of
  biasing eleven file-relative offsets by one base. There is no `.vgi` header in the build any more;
  `VGI_FRAMES` carries the frame count.
- The per-stream state moves to `VGI_STATE`, 96 bytes the caller provides.

`tools/export_music.py` does the placement: it packs the whole tune, cuts the `.vgi` into its eleven
streams, best-fit-decreasing them into the regions, writes one binary per region and generates
`src/data/music_map.asm` - which ASSERTs `main.asm`'s region constants against the ones it placed
with. **Best-fit rather than first-fit for a reason**: seven of the eleven streams are bigger than
either sideways-bank tail and no two of those seven fit in ANDY together, so the biggest stream must
go to ANDY and region A must take the other six. Anything else does not fit at all. If it ever stops
fitting the exporter says so, with the free space per region.

### The bug this shape makes easy, and what caught it

The first build of it played, and sounded like music, and was wrong. `place()` hands addresses out
biggest-stream-first; `emit()` concatenated each region's streams **in stream-index order**. Every
stream but the first in each region was therefore at the wrong address - a permutation, not a
corruption, so it decoded happily for eight thousand frames before a stream ran off the end of what
it had been given.

Nothing about "it plays" would ever have caught that, and neither would listening to it. What caught
it was `tools/verify_vgi.py`: it rebuilds the reference write stream **from the region binaries the
build actually INCBINs and the map it actually assembles**, so the placement itself is under test,
and then searches for a jsbeeb SN76489 capture inside it. Verified, on the shipping build:

| capture | matches |
|---|---|
| the first fields after boot | reference write 2,981, **and nowhere else** |
| deep inside the tune, past where the truncated version ended | write 91,051 |
| across the loop point, 8 fields of the tune's end and 2 of its restart | write 177,190 |

And the eleven decode pointers read out of `&0C00` after 412 frames of the second pass match the
reference decoder's exactly, all eleven, including the two that had crossed `&C000`.

### What it cost

The frame meter, `DEBUG_TIMING`, the same test as the table above - boot to the titles, fire held
for 5,000 fields, the ship never moved:

| worst frame | Layer 7, tune cut | whole tune, four regions |
|---|--:|--:|
| `spr_restore_all` | 9,616 | 9,753 |
| `scroll_frame` | 6,861 | 5,447 |
| `spr_draw_all` | 23,293 | 23,916 |
| logic, `scroll_advance`, HUD | 4,475 | 4,506 |
| whole frame | 42,136 (105%) | **42,083 (105%)** |
| frames that missed their flip | 7 | **7** |

Microseconds; double for 2 MHz cycles. The paging is not readable in the noise, which is what eight
cycles on a path taken a handful of times a field ought to look like.

### And it fixed `-Cpc`

Plain `-Cpc` had never assembled: the CPC artwork pushed bank 3 twelve bytes past `music_lo`'s base.
With the panel gone from bank 3 and `!BOOT` out of main RAM, **all six flag combinations build** -
`-Cpc` and `-Release -Cpc` for the first time, and with the whole tune rather than none of it.

## Q mutes it (decision 39)

Q toggles the tune on and off. `IKN_q = 16`, **measured** with OSBYTE 121 in a BASIC session
holding the key, never recalled — the same rule every other key number in this port follows. Q was
free: the C64 aborts a paused game on Q and we abort on ESCAPE (decision 32).

**The key is read in the VSync handler**, not in the main loop, because it has to work wherever the
foreground happens to be — playing, held inside `pause_check`'s blocking loop, sitting on the
titles, or watching the finale. The handler runs in all of them; nothing else does. Calling
`keydown` from an interrupt is safe the one way round that matters: the foreground's `keydown`
wraps its latch sequence in `php`/`sei`/`plp`, so the IRQ can never land inside one, and between
the five calls `read_joystick` makes the latch is already handed back.

Edge-triggered on the **press**, so holding Q does not toggle every field. `music_mute` and
`mute_was` are two bytes in the code image next to the handler rather than in the `&0800` state
block, so a new game does not silently unmute.

**Muted, `sn_reset` runs INSTEAD OF `vgm_update`, never as well as.** `sn_reset` is the player's
own four volume-off writes, in HAZEL, which is still paged in at that point. The tune stops where
it is and resumes there.

It was written the other way round first — let the player run and silence the chip after it, so the
tune would play on underneath and unmuting would be correct on the very next field. **That
crackled**, on jsbeeb and on b2 (KC). The SN76489 write capture said exactly why:

```
53919520: 0xd9 CH2 vol atten=9      <- vgm_decode_frame, the tune's real volume
53919766: 0xdf CH2 vol atten=15     <- sn_reset, 246 cycles later
```

246 cycles is 123 µs of channel 2 at attenuation 9, **fifty times a second** — a 50 Hz buzz made of
the tune's own leading edges. There is no ordering that closes that window while the player is
still writing volumes, so the player does not run. `BUGS.md` #11.

Verified in jsbeeb by capturing every SN76489 write across ten muted fields: forty writes, all four
channels at attenuation 15, no tone writes at all. And by reading the chip state: volumes back the
field after the second press. Checked on the titles, in play, and while paused with `frame_count`
frozen and `field_count` still climbing.

## Left over

- **No sound effects**, and that is faithful: the C64 has none. `irq_init` calls the music init and
  `rout1` calls `$2e03`, and that is the whole of its audio.
- The completion tune, `source_cpc/Music/WON4.SKS`, is not converted. Decision was EDGEA only,
  everywhere, as the C64 has it.
- Software bass (`--bass` and `lib/vgcplayer_bass.asm`) would recover the notes below 122 Hz that
  the 4 MHz SN76489 cannot reach. It is a second timer IRQ synthesising squarewaves, and there is no
  frame for it.
