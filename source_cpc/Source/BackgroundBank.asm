nolist

scroll_step equ &11c

org &4000
write direct "a:BG.bin"

read "Block_Writer4.asm"

.MapPointer
    defw Map+40
; the C64 level map data, formatted for use on CPC
read "EG_Map_Formatted.asm"
defb 255 ; end map
list
.EndCode
defs &93e
.StartTiles
nolist
; the C64 tile (4x4) data, formatted for use on CPC
read "EG_Tiles_Formatted.asm"
; the 256 background characters
read "char_graphic5.asm"
