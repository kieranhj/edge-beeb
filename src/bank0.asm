\ ******************************************************************
\ *	bank0.asm
\ *	Sideways RAM bank 0 (slot SWRAM_DATA): the converted charset,
\ *	the C64 tiles, both maps, col_decode and the attack wave table. From
\ *	tools/export_tiles.py and tools/export_waves.py;
\ *	regenerate with the tool rather than editing src/data.
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank0_start

\\ Characters as four MODE 2 column planes: plane p at char_data + p*2048,
\\ char c row r at + c*8 + r, colour in the right-pixel bits (6,4,2,0).
\\ 256 chars x 8 rows x 4 planes = 8192 bytes.

.char_data
IF GFX_CPC
INCBIN "src/data/chars-cpc.bin"
ELSE
INCBIN "src/data/chars.bin"
ENDIF
ASSERT P% = char_data + 8192
PRINT "CHARACTER data =", ~char_data

\\ Each tile is 4x4 characters, row-major; 211 tiles x 16 bytes = 3376.

PAGE_ALIGN
.tile_data
INCBIN "src/data/tiles.bin"
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high, column-major, 302 columns (tiles.map + tiles2.map) = 1510 bytes.

PAGE_ALIGN
.map_data
INCBIN "src/data/map.bin"
.map_end
PRINT "MAP data =", ~map_data

\\ The C64 col_decode table: low 3 bits per-char colour (already applied to
\\ the planes), bit 4 = fatal to the player (Layer 4 reads this).

PAGE_ALIGN
.col_decode
INCBIN "src/data/col_decode.bin"
PRINT "COL_DECODE =", ~col_decode

\ The attack wave table: 9 bytes a wave, read a byte at a time by
\ wave_read, terminated by an $ff in the x position. anim_decode is the
\ 19 start/end frame pairs a wave's object byte picks its animation from.
\ Both from tools/export_waves.py.

PAGE_ALIGN
.wave_data
INCBIN "src/data/waves.bin"
.wave_end
PRINT "WAVE data =", ~wave_data

.anim_decode
INCBIN "src/data/anim_decode.bin"
PRINT "ANIM_DECODE =", ~anim_decode

\ coll_map row bases. The map is 800 bytes and crosses pages, so the read
\ is (ptr),Y with the column in Y. They live up here rather than in main
\ RAM because their only reader is coll_read, which runs from game_tick
\ with bank 0 resting - and main RAM below &2000 has none to spare.
.coll_row_lo
FOR n,0,COLL_ROWS-1,1
    EQUB LO(coll_map + n*COLL_COLS)
NEXT
.coll_row_hi
FOR n,0,COLL_ROWS-1,1
    EQUB HI(coll_map + n*COLL_COLS)
NEXT

\ The frame meter lives up here, not in main RAM: it is a DEV-only
\ facility and main RAM below &2000 has no room for one. Bank 0 is the
\ resting SWRAM state, paged in whenever the main loop is running its
\ own code, so a plain JSR reaches it - the only routines that page it
\ out are spr_restore_all and spr_draw_all, and no mark is taken inside
\ either. See src/timing.asm.
INCLUDE "src/timing.asm"


\ ******************************************************************
\ *	Boot-time display setup, up here rather than in main RAM.
\ ******************************************************************
\ setup_display, clear_play and panel_init run once, from main, after
\ the banks are loaded and SWRAM_DATA is paged in, and nothing else
\ calls them. The IRQ handler and install_irq stay in main RAM, where
\ they must be: the handler fires with whatever bank the loop was using.

\ ******************************************************************
\ *	Display setup, after the mode change and the bank loads, before
\ *	install_irq. Starts the CRTC in cycle B's shape so the first VSync
\ *	arrives with C4 where the steady state expects it.
\ ******************************************************************

