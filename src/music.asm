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
\ *	  &C000  vgiplayer.asm: code and its resident decode state
\ *	         music.vgi, the tune
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
ORG &C000
GUARD HAZEL_WORK
.hazel_start

INCLUDE "lib/vgiplayer.asm"

\ tools/export_music.py: the CPC port's EDGEA.SKS through SongToYm,
\ ym2sn and vgipacker. TRUNCATED to what fits - see the layer doc.
.music_data
INCBIN "src/data/music.vgi"

.hazel_end

HAZEL_LOAD_PAGES = (hazel_end - hazel_start + 255) DIV 256

SAVE "MUSIC", hazel_start, hazel_end

PRINT "------"
PRINT "HAZEL - the VGI player and the tune"
PRINT "------"
PRINT "PLAYER size =", ~music_data - vgm_start
PRINT "TUNE size =", ~hazel_end - music_data
PRINT "LOAD PAGES =", HAZEL_LOAD_PAGES
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~HAZEL_WORK - P%
PRINT "------"
