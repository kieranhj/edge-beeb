.MoveSprites
    call ReadJoystick
    ld de,SpritesYXMv+&f
    ld hl,SpritesYX+&f
; player bullet move
    bit 7,(hl) ; check if bullet on screen
    jr z,MSMoveBullet
; if bullet off screen, check fire pressed
    ld a,(de)
    bit 4,a
    jr z,MSFireNotPressed
; if fire pressed, check game state
; ordinarily firing would be handled seperately to movement, but for this
; simple example there is only one player bullet allowed, so have checked it here
    ld a,(Shield)
    rla
    jr c,MSFireNotPressed ; no firing when game over
; now OK to create bullet
    ld a,(SpritesYX+12)
    add a,2
    ld (SpritesYX+14),a
    ld a,(SpritesYX+13)
    jr MSSkipBulletRemove
.MSMoveBullet
    ld a,(hl)
    add a,6
    cp a,78+16 ; check if bullet moved off screen
    jr c,MSSkipBulletRemove
    dec l
    ld (hl),0
    inc l
    ld a,192
.MSSkipBulletRemove
    ld (hl),a
.MSFireNotPressed
; point de and hl to player co-ords & move
    dec e
    dec e
    dec l
    dec l
; now do player move
    ld a,(Shield)
    bit 7,a
    jr z,MSDoPlayer ; game not over or complete
    dec e
    dec e
    dec l
    dec l
    jr MSEnemySprites
.MSDoPlayer
    ld a,(de)
    add a,(hl)
; keep player x co-ord in range
    cp a,16
    jr c,MSCancelXMv
    cp a,72+16
    jr nc,MSCancelXMv
    ld (hl),a
.MSCancelXMv
    dec l
    dec e
    ld a,(de)
    add a,(hl)
; keep player y co-ord in range
    cp a,32
    jr c,MSCancelYMv
    cp a,174
    jr nc,MSCancelYMv
    ld (hl),a
.MSCancelYMv
    dec l
    dec e
; finally move enemy sprites
.MSEnemySprites
    ld de,SpriteData+48-5 ; point to sprite 6 timer reset value
    ld b,6
.MvEnemySprLp
    bit 7,(hl) ; check if sprite on screen
    jr nz,MvEnemyBSkipThisSprite
    set 4,l ; go to SpriteYXMv where move timer is stored
    ld c,(hl)
    inc c
    inc c ; twice, because 25hz rather than 50
    ld a,(de)
    cp a,c
;    jr nz,DontResetMoveTimer
    jr nc,DontResetMoveTimer
    ld c,0
.DontResetMoveTimer
    ld (hl),c
    res 4,l ; set hl back to YX co-ords of sprite, c contains timer
    dec e ; point de to sprite rocker value
    ld a,(de)
    dec e ; point de to move 2
    cp a,c
; if the counter is above the rocker, process move 2, else use move 1
;
    jr c,MvEnemyMove2
    dec e ; point to move 1
    ld a,(de) ; get move 1 byte
    jr SkipEnemyMv2
.MvEnemyMove2
    ld a,(de) ; get move 2 byte
    dec e ; move de along to move 1
.SkipEnemyMv2
    ld c,a ; put move byte in c
; move is stored in byte y,x with 5 bits for y and 3 for x
; do x move first, range of move is 2,1,0,-1,-2
    and a,&7
    sub a,2
    add a,(hl) ; add current sprite x co-ord
    ld (hl),a ; and save back
    dec l ; move to y co-ord
; check sprite has not moved out of bounds
    cp a,16-5
    jr c,MvRemoveSprite
    cp a,78+16+8
    jr nc,MvRemoveSprite
; now do y move, range of move is 8,4,0,-4,-8
    ld a,c
    and a,&f8
    rrca
    rrca
    rrca
    sub a,8
    add a,(hl) ; add current sprite x co-ord
    ld (hl),a ; and save back
; check sprite has not moved out of bounds
    cp a,2 ;12
    jr c,MvRemoveSprite
    cp a,192
    jr nc,MvRemoveSprite
.MvEnemySprRet
    dec l
    ld a,-5 ; point de to next sprites timer reset value
    add a,e
    ld e,a
    djnz MvEnemySprLp
    ret

; to skip sprite, just move pointers along
.MvEnemyBSkipThisSprite
    dec e
    dec e
    dec e
    dec l
    jr MvEnemySprRet

; simply set sprite offscreen to mark as free and prevent
; unneccesary processing
.MvRemoveSprite
    ld (hl),0
    inc l
    ld (hl),128
    dec l
    jr MvEnemySprRet

