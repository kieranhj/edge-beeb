.CheckBackgrounds2
; check if centre (horizontal length) of player bullet is over any background
    ld a,(base_addr+1)
    bit 6,a
    jr z,ChkBG2Low
    ld hl,SpriteAddrHigh+154+6
    jr ChkBG2SkipLow
.ChkBG2Low
    ld hl,SpriteAddrLow+154+6
    nop
    nop
.ChkBG2SkipLow
; have got hl pointing to the screen address list for the middle of the bullet
; read the addresses and check the contents of the bytes at ends & centre of
; the sprite
    ld e,(hl)  ;5
    inc l
    ld d,(hl)  ;5
    inc l
    ex de,hl
    res 3,h      ;2
    ld a,(hl)    ;2
    inc hl       ;2
    res 3,h      ;2
    inc hl       ;2
    res 3,h      ;2
    or a,(hl)    ;2
    inc hl       ;2
    res 3,h      ;2
    or a,(hl)    ;2
    inc hl       ;2
    res 3,h      ;2
    inc hl       ;2
    res 3,h      ;2
    or a,(hl)    ;2
    ex de,hl
; ; read second address from centre of sprite and repeat process
    ld e,(hl)
    inc l
    ld d,(hl)
    ex de,hl
    or a,(hl)
    res 3,h      ;2
    or a,(hl)    ;2
    inc hl       ;2
    res 3,h      ;2
    inc hl       ;2
    res 3,h      ;2
    or a,(hl)    ;2
    inc hl       ;2
    res 3,h      ;2
    or a,(hl)    ;2
    inc hl       ;2
    res 3,h      ;2
    inc hl       ;2
    res 3,h      ;2
    or a,(hl)    ;2
    jr z,CheckBG2Player ; bullet still in play, check player
; if contents not zero, at least one byte hit, must now set bullet co-ords off screen
; along with resetting the screen address list due to the background collision
    ld bc,(base_addr)
    ld hl,&640
    add hl,bc
    set 3,h
    ex de,hl
; de now loaded with base dummy address
; set hl to beginning of address list for the bullet
    ld a,-9
    add a,l
    ld l,a
    ld b,8 ; for each of the 8 addresses, load the offscreen dummy address
.ChkBG2ClrLp
    ld (hl),e
    inc l
    ld (hl),d
    inc l
    djnz ChkBG2ClrLp
; now reset co-ords
    ld hl,SpritesYX+15
    ld (hl),192
    dec l
    ld (hl),0
.CheckBG2Player
; two checks to do, centre for player kill, and edge for grinding bonus
; player kill collision check
; set the high or low screen address pointer according to frame in use
    ld a,(base_addr+1)
    bit 6,a
    jr z,PlyCollLow
    ld ix,SpriteAddrHigh+132+6 ; top of centre for kill check
    ld de,SpriteAddrHigh+132 ; sprite top for top grind check
    jr PlyColSkipLow
.PlyCollLow
    ld ix,SpriteAddrLow+132+6 ; top of centre for kill check
    ld de,SpriteAddrLow+132+20 ; sprite bottom for bottom grind check
.PlyColSkipLow
    ld a,(Shield)
    rlca
    ret c ; if game over or game complete (bit 7 of shield high), abort all checks
    or a
    jr nz,PlyColGrind ; if shield otherwise non-zero, skip kill check
    ld c,0 ; square in centre of player sprite is checked at all 4 corners
    ld l,(ix+0)
    ld h,(ix+1)
    res 3,h
    inc hl
    res 3,h
    inc hl
    res 3,h
    ld a,(hl)
    inc hl
    res 3,h
    or a,(hl)
    jr z,PlyColNoColHigh
    inc c
.PlyColNoColHigh
    ld l,(ix+6)
    ld h,(ix+7)
    res 3,h
    inc hl
    res 3,h
    inc hl
    res 3,h
    ld a,(hl)
    inc hl
    res 3,h
    or a,(hl)
    jr z,PlyColNoColLow
    inc c
.PlyColNoColLow
    ld a,2
    cp a,c ; if both top & bottom of sentre square has a collision
    jr z,PlayColFatal ; consider player to have had fatal collision
