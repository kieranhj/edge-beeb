# Layer 0 — toolchain, source split and documentation (2026-09-02)

## What was done

1. **Source split.** The 1,572-line `edge-beeb.asm` became six files under `src/`, cut at exact
   line ranges and included in the original order so the assembled bytes could not move:

   | File | Contents |
   |---|---|
   | `main.asm` | constants, zero page, boot, the main loop, `move_pages`, the SAVEs, `!BOOT`, includes |
   | `scroll.asm` | `map_read`, `tile_update`, `tile_read_1-5`, `tile_cnt_bump`, `plot_char_y`, column buffer rotate and copy |
   | `sprite.asm` | `plot_sprite`, `calc_sprite_write_ptr`, `restore_background`, `stash_background` |
   | `keyboard.asm` | `read_keyboard` |
   | `tables.asm` | OSFILE block, multiply tables, nibble and pixel tables, the two stashes, sprite address tables |
   | `bank0.asm` | the SWRAM data bank: charset, tiles, both maps, raw sprites |

2. **Build script.** `build.ps1` (with `make.bat` as the wrapper) assembles `src/main.asm` into
   `build/EDGE.SSD`, writes the 200K padded copy and the listing, and launches b-em as a Master
   (`-m3`) with `-Run`. It passes `-D RELEASE=0|1` on every build; `main.asm` asserts the symbol,
   derives `DEV`, and carries a `DEBUG_ANY` that a release build asserts is zero. `!BOOT` is
   assembled by `main.asm` and stamps whether the build is DEV.

3. **Verification.** The old `make.bat` build was run first into a baseline SSD. After the split,
   the new SSD was byte-identical (`cmp`). After the `!BOOT` change the disc differs only in
   `!BOOT`; `Edge` and `BANK0` were extracted from both catalogues and compared equal.

4. **Removed.** `bin/` entirely (decision 10), the monolithic `edge-beeb.asm`, the committed
   `edge-beeb.ssd`, `run.bat`, `compile.txt`, `TODO.md` and `progress.md` (folded into `PLAN.md`
   and `BUGS.md`).

5. **Docs.** `CLAUDE.md` rewritten with the corrected facts; `PLAN.md`, `BUGS.md`,
   `docs/decisions.md` created.

## Facts established

- beebasm 1.11 at `..\..\Bin\beebasm.exe`; INCLUDE and INCBIN paths resolve from the working
  directory, so the build runs from the project root and the includes are written `src/...`.
- Main RAM: code `&0E00-&1396` (`&597` bytes), tables `&1397-&1BEE`, free `&2412` below `&4000`.
  Bank 0: `char_data &8000`, `tile_data &8800`, `map_data &9600`, `map2_data &9B00`,
  `sprite_data &9C00`, high water `&B9C0`.
- The five errors in the old docs (no sprite pipeline; Master not Model B; the `eor #1` item;
  palette never written; music is not Arkos on the C64) are recorded in `PROPOSAL.md` §1.

- **jsbeeb boots it.** `build/EDGE-200K.SSD` on the jsbeeb MCP's `Master` model: `!BOOT` runs,
  the level scrolls and the player sprite draws (screenshot taken at frame 756, about 15 s in).
  The MCP timed out on its first connection in the session and was fine after `/mcp` reconnect.

## Not done in this layer

- The full-strip redraw oracle and the raster tint debug flag: they need code that does not exist
  yet and belong with Layer 2.
