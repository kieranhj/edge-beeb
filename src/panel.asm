\ ******************************************************************
\ *	panel.asm - the status panel image, as its own disc file
\ ******************************************************************
\ *	tools/export_panel.py renders the C64's five-row status bar to
\ *	MODE 2 once, at 1:1. It is 3,200 bytes that are read EXACTLY
\ *	TWICE - once into each bank's &3000 at boot - and never again.
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
INCBIN "src/data/panel.bin"
.panel_file_end
ASSERT panel_file_end - panel_file = PANEL_BYTES

SAVE "PANEL", panel_file, panel_file_end
