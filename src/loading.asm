\ ******************************************************************
\ *	loading.asm - the loading screen, as two disc files
\ ******************************************************************
\ *	assets/TitlescreenBig.png through tools/export_loading.py: a full
\ *	MODE 2 screen, 160 x 256 logical pixels in eight colours, drawn at
\ *	&3000 while the sideways banks load behind it.
\ *
\ *	TWO FILES, top half and bottom, because a ZX0 stream may not be
\ *	overtaken by its own output and one for the whole 20K would have to
\ *	start above &8000 to stay ahead. The halves stage at LOAD_STREAM,
\ *	below the screen, where there is room for one but not for both.
\ *	See export_loading.py and decision 38.
\ *
\ *	tools/make_disc.py replaces both with their ZX0 streams and moves
\ *	the catalogue load address to LOAD_STREAM; the addresses assembled
\ *	here are what the picture unpacks TO, and the boot loader carries
\ *	them itself.
\ ******************************************************************

CLEAR 0, &FFFF
ORG LOADSCR_ADDR
.loadsc1_start
INCBIN "src/data/loading1.bin"
.loadsc1_end
ASSERT loadsc1_end = LOADSCR_ADDR2

ORG LOADSCR_ADDR2
.loadsc2_start
INCBIN "src/data/loading2.bin"
.loadsc2_end
ASSERT loadsc2_end = &8000

SAVE "LOADSC1", loadsc1_start, loadsc1_end
SAVE "LOADSC2", loadsc2_start, loadsc2_end

PRINT "------"
PRINT "LOADING SCREEN - MODE 2, ", ~loadsc2_end - loadsc1_start, "bytes at", ~LOADSCR_ADDR
PRINT "------"
