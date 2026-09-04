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
	    bne mr_chk
	    inc map_read+$02
        .mr_chk

        \\ Wrap at the end of the 302-column map (decision 14). The C64
        \\ never gets here: its wave table sets comp_flag first (Layer 5).
        ldy map_read+$01
        cpy #LO(map_end)
        bne mr_out
        ldy map_read+$02
        cpy #HI(map_end)
        bne mr_out
        ldy #LO(map_data)
        sty map_read+$01
        ldy #HI(map_data)
        sty map_read+$02
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

    \\ Completed a tile. The map wraps inside map_read now, not here.

        inc tile_total

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

    \\ File the character code for the collision map (decision 24). Y is
    \\ still the code: the shifting above went through read_char_data+1.
    \\ The twenty calls a frame run top to bottom, so the store walks one
    \\ map row - COLL_COLS bytes - at a time. All four frames of a
    \\ character write the same codes to the same slot: tile_cnt only
    \\ moves between characters, so it is idempotent and needs no test.
    tya
    .coll_store
    sta &ffff
    clc
    lda coll_store+1
    adc #COLL_COLS
    sta coll_store+1
    bcc coll_no_carry
    inc coll_store+2
    .coll_no_carry

    rts
\}

\ Point plot_char_y's collision store at row 0 of the slot the entering
\ character occupies. Called once a frame, beside set_corner_addr.
.coll_frame_start
{
    clc
    lda #LO(coll_map)
    adc coll_wr
    sta coll_store+1
    lda #HI(coll_map)
    adc #0
    sta coll_store+2
    rts
}

\ A character has finished arriving, so the ring moves on: the slot just
\ written becomes screen column 39 and the one after it column 0.
\ IT MUST NOT TOUCH X. The scroll calls this beside tile_cnt_bump, in
\ the middle of the run of tests on char_col + 1, which lives in X from
\ the increment at the top until the corner_addr update at the bottom.
\ tile_cnt_bump counts in Y for the same reason. Clobbering X here put
\ crtc_addr and corner_addr on the wrong frames and broke the scroll
\ outright (KC, 2026-09-03).
.coll_advance
{
    ldy coll_wr
    iny
    cpy #COLL_COLS
    bne no_wrap
    ldy #0
    .no_wrap
    sty coll_wr
    iny
    cpy #COLL_COLS
    bne base_ok
    ldy #0
    .base_ok
    sty coll_base
    rts
}

\ Clear the map to character 0, which col_decode calls empty, and start
\ the ring. Everything is off before the first characters have arrived.
.coll_init
{
    lda #0
    sta coll_wr
    sta coll_base
    ldx #0
    .page_loop
    sta coll_map, x
    sta coll_map+256, x
    sta coll_map+512, x
    inx
    bne page_loop
    jmp coll_advance
}

.set_corner_addr
{
    lda #LO(column_buffer)
    sta write_column_data+1
    sta read_column_data+1
    sta copy_col_char_loop+1
    sta rot_col_data+1          ; the shifted write-back walks WITH the read,
                                ; so it has to be wound back with it. Missing
                                ; this left row 0 unshifted - the top character
                                ; row smeared - and put its write into &04A0,
                                ; the first eight bytes of the collision map

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

.copy_column_buffer
\{
    \\ Copy the column buffer to the screen, AND shift it left one pixel
    \\ on the way out. These used to be two separate 160-byte loops: the
    \\ shift was its own routine, rotate_column_buffer, run at the top of
    \\ scroll_frame before the twenty plot_char_y calls.
    \\
    \\ Fusing them is exact, not an approximation. What reaches the screen
    \\ is shift(last frame's buffer) OR this frame's characters, and it
    \\ makes no difference whether the shift happens at the end of the
    \\ frame that produced the value or at the start of the frame that
    \\ consumes it. Doing it here saves the other loop's own LDA, its
    \\ index arithmetic and its branch - 11 cycles on every one of the
    \\ 160 bytes, about 1,760 a frame - and the code gets SMALLER.
    \\ docs/performance.md.
    \\
    \\ The buffer needs no initial value: one pass of this leaves it
    \\ holding nothing but that frame's right-hand pixels, so whatever
    \\ was in it at boot is gone after the first column.
    ldy #column_size/8

    .copy_col_row_loop

    ldx #7
    .copy_col_char_loop
    lda column_buffer, X
    .write_beeb_data
    sta &3000, X
    asl a
    and #&aa    ; mask out right pixel: the old right one is the new left
    .rot_col_data
    sta column_buffer, X
    dex
    bpl copy_col_char_loop

    \\ Increment to next row. BOTH column-buffer addresses move now: the
    \\ read at the top of the loop and the shifted write-back.

    clc
    lda copy_col_char_loop+1
    adc #8
    sta copy_col_char_loop+1
    sta rot_col_data+1
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
