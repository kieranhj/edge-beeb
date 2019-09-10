.CalcSprites
; calculate screen addresses for sprites
; addresses are calculated for every second address
    ld a,(base_addr+1) ; determine list to write to from current base_addr high byte
    bit 6,a
    jr z,CalcSprLow
    ld hl,SpriteAddrHigh+170 ; 7 sprites x 11 addresses + 1 bullet x 8 addresses = 85x2 or 170 bytes
    jr CalcSprSkipLow
.CalcSprLow
    ld hl,SpriteAddrLow+170
    nop
    nop
.CalcSprSkipLow
    ld (SaveSP),sp
    ld sp,hl
    ld hl,SpritesYX+15
    exx
    ld h,&42 ; high byte of address table in h'
    exx
    ld b,8 ; sprite total
; for first sprite, only 8 rows as is player shot sprite
    ld a,(hl)
    sub a,16 ; the left of the screen is x co-ord 16, simplifies collision detection and enemy positioning
    jr nc,CalcSprBNotLeft
    xor a ; if sprite falls over left screen edge, align adresses to edge
.CalcSprBNotLeft
    cp a,73 ; screen is 78 bytes byte
    jr c,CalcSprBNotRight
    ld a,72 ; ensure sprites that fall over right edge have addresses that are 6 bytes short of right edge
.CalcSprBNotRight
; the reason for ensuring that the addresses are positioned such that they do not cross a screen edge is that
; the bullet sprite does not save background in the centre, it simply blanks it, and if the addresses weren't
; adjusted then clearing it would result in potential corruption of background on the opposite side of screen
; when it leaves the screen, or would require specific screen clearing routine to handle edges.
; That's only relevent to the right edge of course, the left edge is just 'planning ahead'.
    dec l
    ex af,af'
    ld a,(hl) ; get sprite y value
    add a,14+1 ; start from bottom of y for bullet, y co-ord must be even
    dec l ; move to next sprite x co-ord
    exx
    ld l,a ; hl' now points to lowest base address in table for bullet sprite
    ex af,af' ; get sprite x co-ord back
    ld bc,(base_addr)
    add a,c
    ld c,a
    jr nc,CaSprDontIncDPBul
    inc b
.CaSprDontIncDPBul
; bc' now contains combination of scroll offset + x co-ord to add to base addresses in table
    jr CalcSprPBulEntry ; bullet sprite is shorter, so skip 3 addresses in unrolled loop below
; rest of 7 sprites do full loop
.CalcSprLoop
    ld a,(hl) ; grab x co-ord
    sub a,16 ; left screen edge is x co-ord 16
    jr nc,CalcSprNotLeft
    xor a ; ensure sprite addresses dont cross left edge
.CalcSprNotLeft
    cp a,73
    jr c,CalcSprNotRight
    ld a,72 ; ensure sprite addresses dont cross right edge
.CalcSprNotRight
    dec l ; point to sprite y co-ord
    ex af,af'
    ld a,(hl)
    add a,20+1 ; start from bottom of sprite, y co-ord must be even
    dec l ; point hl to next sprite x co-ord
    exx
    ld l,a ; hl' now points to lowest base address in table for full sized sprite
    ex af,af'
    ld bc,(base_addr)
    add a,c
    ld c,a
    jr nc,CaSprDontIncD
    inc b
.CaSprDontIncD
; bc' now contains combination of scroll offset + x co-ord to add to base addresses in table
    ld d,(hl) ; load high byte of base address from table into d'
    dec l ; point to low byte of base address
    ld a,(hl) ; load low byte of base address from table into a
    add a,c ; add low byte of offset in bc' to a
    ld e,a ; and store result in e'
    ld a,b ; get high byte of offset
    adc a,d ; and add d' and carry from previous add
    ld d,a ; de' now contains screen address for top of the two scan lines each address is used for
    set 3,d ; want screen address to start from bottom scan line. in the event of screen address reset, this will have
            ; occured already, but does not cause a problem as base address starts from top line where reset is less complicated
    push de ; place address into address list pointed to by sp
    dec l ; point to high byte of next base address
; repeat above process another 10 times
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
.CalcSprPBulEntry
; bullet is only 8 addresses, so skips to here
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de
    dec l
;
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a
    set 3,d
    push de

    exx
    dec b ; repeate for all 8 sprites
    jp nz,CalcSprLoop
;
    ld sp,(SaveSP) ; restore sp and finish
    ret

