# Layer 7, second pass — the Arkos replay

Built 2026-09-04, **as a switchable comparison build, not as a decision.** `-D MUSIC_AKL=1`
replaces `lib/vgiplayer.asm` and the pre-converted register log with a 6502 port of Arkos
Tracker 2's "lightweight" replay plus a runtime AY→SN76489 conversion. Everything works and
everything is measured. What is *not* settled is whether it should ship, because it does not sound
the same as the VGI build and that is a musical judgement, not a technical one.

Read [`layer-7-music.md`](layer-7-music.md) first: it is the shipping design and it ends with the
tune truncated to 203 of its 349 seconds, which is the problem this pass exists to answer.

## Why a tracker replay at all

`.vgi` is a compressed log of what the sound chip was told, one entry per register per frame. The
tune's own *source* — patterns, instruments, an order list — is far smaller than any log of its
output. The whole 349 seconds:

| | bytes |
|---|--:|
| `.vgi`, whole tune (what will not fit) | 23,514 |
| `.vgc`, whole tune | 15,942 |
| **Arkos AKL tracker data, whole tune** | **4,741** |
| Arkos AKG (a fuller format, keeps the true envelope) | 4,945 |

With the replay, the converter, their tables and state at 2,930 bytes, the whole music subsystem is
**7,671 bytes and fits inside HAZEL on its own**. `music_lo` leaves sideways bank 3 entirely and
takes 8,960 bytes of it with it — bank 3 goes from full to 9,156 bytes free. The tune is not
truncated in this build.

## The format, proved before any 6502 was written

`.SKS` is a Starkos song; Arkos Tracker 2 imports it and `tools/SongToLightweight.exe -bin -adr`
exports the AKL binary at a given address (the format holds absolute pointers, so the export address
must be the play address — `tools/export_music_akl.py` and `MUSIC_AKL_SONG` have to agree, and
`main.asm` ASSERTs the size).

`PlayerLightweight.asm` is 1,694 lines of Z80 built on self-modifying code and `ld sp,` used as a
data pointer, so the port is a rewrite, not a transcription. Rather than debug a format
misunderstanding in 6502, it was transcribed into Python first and checked against an oracle:
`SongToYm.exe` produces `edgea.ym`, a log of the AY registers **Arkos's own full player** drives,
frame by frame, for the same song.

Over all 17,446 frames the Python reference is audibly identical to that oracle: **11 mismatches,
all channel-2 period off by one.** Three conventions had to be understood before that number came
out, and each is worth knowing:

- **`SongToYm` zeroes registers that cannot be heard**: R6 when no channel has the noise open,
  R11/R12 when nothing uses the envelope. On the 3,020 and 5,730 frames where they *do* matter, the
  reference agrees exactly. A raw register diff reads as 11% wrong and is not.
- **AT2's player does not bother setting a channel's tone-disable bit when its volume is already
  zero.** 1,239 mixer differences, every one on a silent channel.
- **AKL cannot encode this song's envelope.** The format supports envelope shapes 8 and 0xa only;
  EDGEA uses **12** throughout (confirmed in the AKG export, which records the shape in a comment:
  `Soft to Hard. Envelope: 12`). The Lightweight exporter substitutes 8 — a saw-down where the tune
  wants saw-up. `ENV_BASE` in `src/aklplayer.asm` compensates. **If the tune ever changes to a
  different shape, that constant must change with it**, or use AKG, which carries the shape properly
  for 204 more bytes.

The 6502 player was then checked against the Python reference and is **byte-identical on all 17,446
frames**. One bug was found that way and would have been near-impossible to hear out: the hardware
instrument path computed the software period and never stored it.

Finally, the running game was checked against the simulation. Twelve consecutive fields of SN76489
writes captured out of jsbeeb match simulated frames **427–438 exactly, and match nowhere else in
the 17,446** — the same proof Layer 7 used for the VGI build. (Re-run after the noise fix below,
against the rebuilt disc, so it covers the shipped code and not an earlier version of it.)

## What the song uses, and what has never run

| exercised | frames |
|---|--:|
| software instruments | 37,620 |
| no-soft-no-hard | 8,988 |
| soft-to-hard (hardware envelope) | 5,730 |
| noise | 3,051 |
| effect 4 (volume + pitch up/down) | 1,287 |
| effect 3 (pitch up/down) | 100 |
| transposition / speed changes | 29 / 5 |