.setup_display
{
    \\ 16K hardware wrap: addressable latch lines 4 and 5 low
    lda #&0f : sta &fe42        ; DDRB: latch bits are outputs
    lda #4   : sta &fe40        ; C0 = 0
    lda #5   : sta &fe40        ; C1 = 0  -> 16K, &4000-&7FFF

    CRTC 4, PLAY_R4
    CRTC 5, 0
    CRTC 6, PLAY_ROWS
    CRTC 7, PLAY_R7
    CRTC 10, &20                ; cursor off
    CRTC 12, HI(screen_start/8)
    CRTC 13, LO(screen_start/8)

    \\ Palette: logical n -> physical n for 0-7; 8-15 -> 0-7 again, not
    \\ flashing, so logical 8 is a second black that sprites may use
    \\ (transparent is 0). &FE21 takes (logical << 4) OR (physical EOR 7).
    ldx #15
    .pal_loop
    txa
    and #7
    eor #7
    sta pal_tmp
    txa
    asl a : asl a : asl a : asl a
    ora pal_tmp
    sta VIDEO_ULA_PAL
    dex
    bpl pal_loop

    \\ The panel is in the shadow-switched region, so draw it into both
    \\ banks: X = 0 (main) then X = 1 (shadow). Leaves X = 1, which is the
    \\ boot state the caller sets anyway.
    lda &fe34
    and #255-4
    sta &fe34
    jsr clear_play
    jsr panel_init
    lda &fe34
    ora #4
    sta &fe34
    jsr clear_play
    jsr panel_init

    \\ Everything is clear: display on. R8 = 0 also means no interlace,
    \\ which keeps VSync at a fixed phase for the rupture timers.
    CRTC 8, 0

    lda #0
    sta field_count
    sta flip_field
    sta frame_ready
    sta rupt_state
    rts

    .pal_tmp EQUB 0
}

\\ Clear the 16K play buffer in whichever bank the X bit selects. The MOS
\\ only clears the main bank at the mode change; the shadow bank would show
\\ whatever it held until the scroll had covered it.
.clear_play
{
    lda #LO(screen_start) : sta write_ptr
    lda #HI(screen_start) : sta write_ptr+1
    ldx #HI(screen_size)
    lda #0
    tay
    .page_loop
    sta (write_ptr), y
    iny
    bne page_loop
    inc write_ptr+1
    dex
    bne page_loop
    rts
}


\\ The score, the high score and the lives count are initialised data on the
\\ C64 - score and lives zero, high score 012345, all sitting in the file -
\\ and nothing there ever resets the high score. Ours are in the &0800
\\ block, which is not in the image, so they are set once at boot. It
\\ matters because the titles page shows the panel before game_init has run.
.score_boot
{
    ldx #SCORE_DIGITS-1
    .loop
    txa
    sta hi_score, x
    lda #0
    sta score, x
    dex
    bpl loop
    sta lives                   ; A is still 0
    rts
}

\ The HUD, once a game frame from the main loop. Here so that the loop
\ pays three bytes of main RAM for it rather than seven.
.status_call
{
    ldx #LO(status_decode)
    ldy #HI(status_decode)
    jmp bank3_call
}


\ ******************************************************************
\ *	game_init - the C64's main_init: a whole new game
\ ******************************************************************
\ *	Everything a game needs set before its first frame, run once at
\ *	boot and again when a game-over sequence has finished. The C64's
\ *	main_init blanks the screen ($d011), resets the map, the wave
\ *	table, the sprites and the score, gives the player three lives and
\ *	falls into main_dropin. The fast winder at the end of its
\ *	map_read_rst is our scroll_prewind.
\ *
\ *	SAFE TO CALL WITH THE IRQ RUNNING, but only from the top of the
\ *	main loop: scroll_prewind flips &FE34 itself, and the VSync handler
\ *	only does that when frame_ready is set, which it is not there.
\ *
\ *	In bank 0 since Layer 7, because main RAM had to find room for the
\ *	HAZEL loader and the IRQ's music call. Both its callers - boot and
\ *	the top of master_loop - run with SWRAM_DATA paged in, which is the
\ *	resting state, and everything it calls is in main RAM or bank 0.
\ ******************************************************************

