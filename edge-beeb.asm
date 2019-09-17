\ ******************************************************************
\ *	EDGE GRINDER
\ ******************************************************************

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

; Self modifying code for the map reader
.map_read
{
   	    lda map_data
	    inc map_read+$01
	    bne mr_out
	    inc map_read+$02
        .mr_out
	    rts
}

; Map reader self modifying code reset
.map_read_rst
{
    	lda #LO(map_data)
		sta map_read+$01
		lda #HI(map_data)
		sta map_read+$02
		jmp tile_update
}

; Tile self modifying code updaters
.tile_update
{
        jsr map_read
		sta tile_read_1+$01
		asl tile_read_1+$01
		asl tile_read_1+$01
		asl tile_read_1+$01
		asl tile_read_1+$01
		lsr a
		lsr a
		lsr a
		lsr a
		clc
		adc #HI(tile_data)
		sta tile_read_1+$02

		jsr map_read
		sta tile_read_2+$01
		asl tile_read_2+$01
		asl tile_read_2+$01
		asl tile_read_2+$01
		asl tile_read_2+$01
		lsr a
		lsr a
		lsr a
		lsr a
		clc
		adc #HI(tile_data)
		sta tile_read_2+$02

		jsr map_read
		sta tile_read_3+$01
		asl tile_read_3+$01
		asl tile_read_3+$01
		asl tile_read_3+$01
		asl tile_read_3+$01
		lsr a
		lsr a
		lsr a
		lsr a
		clc
		adc #HI(tile_data)
		sta tile_read_3+$02

		jsr map_read
		sta tile_read_4+$01
		asl tile_read_4+$01
		asl tile_read_4+$01
		asl tile_read_4+$01
		asl tile_read_4+$01
		lsr a
		lsr a
		lsr a
		lsr a
		clc
		adc #HI(tile_data)
		sta tile_read_4+$02

		jsr map_read
		sta tile_read_5+$01
		asl tile_read_5+$01
		asl tile_read_5+$01
		asl tile_read_5+$01
		asl tile_read_5+$01
		lsr a
		lsr a
		lsr a
		lsr a
		clc
		adc #HI(tile_data)
		sta tile_read_5+$02
		rts
}

; Self modifying code for the tile readers
.tile_read_1
{
        ldy tile_data,x
		rts
}

.tile_read_2
{
        ldy tile_data,x
		rts
}

.tile_read_3
{
        ldy tile_data,x
		rts
}

.tile_read_4
{
        ldy tile_data,x
		rts
}

.tile_read_5
{
        ldy tile_data,x
		rts
}

; Specific case checks for scrolling
.tile_cnt_bump
{
    	ldy tile_cnt
		iny
		cpy #$04
		bne tcb_out

    \\ Completed a tile - check for looping the map

        ldy tile_total
        iny
        bne no_loop

        \\ Reset our map reader to start of data
        jsr map_read_rst

        .no_loop
        sty tile_total

		jsr tile_update

		ldy #$00
    .tcb_out
    	sty tile_cnt

		rts
}

.plot_char_y
\{
    \\ 8 bytes per char
    sty read_char_data+1
    lda #0
    asl read_char_data+1
    rol a
    asl read_char_data+1
    rol a
    asl read_char_data+1
    rol a
    clc
    adc #HI(char_data)
    sta read_char_data+2

    ldx #7
    .plot_char_loop

    .read_char_data
    ldy &FFFF, X

    .read_column_data
    lda column_buffer, X

    .char_byte_map
    ora map_c64_to_beeb_p0, y    ; mask in right hand pixel

    .write_column_data
    sta column_buffer, X

    dex
    bpl plot_char_loop

    \\ Increment to next row

    clc
    lda write_column_data+1
    adc #8
    sta write_column_data+1
    sta read_column_data+1
    \\ Won't overflow

    rts
\}

.set_corner_addr
{
    lda #LO(column_buffer)
    sta write_column_data+1
    sta read_column_data+1
    sta copy_col_char_loop+1

    clc
    lda corner_addr
    adc #LO(80*8)
    sta write_beeb_data+1
    lda corner_addr+1
    adc #HI(80*8)
    cmp #HI(screen_top)
    bcc ok
    sbc #HI(screen_size)
    .ok
    sta write_beeb_data+2

    rts
}

.rotate_column_buffer
{
    \\ Shift all pixels left
    ldx #0
    .loop
    lda column_buffer, X
    asl a
    and #&aa    ; mask out right pixel
    sta column_buffer, X
    inx
    cpx #column_size
    bcc loop

    rts
}

