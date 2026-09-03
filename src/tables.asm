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
.bank3_filename EQUS "Bank3",13

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

.data_end