.game_init
{
    \\ Set scroll addresses

    lda #LO(screen_start)
    sta corner_addr
    lda #HI(screen_start)
    sta corner_addr+1

    lda #LO(screen_start/8)
    sta crtc_addr
    lda #HI(screen_start/8)
    sta crtc_addr+1

    \\ spr_init first: on a restart the save areas still hold the last
    \\ game's backgrounds, and spr_restore_all would put them back over
    \\ the new screen.

    jsr spr_init
    jsr coll_init
    jsr score_reset
    jsr sprite_reset            \\ enemy_init and wave_read_rst with it

    lda #GAME_LIVES
    sta lives
    lda #0
    sta to_titles
    jsr player_dropin

    ldx #0
    lda #0
    .col_loop
    sta column_buffer, X
    inx
    cpx #column_size
    bcc col_loop

    \\ Initialise the tile readers. map_read_rst ends in tile_update.

    ldx #0
    stx tile_cnt
    stx tile_total
    stx char_col
    jsr map_read_rst

    \\ Fill the play area before anything is shown - see scroll_prewind.
    \\ At boot the display is still blanked from setup_display's R8; on a
    \\ restart this is what hides the wind, as the C64's $d011 does.

    CRTC 8, &30
    jsr scroll_prewind
    CRTC 8, 0

    lda crtc_addr
    sta crtc_live
    lda crtc_addr+1
    sta crtc_live+1
    rts
}


\ ******************************************************************
\ *	pause_check - P holds the game, ESCAPE from inside it gives up
\ ******************************************************************
\ *	The C64 tests its pause key at the top of main_loop and, once in,
\ *	waits on fire to come back out, debouncing it so the release does
\ *	not fire the bullet on the way. Q aborts from in there; ours is
\ *	ESCAPE (decision 32), and the abort is the C64's main_abort
\ *	exactly: one life left and then lose it, so the game-over sequence
\ *	runs as it always does.
\ *
\ *	In bank 0 because main RAM ran out, and it may be: the main loop
\ *	calls it with SWRAM_DATA paged in, which is the resting state.
\ ******************************************************************

.pause_check
{
    ldx #KEY_PAUSE
    jsr keydown
    bpl out

    \\ Wait for P to be let go, or holding it would toggle every frame
    .p_release
    jsr field_wait
    ldx #KEY_PAUSE
    jsr keydown
    bmi p_release

    \\ The tune stops with the game (KC, decision 43) - the C64 leaves it
    \\ playing, which is the deviation. The VSync handler takes its MUTED
    \\ path while this is set, so the player is not run at all and the tune
    \\ stands where it is and carries on from there: Q's mechanism exactly,
    \\ and for the same reason - silencing the chip after running the player
    \\ crackles. It also stops the handler reading Q while we are in here,
    \\ there being nothing left for it to mute.
    lda #&ff
    sta music_pause

    .paused
    jsr field_wait

    ldx #KEY_ABORT
    jsr keydown
    bmi abort

    \\ P comes back out as well as fire (KC). The C64 has only its fire
    \\ button here, having no second key to spare; P is the one that got
    \\ us in, so it is the one a player reaches for.
    ldx #KEY_PAUSE
    jsr keydown
    bmi p_out

    ldx #KEY_FIRE
    jsr keydown
    bpl paused

    \\ Fire is down: wait for it to come up before playing on
    .f_release
    jsr field_wait
    ldx #KEY_FIRE
    jsr keydown
    bmi f_release
    jmp resume

    \\ P is down: wait for it to come up too, or the main loop's own test
    \\ at the top of the next frame would find it still held and pause
    \\ again on the spot.
    .p_out
    jsr field_wait
    ldx #KEY_PAUSE
    jsr keydown
    bmi p_out

    .resume
    lda #0
    sta music_pause
    .out
    rts

    \\ ESCAPE: the tune has to come back before the game-over sequence,
    \\ which is a long way from here and never returns to this routine.
    .abort
    lda #0
    sta music_pause
    lda #1
    sta lives
    jmp life_lost
}

