\ ******************************************************************
\ *	rupture.asm
\ *	Two CRTC cycles per frame, the IRQ that drives them, and the
\ *	double-buffer handover. Lifted from Paradroid's rupture.asm and
\ *	cut down: no vertical scroll, so no R5 adjust and no R8 blanking.
\ *
\ *	Frame (39 rows = 312 scanlines, the MODE 2 shape):
\ *	  cycle A  rows  0-4   panel, PANEL_ROWS displayed, start PANEL_ADDR
\ *	  cycle B  rows  5-38  play, PLAY_ROWS displayed, start = scroll
\ *	           address; VSync at its row PLAY_R7 = absolute row 34
\ *
\ *	WHEN EACH REGISTER MUST BE WRITTEN (measured in Paradroid):
\ *	  R4       inside its own cycle, before C4 reaches the new value
\ *	  R6, R12/R13  inside the PREVIOUS cycle - latched at cycle start
\ *	  R7       constant here: PLAY_R7 never falls inside the 5-row A
\ *
\ *	  VSync IRQ (B row 29+latency): R6 and R12/13 for A; flip the
\ *	           shadow banks if the main loop has a frame ready and
\ *	           FRAME_LOCK fields have passed; restart T1
\ *	  fire 1   (A row 2): R4 for A, R6 and R12/13 for B
\ *	  fire 2   (B row 2): R4 for B
\ ******************************************************************

\ Frame handover. The main loop draws into the hidden bank, parks the
\ scroll address for that bank, sets frame_ready and spins until the
\ VSync handler has flipped the banks and taken the address. The IRQ
\ only flips when FRAME_LOCK fields have passed since the last flip, so
\ the scroll never runs faster than 25 Hz; a slow frame costs whole
\ fields and nothing tears, because the flip and the address change
\ together in vertical blanking.

.rupt_vsync
{
    inc field_count

    lda frame_ready
    beq no_flip
    lda field_count
    sec
    sbc flip_field
    cmp #FRAME_LOCK
    bcc no_flip

    lda field_count
    sta flip_field
    lda &fe34
    eor #5                      ; D (display) and X (CPU) shadow bits together
    sta &fe34
    lda crtc_park
    sta crtc_live
    lda crtc_park+1
    sta crtc_live+1
    lda #0
    sta frame_ready
    .no_flip

    \\ For cycle A, which starts 5 rows from now
    CRTC 6, PANEL_ROWS
    CRTC 12, HI(PANEL_ADDR/8)
    CRTC 13, LO(PANEL_ADDR/8)

    \\ Restart T1 (writing T1C-H loads the counter from the latch and
    \\ starts it), then re-latch the fire 1 -> fire 2 interval, which the
    \\ counter picks up when it reloads at fire 1.
    lda #LO(T1_I1) : sta SYS_VIA_T1LL
    lda #HI(T1_I1) : sta SYS_VIA_T1CH
    lda #LO(T1_I2) : sta SYS_VIA_T1LL
    lda #HI(T1_I2) : sta SYS_VIA_T1LH

    lda #0
    sta rupt_state

    \ The music, LAST: after T1 has been restarted, so the decode runs
    \ inside the 3,326 us the counter is going to spend getting to fire 1
    \ and cannot push the rupture about. The VGI player is bounded at
    \ about 1,340 us a field, so it has three times the room it needs.
    \
    \ This call has to be in main RAM: the IRQ fires with whatever bank
    \ the interrupted code had paged, and the sprite engine is paging 5,
    \ 6 and 7 as it draws. HAZEL is at &C000-&DFFF, clear of the window
    \ altogether, so the ACCCON bit is the whole of the ceremony.
    lda &fe34
    pha
    ora #HAZEL_BIT
    sta &fe34
    jsr vgm_update
    pla
    sta &fe34
    rts
}

.rupt_timer
{
    lda rupt_state
    bne not_fire1

    \\ ---- fire 1: A row 2 ----
    CRTC 4, PANEL_R4            ; A's own; C4 is at 2
    CRTC 6, PLAY_ROWS           ; for B, which starts in 3 rows
    lda #12 : sta CRTC_ADDR : lda crtc_live+1 : sta CRTC_DATA
    lda #13 : sta CRTC_ADDR : lda crtc_live   : sta CRTC_DATA
    lda #LO(T1_I3) : sta SYS_VIA_T1LL   ; fire 2 -> (nothing) : longer than
    lda #HI(T1_I3) : sta SYS_VIA_T1LH   ; the time to VSync, which restarts T1
    inc rupt_state
    rts

    .not_fire1
    cmp #1
    bne done

    \\ ---- fire 2: B row 2 ----
    CRTC 4, PLAY_R4
    inc rupt_state
    .done
    rts
}

\ ******************************************************************
\ *	IRQ1V owner. The MOS saves A in &FC before dispatching and does
\ *	not save X or Y. Nothing is passed on to the MOS: its 100 Hz tick
\ *	stops (keyboard is read direct, no OS sound) and the filing
\ *	system is only used before install_irq.
\ ******************************************************************

.irq_handler
{
    txa : pha
    tya : pha

    lda SYS_VIA_IFR
    and #&40                    ; T1
    beq not_t1
    lda SYS_VIA_T1CL            ; acknowledge
    jsr rupt_timer
    jmp done
    .not_t1

    lda SYS_VIA_IFR
    and #&02                    ; CA1 = VSync
    beq done
    lda #&02
    sta SYS_VIA_IFR             ; acknowledge
    jsr rupt_vsync

    .done
    pla : tay
    pla : tax
    lda &fc
    rti
}

.install_irq
{
    sei
    lda #&7f : sta SYS_VIA_IER  ; silence both VIAs: anything we do not
    lda #&7f : sta USR_VIA_IER  ; service would hold IRQ asserted forever

    lda #LO(irq_handler) : sta IRQ1V
    lda #HI(irq_handler) : sta IRQ1V+1

    lda SYS_VIA_ACR             ; T1 continuous, no PB7 output
    and #&3f
    ora #&40
    sta SYS_VIA_ACR

    lda #&7f : sta SYS_VIA_IFR  ; clear anything pending
    lda #&c2 : sta SYS_VIA_IER  ; enable CA1 (VSync) + T1
    cli
    rts
}
