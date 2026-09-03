\ ******************************************************************
\ *	bank0.asm
\ *	Sideways RAM bank 0 (slot SWRAM_DATA): the converted charset,
\ *	the C64 tiles, both maps, col_decode and the attack wave table. From
\ *	tools/export_tiles.py and tools/export_waves.py;
\ *	regenerate with the tool rather than editing src/data.
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank0_start

\\ Characters as four MODE 2 column planes: plane p at char_data + p*2048,
\\ char c row r at + c*8 + r, colour in the right-pixel bits (6,4,2,0).
\\ 256 chars x 8 rows x 4 planes = 8192 bytes.

.char_data
INCBIN "src/data/chars.bin"
ASSERT P% = char_data + 8192
PRINT "CHARACTER data =", ~char_data

\\ Each tile is 4x4 characters, row-major; 211 tiles x 16 bytes = 3376.

PAGE_ALIGN
.tile_data
INCBIN "src/data/tiles.bin"
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high, column-major, 302 columns (tiles.map + tiles2.map) = 1510 bytes.

PAGE_ALIGN
.map_data
INCBIN "src/data/map.bin"
.map_end
PRINT "MAP data =", ~map_data

\\ The C64 col_decode table: low 3 bits per-char colour (already applied to
\\ the planes), bit 4 = fatal to the player (Layer 4 reads this).

PAGE_ALIGN
.col_decode
INCBIN "src/data/col_decode.bin"
PRINT "COL_DECODE =", ~col_decode

\ The attack wave table: 9 bytes a wave, read a byte at a time by
\ wave_read, terminated by an $ff in the x position. anim_decode is the
\ 19 start/end frame pairs a wave's object byte picks its animation from.
\ Both from tools/export_waves.py.

PAGE_ALIGN
.wave_data
INCBIN "src/data/waves.bin"
.wave_end
PRINT "WAVE data =", ~wave_data

.anim_decode
INCBIN "src/data/anim_decode.bin"
PRINT "ANIM_DECODE =", ~anim_decode

.bank0_end

SAVE "BANK0", bank0_start, bank0_end

PRINT "------"
PRINT "BANK 0"
PRINT "------"
PRINT "DATA size =",~bank0_end-bank0_start
PRINT "------"
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"
