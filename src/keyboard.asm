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
\
\ joy_keys IS IN ZERO PAGE (Layer 9h, decision 71) - it used to be the EQUB
\ table that stood where joy_mask still does. It moved because CTRL+R on the
\ titles writes it, and it moved to ZERO PAGE rather than to the &0800 block
\ because `ldx joy_keys, y` is then zero-page,Y, which LDX has and which is
\ a byte shorter and a cycle cheaper than the absolute,Y this was.

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

.joy_mask EQUB &fe, &fd, &fb, &f7, &ef

\ The defaults, in the same order, copied into joy_keys by key_init at boot.
\ Up here beside joy_mask because they are the same five things in the same
\ order and a reader who finds one wants the other.
.joy_defaults EQUB KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_FIRE
