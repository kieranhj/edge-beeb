# Layer 8b — two VideoNuLA test builds (2026-09-05)

Decision 63. `GFX_NULA=1` builds the game for Rob Coleman's VideoNuLA, which
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
build is ours rather than the machine's. KC will judge them on real hardware or
in b2; jsbeeb has no NuLA and cannot run them at all.

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

Everything about the board comes from `BEEB/Repos/bbc-nula/lib/nula.asm` —
simondotm's gallery, with RobC's hardware and KieranHJ's B-Em support — and
**not** from recall, which `CLAUDE.md` forbids for exactly this reason:

* `&FE23` is the palette. **Two bytes per entry**, `[index<<4 | red]` then
  `[green<<4 | blue]`, each channel the top nibble of the 8-bit value, and they
  must arrive in that order. Sixteen entries, thirty-two bytes.
* `&FE22 = &40` resets NuLA state. `setup_display` does that first, because the
  board can be left in an attribute or direct mode by whatever ran before us
  and nothing else here would put it back.

**The encoding is proved, not assumed.** `nula_bytes` in
`tools/export_palette.py` reproduces that library's own default table —
`&00,&00 &1f,&00 &20,&f0 &3f,&f0 &40,&0f &5f,&0f &60,&ff &7f,&ff` for the eight
BBC colours — byte for byte.

`pal_data` is generated ascending now, entry 0 first, because NuLA needs its
pairs in order. The MODE 2 build does not care either way (each of its bytes
carries its own logical index), so both share one ascending loop and the
descending one is gone.

### Unverified, and the first thing to check

**This build writes no `&FE21` at all under `GFX_NULA`.** The reference gallery
does the same — it takes the MOS's MODE 2 palette from `VDU 22,2` and then
programs NuLA — which is good evidence that the NuLA palette is indexed by the
*logical* colour and supersedes the Video ULA's table. Its default table, whose
entries 8-15 repeat 0-7 as steady colours where a real BBC would flash them,
says the same thing.

But it is an inference from someone else's code, not a measurement, and there
is no way to measure it here. **If b2 shows only eight colours, the `&FE21`
identity write is what to put back** — `setup_display` in `src/bank0.asm` says
so at the point where it would go.

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
* **The NuLA builds have not been run.** They cannot be, here.

## Sizes

`EDGE-NULA.SSD` is 47,616 bytes against the normal build's 46,848, and
`EDGE-CPC-NULA.SSD` 48,896 against 48,640: the palette costs 16 bytes and the
art compresses slightly worse without the dither's regularity. Bank 0 has 16
bytes free in a NuLA build against 23; main RAM 446 against 462.