; secondary bullet move for frame, player bullet is moved twice per frame
; because high speed would otherwise result in requirement for a long hit box tail,
; where unpredictable sprite id order could see bullet hit sprites behind other
; sprites when close together
.InterimBulletMove
    ld hl,SpritesYX+&f
; player bullet move
    bit 7,(hl)
    ret nz ; for interim move, dont need to check fire pressed, quit if bullet off screen
    ld a,(hl)
    add a,6
    cp a,78+16
    jr c,IBMSkipBulletRemove
    dec l
    ld (hl),0
    inc l
    ld a,192
.IBMSkipBulletRemove
    ld (hl),a
    ret

.ReadJoystick
; keys are scanned under interrupt, check key table for input from
; joystick first, or qaop if not, or cursor keys if not those.
; check joystick as first preference
    ld a,(KBmatrixbuf+9)
    and a,31             ;2
    jr nz,InputReceived  ;2/3
    ld e,a               ;1
; keyboard control
    ld a,(KBmatrixbuf+8) ;4
    bit 3,a              ;2
    jr z,RdJoyNotQ       ;2/3
    set 0,e              ;2
.RdJoyNotQ
    bit 5,a              ;2
    jr z,RdJoyNotA       ;2/3
    set 1,e              ;2
.RdJoyNotA
    ld hl,KBmatrixbuf+4  ;3
    bit 2,(hl)           ;3
    jr z,RdJoyNotO       ;2/3
    set 2,e              ;2
.RdJoyNotO
    dec l         ;1
    ld a,8        ;2
    and a,(hl)    ;2
    or a,e        ;1 ; want end product in a
    jr nz,RdJoyCheckSpace ;2/3
; end keyboard read, check cursor if none of qaop pressed
.UseCursor ;
    ld hl,KBmatrixbuf+1 ;3
    bit 0,(hl)          ;2
    jr z,RdJoyNotCurL   ;2/3
    set 2,e             ;2
.RdJoyNotCurL
;    dec hl
    dec l               ;1
    bit 2,(hl)          ;2
    jr z,RdJoyNotCurD   ;2/3
    set 1,e             ;2
.RdJoyNotCurD
    bit 1,(hl)          ;2
    jr z,RdJoyNotCurR   ;2/3
    set 3,e             ;2
.RdJoyNotCurR
    ld a,1        ;2
    and a,(hl)    ;2
    or a,e        ;1 ; want end product in a
; end cursor read
.RdJoyCheckSpace
    ld hl,KBmatrixbuf+5  ;3
    bit 7,(hl)           ;3
    jr z,InputReceived   ;2/3
    set 4,a              ;2
.InputReceived ; at this point, have got what input there is, if any
; translate input to player sprite movement
    ld hl,KeyInY ; point to player y move
    ld c,0
    ld (hl),c ; zero input
    bit 0,a
    jr z,RdJySkipYUp
.PlayerMoveUpStep
    ld (hl),252
    jr RdJySkipYDn
.RdJySkipYUp
    bit 1,a
    jr z,RdJySkipYDn
.PlayerMoveDownStep
    ld (hl),4
.RdJySkipYDn
    inc l ; point to player x move
    ld (hl),c
    bit 2,a
    jr z,RdJySkipXLe
    ld (hl),255
    jr RdJySkipXRi
.RdJySkipXLe
    bit 3,a
    jr z,RdJySkipXRi
    ld (hl),1
.RdJySkipXRi
    inc l ; point to player fire pointer
; need to prevent auto fire
    and a,16
    jr z,RdJyWriteFire ; if fire not held, write no firing, clear last fire
    cp a,(hl) ; if fire held, check if pressed last frame
    jr nz,RdJyWriteFire ; if not, write fire and block autofire for next frame
; holding fire, dont clear auto fire block until released, dont allow fire
    xor a
    jr RdJyWriteFire+1
.RdJyWriteFire
    ld (hl),a ; write last fire value
    inc l
    ld (hl),a ; write firing indicator used in MoveSprites
    ret


.readmatrix
; scan keys, called under interrupt.  KBmatrixbuf assumed page aligned
    ld hl,KBmatrixbuf
    ld de,&f0a
    ld bc,&f40e
    out (c),c
    ld b,&f6
    in a,(c)
    and &30
    ld c,a
    or &c0
    out (c),a
    out (c),c
    inc b
    ld a,&92
    out (c),a
    push bc
    set 6,c
.scankey
    ld b,&f6
    out (c),c
    ld b,&f4
    in a,(c)
    cpl
    ld (hl),a
    inc l
    inc c
    ld a,c
    and a,d
    cp a,e
    jr nz,scankey
    pop bc
    ld a,&82
    out (c),a
    dec b
    out (c),c
    ret ; 64 - 2 + 10 * 23 = 292
