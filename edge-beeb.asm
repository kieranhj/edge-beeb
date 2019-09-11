\ ******************************************************************
\ *	EDGE GRINDER
\ ******************************************************************

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

\ ******************************************************************
\ *	SYSTEM defines
\ ******************************************************************

BG_COL_0 = PAL_black
BG_COL_1 = PAL_blue
BG_COL_2 = PAL_white
BG_COL_3 = PAL_green          ; PAL_red or PAL_cyan also look OK

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

screen_addr = &3000

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

    \\ Set palette
IF 0
    ldx #15
    .pal_loop
    lda mode5_palette, X
    sta &FE21
    dex
    bpl pal_loop
ENDIF

    \\ 

    lda #LO(screen_addr + 79*8)
    sta col_addr
    lda #HI(screen_addr + 79*8)
    sta col_addr+1

    lda #LO(screen_addr/8)
    sta scroll_addr
    lda #HI(screen_addr/8)
    sta scroll_addr+1

    \\ Initialise variables

    .here
    ldx #0
    stx tile_cnt

    \\ Initialise the tile readers

    jsr tile_update

    .loop
    stx char_col
    jsr set_col_addr

    lda char_col
    and #1
    bne map_right
    \\ map left

    LDA #HI(map_c64_to_beeb_L)
    STA char_byte_map+2
    BNE map_cont

    .map_right
    LDA #HI(map_c64_to_beeb_R)
    STA char_byte_map+2

    .map_cont

    \\ Wait for vsync
    lda #19
    jsr osbyte

    \\ Set scroll address
    lda #12:sta &fe00
    lda scroll_addr+1:sta &fe01

    lda #13:sta &fe00
    lda scroll_addr:sta &fe01

    \\ Wait for vsync again (25Hz scroll)
    lda #19
    jsr osbyte

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

    \\ Plot a cheeky blank to separate scroll wrap around garbage
    
    ldy #255
    jsr plot_char_y

    \\ Increment column

    ldx char_col
    inx

    \\ Two columns per character

    txa
    and #1
    bne no_bump

    \\ Bump the tile_cnt

    jsr tile_cnt_bump

    .no_bump

    \\ Increment scroll

    clc
    lda scroll_addr
    adc #1
    sta scroll_addr
    lda scroll_addr+1
    adc #0
    cmp #HI(&8000/8)
    bcc scroll_ok
    sbc #HI(&5000/8)
    .scroll_ok
    sta scroll_addr+1

    lda col_addr
    adc #8
    sta col_addr
    lda col_addr+1
    adc #0
    cmp #HI(&8000)
    bcc col_ok
    sbc #HI(&5000)
    .col_ok
    sta col_addr+1

;    jsr osrdch

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

    .char_byte_map
    lda map_c64_to_beeb_L, y

    .write_beeb_data
    sta &3000, X

    dex
    bpl plot_char_loop

    \\ Increment to next row

    clc
    lda write_beeb_data+1
    adc #LO(640)
    sta write_beeb_data+1
    lda write_beeb_data+2
    adc #HI(640)
    cmp #HI(&8000)
    bcc row_ok
    sbc #HI(&5000)
    .row_ok
    sta write_beeb_data+2

    rts
\}

.set_char_column
{
    stx write_beeb_data+1
    lda #0
    asl write_beeb_data+1
    rol a
    asl write_beeb_data+1
    rol a
    asl write_beeb_data+1
    rol a
    clc
    adc #HI(screen_addr)
    sta write_beeb_data+2
    rts
}

.set_col_addr
{
    lda col_addr
    sta write_beeb_data+1
    lda col_addr+1
    sta write_beeb_data+2
    rts
}

.code_end

\ ******************************************************************
\ *	DATA
\ ******************************************************************

.data_start

.mode5_palette
{
    EQUB &00 + BG_COL_0
    EQUB &10 + BG_COL_0
    EQUB &20 + BG_COL_1
    EQUB &30 + BG_COL_1
    EQUB &40 + BG_COL_0
    EQUB &50 + BG_COL_0
    EQUB &60 + BG_COL_1
    EQUB &70 + BG_COL_1
    EQUB &80 + BG_COL_2
    EQUB &90 + BG_COL_2
    EQUB &A0 + BG_COL_3
    EQUB &B0 + BG_COL_3
    EQUB &C0 + BG_COL_2
    EQUB &D0 + BG_COL_2
    EQUB &E0 + BG_COL_3
    EQUB &F0 + BG_COL_3
}

\\ Characters are 4x8 wide pixels and there are 256 in total = 2048 bytes (8 bytes each @ 2bpp) (tiles.chr)

PRINT "Skipping ", &FE-(P% MOD &100), "bytes"
SKIP &FE-(P% MOD &100)
.characters_bin
INCBIN "source_c64/data/tiles.chr"
char_data = characters_bin+2
PRINT "CHARACTER data =", ~char_data

\\ Each tile is made up of 4x4 characters and there are 211 in total = 3376 bytes (16 bytes each) (tiles.til)

PRINT "Skipping ", &FE-(P% MOD &100), "bytes"
SKIP &FE-(P% MOD &100)
.tiles_bin
INCBIN "source_c64/data/tiles.til"
tile_data = tiles_bin+2
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high vertically and 256 tiles wide = 1280 bytes (tiles.map)

PRINT "Skipping ", &FE-(P% MOD &100), "bytes"
SKIP &FE-(P% MOD &100)
.map_bin
INCBIN "source_c64/data/tiles.map"
map_data = map_bin+2
PRINT "MAP data =", ~map_data

.map_c64_to_beeb_L
FOR p,0,255,1
    A=(p>>7)AND1
    a=(p>>6)AND1
    B=(p>>5)AND1
    b=(p>>4)AND1
    C=(p>>3)AND1
    c=(p>>2)AND1
    D=(p>>1)AND1
    d=(p>>0)AND1

;   EQUB (A<<7) OR (B<<6) OR (C<<5) OR (D<<4) OR (a<<3) OR (b<<2) OR (c<<1) OR (d<<0)
    EQUB (A<<3) OR (B<<2) OR (a<<1) OR (b<<0)

NEXT

.map_c64_to_beeb_R
FOR p,0,255,1
    A=(p>>7)AND1
    a=(p>>6)AND1
    B=(p>>5)AND1
    b=(p>>4)AND1
    C=(p>>3)AND1
    c=(p>>2)AND1
    D=(p>>1)AND1
    d=(p>>0)AND1

;   EQUB (A<<7) OR (B<<6) OR (C<<5) OR (D<<4) OR (a<<3) OR (b<<2) OR (c<<1) OR (d<<0)
    EQUB (C<<3) OR (D<<2) OR (c<<1) OR (d<<0)

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
