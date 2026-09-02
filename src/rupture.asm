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

\\ Clear the panel in whichever bank the X bit selects, then the DEV
\\ placeholder. Anything that draws on the panel must do it for both banks.
.panel_init
{
    lda #LO(PANEL_ADDR) : sta write_ptr
    lda #HI(PANEL_ADDR) : sta write_ptr+1
    ldx #HI(PANEL_BYTES)
    lda #0
    tay
    .clear_page
    sta (write_ptr), y
    iny
    bne clear_page
    inc write_ptr+1
    dex
    bne clear_page
    .clear_tail
    sta (write_ptr), y
    iny
    cpy #LO(PANEL_BYTES)
    bne clear_tail

IF DEV
    jmp fill_panel_test
ELSE
    rts
ENDIF
}

\ ******************************************************************
\ *	TEMPORARY, DEV only: a placeholder in the panel so the rupture can
\ *	be seen. White line on the panel's top and bottom scanlines, and
\ *	sixteen 5-column bars of logical colours 0-15 across rows 1-3
\ *	(8-15 must look like 0-7 and must not flash). Layer 6 replaces it.
\ ******************************************************************

IF DEV
.fill_panel_test
{
    \\ Top scanline of row 0 and bottom scanline of row 4
    lda #LO(PANEL_ADDR) : sta write_ptr
    lda #HI(PANEL_ADDR) : sta write_ptr+1
    lda #LO(PANEL_ADDR + 4*row_stride) : sta read_ptr
    lda #HI(PANEL_ADDR + 4*row_stride) : sta read_ptr+1
    ldx #80
    .edge_loop
    ldy #0
    lda #&ff
    sta (write_ptr), y
    ldy #7
    sta (read_ptr), y
    clc
    lda write_ptr : adc #8 : sta write_ptr
    bcc no_c1
    inc write_ptr+1
    .no_c1
    clc
    lda read_ptr : adc #8 : sta read_ptr
    bcc no_c2
    inc read_ptr+1
    .no_c2
    dex
    bne edge_loop

    \\ Colour bars: rows 1-3, column c shows logical colour c DIV 5
    lda #LO(PANEL_ADDR + row_stride) : sta write_ptr
    lda #HI(PANEL_ADDR + row_stride) : sta write_ptr+1
    lda #3 : sta y_count            ; rows
    .row_loop
    lda #0 : sta sprite_idx         ; bar number
    lda #5 : sta x_count            ; columns left in this bar
    ldx #80
    .col_loop
    ldy sprite_idx
    lda bar_bytes, y
    ldy #7
    .byte_loop
    sta (write_ptr), y
    dey
    bpl byte_loop
    clc
    lda write_ptr : adc #8 : sta write_ptr
    bcc no_c3
    inc write_ptr+1
    .no_c3
    dec x_count
    bne same_bar
    lda #5 : sta x_count
    inc sprite_idx
    .same_bar
    dex
    bne col_loop
    dec y_count
    bne row_loop
    rts

    \\ Solid MODE 2 byte for logical colour n: bit i of n -> bits 2i+1 and 2i
    .bar_bytes
    FOR n, 0, 15, 1
        EQUB ((n AND 1) * 3) OR ((n AND 2) * 6) OR ((n AND 4) * 12) OR ((n AND 8) * 24)
    NEXT
}
ENDIF