.PlyColGrind
; now do player grinding check
; depending on frame, this will either be top or bottom of sprite edge,
; but not both in one game frame
    ex de,hl
    ld e,(hl)
    inc l
    ld d,(hl)
    ex de,hl
    res 3,h
    ld a,(hl)
    inc hl
    res 3,h
    inc hl
    res 3,h
    ld a,(hl)
    inc hl
    res 3,h
    or a,(hl)
    inc hl
    res 3,h
    inc hl
    res 3,h
    ld a,(hl)
    ret z
; player is grinding, add score
    ld a,(ScoreFrame+1)
    add a,25
    ld (ScoreFrame+1),a
    ld a,2 ; grind state means animation for grinding continues every frame even though
    ld (GrindState),a ; top and bottom of sprite are checked on alternate frames
    ret

.PlayColFatal ; also used by player sprite collision
    ld hl,Lives
    ld c,50 ; 2 seconds for shield after life loss
    dec (hl)
    ld a,(hl)
    or a
    jr nz,ContinuePlay ; if lives still above zero
    ld c,128+100 ; else trigger game over and 4 second wait instead
.ContinuePlay
    inc l
    ld (hl),c
    inc l
    inc (hl) ; next frame, convert enemy sprites to explosion (trigger by non zero value)
; this is delayed so screen addresses dont need rewriting for all 6 sprites in this frame
    ret

.CheckScreenReset
; check the player sprite and 6 enemy sprites against the x,y location of the screen
; address reset position.  Set a bit in c if necessary so that 'safe' save and restore
; background routines are used.  The bullet is always handled 'safely' simply because
; it is a different size and the saving would be in my view too minimal to warrant
; the additional code (in a larger game, at least)
    exx
    ld a,(base_addr+1)
    bit 6,a
    jr z,ChkSRLow
    ld hl,ResetHigh
    jr ChkSRSkipLow
.ChkSRLow
    ld hl,ResetLow
    nop
    nop
.ChkSRSkipLow
    exx
    ld c,0
    ld hl,ResetYX
    ld a,(hl)
    sub a,20
    ld d,a
    inc l
    ld a,(hl)
; dont check if YX reset point on screen edge, cant be crossed by any sprite
    cp a,16 ; screen left edge is x co-ord 16
    jr z,CSRAllClear
    sub a,6 ; subtract sprite width off location for check
    ld e,a
;.ColSwimYXInsert
    ld hl,SpritesYX+13
;.ColSwimbInsert
    ld b,7
.ChkSRloop
    sla c ; shift current collsion bits along
    ld a,(hl) ; get sprite x co-ord
    dec l
; if sprite is partially or fully offscreen, default to safe method
; this is because the screen co-ords dont match the addresses generated in this
; case (see CalcSprites for reason why)
    cp a,16
    jr c,CSRSafe
    cp a,73+16
    jr nc,CSRSafe
; sprite not on screen edge or offscreen, so check if sprite overlaps screen address
; reset location
    sub a,e
    jr c,CSNoColl
    cp a,6
    jr nc,CSNoColl
    ld a,(hl)
    sub a,d
    jr c,CSNoColl
    cp a,28
    jr nc,CSNoColl
; if reached here, collision with reset point occured, so mark sprite as requiring
; the 'safe' version of background save & restore
.CSRSafe
    set 0,c

.CSNoColl
    dec l
    djnz ChkSRloop
.CSRAllClear
    ld a,c
    exx
    ld (hl),a ; write collision byte for current frame
    exx
    ret

.BulletCollision
; check player bullet against enemy sprites
; start with checking player bullet
    ld hl,SpritesYX+15
    ld a,(hl)
; dont check if shot off screen
    bit 7,a
    ret nz ; abort if bullet off screen
; get bullet co-ordinates and adjust according to dimensions of enemy sprites
    sub a,5 ; if enemy sprite x co-ord is less than 6 lower than bullet, there is a hit
    ld e,a ; put adjusted x co-ord into e
    dec l
    ld a,(hl) ; get bullet y co-ord
    sub a,20 ; as for x, if sprite y co-ord is less than 21 lower than bullet, it hits
    ld d,a ; put adjusted y co-ord into d
    dec l
    dec l ; pass over player xy co-ords
    dec l
    ld b,6 ; check 6 enemy sprites xy co-ords, pointed to by hl