.copy_column_buffer
\{
    \\ Copy column buffer to screen
    ldy #column_size/8
    
    .copy_col_row_loop

    ldx #7
    .copy_col_char_loop
    lda column_buffer, X
    .write_beeb_data
    sta &3000, X
    dex
    bpl copy_col_char_loop

    \\ Increment to next row

    clc
    lda copy_col_char_loop+1
    adc #8
    sta copy_col_char_loop+1
    \\ won't overflow

    clc
    lda write_beeb_data+1
    adc #LO(row_stride)
    sta write_beeb_data+1
    lda write_beeb_data+2
    adc #HI(row_stride)
    cmp #HI(screen_top)
    bcc row_ok
    sbc #HI(screen_size)
    .row_ok
    sta write_beeb_data+2
    
    dey
    bne copy_col_row_loop
    rts
\}

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

\\ A=sprite no, X=column X, Y=line
.plot_sprite
{
    sta sprite_no

    jsr calc_sprite_write_ptr

    \\ Calculate sprite read address
    ldx sprite_no
    lda sprite_addr_LO, X
    sta load_sprite_byte+1
    lda sprite_addr_HI, X
    sta load_sprite_byte+2

    clc
    ldx #0

    lda #sprite_height
    sta y_count

    .y_loop

    lda #sprite_width_bytes
    sta x_count

    lda write_ptr
    sta read_ptr
    lda write_ptr+1
    sta read_ptr+1

    .x_loop
    stx sprite_idx

    .load_sprite_byte
    lda &ffff, X
    sta sprite_byte

    \\ Top nibble
    lsr a:lsr a:lsr a:lsr a
    tax

    \\ Load screen byte
    ldy #0
    lda (read_ptr), Y

    \\ Mask
    and map_c64_nibble_to_mask, x

    \\ OR in sprite
    ora map_c64_nibble_to_mode2, x

    \\ Store screen byte
    sta (read_ptr), Y

    \\ Next column
    {
        clc
        lda read_ptr
        adc #8
        sta read_ptr
        lda read_ptr+1
        adc #0
        cmp #HI(screen_top)
        bcc read_ok
        sbc #HI(screen_size)
        .read_ok
        sta read_ptr+1
    }

    \\ Bottom nibble
    lda sprite_byte
    and #&f
    tax

    \\ Load screen byte
    lda (read_ptr), Y

    \\ Mask
    and map_c64_nibble_to_mask, x

    \\ OR in sprite
    ora map_c64_nibble_to_mode2, x

    \\ Store screen byte
    sta (read_ptr), Y

    \\ Next column
    {
        clc
        lda read_ptr
        adc #8
        sta read_ptr
        lda read_ptr+1
        adc #0
        cmp #HI(screen_top)
        bcc read_ok
        sbc #HI(screen_size)
        .read_ok
        sta read_ptr+1
    }

    \\ Next sprite byte
    ldx sprite_idx
    inx

    dec x_count
    bne x_loop

    \\ Next line

    lda write_ptr
    and #7
    cmp #7
    beq increment_row
    inc write_ptr
    jmp next

    .increment_row
    {
        clc
        lda write_ptr
        adc #LO(640-7)
        sta write_ptr
        lda write_ptr+1
        adc #HI(640-7)
        cmp #HI(screen_top)
        bcc inc_ok
        sbc #HI(screen_size)
        .inc_ok
        sta write_ptr+1
    }

    .next
    dec y_count
    beq done
    jmp y_loop
    .done

    rts
}

.calc_sprite_write_ptr
{
    \\ X*8
    clc
    lda corner_addr
    adc mult8_LO, X
    sta write_ptr
    lda corner_addr+1
    adc mult8_HI, X
    sta write_ptr+1

    \\ Add y MOD 7
    tya
    and #7
    adc write_ptr
    sta write_ptr

    \\ Add (y DIV 8)*640
    tya
    lsr a:lsr a:lsr a
    tax
    clc
    lda write_ptr
    adc mult640_LO, X
    sta write_ptr
    lda write_ptr+1
    adc mult640_HI, X

    \\ Check for wrap
    cmp #HI(screen_top)
    bcc write_ok
    sbc #HI(screen_size)
    .write_ok
    sta write_ptr+1

    rts
}

