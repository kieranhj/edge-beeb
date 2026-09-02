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

\ ******************************************************************
\ *	CODE START
\ ******************************************************************
ORG &E00
GUARD screen_start

.start

\ ******************************************************************
\ *	Code entry
\ ******************************************************************

.code_start

.main
{
    txs

    \\ Set interrupts

    SEI
	LDA #&7F		; A=01111111
	STA &FE4E		; R14=Interrupt Enable (disable all interrupts)

	LDA #0			; A=00000000
	STA &FE4B		; R11=Auxillary Control Register (timer 1 one shot mode)

	LDA #&C2		; A=11000010
	STA &FE4E		; R14=Interrupt Enable (enable main_vsync and timer interrupt)
    CLI

    \\ Wipe ZP

    ldx #0
    lda #0
    .zp_loop
    sta &00,x
    inx
    cpx #&a0
    bcc zp_loop

	\\ Set MODE

	lda #22
	jsr oswrch
	lda #2
	jsr oswrch

    \\ Load SWRAM bank

    \\ Set SWRAM slot 4
    lda #4
    sta &fe30
    sta &f4

     \ Ask OSFILE to load our file
	LDX #LO(osfile_params)
	LDY #HI(osfile_params)
	LDA #&FF
    JSR osfile

    \\ Copy up to SWRAM

    lda #HI(&4000)
    ldx #HI(&8000)
    ldy #HI(&4000)
    jsr move_pages

	\\ Turn off cursor

	lda #10: sta &FE00
	lda #32: sta &FE01

    \\ Visibile lines = 20 (to blank scroll garbage for now)

    lda #6: sta &fe00
    lda #20: sta &fe01

    \\ Set 16K wraparound

    SEI
    LDA #&0F					; A=00001111
	STA &FE42					; R2=Data Direction Register "B" (set addressable latch for writing)

	LDA #&00 + 4				; A=00000100	; B4
	STA &FE40					; R0=Output Register "B" (write) (write 0 in to bit 4)

	LDA #&00 + 5				; A=00001101	; B5
	STA &FE40					; R0=Output Register "B" (write) (write 0 in to bit 5)
    CLI

\ Setup SHADOW buffers for double buffering

IF  _DOUBLE_BUFFER
    lda &fe34
    and #255-1  ; set D to 0
    ora #4    	; set X to 1
    sta &fe34
ENDIF

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

    .loop
    stx char_col

    \\ Wait for vsync
    lda #19
    jsr osbyte

    \\ Wait for vsync again (25Hz scroll)
    lda #19
    jsr osbyte

    \\ Swap screen buffers here!

    lda &fe34
    eor #5
    sta &fe34

    \\ Set scroll address
    lda #12:sta &fe00
    lda crtc_addr+1:sta &fe01

    lda #13:sta &fe00
    lda crtc_addr:sta &fe01

    \\ Remove sprites from frame

    jsr restore_background

    \\ Start column plot

    jsr set_corner_addr

    \\ Set lookup for this pixel

    lda char_col
    and #3
    clc
    adc #HI(map_c64_to_beeb_p0)
    sta char_byte_map+2

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

    \\ Plot a sprite

    lda num
    ldx x_pos
    ldy y_pos
    jsr plot_sprite

    \\ Animate sprite

    lda char_col            ; definitely need a frame flag!
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

    jmp loop

    .done

    rts
}

INCLUDE "src/scroll.asm"

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