.ColShotSloop
    ld a,(hl) ; get sprite x pos into a
    dec l ; point hl to sprite y
    sub a,e ; sub adjusted bullet x pos
    jr c,CSSNoColl ; if still carry, sprite x too far left for hit
    cp a,11 ; compare with 11 - bullet width + the 5 subtracted from it previously
    jr nc,CSSNoColl ; if sprite x still higher, is too far right for hit
    ld a,(hl) ; get sprite y
    sub a,d ; sub adjusted bullet y pos
    jr c,CSSNoColl ; if still carry, sprite y too far above for hit
    cp a,36 ; compare with 36 - bullet height + the 20 subtracted from it previously
    jr c,ShotHit ; if sprite y lower than 36, bullet has hit, handle
; not hit otherwise
.CSSNoColl
    dec l ; move to next sprite x co-ord
    djnz ColShotSloop ; and check next sprite
    ret

.PlayerCollision
; check player against sprites
    ld a,(Shield)
    or a
    ret nz ; if player has non zero shield value, abort check
; get player co-ordinates and adjust according to dimensions of enemy sprites
; process is same as for bullet above, except as noted below
    ld hl,SpritesYX+13
    ld a,(hl)
    sub a,4 ; player has a byte width of overlap with sprites in x that is safe
    ld e,a
    dec l
    ld a,(hl)
    sub a,16 ; player has a 4 bytes height of overlap with sprites in y that is safe
    ld d,a
    dec l ; hl now points to 6th enemy sprite
    ld b,6
.ColPlyCloop
; following process identical to bullet check, except for overlap
    ld a,(hl)
    dec l
    sub a,e
    jr c,CPCNoColl
    cp a,9 ; 9 is sprite width -1 for over lap, plus the 4 subracted above, giving
    jr nc,CPCNoColl ; overlap for both sides
    ld a,(hl)
    sub a,d
    jr c,CPCNoColl
    cp a,33 ; 33 is sprite height -4 for over lap, plus the 16 subracted above, giving
    jr c,PlyCollision ; overlap for both above and below the player
; player OK if here
.CPCNoColl
    dec l ; move to next sprite x co-ord
    djnz ColPlyCloop ; and check next sprite
    ret

.ShotHit
; if bullet has hit sprite, find entry in SpriteData table from value in b
    ld a,b
; swap to alternate registers in case hit was with explosion and collsion checks
; need to continue
    exx
    rlca ; x2
    rlca ; x4
    rlca ; SpriteData is 8 bytes long
    add a,&60+5-8 ; and starts at &60, while b=1-6 so -8 is applied, +5 is animation entry
    ld l,a
    ld h,0 ; hl points to SpriteData for sprite hit, animation entry
    ld a,(hl)
    exx ; swap to primary registers in case collison checks need to continue
    bit 5,a ; indicates if sprite is explosion
    jr nz,CSSNoColl ; if bit set, have hit an explosion, check rest of sprites
; if here, must remove shot and deal with impact on enemy
    exx ; return to SpriteData table
    inc l
    inc l ; got to entry at +7, this holds enemy sprite shield value
    ld a,(hl)
    dec a
    jr z,ShotHDestroy ; if no hits left, turn enemy into explosion
; not destroyed yet, so reduce hits, remove shot and add chipping score
    ld (hl),a ; store new shield value
    dec l
    dec l ; back to animation byte at +5 in SpriteData
    set 4,(hl) ; tells sprite print routine to use strobe frame for this sprite
    exx ; done with SpriteData table
    ld a,40 ; add chipping score
    ld hl,ScoreFrame+1
    jr ShotRemove ; skip to removing the bullet
.ShotHDestroy
; enemy becomes explosion
    dec l ; go to +6 in SpriteData, which is sprite animation data
    xor a
    ld (hl),a ; clear the animation data
    dec l
    ld (hl),32 ; set animation type to 0 (explosion), offset to 0, bit 5 on to indicate explosion
    dec l
    ld (hl),a ; explosion starts at frame 0 in sprite table
    dec l
    ld (hl),a ; set animation timer to 0
    dec l
    ld (hl),a ; set rocker to 0
    dec l
    ld (hl),64+2 ; set move 2 to stationary
    dec l
    ld (hl),64+2 ; set move 1 to stationary
    exx
    ld a,4 ; add destruction score - 400
    ld hl,ScoreFrame
.ShotRemove
    ld (hl),a ; put destruction or chipping score in hl
    ld hl,SpritesYX+14 ; point to bullet y co-ord
    ld (hl),0 ; set y to 0
    inc l ; point to bullet x co-ord
    ld (hl),192 ; set to 192
    ret

