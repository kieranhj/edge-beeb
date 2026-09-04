\ ******************************************************************
\ *	andy.asm - ANDY's share of the tune, as its own disc file
\ ******************************************************************
\ *	ANDY is the Master's own 4K of private RAM at &8000-&8FFF, paged
\ *	in by BIT 7 of ROMSEL (&FE30) rather than by ACCCON. Measured in
\ *	jsbeeb 2026-09-04, from 6502 in main RAM because a BASIC session
\ *	cannot do it - BASIC is itself the ROM at &8000, so paging ANDY
\ *	in removes the interpreter mid-statement and the machine hangs:
\ *
\ *	    &FE30 = 4    write &AA to &8000, &BB to &9000
\ *	    &FE30 = &84  write &55 to &8000, &CC to &9000
\ *	    &FE30 = &84  &8000 reads &55, &9000 reads &CC
\ *	    &FE30 = 4    &8000 reads &AA, &9000 reads &CC
\ *
\ *	So it is 4K of storage of its own, it overlays only the LOW 4K of
\ *	whichever sideways bank is selected, and the bank keeps its own
\ *	&8000 underneath. That window is the busiest ground in the game -
\ *	bank 0's char_data starts there and the scroll reads it every
\ *	frame - so ANDY can only hold something read under its own paging,
\ *	in one place. One register stream of the tune is precisely that:
\ *	fetchbyte pages it in, reads a byte and the caller puts &FE30 back
\ *	(decision 48).
\ *
\ *	Its own disc file because ANDY is nobody's staging area and the
\ *	loader cannot unpack into it while the filing system is running -
\ *	see ANDY_STREAM in main.asm. tools/export_music.py decides what
\ *	goes here; it is whichever streams best-fit-decreasing put in the
\ *	ANDY region, and today that is the biggest single stream of the
\ *	eleven.
\ ******************************************************************

IF MUSIC_AKL = 0

CLEAR 0, &FFFF
ORG MUSIC_ANDY_BASE
GUARD MUSIC_ANDY_TOP
.andy_start
INCBIN "src/data/music_andy.bin"
.andy_end

SAVE "ANDY", andy_start, andy_end

PRINT "------"
PRINT "ANDY - the Master's private 4K, ROMSEL bit 7"
PRINT "------"
PRINT "TUNE STREAMS =", ~andy_end - andy_start
PRINT "FREE =", ~MUSIC_ANDY_TOP - andy_end
PRINT "------"

ENDIF
