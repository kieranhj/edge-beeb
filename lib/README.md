# `lib/` — code from other repositories, copied and not edited

Everything in this directory is a **verbatim copy** of a file that is maintained
somewhere else. Nothing here is edited in this repository: a change made here
would be lost the next time the file is copied, and worse, it would make the two
copies disagree while both still claimed to be the same player.

If one of these needs to change, it changes upstream and is copied back.

| file | upstream | terms |
|---|---|---|
| `vgiplayer.asm`, `vgiplayer.h.asm` | `Repos/vgm-player-bbc` (simondotm's VGM player, this fork's VGI variant) | as that repo states |
| `aklplayer.asm`, `aklplayer.h.asm` | `Repos/arkos-player-bbc`, `lib/` | MIT |
| `ay2sn.asm`, `ay2sn_tables.asm` | `Repos/arkos-player-bbc`, `lib/` | MIT |
| `akl_periods.asm` | `Repos/arkos-player-bbc`, `lib/` — **generated** there by its `tools/make_tables.py` | MIT |
| `disksys.asm` | Bitshifters' disc system | as that project states |

The Arkos files are decision 70 here and decision 4 there. That repository was
extracted from this port in the first place, so it is upstream of its own
ancestor; the players, the AY→SN76489 conversion, the verification harness and
the format documentation all live there now.

**Their `INCLUDE "lib/..."` lines are written relative to a repo root**, which is
why a straight copy works: `lib/ay2sn.asm` asking for `lib/ay2sn_tables.asm`
resolves in either repository without a change. Keep that property.

**Two constants are the host's and are set in `src/main.asm`**, not here:
`ENV_BASE` (a property of the song — both Edge Grinder tunes are envelope 12)
and `BASS_MODE` (2, the periodic-noise bass). The library deliberately defaults
neither, because BeebASM cannot ask whether a symbol exists and a default would
be a choice this port did not make.

To check a copy has not drifted:

```
for %f in (aklplayer.asm aklplayer.h.asm ay2sn.asm ay2sn_tables.asm akl_periods.asm) do ^
    fc /b lib\%f ..\arkos-player-bbc\lib\%f
```
