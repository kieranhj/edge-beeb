; animate sprites called every other frame from main loop
.AnimateSprites
; increment player frame, and restrict to 0-6
    ld hl,PlayerFrame
    ld a,(hl)
    inc a
    cp a,7
    jr c,ResetPlayerFrame
    xor a
.ResetPlayerFrame
    ld (hl),a
; animate enemy sprites
    ld hl,SpriteData+5
    ld de,SpritesYX+1
    ld b,6 ; 6 enemy sprites to animate
.AnmEnemyLp
    ld a,(de)
    rla ; if x coord 128 or higher, sprite off screen, so
    jr c,AnmEnemyReturn ; skip this sprite
    ld a,(hl) ; get animation byte/offset byte from SpriteData
    ld c,a ; save byte for retrieval later
    rlca
    rlca
    and a,3 ; mask out current frame, and continue based on animation type
    jr z,AEExplosion
    dec a
    jr z,AECycle
    dec a
    jr z,AEYoYo6
; if not those 3, must be YoYo5 (5 frame up then down animation cycle)
    ld a,c ; get byte from table back
    and a,15 ; get current frame
    inc l
    add a,(hl) ; add current direction (+1 or -1)
    jr z,AEYoYo5Invert ; if new frame is 0
    cp a,4
    jr nz,AEYoYo5NoInvert ; or new frame is 4
.AEYoYo5Invert ; then dont invert the animation direction byte
    ld c,a ; save new frame pointer
    ld a,&fe
    xor a,(hl) ; swap -1 to +1 or vice versa
    ld (hl),a
    ld a,c ; retrieve frame pointer
.AEYoYo5NoInvert
    dec l
    or a,128+64 ; put the animation type back in the byte
    ld (hl),a ; and write back to table
.AnmEnemyReturn ; common reentry point for other animation types
; move de and hl to point to next SpriteYX/SpriteData entry
    inc e
    inc e
    ld a,8
    add a,l
    ld l,a
    djnz AnmEnemyLp
    ret
.AECycle ; cycle frame up to specified maximum & reset
    ld a,c ; get byte from table back
    and a,15 ; get current frame
    inc a ; increment the current frame
    inc l
    ld c,(hl) ; get maximum frame into c
    dec l
    cp a,c
    jr c,AECycleNoReset ; if current frame exceeds maximum
    xor a ; reset current frame to 0
.AECycleNoReset
    or a,64 ; put the animation type back in the byte
    ld (hl),a ; and write back to table
    jr AnmEnemyReturn
.AEYoYo6 ; 6 frame up then down animation cycle
    ld a,c ; get byte from table back
    and a,15 ; get current frame
    inc l
    add a,(hl) ; add current direction (+1 or -1)
    jr z,AEYoYo6Invert ; if new frame is 0
    cp a,5
    jr nz,AEYoYo6NoInvert ; or new frame is 5
.AEYoYo6Invert ; then dont invert the animation direction byte
    ld c,a ; save new frame pointer
    ld a,&fe
    xor a,(hl) ; swap -1 to +1 or vice versa
    ld (hl),a
    ld a,c ; retrieve new frame pointer
.AEYoYo6NoInvert
    dec l
    or a,128 ; put the animation type back in the byte
    ld (hl),a ; and write back to table
    jr AnmEnemyReturn
.AEExplosion ; explosions are a special animation type
    ld a,c ; get byte from table back
    and a,15 ; get current frame
    inc a ; increment the current frame
    cp a,10 ; check to see if exceeded last frame
    jr nc,AEExpComplete ; if so, remove sprite
    set 5,a ; animation type is 0, but bit 5 represents 'transparent' to collision code
    ld (hl),a ; and write back to table
    jr AnmEnemyReturn
.AEExpComplete ; to remove the sprite, the coordinates just need to be set offscreen
    ex de,hl
    ld (hl),128 ; x= 128
    dec l
    ld (hl),0 ; y = 0
    inc l
    ex de,hl
    jr AnmEnemyReturn
