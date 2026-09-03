\ ******************************************************************
\ *	enemy.asm
\ *	The attack waves and the enemy pool: the C64's wave_manager,
\ *	wave_read, the movement half of enemy_manage, emove_*,
\ *	enemy_bounds, enemy_colls and explosion_chk, transcribed.
\ *
\ *	SLOTS 2-7 ARE THE POOL, which is the C64's arrangement and the
\ *	reason its code is full of `+$02,y` and `+$04,x`: Y walks the
\ *	one-byte-per-slot arrays and X the two-byte sprite_pos, both
\ *	starting at slot 2. Those offsets are kept exactly as they are,
\ *	because our arrays have the same shape as the original's.
\ *
\ *	A WAVE IS NINE BYTES (tools/export_waves.py): start x and y, two
\ *	movement commands, the timer value it rocks between them at, the
\ *	value the timer wraps at, the object, its shielding, and the delay
\ *	before the next wave. 201 of them, in bank 0, read a byte at a time
\ *	by self-modifying code exactly as the map is.
\ *
\ *	A MOVEMENT COMMAND IS FOUR BIT PAIRS - up, down, left, right -
\ *	applied twice per tick, so `left_1` is one pixel a tick and
\ *	`left_2` two. Vertical steps are doubled because the C64's y is
\ *	not halved the way its x is.
\ ******************************************************************

ENEMY_FIRST = 2                 ; slots 2-7; 0 is the player, 1 his bullet
ENEMY_COUNT = SPR_SLOTS - ENEMY_FIRST
ENEMY_X_KILL = &d0              ; enemy_bounds
ENEMY_Y_LIVE = &40
EXPL_OBJECT = 0                 ; anim_decode entry 0, the explosion
EXPL_LAST = &0a                 ; its final frame: the slot is free again
WAVE_START_DELAY = &10          ; wave_read_rst's first wait
WAVE_BYTES = 9                  ; one wave; the skip path must eat all nine

\ ******************************************************************
\ *	wave_read - one byte of the table, self-modifying as map_read is
\ ******************************************************************
\ Runs with SWRAM_DATA paged in, which is the resting state and what
\ game_tick has in.

.wave_read
{
    lda wave_data
    inc wave_read+1
    bne out
    inc wave_read+2
    .out
    rts
}

.wave_read_rst
{
    lda #LO(wave_data)
    sta wave_read+1
    lda #HI(wave_data)
    sta wave_read+2
    lda #WAVE_START_DELAY
    sta wave_tmr
    rts
}

\ ******************************************************************
\ *	wave_manager - count down, then spawn whatever is next
\ ******************************************************************
\ It loops back to itself after a spawn rather than returning, because a
\ wave whose "time to next" is zero means several enemies in one tick.
\ The C64 calls that "a little messy" and it is, but it is the shape the
\ table is written against.

