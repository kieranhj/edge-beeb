# Layer 7 — music

Done 2026-09-04, **with the tune truncated to 203 seconds of its 349**. Everything works: the
toolchain, the player, the placement, the IRQ hookup, and it is verified byte-exact against the
source VGM. What is not done is fitting the last 2m26s, and that is a memory problem, not a music
one. The options are costed at the end and want KC's decision.

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
  moment the banks are loaded. `MUSIC` is therefore the **last** of the five files loaded, and
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
  lands in HAZEL and the player does not have to know the join is there. That is what lets the tune
  be nearly three times the size HAZEL alone could hold.

So the tune is **one contiguous block spanning the two**:

```
bank 3
  &9D00   music_lo.bin, the low half of the tune              8,960 bytes
          ends EXACTLY at &C000 - the exporter pads it to MUSIC_LO_SIZE, so
          the join holds whatever the tune's length
HAZEL
  &C000   music_hi.bin, the rest                              4,602 bytes
  &D1FA   6 free before the player
  &D200   lib/vgiplayer.asm: code and its resident decode state  545 bytes
  &D421   223 free
  &D500   the 11 x 256 ring workspace, page aligned, reaching exactly to &DFFF
```

The workspace is not in the file - it is scratch, and `vgm_init` sets up what it needs. Bank 3's own
code and data end at `&9C3D`, so there are 195 bytes of slack below `music_lo`; `bank3.asm` ASSERTs
it, and if a later layer wants that room `MUSIC_LO_SIZE` comes down and the tune with it.

OSFILE cannot write into HAZEL (the MOS would be overwriting the filing system's own workspace from
underneath itself), so `MUSIC` stages through `&4000` exactly as a bank does and `move_pages` copies
it up with the Y bit set. `load_bank`'s OSFILE half is now `load_stage`, shared by both.

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

The whole chain is verified **byte-exact against the source VGM**, not by ear:

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

## What is left: the tune does not fit

**EDGEA is 349 seconds and packs to 23,514 bytes of `.vgi`. There are 13,562 between the top of bank
3 and the player in HAZEL.** So what ships is the first 203 seconds, looped by the player
(`vgm_init` with C=1) - 58% of it.

The alternatives, costed:

| | size | cost |
|---|--:|---|
| VGI, whole tune | 23,514 | needs ~19K more RAM than exists in one place |
| VGI, no envelope simulation (`ym2sn -n`) | 22,058 | 1.5K, and 32% of frames lose their envelope |
| VGC | 15,942 | the spiky player: worst frame 5,321 cycles a field, ~13,000 a game frame |
| VGC + huffman | 13,500 | slower again, and 13,500 still does not fit anywhere contiguous |

And the space, if it were all collected:

| | bytes |
|---|--:|
| bank 3 and HAZEL, as used now | 13,562 |
| the panel image, if it moved to a boot-time load instead of living in bank 3 | 3,200 |
| ANDY (`&8000-&8FFF`, ROMSEL bit 7) | 4,096 |
| sideways banks 0, 1 and 2 scraps | 5,684 |

**The shape of the answer.** `.vgi` is not one blob: it is **eleven independent streams**, one per
SN76489 register, and the packer reports their sizes separately (2,283 2,998 2,218 2,776 3,195 3,402
596 1,173 1,351 1,273 2,221 for the whole tune). The player reads one byte from each per frame
through its own pointer. So whole streams can be **placed in different regions** and the total does
not have to be contiguous — which is exactly what a machine with 4,831 here and 9,182 there is good
for. Two observations make it cheap:

- **Moving the panel image out of bank 3** - it is read once, at boot, into `&3000` in each shadow
  bank, and never again - would push `MUSIC_LO_BASE` down 3,200 bytes and needs no format work at
  all. That is 16,762 of 23,514: **71%, up from 58%**, for an afternoon.
- Streams in a *second* sideways bank, or in ANDY, would need a bank select before the byte fetch:
  four of the eleven streams are under 1,400 bytes and would fit the scraps in banks 1 and 2. About
  ten cycles a stream, five switches a frame. With those and ANDY the whole tune fits.

The work is a table of eleven base addresses (and, if the scraps are used, eleven region bytes) in
place of `vgm_stream_mount`'s "offset + one base" arithmetic, plus a packer-side or build-side
relocation. It is a change to a library taken unaltered, and it is a numbered decision, so it waits
for KC.

The cheap alternative is to **cut the tune**, musically rather than by frame count — 349 seconds is
longer than anybody will play — which is a decision only its author can take well.

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

**Muting silences the chip and lets the tune play on underneath**, rather than stopping the player:
`vgm_update` still runs, and `sn_reset` — the player's own four volume-off writes, in HAZEL, which
is still paged in at that point — follows it. `vgm_decode_frame` writes all eleven registers every
frame, so unmuting is correct on the very next field and the tune has not lost its place.

Verified in jsbeeb by reading the SN76489 state: all four channels at attenuation 15 within a few
fields of the press, tone registers still advancing underneath, and volumes back on the field after
the second press. Checked on the titles, in play, and while paused with `frame_count` frozen and
`field_count` still climbing.

## Left over

- **No sound effects**, and that is faithful: the C64 has none. `irq_init` calls the music init and
  `rout1` calls `$2e03`, and that is the whole of its audio.
- The completion tune, `source_cpc/Music/WON4.SKS`, is not converted. Decision was EDGEA only,
  everywhere, as the C64 has it.
- Software bass (`--bass` and `lib/vgcplayer_bass.asm`) would recover the notes below 122 Hz that
  the 4 MHz SN76489 cannot reach. It is a second timer IRQ synthesising squarewaves, and there is no
  frame for it.
