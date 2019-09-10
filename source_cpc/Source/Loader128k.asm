nolist
org &a000
run &a000
write direct "a:disc.bin"

; check system memory
    ld hl,&4000
    xor a
    ld (hl),a
; now do bank switch
    ld bc,&7fc7
    out (c),c
    inc a
    ld (hl),a
    ld bc,&7fc0
    out (c),c
    ld a,(hl)
    or a
    jp nz,AbortLoading
;
    ld hl,(&be7d)
    ld a,(hl)
    ld (drive+1),a
;
    ld c,&ff
    ld hl,startldr
    call &bd16
.startldr
    ld c,7
    call &bcce
.drive
    ld a,0
    ld hl,(&be7d)
    ld (hl),a

; set mode 0
    ld a,0
    call &bc0e
; set border black
    ld bc,0
    call &bc38
; set loader colours
    ld hl,LoaderCols
    ld a,15
    call SetColours
; load loading screen
    ld b,SprFN-LoadScrTFN
    ld hl,LoadScrTFN
    ld de,&4000
    call LoadFile
    ld hl,&4000
    ld de,&c000
    call depackINT
; set loader colours
    ld hl,LoadScrCols
    ld a,15
    call SetColours

; load bank 1 file
;    ld bc,&7fc5
;    out (c),c
;    ld b,Bank2FN-Bank1FN
;    ld hl,Bank1FN
;    ld de,&2000
;    call LoadFile
;    ld bc,&7fc4
;    out (c),c
;    call JoinBank

; load bank 2 file
;    ld bc,&7fc7
;    out (c),c
;    ld b,CodeFN-Bank2FN
;    ld hl,Bank2FN
;    ld de,&2000
;    call LoadFile
;    ld bc,&7fc6
;    out (c),c
;    call JoinBank

; load strobe sprite bank block
    ld bc,&7fc4
    out (c),c
    ld b,LoadScrFN-SprFN
    ld hl,SprFN
    ld de,&4000
    call LoadFile
    ld bc,&7fc0
    out (c),c

; load sprite bank block
    ld bc,&7fc6
    out (c),c
    ld b,Bank1FN-LoadScrFN
    ld hl,LoadScrFN
    ld de,&4000
    call LoadFile
    ld bc,&7fc0
    out (c),c

; load compiled sprite block
    ld bc,&7fc5
    out (c),c
    ld b,Bank2FN-Bank1FN
    ld hl,Bank1FN
    ld de,&4000
    call LoadFile
    ld bc,&7fc0
    out (c),c

; load map block
    ld bc,&7fc7
    out (c),c
    ld b,CodeFN-Bank2FN
    ld hl,Bank2FN
    ld de,&4000
    call LoadFile
    ld bc,&7fc0
    out (c),c

; load code file
;    ld bc,&7fc0
;    out (c),c
    ld b,EndFN-CodeFN
    ld hl,CodeFN
    ld de,&d0
    call LoadFile
; go to game
    jp &155

.SetColours
; HL points to list, A holds 15 or 3

    ld b,(hl)
    ld c,b
    push af
    push hl
    call &bc32
    pop hl
    pop af
    inc hl
    cp a,0
    ret z
    dec a
    jr SetColours

; load a file
.LoadFile
; B has filename length, HL points to
; filename, DE location to load file

    push de
;    ld de,&5000
    ld de,&9000
    call &bc77
    pop hl
    call &bc83
    call &bc7a
    ret

; Put split bank together
.JoinBank
; split loaded bank
    ld hl,&2000
    ld de,&4000
    ld bc,&2000
    ldir
    ld hl,&8000
    ld bc,&2000
    ldir
    ret

.AbortLoading
; set mode 0
    ld a,1
    call &bc0e
; set border black
    ld bc,0
    call &bc38
; set loader colours
    ld hl,ErrorCols
    ld a,3
    call SetColours
; print messages
    ld hl,&30a
    call &bb75
    ld a,2
    call &bb96
    ld hl,SabreLine1
    call PrintMsgLp
    ld hl,&30b
    call &bb75
    ld a,1
    call &bb90
    ld hl,SabreLine2
    call PrintMsgLp
    ld hl,&30c
    call &bb75
    ld a,1
    call &bb96
    ld hl,SabreLine3
    call PrintMsgLp
    ld hl,&50d
    call &bb75
    ld a,3
    call &bb96
    ld hl,SabreLine4
    call PrintMsgLp
    ld hl,&30e
    call &bb75
    ld hl,SabreLine5
    call PrintMsgLp
    ld hl,&f10
    call &bb75
    ld a,0
    call &bb96
    ld hl,Edition
    call PrintMsgLp
    ld hl,&416
    call &bb75
    ld hl,WontLoadMsg
    call PrintMsgLp
    call &bb18
    ret

.PrintMsgLp
    ld a,(hl)
    or a
    ret z
    call &bb5a
    inc hl
    jr PrintMsgLp

.ErrorCols
    defb 6,14,26,0
.LoaderCols
    defb 0,0,0,0
    defb 0,0,0,0
    defb 0,0,0,0
    defb 0,0,0,0
.LoadScrCols
;    defb 16,26,24,13,23,14,15,10
;    defb 5,7,3,1,6,4,0,2
;    defb 0,13,26,3,16,25,9,22
;    defb 23,10,1,2,4,17,6,14
    defb 26,20,2,16,17,11,10,4
    defb 1,24,9,6,18,15,3,0
.dummy
.LoadScrTFN
    text "LOADSCR.BIN"
.SprFN
    text "SPRITESS.BIN"
.LoadScrFN
    text "SPRITES.BIN"
.Bank1FN
    text "CS.BIN" ;;"CSTITLE.BIN"
.Bank2FN
    text "BG.BIN"
.CodeFN
    text "CODE.BIN"
.EndFN
.SabreLine1
    defb 32,32,32,9,32,32,32,9,9,32,9,9,32,32,9,9,9,32,32,32,9,9,32,9,9,32,32,9,9,32,32,9,9,32,32,32,0
.SabreLine2
    defb 127,9,9,9,9,127,9,9,127,9,127,9,127,9,127,9,9,127,9,9,9,127,9,127,9,127,9,127,9,127,9,127,9,127,0
.SabreLine3
    defb 32,32,32,9,9,32,9,9,32,32,32,9,32,32,9,9,9,32,32,32,9,32,32,32,9,32,32,9,9,32,32,9,9,32,32,0
.SabreLine4
    defb 127,9,9,127,9,9,127,9,127,9,127,9,127,9,9,9,9,127,9,127,9,127,9,127,9,127,9,127,9,127,9,127,0
.SabreLine5
    defb 32,32,32,9,9,32,9,9,32,9,32,9,32,9,32,9,9,32,32,32,9,32,9,32,9,32,32,9,9,32,9,32,9,32,32,32,0
.Edition
    Text "128K Edition",0
.WontLoadMsg
    text "64K System detected. 128K required.",0
.EndLoader

read "bitbust_ldr.asm"