**Not exercised, and therefore not tested**: arpeggio tables, pitch tables, soft-and-hard
instruments, and effects 0, 1, 2, 5 and 6. They are written and they look right; that is not the
same thing, and `CLAUDE.md`'s rule applies — a path nothing has ever called is not a tested path.
`tools/export_music_akl.py --check` reports whether a tune has strayed into one.

## Cost

Simulated in py65 over all 17,446 frames, per 25 Hz game frame (two fields, budget 79,872 cycles):

| | mean | p90 | p99 | max |
|---|--:|--:|--:|--:|
| VGI looped (ships) | 3,141 | 3,508 | 4,091 | **4,964** |
| VGI unrolled | 2,301 | 2,700 | 3,335 | 4,331 |
| VGC (FX off) | 2,952 | 5,116 | 7,006 | **8,435** |
| **AKL replay alone** | 2,183 | 2,525 | 2,855 | **3,206** |
| **AKL replay + AY→SN + the SN writes** | 4,323 | 4,689 | 4,997 | **5,441** |

The replay by itself is the cheapest player measured — cheaper than VGI unrolled. The full stack is
flat like VGI's rather than spiky like VGC's, and lands 477 cycles above VGI at the worst case.
`sn_write` is the library's own routine, 32 cycles and it clobbers X, so `ay2sn` parks the nine
tone/volume bytes and emits them after the channel loop where X is free.

Measured in the game, identical brutal test to Layer 7 — boot to the titles, fire held for 5,000
fields, ship never moved, so it dies over and over with the screen full of explosions.
Microseconds; double for 2 MHz cycles:

| worst frame | VGI (ships) | AKL |
|---|--:|--:|
| `spr_restore_all` | 9,616 | 9,616 |
| `scroll_frame` | 6,280 | 7,429 |
| `spr_draw_all` | 23,073 | 23,392 |
| logic, `scroll_advance`, HUD | 4,756 | 5,090 |
| whole frame | 42,121 (105%) | **42,975 (108%)** |
| frames that missed their flip | 7 | **9** |

**+854 µs on the worst frame, and nine missed flips instead of seven** over 2,500 game frames. The
in-game figure is larger than the simulated worst-case delta of 477 cycles because the game's worst
frame is far more likely to coincide with the music's *mean* than with its single worst field, and
the mean difference is 1,182 cycles.

## The catch: the conversion, not the replay

The offline chain and a runtime converter are not doing the same job. `ym2sn.py` does **whole-song
analysis**: it picks a priority bass channel (channel A, for this song) and synthesises the tones
below the SN's 122 Hz floor using **periodic noise**, and it **averages** the hardware envelope
across each frame with a low-pass. `src/ay2sn.asm` sees one frame at a time and samples the
envelope once.

Compared against the shipping VGM frame for frame:

| | tone period exact | volume exact |
|---|--:|--:|
| non-envelope frames | 63.9% | ~25% |
| envelope frames (33% of the tune) | 3.6% | 5.9% |

That is not arithmetic error. On a channel where every AY register is constant, the shipping VGM
sweeps 440→554→659→880 Hz — information that is simply not in the frame. And every envelope in the
song runs at 58–145 Hz, **1.2 to 2.9 complete cycles per 50 Hz frame**, so the per-frame level is an
artefact of how you average; ym2sn's artefact and ours are different artefacts.

The arithmetic that *is* shared is exact and cheap. With the CPC's AY at 1 MHz and the SN at 4 MHz,
ym2sn's own formula reduces to **SN period = 2 × AY period**, with out-of-range periods halved an
octave at a time — a shift and a clamp. Volume is a 32-entry LUT built from the same curve.

So the Arkos build is not "the same tune, smaller". It is **the tune re-voiced for the SN76489**.
`tools/sn2wav.py` renders either stream to a WAV so the two can be compared by ear, which is the
only way this can be decided.

### The drums, and what was actually wrong with them

KC heard "spurious tones when the drums kick in" in the first pass and guessed the crude noise
mapping. It was not the mapping, it was a **bug**: the SN's noise-control byte was built as
`&E0 | rate`, and **bit 2 of that byte is the feedback bit, which selects white noise**. With it
clear the chip plays *periodic* noise — a short repeating LFSR pattern, i.e. a pitched buzz — so
every percussion hit came out as a note. `BUGS.md` #12. Diagnosed by diffing the noise bytes of the
two streams, not by ear:

```
shipping  &E4 &E5 &E6 &E7   WHITE      the drums
runtime   &E0 &E1 &E2       PERIODIC   every one of them wrong
```

