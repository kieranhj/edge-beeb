\ ******************************************************************
\ *	tables.asm
\ *	Main-RAM data: OSFILE block, multiply tables, C64->MODE 2 pixel tables, stashes.
\ ******************************************************************

.code_end

\ ******************************************************************
\ *	DATA
\ ******************************************************************

.data_start

.loadsc1_filename EQUS "LoadSc1",13
.loadsc2_filename EQUS "LoadSc2",13
.bank0_filename EQUS "Bank0",13
.bank1_filename EQUS "Bank1",13
.bank2_filename EQUS "Bank2",13
.bank3_filename EQUS "Bank3",13
.panel_filename EQUS "Panel",13
.andy_filename EQUS "Andy",13
.music_filename EQUS "Music",13

\ The C64's player explosion direction vectors, verbatim. Movement
\ commands in emove's encoding, one pair per pool slot; life_lost reads
\ from +2*ENEMY_FIRST, so the first four bytes are never used - they are
\ the player's and bullet's slots, which have no pieces to throw.
.explosion_dirs
EQUB &00,&00,&02,&03,&19,&09,&44,&44
EQUB &22,&22,&8a,&8a,&45,&45,&26,&26

.osfile_params
.osfile_nameaddr
EQUW loadsc1_filename
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
