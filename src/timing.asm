\ ******************************************************************
\ *	timing.asm - the frame meter (DEBUG_TIMING only)
\ *
\ *	BUGS.md #9 says the game drops below 25 Hz while shooting and the
\ *	budget table's 63,667 cycles is known to be optimistic. This
\ *	measures the frame instead of arguing about it.
\ *
\ *	Two independent readings, because they answer different questions:
\ *
\ *	  tim_over    how many frames MISSED their flip. field_count minus
\ *	              flip_field at the moment the loop hands the frame
\ *	              over is the number of fields the work took; FRAME_LOCK
\ *	              or more means the VSync that should have flipped has
\ *	              already gone by and the frame rate has dropped. This
\ *	              is the definitive answer and costs nothing.
\ *	  tim_max_*   where the time actually goes, per phase, worst case.
\ *
\ *	The clock is the USER VIA's T2, which nothing else in the game
\ *	touches (install_irq disables that VIA's interrupts outright). It
\ *	is loaded with &FFFF at the top of the loop and counts DOWN at
\ *	1 MHz, so elapsed = &FFFF - T2 and the unit is microseconds.
\ *	A 25 Hz frame is 39,936 us = 79,872 2 MHz cycles: to compare a
\ *	figure here against the cycle counts in docs/, DOUBLE IT.
\ *
\ *	TWO THINGS THE READER HAS TO KNOW, both learned the hard way
\ *	(docs/performance.md):
\ *
\ *	  * T2's two bytes are read separately and the counter can roll
\ *	    between them. tim_mark throws away any sample that comes out
\ *	    going backwards; without that one bad read poisons a slot.
\ *	  * A frame longer than 65.5 ms wraps the counter outright and
\ *	    every phase in it is nonsense. Deaths and mode changes do it -
\ *	    one measured frame took 138 fields. tim_fields is the tell, and
\ *	    the cure is to zero the slots and sample uninterrupted play.
\ *
\ *	A phase maximum also includes any INTERRUPT that happened to land
\ *	inside it, and there are six a frame. On the short phases that is
\ *	most of the figure, so read their maxima as an upper bound and take
\ *	the typical cost from a single-frame sample instead.
\ ******************************************************************

\ The phases, in the order the maximum slots are declared in main.asm.
\ A mark is taken with TIMMARK <one of these>.
TIM_RESTORE = 0
TIM_SCROLL  = 1
TIM_DRAW    = 2
TIM_LOGIC   = 3
TIM_TOTAL   = 4

IF DEBUG_TIMING

\ Writing T2C-H loads the counter from the latch and starts it. ACR bit 5
\ clear is the one-shot timed mode, which is what we want: it counts down
\ past zero and keeps going, so a single load times the whole frame.
USR_VIA_T2CL = &FE68
USR_VIA_T2CH = &FE69
USR_VIA_ACR  = &FE6B

.tim_init
{
    lda USR_VIA_ACR
    and #255-&20                ; T2 one-shot, not pulse counting
    sta USR_VIA_ACR

    ldx #tim_slots_end - tim_slots_start - 1
    lda #0
    .wipe
    sta tim_slots_start, x
    dex
    bpl wipe
    rts
}

\ Start of frame: reload T2 and forget the previous frame's marks.
.tim_start
{
    lda #&ff
    sta USR_VIA_T2CL
    sta USR_VIA_T2CH
    lda #0
    sta tim_prev
    sta tim_prev+1
    rts
}

\ Point tim_ptr at the TIM_ maximum slot in A.
.tim_setptr
{
    asl a
    clc
    adc #LO(tim_slots_start)
    sta tim_ptr
    lda #HI(tim_slots_start)
    adc #0
    sta tim_ptr+1
    rts
}

\ A = the TIM_ phase this mark closes. Times from the last mark (or from
\ tim_start) to now and keeps it if it is the worst seen so far.
\ tim_val is left holding the time since tim_start, which is what
\ tim_handover wants for the total.
.tim_mark
{
    jsr tim_setptr

    \\ elapsed since tim_start = &FFFF - T2
    sec
    lda #&ff : sbc USR_VIA_T2CL : sta tim_val
    lda #&ff : sbc USR_VIA_T2CH : sta tim_val+1

    \\ this phase = elapsed - the elapsed at the previous mark
    sec
    lda tim_val   : sbc tim_prev   : sta tim_phase
    lda tim_val+1 : sbc tim_prev+1 : sta tim_phase+1

    php                          ; carry: clear = borrow = the clock ran
    lda tim_val   : sta tim_prev ; backwards between the two T2 byte reads
    lda tim_val+1 : sta tim_prev+1
    plp
    bcs tim_keep

    \ THROW THE SAMPLE AWAY. T2CL and T2CH are read one after the other
    \ and the counter can roll between them, so elapsed can come out 256us
    \ SMALLER than the mark before it. tim_keep compares unsigned, so a
    \ single bad read is stored as a ~65,000us maximum and poisons that
    \ slot for the rest of the run - which it did, on three readings out
    \ of three, before this was here. A dropped sample costs nothing: the
    \ phase is measured again next frame.
    rts
}

\ Store tim_phase in the 2-byte slot at tim_ptr if it is bigger.
.tim_keep
{
    ldy #1
    lda tim_phase+1
    cmp (tim_ptr), y
    bcc no_new
    bne is_new
    dey
    lda tim_phase
    cmp (tim_ptr), y
    bcc no_new
    .is_new
    ldy #0
    lda tim_phase   : sta (tim_ptr), y
    iny
    lda tim_phase+1 : sta (tim_ptr), y
    .no_new
    rts
}

\ Called with the frame's work finished, inside the loop's SEI, before
\ frame_ready goes up. tim_val is the whole frame's work, left there by
\ the last mark; field_count - flip_field is what the flip made of it.
.tim_handover
{
    \ The two clock-free readings first. Neither can lie: they count
    \ fields, and A still holds the count all the way down.
    lda field_count
    sec
    sbc flip_field
    cmp tim_fields
    bcc not_worst
    sta tim_fields
    .not_worst
    cmp #FRAME_LOCK
    bcc timed
    inc tim_over
    bne timed
    dec tim_over                ; saturate rather than wrap to nothing
    .timed

    \ Four fields is 80 ms and T2 wraps at 65.5, so tim_val is a random
    \ number and keeping it would pin tim_max_total near 65,535 for the
    \ rest of the run. A death or a mode change does this - one frame was
    \ measured at 234 fields. Two and three fields are honest overruns
    \ and still fit the counter, so they are kept.
    cmp #4
    bcs out
    lda tim_val   : sta tim_phase
    lda tim_val+1 : sta tim_phase+1
    lda #TIM_TOTAL
    jsr tim_setptr
    jmp tim_keep
    .out
    rts
}

ENDIF