\ ******************************************************************
\ *	comp_mess - the game is won: the bonus, then the finale
\ ******************************************************************
\ *	The C64's comp_mess, whole and in its order: every sprite hidden,
\ *	the "mega hero" message drawn a cell a field over the frozen play
\ *	area, 5,000 points a remaining life counted on with the original's
\ *	own 50-field pause between them, and then the finale.
\ *
\ *	The message is up in bank 1 (Layer 9c) - the 240-field loop as
\ *	well as the plotting, because this bank has twenty-five bytes
\ *	left. It is not a font and never needed one; the commentary is
\ *	there with the code.
\ *
\ *	It BLOCKS, on field_wait, exactly as the original blocks on
\ *	sync_wait. Nothing is moving and nothing is being drawn, so there
\ *	is no frame to hand over.
\ *
\ *	Up here in bank 0 because main RAM has no room for it, and bank 0
\ *	is the resting state the sprite engine puts back - so unlike bank
\ *	3, code here may call into main RAM and be returned to.
\ ******************************************************************

.comp_mess
{
    ldx #0
    txa
    .hide
    sta sprite_pos, x
    inx
    cpx #2*SPR_SLOTS
    bne hide

    \ The "mega hero" message, a cell a field, over the frozen play
    \ area. All of it - the 240-field loop included - is in bank 1,
    \ because there are twenty-five bytes left in this one.
    lda #SWRAM_SPRITES0
    ldx #LO(mega_mess)
    ldy #HI(mega_mess)
    jsr bank_call

    ldy lives
    beq no_bonus                \\ cannot happen in play; a loop of 256 if it did
    .bonus_loop
    jsr bump_score_1000
    jsr bump_score_1000
    jsr bump_score_1000
    jsr bump_score_1000
    jsr bump_score_1000
    ldx #&32
    .bonus_wait
    jsr field_wait
    dex
    bne bonus_wait
    dey
    bne bonus_loop
    .no_bonus

    \\ Into the finale. comp_flag stops being the completion flag here and
    \\ becomes the index the bangs are placed from, which is what the C64
    \\ does with it too.
    lda #0
    sta comp_flag
    sta finale_slot
    lda #MODE_FINALE
    sta game_mode
    lda #FINALE_GAP
    sta finale_tmr
    rts
}

\ ******************************************************************
\ *	finale_tick - bangs until fire, the C64's cm_splode_wait
\ ******************************************************************
\ *	One slot every FINALE_GAP ticks is turned into an explosion at a
\ *	position read out of memory, round-robin through all eight. Then
\ *	the animation, and fire ends it.
\ *
\ *	THE POSITIONS ARE READ OUT OF OUR OWN CODE (decision 33), because
\ *	that is what the original does: it loads at $0812, so the $0900 and
\ *	$0a00 it reads here are its own machine code, used purely as a
\ *	source of scattered numbers. Two pages of ours do the same job.
\ *	The map was tried first and is useless for it - the level opens on
\ *	empty tiles, so every bang landed at x = 0 - and the character set
\ *	is worse, being pixel patterns with four distinct values in a page.
\ *	The arithmetic around the two reads is the original's, unaltered.

.finale_tick
{
    dec finale_tmr
    bpl no_bang

    ldx finale_slot
    lda finale_slot
    asl a
    tay                         \\ Y indexes sprite_pos by twos

    ldx comp_flag
    lda code_start+&200, x
    sta sprite_pos, y
    lda code_start+&300, x
    and #&7f
    clc
    adc #&5e                    \\ &5e-&dd: down the play area, as the C64 has it
    sta sprite_pos+1, y
    lda #0
    sta enemy_spds, y
    sta enemy_spds+1, y
    inc comp_flag

    ldx finale_slot
    lda #0
    sta sprite_dp, x
    lda #EXPL_LAST
    sta anim_starts, x
    lda #EXPL_LAST+1
    sta anim_ends, x

    inx
    cpx #SPR_SLOTS
    bne slot_ok
    ldx #0
    .slot_ok
    stx finale_slot
    lda #FINALE_GAP
    sta finale_tmr
    .no_bang

    jsr anim_step

    ldx #KEY_FIRE
    jsr keydown
    bpl out
    inc to_titles
    .out
    rts
}

