\ ******************************************************************
\ *	EDGE GRINDER
\ ******************************************************************

\ RELEASE is a beebasm command-line symbol (-D RELEASE=0 or 1); build.ps1
\ passes it on every build. beebasm has no IFDEF, so there is no default here.
ASSERT RELEASE=0 OR RELEASE=1
DEV = 1-RELEASE

\ Debug flags. Each must be off under RELEASE; add new ones to DEBUG_ANY and
\ to the !BOOT stamp at the bottom of this file so a build says what it is.
\ MUSIC_AKL is stamped there too, but it is not one of these: it is legal
\ under RELEASE and so is deliberately not in DEBUG_ANY.
DEBUG_COLL = 0              ; collisions never take a life (the C64 source's
                            ; own "patch me out to disable collisions!").
                            ; OFF in DEV too: dying is the normal case
DEBUG_TIMING = DEV          ; the frame meter: see src/timing.asm
DEBUG_ANY = DEBUG_COLL OR DEBUG_TIMING
IF RELEASE
    ASSERT DEBUG_ANY=0
ENDIF

_DOUBLE_BUFFER = TRUE

\ ******************************************************************
\ *	OS defines
\ ******************************************************************

osfile = &FFDD
oswrch = &FFEE
osasci = &FFE3
osbyte = &FFF4
osword = &FFF1
osfind = &FFCE
osgbpb = &FFD1
osargs = &FFDA
osrdch = &FFE0

\\ Palette values for ULA
PAL_black	= (0 EOR 7)
PAL_blue	= (4 EOR 7)
PAL_red		= (1 EOR 7)
PAL_magenta = (5 EOR 7)
PAL_green	= (2 EOR 7)
PAL_cyan	= (6 EOR 7)
PAL_yellow	= (3 EOR 7)
PAL_white	= (7 EOR 7)

MODE2_PIXEL_00  = &00
MODE2_PIXEL_01  = &01
MODE2_PIXEL_02  = &04
MODE2_PIXEL_03  = &05
MODE2_PIXEL_04  = &10
MODE2_PIXEL_05  = &11
MODE2_PIXEL_06  = &14
MODE2_PIXEL_07  = &15

MODE2_PIXEL_10  = MODE2_PIXEL_01<<1
MODE2_PIXEL_20  = MODE2_PIXEL_02<<1
MODE2_PIXEL_30  = MODE2_PIXEL_03<<1
MODE2_PIXEL_40  = MODE2_PIXEL_04<<1
MODE2_PIXEL_50  = MODE2_PIXEL_05<<1
MODE2_PIXEL_60  = MODE2_PIXEL_06<<1
MODE2_PIXEL_70  = MODE2_PIXEL_07<<1

MODE2_PIXEL_LEFT_MASK = &AA
MODE2_PIXEL_RIGHT_MASK = &55

\ Internal key numbers, every one MEASURED with OSBYTE 121 in a BASIC
\ session holding the key, never recalled: they are hardware facts and
\ getting one wrong is silent.
IKN_z = 97
IKN_x = 66
IKN_k = 70
IKN_m = 101
IKN_l = 86
IKN_p = 55
IKN_q = 16
IKN_escape = 112            ; the MOS interrupt is gone, so it is just a key

\ ******************************************************************
\ *	GAME defines
\ ******************************************************************

BG_COL_0 = PAL_black
BG_COL_1 = PAL_blue
BG_COL_2 = PAL_white
BG_COL_3 = PAL_green          ; PAL_red or PAL_cyan also look OK

BG_PIX_0 = MODE2_PIXEL_00
BG_PIX_1 = MODE2_PIXEL_04
BG_PIX_2 = MODE2_PIXEL_07
BG_PIX_3 = MODE2_PIXEL_02

SPRITE_PIX_0 = MODE2_PIXEL_00   ; actually transparent
SPRITE_PIX_1 = MODE2_PIXEL_05 OR MODE2_PIXEL_50 ; magenta (black on C64)
SPRITE_PIX_2 = MODE2_PIXEL_01 OR MODE2_PIXEL_10 ; red
SPRITE_PIX_3 = MODE2_PIXEL_03 OR MODE2_PIXEL_30 ; yellow (white on C64)

GAME_LIVES = 3                  ; the C64's main_init

KEY_LEFT = IKN_z
KEY_RIGHT = IKN_x
KEY_UP = IKN_k
KEY_DOWN = IKN_m
KEY_FIRE = IKN_l
KEY_PAUSE = IKN_p           ; decision 32
KEY_ABORT = IKN_escape      ; and only while paused, as the C64 has it
KEY_MUTE = IKN_q            ; decision 39. Read in the VSync handler, so it
                            ; works wherever the foreground happens to be

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

MACRO BG_PIXEL c
IF c=1
    EQUB BG_PIX_1
ELIF c=2
    EQUB BG_PIX_2
ELIF c=3
    EQUB BG_PIX_3
ELSE    
    EQUB BG_PIX_0
ENDIF
ENDMACRO


MACRO CRTC r, v
    lda #r : sta CRTC_ADDR
    lda #v : sta CRTC_DATA
ENDMACRO

MACRO PAGE_ALIGN
H%=P%
ALIGN &100
PRINT "Skipping ", P%-H%, "bytes"
ENDMACRO

\ Close off one phase of the main loop into the TIM_ slot named. Four
\ bytes and ~80 cycles here, and nothing at all without DEBUG_TIMING;
\ the work is in bank 0. See src/timing.asm.
MACRO TIMMARK slot
IF DEBUG_TIMING
    lda #slot
    jsr tim_mark
ENDIF
ENDMACRO

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

screen_start = &4000
screen_size = &4000
screen_top = screen_start + screen_size
row_stride = 640

column_buffer = &400        ; 160 bytes for right hand column
column_size = 160

\\ The background collision character map (decision 24). The C64 reads the
\\ character codes back out of its own screen; we draw pixels, so scroll.asm
\\ writes them here as it plots and player.asm reads them. 40 columns as a
\\ ring, 20 rows of the play area, the same grid the C64's screen has.
\\ &04A0-&07FF is the language workspace: BASIC's, and ours once *RUN has
\\ handed over. Verified in jsbeeb - a sentinel across the whole of it
\\ survives 3,000 fields of the running game untouched.
COLL_COLS = 40
COLL_ROWS = 20
coll_map = &04A0
ASSERT coll_map >= column_buffer + column_size
ASSERT coll_map + COLL_COLS * COLL_ROWS <= &0800

SCORE_DIGITS = 6

\\ Game state lives at &0800, not in the code image. The C64 keeps the
\\ same block in its tape buffer at $0340 for the same reason: it is RAM
\\ that needs no initial value, so it costs nothing to put it where the
\\ image is not. &0800-&0BFF is the MOS's sound, serial and soft-key
\\ workspace, which is ours with the MOS interrupt gone - verified in
\\ jsbeeb, a sentinel across all four pages surviving 1,500 fields of
\\ the running game. Declared at the bottom of this file, outside the
\\ SAVE, so none of it is written to the disc.
GAME_STATE = &0800
GAME_STATE_TOP = &0C00

SWRAM_DATA = 4              ; bank 0: chars, tiles, map, col_decode (resting state)
SWRAM_SPRITES0 = 5          ; bank 1: sprite data, pixel shift 0
SWRAM_SPRITES1 = 6          ; bank 2: the same, shift 1. The engine adds the
                            ; shift to SWRAM_SPRITES0, so these must be adjacent.
SWRAM_COMPILED = 7          ; bank 3: compiled sprite bodies, both shifts together
ASSERT SWRAM_SPRITES1 = SWRAM_SPRITES0 + 1
\ Slots 4-7 are the Master's 64K of sideways RAM; 8-F hold the MOS ROMs and
\ 0-3 are the cartridge slots, empty on a stock machine. Measured in jsbeeb:
\ a pattern written to slot 7 survives a page out and back, and the same
\ write to slot 3 vanishes.
ASSERT SWRAM_COMPILED <= 7

