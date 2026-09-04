\ ******************************************************************
\ * sim_akl.asm - src/aklplayer.asm and src/ay2sn.asm, standalone,
\ * for tools/akl/verify_akl.py to run in a 6502 simulator.
\ *
\ * It INCLUDEs the REAL sources, not copies, so what is verified is
\ * what ships. Assemble from the PROJECT ROOT, because the players'
\ * own INCLUDEs are written relative to it:
\ *
\ *   beebasm -i tools/akl/sim_akl.asm -d -labels tools/akl/build/labels.txt
\ *
\ * The zero page block below is main.asm's `IF MUSIC_AKL` branch; if
\ * one gains a variable the other must too, and verify_akl.py will fail
\ * loudly rather than quietly if they drift, because the player will
\ * not assemble.
\ ******************************************************************

ORG &70
.ptr        skip 2
.iptr       skip 2
.tptr       skip 2
.cell       skip 1
.iofs       skip 1
.per        skip 2
.tmp        skip 2
.mixer      skip 1
.akl_tick   skip 1
.akl_speed  skip 1
.akl_height skip 1
.akl_prevh  skip 1
.lnk        skip 2
.jvec       skip 2

ORG &1100
GUARD &3f00
.start

INCLUDE "src/aklplayer.asm"
INCLUDE "src/ay2sn.asm"

\ One frame of music, exactly as src/music.asm defines it for the game.
.akl_frame
{
    jsr akl_play
    jmp ay2sn
}
.all_end

ORG SIM_SONG
.song_data
INCBIN "tools/akl/build/song.akl"
.song_end

SAVE "tools/akl/build/Akl", start, song_end, start