.wave_manager
{
    ldx wave_tmr
    beq new_enemy
    dex
    stx wave_tmr
    rts

    \\ An enemy is approaching... find it an object. A slot is free when
    \\ its y is zero, which is what explosion_chk and enemy_bounds leave.
    .new_enemy
    ldx #0
    .find
    lda sprite_pos+2*ENEMY_FIRST+1, x
    beq assign
    inx
    inx
    cpx #2*ENEMY_COUNT
    bne find
    jmp fail

    \\ Assign the enemy to the slot found. X indexes sprite_pos and
    \\ enemy_spds by twos, Y the one-byte-a-slot arrays by ones.
    .assign
    txa
    lsr a
    tay
    jsr wave_read
    cmp #&ff
    bne assign_2
    jmp wm_comp

    .assign_2
    sta sprite_pos+2*ENEMY_FIRST, x
    jsr wave_read
    sta sprite_pos+2*ENEMY_FIRST+1, x
    jsr wave_read
    sta enemy_spds+2*ENEMY_FIRST, x
    jsr wave_read
    sta enemy_spds+2*ENEMY_FIRST+1, x
    jsr wave_read
    sta enemy_rockers+ENEMY_FIRST, y
    jsr wave_read
    sta enemy_resets+ENEMY_FIRST, y
    lda #&ff
    sta enemy_tmrs+ENEMY_FIRST, y

    \\ The object byte indexes anim_decode, which is in bank 0 with the
    \\ table it came from.
    jsr wave_read
    asl a
    tax
    lda anim_decode, x
    sta sprite_dp+ENEMY_FIRST, y
    sta anim_starts+ENEMY_FIRST, y
    lda anim_decode+1, x
    sta anim_ends+ENEMY_FIRST, y

    jsr wave_read
    sta enemy_shields+ENEMY_FIRST, y
    jsr wave_read
    sta wave_tmr
    jmp wave_manager            ; see the note above

    \\ The end of the table. The C64 never reaches it in play - see
    \\ decision 14 - and Layer 6 is what reads comp_flag.
    \ NOT .comp_flag: a local label of that name would shadow the
    \ variable inside this block and the store would land in code.
    .wm_comp
    lda #1
    sta comp_flag
    rts

    \\ No slot free, so the wave is read past and thrown away. Its last
    \\ byte is still the delay to the next one.
    \\
    \\ IT MUST CONSUME THE WHOLE NINE BYTES. The C64 writes eight
    \\ `jsr wave_read` out longhand after the one above; this loop is the
    \\ same count, and getting it wrong leaves the reader one byte out of
    \\ step for the rest of the game - every later wave read with its
    \\ fields shifted, enemies at nonsense positions on nonsense courses,
    \\ and an object byte that gives a blank frame which still collides.
    \\ It only shows once something fills all six slots at once, which is
    \\ the player explosion, so it hid until Layer 6b. BUGS.md #10.
    .fail
    jsr wave_read
    cmp #&ff
    bne fail_2
    jmp wm_comp
    .fail_2
    ldx #WAVE_BYTES-1
    .skip
    jsr wave_read
    dex
    bne skip
    sta wave_tmr
    rts
}

\ ******************************************************************
\ *	enemy_manage - move the pool, bound it, and shoot at it
\ ******************************************************************
\ The bullet's own move is player.asm's; this is the rest of the C64's
\ enemy_manage.

.enemy_manage
{
    \\ Movement. Each slot has two commands and rocks between them on its
    \\ own timer: below the rocker value it uses the first, at or above
    \\ it the second, and the timer wraps at the reset value.
    ldx #0
    ldy #0
    .move_loop
    lda enemy_tmrs+ENEMY_FIRST, y
    clc
    adc #1
    sta enemy_tmrs+ENEMY_FIRST, y

    lda enemy_rockers+ENEMY_FIRST, y
    cmp enemy_tmrs+ENEMY_FIRST, y
    bcc second
    lda enemy_spds+2*ENEMY_FIRST, x
    jmp apply
    .second
    lda enemy_spds+2*ENEMY_FIRST+1, x
    .apply
    jsr emove
    jsr emove

    lda enemy_tmrs+ENEMY_FIRST, y
    cmp enemy_resets+ENEMY_FIRST, y
    bcc no_reset
    lda #0
    sta enemy_tmrs+ENEMY_FIRST, y
    .no_reset

    inx
    inx
    iny
    cpy #ENEMY_COUNT
    bne move_loop

    \\ Out of bounds: decommission. This runs from the BULLET's slot up,
    \\ as the C64's does, so it is what kills a bullet that leaves the
    \\ right-hand edge as well.
    ldx #0
    .bounds
    lda sprite_pos+2, x
    cmp #ENEMY_X_KILL
    bcs kill
    lda sprite_pos+3, x
    cmp #ENEMY_Y_LIVE
    bcs bounds_next
    .kill
    lda #0
    sta sprite_pos+2, x
    sta sprite_pos+3, x
    sta enemy_spds+2, x
    sta enemy_spds+3, x
    .bounds_next
    inx
    inx
    cpx #2*(SPR_SLOTS-1)
    bne bounds

    \\ Bullet to enemy. No bullet, no check - the C64 tests its y here
    \\ and so do we.
    lda sprite_pos+2
    sec
    sbc #8
    sta coll_temp
    clc
    adc #&11
    sta coll_temp+1
    lda sprite_pos+3
    bne enemy_colls
    rts
}