.restore_background
{
    lda char_col
    and #1
;    eor #1  ; the other buffer!
    asl a
    tax

    lda bg_ptrs+1, X
    beq return          ; nothing to see here
    sta write_ptr+1
    lda bg_ptrs, X
    sta write_ptr

    \\ Which stash?

    lda char_col
    and #1
;    eor #1  ; the other buffer!
    clc
    adc #HI(background_stash_0)
    sta stash_addr+2

    \\ Retore 6*21=126 bytes of screen

    ldx #0
    ldy #0

    lda #sprite_height
    sta y_count

    .y_loop

    lda #sprite_width_bytes*2   ; for MODE 2
    sta x_count

    lda write_ptr
    sta read_ptr
    lda write_ptr+1
    sta read_ptr+1

    .x_loop

    .stash_addr
    lda background_stash_0, X
    sta (read_ptr), Y

    \\ Next column
    {
        clc
        lda read_ptr
        adc #8
        sta read_ptr
        lda read_ptr+1
        adc #0
        cmp #HI(screen_top)
        bcc read_ok
        sbc #HI(screen_size)
        .read_ok
        sta read_ptr+1
    }

    \\ Next byte
    inx

    dec x_count
    bne x_loop

    \\ Next line

    lda write_ptr
    and #7
    cmp #7
    beq increment_row
    inc write_ptr
    jmp next

    .increment_row
    {
        clc
        lda write_ptr
        adc #LO(640-7)
        sta write_ptr
        lda write_ptr+1
        adc #HI(640-7)
        cmp #HI(screen_top)
        bcc inc_ok
        sbc #HI(screen_size)
        .inc_ok
        sta write_ptr+1
    }

    .next
    dec y_count
    bne y_loop

    .return
    rts
}


.stash_background
{
    jsr calc_sprite_write_ptr

    \\ Remember what address we saved

    lda char_col
    and #1
    asl a
    tax

    lda write_ptr
    sta bg_ptrs, X
    lda write_ptr+1
    sta bg_ptrs+1, X

    \\ Which stash?

    lda char_col
    and #1
    clc
    adc #HI(background_stash_0)
    sta stash_addr+2

    \\ Store 6*21=126 bytes of screen

    ldx #0
    ldy #0

    lda #sprite_height
    sta y_count

    .y_loop

    lda #sprite_width_bytes*2   ; for MODE 2
    sta x_count

    lda write_ptr
    sta read_ptr
    lda write_ptr+1
    sta read_ptr+1

    .x_loop

    lda (read_ptr), Y

    .stash_addr
    sta background_stash_0, X

    \\ Next column
    {
        clc
        lda read_ptr
        adc #8
        sta read_ptr
        lda read_ptr+1
        adc #0
        cmp #HI(screen_top)
        bcc read_ok
        sbc #HI(screen_size)
        .read_ok
        sta read_ptr+1
    }

    \\ Next byte
    inx

    dec x_count
    bne x_loop

    \\ Next line

    lda write_ptr
    and #7
    cmp #7
    beq increment_row
    inc write_ptr
    jmp next

    .increment_row
    {
        clc
        lda write_ptr
        adc #LO(640-7)
        sta write_ptr
        lda write_ptr+1
        adc #HI(640-7)
        cmp #HI(screen_top)
        bcc inc_ok
        sbc #HI(screen_size)
        .inc_ok
        sta write_ptr+1
    }

    .next
    dec y_count
    bne y_loop

    rts
}

.read_keyboard
{
    \\ Read keyboard

    lda #&79
    ldx #KEY_UP EOR &80
    jsr osbyte
    txa
    bpl not_up
    \\ Up
    dec y_pos
    dec y_pos
    .not_up

    lda #&79
    ldx #KEY_DOWN EOR &80
    jsr osbyte
    txa
    bpl not_down
    \\ Down
    inc y_pos
    inc y_pos
    .not_down

    lda #&79
    ldx #KEY_LEFT EOR &80
    jsr osbyte
    txa
    bpl not_left
    \\ Left
    dec x_pos
    .not_left

    lda #&79
    ldx #KEY_RIGHT EOR &80
    jsr osbyte
    txa
    bpl not_right
    \\ Right
    inc x_pos
    .not_right

    rts
}

.code_end

\ ******************************************************************
\ *	DATA
\ ******************************************************************

.data_start

.bank0_filename EQUS "Bank0",13

.osfile_params
.osfile_nameaddr
EQUW bank0_filename
; file load address
.osfile_loadaddr
EQUD &4000
; file exec address
.osfile_execaddr
EQUD 0
; start address or length
.osfile_length
EQUD 0
; end address of attributes
.osfile_endaddr
EQUD 0

.mult8_LO
FOR n,0,79,1
    EQUB LO(n*8)