SPR_SAVE = &2000            ; 8 slots x 256 B x 2 banks, saved background

\ HAZEL: the Master's 8K of filing-system RAM at &C000-&DFFF, paged in by
\ ACCCON bit 3 (Y). Layer 7 puts the music player and the tune there - it is
\ the only RAM left, and unlike a sideways bank it does not collide with the
\ window the sprite engine is paging while the IRQ fires. See src/music.asm.
HAZEL_BIT   = 8
HAZEL_BASE  = &C000
HAZEL_WORK  = &D500         ; the VGI player's 11 x 256 ring, exactly to &DFFF
ASSERT HAZEL_WORK + 11 * 256 = &E000

\ THE TUNE, IN FOUR PLACES (decision 48)
\
\ EDGEA packs to 23,514 bytes of .vgi and there is no hole that size on this
\ machine. But a .vgi is not one blob: it is ELEVEN INDEPENDENT STREAMS, one
\ per SN76489 register, and the player reads exactly one byte from each per
\ frame through its own pointer. So each stream has to be contiguous and the
\ tune does not, and the whole 349 seconds goes in four regions:
\
\   A     &9100-&D2FF   the tail of bank 3 running on into HAZEL. Both are
\                       VISIBLE AT THE SAME TIME - they are paged by
\                       different registers over different windows - so a
\                       stream may cross &C000 and the player never learns
\                       the join is there. It ships as two files: below
\                       &C000 in BANK3 (music_lo, padded to meet the join
\                       exactly) and above it in MUSIC (music_hi).
\   ANDY  &8000-&8FFF   the Master's own 4K, ROMSEL bit 7 - measured in
\                       jsbeeb, 2026-09-04: it overlays the LOW 4K of
\                       whichever sideways bank is selected and leaves the
\                       rest of the window alone. That is the busiest ground
\                       we have, so nothing an inner loop walks could live
\                       here; a music stream read a few times a frame from
\                       an interrupt is exactly the right tenant.
\   B1    &B900-&BFFF   the tail of sideways bank 1, above the sprite
\   B2    &BA00-&BFFF   data, and the same for bank 2 a page higher - the
\                       CPC artwork's sprite bank 2 reaches &B941.
\
\ tools/export_music.py does the placement and writes src/data/music_map.asm
\ - eleven addresses and eleven ROMSEL bytes - which ASSERTs these constants
\ against its own. lib/vgiplayer.asm reads that map under VGI_SPLIT and pages
\ each stream's region in before every raw byte it fetches.
MUSIC_A_BASE    = &9100     ; region A: bank 3's tail, ...
MUSIC_A_JOIN    = HAZEL_BASE                    ; ... across this join, ...
MUSIC_A_TOP     = &D300     ; ... to here, where the player's code starts
MUSIC_ANDY_BASE = &8000
MUSIC_ANDY_TOP  = &9000
MUSIC_B1_BASE   = &B900
MUSIC_B2_BASE   = &BA00     ; higher than B1's: the CPC artwork's
                            ; sprite bank 2 reaches &B941
MUSIC_LO_SIZE   = MUSIC_A_JOIN - MUSIC_A_BASE   ; what BANK3 carries
MUSIC_PLAYER    = MUSIC_A_TOP
ASSERT MUSIC_A_BASE >= &8000
ASSERT MUSIC_ANDY_TOP - MUSIC_ANDY_BASE = &1000

\ ANDY's ROMSEL byte. Bit 7 is what selects it; the bank number underneath is
\ irrelevant while it is set, and bank 3 is what the music update has paged
\ anyway.
ANDY_ROM = &80 OR SWRAM_COMPILED

\ The VGI player's own state - 96 bytes - in the MOS user-font page, which
\ this game never writes. It is there rather than in HAZEL beside the code
\ because HAZEL is the scarce thing and main RAM at &0C00 is not, and because
\ fetchbyte reads it with the sideways window pointed at a music stream.
VGI_STATE = &0C00
VGI_SPLIT = 1

\ MUSIC_AKL picks the OTHER music subsystem, for the comparison Layer 7 left
\ open: src/aklplayer.asm replays the Arkos tracker data directly and
\ src/ay2sn.asm converts AY registers to the SN76489 every frame, instead of
\ lib/vgiplayer.asm decoding a pre-converted register log. It is passed on the
\ command line beside RELEASE, because beebasm has no IFDEF and refuses a
\ symbol defined twice, so main.asm cannot carry a default.
\
\ The whole subsystem then fits inside HAZEL - player, converter, tables and
\ the WHOLE 349-second tune - so bank 3's music_lo disappears and its 8,960
\ bytes come free. The tune is not truncated in this build.
MUSIC_AKL_SONG = &CC00      ; the tracker data; tools/export_music_akl.py
ASSERT MUSIC_AKL_SONG > HAZEL_BASE
ASSERT MUSIC_AKL_SONG < &E000

\ GFX_CPC builds the game from the Amstrad CPC port's artwork instead of the
\ C64's - every sprite frame, every character - for the comparison decision 41
\ left open. Smila redrew the lot in mode 0's sixteen colours, and the CPC's
\ frame, character and tile NUMBERS are the C64's exactly, so nothing but the
\ pixels changes: the tile table, the map, col_decode, the wave table and
\ dp_dcd are shared. Passed on the command line beside RELEASE for the same
\ reason: beebasm has no IFDEF and refuses a symbol defined twice.
\
\ tools/export_tiles.py --cpc and tools/export_sprites.py --cpc write the
\ data; tools/render_bbc.py --cpc renders it back for checking.
ASSERT GFX_CPC=0 OR GFX_CPC=1

\ Build flag for lib/vgiplayer.asm, which the library expects on the command
\ line; set here instead so a bare beebasm invocation cannot get it wrong.
\ 0 is the compact looped decoder, 1 the unrolled one - half a K more code
\ for about 300 cycles a field.
VGI_UNROLL = 0

\ Sprites are SCREEN space and do not take the scroll's half-byte bank
\ phase, so this is 0. Both banks are drawn at the same origin
\ (corner_addr + 8) and displayed at the same CRTC address - the
\ picture's one-pixel offset is in the map content, not in the window -
\ so the same sprite bytes at the same address stand still under both.
\ Set it to 1 if that turns out to be the wrong way round: a sprite
\ that should be still would then shimmer one pixel at 50 Hz.
SPR_PHASE_MASK = 0

\ Hardware
CRTC_ADDR     = &FE00
CRTC_DATA     = &FE01
VIDEO_ULA_PAL = &FE21
IRQ1V         = &0204
SYS_VIA_T1CL  = &FE44
SYS_VIA_T1CH  = &FE45
SYS_VIA_T1LL  = &FE46
SYS_VIA_T1LH  = &FE47       ; latch only - does not reload the counter
SYS_VIA_ACR   = &FE4B
SYS_VIA_IFR   = &FE4D
SYS_VIA_IER   = &FE4E
USR_VIA_IER   = &FE6E
KBD_PORTB     = &FE40       ; addressable latch: (value << 3) | line
KBD_DDRA      = &FE43
KBD_ORA       = &FE4F       ; port A, no handshake
KBD_LATCH_OFF = &03         ; line 3 = 0: stop the free-run scan
KBD_LATCH_ON  = &0B         ; line 3 = 1: hand it back
KBD_DDRA_SCAN = &7F         ; PA0-PA6 out (key number), PA7 in

