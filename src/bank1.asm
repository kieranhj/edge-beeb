\ ******************************************************************
\ *	bank1.asm
\ *	Sideways RAM bank 1 (slot SWRAM_SPRITES): sprite data.
\ *	Still the raw C64 bytes (119 x 64), converted per nibble by the 2019
\ *	plotter; Layer 3 replaces both with src/data/sprites.bin.
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank1_start

.sprite_data
INCBIN "data/sprites.spr.bin"
PRINT "SPRITE data =", ~sprite_data

.bank1_end

SAVE "BANK1", bank1_start, bank1_end

PRINT "------"
PRINT "BANK 1"
PRINT "------"
PRINT "DATA size =",~bank1_end-bank1_start
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"