.SaveSpriteBG
    ld a,(base_addr+1) ; determine list to read from current base_addr high byte
    bit 6,a
    jr z,SaveSprBGLow
    ld hl,SpriteAddrHigh ; hl points to high screen sprite addresses
    ld a,(ResetHigh) ; get byte indicating which sprites require slower 'safe' background save for high screen
    exx
    ld de,SpriteBufHigh ; de' points to high screen sprite background save buffer
    jr SaveSprBGSkipLow
.SaveSprBGLow
    ld hl,SpriteAddrLow ; hl points to low screen sprite addresses
    ld a,(ResetLow) ; get byte indicating which sprites require slower 'safe' background save for low screen
    exx
    ld de,SpriteBufLow ; de' points to lowscreen sprite background save buffer
    nop
    nop
.SaveSprBGSkipLow
    exx
    ld e,a ; e now has byte indicating which sprites require 'safe' background save
    ld c,7 ; 7 sprites at full size
.SaveSprLpO
    srl e ; put 'safe' marker bit for current sprite into carry
    jp nc,SaveSprFastSave ; if bit is 0, save background using fast method
    ld b,10 ; 10.5 line pairs, only save top line of last address, C64 sprites are an irritating 21 lines high
.SaveSprLoop
; this saves the background for the sprite a slow or 'safe' way, which means the sprite was determined to
; have crossed a screen edge, where the addresses no longer reflect the co-ordinates, or have overlapped with
; the screen address reset point.  Only one 'safe' routine, so every shift right is allowing for reset
    ld a,(hl) ; get low byte of address into a
    inc l
    ex af,af'
    ld a,(hl) ; get high byte of address into a'
    inc l
    exx
    ld h,a
    ex af,af'
    ld l,a ; hl' now contains screen address
;
    ld a,(hl)
    ld (de),a ; copy byte at address to buffer
    inc e ; move to next byte in buffer
    res 3,h ; point screen address to byte above
    ldi ; copy byte and move both buffer and screen address along
    set 3,h ; set screen address to point to lower line again
; sprites are 6 bytes wide, so repeat another 5 times
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    exx
    djnz SaveSprLoop ; repeat for all 10 line pairs of sprite
; repeat above process one last time for last address line, except only
; copy the top line as sprites are 21 lines high
    ld a,(hl)
    inc l
    ex af,af'
    ld a,(hl)
    inc l
    exx
    ld h,a
    ex af,af'
    ld l,a
;
    res 3,h
    ldi
;
    res 3,h
    ldi
;
    res 3,h
    ldi
;
    res 3,h
    ldi
;
    res 3,h
    ldi
;
    res 3,h
    ldi
;
    inc e ; buffer per sprite is 126 bytes, moving along by two bytes makes 128 bytes,
    inc de ; and buffer is page aligned so can use 8 bit increment on all but this last one
    exx
.SaveSprReturn
    dec c ; repeat for all 7 full sized sprites
    jr nz,SaveSprLpO
; now save bullet background
; middle two lines are not save as bullet sprite does not go through background, but can 'clip' it
; so only top and bottom 3 line pairs are saved
; bullet background is always saved with the slower 'safe' method
    ld e,2 ; do two sets of 3 pairs
.SaveSprPBLpO
    ld b,3 ; 3 line pairs
.SaveSprLoopPB ; below as for full sprites above
    ld a,(hl)
    inc l
    ex af,af'
    ld a,(hl)
    inc l
    exx
    ld h,a
    ex af,af'
    ld l,a
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    set 3,h
;
    ld a,(hl)
    ld (de),a
    inc e
    res 3,h
    ldi
    exx
    djnz SaveSprLoopPB
    inc l ; want to skip the two middle screen addresses
    inc l
    inc l
    inc l
    dec e
    jr nz,SaveSprPBLpO
    ret

;.SaveSprSkipSave
;    ld a,22
;    add a,l
;    ld l,a
;    exx
;    ld hl,128
;    add hl,de
;    ex de,hl
;    exx
;    jr SaveSprReturn
.SaveSprFastSave
    ld b,10 ; 10.5 line pairs
    exx
    ld c,&ff ; put a value in c' to stop b' from corrupting in loop
    exx
.SaveSprFLoop
    ld a,(hl) ; get low byte of address into a
    inc l
    ex af,af'
    ld a,(hl) ; get high byte of address into a'
    inc l
    exx
    ld h,a
    ex af,af'
    ld l,a ; hl' now contains screen address