NEXT

.mult8_HI
FOR n,0,79,1
    EQUB HI(n*8)
NEXT

.mult640_LO
FOR n,0,31,1
    EQUB LO(n*640)
NEXT

.mult640_HI
FOR n,0,31,1
    EQUB HI(n*640)
NEXT

.map_c64_nibble_to_mask
FOR p,0,15,1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1
    p2=(C*2)+c:p3=(D*2)+d

    IF p2=0
        lp=&AA
    ELSE
        lp=0
    ENDIF

    IF p3=0
        rp=&55
    ELSE
        rp=0
    ENDIF

    EQUB lp OR rp

\\ 0->transparent
\\ 1->black
\\ 2->sprite colour
\\ 3->white
NEXT

.map_c64_nibble_to_mode2
FOR p,0,15,1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1
    p2=(C*2)+c:p3=(D*2)+d

    IF p2=3
        lp=SPRITE_PIX_3 AND MODE2_PIXEL_LEFT_MASK
    ELIF p2=2
        lp=SPRITE_PIX_2 AND MODE2_PIXEL_LEFT_MASK
    ELIF p2=1
        lp=SPRITE_PIX_1 AND MODE2_PIXEL_LEFT_MASK
    ELSE
        lp=SPRITE_PIX_0 AND MODE2_PIXEL_LEFT_MASK
    ENDIF

    IF p3=3
        rp=SPRITE_PIX_3 AND MODE2_PIXEL_RIGHT_MASK
    ELIF p3=2
        rp=SPRITE_PIX_2 AND MODE2_PIXEL_RIGHT_MASK
    ELIF p3=1
        rp=SPRITE_PIX_1 AND MODE2_PIXEL_RIGHT_MASK
    ELSE
        rp=SPRITE_PIX_0 AND MODE2_PIXEL_RIGHT_MASK
    ENDIF

    EQUB lp OR rp

\\ 0->transparent
\\ 1->black
\\ 2->sprite colour
\\ 3->white
NEXT

PAGE_ALIGN
.background_stash_0
skip 126

PAGE_ALIGN
.background_stash_1
skip 126

PAGE_ALIGN
.map_c64_to_beeb_p0
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p0
NEXT

PAGE_ALIGN
.map_c64_to_beeb_p1
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p1
NEXT

PAGE_ALIGN
.map_c64_to_beeb_p2
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p2
NEXT

PAGE_ALIGN
.map_c64_to_beeb_p3
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p3
NEXT

PAGE_ALIGN
.sprite_addr_LO
FOR n,0,sprite_total-1,1
    EQUB LO(sprite_data + n*sprite_stride)
NEXT

.sprite_addr_HI
FOR n,0,sprite_total-1,1
    EQUB HI(sprite_data + n*sprite_stride)
NEXT

.data_end

\ ******************************************************************
\ *	End address to be saved
\ ******************************************************************

.end

\ ******************************************************************
\ *	Save the code
\ ******************************************************************

SAVE "Edge", start, end

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
\ * SWRAM DATA BANK
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank0_start

\\ Characters are 4x8 wide pixels and there are 256 in total = 2048 bytes (8 bytes each @ 2bpp) (tiles.chr)

PAGE_ALIGN
.char_data
INCBIN "data/tiles.chr.bin"
PRINT "CHARACTER data =", ~char_data

\\ Each tile is made up of 4x4 characters and there are 211 in total = 3376 bytes (16 bytes each) (tiles.til)

PAGE_ALIGN
.tile_data
INCBIN "data/tiles.til.bin"
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high vertically and 256 tiles wide = 1280 bytes (tiles.map)

PAGE_ALIGN
.map_data
INCBIN "data/tiles.map.bin"
PRINT "MAP data =", ~map_data

\\ Map2 is 5 tiles high vertically and 46 tiles wide = 230 bytes (tiles2.map)
\\ Map2 follows on from Map1 data - it's not a separate level!

.map2_data
INCBIN "data/tiles2.map.bin"
PRINT "MAP2 data =", ~map2_data

PAGE_ALIGN
.sprite_data
INCBIN "data/sprites.spr.bin"
PRINT "SPRITE data =", ~sprite_data

.bank0_end

SAVE "BANK0", bank0_start, bank0_end

PRINT "------"
PRINT "BANK 0"
PRINT "------"
PRINT "DATA size =",~bank0_end-bank0_start
PRINT "------"
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"

\ ******************************************************************
\ *	Any other files for the disc
\ ******************************************************************
