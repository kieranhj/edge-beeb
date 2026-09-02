\ ******************************************************************
\ *	keyboard.asm
\ *	Player input via OSBYTE &79 (to be replaced by direct VIA reads in Layer 2).
\ ******************************************************************

.read_keyboard
{
    \\ Read keyboard

    lda #&79
    ldx #KEY_UP EOR &80
    jsr osbyte
    txa
    bpl not_up
    \\ Up
    dec y_pos
    dec y_pos
    .not_up

    lda #&79
    ldx #KEY_DOWN EOR &80
    jsr osbyte
    txa
    bpl not_down
    \\ Down
    inc y_pos
    inc y_pos
    .not_down

    lda #&79
    ldx #KEY_LEFT EOR &80
    jsr osbyte
    txa
    bpl not_left
    \\ Left
    dec x_pos
    .not_left

    lda #&79
    ldx #KEY_RIGHT EOR &80
    jsr osbyte
    txa
    bpl not_right
    \\ Right
    inc x_pos
    .not_right

    rts
}