;
    ld b,h ; save high byte in b
    res 3,h ; set to top line of line pair
    ldi ; copy the 6 bytes for the top line for this address
    ldi
    ldi
    ldi
    ldi
    ldi
    ld h,b ; retrieve the original high byte
    ld l,a ; and put the original low byte back
    ldi ; copy the 6 bytes for the bottom line for this address
    ldi
    ldi
    ldi
    ldi
    ldi
    exx
    djnz SaveSprFLoop ; repeat for all 10 line pairs
; as with 'safe' method, now need to do just the top line
; for the last address
    ld a,(hl)
    inc l
    ex af,af'
    ld a,(hl)
    inc l
    exx
    ld h,a
    ex af,af'
    ld l,a ; hl' has address to copy from
;
    res 3,h ; only want top address
    ldi ; copy last 6 bytes, line 21 of the sprite
    ldi
    ldi
    ldi
    ldi
    ldi
;
    inc e ; move de', the buffer pointer, along 2 bytes so buffer is 128 bytes
    inc de ; and so the slow routine can use 8 bit incs on e
    exx
    jp SaveSprReturn

.RestoreSpriteBG
    exx
    ld (SaveSP),sp
    ld a,(base_addr+1)
    bit 6,a ; load initial register values depending on high byte of base address
    jr z,RestSprBGLow
    ld sp,SpriteAddrHigh ; dont need address list again, so can use stack pointer to read
    ld hl,SpriteBufHigh ; hl' points to buffer of background to restore
    ld a,(ResetHigh) ; a temporarily holds reset byte
    jr RestSprBGSkipLow
.RestSprBGLow
    ld sp,SpriteAddrLow
    ld hl,SpriteBufLow
    ld a,(ResetLow)
    nop
    nop
.RestSprBGSkipLow
    exx
    ld b,a ; put reset byte into b
    ld c,7 ; 7 full sized sprites
.RestSprLpO
    srl b ; put reset bit into carry
    exx
    jp nc,RestSprFastRest ; if reset bit is 0, restore sprite background the fast way
; must restore sprite background the 'safe' way
    ld c,70 ; 10.5 line pairs - 6 ldis per iteration, plus 1 for the loop makes c=7*10
.RestSprLoop
    pop de ; get screen address into de'
;
    ld a,(hl)
    ld (de),a ; copy byte from buffer back to screen
    inc l ; move buffer pointer along
    res 3,d ; move screen address pointer up to byte above
    ldi ; copy byte from buffer to screen, and move both pointers right one byte
    set 3,d ; set screen address pointer to lower of the two lines
; repeat for the next 5 byte pairs
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
;
    dec c
    jr nz,RestSprLoop ; repeat for all 10 full line pairs
;    ld c,&ff ;    dec c
; get last address line and just copy the top line
    pop de
;
    res 3,d
    ldi
;
    res 3,d
    ldi
;
    res 3,d
    ldi
;
    res 3,d
    ldi
;
    res 3,d
    ldi
;
    res 3,d
    ldi
;
    inc l ; move buffer pointer along 2 bytes so sprite buffer is page aligned
    inc hl ; and only this one 16 bit inc is required
.RestSprReturn
    exx
    dec c ; repeat above for all 7 full sized sprites
    jr nz,RestSprLpO
; now restore the smaller player bullet, always performed with 'safe' method
    exx
    ld b,2 ; 2 lots of 3 line pairs
.RestSprLpPBO
    ld c,21 ; each line pair with 6 ldis per iteration 3*7=21
.RestSprLoopPB ; below restore as for full sprites above
    pop de
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
    set 3,d
;
    ld a,(hl)
    ld (de),a
    inc l
    res 3,d
    ldi
;
    dec c
    jr nz,RestSprLoopPB ; do the 3 line pairs
    djnz RestSprPBMidLoop ; if b is not zero, jumpt to below routine to blank the two middle line pairs
    exx
    ld sp,(SaveSP)
    ret
.RestSprPBMidLoop

    ld c,2 ; two line pairs in middle of bullet sprite to blank
    xor a ; zero a to write to the screen
.RestSprLoopPBBlank
    pop de ; get screen address into de'
;
    ld (de),a ; blank the first byte
    res 3,d
    ld (de),a ; blank the byte above
    inc de ; move screen pointer right
    set 3,d ; and set screen pointer to lower of two line pairs
; repeat process for next 10 bytes
    ld (de),a
    res 3,d
    ld (de),a
    inc de
    set 3,d
