\ ******************************************************************
\ *	sprite.asm
\ *	Single-sprite plotter with background stash/restore (to be replaced in Layer 3).
\ ******************************************************************

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
