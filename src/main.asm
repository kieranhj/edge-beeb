\ ******************************************************************
\ *	EDGE GRINDER
\ ******************************************************************

\ RELEASE is a beebasm command-line symbol (-D RELEASE=0 or 1); build.ps1
\ passes it on every build. beebasm has no IFDEF, so there is no default here.
ASSERT RELEASE=0 OR RELEASE=1
DEV = 1-RELEASE

\ Debug flags. Each must be off under RELEASE; add new ones to DEBUG_ANY and
\ to the !BOOT stamp at the bottom of this file so a build says what it is.
DEBUG_COLL = DEV            ; a fatal hit flashes instead of killing
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

KEY_LEFT = IKN_z
KEY_RIGHT = IKN_x
KEY_UP = IKN_k
KEY_DOWN = IKN_m
KEY_FIRE = IKN_l

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
ASSERT SWRAM_SPRITES1 = SWRAM_SPRITES0 + 1

SPR_SAVE = &2000            ; 8 slots x 256 B x 2 banks, saved background

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
CODE_TOP    = &2000         ; &2000-&2FFF is reserved for the Layer 3 sprite saves

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

    \\ Blank the display until setup_display has cleared everything: the
    \\ banks stage through &4000, which is on screen if the machine booted in
    \\ a graphics mode. R8 skew bits (Paradroid's R8_BLANK); VDU 22 resets R8
    \\ and setup_display writes it again after the clears.
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

    lda #SWRAM_DATA
    sta &f4
    sta &fe30

    \ Mode change LAST, after every load: the banks stage through &4000,
    \ which is on screen the moment MODE 2 is selected.
	\\ Set MODE

	lda #22
	jsr oswrch
	lda #2
	jsr oswrch
    CRTC 8, &30                 ; VDU 22 turned the display back on; off again
    jsr setup_display           ; until the buffers and panel are drawn

    \\ Shadow state: display main (D=0), CPU writes shadow (X=1)
    lda &fe34
    and #255-1
    ora #4
    sta &fe34

    \\ Set scroll addresses

    lda #LO(screen_start)
    sta corner_addr
    lda #HI(screen_start)
    sta corner_addr+1

    lda #LO(screen_start/8)
    sta crtc_addr
    lda #HI(screen_start/8)
    sta crtc_addr+1

    \\ Initialise variables

IF DEBUG_TIMING
    jsr tim_init
ENDIF
    jsr spr_init
    jsr coll_init
    jsr score_reset
    jsr sprite_reset

    ldx #0
    lda #0
    .col_loop
    sta column_buffer, X
    inx
    cpx #column_size
    bcc col_loop

    \\ Initialise the tile readers

    ldx #0
    stx tile_cnt
    stx tile_total
    stx char_col
    jsr tile_update

    \\ Fill the play area before anything is shown - see scroll_prewind.
    \\ The display is still blanked from setup_display's R8; it goes on
    \\ once there is a picture in both banks to show.
    CRTC 8, &30
    jsr scroll_prewind
    CRTC 8, 0

    lda crtc_addr
    sta crtc_live
    lda crtc_addr+1
    sta crtc_live+1
    jsr install_irq

    \\ The loop draws into the hidden bank (the &FE34 X bit already points
    \\ at it), parks the scroll address, and hands the frame to the VSync
    \\ IRQ, which flips the banks on a FRAME_LOCK-field cadence.

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

    jsr scroll_frame            \\ plots this frame's byte column
    TIMMARK TIM_SCROLL
    jsr spr_draw_all
    TIMMARK TIM_DRAW

    \\ Game logic. Two ticks a frame: one pass of this loop is two of the
    \\ C64's, so its per-frame constants transcribe unchanged (decision 23).
    \\ The joystick is read once - it cannot change between the two.

    jsr read_joystick
    jsr game_tick
    jsr game_tick

    jsr scroll_advance          \\ AFTER the draw - see scroll_advance
    TIMMARK TIM_LOGIC

    inc frame_count

    \\ Hand the frame over and wait for the flip
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

    jmp loop

    .done

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

    \\ Rotate right hand column

    jsr rotate_column_buffer

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

\\ Load a 16K bank file: A/Y = filename ptr, X = SWRAM slot.
\\ OSFILE loads it to &4000 (below the mode-7 screen the MOS is showing)
\\ and move_pages copies it up to &8000 in the selected slot, wiping the
\\ staging copy. Must run before the mode change and before any IRQ takeover.
.load_bank
{
    sta osfile_nameaddr
    sty osfile_nameaddr+1
    stx &f4
    stx &fe30

    \\ OSFILE writes the file's catalogue addresses back into the block
    \\ after a load, so the second call would honour BANK1's &8000 load
    \\ address and land in the DFS ROM. Reset load = &4000, exec = 0
    \\ (exec low byte 0 = "use the block's load address") every call.
    lda #0
    sta osfile_loadaddr
    sta osfile_loadaddr+2
    sta osfile_loadaddr+3
    sta osfile_execaddr
    lda #HI(&4000)
    sta osfile_loadaddr+1

	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

    lda #HI(&4000)
    ldx #HI(&8000)
    ldy #HI(&4000)
    jmp move_pages
}

\\ A=from page, X=to page, Y=num pages
.move_pages
{
    STA from_page+2
    STA wipe_page+2
    STX to_page+2

    LDX #0
    .loop
    .from_page
    LDA &FF00, X
    .to_page
    STA &FF00, X
    lda #0
    .wipe_page
    sta &ff00, X

    INX
    BNE loop

    INC from_page+2
    INC to_page+2
    INC wipe_page+2

    DEY
    BNE loop

    RTS
}

INCLUDE "src/sprite.asm"
INCLUDE "src/player.asm"
INCLUDE "src/enemy.asm"
INCLUDE "src/keyboard.asm"
INCLUDE "src/rupture.asm"
INCLUDE "src/tables.asm"

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

.bootfile
IF RELEASE
    EQUS "REM Edge Grinder", 13
ELSE
    EQUS "REM Edge Grinder DEV build", 13
IF DEBUG_COLL
    EQUS "REM DEBUG_COLL: a fatal hit flashes, it does not kill", 13
ENDIF
IF DEBUG_TIMING
    EQUS "REM DEBUG_TIMING: the frame meter is running", 13
ENDIF
ENDIF
EQUS "REM BUILD ", TIME$("%d %b %Y %H:%M:%S"), 13
EQUS "*RUN Edge", 13
.bootfile_end

SAVE "!BOOT", bootfile, bootfile_end


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
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~screen_start-P%
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
.coll_flag      skip 1              ; a fatal hit; Layer 6 takes the life
.comp_flag      skip 1              ; the wave table ran out; Layer 6 again
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
.spr_sv_wrap    skip 2*SPR_SLOTS

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

INCLUDE "src/bank0.asm"
INCLUDE "src/bank1.asm"
INCLUDE "src/bank2.asm"