;
    ld (de),a
    res 3,d
    ld (de),a
    inc de
    set 3,d
;
    ld (de),a
    res 3,d
    ld (de),a
    inc de
    set 3,d
;
    ld (de),a
    res 3,d
    ld (de),a
    inc de
    set 3,d
;
    ld (de),a
    res 3,d
    ld (de),a
;
    dec c
    jr nz,RestSprLoopPBBlank ; repeat for the second pair of lines to be blanked
    jr RestSprLpPBO ; jump back to loop to restore background for lower part of bullet sprite

.RestSprFastRest
    ld c,130 ; 10.5 line pairs, 10 full pairs, 12 ldis per iterations, c=13*10
.RestSprFLoop
    pop de ; get screen address into de'
    ld a,e ; save low byte in a
    ld b,d ; save high byte in b'
;
    res 3,d ; set de' to point to top of the two lines
    ldi ; copy the top 6 bytes
    ldi
    ldi
    ldi
    ldi
    ldi
    ld d,b ; reset de' to begining of lower line
    ld e,a
    ldi
    ldi
    ldi
    ldi
    ldi
    ldi
    dec c ; repeat for all 10 lines
    jr nz,RestSprFLoop
;    ld c,&ff
    pop de ; get the last address
;
    res 3,d ; set to top line
    ldi ; copy the last 6 bytes
    ldi
    ldi
    ldi
    ldi
    ldi
;
    inc l ; move pointer to buffer along 2 bytes
    inc hl
    jp RestSprReturn ; return to main background restore loop

.PrnSprSkipSprite ; if sprite not on screen, simply move address pointer along and re-enter sprite print loop
    ld a,22
    add a,ixl
    ld ixl,a
    jp PrnSprSkipSpriteReturn

.PrintSprites
; map in sprite bank
    ld a,&c6
    ld (CurrentBank),a ; save current memory setting
    ld b,&7f
    out (c),a ; and bank in sprites
    ld a,(base_addr+1) ; retrieve high byte of base_screen
    bit 6,a
    jr z,PrnSprLow ; determine which address list to use
    ld ix,SpriteAddrHigh
    jr PrnSprSkipLow
.PrnSprLow
    ld ix,SpriteAddrLow
.PrnSprSkipLow
    ld b,6 ; 6 enemy sprites to print
    ld hl,SpriteData+5 ; point to location of first sprite's animation byte
    ld de,SpritesYX+1 ; point to location of first sprite's x co-ord
.PrnSprLpO
; get sprite frame
    ld a,(hl)
    bit 4,a ; first determine if enemy was just hit and needs to strobe
    jr z,NotStrobeFrame
    exx ; if so, swap out current b
    ld a,&c4 ; and bank in the strobed versions of sprite frames
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
    exx
    ld a,(hl) ; re-fetch the animation byte
.NotStrobeFrame
    and a,&f ; filter out all bits but the last 4, which are the frame offset
    dec l ; point hl to the base frame for the sprite
    add a,(hl) ; add base frame to offset
    ld c,a ; store sprite frame to display in c
    ld a,(de) ; get the sprite x co-ord
; test x co-ord for print sprite
;.SwimmerPrintEntry
    sub a,16 ; if sprite crosses left edge
    jp c,PrnSprOnLeftEdge ; jump to routine to handle found in EG_sprites_partial.asm
    sub a,73 ; if sprite crosses right edge or is unused
    jp nc,PrnSprOnRightEdge ; jump to routine to handle found in EG_sprites_partial.asm
    ld a,c ; retrieve sprite frame to print
; get sprite frame data start address
    exx ; save loop counters and pointers by using alternate registers
    ld l,0 ; zero l, sprites are page aligned with 2 empty bytes following every 126 byte sprite
    srl a ; divide a by 2, equates to a=a*128 for high byte
    jr nc,PrnSprDontIncL
    set 7,l ; if carry, sprite low byte pointer needs to be &80
.PrnSprDontIncL
    add a,&40 ; sprites banked into &4000, so add &40 to a
    ld h,a ; and ld into h, hl' now points to beginning of sprite data
    ld b,10 ; there are 10 full line pairs per sprite
.PrnSprLoop
; get screen address into de'
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
; the speed gain from having a fast and 'safe' way of printing the sprites was fairly small,
; and the sprite data required re-ordering to be faster in such a way that the 'safe' write
; would be even slower, so for this case, sprites are always printed a 'safe' way with respect
; to the screen address reset
    ld a,(hl) ; get the first byte, which is the lower left byte of the address line pair
    or a ; check if it's zero, masking only performed at byte level, or by pixel pairs
    jr z,PrnSprSkip1 ; don't print the byte to screen if zero
    ld (de),a ; otherwise, print it
