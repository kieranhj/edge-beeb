.ProcessWave
; if game ended or lives out, dont process
    ld a,(Shield)
    cp a,&80
    ret z
; check delay to next enemy, if zero process next entry, else decrement and quit
    ld a,(WaveDelay)
    dec a
    jr z,SpawnNewEnemy
    ld (WaveDelay),a
    ret
.SpawnNewEnemy
; map in wave data sprite bank
    ld a,&c5
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
;find a vacant sprite slot, sprites are vacant when X coord is 128 or higher
    ld hl,SpritesYX+11
    ld b,6
.SNEFindSlot
    bit 7,(hl)
    jr nz,SNEFoundSlot
    dec l
    dec l
    djnz SNEFindSlot
; no slot free, abort, and retrieve wait to next sprite and insert into wait
    ld hl,(WavePointer)
    ld de,8
    add hl,de
    jr SNEAbortEntry

.SNEFoundSlot
; grab wave pointer and get start coords for new enemy to spawn
; data format can be found in EG_Wave_Export2.asm
    ld de,(WavePointer)
    ld a,(de)
    cp a,&fe         ; if X coord is &fe, end of game reached
    jr z,SNEEndGame  ; so trigger end sequence
    ld (hl),a ; put X coord in SpriteYX table
    inc de
    dec l
    ld a,(de)
    ld (hl),a ; put Y coord in SpriteYX table
    set 4,l
    inc l
    ld (hl),0 ; clear sprite behaviour timer
    inc de
    ex de,hl ; now put wave source in hl
    ld a,b
    add a,a
    add a,a
    add a,a
    add a,&60-8
    ld e,a ; and SpriteData table entry in de based on entry still held in b
           ; d already contained 0 as de previously held ptr to SpriteYX
    ldi ; copy move 1
    ldi ; copy move 2
    ldi ; copy rocker
    ldi ; copy timer reset point
    ld a,(hl) ; get sprite id ptr
    inc hl
    push hl ; save wave ptr so can get frame & animation data from lookup table SpriteLookup
    ld c,a
    add a,a
    add a,c ; a = a*3
    add a,&d0 ; SpriteLookup starts at &d0
    ld h,d ; set h=0
    ld l,a
    ldi ; copy base sprite frame to SpriteData entry
    ldi ; animation type and start offset
    ldi ; max offset or direction, depending on animation type
    pop hl ; get wave data pointer back
    ldi ; copy enemy shield strength
.SNEAbortEntry
    ld a,(hl) ; get wait until next enemy is to be spawned
    or a ; check if not creating two enemies at once
    jr nz,SNEWaitfornextEnemy
; spawn additional enemy in same frame if wait is 0
    inc hl
    ld (WavePointer),hl
    jr SpawnNewEnemy
.SNEGameNotQuiteWon ; entry from SNEEndGame below
; if reach end of game after final life lost, put dummy values in wave process
; pointers and wait for game over time out as normal
    ld hl,wave_data-1
.SNEWaitfornextEnemy
; write delay and pointer to next enemy
    inc hl
    ld (WavePointer),hl
    ld (WaveDelay),a
.SNECommonExit
; map out wave data sprite bank
    ld a,&c0
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
    ret

.SNEEndGame
; end of game reached
    ld a,(Lives)
    or a ; .  check if lives not 0
    jr z,SNEGameNotQuiteWon ; in which case, continue with game over sequence
; put lives into bonus marker
    ld (MegaBonus),a
    ld a,50
    ld (BonusWait),a ; just used to space the 5000 point bonus for each life apart
; set player sprite status
    ld a,&80
    ld (Shield),a
; copy player location to sprite 1 for flying offscreen animation
; required as player sprite is compiled and would require a fix to fly
; off of screen edge
    ld hl,SpritesYX+12
    ld de,SpritesYX
    ldi
    ldi
    ld hl,SpriteData
    ld (hl),64+3
    inc l
    ld (hl),64+3
    inc l
    ld (hl),0
    inc l
    ld (hl),0
    inc l
    ld (hl),11
    inc l
    ld a,(PlayerFrame)
    add a,64
    ld (hl),a
    inc l
    ld (hl),7
; now put player sprite below visible screen so does not interfere with end seq
; with the background save and restore being offset by a pixel between frames
    ld a,192
    ld (SpritesYX+12),a
; set up pause to clear enemy sprite from visible screen address space
    ld a,3 ; this ensures enemy sprite used to show player flying off screen has it's
    ld (GameCompletePlyrClear+1),a ; screen addresses set offscreen for both frames
                                   ; to avoid old background being written over end sequence
    jr SNECommonExit ; use common exit above to map out wave data bank