Beside it, channel 3's volume was hard-coded to full blast. On the AY the noise is heard at the
volume of whichever channel has it open, and that channel usually has its *tone* disabled — so the
volume has to be taken **before** the tone-disable test forces the channel to attenuation 15. It is
captured into `noise_att` at that point now, loudest channel winning.

After the fix the noise byte is white on all 17,446 frames and channel 3's attenuation varies 0–6
while playing instead of being pinned at 0.

**Still a placeholder**: `ym2sn` uses noise rate 3 — the noise clocked by tone generator 3, which is
the tuned-noise trick — on 1,701 of its frames, and `src/ay2sn.asm` never emits rate 3 at all. That
is the crudeness that genuinely remains.

## Where it lives

```
HAZEL
  &C000  src/aklplayer.asm     the replay: code, period table, per-channel state
         src/ay2sn.asm         the AY -> SN conversion, its tables, akl_silence
  &CC00  src/data/music_akl.bin   the WHOLE tune as tracker data, 4,741 bytes
  &DE85  379 bytes free
```

The code ends at `&CB72`, so there are 142 bytes between it and the song — the one figure to watch
if the converter grows.  `&CC00` is in `main.asm` as `MUSIC_AKL_SONG` and in
`tools/export_music_akl.py` as the export address, and they must agree.

No ring workspace, no half in bank 3. `akl_play` needs 22 bytes of zero page (against the VGI
player's four) declared in `main.asm` under `IF MUSIC_AKL`; everything else it keeps is absolute, up
in HAZEL with the code, so the IRQ still only has one ACCCON bit to set. The reasoning for HAZEL is
decision 36 and is unchanged. `rupt_vsync` calls `akl_frame` where it called `vgm_update`, and
`akl_silence` where it called `sn_reset` — mute is **instead of** a frame of music, never as well
as, for the reason in `BUGS.md` #11. Verified: forty writes over ten muted fields, all four channels
at attenuation 15, no tone writes at all, and the tune resumes where it stopped.

`akl_frame` no longer needs bank 3 paged in, since the tune is not there any more; the bank select
in `rupt_vsync` was left alone rather than made conditional, because six cycles is not worth a
second code path in the interrupt.

## Building it

`MUSIC_AKL` is a beebasm command-line symbol beside `RELEASE` — beebasm has no `IFDEF` and refuses a
symbol defined twice, so `main.asm` cannot carry a default and **every** invocation must pass it.

```powershell
.\build.ps1            # the VGI build:  build/EDGE.SSD
.\build.ps1 -Akl       # the Arkos build: build/EDGE-AKL.SSD
```

The two discs have **different filenames, different disc titles** (`EDGE` / `EDGEAKL`) and different
`!BOOT` stamps, so neither can be mistaken for the other:

```
REM MUSIC: VGI player, tune cut to 203s
REM MUSIC_AKL: Arkos replay, whole 349s tune
```

`MUSIC_AKL` is deliberately **not** in `DEBUG_ANY`: it is legal under `RELEASE`, so it is stamped
outside the `RELEASE` test rather than with the debug flags.

## The tools

- `tools/export_music_akl.py` — SKS → AKL binary at the play address. `--check` reports what the
  song uses and warns about the untested paths.
- `tools/sn2wav.py` — renders a `.vgm` **or** a captured `.snf` frame stream to a WAV. The chip
  model is the BBC's, read out of the VGM header rather than assumed: SN76489 at 4 MHz, 15-bit LFSR,
  feedback on bits 0 and 1. Tones are rendered analytically per frame at 4× oversampling; the noise
  LFSR is stepped for real. `--start` walks the chip through the skipped frames and re-emits its
  state, so a clip from the middle of a tune starts correctly.

Checked: rendered against the AY original from `SongToWav.exe`, both the shipping stream and the
runtime stream track its melody equally well — 76.1% and 77.1% of 50 ms windows within half a
semitone, median error 0.

## What is left

- **The listening test.** Everything above says the two are different; only KC can say whether the
  difference is acceptable.
- If the answer is yes, the envelope treatment deserves a second look before it ships — averaging
  over the frame rather than sampling would cost a few hundred cycles and is closer to what the
  offline chain does.
- The noise mapping still needs finishing: rate 3, the tuned noise clocked by tone generator 3,
  is not implemented at all and the offline chain uses it on 1,701 frames.
- The untested player paths need a test tune, if the player is going to be a tool for other projects
  rather than for this one song.
