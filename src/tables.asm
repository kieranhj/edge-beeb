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

\ coll_map row bases. The map is 800 bytes and crosses pages, so the
\ read is (ptr),Y with the column in Y. The state these serve moved to
\ &0800 with the rest of the game's - see main.asm.
.coll_row_lo
FOR n,0,COLL_ROWS-1,1
    EQUB LO(coll_map + n*COLL_COLS)
NEXT
.coll_row_hi
FOR n,0,COLL_ROWS-1,1
    EQUB HI(coll_map + n*COLL_COLS)
NEXT

.data_end
