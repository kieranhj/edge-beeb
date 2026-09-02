\ ******************************************************************
\ *	keyboard.asm
\ *	Keys read straight from the System VIA keyboard matrix (Paradroid's
\ *	keydown: 69 cycles against OSBYTE's 243, and it works with the MOS
\ *	interrupt gone). X = internal key number; returns N set if pressed.
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
    dec y_pos
    dec y_pos
    .not_up

    ldx #KEY_DOWN
    jsr keydown
    bpl not_down
    inc y_pos
    inc y_pos
    .not_down

    ldx #KEY_LEFT
    jsr keydown
    bpl not_left
    dec x_pos
    .not_left

    ldx #KEY_RIGHT
    jsr keydown
    bpl not_right
    inc x_pos
    .not_right

    rts
}
