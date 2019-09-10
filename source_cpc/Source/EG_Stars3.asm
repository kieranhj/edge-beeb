.ClearStars
; select table of star addresses for high or low screen depending on current
; working screen and point to with hl
    ld a,(base_addr+1)
    bit 6,a
    jr z,StarClearLow
    ld hl,StarsHigh
    jr StarClearSkipLow
.StarClearLow
    ld hl,StarsLow
.StarClearSkipLow
    ld bc,&a0a ; c = star byte
; there are 10 stars, 5 are displayed dark green, 5 light green
; every 2 frames they are swapped between dark/light green in time with
; h-sync change, which will reduce visible impact of R3 effect on monitors
; that do not shift the screen precisely half a character
    ld a,(scroll_step)
    dec a ; the scroll step is incremented after use in the interupt
    bit 1,a ; so a dec is required to synchronise with R3 change
    jr z,StarClearLp
    ld a,42 ; the byte for light green star is &a, dark green is &20
    xor a,c
    ld c,a
;
.StarClearLp
; get address of star into de
    ld e,(hl)
    inc l
    ld d,(hl)
    inc l ; and point to next star address
    ld a,(de)
    cp a,c ; if it does not contain a star byte
    jr nz,DontClearStar ; then leave it be
    xor a
    ld (de),a ; otherwise clear it
.DontClearStar
    ld a,6
    cp a,b ; if not halfway through the stars
    jr nz,StarClrDontInvert ; continue with loop
    ld a,42 ; otherwise invert the star byte in c
    xor a,c
    ld c,a
.StarClrDontInvert
    djnz StarClearLp
    ret

PrintStars
; select table of star addresses for high or low screen depending on current
; working screen and point to with hl
    ld a,(base_addr+1)
    bit 6,a
    jr z,StarPrnLow
    ld hl,StarsHigh
    jr StarPrnSkipLow
.StarPrnLow
    ld hl,StarsLow
.StarPrnSkipLow
    ld bc,&a0a ; c = star byte
; there are 10 stars, 5 are displayed dark green, 5 light green
; every 2 frames they are swapped between dark/light green in time with
; h-sync change, which will reduce visible impact of R3 effect on monitors
; that do not shift the screen precisely half a character
    ld a,(scroll_step)
    dec a ; the scroll step is incremented after use in the interupt
    bit 1,a ; so a dec is required to synchronise with R3 change
    jr nz,StarPrnLp
    ld a,42 ; the byte for light green star is &a, dark green is &20
    xor a,c
    ld c,a
;
.StarPrnLp
; get address of star into de
    ld e,(hl)
    inc l
    ld d,(hl)
    dec l
; increment the address to move star against the scroll, star will appear static
    inc de
    res 3,d ; ensure star remains on same scan line if crossed address reset point
; write address back to table pointed to by hl
    ld (hl),e
    inc l
    ld (hl),d
    inc l ; and point to next star address
    ld a,(de) ; check byte at current star address
    or a ; if byte is not blank
    jr nz,DontPrnStar ; dont print a star
    ld a,c ; otherwise, put current star byte at address
    ld (de),a
.DontPrnStar
    ld a,6
    cp a,b ; if not halfway through the stars
    jr nz,StarPrnDontInvert ; continue with loop
    ld a,42 ; otherwise invert the star byte in c
    xor a,c
    ld c,a
.StarPrnDontInvert
    djnz StarPrnLp
    ret
