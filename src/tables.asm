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

\ explosion_dirs USED TO BE HERE AND MUST NOT COME BACK. Everything in
\ this section sits above SPR_SAVE's base and is therefore boot-only:
\ the filenames and the OSFILE block are read while the disc is being
\ loaded and never again, which is the same licence src/zx0depack.asm
\ has. The explosion vectors are read every time the player dies, so
\ they were being served out of the blitter's save area; they are in
\ bank 1 now, with the loop that reads them. See the ASSERT on
\ code_end in main.asm.

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
