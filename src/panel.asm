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
IF GFX_NULA
IF GFX_CPC
INCBIN "src/data/panel-nula-cpc.bin"     \ the Amstrad port's own panel, decision 56
ELSE
INCBIN "src/data/panel-nula.bin"     \ the Amstrad port's own panel, decision 56
ENDIF
ELIF GFX_CPC
INCBIN "src/data/panel-cpc.bin"     \ the Amstrad port's own panel, decision 56
ELSE
INCBIN "src/data/panel.bin"     \ the Amstrad port's own panel, decision 56
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
ASSERT P% = TTL_KRTEXT

\ And behind them the redefine screen's text (Layer 9h, decision 71): five
\ labels and eight key names at eight glyphs each, then three messages at
\ sixteen, of which twelve are ever drawn. Written by tools/export_title.py
\ through the same font and the same assertions as the credits, so a word the
\ font cannot draw is a build error rather than a blank on the screen.
\ Read from bank 1, where the code is - a sideways bank reads main RAM
\ without paging anything.
.kr_text
INCBIN "src/data/title_kr.bin"
ASSERT P% - kr_text = KR_TEXT_BYTES

\ ---- and the screen's three tables, up here for the room ----------
\ These would rather be in bank 1 next to the code that reads them, and they
\ are here because that code came in 69 bytes over what bank 1's hole has
\ and these are 44 of them. Assembled, not generated: a measured internal key
\ number is a hardware fact and belongs where a person reads it.

\ ---- the bindable keys, and every number MEASURED -----------------
\ jsbeeb, Master, 2026-09-06, by OSBYTE 121 scanning from key 16 with the key
\ held down; docs/layer-9h-keyredef.md records the method and the run. Eight
\ of them cross-check exactly against the numbers src/main.asm already
\ carried from 2026-09-04 - Z 97, X 66, K 70, M 101, L 86, P 55, Q 16 and
\ ESCAPE 112 - which is what says the method was right.
\
\ SHIFT IS 0 AND THE OSBYTE SCAN CANNOT SEE IT: the MOS scan will not report
\ keys 0-2, so SHIFT and CTRL were measured through INKEY and calibrated on
\ Z instead - SHIFT is INKEY -1, CTRL is INKEY -2, Z is INKEY -98 and Z's
\ internal number is 97, so internal is the INKEY index less one. SHIFT is
\ bindable and makes a fine fire button; CTRL is not, and must not be - it is
\ this screen's own trigger.
\
\ THE ORDER IS THE NAMING ORDER: 0-25 are A-Z and their glyph is the index
\ plus one, which is why twenty-six of the thirty-five need no name at all;
\ 26-34 are the nine that want a word, in kr_text's name order.
\ SPACE IS ONE OF THEM (KC). It looked as though it could not be, SPACE
\ being what starts a game from the titles - but the two never meet: while
\ this screen is up it owns the keyboard and title_page's key_start is not
\ running, and kr_wait_up will not let the screen exit until SPACE is up
\ again, so a game cannot start on the way out either. In play SPACE means
\ nothing else at all.
.kr_keys
    EQUB 65, 100, 82, 50, 34, 67, 83, 84, 37, 69, 70, 86, 101
    \      A    B   C   D   E   F   G   H   I   J   K   L    M
    EQUB 85, 54, 55, 16, 51, 81, 35, 53, 99, 33, 66, 68, 97
    \     N   O   P   Q   R   S   T   U   V   W   X   Y   Z
    EQUB 57, 41, 25, 121, 0, 73, 98, 104, 72
    \     UP  DN  LT  RT  SH  RET  SP   /   :
ASSERT P% - kr_keys = KR_CANDS

\ Ask order -> joy_keys index. The screen asks LEFT RIGHT UP DOWN FIRE, which
\ is the order a player thinks in; joy_keys is in read_joystick's, which is
\ the C64's own $dc00 bit order and may not be disturbed.
.kr_order   EQUB JOY_LEFT, JOY_RIGHT, JOY_UP, JOY_DOWN, JOY_FIRE

\ Where each of the five CONTROL lines starts in the 228-byte block. They
\ begin at row 1: row 0 is the heading, which kr_build draws before the loop
\ and which is why these are one row further on than they look (decision 72).
.kr_rows    EQUB 38, 76, 114, 152, 190

ASSERT P% - kr_text = KR_TEXT_BYTES + KR_TAB_BYTES
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
