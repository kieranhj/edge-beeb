\ ******************************************************************
\ *	player.asm
\ *	The player: movement, the fire latch, the bullet, and both
\ *	background collision checks. A transcription of the C64's
\ *	player_manage, player_colls, bullet_colls, player_grinds, the
\ *	bullet half of enemy_manage, and multimate's animation tail.
\ *
\ *	THE GAME LOGIC TICKS TWICE PER DISPLAY FRAME (decision 23). The
\ *	C64's main_loop runs at 50 Hz and ours at 25, so one pass of our
\ *	loop is two of its iterations. Ticking twice rather than doubling
\ *	every constant means the original's numbers - 1 pixel of x, 2 of
\ *	y, 12 of bullet, the scroll_x AND 3 grind gate - all transcribe
\ *	unchanged, and the bullet is collision-checked at each 12-pixel
\ *	step exactly as the original checks it.
\ *
\ *	BACKGROUND COLLISION READS A CHARACTER MAP WE KEEP OURSELVES
\ *	(decision 24). The C64 is a character-mode game and reads the
\ *	character codes back out of its own screen; we draw pixels, so
\ *	scroll.asm writes the codes into coll_map as it plots them and
\ *	this file reads that instead. Same codes, same col_decode, same
\ *	fatal nibble - only the array is ours.
\ ******************************************************************

\ C64 movement bounds, verbatim (player_up/down/left/right).
PLY_X_MIN = &10
PLY_X_MAX = &9b
PLY_Y_MIN = &5a
PLY_Y_MAX = &e5

\ Bullet: 12 pixels a tick. The bounds it dies at are enemy_bounds', in
\ enemy.asm, which walks the bullet's slot as well as the pool's.
BUL_SPEED = &0c

\ The C64 takes the character row from (y - $30) >> 3 and indexes a table
\ of 24 absolute screen rows; ours is the play area alone, which starts
\ PANEL_ROWS character rows further down, so the offset carries that.
\ The two-pixel bias in the original's $30 and $28 is kept: it is what
\ makes the three sampled rows straddle the sprite.
PLY_ROW_OFF = &30 + PANEL_ROWS * 8      ; 88
BUL_ROW_OFF = &28 + PANEL_ROWS * 8      ; 80

\ The player's own animation frames, from the C64's anim_defaults.
PLY_ANIM_START = &0b
PLY_ANIM_END   = &12
BUL_ANIM_START = &12
BUL_ANIM_END   = &13

\ ******************************************************************
\ *	game_tick - one C64 main_loop iteration
\ ******************************************************************
\ The C64's order: player_manage (which ends in the collision checks),
\ enemy_manage (which moves the bullet and then runs multimate), and
\ scroll_manage. The enemy pool and the wave manager are Layer 5; what
\ is here is the bullet's share of enemy_manage.
\
\ joy is read once a display frame rather than once a tick: it cannot
\ change between the two, and keydown costs 69 cycles a key.

.game_tick
{
    jsr player_manage
    jsr bullet_manage
    jsr enemy_manage
    jsr multimate

    \\ scroll_manage's counter. The buffer swaps it also drives are the
    \\ C64's own double buffer and have no equivalent here; what is left
    \\ is the 16-step cycle the grind gate reads.
    ldx scroll_x
    inx
    cpx #&10
    bne no_wrap
    ldx #0
    .no_wrap
    stx scroll_x
    rts
}

\ ******************************************************************
\ *	player_manage - C64 $... player_manage, verbatim
\ ******************************************************************
\ joy carries the C64's joystick bits and its polarity: bit 0 up, 1
\ down, 2 left, 3 right, 4 fire, and a CLEAR bit is pressed. That is
\ what lets the LSR/BCS chain below be the original's.

