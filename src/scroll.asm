\ ******************************************************************
\ *	scroll.asm
\ *	Map reader, tile readers, column buffer and the column copy to screen.
\ *	One new byte column per frame; see docs/layer-0-toolchain.md for the scheme.
\ ******************************************************************

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
    adc plane_hi                ; this frame's pixel column of every char
    sta read_char_data+2

    ldx #7
    .plot_char_loop

    .read_column_data
    lda column_buffer, X

    .read_char_data
    ora &FFFF, X                ; plane byte: colour already in the right pixel

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
