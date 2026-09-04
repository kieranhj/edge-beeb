# The Arkos player harness

Everything needed to re-verify and re-measure `src/aklplayer.asm` and `src/ay2sn.asm` — the
`MUSIC_AKL` music build. Kept because the player is unfinished (see
[`../../docs/layer-7-music-arkos.md`](../../docs/layer-7-music-arkos.md), "What is left") and
whoever picks it up needs to be able to prove they have not broken it.

```
python tools/akl/verify_akl.py                          # from the PROJECT ROOT
python tools/akl/verify_akl.py --frames 3000            # a quick pass
python tools/akl/verify_akl.py --snf build/runtime.snf  # and capture for listening
python tools/sn2wav.py build/runtime.snf -o runtime.wav
```

Needs beebasm, `pip install py65 numpy`, and Arkos Tracker 2 plus `SongToYm.exe` (from
`Repos/nova-invite/bin`) for the oracle. Without the oracle it still checks the 6502 against the
reference and reports the cost, and says which check it skipped.

## What it proves, and against what

Nothing here is checked against itself. The chain is:

| | checked against | what it catches |
|---|---|---|
| `akl_reference.py` | `edgea.ym` — the AY register log **Arkos's own full player** produces from the same song, via `SongToYm.exe` | a misunderstanding of the AKL format |
| `src/aklplayer.asm` | `akl_reference.py`, frame for frame | a 6502 bug |
| the running game | the simulation, by capturing SN76489 writes in jsbeeb and finding where they match | a wiring, paging or IRQ bug |

`verify_akl.py` does the first two. The third is manual and is the check to run after touching
anything in `src/music.asm`, `src/rupture.asm` or the HAZEL layout: capture ten or twenty
consecutive fields out of jsbeeb and search the `.snf` for them. A **unique** match is the pass —
twelve fields matched frame 427 and nothing else in the tune's 17,446 when this was last done.

## The known baseline

`verify_akl.py` should print, over the whole tune:

```
1. IDENTICAL on every frame
2. audible mismatches: {'ch2 period': 11}
```

**Eleven channel-2 periods off by one is correct**, not a defect — it is Arkos's own documented
±1 difference in the volume/pitch effects between the PC side and the Z80 player. Anything else is
a regression.

The oracle comparison deliberately ignores what cannot be heard. `SongToYm` zeroes R6 when nothing
has the noise open and R11/R12 when nothing uses the envelope, and Arkos's player does not bother
clearing a silent channel's tone-disable bit — so a raw fourteen-register diff reads as 11% wrong
and is nothing of the kind. `check_reference()` is where that judgement lives.

## Files

| | |
|---|---|
| `akl_reference.py` | the Python transcription of `PlayerLightweight.asm`. `ENV_BASE = 12` here mirrors `src/aklplayer.asm`'s — **if one changes the other must** |
| `sim_akl.asm` | the real players with a zero page block and an ORG around them. It `INCLUDE`s `src/aklplayer.asm` and `src/ay2sn.asm`, so it tests what ships, not a copy. Its ZP block mirrors `main.asm`'s `IF MUSIC_AKL` branch |
| `verify_akl.py` | builds, runs, both checks, the cost, and optionally an `.snf` |
| `build/` | intermediates, gitignored |

## Judging the sound

The remaining questions are not correctness questions and this harness cannot answer them — see
the layer doc. Render and listen:

```
python tools/akl/verify_akl.py --snf build/runtime.snf
python tools/sn2wav.py build/runtime.snf -o runtime.wav --start 49 --seconds 30
python tools/sn2wav.py build/cut.vgm      -o shipping.wav --start 49 --seconds 30
```

For the reference the tune is *supposed* to sound like, `SongToWav.exe` renders the CPC AY original
straight from `source_cpc/Music/EDGEA.SKS`.
