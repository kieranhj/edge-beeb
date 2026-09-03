\ ******************************************************************
\ *	keyboard.asm
\ *	Keys read straight from the System VIA keyboard matrix (Paradroid's
\ *	keydown: 69 cycles against OSBYTE's 243, and it works with the MOS
\ *	interrupt gone). X = internal key number; returns N set if pressed.
\ *
\ *	read_keyboard moves the player - sprite slot 0 - in the C64's own
\ *	units: x is halved (one step is one fat pixel), y is not. Layer 4
\ *	replaces it with the original's acceleration and bounds.
\ ******************************************************************

.keydown
{
    txa
    ldx #KBD_LATCH_OFF
    ldy #KBD_LATCH_ON
    php
    sei
    stx KBD_PORTB               ; stop the free-running scan...
    ldx #KBD_DDRA_SCAN
    stx KBD_DDRA
    sta KBD_ORA                 ; ask about this key
    lda KBD_ORA                 ; PA7 is the answer
    sty KBD_PORTB               ; ...and hand it back
    plp
    and #&80                    ; N = pressed
    rts
}

.read_keyboard
{
    ldx #KEY_UP
    jsr keydown
    bpl not_up
    dec sprite_pos+1
    dec sprite_pos+1
    .not_up

    ldx #KEY_DOWN
    jsr keydown
    bpl not_down
    inc sprite_pos+1
    inc sprite_pos+1
    .not_down

    ldx #KEY_LEFT
    jsr keydown
    bpl not_left
    dec sprite_pos
    .not_left

    ldx #KEY_RIGHT
    jsr keydown
    bpl not_right
    inc sprite_pos
    .not_right

    rts
}
