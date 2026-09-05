\ ******************************************************************
\ *	panel.asm - the status panel image, as its own disc file
\ ******************************************************************
\ *	tools/export_panel.py renders the C64's five-row status bar to
\ *	MODE 2 once, at 1:1. It is 3,200 bytes that are read EXACTLY
\ *	TWICE - once into each bank's &3000 at boot - and never again.
\ *
\ *	Under GFX_CPC it is the Amstrad port's panel instead (decision 56).
\ *	That one is FOUR character rows to the C64's five, so it sits in
\ *	rows 0-3 and row 4 is black; the file is the same 3,200 bytes and
\ *	the score, high score and lives land in the same cells, so nothing
\ *	below this line changes.
\ *
\ *	It used to live in sideways bank 3, which is the one bank the
\ *	tune wants: bank 3 and HAZEL are adjacent in the address map, so
\ *	the .vgi streams that span the join have to start there. Boot-time
\ *	data has no business holding that ground, so the image is a disc
\ *	file now and panel_init unpacks it straight into the screen -
\ *	twice, once per bank - out of the stream still sitting at
\ *	LOAD_STREAM. Nothing keeps a copy (decision 47).
\ *
\ *	As with the loading screen, the address assembled here is where
\ *	the picture unpacks TO; tools/make_disc.py replaces the file with
\ *	its ZX0 stream and moves the catalogue load address to
\ *	LOAD_STREAM.
\ ******************************************************************

CLEAR 0, &FFFF
ORG PANEL_ADDR
.panel_file
IF GFX_CPC
INCBIN "src/data/panel-cpc.bin"     \ the Amstrad port's own panel, decision 56
ELSE
INCBIN "src/data/panel.bin"
ENDIF
.panel_image_end
ASSERT panel_image_end - panel_file = PANEL_BYTES
ASSERT panel_image_end = TTL_EXTRA

\ And riding on the end of it: the titles' second credit set (Layer 9e,
\ decision 53). &3C80-&3FFF is 896 bytes above the panel and below the play
\ buffer that NEITHER rupture cycle fetches - real RAM in both banks that
\ nothing has ever claimed - and this file is already being unpacked into
\ both banks' &3000 at boot, so 190 bytes on the end of it arrive there for
\ nothing. Bank 3, where the font and the plotter live, has 45 bytes left in
\ a -Cpc build.
.ttl_cred_bbc
INCBIN "src/data/title_extra.bin"
ASSERT P% - ttl_cred_bbc = TITLE_LINE_LEN * TITLE_LINES
ASSERT P% = TTL_SCROLL

\ And after them the zoom scroller's message, out of assets/scrolltext.txt
\ (Layer 9f). It used to sit behind the font in bank 1, which has eleven
\ bytes of headroom - no use at all for something a person is meant to
\ edit. Here it has hundreds, and the build prints how many.
.ttl_scroll
INCBIN "src/data/scroll.bin"
.panel_file_end
ASSERT panel_file_end <= screen_start

PRINT "------"
PRINT "SCROLLTEXT =", panel_file_end - ttl_scroll - 1, "characters, HEADROOM =", screen_start - panel_file_end
PRINT "------"

SAVE "PANEL", panel_file, panel_file_end