\ Frame geometry: 39 rows = 312 scanlines, the MODE 2 shape.
\ Cycle A = the panel, cycle B = play area + everything down to VSync.
PANEL_ROWS  = 5             ; C64 status bar: rows 0-4
PLAY_ROWS   = 20            ; C64 playfield: rows 5-24
PANEL_R4    = PANEL_ROWS - 1
PLAY_R4     = 39 - PANEL_ROWS - 1          ; 33
PLAY_R7     = 34 - PANEL_ROWS              ; VSync at absolute row 34, as MODE 2
\ The panel lives INSIDE the shadow-switched region and is drawn into both
\ banks (decision 17). It was at &2000 first, which jsbeeb displayed under
\ both shadow states and b-em showed as garbage every other frame: what the
\ video circuit fetches below &3000 with the D bit set is emulator-dependent,
\ so nothing displayed may live there. Every write to the panel goes to both
\ banks: see panel_init.
PANEL_ADDR  = &3000
PANEL_BYTES = PANEL_ROWS * row_stride      ; 3200, to &3C7F
ASSERT PANEL_ADDR + PANEL_BYTES <= screen_start

\ The starfield (Layer 9c): ten stars standing still on the screen while
\ the level scrolls under them. The code and the tables are in bank 1;
\ what is here is the per-bank record of which of them are on screen, one
\ byte a star, the banks STAR_BANK apart so that &FE34's X bit shifts
\ twice into the index. The stars are the CPC port's, not the C64's -
\ see src/bank1.asm.
STAR_COUNT = 10
STAR_BANK  = 16             ; stride between the two banks' flags
ASSERT STAR_BANK >= STAR_COUNT
\ The loading screen (Layer 9a): a full MODE 2 picture in main RAM, shown
\ while the banks load. It is the MOS's own screen address, because the
\ mode change now happens FIRST and the picture is simply what MODE 2 is
\ displaying. Two halves, because of where their streams have to sit.
LOADSCR_ADDR  = &3000
LOADSCR_ADDR2 = &5800       ; halfway: 16 of the 32 character rows
ASSERT LOADSCR_ADDR2 - LOADSCR_ADDR = 16 * row_stride

\ Where a ZX0 stream is staged before it is unpacked (decision 38).
\ LOAD_STREAM is main RAM below the screen, the only ground the loading
\ screen's own stream can use: ZX0 unpacks forwards, so a stream may not be
\ overtaken by its own output, and one covering the whole 20K screen would
\ have to start above &8000 to stay ahead of it. It is also the ceiling of
\ the code image - the depacker is boot code and is allowed to run past
\ SPR_SAVE's base, which nothing reads until the game starts.
\ DEPK_STREAM is the SHADOW screen, free the whole time the picture is up in
\ main, and roomy: the four bank streams and the music's go there.
LOAD_STREAM = &2200
DEPK_STREAM = &3000
\ ANDY's stream needs a staging address of its own, because it is the one
\ file that cannot be unpacked when it is loaded: the depacker would be
\ writing into ANDY while the filing system was still running, and nothing
\ says the filing system does not use ANDY itself. So it is loaded before
\ MUSIC, sits here through MUSIC's load, and is unpacked afterwards, when
\ the disc is finished with for good. It shares the shadow screen with
\ DEPK_STREAM, above everything that stages there.
ANDY_STREAM = &6800
\ And where !BOOT is ASSEMBLED - it is never loaded anywhere, it is a disc
\ file the MOS *EXECs. Inside the sprite saves, which do not exist at
\ assembly time and are not written until the first sprite is drawn.
BOOT_STAGE  = &2400
CODE_TOP    = LOAD_STREAM   ; and &2000-&2FFF is the Layer 3 sprite saves,
                            ; which boot code may sit in and boot streams fill

\ T1 runs at 1 MHz: one scanline = 64 ticks. Fire 1 lands on A row 2,
\ fire 2 on B row 2 (see rupture.asm). -4 scanlines for the CA1 service
\ latency measured in Paradroid; the windows are 4 and 33 rows wide.
SL      = 64
T1_TUNE = -4 * SL
T1_I1   = (5 + 2) * 8 * SL - 2 + T1_TUNE   ; VSync (row 34) -> A row 2
T1_I2   = 5 * 8 * SL - 2                   ; A row 2 -> B row 2
T1_I3   = 250 * SL                         ; B row 2 -> never (VSync restarts T1 first)
ASSERT T1_I3 > (PLAY_R7 - 2) * 8 * SL
ASSERT T1_I3 < 65536

FRAME_LOCK = 2              ; fields per game frame: 25 Hz


\ ******************************************************************
\ *	The titles page (Layer 6e): four CRTC cycles, two hardware
\ *	scrolled zoom bands, one in each shadow bank
\ ******************************************************************
\ *	The C64's 5-row status bar and 20 rows of titles are our panel and
\ *	our play area, so its rows 5-24 are our play rows 0-19 and the page
\ *	transcribes 1:1 with nothing re-centred:
\ *
\ *	  cycle A  abs  0-4    5 rows, all shown    panel, &3000, MAIN
\ *	  cycle B  abs  5-11   7 rows, 6 shown      top band, ring in MAIN
\ *	  cycle C  abs 12-18   7 rows, 6 shown      credits, &4000, SHADOW
\ *	  cycle D  abs 19-38  20 rows, 6 shown      bottom band, ring in SHADOW
\ *
\ *	The blank 7th row of B and C is the C64's own blank row either side
\ *	of the credits, and B's is where the display bank is switched: it is
\ *	fetched by nobody, so the write has a whole row of slack.
\ *
\ *	The bands are hardware-scrolled by R12/R13, which needs a ring, and
\ *	the display wrap gives exactly one per bank: at 8K it is &6000-&7FFF,
\ *	1,024 byte columns against the 480 a six-row band shows. Measured in
\ *	jsbeeb 2026-09-04 - the four sizes are 20K, 16K, 10K and 8K, and 8K
\ *	is latch line 4 high, line 5 low. See CLAUDE.md.
TTL_RING      = &6000
TTL_RING_SIZE = &2000
TTL_CRED      = screen_start        ; the credits block, 6 rows, SHADOW
TTL_BAND_ROWS = 6                   ; zoom cells high, and CRTC rows displayed
TTL_BAND_CELLS = 40                 ; 80 byte columns: the band is full width
TTL_CELL      = 16                  ; 2 byte columns x 8 scanlines
TTL_CYC_ROWS  = 7                   ; cycles B and C: 6 shown, 1 blank
TTL_PANEL_R4  = PANEL_ROWS - 1
TTL_BAND_R4   = TTL_CYC_ROWS - 1
TTL_LAST_R4   = 39 - PANEL_ROWS - 2 * TTL_CYC_ROWS - 1      ; cycle D: 19
TTL_R7        = 34 - PANEL_ROWS - 2 * TTL_CYC_ROWS          ; VSync, abs row 34
ASSERT TTL_R7 > TTL_BAND_R4         ; so R7 is a constant: it cannot fall in A, B or C
ASSERT TTL_R7 < TTL_LAST_R4
ASSERT TTL_RING + TTL_BAND_ROWS * row_stride <= TTL_RING + TTL_RING_SIZE
ASSERT TTL_CRED + TTL_BAND_ROWS * row_stride <= TTL_RING

\ Five T1 fires instead of the game's two. The first two intervals are the
\ game's own - cycle A is the same 5 rows and B starts in the same place.
\   fire 1  abs  2   A row 2   R4 for A, R6 and R12/13 for B
\   fire 2  abs  7   B row 2   R4 for B (C inherits it), R6 and R12/13 for C
\   fire 3  abs 11   B row 6   display bank -> SHADOW, in a blank row
\   fire 4  abs 12   C row 0   R6 and R12/13 for D, then the first raster
\   fire 5  abs 17   C row 5   the second raster
\   fire 6  abs 20   D row 1   R4 for D
\
\ Fire 6 exists because R4 must be written INSIDE its own cycle and every
\ other candidate is outside D. Fire 5 is still in C, where R4 = 19 would
\ stretch C to twenty rows; and the VSync handler is too late in a worse
\ way - with R4 still 6 from cycle C, D would never reach R7 = 15, so
\ VSync would never happen and the handler that was to fix it would never
\ run. Measured the hard way: the first build hung in field_wait.
TTL_T1_I3 = 4 * 8 * SL - 2          ; fire 2 -> fire 3
TTL_T1_I4 = 1 * 8 * SL - 2          ; fire 3 -> fire 4
TTL_T1_I5 = 5 * 8 * SL - 2          ; fire 4 -> fire 5
TTL_T1_I6 = 3 * 8 * SL - 2          ; fire 5 -> fire 6