\ ******************************************************************
\ *	title_page - the C64's titles page
\ ******************************************************************
\ *	Four CRTC cycles: the panel, the top zoom band, the credits and
\ *	the bottom zoom band, the last two displayed out of the SHADOW
\ *	bank and the first two out of MAIN, with the display bit switched
\ *	inside the frame. src/bank1.asm has the scroller and the rupture;
\ *	all this does is set the page up, run a field at a time, and put
\ *	the game's shape back on the way out.
\ *
\ *	Nothing is handed over here - field_wait leaves frame_ready alone
\ *	and the VSync handler never flips, because both banks are on
\ *	screen inside the same frame and there is no hidden one to draw.
\ *
\ *	Returns when fire is pressed, which is where the C64's ttl_loop
\ *	goes to main_init.
\ *
\ *	Up here in bank 0 because it is a run-once routine, like
\ *	setup_display, and because the credits it draws live one call away.
\ ******************************************************************

.title_page
{
    CRTC 8, &30                 ; blanked while the shape changes under it
    CRTC 10, &20                ; R8 does not hide the cursor; R10 does

    lda &fe34
    sta ttl_acccon

    \\ ---- the still parts ------------------------------------------
    \\
    \\ clear_play covers &4000-&7FFF, which is the credits block and both
    \\ zoom rings; the panel is below it and stays. The credits go into
    \\ SHADOW only, because that is the bank cycle C displays.
    lda &fe34 : and #&ff - 4 : sta &fe34        ; CPU sees MAIN
    jsr clear_play
    jsr status_call
    lda &fe34 : ora #4 : sta &fe34              ; CPU sees SHADOW
    jsr clear_play
    jsr status_call
    jsr ttl_cred_start          ; the crossfade's clock, and which set is
    ldx #LO(title_text)         ; up - BEFORE the draw, which reads it
    ldy #HI(title_text)
    jsr bank3_call

    \\ ---- the display ----------------------------------------------
    \\
    \\ 8K wrap: latch line 4 high, line 5 low, so &6000-&7FFF is a ring
    \\ of 1,024 byte columns in each bank - one per bank, and only one,
    \\ which is why the two bands are split across them. Measured in
    \\ jsbeeb 2026-09-04; the four sizes are 20K, 16K, 10K and 8K.
    lda #12 : sta &fe40
    lda #5  : sta &fe40
    CRTC 7, TTL_R7

    lda #SWRAM_SPRITES0
    ldx #LO(ttl_init)
    ldy #HI(ttl_init)
    jsr bank_call

    lda #&ff
    sta ttl_active
    jsr field_wait              ; two fields for the new shape to settle
    jsr field_wait
    CRTC 8, 0

    \\ Fire starts a game, as it does on the C64. No debounce: the
    \\ original has none either, and sprite_reset clears fire_latch.
    .wait
    jsr field_wait
    lda #SWRAM_SPRITES0
    ldx #LO(ttl_frame)
    ldy #HI(ttl_frame)
    jsr bank_call
    jsr ttl_cred_tick
    ldx #KEY_FIRE
    jsr keydown
    bpl wait

    \\ ---- and back to the game's own shape --------------------------
    CRTC 8, &30
    jsr ttl_cred_end            ; logicals 8-15 back: logical 8 is the
                                ; second black the sprites draw with
    lda #0
    sta ttl_active
    lda #4  : sta &fe40         ; 16K wrap again: the play buffers' own
    lda #5  : sta &fe40
    CRTC 7, PLAY_R7
    CRTC 4, PLAY_R4
    CRTC 6, PLAY_ROWS
    lda ttl_acccon
    sta &fe34
    rts
}

.ttl_acccon EQUB 0              ; &FE34 as the titles found it

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