.player_manage
{
    lda joy

    .player_up
    lsr a
    bcs player_down
    ldx sprite_pos+1
    dex
    dex
    cpx #PLY_Y_MIN
    bcs p_up_out
    ldx #PLY_Y_MIN
    .p_up_out
    stx sprite_pos+1

    .player_down
    lsr a
    bcs player_left
    ldx sprite_pos+1
    inx
    inx
    cpx #PLY_Y_MAX+1
    bcc p_down_out
    ldx #PLY_Y_MAX
    .p_down_out
    stx sprite_pos+1

    .player_left
    lsr a
    bcs player_right
    ldx sprite_pos
    dex
    cpx #PLY_X_MIN
    bcs p_left_out
    ldx #PLY_X_MIN
    .p_left_out
    stx sprite_pos

    .player_right
    lsr a
    bcs player_fire
    ldx sprite_pos
    inx
    cpx #PLY_X_MAX+1
    bcc p_right_out
    ldx #PLY_X_MAX
    .p_right_out
    stx sprite_pos

    \\ The latch stops fire autorepeating: it is set when a bullet goes
    \\ out and only cleared when the button is seen released.
    .player_fire
    ldy fire_latch
    beq fire_bullet
    lsr a
    bcc fire_out
    lda #0
    sta fire_latch
    .fire_out
    jmp player_colls

    \\ The latch says it is okay, so fire if the bullet slot is free.
    .fire_bullet
    lsr a
    bcs player_s_colls
    lda sprite_pos+3
    bne player_s_colls
    lda sprite_pos
    sta sprite_pos+2
    lda sprite_pos+1
    sta sprite_pos+3
    lda #BUL_SPEED
    sta enemy_spds+2
    lda #0
    sta enemy_spds+3
    lda #1
    sta fire_latch
    lda #BUL_ANIM_START
    sta sprite_dp+1
    sta anim_starts+1
    lda #BUL_ANIM_END
    sta anim_ends+1

    \\ Player to enemy collisions: a box round the ship against every
    \\ live enemy. Frames below $0b are the explosion, which cannot hit.
    .player_s_colls
    lda sprite_pos
    sec
    sbc #6
    sta coll_temp
    clc
    adc #&0d
    sta coll_temp+1
    lda sprite_pos+1
    sec
    sbc #&0b
    sta coll_temp+2
    clc
    adc #&18
    sta coll_temp+3

    ldx #0
    ldy #0
    .psc_loop
    lda sprite_dp+ENEMY_FIRST, y
    cmp #&0b
    bcc psc_over
    lda sprite_pos+2*ENEMY_FIRST, x
    cmp coll_temp
    bcc psc_over
    cmp coll_temp+1
    bcs psc_over
    lda sprite_pos+2*ENEMY_FIRST+1, x
    cmp coll_temp+2
    bcc psc_over
    cmp coll_temp+3
    bcs psc_over
    inc coll_flag
IF DEBUG_COLL
    lda #20
    sta sprite_pls_tmr
ENDIF
    .psc_over
    iny
    inx
    inx
    cpx #2*ENEMY_COUNT
    bne psc_loop
    jmp player_colls
}

\ ******************************************************************
\ *	bullet_manage - the bullet's share of the C64's enemy_manage
\ ******************************************************************

.bullet_manage
{
    lda sprite_pos+2
    clc
    adc enemy_spds+2
    sta sprite_pos+2
    rts
}

\ ******************************************************************
\ *	multimate - the C64's animation and pulse-timer tail
\ ******************************************************************
\ Every fourth tick, step every slot's frame between its anim_starts
\ and anim_ends; free the slots whose explosions have finished; count
\ the hit-flash timers down; and run the wave manager. The C64's tail,
\ in its order.

.multimate
{
    ldx anim_tmr
    inx
    cpx #4
    bne mm_out

    ldx #0
    .mm_loop
    lda sprite_dp, x
    clc
    adc #1
    cmp anim_ends, x
    bne mm_over
    lda anim_starts, x
    .mm_over
    sta sprite_dp, x
    inx
    cpx #SPR_SLOTS
    bne mm_loop

    ldx #0
    .mm_out
    stx anim_tmr

    jsr explosion_chk

    \\ Decrement the pulse timers
    ldx #SPR_SLOTS-1
    .pt_loop
    lda sprite_pls_tmr, x
    beq pt_next
    dec sprite_pls_tmr, x
    .pt_next
    dex
    bpl pt_loop

    jmp wave_manager
}

\ ******************************************************************
\ *	coll_read - X = play-area character row, Y = screen character
\ *	column. Returns the fatal nibble of col_decode for that cell.
\ ******************************************************************
\ The C64's coll_read is self-modifying code over its screen; ours
\ indexes coll_map, whose columns are a 40-entry ring that the scroll
\ advances. coll_base is the slot holding screen column 0.

.coll_read
{
    lda coll_row_lo, x
    sta read_ptr
    lda coll_row_hi, x
    sta read_ptr+1
    tya
    clc
    adc coll_base
    cmp #COLL_COLS
    bcc no_wrap
    sbc #COLL_COLS
    .no_wrap
    tay
    lda (read_ptr), y
    tay
    lda col_decode, y           ; in bank 0, the resting state
    and #&f0                    ; the fatal nibble; the low bits are colour
    rts
}

\ ******************************************************************
\ *	player_colls - the C64's player_colls and player_grinds
\ ******************************************************************
\ Three cells in the same column: the row the sprite starts in, two
\ below it, and the one between. The outer two are the grind - scoring
\ and a flash for scraping the scenery - and the middle one is fatal.

