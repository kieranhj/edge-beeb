# Edge Grinder on the BBC Master — artwork

Five PNGs in this folder are the game's artwork. Repaint them, send them back,
and they go straight into the build. Everything else — the level layout, which
tile goes where, the animation order, what kills you — is fixed and is not in
these files.

All five sheets are seeded with the current conversion of the C64 original, so
you are always painting over a working game rather than starting from nothing.

## The palette — eight colours, and that is all there is

`palette.png` is the palette: sixteen pixels, one per colour slot. There is no
choosing it. The BBC's MODE 2 shows all eight of its colours at once and they
are all fully saturated — **black, red, green, yellow, blue, magenta, cyan,
white**. No greys, no dark shades, no half-tones. Tiles and sprites share the
same eight.

`palette.gpl` (GIMP, Aseprite, Krita) and `palette.act` (Photoshop, Aseprite)
are the same thing in a form those programs load directly. **Please work with
one of them loaded and use nothing outside it.** Any other colour is a hard
error on our side — we would rather bounce the file back than guess which of
the eight you meant.

The good news, if you know the C64: there is **no per-character colour limit**.
Any colour, anywhere, on any pixel. That constraint is gone.

Slots 8–15 are duplicates of 0–7 today. They exist because the machine may
later get a Pi1MHz/NULA upgrade that turns them into eight more colours from a
palette of 4096. Ignore them for now; nothing is lost if that never happens.

### Two colours that are not colours

| Swatch | RGB | Meaning |
|---|---|---|
| grey | `96, 96, 96` | **see-through.** Sprites only. |
| orange | `255, 128, 0` | **not drawn yet.** Fill a whole cell with it and we use the old conversion for that cell. |

The orange is how you hand over ten sprites at a time: paint what you have
done, leave the rest orange, and the game still builds complete. It must be a
**whole cell** — orange mixed into a painted cell is an error.

## Pixels are 2:1

A BBC MODE 2 pixel is twice as wide as it is tall. All five sheets are drawn at
**2 image pixels across, 1 down** per screen pixel, so they look on your screen
roughly the way they will look on a TV. **Always paint in 2×1 blocks** — a
1-pixel-wide mark is half a pixel and we cannot use it. In Aseprite, set the
brush to 2×1 and it takes care of itself.

## `chars.png` — the scenery, 128 × 128

256 characters, 16 to a row. Each is one cell of 8 × 8 image pixels — **4
screen pixels wide, 8 rows tall**.

The level is built out of these: 211 tiles of 4 × 4 characters, laid out in a
map 302 tiles long. The tile definitions and the map are the original's and
stay as they are, so **repainting a character repaints every tile that uses
it** — the charset is reused about thirteen times over. That is the whole
reason you paint characters and not the level.

To see what your characters look like assembled, ask for a fresh render — we
regenerate `tiles.png` (all 211 tiles) and `map.png` (the whole level, end to
end) from your sheet in a second.

Three things to keep in mind:

1. **Empty space must stay pure black.** The starfield only draws stars where
   the background is genuinely empty. Anything else — a very dark colour, a
   single stray pixel — and the stars stop appearing there. There are 23
   all-black characters at the moment and it is worth keeping it that way.
2. **Keep solid things looking solid.** What kills the player is decided per
   character number, in a table, not by what the character looks like. If you
   repaint a deadly character to look like open sky, it stays just as deadly.
3. **No transparency here.** The scenery is opaque; the grey key is a sprite
   thing only.

## `sprites.png` — the ships and everything that moves, 192 × 336

128 cells, 8 to a row. Frames **0–118** are the game's; 119–127 are spare and
ignored. Each cell is 24 × 21 image pixels — **12 screen pixels wide, 21 rows
tall**, which is the size of a C64 sprite and what the engine is built around.

Grey `96, 96, 96` is see-through. Black is a real colour here and is drawn.

**Frame order is the animation order** and is fixed: which frame is the player,
which is the bullet, which are the six enemy types and their animation runs,
is all wired into the game's own tables. Repaint frames; do not move them. The
current sheet shows you what each frame is.

One thing worth knowing before you pick colours: when the player is grinding
along a wall, and when an enemy is hit, the sprite **flashes**. The way the
original does it is to leave blue and white alone and recolour everything else.
If your frames keep to *blue, white, transparent and one further colour each*,
you get exactly that. If you use colour more freely — which you are welcome to
— the flash recolours the whole sprite instead. Both look fine; we just check
which one your sheet is going to get and tell you.

## `panel.png` — the status bar, 320 × 40

This one is not a sheet of cells, it is a **picture**: the status bar exactly as
it appears across the top of the screen, at the size it appears. 40 characters
wide and 5 rows tall, which is 160 screen pixels by 40. Paint it as one image.

It is drawn once, at the start, and never redrawn — so it costs nothing and you
can be as detailed as you like.

**Three parts of it are not yours to paint**, because the game writes over them
every time the numbers change:

| What | Where |
|---|---|
| score | row 1, columns 7–12 |
| high score | row 1, columns 27–32 |
| lives | row 2, columns 17–22 |

Columns and rows count from 0, and a column is 8 image pixels wide, a row 8
tall. Anything you paint in those eighteen cells is seen at boot and then
replaced. The C64's bar leaves them empty and lets the digits sit on black; the
Amstrad's paints a background into them and lets the digits sit on that. Either
works — we just tell you which you have done, so it is never a surprise.

## `hud.png` — the digits and the life marker, 128 × 8

Thirteen small cells in a row, each 8 × 8 image pixels (4 screen pixels by 8) —
the same size as one character:

```
 0        blank (used to rub a digit out)
 1 .. 10  the digits 0 to 9
 11, 12   the life marker, left half and right half
```

These are stamped into the cells listed above whenever the score or the lives
change, so they have to read against whatever background `panel.png` puts
behind them. Four pixels is not much width for a digit — the current ones use a
bright body with a darker shadow pixel, which is what makes them legible on
eight colours, and that is worth keeping in mind rather than copying.

Cells 13–15 are spare and ignored.

## `titlefont.png` — the credits lettering, 128 × 16

32 cells, 16 to a row, each 8 × 8 image pixels (4 screen pixels by 8) — the same
size as a character. In order: blank, then **A–Z**, then `!` `.` `,` `-` `?`.
There are no digits and no lower case; the credits are written in this alphabet
and nothing else needs them.

It draws the five credit lines on the title screen, and the "IN MEMORY OF
T.M.R." message before them.

**This one sheet has only three colours: blue, cyan and white** (plus black for
the background). Not a stylistic preference — the credits fade in and out by
changing the palette rather than by redrawing, and there are exactly three
palette slots set aside for it. A fourth colour has nowhere to live, so we bounce
it back rather than let it quietly drag the status bar into the fade with it.

*(We think this limit can be lifted later — there is a way to give the title
screen a palette of its own — so if three colours is really cramping the
lettering, say so and we will look at it rather than you working around it.)*

The credit **text** is not in this file; if you want wording changed, just say.

## Sending work back

Send whichever PNGs you have changed. We run one command that checks them and
tells us, with exact coordinates, about anything that is off — a colour outside the palette, a
half-width pixel, transparency where it cannot go. Then it goes into a disc
image and you get a link that boots the real game in a web browser, no
emulator to install.

If something in here is fighting you, say so — most of these rules are the
machine's, but the sheet layout is ours and can change.
