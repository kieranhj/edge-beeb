.Copy_Buffer
; enter with hl pointing to target screen column address to write
    ld bc,&4f60 ; start position of 160 byte buffer for current column to write to screen
    ld de,80 - #2000 ; last pixel line written is line 5, +&2000 from line 1
                     ; so next char lines pixel line 1 is 80-&2000 away
    ld a,20 ; screen is 20 chars high
.CopyColLp
    ex af,af'
    ld a,(bc):inc c
    ld (hl),a:set 3,h ; copy line 1
    ld a,(bc):inc c
    ld (hl),a:set 4,h ; copy line 2
    ld a,(bc):inc c
    ld (hl),a:res 3,h ; copy line 4
    ld a,(bc):inc c
    ld (hl),a:set 5,h ; copy line 3
    ld a,(bc):inc c
    ld (hl),a:set 3,h ; copy line 7
    ld a,(bc):inc c
    ld (hl),a:res 4,h ; copy line 8
    ld a,(bc):inc c
    ld (hl),a:res 3,h ; copy line 6
    ld a,(bc):inc c
    ld (hl),a ;         copy line 5
    add hl,de:res 3,h ; go to top of next character line
    ex af,af'
    dec a
    jr nz,CopyColLp
    ret

.Fill_Buffer
    ld a,(scroll_step)
    dec a ; get scroll step & dec.  Was incremented by interrupt prior to first frame
    ld ix,LowCharWrite
    bit 0,a ; determine whether to use right or left pixels this frame
    jr nz,SkipHighCharWriteSet
    ld ix,HighCharWrite
.SkipHighCharWriteSet
    ld c,a ; save scroll_step
    and a,&c
    add a,&50 ; character columns in tiles start at &5000, &5400, &5800 & &5c00
    ld (FillBufTileLp+1),a ; write high byte to loop later in routine
    ld a,c ; retrieve scroll step
    exx
    ld de,&4f60 ; set de' to start of vertical column buffer
    ld h,&60 ; depending on stage, want left or right byte of each character
    bit 1,a
    jr z,FillBufFirstHalf ; left bytes start at &6000
    set 3,h ; right bytes start at &6800
.FillBufFirstHalf
    ld a,h
    ld (FillBufCharHalf+1),a ; write high byte to loop later in routine
    exx
    ld de,(MapPointer) ; get pointer to tile column to display
    ld b,5 ; each column is 5 tiles
.FillBufTileLp
    ld h,&50 ; this high byte tile pointer was pre determined above
    ld a,(de) ; get tile number from tile pointer
    ld l,a ; put tile in l so hl points to character list in tile
    ld c,4 ; each tile is 4 characters high
.FillBufCharLp
    ld a,(hl) ; get character from tile pointer
    exx ; switch to alternate registers
    ld l,a ; put character number in low byte of tile pointer
.FillBufCharHalf
    ld h,&60 ; this high byte char pointer was pre determined above
    jp (ix) ; shift left or right pixel of character bytes into the buffer
.FillBufCharRet
    exx
    inc h ; point to next character in tile
    dec c
    jr nz,FillBufCharLp ; do all 4 characters of tile
    inc de ; point to next tile
    djnz FillBufTileLp ; do all 5 characters of screen column
    ret

.LowCharWrite
; this routine shifts the right pixel of a given character byte into the buffer
    ld c,85 ; right pixel mask
    ld a,4 ; each character is a column of 8 bytes, handled in pairs
.LowChrWrlp
    ex af,af' ;1 - save counter
    ld a,(hl) ;2 - get right pixel from byte
    and a,c   ;1 - mask out left pixel
    ld b,a    ;1 - save result in b
    ld a,(de) ;2 - get current byte from buffer
    and a,c   ;1 - mask out left pixel
    rlca      ;1 - shift previously right pixel to left
    or a,b    ;1 - add new right pixel to buffer byte
    ld (de),a ;2 - write back to buffer
    inc h     ;1 - point to next byte in character
    inc e     ;1 - and next byte in buffer

    ld a,(hl) ;2 - get byte with next right pixel
    rrca      ;1 - even bytes stored swapped, so shift left pixel to right
    and a,c   ;1 - and mask out left pixel data
    ld b,a    ;1 - store result in b
    ld a,(de) ;2 - get current byte from buffer
    and a,c   ;1 - mask out left pixel
    rlca      ;1 - shift previously right pixel to left
    or a,b    ;1 - add new right pixel to buffer byte
    ld (de),a ;2 - write back to buffer
    inc h     ;1 - point to next byte in character
    inc e     ;1 - and next byte in buffer

    ex af,af' ;1 - get counter back
    dec a     ;1 - repeat for all 4 byte pairs
    jr nz,LowChrWrlp  ;2/3 - 33*4-1 = 131 per character, so around 41 scan lines for a whole column
    jp FillBufCharRet ; return to main loop

.HighCharWrite
; this routine shifts the left pixel of a given character byte into the buffer
    ld c,85 ; right pixel mask
    ld a,4 ; each character is a column of 8 bytes, handled in pairs
.HighChrWrlp
    ex af,af' ;1 - save counter
    ld a,(hl) ;2 - get left pixel from byte
    rrca      ;1 - shift the left pixel to the right of the byte
    and a,c   ;1 - and mask out left pixel data
    ld b,a    ;1 - save result in b
    ld a,(de) ;2 - get current byte from buffer
    and a,c   ;1 - mask out left pixel
    rlca      ;1 - shift previously right pixel to left
    or a,b    ;1 - add new right pixel to buffer byte
    ld (de),a ;2 - write back to buffer
    inc h     ;1 - point to next byte in character
    inc e     ;1 - and next byte in buffer

    ld a,(hl) ;2 - get byte with next left pixel
    and a,c   ;1 - even bytes are swapped, left pixel is already right, so mask out left pixel
    ld b,a    ;1 - save result in b
    ld a,(de) ;2 - get current byte from buffer
    and a,c   ;1 - mask out left pixel
    rlca      ;1 - shift previously right pixel to left
    or a,b    ;1 - add new right pixel to buffer byte
    ld (de),a ;2 - write back to buffer
    inc h     ;1 - point to next byte in character
    inc e     ;1 - and next byte in buffer

    ex af,af' ;1 - get counter back
    dec a     ;1 - repeat for all 4 byte pairs
    jr nz,HighChrWrlp  ;2/3 - 33*4-1 = 131 per character, so around 41 scan lines for a whole column
    jp FillBufCharRet ; return to main loop

.ProcessMapPointer
    ld a,(scroll_step)
    dec a ; interupt has progressed scroll_step to 1 for first frame, so do test on scroll_step minus one
    and a,&f ; want new column of tiles every 4 characters, or 16 pixels
    ret nz
    ld hl,(MapPointer) ; if scroll_step-1 = 0, move to next row of tiles
    ld de,5 ; there are 5 tiles per column
    add hl,de
    ld a,(hl) ; for testing purposes, allowed loop of level data
    cp a,255 ; if tile 255 is first tile
    jr nz,DontResetMapPtr
    ld hl,Map+40 ; reset the map pointer
.DontResetMapPtr
    ld (MapPointer),hl ; write tile pointer back
    ret