\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &00
GUARD &9F

.tile_cnt       skip 1      ; which column within a tile
.tile_total     skip 1      ; how many tiles have we covered?

.char_col       skip 1      ; incremented per pixel / tick - NEED BETTER NAME!

.corner_addr    skip 2      ; address of top left corner of screen buffer
.crtc_addr      skip 2      ; start address of visible screen in CRTC chars

.read_ptr       skip 2      ; generic read ptr
.write_ptr      skip 2      ; generic write ptr

.sprite_idx     skip 1      ; temp for the panel test pattern

.x_count        skip 1      ; temp for sprite_plot
.y_count        skip 1      ; temp for sprite_plot

\\ Sprite engine (src/sprite.asm). bufp/svp/src are the blitter's three
\\ pointers; the rest is one sprite's working state, live only inside
\\ spr_draw_slot.
.bufp           skip 2      ; the screen byte being drawn
.svp            skip 2      ; the matching byte of the slot's save page
.src            skip 2      ; the frame's data, in the paged-in sprite bank
.spr_slot       skip 1      ; 0-7
.spr_idx        skip 1      ; spr_bank8 + spr_slot: the per-bank state index
.spr_bank8      skip 1      ; 8 while the CPU writes the shadow bank, else 0
.spr_phase      skip 1      ; 1 while the bank being drawn is the odd pixel
.spr_frame      skip 1      ; 0-118, from sprite_dp through sprite_dp_dcd
.spr_y          skip 1      ; the C64 y of the sprite in hand
.spr_c          skip 1      ; signed byte column, while it is being worked out
.spr_c0         skip 1      ; first byte column drawn, 0-79
.spr_r0         skip 1      ; first scanline drawn, 0-159
.spr_cols       skip 1      ; the frame's box width = its data row stride
.spr_rows       skip 1      ; rows left to draw
.spr_count      skip 1      ; byte columns actually drawn, 1-7
.spr_skip_c     skip 1      ; columns and rows clipped off the left and top
.spr_skip_r     skip 1
.spr_scan       skip 1      ; scanline within the first character row
.spr_wrap       skip 1      ; one of this sprite's character rows crosses the end
.spr_split      skip 1      ; byte columns of THIS character row before it, 0 = whole
.spr_bias       skip 1      ; spr_split * 8: the same step along screen and save
.spr_entry      skip 2      ; the whole-row body, for the split body to tail into
.spr_tmp        skip 2      ; scratch: the bufp arithmetic and the straddle walk

\\ Player and collisions (src/player.asm)
.joy            skip 1      ; the C64's joystick byte: a CLEAR bit is pressed
.joy_idx        skip 1      ; which key read_joystick is asking about
.coll_row       skip 1      ; play-area character row being sampled
.coll_col       skip 1      ; and screen character column, 0-39
.coll_base      skip 1      ; coll_map slot holding screen column 0
.coll_wr        skip 1      ; and the slot the entering character goes in

.plane_hi       skip 1      ; HI(char_data) + 8 * (char_col AND 3): this frame's column plane

.frame_count    skip 1      ; game frames (25 Hz), for animation timing
.field_count    skip 1      ; fields (50 Hz), incremented by the VSync IRQ
.flip_field     skip 1      ; field_count at the last bank flip
.frame_ready    skip 1      ; main loop -> IRQ: hidden bank is drawn, flip at next VSync
.crtc_park      skip 2      ; scroll address for the bank being drawn (main loop writes)
.crtc_live      skip 2      ; scroll address the IRQ programs at fire 1
.rupt_state     skip 1      ; 0 = fire 1 pending, 1 = fire 2 pending, 2 = done

IF MUSIC_AKL
\ src/aklplayer.asm's working pointers. Everything else it keeps - the
\ per-channel state, the tables, the register file - is absolute, up in
\ HAZEL with the code, so only the indirect reads need to be down here.
.ptr            skip 2      ; the track / linker pointer being read
.iptr           skip 2      ; the instrument pointer being read
.tptr           skip 2      ; scratch indirect: the table lookups
.cell           skip 1      ; the byte being decoded
.iofs           skip 1      ; Y, parked while Y is needed for a table
.per            skip 2      ; the period being computed
.tmp            skip 2
.mixer          skip 1      ; R7 as the three channels build it up
.akl_tick       skip 1      ; ticks until the next line
.akl_speed      skip 1
.akl_height     skip 1      ; lines left in this pattern
.akl_prevh      skip 1      ; the height to reuse when a pattern does not say
.lnk            skip 2      ; the linker pointer
.jvec           skip 2      ; the effect dispatch vector
ELSE
\ The VGI music player's four bytes (lib/vgiplayer.h.asm): two indirect
\ pointers. Everything else it keeps is absolute, up in HAZEL with the code.
INCLUDE "lib/vgiplayer.h.asm"
ENDIF

\ The ZX0 depacker (src/zx0depack.asm) borrows six of the above. It runs
\ only at boot, before any of them is live, and it is over before the
\ first sprite is drawn. Declared HERE rather than in the depacker so
\ beebasm sees them before the loader's first zero-page reference: an
\ undefined symbol in pass 1 assembles as an absolute address and the
\ pass-2 size change is an error.
zxsrc = read_ptr            ; -> the compressed stream
zxdst = write_ptr           ; -> the output
zxofs = bufp                ; the current offset
zxlen = svp                 ; gamma accumulator / count
zxbit = spr_slot            ; the bit buffer, sentinel-marked
zxwrk = spr_tmp             ; -> the copy source

IF DEBUG_TIMING
.tim_ptr        skip 2      ; the maximum slot the next mark writes
.tim_val        skip 2      ; us since tim_start, at the last mark
.tim_prev       skip 2      ; and what it was at the mark before that
.tim_phase      skip 2      ; the difference: one phase of the loop
ENDIF

\ ******************************************************************
\ *	CODE START
\ ******************************************************************
ORG &E00
GUARD CODE_TOP

.start

\ ******************************************************************
\ *	Code entry
\ ******************************************************************

.code_start

