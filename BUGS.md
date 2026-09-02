# Bugs

Open defects, with the evidence and what has been ruled out. Fixed entries stay for what they
ruled out. Index first, detail below.

| # | Status | Summary |
|---|---|---|
| 1 | open, suspected non-bug | "Double-buffer stash restore reads the wrong buffer" (`eor #1` commented out in `sprite.asm`) |
| 2 | open | No sprite clipping: `x_pos >= 80` indexes past `mult8_*` into the following tables and produces an arbitrary write pointer |
| 3 | open | `read_keyboard` has no bounds; the C64 clamps x to `$10-$9b` and y to `$5a-$e5` |
| 4 | open | The map loops after 256 tiles (`tile_total` is 8-bit); `map2_data` is loaded but never reached |

## 1. The `eor #1` that TODO.md wanted re-enabled

`src/sprite.asm`, `restore_background`, two commented-out `eor #1` lines. The 2026-03 TODO said the
restore "reads the wrong stash buffer half the time" and should have the `eor` put back.

Reading the loop: `&FE34` flips every iteration, so the bank being *drawn* in iteration *n* has
parity `char_col AND 1`. The sprite in that bank was last drawn in iteration *n-2*, and
`stash_background` in *n-2* wrote stash `[(n-2) AND 1] = [n AND 1]`. So restore and stash in
iteration *n* both address stash `[n AND 1]` and the code as it stands is consistent. Re-enabling the
`eor` would restore from the *other* bank's stash.

**Not yet verified in the emulator.** Do that (move the sprite to the screen edge and look for
trails in both banks) before touching it. The whole routine is replaced in Layer 3 anyway.
