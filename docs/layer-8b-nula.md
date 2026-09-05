# Layer 8b — two VideoNuLA test builds (2026-09-05)

Decisions 63 and 64. `GFX_NULA=1` builds the game for Rob Coleman's VideoNuLA, which
replaces the Video ULA with one that gives each of MODE 2's sixteen logical
colours a 12-bit RGB of its own. Two of them, and neither is the eventual
BBC-specific artwork:

| Build | Artwork | Palette |
|---|---|---|
| `.\build.ps1 -Nula` | the C64's | the C64's own sixteen, Pepto |
| `.\build.ps1 -Nula -Cpc` | the Amstrad's | its own sixteen mode 0 pens |

**They are references, not candidates.** The point of each is that *nothing is
approximated*: sixteen logical colours and sixteen source colours, so logical
colour n **is** source colour n and there is no mapping to argue about. What
they show is what the original showed, and any difference from the eight-colour
build is ours rather than the machine's. KC judges them on real hardware or in
b2; jsbeeb has no NuLA and cannot run them at all, which is why the one thing
this layer got wrong was found by him and not here.

Two things go away that the eight-colour builds cannot avoid:

* **`C64_TO_BBC`'s hue collapse.** Decision 11 sends the playfield's brown to
  blue, both greys and light blue to whatever is nearest, and the panel's dark
  grey and its blue to the same colour. Here the scenery is brown, the panel
  has its two greys, and `HUD_PAIR_3`'s white-body trick — invented because a
  four-pixel digit in dark-grey-collapsed-to-blue was unreadable — is not
  needed and is not applied.
* **Decision 55's dither.** A CPC pen is one colour again, not two MODE 2
  colours checkerboarded. `tools/art/nula.py` reads the same banks with no
  `dither_pair` anywhere.

## What was built

`tools/art/nula.py` is the whole art side: the two palettes, and the C64 and
CPC readers again but returning **source** colours. It deliberately bypasses
the PNG sheets — a NuLA build is the original artwork at its own colours, not
the artist's work — so `assets/art/` is untouched by any of this.

The exporters gained `--nula` (composing with `--cpc`) and write `-nula` and
`-nula-cpc` copies beside the others; `src/` picks between the four with a 2×2
`IF GFX_NULA` / `IF GFX_CPC` at each of the eight INCBIN sites.
`tools/render_bbc.py --nula [--cpc]` renders them at the right palette, which
is the only way to look at either build without the hardware.

## The hardware, which is the part that is not ours

All of it comes from the **VideoNuLA User Guide** (`BEEB/Manuals/VideoNuLA
manual.pdf`) and from `BEEB/Repos/bbc-nula/lib/nula.asm` — simondotm's gallery,
with RobC's hardware and KieranHJ's B-Em support — and **not** from recall,
which `CLAUDE.md` forbids for exactly this reason. `setup_display` writes, in
this order:

* **`&FE22 = &40`** — control code 4, reset extended features. First, because
  the board can be left in an attribute or direct mode by whatever ran before
  us and nothing else here would put it back.
* **`&FE22 = &11`** — control code 1 with parameter 1, **logical colour
  mapping**. Load-bearing, and the subject of the next section: without it
  `&FE21` composes in front of the auxiliary palette and the titles wreck the
  game's colours.
* **thirty-two bytes to `&FE23`** — the palette. **Two bytes per entry**,
  `[index<<4 | red]` then `[green<<4 | blue]`, each channel the top nibble of
  the 8-bit value, and they must arrive in that order.

**The encoding is proved twice, not assumed.** `nula_bytes` in
`tools/export_palette.py` reproduces the reference library's own default table —
`&00,&00 &1f,&00 &20,&f0 &3f,&f0 &40,&0f &5f,&0f &60,&ff &7f,&ff` for the eight
BBC colours — byte for byte, and it agrees with the manual's worked example
(`?&FE23=&78 : ?&FE23=&88` sets colour 7 to mid grey).

`pal_data` is generated ascending now, entry 0 first, because NuLA needs its
pairs in order. The MODE 2 build does not care either way (each of its bytes
carries its own logical index), so both share one ascending loop and the
descending one is gone.

### How the two palettes compose — measured, and I had it wrong

The first version of this layer wrote **no `&FE21` at all** under `GFX_NULA`, on
the reasoning that the reference gallery does the same and its default table
implies NuLA is indexed by the logical colour. That was flagged as an inference
rather than a measurement, and it was wrong. KC ran the CPC build on real
hardware and the scenery came back with a **blue background** instead of black,
with stepped edges wherever a diagonal met it (`reference/cpc-nula-bug1.png`).

The VideoNuLA User Guide settles it:

> By default, VideoNuLA will mimic the Video ULA IC and map logical colours to
> the 16 physical colours using the original palette (accessed at 0xFE21). It
> then translates the physical colours into 12-bit RGB colours using the
> auxiliary palette (accessed at 0xFE23).

So by default the two tables **compose**: logical → `&FE21` → physical →
`&FE23` → 12-bit RGB. `&FE21` matters enormously, and this game writes it from
somewhere I had not accounted for. `ttl_raster` in `src/bank1.asm` pulses
logicals 14 and 15 every scanline of the titles to colour-cycle the zoom bands
(decision 53), and it leaves logical 15 pointing at **physical 7**. The
Amstrad's charset paints its background in **pen 15**, so in play that
background arrived as NuLA entry 7 — which in the CPC palette is `(0,0,255)`,
blue. Every part of the symptom is accounted for, including why it only shows
after the titles have been seen and why the C64 build is much less affected.