.player_colls
{
    lda sprite_pos+1
    sec
    sbc #PLY_ROW_OFF
    lsr a : lsr a : lsr a
    sta coll_row
    lda sprite_pos
    sec
    sbc #8
    lsr a : lsr a
    sta coll_col

    ldx coll_row
    ldy coll_col
    jsr coll_read
    sta coll_grind

    ldx coll_row
    inx
    inx
    ldy coll_col
    jsr coll_read
    sta coll_grind+1

    ldx coll_row
    inx
    ldy coll_col
    jsr coll_read
    beq pc_no_coll

    \\ Collision occurred, so flag it. Layer 6 reads coll_flag and takes
    \\ the life; until then DEBUG_COLL shows it as a long hit flash.
    inc coll_flag
IF DEBUG_COLL
    lda #20
    sta sprite_pls_tmr
ENDIF

    .pc_no_coll
    jsr bullet_colls
    lda scroll_x
    and #3
    cmp #3
    beq player_grinds
    rts
}

\ Grinding the scenery: flash the ship and score 25, twice over if both
\ the top and the bottom edge are touching.
.player_grinds
{
    lda coll_grind
    beq pg_chk_2
    jsr grind_score
    .pg_chk_2
    lda coll_grind+1
    beq pg_out
    jsr grind_score
    .pg_out
    rts
}

.grind_score
{
    lda #4
    sta sprite_pls_tmr
    jsr bump_score_10
    jsr bump_score_10
    jsr bump_score_1
    jsr bump_score_1
    jsr bump_score_1
    jsr bump_score_1
    jmp bump_score_1
}

\ ******************************************************************
\ *	bullet_colls - the C64's bullet_colls
\ ******************************************************************
\ Three cells side by side, which is 12 pixels - exactly one tick of
\ bullet travel, so nothing is tunnelled through.
\
\ TWO GUARDS THE ORIGINAL DOES NOT HAVE. With no bullet its y is 0 and
\ the C64 indexes 27 rows into a 24-row table; and past column 39 it
\ reads into the next row down. Both are off-screen nonsense there and
\ would be an out-of-range read here, so both return "no collision".

.bullet_colls
{
    lda sprite_pos+3
    beq out
    sec
    sbc #BUL_ROW_OFF
    lsr a : lsr a : lsr a
    sta coll_row
    lda sprite_pos+2
    sec
    sbc #4
    lsr a : lsr a
    sta coll_col
    cmp #COLL_COLS
    bcs out

    ldx coll_row
    ldy coll_col
    jsr coll_read
    bne bullet_reset

    ldy coll_col
    iny
    cpy #COLL_COLS
    bcs skip_right
    ldx coll_row
    jsr coll_read
    bne bullet_reset
    .skip_right

    ldy coll_col
    beq out
    dey
    ldx coll_row
    jsr coll_read
    bne bullet_reset
    .out
    rts
}

.bullet_reset
{
    lda #0
    sta sprite_pos+2
    sta sprite_pos+3
    sta enemy_spds+2
    sta enemy_spds+3
    rts
}

\ ******************************************************************
\ *	Score - six decimal digits, one to a byte, most significant first
\ ******************************************************************
\ The C64's bump_score_* and its high-score compare, verbatim. Layer 6
\ puts them on the panel.

.bump_score_1
{
    ldx #5
    jmp bs_loop
}

.bump_score_10
{
    ldx #4
    jmp bs_loop
}

.bump_score_100
{
    ldx #3
    jmp bs_loop
}

.bump_score_1000
{
    ldx #2
}
.bs_loop
{
    .loop
    lda score, x
    clc
    adc #1
    cmp #10
    beq carry
    sta score, x
    jmp bs_out
    .carry
    lda #0
    sta score, x
    dex
    cpx #&ff
    bne loop
}

\ Score to high score comparison, then copy if it is ahead
.bs_out
{
    ldx #0
    .scan
    lda score, x
    cmp hi_score, x
    beq next
    bcc out
    bcs update
    .next
    inx
    cpx #SCORE_DIGITS
    bne scan
    .out
    rts
    .update
    ldx #0
    .copy
    lda score, x
    sta hi_score, x
    inx
    cpx #SCORE_DIGITS
    bne copy
    rts
}

.score_reset
{
    ldx #SCORE_DIGITS-1
    lda #0
    .loop
    sta score, x
    dex
    bpl loop
    rts
}

\ ******************************************************************
\ *	sprite_reset - the C64's, for the slots this layer owns
\ ******************************************************************
\ spr_defaults puts the player at $28,$a0 and anim_defaults gives him
\ frames $0b-$11; the bullet's slot starts empty.

.sprite_reset
{
    lda #&28 : sta sprite_pos
    lda #&a0 : sta sprite_pos+1
    lda #0
    sta sprite_pos+2
    sta sprite_pos+3
    sta enemy_spds+2
    sta enemy_spds+3
    sta fire_latch
    sta coll_flag
    sta anim_tmr
    sta scroll_x

    jsr enemy_init
    lda #PLY_ANIM_START
    sta sprite_dp
    sta anim_starts
    lda #PLY_ANIM_END
    sta anim_ends
    lda #BUL_ANIM_START
    sta anim_starts+1
    sta sprite_dp+1
    lda #BUL_ANIM_END
    sta anim_ends+1
    rts
}
