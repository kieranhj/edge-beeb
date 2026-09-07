# Edge Grinder for the BBC Master 128

A port of *Edge Grinder*, Cosine's Commodore 64 shooter, to the BBC Master 128, written in
6502 assembly for BeebASM.

*Edge Grinder* is a horizontal scroller: fly right along a five-tile-high level, shoot the 201
attack waves the original throws at you, and grind the scenery for points. This port reproduces
the original's game logic, level, waves, sprites and titles on a Master, with the Amstrad CPC
port's tune on the BBC's sound chip.

## Play it

In a browser, no setup needed:

**https://bbc.xania.org/?disc=https://bitshifters.github.io/content/wip/edge-beeb.ssd&autoboot&model=Master**

Or hand `EDGE-200K.SSD` from a build to any emulator, or a real Master 128, as a Master. It needs
a Master: the game uses shadow RAM, sideways RAM, ANDY and HAZEL.

| Key | |
|---|---|
| **Z** / **X** | left / right |
| **K** / **M** | up / down |
| **L** | fire; also starts a game from the titles, as does **SPACE** |
| **CTRL+R** | redefine the five keys, on the titles |
| **CTRL+A** | auto-fire on / off, on the titles |
| **CTRL+P** | pause; CTRL+P or fire resumes |
| **ESCAPE** | give up, only while paused, as the original has it |
| **CTRL+Q** | mute the tune |

## Why

The C64 original is small, clean, and fully documented in its own source, and the BBC has never
had it. The port takes the original as its specification: its code, constants and tables are
transcribed verbatim wherever the hardware allows, and where MODE 2, the 6502 at 2 MHz or the
SN76489 force a change, the aim is to port the decision the original made rather than just its
effect, and to write down why. Every deviation is a numbered row in
[`docs/decisions.md`](docs/decisions.md).

Under the hood that means a one-pixel-per-frame scroll at 25 Hz across two hardware-wrapped shadow
screens, a CRTC rupture holding the status panel, eight software sprites, IRQ1V owned outright,
and a 349-second tune split across four regions of memory because no single hole would take it.
Each layer of the port has its own write-up in [`docs/`](docs/), with the measurements and the
dead ends.

## Building

Needs [BeebASM](https://github.com/stardot/beebasm) 1.11 at `..\..\Bin\beebasm.exe` or in
`bin\`, Python 3 with Pillow, and `zx0.exe` (the reference ZX0 compressor) in the same places.

```powershell
.\build.ps1           # assemble into build/
.\build.ps1 -Run      # and launch b-em as a Master 128
.\build.ps1 -Release  # every DEBUG_ flag off
.\build.ps1 -Cpc      # the same game with the Amstrad CPC port's artwork
.\build.ps1 -Nula     # the artwork at its own sixteen colours, for a VideoNuLA
.\build.ps1 -Akl      # the tune replayed from Arkos tracker data instead
make                  # wrappers: make, make run, make -Release
```

The output is `build/EDGE.SSD` and the padded `build/EDGE-200K.SSD`. BeebASM's own image,
`EDGE-RAW.SSD`, is not bootable: every data file ships ZX0-compressed and `tools/make_disc.py`
is the second pass that does it. Details in [`docs/layer-0-toolchain.md`](docs/layer-0-toolchain.md).

The artwork is read from PNGs in `assets/art/`, and the graphics, tables and music in `src/data/`
are generated from them by the exporters in `tools/`. They are committed; regenerate them with the
tool rather than editing them.

## Layout

| | |
|---|---|
| `src/` | The assembly, all included from `main.asm` |
| `assets/` | The BBC artwork and the scrolltext |
| `tools/` | The exporters, the disc builder and the checking tools (Python) |
| `docs/` | One file per layer, [`decisions.md`](docs/decisions.md) and [`memory-map.md`](docs/memory-map.md) |
| [`PLAN.md`](PLAN.md) | Where the port is and what is left |
| [`PROPOSAL.md`](PROPOSAL.md) | The design rationale |
| [`BUGS.md`](BUGS.md) | Open defects, and fixed ones kept for what they ruled out |
| `source_c64/` | The original's source, which is the specification |
| `source_cpc/` | Axelay's Amstrad CPC port, the closest architecture to this one |
| `reference/`, `data/` | The original's map, tiles, characters and sprites, as PNG and as binaries |

## Credits

*Edge Grinder* was written by Cosine for the Format War contest and published on cartridge by
RGCD: code by Jason "TMR" Kelk, graphics by Trevor "Smila" Storey, music by Sean "Odie" Connolly.
Axelay's Amstrad CPC conversion supplied the tune and has been a reference throughout. The port is
dedicated to the memory of TMR.

This port is by Kieran Connell and is an unaffiliated hobbyist project. It carries no licence: the
repository vendors the original's source and data, and the CPC port's, which are their authors'
and not mine to license. Ask if you want to do something with the port's own code.
