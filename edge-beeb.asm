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

\ ******************************************************************
\ *	SYSTEM defines
\ ******************************************************************

BG_COL_0 = PAL_black
BG_COL_1 = PAL_blue
BG_COL_2 = PAL_white
BG_COL_3 = PAL_green          ; PAL_red or PAL_cyan also look OK

BG_PIX_0 = MODE2_PIXEL_00
BG_PIX_1 = MODE2_PIXEL_04
BG_PIX_2 = MODE2_PIXEL_07
BG_PIX_3 = MODE2_PIXEL_02

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

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

screen_addr = &4000
screen_size = &4000
screen_top = screen_addr + screen_size
row_stride = 640

column_buffer = &400        ; 160 bytes for right hand column
column_size = 160

\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &00
GUARD &9F

.tile_cnt       skip 1
.char_col       skip 1

.col_addr       skip 2
.scroll_addr    skip 2

\ ******************************************************************
\ *	CODE START
\ ******************************************************************

ORG &E00
GUARD screen_addr

.start

\ ******************************************************************
\ *	Code entry
\ ******************************************************************

.code_start

.main
{
	\\ Set MODE

	lda #22
	jsr oswrch
	lda #2
	jsr oswrch

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

    lda #LO(screen_addr + 80*8)
    sta col_addr
    lda #HI(screen_addr + 80*8)
    sta col_addr+1

    lda #LO(screen_addr/8)
    sta scroll_addr
    lda #HI(screen_addr/8)
    sta scroll_addr+1

    \\ Initialise variables

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
    lda scroll_addr+1:sta &fe01

    lda #13:sta &fe00
    lda scroll_addr:sta &fe01

    \\ Start column plot

    jsr set_col_addr

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
    lda scroll_addr
    adc #1
    sta scroll_addr
    lda scroll_addr+1
    adc #0
    cmp #HI(screen_top/8)
    bcc scroll_ok
    sbc #HI(screen_size/8)
    .scroll_ok
    sta scroll_addr+1
IF _DOUBLE_BUFFER
    .no_scroll

    txa
    and #1
    bne no_column
ENDIF

    clc
    lda col_addr
    adc #8
    sta col_addr
    lda col_addr+1
    adc #0
    cmp #HI(screen_top)
    bcc col_ok
    sbc #HI(screen_size)
    .col_ok
    sta col_addr+1

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

.set_col_addr
{
    lda #LO(column_buffer)
    sta write_column_data+1
    sta read_column_data+1
    sta copy_col_char_loop+1

    lda col_addr
    sta write_beeb_data+1
    lda col_addr+1
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

.code_end

\ ******************************************************************
\ *	DATA
\ ******************************************************************

.data_start

\\ Characters are 4x8 wide pixels and there are 256 in total = 2048 bytes (8 bytes each @ 2bpp) (tiles.chr)

MACRO PAGE_ALIGN
H%=P%
ALIGN &100
PRINT "Skipping ", P%-H%, "bytes"
ENDMACRO

PAGE_ALIGN
.characters_bin
.char_data
INCBIN "data/tiles.chr.bin"
PRINT "CHARACTER data =", ~char_data

\\ Each tile is made up of 4x4 characters and there are 211 in total = 3376 bytes (16 bytes each) (tiles.til)

PAGE_ALIGN
.tiles_bin
.tile_data
INCBIN "data/tiles.til.bin"
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high vertically and 256 tiles wide = 1280 bytes (tiles.map)

PAGE_ALIGN
.map_bin
.map_data
INCBIN "data/tiles.map.bin"
PRINT "MAP data =", ~map_data

.map_c64_to_beeb_p0
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p0
NEXT

.map_c64_to_beeb_p1
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p1
NEXT

.map_c64_to_beeb_p2
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p2
NEXT

.map_c64_to_beeb_p3
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p3
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
PRINT "FREE =", ~screen_addr-P%
PRINT "------"

\ ******************************************************************
\ *	Any other files for the disc
\ ******************************************************************