.main
{
    txs

    \\ BREAK must clear memory from here on (KC). We take HAZEL, which is the
    \\ filing system's own workspace, so once MUSIC is copied up there the DFS
    \\ workspace is gone. A SOFT break leaves it that way and the machine comes
    \\ back with no filing system at all - measured: no DFS banner and *CAT
    \\ returns nothing. OSBYTE 200 bit 1 makes BREAK behave as a power-on reset,
    \\ which re-initialises it; bit 0 disables ESCAPE with it, which is welcome
    \\ anyway - it cannot abort the bank loads, and we read the ESCAPE key
    \\ straight off the VIA matrix rather than through the MOS.
    \\
    \\ First thing done, before anything can be interrupted or broken into.
    lda #200
    ldx #3
    ldy #0
    jsr osbyte

    \\ Blank the display until the loading screen is unpacked: whatever
    \\ mode the machine booted in, its screen is about to be walked over.
    \\ R8 skew bits (Paradroid's R8_BLANK); VDU 22 resets R8, so the mode
    \\ change writes it again, and so does setup_display after the clears.
    CRTC 8, &30
    CRTC 10, &20                ; and the MOS cursor, which R8 does not hide

    \\ Wipe ZP

    ldx #0
    lda #0
    .zp_loop
    sta &00,x
    inx
    cpx #&a0
    bcc zp_loop


    \\ Mode change FIRST now, not last: the loading screen is a MODE 2
    \\ picture and it has to be up before the banks come in. The old
    \\ ordering was there because the banks staged through &4000, which
    \\ MODE 2 puts on screen; they stage in the SHADOW screen now, so
    \\ there is nothing left to hide.
    lda #22
    jsr oswrch
    lda #2
    jsr oswrch
    CRTC 8, &30                 ; VDU 22 turned the display back on
    CRTC 10, &20                ; and put the cursor back

    \\ The loading screen: two halves into main &3000-&7FFF, each from a
    \\ stream staged at LOAD_STREAM below it.
    lda #LO(loadsc1_filename)
    ldy #HI(loadsc1_filename)
    ldx #HI(LOAD_STREAM)
    jsr load_stream
    lda #LO(LOADSCR_ADDR)
    ldx #HI(LOADSCR_ADDR)
    jsr unpack_to

    lda #LO(loadsc2_filename)
    ldy #HI(loadsc2_filename)
    ldx #HI(LOAD_STREAM)
    jsr load_stream
    lda #LO(LOADSCR_ADDR2)
    ldx #HI(LOADSCR_ADDR2)
    jsr unpack_to

    CRTC 8, 0                   ; and there it is

    \\ Display MAIN (D=0), CPU sees SHADOW (X=1). That is the state the
    \\ game itself runs in, and here it is what keeps the picture up:
    \\ every stream from now on stages in the shadow screen at
    \\ DEPK_STREAM, which is 20K of RAM nobody is looking at.
    lda &fe34
    and #255-1
    ora #4
    sta &fe34

    \\ Load the SWRAM banks: 0 = chars/tiles/map (slot 4), 1 = sprites (slot 5).
    \\ Bank 0 is the resting state; only plot_sprite pages bank 1 in.

    lda #LO(bank0_filename)
    ldy #HI(bank0_filename)
    ldx #SWRAM_DATA
    jsr load_bank

    lda #LO(bank1_filename)
    ldy #HI(bank1_filename)
    ldx #SWRAM_SPRITES0
    jsr load_bank

    lda #LO(bank2_filename)
    ldy #HI(bank2_filename)
    ldx #SWRAM_SPRITES1
    jsr load_bank

    lda #LO(bank3_filename)
    ldy #HI(bank3_filename)
    ldx #SWRAM_COMPILED
    jsr load_bank

    \\ The panel image: loaded, not unpacked. Its stream sits at
    \\ LOAD_STREAM until setup_display asks for it, and panel_init then
    \\ unpacks it straight into &3000 in each bank - the only two places
    \\ it is ever wanted. Nothing else touches LOAD_STREAM from here on.
    lda #LO(panel_filename)
    ldy #HI(panel_filename)
    ldx #HI(LOAD_STREAM)
    jsr load_stream

IF MUSIC_AKL = 0
    \\ ANDY's share of the tune: loaded here, unpacked below. See
    \\ ANDY_STREAM for why the two are not together.
    lda #LO(andy_filename)
    ldy #HI(andy_filename)
    ldx #HI(ANDY_STREAM)
    jsr load_stream
ENDIF

    \\ MUSIC goes into HAZEL, and HAZEL is the filing system's own
    \\ workspace, so it must be the LAST file loaded. Nothing may touch
    \\ the disc after this.
    lda #LO(music_filename)
    ldy #HI(music_filename)
    jsr load_hazel

IF MUSIC_AKL = 0
    jsr unpack_andy             \\ and now the disc is finished with
ENDIF

    lda #SWRAM_DATA
    sta &f4
    sta &fe30

    CRTC 8, &30                 ; the loading screen has done its job
    jsr setup_display           ; blanked until the buffers and panel are drawn
    jsr score_boot              ; the C64's initialised score, lives and 012345
    ldx #LO(music_init)         ; the tune starts before the titles and loops
    ldy #HI(music_init)
    jsr bank3_call

    \\ Initialise variables

IF DEBUG_TIMING
    jsr tim_init
ENDIF
    jsr install_irq

    \\ ---- the state machine, the C64's master_loop --------------------
    \\
    \\ Titles -> game_init -> the play loop -> life lost -> game over or
    \\ completion -> titles. Only the titles are a loop of their own,
    \\ because only they hold a still picture. Playing, game over and
    \\ completion all differ in what the TICK does and not in what the
    \\ frame does, so they share this loop and are told apart by
    \\ game_mode, which says which of the original's loops the tick is
    \\ standing in for.
    \\
    \\ game_init is called HERE, at the top, and the loop leaves through
    \\ the bottom: scroll_prewind flips &FE34 itself, and frame_ready has
    \\ to be 0 while it does, which it is everywhere outside the loop.

    .master_loop
    jsr title_page              \\ static credits, returns when fire is hit
    jsr game_init

    \\ No star is on screen: game_init has just wound a fresh screen in
    \\ under them, and a flag left set from the last game would have the
    \\ wipe punch a black byte into it that nothing repaints for six
    \\ seconds. After game_init, because the wind is what clears them.
    lda #SWRAM_SPRITES0
    ldx #LO(star_init)
    ldy #HI(star_init)
    jsr bank_call

    .loop

IF DEBUG_TIMING
    jsr tim_start
ENDIF

    \\ Every sprite's background comes back before anything is drawn:
    \\ a draw between another slot's restore and its draw would be
    \\ captured into that slot's save. The new scroll column is not.

    jsr spr_restore_all
    TIMMARK TIM_RESTORE

    lda char_col
    and #SPR_PHASE_MASK
    sta spr_phase

    \\ The finale's background stands still: the C64's cm_splode_wait
    \\ calls neither scroll_manage nor anything that plots, so the level
    \\ stops where the player left it and only the bangs move.
    lda game_mode
    cmp #MODE_FINALE
    beq no_scroll
    jsr scroll_frame            \\ plots this frame's byte column

    \\ The stars go on after the scroll and before the sprites: over the
    \\ scenery, under everything that flies. In the finale, with the
    \\ level standing still, they stand still with it - which is why they
    \\ are inside this test and not below it. corner_addr does not move
    \\ there, so the wipe's "one byte column back" would be the star's
    \\ own byte and it would rub itself out.
    lda #SWRAM_SPRITES0
    ldx #LO(star_frame)
    ldy #HI(star_frame)
    jsr bank_call
    .no_scroll
    TIMMARK TIM_SCROLL
    jsr spr_draw_all
    TIMMARK TIM_DRAW

    \\ Game logic. Two ticks a frame: one pass of this loop is two of the
    \\ C64's, so its per-frame constants transcribe unchanged (decision 23).
    \\ The joystick is read once - it cannot change between the two.

    jsr read_joystick
    jsr pause_check
    jsr game_tick
    jsr game_tick

    lda game_mode
    cmp #MODE_FINALE
    beq no_advance
    jsr scroll_advance          \\ AFTER the draw - see scroll_advance
    .no_advance

    \\ The panel last: the C64 runs status_decode from its raster interrupt
    \\ and nothing else this frame touches &3000. It writes only the cells
    \\ that have changed in the bank the CPU owns, so a still frame costs
    \\ eighteen compares and nothing else.
    jsr status_call
    TIMMARK TIM_LOGIC

    inc frame_count
    jsr frame_wait

    \\ The game-over count and the completion sequence both end by asking
    \\ for the titles again; nothing else leaves this loop.
    lda to_titles
    beq loop
    jmp master_loop

    .done

    rts
}

\ ******************************************************************
\ *	frame_wait - hand the frame over and wait for the flip
\ ******************************************************************
\ *	The bottom of every playing frame. The loop has drawn into the
\ *	hidden bank; this parks that bank's scroll address, sets the ready
\ *	flag and spins until the VSync handler has flipped and taken it.

.frame_wait
{
    sei
IF DEBUG_TIMING
    \\ Inside the SEI so field_count cannot move under the subtraction.
    jsr tim_handover
ENDIF
    lda crtc_addr
    sta crtc_park
    lda crtc_addr+1
    sta crtc_park+1
    lda #1
    sta frame_ready
    cli
    .wait_flip
    lda frame_ready
    bne wait_flip
    rts
}

\ ******************************************************************
\ *	bank3_call - page bank 3 in, call X/Y, page SWRAM_DATA back
\ ******************************************************************
\ *	In main RAM because it has to be: nothing in a sideways bank can
\ *	page its own bank out from under itself, and bank 0 - where every
\ *	caller sits - is a sideways bank too. Bank 3 holds the titles' font
\ *	and text, the panel image and the HUD, because it is the only bank
\ *	with room; SWRAM_DATA is the resting state everything else assumes.
\ *
\ *	X = LO, Y = HI of the routine in bank 3. Self-modifying rather than
\ *	one entry a routine: main RAM has tens of bytes left, not hundreds.
\ *	Not re-entrant, and nothing calls it from an interrupt.

.bank3_call
    lda #SWRAM_COMPILED
\ A = the bank, X = LO, Y = HI. The titles' zoom scroller lives in bank 1,
\ whose sprite data nothing on that page reads.
.bank_call
    stx bank_call_t+1
    sty bank_call_t+2
    sta &f4
    sta &fe30
    jsr bank_call_t
    lda #SWRAM_DATA
    sta &f4
    sta &fe30
    rts
.bank_call_t
    jmp &ffff                   ; written above

\ ******************************************************************
\ *	field_wait - one field, WITHOUT handing a frame over
\ ******************************************************************
\ *	What a frozen screen waits on: the pause loop and the titles. The
\ *	flip only happens when frame_ready is set, so leaving it alone
\ *	keeps the displayed bank displayed - a paused picture that is
\ *	genuinely still, rather than the last two frames alternating at
\ *	25 Hz, which is what handing frames over would give.

.field_wait
{
    lda field_count
    .same
    cmp field_count
    beq same
    rts
}

\ ******************************************************************
\ *	scroll_frame - plot one byte column and advance the scroll
\ ******************************************************************
\ *	The whole of a frame's scroll work, lifted out of the main loop so
\ *	that scroll_prewind can run it before the game starts. It reads
\ *	char_col, draws that pixel column of the incoming characters, and
\ *	leaves char_col, tile_cnt, the collision ring, crtc_addr and
\ *	corner_addr on the next frame's values.
\ ******************************************************************

.scroll_frame
{
    \\ Start column plot

    jsr set_corner_addr
    jsr coll_frame_start        ; where plot_char_y files this column's codes

    \\ Select this frame's column plane (2K per plane, pixel column = char_col AND 3)

    lda char_col
    and #3
    asl a: asl a: asl a
    clc
    adc #HI(char_data)
    sta plane_hi

    \\ The right-hand column is NOT shifted here any more. copy_column_buffer
    \\ does it on the way out at the bottom of the frame, which is the same
    \\ shift one frame earlier and saves a whole 160-byte pass.

    \\ Column reader for tile 1

    ldx tile_cnt
    jsr tile_read_1

    \\ Gives character value in y - C64 can store this in character map, we need to plot to screen
    jsr plot_char_y

    \\ Add 4 to index as each tile has stride of 4
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_1
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_1
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_1
    jsr plot_char_y

    \\ Tile 2

    ldx tile_cnt
    jsr tile_read_2
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_2
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_2
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_2
    jsr plot_char_y

    \\ Tile 3

    ldx tile_cnt
    jsr tile_read_3
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_3
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_3
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_3
    jsr plot_char_y

    \\ Tile 4

    ldx tile_cnt
    jsr tile_read_4
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_4
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_4
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_4
    jsr plot_char_y

    \\ Tile 5

    ldx tile_cnt
    jsr tile_read_5
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_5
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_5
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_5
    jsr plot_char_y

    \\ Now copy new right hand column to screen buffer

    jsr copy_column_buffer
    rts
}

\ ******************************************************************
\ *	scroll_advance - move the scroll on by one pixel
\ ******************************************************************
\ *	SEPARATE FROM scroll_frame, AND CALLED AFTER THE SPRITES ARE DRAWN.
\ *	Sprites are placed from corner_addr, so advancing it before the draw
\ *	puts them one byte column - two pixels - further right on the frames
\ *	where it moves and not on the others. A stationary ship then rocks
\ *	back and forth in step with the scroll, which is exactly what KC saw
\ *	when these two were one routine (BUGS.md #7). The order here is the
\ *	loop's original one: plot, draw, then advance.
\ ******************************************************************

.scroll_advance
{
    \\ Scrolling

    \\ Increment column

    ldx char_col
    inx

    \\ Two columns per character

    txa
    and #3
    bne no_bump

    \\ Bump the tile_cnt

    jsr tile_cnt_bump
    jsr coll_advance

    .no_bump

    \\ Increment scroll every other column

    txa
    and #1
    beq no_scroll

    clc
    lda crtc_addr
    adc #1
    sta crtc_addr
    lda crtc_addr+1
    adc #0
    cmp #HI(screen_top/8)
    bcc scroll_ok
    sbc #HI(screen_size/8)
    .scroll_ok
    sta crtc_addr+1
IF _DOUBLE_BUFFER
    .no_scroll

    txa
    and #1
    bne no_column
ENDIF

    clc
    lda corner_addr
    adc #8
    sta corner_addr
    lda corner_addr+1
    adc #0
    cmp #HI(screen_top)
    bcc col_ok
    sbc #HI(screen_size)
    .col_ok
    sta corner_addr+1

IF _DOUBLE_BUFFER
    .no_column
ELSE
    .no_scroll
ENDIF

    stx char_col
    rts
}

\ ******************************************************************
\ *	scroll_prewind - fill the play area before the first frame
\ ******************************************************************
\ *	THE C64 DOES THIS AND WE HAVE TO AS WELL. map_read_rst ends in what
\ *	its author calls a "Scroll fast winder for the start of game": the
\ *	whole buffer-swap cycle run 20 times, which is 40 characters, which
\ *	is exactly the width of the screen. Without it the game opens on an
\ *	empty playfield that takes a screen's worth of scrolling to fill,
\ *	and - far worse - the wave table, whose timings were authored
\ *	against a full screen, spawns its first enemies a screen ahead of
\ *	the scenery they were drawn to fly through. KC saw both: a long
\ *	blank start, and enemies that did not line up with the level.
\ *
\ *	40 characters is 160 of our frames: a character is 4 pixels wide and
\ *	we move one pixel a frame. Each frame writes one byte column into
\ *	the bank the X bit selects, so the flip has to happen here too -
\ *	the VSync handler that normally does it is not installed yet. Each
\ *	bank then gets its own 80 columns, one pixel out of phase with the
\ *	other, exactly as the running loop leaves them.
\ ******************************************************************

\ COLL_COLS is the width in CHARACTERS (40), not byte columns: a
\ character is 4 pixels wide and we move one pixel a frame, so a screen
\ is 160 frames. It is also defined above, which PLAY_COLS is not -
\ sprite.asm is included after this point and beebasm takes constant
\ assignments in file order.
SCROLL_PREWIND = 4 * COLL_COLS

.scroll_prewind
{
    lda #LO(SCROLL_PREWIND)
    sta prewind_count
    lda #HI(SCROLL_PREWIND)
    sta prewind_count+1
    .loop
    jsr scroll_frame
    jsr scroll_advance
    lda &fe34                   ; the CPU's bank, as the VSync flip does it
    eor #5
    sta &fe34
    lda prewind_count
    bne no_borrow
    dec prewind_count+1
    .no_borrow
    dec prewind_count
    lda prewind_count
    ora prewind_count+1
    bne loop
    rts
    .prewind_count EQUW 0
}

INCLUDE "src/scroll.asm"

\\ ---- the loader: OSFILE a ZX0 stream in, unpack it out --------------
\\
\\ Every file on the disc but Edge and !BOOT ships ZX0-compressed, with a
\\ catalogue load address tools/make_disc.py writes (decision 38). None of
\\ them could be loaded straight to where they belong even uncompressed:
\\ the filing system has the DFS ROM paged in at &8000 while it works, so
\\ a bank's bytes would land in the ROM socket, and HAZEL is the filing
\\ system's own workspace. So each stages in RAM and is unpacked from
\\ there. All of it must run before any IRQ takeover.

\\ A/Y = filename, X = the page the stream loads at. Leaves zxsrc pointing
\\ at it, ready for unpack_to.
.load_stream
{
    stx stream_page
    sta osfile_nameaddr
    sty osfile_nameaddr+1

    \\ OSFILE writes the file's catalogue addresses back into the block
    \\ after a load, so the next call would honour the last file's load
    \\ address and land wherever that was. Reset load and exec = 0 (exec
    \\ low byte 0 = "use the block's load address") every call.
    lda #0
    sta osfile_loadaddr
    sta osfile_loadaddr+2
    sta osfile_loadaddr+3
    sta osfile_execaddr
    lda stream_page
    sta osfile_loadaddr+1

    ldx #LO(osfile_params)
    ldy #HI(osfile_params)
    lda #&FF
    jsr osfile

    \\ AFTER the call, not before: the depacker's zero page is borrowed
    \\ from the game's, and there is nothing to gain by setting it up
    \\ while the filing system is still running in it.
    lda #0
    sta zxsrc
    lda stream_page
    sta zxsrc+1
    rts
    .stream_page EQUB 0
}

\\ Unpack the stream at zxsrc to X:A.
.unpack_to
{
    sta zxdst
    stx zxdst+1
    jmp zx0_unpack
}

\\ The status panel into whichever bank the X bit selects. The image is
\\ not resident anywhere: it is a disc file whose ZX0 stream is still
\\ sitting at LOAD_STREAM from boot, and this unpacks it straight into
\\ the screen. Called once per bank, so the stream is read twice and
\\ zxsrc has to be pointed at it again each time - zx0_unpack walks it.
\\ Anything that draws on the panel must do it for both banks.
\\
\\ The depacker is boot code living in SPR_SAVE, which nothing reads
\\ until the first sprite is drawn; this is the last call it gets.
.panel_init
{
    lda #0
    sta zxsrc
    lda #HI(LOAD_STREAM)
    sta zxsrc+1
    lda #LO(PANEL_ADDR)
    ldx #HI(PANEL_ADDR)
    jsr unpack_to

    \\ Nothing of the HUD survives a repaint, in either bank, and the
    \\ cache that says so is in bank 3 with status_decode.
    ldx #LO(panel_dirty)
    ldy #HI(panel_dirty)
    jmp bank3_call
}

\\ A 16K bank: A/Y = filename ptr, X = SWRAM slot. The stream stages in the
\\ shadow screen, which the loading screen is not using, and unpacks
\\ straight into the paged-in bank.
.load_bank
{
    stx &f4
    stx &fe30
    ldx #HI(DEPK_STREAM)
    jsr load_stream
    lda #LO(&8000)
    ldx #HI(&8000)
    jmp unpack_to
}

IF MUSIC_AKL = 0
\\ ANDY's share of the tune, from the stream left at ANDY_STREAM. Called
\\ after MUSIC, so no disc access can follow it.
\\
\\ With interrupts off and &F4 set as well as &FE30: the MOS's own IRQ
\\ handler is still installed here, and anything that pages a ROM restores
\\ &FE30 from &F4 - which would drop ANDY out from under the depacker half
\\ way through and put the rest of the stream into bank 3. The SEI alone
\\ would do; both is cheaper than reasoning about it again.
\\
\\ It does NOT put the bank back: the caller's next three instructions
\\ select SWRAM_DATA, and main RAM has tens of bytes left.
.unpack_andy
{
    sei
    lda #ANDY_ROM
    sta &f4
    sta &fe30
    lda #0
    sta zxsrc
    lda #HI(ANDY_STREAM)
    sta zxsrc+1
    lda #LO(MUSIC_ANDY_BASE)
    ldx #HI(MUSIC_ANDY_BASE)
    jsr unpack_to
    cli
    rts                         \\ ANDY still selected: boot's next three
}                               \\ instructions put SWRAM_DATA back anyway
ENDIF

\\ MUSIC into HAZEL, the same way, with the Y bit set over the unpack.
\\ Nothing may use the disc afterwards.
.load_hazel
{
    ldx #HI(DEPK_STREAM)
    jsr load_stream
    lda &fe34
    ora #HAZEL_BIT
    sta &fe34
    lda #LO(HAZEL_BASE)
    ldx #HI(HAZEL_BASE)
    jsr unpack_to
    lda &fe34
    and #255-HAZEL_BIT
    sta &fe34
    rts
}

INCLUDE "src/sprite.asm"
INCLUDE "src/player.asm"
INCLUDE "src/enemy.asm"
INCLUDE "src/keyboard.asm"
INCLUDE "src/rupture.asm"
IF GFX_CPC
    INCLUDE "src/data/compiled_zp-cpc.asm"  \ what the compiled bodies assume
ELSE
    INCLUDE "src/data/compiled_zp.asm"      \ what the compiled bodies assume
ENDIF
INCLUDE "src/tables.asm"

\ The ZX0 depacker LAST, after the tables: it is boot code and nothing
\ else calls it, so it is the one thing in the image that may sit above
\ SPR_SAVE's base and be walked over once the game starts.
INCLUDE "src/zx0depack.asm"

\ ******************************************************************
\ *	End address to be saved
\ ******************************************************************

.end

\ ******************************************************************
\ *	Save the code
\ ******************************************************************

SAVE "Edge", start, end

\ ******************************************************************
\ *	!BOOT - assembled here so the build stamps what it is
\ ******************************************************************
\ *	It is a disc file, not code, and it was costing the code image
\ *	its own length in address space - two hundred bytes of the
\ *	tightest region in the build, for text nothing ever executes.
\ *	So it is assembled in the sprite saves instead, the way
\ *	src/panel.asm and src/loading.asm assemble theirs: somewhere
\ *	that exists, that nothing has claimed at assembly time, and that
\ *	it is never loaded to. P% goes back afterwards.
\ ******************************************************************

code_p% = P%
CLEAR BOOT_STAGE, BOOT_STAGE + 256
ORG BOOT_STAGE

.bootfile
IF RELEASE
    EQUS "REM Edge Grinder", 13
ELSE
    EQUS "REM Edge Grinder DEV build", 13
IF DEBUG_COLL
    EQUS "REM DEBUG_COLL: collisions do not kill", 13
ENDIF
IF DEBUG_TIMING
    EQUS "REM DEBUG_TIMING: the frame meter is running", 13
ENDIF
ENDIF
\ MUSIC_AKL is NOT a DEBUG_ flag: it is legal under RELEASE and it changes
\ what the disc contains, so it is stamped outside the RELEASE test. Saying
\ nothing means the default - lib/vgiplayer.asm and the tune cut to 203 s.
IF MUSIC_AKL
    EQUS "REM MUSIC_AKL: Arkos replay, whole 349s tune", 13
ELSE
    EQUS "REM MUSIC: VGI player, whole 349s tune, 4 regions", 13
ENDIF
\ GFX_CPC is not a DEBUG_ flag either, and it changes every pixel on the
\ disc, so it is stamped outside the RELEASE test too.
IF GFX_CPC
    EQUS "REM GFX_CPC: the Amstrad CPC artwork", 13
ENDIF
EQUS "REM BUILD ", TIME$("%d %b %Y %H:%M:%S"), 13
EQUS "*RUN Edge", 13
.bootfile_end

SAVE "!BOOT", bootfile, bootfile_end
ASSERT bootfile_end < BOOT_STAGE + 256

ORG code_p%


\ ******************************************************************
\ *	Space reserved for runtime buffers not preinitialised
\ ******************************************************************

.bss_start
.bss_end

\ ******************************************************************
\ *	Memory Info
\ ******************************************************************

PRINT "------"
PRINT "EDGE GRINDER"
PRINT "------"
PRINT "CODE size =", ~code_end-code_start
PRINT "DATA size =",~data_end-data_start
PRINT "BSS size =",~bss_end-bss_start
PRINT "------"
\ ******************************************************************
\ *	THE REAL CEILING IS SPR_SAVE, NOT LOAD_STREAM
\ ******************************************************************
\ *	&2000-&2FFF is the sprite save area, rewritten every frame from
\ *	the moment the first sprite is drawn. Boot code and boot data may
\ *	sit in it - src/zx0depack.asm and the OSFILE block do, and !BOOT
\ *	is assembled there - because they are dead before anything reads
\ *	there. ANYTHING READ OR EXECUTED IN PLAY MAY NOT.
\ *
\ *	This is the guard that was missing: explosion_dirs drifted above
\ *	&2000 unnoticed and the player's pieces stopped flying, because
\ *	the blitter was writing the player's saved background over their
\ *	movement vectors. The FREE figure below is measured to
\ *	LOAD_STREAM and OVERSTATES the room for anything permanent - the
\ *	number that matters is this one.
\ ******************************************************************

ASSERT code_end <= SPR_SAVE
PRINT "CODE CEILING: code_end", ~code_end, "-", ~SPR_SAVE-code_end, "under SPR_SAVE"

PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~CODE_TOP-P%     \ to LOAD_STREAM: the depacker sits in SPR_SAVE
PRINT "------"

\ ******************************************************************
\ *	GAME STATE at &0800 - see GAME_STATE above. None of it is saved:
\ *	it is declared after the SAVEs and outside them, and every routine
\ *	that reads it writes it first. The first four blocks are the C64's
\ *	own $0340-$039F labels, same names, same meanings.
\ ******************************************************************

CLEAR GAME_STATE, GAME_STATE_TOP
ORG GAME_STATE
.game_state_start

.sprite_pos     skip 2*SPR_SLOTS    ; x,y a slot: 0 player, 1 bullet, 2-7 pool
.sprite_dp      skip SPR_SLOTS      ; the sprite_dp_dcd index = the frame
.sprite_pls_tmr skip SPR_SLOTS      ; hit-flash countdown
.anim_starts    skip SPR_SLOTS
.anim_ends      skip SPR_SLOTS
.anim_tmr       skip 1              ; multimate steps every fourth tick

.enemy_spds     skip 2*SPR_SLOTS    ; movement commands; slot 1 is the bullet's speed
.enemy_shields  skip SPR_SLOTS      ; hits left before it explodes
.enemy_rockers  skip SPR_SLOTS      ; timer value it switches command at
.enemy_resets   skip SPR_SLOTS      ; and wraps at
.enemy_tmrs     skip SPR_SLOTS

.scroll_x       skip 1              ; the C64's 16-step fine-scroll counter
.wave_tmr       skip 1              ; ticks until the next wave is spawned
.fire_latch     skip 1              ; set while fire is held, so it does not repeat
.coll_flag      skip 1              ; a fatal hit; doubles as the game-over
                                    ; countdown once the player is gone
.comp_flag      skip 1              ; the wave table ran out; Layer 6c reads it
.lives          skip 1              ; three at main_init, one taken per hit
.player_shield  skip 1              ; ticks of invulnerability after a drop-in
.game_mode      skip 1              ; MODE_PLAY / OVER / COMP / FINALE: which of
                                    ; the C64's loops the tick is standing in for
.to_titles      skip 1              ; game over or completion has finished:
                                    ; the loop drops back to master_loop
.finale_slot    skip 1              ; which slot the next bang takes, 0-7
.finale_tmr     skip 1              ; ticks until it goes off
.coll_grind     skip 2              ; the two grind cells, above and below the ship
.coll_temp      skip 4              ; the collision box being tested
.rt_store       skip 1              ; X across a bump_score call

.score          skip SCORE_DIGITS   ; one decimal digit a byte, biggest first
.hi_score       skip SCORE_DIGITS

\ What each bank's last sprite draw did, for the restore: bank*8 + slot.
.spr_sv_on      skip 2*SPR_SLOTS
.spr_sv_lo      skip 2*SPR_SLOTS
.spr_sv_hi      skip 2*SPR_SLOTS
.spr_sv_scan    skip 2*SPR_SLOTS
.spr_sv_rows    skip 2*SPR_SLOTS
.spr_sv_cols    skip 2*SPR_SLOTS
.spr_sv_wrap    skip 2*SPR_SLOTS    ; 0 plain, 1 split, 2 compiled
.spr_sv_clo     skip 2*SPR_SLOTS    ; and the compiled restore body, if 2
.spr_sv_chi     skip 2*SPR_SLOTS

\ The starfield (Layer 9c). The first four are the star itself, shared
\ by both banks because a star is at one place on the screen whichever
\ bank is being drawn; the last two are per bank, because a bank is
\ only redrawn every other frame and what has to be put back is
\ wherever THAT bank last left it.
.star_ofs_lo    skip STAR_COUNT     ; screen offset from corner_addr, 16-bit:
.star_ofs_hi    skip STAR_COUNT     ; 8 + row * 640 + column * 8
.star_col       skip STAR_COUNT     ; column 0-79, kept for the wrap test alone
.star_pix       skip STAR_COUNT     ; the byte to write: the colour in whichever
                                    ; half of it the star is standing in
\ Where this bank last plotted each star, or 0 in the high byte for "it
\ did not". A star is only ever plotted into a blank byte, so what goes
\ back is always zero and there is nothing else to remember.
.star_lo        skip STAR_BANK + STAR_COUNT
.star_hi        skip STAR_BANK + STAR_COUNT

\ The frame meter (src/timing.asm). Microseconds, worst case since boot;
\ double them for 2 MHz cycles. tim_over is the one that matters.
IF DEBUG_TIMING
\ The five maxima are addressed by the TIM_ index, so they must stay
\ in this order and adjacent.
.tim_slots_start
.tim_max_restore skip 2         ; TIM_RESTORE: spr_restore_all
.tim_max_scroll  skip 2         ; TIM_SCROLL:  scroll_frame
.tim_max_draw    skip 2         ; TIM_DRAW:    spr_draw_all
.tim_max_logic   skip 2         ; TIM_LOGIC:   read_joystick, 2 x game_tick, scroll_advance
.tim_max_total   skip 2         ; TIM_TOTAL:   the lot, tim_start to handover
.tim_fields      skip 1         ; worst fields a frame took; FRAME_LOCK is late
.tim_over        skip 1         ; frames that missed their flip, saturating
.tim_slots_end
ASSERT tim_max_restore = tim_slots_start + 2 * TIM_RESTORE
ASSERT tim_max_scroll  = tim_slots_start + 2 * TIM_SCROLL
ASSERT tim_max_draw    = tim_slots_start + 2 * TIM_DRAW
ASSERT tim_max_logic   = tim_slots_start + 2 * TIM_LOGIC
ASSERT tim_max_total   = tim_slots_start + 2 * TIM_TOTAL
ENDIF

.game_state_end
ASSERT game_state_end <= GAME_STATE_TOP
PRINT "GAME STATE =", ~game_state_start, "to", ~game_state_end

\ The loading screen is FIRST: it is the first thing off the disc, and
\ tools/make_disc.py lays the image out in the order the boot reads it.
INCLUDE "src/loading.asm"
INCLUDE "src/panel.asm"
INCLUDE "src/andy.asm"
INCLUDE "src/bank0.asm"
INCLUDE "src/bank1.asm"
INCLUDE "src/bank2.asm"
INCLUDE "src/bank3.asm"
INCLUDE "src/music.asm"