.PrnSprSkip1
    res 3,d ; move the screen address pointer to the byte above
    inc l ; move the sprite data pointer along
    ld a,(hl) ; get the second data byte, now the top left byte of the address line pair
    or a ; check if it's zero
    jr z,PrnSprSkip2 ; skip if it is
    ld (de),a ; print if it is not
.PrnSprSkip2
    inc de ; move screen address pointer right
    set 3,d ; and move to the second line of the address line pair
    inc l ; move the sprite data pointer along one byte
; repeat for another 10 bytes, so all 12 bytes are printed
    ld a,(hl)
    or a
    jr z,PrnSprSkip3
    ld (de),a
.PrnSprSkip3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip4
    ld (de),a
.PrnSprSkip4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip5
    ld (de),a
.PrnSprSkip5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip6
    ld (de),a
.PrnSprSkip6
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip7
    ld (de),a
.PrnSprSkip7
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip8
    ld (de),a
.PrnSprSkip8
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip9
    ld (de),a
.PrnSprSkip9
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip10
    ld (de),a
.PrnSprSkip10
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip11
    ld (de),a
.PrnSprSkip11
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip12
    ld (de),a
.PrnSprSkip12
    inc l
; repeat for all 10 address line pairs
    djnz PrnSprLoop
; need to do last line of sprite, just the high line of the last address
; get address into de'
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d ; set the address to high line first
    ld a,(hl) ; get the data byte
    or a ; check if zero
    jr z,PrnSprSkip13 ; skip if it is
    ld (de),a ; otherwise print it
.PrnSprSkip13
    inc l ; move sprite data pointer along
    inc de ; move the screen pointer right
; repeat above for 5 more bytes
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip14
    ld (de),a
.PrnSprSkip14
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip15
    ld (de),a
.PrnSprSkip15
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip16
    ld (de),a
.PrnSprSkip16
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip17
    ld (de),a
.PrnSprSkip17
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip18
    ld (de),a
.PrnSprSkip18
; at this point, partial sprite print routines for left and right screen edge re-enter the main loop
.PrnSprPartialReturn
; in case last frame was strobe, set back to normal bank containing normal sprite frame data
    ld a,&c6
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
    exx ; get back the counter and pointer registers
.PrnSprSkipSpriteReturn ; if sprite was skipped, jumps to here after moving ix along
    inc e
    inc e ; move de along to next sprite x co-ord
    ld a,9
    add a,l
    ld l,a ; move hl along to next sprite's animation data
;
    dec b ; repeat for all 6 enemy sprites
    jp nz,PrnSprLpO
; player sprite frames and enemy bullet are compiled sprites, in a different bank
; map in compiled sprite bank
    ld a,&c5
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
; check shield life
    ld a,(Shield) ; check if player has invulnerabilty or game is over/complete
    or a
    jr z,PrnPlayerNormal ; if shield=0 continue as normal
    bit 7,a ; if highest bit is set
    jr nz,PrnPlySkip ; game over or complete, dont print player
    dec a ; otherwise, player died recently and is now invulnerable, so flicker (max of 2 seconds)
    ld (Shield),a ; write back new shield value
    cp a,25 ; if shield has less than a second left, want to flash faster
    jr c,PrnPlayerFastFlash ; so skip one divide by 2
    rra ; if shield more than one second left, flash slower
.PrnPlayerFastFlash
    rra
    jr c,PrnPlySkip ; skip player display depending on shield value bits 1 or two to indicate invulnerability
;
.PrnPlayerNormal
    ld a,(GrindState) ; check if player is currently grinding against background
    or a
    jr z,PrnPlyNoGrind ; if grind state is 0, not grinding, use normal frames
    dec a ; otherwise player is grinding, a counter is used because top and bottom of player are checked in alternate frames
    ld (GrindState),a ; so grind state persists for 1 frame after grinding is detected
    ld a,&10 ; now load lookup table offset for grinding player sprite frames