The fix is one write the manual gives us:

> To switch from physical-mode to logical-mode mapping, type: `?&FE22 = &11`.
> This will cause the original palette (accessed at 0xFE21) which maps logical
> colours to physical colours to be **ignored**.

`setup_display` now sends `&40` (control code 4, reset extended features) and
then **`&11`** (control code 1, parameter 1, logical colour mapping) before the
thirty-two palette bytes. That is strictly what this game wants:

* all sixteen entries are reachable as logicals 0-15, with nothing composed in
  front of them;
* the MOS's default palette is no longer depended on at all;
* `ttl_raster`'s writes become inert, so the titles cannot corrupt the game's
  colours. Its colour cycling simply does nothing under NuLA, which is a
  cosmetic loss on the zoom bands and the honest price of the fix.

Two things were confirmed by measurement in jsbeeb along the way, both about
the *Video ULA* rather than NuLA, and both still true of the eight-colour
build: the MOS's default MODE 2 palette is logical n → physical n for all
sixteen, and `(n << 4) OR (n EOR 7)` written to `&FE21` reproduces it exactly.

**The encoding was right and is now doubly confirmed** — against the reference
library's default table, and against the manual's own worked example
(`?&FE23=&78 : ?&FE23=&88` sets colour 7 to mid grey).

## The Amstrad's background is pen 15, not pen 0

Found while chasing the above, and a real defect of its own. The CPC charset
uses pen **15** for empty space — 2,196 uses against pen 0's 64 — and both are
black in the in-game palette. Under a straight pen-to-logical identity an empty
play-buffer byte would read `&FF` where the C64's reads `0`, and **the starfield
would never draw a star**: `src/bank1.asm` plots one only where the byte is
exactly zero.

So the opaque CPC art — characters, panel, HUD — sends every black pen to
logical 0. Same colour, right zero. Sprites keep the opposite rule, drawn black
going to logical 15, because there logical 0 is the transparency key.

The eight-colour `-Cpc` build never had this problem: `dither_pair` sends both
black pens to logical 0 already.

## What these builds do NOT do

**The fades are cuts.** `fade_pal` under `GFX_NULA` writes either the palette or
black, thresholded halfway through whatever fade asked for it, rather than
walking a gradient.

A real NuLA fade means scaling sixteen 12-bit colours towards black, which
needs a multiply or a ramp table — 8 levels × 32 bytes = 256, or 8 × 16 nibbles
= 128 with more code around it — and bank 2 has 86 bytes free. It is a memory
map problem, not a hard one, and it is the obvious next piece of work if these
builds turn out to be the direction.

What the cut keeps is the property the sequences actually depend on: the screen
is black while a redraw happens, so the memorial's message and the credits'
swap are still not seen being drawn. What is lost is the gradient.

**The credit crossfade does not run at all.** It works by owning three palette
entries nothing else on the titles uses (decision 53) and under NuLA there are
no spare entries — all sixteen are real colours and the panel uses several of
the top eight, so fading 8-15 would take parts of the status bar with it. So
the C64's credit set stays up, unfaded, and the second set is never shown.

That is the same constraint KC has already flagged for revisiting on the
eight-colour build (the end of [`layer-9e-credits.md`](layer-9e-credits.md)),
and the answer there is the answer here: give the credits' own CRTC cycle its
own palette, or stop sharing one between the titles and the game. Under NuLA
that is *more* attractive, not less, because sixteen entries make the sharing
tighter rather than looser.

## Verified

* **The palette encoding**, against the reference library's default table, byte
  for byte.
* **Every existing output is untouched.** `sprites0/1.bin`, `compiled.bin`,
  `compiled_zp.asm`, `chars.bin`, `panel.bin`, `hud.bin`, `title.bin` and all
  their `-cpc` copies are byte for byte what they were; only `palette.asm`
  changed, and only in row order. The refactor that made `lut_dcd`'s two flash
  tables selectable put them in the other order at first and moved 28 bytes of
  every sprite bank — caught by that diff, and `order` is named rather than
  derived now so the tables keep their addresses.
* **`lut_dcd` is identical in all four builds.** Which frames flash and when is
  game logic and is judged on the C64 mapping everywhere, the CPC's and both
  NuLA builds included, for the same reason `dp_dcd` is.
* **All sixteen flag combinations assemble**, `RELEASE` × `MUSIC_AKL` ×
  `GFX_CPC` × `GFX_NULA`.
* `tools/verify_compiled.py` passes on both eight-colour builds.
* The eight-colour build is unchanged in jsbeeb after the palette loop turned
  round — memorial, titles, crossfade and a game in play all correct.
* **KC ran the CPC build on hardware**, which is what found the `&FE21`
  composition; the fix is verified by the manual and by reasoning that accounts
  for every part of the symptom, but **not yet re-run**.

## Sizes

`EDGE-NULA.SSD` is 47,616 bytes against the normal build's 46,848, and
`EDGE-CPC-NULA.SSD` 48,896 against 48,640: the palette costs 16 bytes and the
art compresses slightly worse without the dither's regularity. Bank 0 has 16
bytes free in a NuLA build against 23; main RAM 446 against 462.
