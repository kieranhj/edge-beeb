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
.bank1_filename EQUS "Bank1",13
.bank2_filename EQUS "Bank2",13

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

\ ******************************************************************
\ *	Sprite engine state (Layer 3). The first four are the C64's own
\ *	tables at $0360-$037F, same layout, same meaning: an x,y pair per
\ *	sprite, the sprite_dp_dcd index, and the hit-flash countdown. The
\ *	spr_sv_* arrays are ours - what the last draw into each BANK did,
\ *	indexed bank*8 + slot, so the restore can replay it.
\ ******************************************************************

.sprite_pos     skip 2*SPR_SLOTS
.sprite_dp      skip SPR_SLOTS
.sprite_pls_tmr skip SPR_SLOTS

.spr_sv_on      skip 2*SPR_SLOTS    ; 0 = nothing saved for this slot/bank
.spr_sv_lo      skip 2*SPR_SLOTS    ; where the draw started
.spr_sv_hi      skip 2*SPR_SLOTS
.spr_sv_scan    skip 2*SPR_SLOTS    ; and at which scanline
.spr_sv_rows    skip 2*SPR_SLOTS    ; rows and columns it actually covered
.spr_sv_cols    skip 2*SPR_SLOTS
.spr_sv_wrap    skip 2*SPR_SLOTS    ; and whether it walked bufp per column

.data_end
