# Bugs

Open defects, with the evidence and what has been ruled out. Fixed entries stay for what they
ruled out. Index first, detail below.

| # | Status | Summary |
|---|---|---|
| 1 | gone (Layer 3) | "Double-buffer stash restore reads the wrong buffer" (`eor #1` commented out in `sprite.asm`). The routine it was about no longer exists |
| 2 | fixed (Layer 3) | No sprite clipping: `x_pos >= 80` indexed past `mult8_*`. The engine now clips the frame's box to 80 columns x 160 scanlines at all four edges (decision 2) |
| 3 | open | `read_keyboard` has no bounds; the C64 clamps x to `$10-$9b` and y to `$5a-$e5`. Harmless now that sprites clip, but the player will run off the edge until Layer 4 ports the bounds |
| 4 | fixed (Layer 2) | The map looped after 256 tiles; `map_read` now wraps at the 302-column end (decision 14) |

## 1. The `eor #1` that TODO.md wanted re-enabled — gone with the plotter

**Closed 2026-09-03, unverified and now unverifiable**: Layer 3 replaced `restore_background` and
`stash_background` outright. The engine that took their place keeps per-bank save state indexed
`bank*8 + slot` and the restore replays the draw's own recorded walk, so there is no parity to get
wrong. The analysis below is kept only for what it ruled out.


`src/sprite.asm`, `restore_background`, two commented-out `eor #1` lines. The 2026-03 TODO said the
restore "reads the wrong stash buffer half the time" and should have the `eor` put back.

Reading the loop: `&FE34` flips every iteration, so the bank being *drawn* in iteration *n* has
parity `char_col AND 1`. The sprite in that bank was last drawn in iteration *n-2*, and
`stash_background` in *n-2* wrote stash `[(n-2) AND 1] = [n AND 1]`. So restore and stash in
iteration *n* both address stash `[n AND 1]` and the code as it stands is consistent. Re-enabling the
`eor` would restore from the *other* bank's stash.

**Not yet verified in the emulator.** Do that (move the sprite to the screen edge and look for
trails in both banks) before touching it. The whole routine is replaced in Layer 3 anyway.
