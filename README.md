# Edge Grinder — BBC Master 128

A port of Cosine's *Edge Grinder* (Commodore 64) to the BBC Master 128, in 6502 assembly.

**It is a game now.** Layers 0 to 7 are done, and Layer 9 has started. What runs today: a
one-pixel-per-frame horizontal scroller at 25 Hz in MODE 2, a five-row status panel held by a CRTC
rupture, eight software sprites clipped and redrawn every frame in both shadow banks, a player ship
you can fly, shoot with and be killed in, the original's 201 attack waves, three lives with the
six-piece explosion and the drop-in shield, game over, the completion sequence, score and high
score on the panel, the CPC port's tune on the SN76489 out of HAZEL, and a titles page with the
original's zoom scroller running across it twice over. There is a memorial to T.M.R. between the loading screen and the titles, and the credits
cross-fade between the original's and this port's. What is left is hand-drawn BBC artwork
(Layer 8) and the rest of the polish.

Try the current build in a browser:

**https://bbc.xania.org/?disc=https://bitshifters.github.io/content/wip/edge-beeb.ssd&autoboot&model=Master**

**Z** and **X** steer left and right, **K** and **M** up and down, **L** fires, **SPACE** or **L**
starts a game from the titles, **P** pauses, **ESCAPE** gives up (only from inside the pause, as the
original has it) and **Q** mutes the tune.
Boot takes about eleven seconds with the loading screen up, while four sideways banks and the music
come off the disc and the scroll is wound forward a screen.

The published build is a development one: the frame meter is running, though it writes to memory
and shows nothing, so it looks like a release build. The tune used to be cut to 203 of its 349
seconds for want of room; it is not any more, and the whole thing plays and loops.

## What works

**The scroll.** Two 16K shadow screens at `&4000-&7FFF`, both hardware-wrapped, half a byte out of
phase with each other so a CRTC step of two pixels reads as one. One byte column a frame is built in
a 160-byte column buffer — rotated left a pixel, the next map column ORed in — and copied to the
edge of the hidden bank. The character set is stored as four MODE 2 column planes so that OR is a
single indexed load. 11,153 cycles a frame.

**The display.** In play, a two-cycle CRTC rupture: five rows of status panel at a fixed address,
then thirty-four rows holding the twenty-row play area at the scrolling address, with VSync where
MODE 2 puts it. IRQ1V is ours outright — no MOS tick, no OS sound, the keyboard read straight off the
System VIA — and the VSync handler owns the bank flip, taking a parked scroll address only when two
fields have passed. A slow frame costs whole fields and never tears.

**The sprites.** Eight slots in the C64's own arrangement: the player, his bullet, and a pool of six.
Masks are derived from the data byte rather than stored, the save area mirrors screen geometry so one
`Y` addresses both the screen and the saved background, and the restore replays the draw's recorded
walk rather than remembering addresses. Clipped at all four edges, and a sprite straddling the
buffer's 16K wrap falls back to walking the pointer per column. The frames worth it — the bullet
and the densest explosions — are compiled to straight-line 6502 in a sideways bank of their own.

**The player and the waves.** Movement and bounds, the fire latch, the bullet, and both background
collision checks, transcribed from the original; and the 201-wave attack table with its two-command
movement model, shields, scoring and explosions. The game logic ticks twice per display frame, because the
C64's loop runs at 50 Hz and ours at 25, which lets its per-frame constants transcribe unaltered.
Collision reads a character map the scroll keeps as it plots — the C64 reads codes back out of the
screen it displays, which a bitmap port cannot do — and puts them through the original's own
`col_decode` table.

**The game around it.** Three lives, the six-piece player explosion thrown on the original's own
direction vectors, the drop-in shield, game over, and the completion sequence the end of the wave
table triggers. Pause on P and abort on ESCAPE. The status panel is the C64's, rendered whole at boot from its multicolour charset
and colour map, with the score, the high score and the lives bars decoded onto it as they change.

**The titles.** The original's credits in its own charset, and its zoom scroller — a six-row-high
message in fat cells, and the same thing again above it rotated a hundred and eighty degrees. Four
CRTC cycles rather than two, with **both bands hardware-scrolled**: the display wrap goes to 8K, so
`&6000-&7FFF` is a ring in each shadow bank, one band lives in each, and the display bank is
switched inside the frame to show both. That leaves nothing to shift in software — a band whose
start address moves shears one column per row per step, which is exactly what the play area's column
copy has been paying since Layer 2, so the whole per-frame cost is the original's own new-column
write. The C64's colour pulse on the first and last credit lines is a horizontal colour-RAM cycle
that MODE 2 cannot do, so it is the CPC port's answer instead: a raster down the eight scanlines of
each line, through the CPC's own colour list, the two indexed from opposite ends.

The credits **cross-fade** between the original's and this port's, five seconds a set — on the
palette alone, and touching nothing else on the page. The trick is that their font is drawn in
logicals 12, 14 and 15 rather than 4, 6 and 7: the MODE 2 palette maps 8–15 back onto 0–7, so they
are the same blue, cyan and white and the page looks identical, but they are entries nothing else
there uses. Eight writes to the palette register a step, no screen memory touched, so the panel and
both zoom bands stay lit and the scroller never loses a field. The scroller's own message is
**`assets/scrolltext.txt`**, seeded with the C64's, and meant to be edited: run
`python tools/export_zoom.py` and rebuild. The build prints how many characters are left.

