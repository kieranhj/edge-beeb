; this file contains sprite printing routines for partial sprites that cross the
; left and right edges of the screen

; these wont be commented as they are a straight forward revision of the main sprite
; printing code.

; Only thing to note is that screen addresses are always calculated
; for a 6x21 byte block that is entirely on the screen and does not cross an edge, so for
; printing sprites on the left edge, the sprite uses the screen addresses in the address
; list but for printing on the right edge, the addresses will be 6 bytes from the right
; edge, so the routines need to move the address right by 6 minus the number of bytes
; to print 

.PrnSprOnLeftEdge
    inc a
    jp z,PrnSprLeft5
    inc a
    jp z,PrnSprLeft4
    inc a
    jp z,PrnSprLeft3
    inc a
    jp z,PrnSprLeft2
    inc a
    jp nz,PrnSprSkipSprite
; assume print one column of sprite on left
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLL1
    set 7,l
.PrnSprDontIncLL1
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopL1
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip11L1
    ld (de),a
.PrnSprSkip11L1
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip12L1
    ld (de),a
.PrnSprSkip12L1
    inc l
;
    djnz PrnSprLoopL1
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
;
    inc l
;
    inc l
;
    inc l
;
    inc l
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip18L1
    ld (de),a
.PrnSprSkip18L1
    jp PrnSprPartialReturn

.PrnSprLeft5
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLL5
    set 7,l
.PrnSprDontIncLL5
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopL5
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip3L5
    ld (de),a
.PrnSprSkip3L5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip4L5
    ld (de),a
.PrnSprSkip4L5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip5L5
    ld (de),a
.PrnSprSkip5L5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip6L5
    ld (de),a
.PrnSprSkip6L5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip7L5
    ld (de),a
.PrnSprSkip7L5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip8L5
    ld (de),a
.PrnSprSkip8L5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip9L5
    ld (de),a
.PrnSprSkip9L5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip10L5
    ld (de),a
.PrnSprSkip10L5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip11L5
    ld (de),a
.PrnSprSkip11L5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip12L5
    ld (de),a
.PrnSprSkip12L5
    inc l
;
    djnz PrnSprLoopL5
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip14L5
    ld (de),a
.PrnSprSkip14L5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip15L5
    ld (de),a
.PrnSprSkip15L5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip16L5
    ld (de),a
.PrnSprSkip16L5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip17L5
    ld (de),a
.PrnSprSkip17L5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip18L5
    ld (de),a
.PrnSprSkip18L5
    jp PrnSprPartialReturn

.PrnSprLeft4
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLL4
    set 7,l
.PrnSprDontIncLL4
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopL4
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
    inc l
;
    inc l
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip5L4
    ld (de),a
.PrnSprSkip5L4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip6L4
    ld (de),a
.PrnSprSkip6L4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip7L4
    ld (de),a
.PrnSprSkip7L4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip8L4
    ld (de),a
.PrnSprSkip8L4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip9L4
    ld (de),a
.PrnSprSkip9L4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip10L4
    ld (de),a
.PrnSprSkip10L4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip11L4
    ld (de),a
.PrnSprSkip11L4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip12L4
    ld (de),a
.PrnSprSkip12L4
    inc l
;
    djnz PrnSprLoopL4
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
;
    inc l
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip15L4
    ld (de),a
.PrnSprSkip15L4
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip16L4
    ld (de),a
.PrnSprSkip16L4
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip17L4
    ld (de),a
.PrnSprSkip17L4
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip18L4
    ld (de),a
.PrnSprSkip18L4
    jp PrnSprPartialReturn

.PrnSprLeft3
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLL3
    set 7,l
.PrnSprDontIncLL3
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopL3
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip7L3
    ld (de),a
.PrnSprSkip7L3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip8L3
    ld (de),a
.PrnSprSkip8L3
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip9L3
    ld (de),a
.PrnSprSkip9L3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip10L3
    ld (de),a
.PrnSprSkip10L3
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip11L3
    ld (de),a
.PrnSprSkip11L3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip12L3
    ld (de),a
.PrnSprSkip12L3
    inc l
;
    djnz PrnSprLoopL3
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
;
    inc l
;
    inc l
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip16L3
    ld (de),a
.PrnSprSkip16L3
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip17L3
    ld (de),a
.PrnSprSkip17L3
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip18L3
    ld (de),a
.PrnSprSkip18L3
    jp PrnSprPartialReturn

.PrnSprLeft2
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLL2
    set 7,l
.PrnSprDontIncLL2
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopL2
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip9L2
    ld (de),a
.PrnSprSkip9L2
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip10L2
    ld (de),a
.PrnSprSkip10L2
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip11L2
    ld (de),a
.PrnSprSkip11L2
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip12L2
    ld (de),a
.PrnSprSkip12L2
    inc l
;
    djnz PrnSprLoopL2
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    inc l
;
    inc l
;
    inc l
;
    inc l
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip17L2
    ld (de),a
.PrnSprSkip17L2
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip18L2
    ld (de),a
.PrnSprSkip18L2
    jp PrnSprPartialReturn

