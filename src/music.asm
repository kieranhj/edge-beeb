\ ******************************************************************
\ *	music.asm - the HAZEL image: the VGI player and the tune
\ ******************************************************************
\ *	HAZEL is the Master's 8K of filing-system RAM at &C000-&DFFF,
\ *	paged in by ACCCON bit 3 (Y) over the MOS's VDU driver. It is the
\ *	only RAM left: main RAM below &2000 has tens of bytes and every
\ *	sideways bank is spoken for.
\ *
\ *	Three things make it the right home rather than a desperate one:
\ *
\ *	  - It does not overlap the sideways window, so the player is
\ *	    reachable from the IRQ no matter which bank the interrupted
\ *	    code had paged in - and the IRQ can fire inside the sprite
\ *	    engine, which pages 5, 6 and 7 as it goes.
\ *	  - The MOS's IRQ entry is at &E59E (read out of the vector at
\ *	    &FFFE on a Master, not recalled), which is ABOVE HAZEL, so
\ *	    paging HAZEL in cannot break interrupt dispatch. We only page
\ *	    it in inside our own handler anyway.
\ *	  - Its resident content is the filing system's workspace, and the
\ *	    filing system is finished with the moment the banks are loaded.
\ *	    MUSIC is therefore loaded LAST of the five files.
\ *
\ *	  &C000  the HIGH HALF of the tune. Its low half is at the top of
\ *	         sideways bank 3, ending exactly at &C000, and the two are
\ *	         one contiguous block: bank 3 and HAZEL are paged by
\ *	         different registers over different windows, so both are
\ *	         visible at once and the player reads across the join
\ *	         without knowing it is there.
\ *	  &D200  vgiplayer.asm: code and its resident decode state
\ *	  &D500  the player's ring workspace, 11 x 256, page aligned and
\ *	         reaching exactly to &DFFF. Not in the file: it is scratch,
\ *	         and vgm_init zeroes what it needs.
\ *
\ *	The player is lib/vgiplayer.asm from Repos/vgm-player-bbc, taken
\ *	unaltered. It decodes one byte per register stream per frame, so
\ *	its cost is flat rather than the VGC player's spiky RLE+LZ4 -
\ *	which is what a frame already at 90% needs. See docs/layer-7-music.md.
\ ******************************************************************

CLEAR 0, &FFFF
ORG HAZEL_BASE
GUARD MUSIC_PLAYER
.hazel_start

\ tools/export_music.py: the CPC port's EDGEA.SKS through SongToYm, ym2sn
\ and vgipacker, cut at MUSIC_LO_SIZE. TRUNCATED to what fits - see the
\ layer doc for how much is missing and what it would take.
.music_hi
INCBIN "src/data/music_hi.bin"
.music_hi_end
ASSERT music_hi_end <= MUSIC_PLAYER

\ The guard was on the player's base so the tune could not run into it;
\ now put the player there. beebasm guards one address, so it has to be
\ cleared before anything is assembled at it.
CLEAR MUSIC_PLAYER, MUSIC_PLAYER+1
ORG MUSIC_PLAYER
GUARD HAZEL_WORK

INCLUDE "lib/vgiplayer.asm"

.hazel_end

HAZEL_LOAD_PAGES = (hazel_end - hazel_start + 255) DIV 256

SAVE "MUSIC", hazel_start, hazel_end

PRINT "------"
PRINT "HAZEL - the VGI player and the tune"
PRINT "------"
PRINT "PLAYER size =", ~hazel_end - vgm_start
PRINT "TUNE size =", ~MUSIC_LO_SIZE + (music_hi_end - music_hi)
PRINT "TUNE ROOM LEFT =", ~MUSIC_PLAYER - music_hi_end
PRINT "LOAD PAGES =", HAZEL_LOAD_PAGES
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~HAZEL_WORK - P%
PRINT "------"