.PlyCollision
; if palyer has hit sprite, find entry in SpriteData table from value in b
    ld a,b
; swap to alternate registers in case hit was with explosion and collsion checks
; need to continue
    exx
    rlca ; x2
    rlca ; x4
    rlca ; SpriteData is 8 bytes long
    add a,&60+5-8 ; and starts at &60, while b=1-6 so -8 is applied, +5 is animation entry
    ld l,a
    ld h,0 ; hl points to SpriteData for sprite hit, animation entry
    ld a,(hl)
    exx ; swap to primary registers in case collison checks need to continue
    bit 5,a ; indicates if sprite is explosion
    jr nz,CPCNoColl ; if bit set, have hit an explosion, check rest of sprites
    jp PlayColFatal ; player hit sprite, reduce lives and trigger explosion

.InterimBulletCollision
; do interim background collision check
; in this case, screen address for bullet has not yet been calculated
; so first, must determine screen address for interim background collision check
    ld hl,SpritesYX+15
    ld a,(hl)
; dont check if shot off screen
    bit 7,a
    ret nz ; abort if bullet off screen
    sub a,16-5 ;; -5: want leading edge of bullet sprite in this case
    jr nc,IBCCalcSprBNotLeft
    xor a ; should occur, but make sure bullet is not past left edge
.IBCCalcSprBNotLeft
    cp a,73+5
    jr c,IBCCalcSprBNotRight
    ld a,72+5 ; ensure screen address is no further right than right most screen edge
.IBCCalcSprBNotRight
    dec l
    ex af,af'
    ld a,(hl)
    add a,6+1 ; point in the middle of bullet sprite (horizontally)
    ld h,&42
    ld l,a ; point hl to address look up table for screen addresses
    ex af,af'
    ld bc,(base_addr) ; get scroll offset and add sprite offset
    add a,c
    ld c,a
    jr nc,IBCCaSprDontIncDPBul
    inc b
.IBCCaSprDontIncDPBul
; get address from table location pointed to by hl into de and apply offset in bc
    ld d,(hl)
    dec l
    ld a,(hl)
    add a,c
    ld e,a
    ld a,b
    adc a,d
    ld d,a ; base address read from table and scroll & sprite offset now applied
; now check background.  For the interim check, only checking one byte of leading edge
; as the bullet is not actually printed here, and the background is 'thick' enough that
; this one test ensures the bullet will not pass through anything
    ld a,(de)
    or a
    ret z ; if byte clear, bullet can continue
    ld hl,SpritesYX+14 ; otherwise, set it off screen
    ld (hl),0
    inc l
    ld (hl),192
    ret

; when the player explodes the 6 enemy sprites are set up as explosions
; by doing this before screen addresses are calculated the addresses are determined
; as normal in CalcSprites, reducing the additional code executed to when the player
; loses a life
.SetExplosion
    xor a
    ld (ExplosionSet),a ; clear the explosion trigger
    ld hl,SpritesYX+13 ; get the players current xy co-ords for start position
    ld d,(hl)
    dec l
    ld e,(hl)
    dec l ; hl now points to x co-ord of 6th sprite
    ld b,6
.SetExCoordLp ; make all 6 sprites share player current co-ords
    ld (hl),d
    dec l
    ld (hl),e
    dec l
    djnz SetExCoordLp
    ld hl,ExplosionList ; hl = move list so explosions move in different directions
    ld de,SpriteData ; de = beginning of move and animation data table
    xor a
    ld bc,&6ff
.SetExSDLp
    ldi ; write move 1
    ldi ; write move 2
    ld (de),a ; write rocker
    inc e
    ld (de),a ; write timer
    inc e
    ld (de),a ; write base sprite frame
    inc e
    ex de,hl
    ld (hl),32 ; write animation type/current frame offset
    ex de,hl
    inc e
    ld (de),a ; unused in explosion
    inc e
    ld (de),a ; no hits
    inc e
    djnz SetExSDLp
    ret

; list of directions for the 6 sprites used when player 'explodes'
.ExplosionList
    defb 64+0,64+0
    defb 32+0,32+0
    defb 32+3,32+3
    defb 96+4,96+4
    defb 128+2,128+2
    defb 128+1,128+1

