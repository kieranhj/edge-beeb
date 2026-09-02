# Layer 1 — graphics pipeline A: mechanical conversion (2026-09-02)

## What was done

1. **`tools/export_tiles.py`** converts the C64 charset offline into four MODE 2 *column
   planes* (`src/data/chars.bin`, 8K): plane *p* holds pixel column *p* of every character with
   the colour already in the right-pixel bits (6,4,2,0), which is exactly what the column buffer
   ORs in after its left shift. It also writes the tile definitions, the two maps concatenated
   (302 columns) and the C64 `col_decode` table unchanged.

2. **Colour is now per character, as on the C64.** Bit pair 00 → black, 01 → brown (`$d022`),
   10 → white (`$d023`), 11 → the character's own colour from `col_decode` (cyan, yellow, red,
   purple or green in this level). The 2019 build painted every 11 pixel green. C64 → BBC is the
   `C64_TO_BBC` table in `tools/bbc.py` (decision 11); brown goes to blue, as before.

3. **`scroll.asm` `plot_char_y`** reads the plane byte with `ora abs,X` instead of
   `ldy abs,X` + `ora abs,Y` through a 256-byte table: 4 cycles a byte, 160 bytes a frame, ~640
   cycles saved, and the four page-aligned `map_c64_to_beeb_p0-3` tables (1K) are gone from main
   RAM. `plane_hi` (zero page) is set once per frame to `HI(char_data) + 8 * (char_col AND 3)`.

4. **`tools/export_sprites.py`** writes `src/data/sprites.bin` in the Layer 3 proposal format:
   119 frames × two shifts × 7 × 21 bytes, then a bounding-box table. Colours: 01 → blue
   (`$d025`), 11 → white (`$d026`), 10 → the frame's `sprite_col_dcd` colour. **Nothing consumes
   it yet**: the plotter still reads the raw C64 bytes (moved to bank 1) and converts nibbles at
   plot time. Rewriting the plotter twice was not worth it; Layer 3 replaces plotter and data
   together. The box table says the opaque area is **44%** of the 7 × 21 cell on average.

5. **`tools/render_bbc.py`** renders chars, tiles, any map range, or the sprite sheet from
   `src/data` to PNG at 2:1 aspect (`tools/output/`, gitignored). `map 0 40` was compared against
   a jsbeeb screenshot of the same tiles: identical colours and shapes.

6. **Two sideways banks.** The planes fill bank 0 (`BANK0`, 13.5K: chars, tiles, map,
   `col_decode`), so the raw sprites moved to `BANK1` in slot 5. `load_bank` in `main.asm` loads
   either; `plot_sprite` is bracketed by paging slot 5 in and slot 4 back (`SWRAM_DATA` is the
   resting state, as in Paradroid).

## Facts established

- **OSFILE writes the file's catalogue addresses back into its parameter block after a load.**
  The second `load_bank` call therefore used `BANK1`'s own load address (`&8000`) and put the
  file into the paged-in DFS ROM: the sprite vanished and slot 5 read as zeros. `load_bank` now
  resets load = `&4000` and exec = 0 before every call. Found by paging slot 5 in from the jsbeeb
  MCP and reading `&82C0`.
- Bank 1's data does not show in the map render, so the check for a data change is
  `render_bbc.py` for tiles and a jsbeeb screenshot for sprites.
- Main RAM after this layer: code `&0E00-&13C0`, data to `&1813`, free `&27ED`. Bank 0 high water
  `&B500` (`&B00` free); bank 1 `&9DC0`.
- Per-character colours actually used by `col_decode`: C64 2, 3, 4, 5, 7. Character 0 is the
  star/blank char with colour 5 in hires mode.

## Rejected

- Chars as plain 4 bpp (16 B each, 4K) with the pixel column extracted at plot time: needs a
  shift or a second table per byte. The planes cost 4K more bank and nothing per frame.
- The CPC's "id in the low byte, row in the high byte" layout: it would need eight patched
  operands per character instead of two, because the plot loop indexes rows with X.

## Left for later

- The map still loops after 256 tiles (`tile_total` is 8-bit): Layer 2, with the level end.
- The palette is still the default (logical = physical): Layer 2 writes `&FE21`, including
  logical 8 → black for sprites.
