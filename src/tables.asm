\ ******************************************************************
\ *	tables.asm
\ *	Main-RAM data: OSFILE block, multiply tables, C64->MODE 2 pixel tables, stashes.
\ ******************************************************************

.code_end

\ ******************************************************************
\ *	DATA
\ ******************************************************************

.data_start

.bank0_filename EQUS "Bank0",13

.osfile_params
.osfile_nameaddr
EQUW bank0_filename
; file load address
.osfile_loadaddr
EQUD &4000
; file exec address
.osfile_execaddr
EQUD 0
; start address or length
.osfile_length
EQUD 0
; end address of attributes
.osfile_endaddr
EQUD 0

.mult8_LO
FOR n,0,79,1
    EQUB LO(n*8)
NEXT

.mult8_HI
FOR n,0,79,1
    EQUB HI(n*8)
NEXT

.mult640_LO
FOR n,0,31,1
    EQUB LO(n*640)
NEXT

.mult640_HI
FOR n,0,31,1
    EQUB HI(n*640)
NEXT

.map_c64_nibble_to_mask
FOR p,0,15,1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1
    p2=(C*2)+c:p3=(D*2)+d

    IF p2=0
        lp=&AA
    ELSE
        lp=0
    ENDIF

    IF p3=0
        rp=&55
    ELSE
        rp=0
    ENDIF

    EQUB lp OR rp

\\ 0->transparent
\\ 1->black
\\ 2->sprite colour
\\ 3->white
NEXT

.map_c64_nibble_to_mode2
FOR p,0,15,1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1
    p2=(C*2)+c:p3=(D*2)+d

    IF p2=3
        lp=SPRITE_PIX_3 AND MODE2_PIXEL_LEFT_MASK
    ELIF p2=2
        lp=SPRITE_PIX_2 AND MODE2_PIXEL_LEFT_MASK
    ELIF p2=1
        lp=SPRITE_PIX_1 AND MODE2_PIXEL_LEFT_MASK
    ELSE
        lp=SPRITE_PIX_0 AND MODE2_PIXEL_LEFT_MASK
    ENDIF

    IF p3=3
        rp=SPRITE_PIX_3 AND MODE2_PIXEL_RIGHT_MASK
    ELIF p3=2
        rp=SPRITE_PIX_2 AND MODE2_PIXEL_RIGHT_MASK
    ELIF p3=1
        rp=SPRITE_PIX_1 AND MODE2_PIXEL_RIGHT_MASK
    ELSE
        rp=SPRITE_PIX_0 AND MODE2_PIXEL_RIGHT_MASK
    ENDIF

    EQUB lp OR rp

\\ 0->transparent
\\ 1->black
\\ 2->sprite colour
\\ 3->white
NEXT

PAGE_ALIGN
.background_stash_0
skip 126

PAGE_ALIGN
.background_stash_1
skip 126

PAGE_ALIGN
.map_c64_to_beeb_p0
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p0
NEXT

PAGE_ALIGN
.map_c64_to_beeb_p1
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p1
NEXT

PAGE_ALIGN
.map_c64_to_beeb_p2
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p2
NEXT

PAGE_ALIGN
.map_c64_to_beeb_p3
FOR p,0,255,1
    A=(p>>7)AND1:a=(p>>6)AND1:B=(p>>5)AND1:b=(p>>4)AND1
    C=(p>>3)AND1:c=(p>>2)AND1:D=(p>>1)AND1:d=(p>>0)AND1

    p0=(A*2)+a:p1=(B*2)+b:p2=(C*2)+c:p3=(D*2)+d

    BG_PIXEL p3
NEXT

PAGE_ALIGN
.sprite_addr_LO
FOR n,0,sprite_total-1,1
    EQUB LO(sprite_data + n*sprite_stride)
NEXT

.sprite_addr_HI
FOR n,0,sprite_total-1,1
    EQUB HI(sprite_data + n*sprite_stride)
NEXT

.data_end
