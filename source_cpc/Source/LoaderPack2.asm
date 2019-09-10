nolist
org &8000
run &8000
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

; experiment
    ld hl,(&be7d)
    ld a,(hl)
    ld (drive+1),a
;
    ld c,&ff
    ld hl,startldr
    call &bd16
.startldr
;    call &bccb
    ld c,7
    call &bcce
.drive
    ld a,0
    ld hl,(&be7d)
    ld (hl),a
; needed above?

; set mode 0
    ld a,0
    call &bc0e
; set border black
    ld bc,0
    call &bc38
; set loader colours
    ld hl,LoaderCols+15
    ld a,15
    call SetColours
; load loading screen
    ld b,CodeFN-LoadScrFN
    ld hl,LoadScrFN
    ld de,&4000
    call LoadFile
    ld hl,&4000
    ld de,&c000
    call depackINT
; set loader colours
    ld hl,LoadScrCols+15
    ld a,15
    call SetColours

; load code file
    ld b,EndFN-CodeFN
    ld hl,CodeFN
    ld de,&100
    call LoadFile

; strobe loc &100 len 5395
; cs loc 5651 len 2362
; sprites loc 8013 len 6387
; bg loc 14400 len 6517
; code loc 20917 len 10168

; disable firmware
    di
    ld hl,#c9fb
    ld (#38),hl
    ei

; copy code to after loader
    ld hl,20917
    ld de,&8400
    ld bc,10168
    ldir

; decompress bg/map bank to &c1/7
    ld bc,&7fc1
    out (c),c
    ld hl,14400
    ld de,&c000
    call depackINT
; fade colours
    ld hl,Fade1Cols+15
    call SetColoursHW

; decompress strobe sprite bank block
    ld bc,&7fc4
    out (c),c
    ld hl,&100
    ld de,&4000
    call depackINT
; fade colours
    ld hl,Fade2Cols+15
    call SetColoursHW

; decompress compiled sprite block
    ld bc,&7fc5
    out (c),c
    ld hl,5651
    ld de,&4000
    call depackINT
; fade colours
    ld hl,Fade3Cols+15
    call SetColoursHW

; decompress sprite bank block
    ld bc,&7fc6
    out (c),c
    ld hl,8013
    ld de,&4000
    call depackINT
; fade colours
    ld hl,Fade4Cols+15
    call SetColoursHW

; decompress code file
    ld bc,&7fc0
    out (c),c
    ld hl,&8400
    ld de,&d0
    call depackINT
; clear title screen so it does not appear in wrong colours
    ld hl,&c000
    ld (hl),0
    ld de,&c001
    ld bc,&3fff
    ldir
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
    dec hl
    cp a,0
    ret z
    dec a
    jr SetColours

.SetColoursHW
    ld bc,&7F10
    xor a
.SetColLp
; HL points to list
    ld d,(hl)
    dec c
    out (c),c
    out (c),d
    dec hl
    cp a,c
    ret z
    jr SetColLp

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

.AbortLoading
; set mode 0
    ld a,1
    call &bc0e
; set border black
    ld bc,0
    call &bc38
; set loader colours
    ld hl,ErrorCols+3
    ld a,3
    call SetColours
; print messages
    ld hl,&f08
    call &bb75
    ld a,1
    call &bb90
    ld a,0
    call &bb96
    ld hl,Edition
    call PrintMsgLp
    ld hl,&40e
    call &bb75
    ld hl,WontLoadMsg
    call PrintMsgLp
    ld hl,&1412
    call &bb75
    ld a,2
    call &bb90
    ld hl,BooHoo
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
;    defb 6,14,26,0
    defb 0,26,14,6
.LoaderCols
    defb 0,0,0,0
    defb 0,0,0,0
    defb 0,0,0,0
    defb 0,0,0,0
.LoadScrCols
;    defb 26,20,2,16,17,11,10,4
;    defb 1,24,9,6,18,15,3,0
    defb 0,3,15,18,6,9,24,1
    defb 4,10,11,17,16,2,20,26

.Fade1Cols
    defb &54,&5c,&4c,&56,&5c,&5c,&4e,&44
    defb &58,&5d,&55,&4d,&45,&44,&5f,&5b
.Fade2Cols
    defb &54,&54,&44,&5c,&54,&54,&4c,&54
    defb &54,&44,&54,&58,&5c,&54,&5d,&57
.Fade3Cols
    defb &54,&54,&54,&54,&54,&54,&5c,&54
    defb &54,&54,&54,&54,&54,&54,&44,&55
.Fade4Cols
    defb &54,&54,&54,&54,&54,&54,&54,&54
    defb &54,&54,&54,&54,&54,&54,&54,&54
.dummy
.LoadScrFN
    text "LOADSCR.BIN"
.CodeFN
    text "EDGEPCK.BIN"
.EndFN

.BooHoo
    defb 225,0
.Edition
    Text "EDGE GRINDER",0
.WontLoadMsg
    text "64K System detected. 128K required.",0
.EndLoader

read "bitbust_ldr.asm"