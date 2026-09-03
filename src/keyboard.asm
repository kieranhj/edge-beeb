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

\ ******************************************************************
\ *	read_joystick - the five keys as a C64 joystick byte
\ ******************************************************************
\ Bit 0 up, 1 down, 2 left, 3 right, 4 fire, and a CLEAR bit is pressed,
\ which is the C64's $dc00 exactly - so player_manage's LSR/BCS chain is
\ the original's, unaltered. keydown clobbers X and Y, hence joy_idx.

.read_joystick
{
    lda #&ff
    sta joy
    lda #4
    sta joy_idx
    .loop
    ldy joy_idx
    ldx joy_keys, y
    jsr keydown
    bpl not_pressed
    ldy joy_idx
    lda joy
    and joy_mask, y
    sta joy
    .not_pressed
    dec joy_idx
    bpl loop
    rts
}

.joy_keys EQUB KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_FIRE
.joy_mask EQUB &fe, &fd, &fb, &f7, &ef
