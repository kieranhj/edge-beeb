\ ******************************************************************
\ *	EDGE GRINDER
\ ******************************************************************

\ RELEASE is a beebasm command-line symbol (-D RELEASE=0 or 1); build.ps1
\ passes it on every build. beebasm has no IFDEF, so there is no default here.
ASSERT RELEASE=0 OR RELEASE=1
DEV = 1-RELEASE

\ Debug flags. Each must be off under RELEASE; add new ones to DEBUG_ANY and
\ to the !BOOT stamp at the bottom of this file so a build says what it is.
DEBUG_ANY = 0
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

IKN_z = 97
IKN_x = 66
IKN_colon = 72
IKN_fwd_slash = 104

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
KEY_UP = IKN_colon
KEY_DOWN = IKN_fwd_slash

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

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

screen_start = &4000
screen_size = &4000
screen_top = screen_start + screen_size
row_stride = 640

column_buffer = &400        ; 160 bytes for right hand column
column_size = 160

SWRAM_DATA = 4              ; bank 0: chars, tiles, map, col_decode (resting state)
SWRAM_SPRITES = 5           ; bank 1: sprite data

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

sprite_total = 119
sprite_stride = 64
sprite_width_bytes = 3
sprite_height = 21          ; total 63 bytes for a C64 sprite

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

.sprite_no      skip 1      ; temp for sprite_plot
.sprite_byte    skip 1      ; temp for sprite_plot
.sprite_idx     skip 1      ; temp for sprite_plot

.x_count        skip 1      ; temp for sprite_plot
.y_count        skip 1      ; temp for sprite_plot

.x_pos          skip 1      ; sprite x
.y_pos          skip 1      ; sprite y
.num            skip 1      ; sprite frame

.bg_ptrs        skip 4      ; pointers to sprite plot address on screen for stash

.plane_hi       skip 1      ; HI(char_data) + 8 * (char_col AND 3): this frame's column plane

.frame_count    skip 1      ; game frames (25 Hz), for animation timing
.field_count    skip 1      ; fields (50 Hz), incremented by the VSync IRQ
.flip_field     skip 1      ; field_count at the last bank flip
.frame_ready    skip 1      ; main loop -> IRQ: hidden bank is drawn, flip at next VSync
.crtc_park      skip 2      ; scroll address for the bank being drawn (main loop writes)
.crtc_live      skip 2      ; scroll address the IRQ programs at fire 1
.rupt_state     skip 1      ; 0 = fire 1 pending, 1 = fire 2 pending, 2 = done

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
    ldx #SWRAM_SPRITES
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

    lda #4
    sta x_pos
    lda #70
    sta y_pos
    lda #11
    sta num

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
    jsr tile_update

    lda crtc_addr
    sta crtc_live
    lda crtc_addr+1
    sta crtc_live+1
    jsr install_irq

    \\ The loop draws into the hidden bank (the &FE34 X bit already points
    \\ at it), parks the scroll address, and hands the frame to the VSync
    \\ IRQ, which flips the banks on a FRAME_LOCK-field cadence.

    .loop
    stx char_col

    \\ Remove sprites from frame

    jsr restore_background

    \\ Start column plot

    jsr set_corner_addr

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

    \\ Store new bg

    ldx x_pos
    ldy y_pos
    jsr stash_background

    \\ Plot a sprite (raw C64 data lives in bank 1)

    lda #SWRAM_SPRITES
    sta &f4
    sta &fe30

    lda num
    ldx x_pos
    ldy y_pos
    jsr plot_sprite

    lda #SWRAM_DATA
    sta &f4
    sta &fe30

    \\ Animate sprite

    lda frame_count
    and #1
    beq skip_anim

    ldx num
    inx
    cpx #18
    bcc num_ok
    ldx #11
    .num_ok
    stx num

    .skip_anim

    \\ Read keyboard

    jsr read_keyboard

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

    inc frame_count

    \\ Hand the frame over and wait for the flip
    sei
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
ENDIF
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

INCLUDE "src/bank0.asm"
INCLUDE "src/bank1.asm"
