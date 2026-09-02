\ ******************************************************************
\ *	bank0.asm
\ *	Sideways RAM bank 0: C64 charset, tiles, both maps and raw sprite data.
\ ******************************************************************

\ ******************************************************************
\ * SWRAM DATA BANK
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank0_start

\\ Characters are 4x8 wide pixels and there are 256 in total = 2048 bytes (8 bytes each @ 2bpp) (tiles.chr)

PAGE_ALIGN
.char_data
INCBIN "data/tiles.chr.bin"
PRINT "CHARACTER data =", ~char_data

\\ Each tile is made up of 4x4 characters and there are 211 in total = 3376 bytes (16 bytes each) (tiles.til)

PAGE_ALIGN
.tile_data
INCBIN "data/tiles.til.bin"
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high vertically and 256 tiles wide = 1280 bytes (tiles.map)

PAGE_ALIGN
.map_data
INCBIN "data/tiles.map.bin"
PRINT "MAP data =", ~map_data

\\ Map2 is 5 tiles high vertically and 46 tiles wide = 230 bytes (tiles2.map)
\\ Map2 follows on from Map1 data - it's not a separate level!

.map2_data
INCBIN "data/tiles2.map.bin"
PRINT "MAP2 data =", ~map2_data

PAGE_ALIGN
.sprite_data
INCBIN "data/sprites.spr.bin"
PRINT "SPRITE data =", ~sprite_data

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

\ ******************************************************************
\ *	Any other files for the disc
\ ******************************************************************