.PrnSprOnRightEdge
    or a
    jp z,PrnSprRight5
    dec a
    jp z,PrnSprRight4
    dec a
    jp z,PrnSprRight3
    dec a
    jp z,PrnSprRight2
    dec a
    jp nz,PrnSprSkipSprite ; if sprite so far right is offscreen or unused, simply skip the sprite
; assume print one column of sprite on right
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLR1
    set 7,l
.PrnSprDontIncLR1
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopR1
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    set 3,d
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip1R1
    ld (de),a
.PrnSprSkip1R1
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip2R1
    ld (de),a
.PrnSprSkip2R1
    inc de
    set 3,d
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    djnz PrnSprLoopR1
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip13R1
    ld (de),a
.PrnSprSkip13R1
    jp PrnSprPartialReturn

.PrnSprRight5
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLR5
    set 7,l
.PrnSprDontIncLR5
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopR5
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    set 3,d
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip1R5
    ld (de),a
.PrnSprSkip1R5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip2R5
    ld (de),a
.PrnSprSkip2R5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip3R5
    ld (de),a
.PrnSprSkip3R5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip4R5
    ld (de),a
.PrnSprSkip4R5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip5R5
    ld (de),a
.PrnSprSkip5R5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip6R5
    ld (de),a
.PrnSprSkip6R5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip7R5
    ld (de),a
.PrnSprSkip7R5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip8R5
    ld (de),a
.PrnSprSkip8R5
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip9R5
    ld (de),a
.PrnSprSkip9R5
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip10R5
    ld (de),a
.PrnSprSkip10R5
    inc l
;
    inc l
    inc l
;
    djnz PrnSprLoopR5
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip13R5
    ld (de),a
.PrnSprSkip13R5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip14R5
    ld (de),a
.PrnSprSkip14R5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip15R5
    ld (de),a
.PrnSprSkip15R5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip16R5
    ld (de),a
.PrnSprSkip16R5
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip17R5
    ld (de),a
.PrnSprSkip17R5
    jp PrnSprPartialReturn

.PrnSprRight4
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLR4
    set 7,l
.PrnSprDontIncLR4
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopR4
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    set 3,d
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip1R4
    ld (de),a
.PrnSprSkip1R4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip2R4
    ld (de),a
.PrnSprSkip2R4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip3R4
    ld (de),a
.PrnSprSkip3R4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip4R4
    ld (de),a
.PrnSprSkip4R4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip5R4
    ld (de),a
.PrnSprSkip5R4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip6R4
    ld (de),a
.PrnSprSkip6R4
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip7R4
    ld (de),a
.PrnSprSkip7R4
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip8R4
    ld (de),a
.PrnSprSkip8R4
    inc de
    set 3,d
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    djnz PrnSprLoopR4
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip13R4
    ld (de),a
.PrnSprSkip13R4
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip14R4
    ld (de),a
.PrnSprSkip14R4
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip15R4
    ld (de),a
.PrnSprSkip15R4
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip16R4
    ld (de),a
.PrnSprSkip16R4
    jp PrnSprPartialReturn

.PrnSprRight3
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLR3
    set 7,l
.PrnSprDontIncLR3
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopR3
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    set 3,d
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip1R3
    ld (de),a
.PrnSprSkip1R3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip2R3
    ld (de),a
.PrnSprSkip2R3
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip3R3
    ld (de),a
.PrnSprSkip3R3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip4R3
    ld (de),a
.PrnSprSkip4R3
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip5R3
    ld (de),a
.PrnSprSkip5R3
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip6R3
    ld (de),a
.PrnSprSkip6R3
    inc de
    set 3,d
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    djnz PrnSprLoopR3
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip13R3
    ld (de),a
.PrnSprSkip13R3
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip14R3
    ld (de),a
.PrnSprSkip14R3
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip15R3
    ld (de),a
.PrnSprSkip15R3
    jp PrnSprPartialReturn

.PrnSprRight2
    ld a,c
    exx
    ld l,0
    srl a
    jr nc,PrnSprDontIncLR2
    set 7,l
.PrnSprDontIncLR2
    add a,&40
    ld h,a
    ld b,10
.PrnSprLoopR2
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    set 3,d
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip1R2
    ld (de),a
.PrnSprSkip1R2
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip2R2
    ld (de),a
.PrnSprSkip2R2
    inc de
    set 3,d
    inc l
;
    ld a,(hl)
    or a
    jr z,PrnSprSkip3R2
    ld (de),a
.PrnSprSkip3R2
    res 3,d
    inc l
    ld a,(hl)
    or a
    jr z,PrnSprSkip4R2
    ld (de),a
.PrnSprSkip4R2
    inc de
    set 3,d
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    inc l
    inc l
;
    djnz PrnSprLoopR2
;
    ld e,(ix+0)
    inc ixl
    ld d,(ix+0)
    inc ixl
;
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
    res 3,d
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip13R2
    ld (de),a
.PrnSprSkip13R2
    inc l
    inc de
;
    res 3,d
    ld a,(hl)
    or a
    jr z,PrnSprSkip14R2
    ld (de),a
.PrnSprSkip14R2
    jp PrnSprPartialReturn
