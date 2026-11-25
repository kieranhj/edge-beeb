# edge-beeb: start here

A port of *Edge Grinder* (Cosine, Commodore 64 horizontal shooter) to the BBC Master 128, in 6502 assembly for BeebASM, with the Amstrad CPC port's tune on the SN76489. A complete game.

| | |
|---|---|
| GitHub | https://github.com/kieranhj/edge-beeb (public) |
| Upstream | Original: Edge Grinder by Cosine (C64); CPC port sources in `source_cpc/`, C64 in `source_c64/` |
| Local path | D:\beeb\mine\edge-beeb (moved from OneDrive\BEEB\Repos\edge-beeb on 2026-11-22) |
| Branch | master (only branch) |
| Last commit | 2026-10-06: ttl_raster's comment: &FE21 is a 2 MHz access, so nothing realigns the loop |

## What's in here
- `src/` - the game (`main.asm` and friends, BeebASM).
- `tools/` - Python pipeline: `make_disc.py` (ZX0-compressed disc), `export_music.py`, art converters, `akl/` (Arkos music checks).
- `assets/`, `data/` - converted art and data; `source_c64/`, `source_cpc/` - the originals' sources/assets.
- `docs/` - one file per layer, `decisions.md`, `memory-map.md`, `performance.md`, dataflow reviews; `notes/` - early tech notes.
- `PROPOSAL.md`, `PLAN.md`, `BUGS.md`, `CLAUDE.md` - proposal, state and what's left, defects, standing rules.

## Build and run
- `make`: runs `build.ps1` -> `build\EDGE.SSD` (+ `EDGE-200K.SSD` padded for jsbeeb, `EDGE-RAW.SSD`, listing). Tested 2026-11-22, works. Other targets: `make release`, `make cpc` (CPC artwork), `make nula` (VideoNuLA build), `make run` (build and launch b-em), `make help`.
- `make.bat` is the older cmd.exe wrapper (`make run` = `-Run`); still there for cmd.
- Tools: beebasm via `..\..\Bin\beebasm.exe`; Python 3; `zx0.exe` from `bin\` or `..\..\Bin`. `-Run` uses b-em at `D:\tools\beeb\B-Em\b-em-42f6597-w64\b-em.exe`.
- Play online: https://bbc.xania.org/?disc=https://bitshifters.github.io/content/wip/edge-beeb.ssd&autoboot&model=Master (needs a Master).

## Local changes
- 2026-11-22 tidy fixes (uncommitted): `build.ps1` b-em path moved off OneDrive to D:\tools; `tools/export_music.py` and `tools/akl/verify_akl.py` now find nova-invite and vgm-packer under `D:\beeb\mine\` (were `BEEB\Repos\`). Arkos Tracker is still looked for in `OneDrive\Retro\Trackers`.
- No stashes, no snapshot branches.

## Status and next steps
- PLAN.md: layers 0-9i done (2026-09-06); one open defect, BUGS.md #14 (one malformed field at the titles-to-game switch).
- Since then: Tube fix (BUGS #15, 2026-09-11) and static-analysis passes over BANK0/BANK1 (2026-10-06, 129 bytes of leads, none applied).
- See PLAN.md for what is left.

## See also
- README.md (keys, play link), PLAN.md, BUGS.md, CLAUDE.md, PROPOSAL.md, docs/layer-history.md.
- Related: D:\beeb\mine\nova-invite and D:\beeb\mine\vgm-packer (music tools).