.PrnPlyNoGrind
    ld e,a ; ld e with 0 or &10
    ld a,(PlayerFrame) ; get player frame 0-6
    ld h,&40 ; get high byte of lookup table into h
    add a,a ; double the players frame value
    add a,e ; and add to e
    ld l,a ; put into l  hl now points to address of compiled sprite to jump to
    ld e,(hl) ; get low byte of sprite frame address
    inc l
    ld d,(hl) ; get high byte of sprite frame address
    ex de,hl ; hl now has start address of compiled sprite routine
    ld iy,PlySprReturn ; put return address in iy
    jp (hl) ; jump to player display routine, see CompiledSpriteBank2.asm
.PrnPlySkip ; if player was not displayed, move screen address pointer along
    ld de,22
    add ix,de
.PlySprReturn ; compiled player sprite routines return to here
    ld a,(SpritesYX+15) ; get x co-ord of player bullet
    sub a,72+16 ; adjust x co-ord so that a becomes 1-5 for partial frames on right screen edge
    jr c,PrnSpPBComplete ; if carried, need to print entire bullet sprite
    cp a,6 ; if player bullet not onscreen
    jr nc,LaserPrnRet ; dont print the bullet
    jr PrnSprPBCSkip ; otherwise continue, and skip the next line
.PrnSpPBComplete
    xor a ; the full frame of the player bullet is the first entry in the lookup table
.PrnSprPBCSkip
    ld h,&40 ; lookup table for player bullet starts at &4020
    add a,a ; double a to get address of routine for player bullet frame required
    add a,&20
    ld l,a ; hl now points to entry for address to jump to
    ld e,(hl)
    inc hl
    ld d,(hl)
    ex de,hl ; hl now holds address to jump to
    ld iy,LaserPrnRet ; load return address into iy
    jp (hl)
.LaserPrnRet ; bullet print returns here, or if bullet offscreen, skips to here
; map out compiled sprite bank, set memory to all base ram
    ld a,&c0
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
    ret

; this routine randomly places an explosion on the screen during the end sequence
.EndSeqExplosion
; only create a new explosion every 4 game frames
    ld a,(EndExpDelay)
    inc a
    and a,3
    ld (EndExpDelay),a
    ret nz ; abort if not time to create a new explosion
; loop through a pointer to a sprite, cycles through 0-5
    ld a,(EndExpPtr)
    inc a
    cp a,6
    jr c,ESENoRstPtr
    xor a
.ESENoRstPtr
    ld (EndExpPtr),a ; a now equals 0-5
; sprite coords
    add a,a ; double a
    add a,SpritesYX+1 ; and add Sprite co-ord base +1 so point to sprite x co-ord
    ld l,a
    ld h,0 ; hl now points to x co-ord in SpritesYX
    ld a,(hl)
    rla ; see if sprite co-ord is 128 or high, indication sprite is not in use
    ret nc ; abort if sprite is already on screen
    push hl ; preserve pointer
    call GenerateRandom ; get a random number for x co-ord
    ld a,l ; a has psuedo random number
    pop hl ; retrieve co-ord pointer
    and a,&7f ; make a 0-127
    cp a,80 ; check if over 79
    jr c,ESENoCorrX
    sub a,64 ; reduce by 64 if over 79
.ESENoCorrX
    add a,13 ; and add 13
    ld (hl),a ; sprite x co-ord now 13-92
    dec l ; point to sprite y co-ord
    push hl ; save pointer to y
    call GenerateRandom ; get another random number
    ld a,l ; a has the random number
    pop hl ; get pointer to y back
    cp a,200 ; check if over 199
    jr c,ESENoCorrY
    sub a,128 ; reduce by 128 if over 199
.ESENoCorrY
    add a,24 ; a now holds 24-223
    res 0,a ; y co-ord must be even number
    ld (hl),a ; write to sprite y
; no set up the sprite data
    ld a,l
    sub a,SpritesYX ; get a back to sprite index times 2
    add a,a
    add a,a ; now have sprite index times 8, length of SpriteData record
    add a,SpriteData+6 ; add SpriteData base, plus point to animation data record
    ld l,a ; h is identical for SpritesYX and SpriteData, so hl now points to appropriate SprideData entry
    xor a
    ld (hl),a ; animation data for explosion is zero
    dec l
    ld (hl),32 ; set animation type, start frame and transparent
    dec l
    ld (hl),a ; set base sprite frame
    dec l
    ld (hl),a ; timer
    dec l
    ld (hl),a ; rocker
    dec l
    ld (hl),64+2 ; move 2 - stationary
    dec l
    ld (hl),64+2 ; move 1 - stationary
; explosion now created
    ret