**The music.** The Amstrad CPC port's Arkos tune, converted SKS → YM → VGM → VGI and played by the
VGI player at 50 Hz from the VSync handler. All 349 seconds of it, which took some finding: it is
23,514 bytes and the largest contiguous hole on the machine is about 17K. But a `.vgi` is not one
blob — it is **eleven independent streams**, one per sound chip register, and the player reads
exactly one byte from each per frame through its own pointer. So each *stream* has to be contiguous
and the *tune* does not, and it lives in four separate places: the top of sideways bank 3 running
on into HAZEL (which are one block, because both windows are visible at once), **ANDY** — the
Master's own private 4K, paged by bit 7 of ROMSEL — and the tails of the two sprite banks. A build
tool does the packing and generates the eleven addresses and eleven bank-select bytes; the player
pages each stream's region in for the eight cycles it takes to fetch a byte. It costs nothing
measurable: the worst frame is unchanged.

The C64 has no sound effects at all, and neither does this.

**The loader.** A full-screen MODE 2 loading picture goes up before anything else and stays there
while the banks come in behind it, staged in the shadow screen where nothing is displaying them.
Every data file on the disc ships ZX0-compressed: 104,192 bytes of files becomes 45,824. The status
panel is one of them — 3,200 bytes read exactly twice in the life of a run, unpacked straight into
each bank's screen, because the sideways bank it used to sit in is where the tune has to be.

When the loading is done the picture **fades out**, **IN MEMORY OF T.M.R.** fades up in the credits'
own font, holds, and fades out again into the titles. That is the palette too: MODE 2's eight
colours sit on one brightness ladder — black, blue, red, magenta, green, cyan, yellow, white — so a
step down it is the whole picture one step darker, and not a byte of it is touched.

Roughly 90% of the 79,872-cycle frame is spoken for in ordinary play, plus 4.3% for the music —
measured with the frame meter, not estimated. A deliberate stress test (fire held, the ship parked
so it dies over and over) reaches 105% and misses seven flips in 2,500 frames; `BUGS.md` #9 costs
the options for buying that margin back.

## Building

Needs [BeebASM](https://github.com/stardot/beebasm) 1.11 at `..\..\Bin\beebasm.exe`, or a copy in
`bin\`, plus Python 3 and `zx0.exe` (the reference ZX0, at `..\..\Bin\` or `bin\`). PowerShell:

```powershell
.\build.ps1           # assemble into build/
.\build.ps1 -Run      # and launch b-em as a Master 128
.\build.ps1 -Release  # the build for other people: every DEBUG_ flag off
.\build.ps1 -Cpc      # the same game drawn with the Amstrad CPC port's artwork
.\build.ps1 -Akl      # the tune replayed from Arkos data instead, for comparison
make                  # thin wrappers: make, make run, make -Release
```

**The build is two passes and BeebASM's own image is not bootable.** Everything lands in `build/`:
`EDGE-RAW.SSD` is BeebASM's, uncompressed; `tools/make_disc.py` compresses the data files, moves
each catalogue load address to the staging address the boot loader expects and lays the files out
in boot access order, giving `EDGE.SSD` and `EDGE-200K.SSD` (padded — hand this one to an emulator).
`RELEASE`, `GFX_CPC` and `MUSIC_AKL` are command-line symbols and every build must pass all three,
because BeebASM has no `IFDEF` and the source cannot carry a default. Every flag that changes what
the disc contains is stamped into `!BOOT`, so a build cannot lie about itself.

The graphics in `src/data/` are generated by the exporters in `tools/` (Python 3 and Pillow) from
`assets/`, the C64 binaries in `data/` and the original source. They are committed; regenerate them
with the tool rather than editing them. `tools/render_bbc.py` renders them back to PNG for checking.

## Layout

| | |
|---|---|
| [`PLAN.md`](PLAN.md) | The live plan: where the port is and what is left. Start here |
| [`PROPOSAL.md`](PROPOSAL.md) | The design rationale — the sprite engine, the artist pipeline, the options costed and rejected |
| [`docs/`](docs/) | One file per finished layer: measurements, dead ends, and why things are as they are |
| [`docs/decisions.md`](docs/decisions.md) | Every deviation from the original, numbered |
| [`BUGS.md`](BUGS.md) | Open defects, and fixed ones kept for what they ruled out |
| `src/` | The assembly, all included from `main.asm` |
| `assets/` | The hand-drawn BBC artwork |
| `source_c64/` | The original's source, which is the specification |
| `source_cpc/` | Axelay's Amstrad CPC port — the closest architecture to this one |

The C64 original is the specification: features start by finding what it does, and take its code,
constants and tables verbatim wherever the hardware allows. Where the BBC forces a change, the aim
is to port the decision the original made rather than just the effect — and to write down why.

## Credits

*Edge Grinder* was written by Cosine — code by Jason "TMR" Kelk, graphics by Trevor "Smila" Storey,
music by Sean "Odie" Connolly — for the Format War contest, and published on cartridge by RGCD.
Axelay's Amstrad CPC conversion has been a reference throughout.

This port is by Kieran Connell, and is an unaffiliated hobbyist project. It carries no licence: the
repository vendors the original's source and data, and the CPC port's, which are their authors' and
not mine to license. Ask if you want to do something with the port's own code.