.enemy_colls
{
    sec
    sbc #&10
    sta coll_temp+2
    clc
    adc #&22
    sta coll_temp+3

    ldx #0
    ldy #0
    .loop
    \\ Frames below $0b are the explosion: it cannot be shot again.
    lda sprite_dp+ENEMY_FIRST, y
    cmp #&0b
    bcc next

    lda sprite_pos+2*ENEMY_FIRST, x
    cmp coll_temp
    bcc next
    cmp coll_temp+1
    bcs next
    lda sprite_pos+2*ENEMY_FIRST+1, x
    cmp coll_temp+2
    bcc next
    cmp coll_temp+3
    bcs next

    \\ Hit. The bullet goes first, whatever happens to the enemy.
    lda #0
    sta sprite_pos+2
    sta sprite_pos+3
    sta enemy_spds+2
    sta enemy_spds+3

    lda enemy_shields+ENEMY_FIRST, y
    sec
    sbc #1
    sta enemy_shields+ENEMY_FIRST, y
    bne no_kill

    \\ Destroyed: stop it dead, run the explosion animation, 400 points.
    sta enemy_spds+2*ENEMY_FIRST, x
    sta enemy_spds+2*ENEMY_FIRST+1, x
    lda #0
    sta sprite_dp+ENEMY_FIRST, y
    lda #EXPL_LAST
    sta anim_starts+ENEMY_FIRST, y
    lda #EXPL_LAST+1
    sta anim_ends+ENEMY_FIRST, y
    stx rt_store                ; bump_score_* uses X and leaves Y alone
    jsr bump_score_400
    ldx rt_store
    jmp next

    \\ Chipped: flash it and score 40.
    .no_kill
    lda #4
    sta sprite_pls_tmr+ENEMY_FIRST, y
    stx rt_store
    jsr bump_score_10
    jsr bump_score_10
    jsr bump_score_10
    jsr bump_score_10
    ldx rt_store

    .next
    iny
    inx
    inx
    cpx #2*ENEMY_COUNT
    bne loop
    rts
}

\ 400 points, the C64's bump_score_400 without its X save: the callers
\ here keep their own.
.bump_score_400
{
    jsr bump_score_100
    jsr bump_score_100
    jsr bump_score_100
    jmp bump_score_100
}

\ ******************************************************************
\ *	emove - apply one movement command to slot X
\ ******************************************************************
\ Four bit pairs, tested low to high: up, down, left, right. Called
\ twice a tick by the movement loop, so a command of `left_2` ($44)
\ moves two pixels each time it is applied and four in the tick.
\ Vertical moves go two at a time because the C64's y is unhalved.

.emove
{
    lsr a
    bcc down
    dec sprite_pos+2*ENEMY_FIRST+1, x
    dec sprite_pos+2*ENEMY_FIRST+1, x
    .down
    lsr a
    bcc left
    inc sprite_pos+2*ENEMY_FIRST+1, x
    inc sprite_pos+2*ENEMY_FIRST+1, x
    .left
    lsr a
    bcc right
    dec sprite_pos+2*ENEMY_FIRST, x
    .right
    lsr a
    bcc out
    inc sprite_pos+2*ENEMY_FIRST, x
    .out
    rts
}

\ ******************************************************************
\ *	explosion_chk - free the slot when an explosion has finished
\ ******************************************************************
\ multimate parks a finished explosion on its last frame; zeroing the y
\ is what tells wave_manager's search that the slot is free again.

.explosion_chk
{
    ldx #0
    ldy #0
    .loop
    lda sprite_dp+ENEMY_FIRST, x
    cmp #EXPL_LAST
    bne next
    lda #0
    sta sprite_pos+2*ENEMY_FIRST+1, y
    .next
    iny
    iny
    inx
    cpx #ENEMY_COUNT
    bne loop
    rts
}

\ ******************************************************************
\ *	enemy_init - an empty pool and the wave table back at the start
\ ******************************************************************

.enemy_init
{
    ldx #ENEMY_COUNT-1
    lda #0
    .loop
    lda #SPR_DP_BLANK
    sta sprite_dp+ENEMY_FIRST, x
    lda #0
    sta enemy_shields+ENEMY_FIRST, x
    sta enemy_rockers+ENEMY_FIRST, x
    sta enemy_resets+ENEMY_FIRST, x
    sta enemy_tmrs+ENEMY_FIRST, x
    sta anim_starts+ENEMY_FIRST, x
    sta anim_ends+ENEMY_FIRST, x
    dex
    bpl loop

    ldx #2*ENEMY_COUNT-1
    lda #0
    .loop2
    sta sprite_pos+2*ENEMY_FIRST, x
    sta enemy_spds+2*ENEMY_FIRST, x
    dex
    bpl loop2

    sta comp_flag
    jmp wave_read_rst
}
