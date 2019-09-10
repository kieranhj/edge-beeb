org &d0
run start
write direct "a:edgegrnd.bin"
nolist
SpritesYX equ &40
SpritesYXMv equ &50
KeyInY equ &50+12
SpriteData equ &60
StarsLow equ &90
StarsHigh equ &a4

ProcessMapPointer equ &40bf
Copy_Buffer equ &4000
Fill_Buffer equ &4037
Map equ &40db
MapPointer equ &40d9

PrintCredits equ &498c ;fc8c
wave_data equ &63bd

ZoomScrollMsg equ &5140

SpriteAddrHigh equ &3e00+48
SpriteAddrLow equ &3f00+48
SpriteBufHigh equ &7400
SpriteBufLow equ &7c00

; sprite id table, starting at &d0
; for each of 16 sprite id's, define base frame, animation type and data
.SpriteLookup
    defb 19,192,1 ; sprite 1
    defb 24,64,6 ; sprite 2
    defb 30,64,4 ; sprite 3
    defb 34,128,1 ; sprite 4
    defb 40,64,6 ; sprite 5
    defb 46,64,6 ; sprite 6
    defb 52,64,6 ; sprite 7
    defb 58,64,7 ; sprite 8
    defb 65,64,6 ; sprite 9
    defb 71,64,6 ; sprite 10
    defb 77,64,8 ; sprite 11
    defb 85,64,8 ; sprite 12
    defb 93,64,8 ; sprite 13
    defb 101,64,6 ; sprite 14
    defb 107,64,6 ; sprite 15
    defb 113,64,6 ; sprite 16

; key reading buffer at &100
.KBmatrixbuf
defs 10

; old test code, unused!
.MoveDown
    ld hl,&5000
    ld de,&100
    ld bc,EndEG-&100
    ldir
    jp start

.base_addr ; current screen base address
dw &c000

.paint_addr ; current screen background column
dw #c04d

.scroll_step ; pointer for stage of tile writer
db 0

.scroll ; tells interrupt to advance a frame
db 0

; variables used for display of title screens two 'zoom scrolls'
.ZSCharPtr
    defw ZoomScrollMsg-1
.ZSCharCol
    defb 7
.HighZoomScrlOffset
    defw 0
.LowZoomScrlOffset
    defw 0

; screen address reset position in sprite co-ordinates
.ResetYX
defb 232,16+48
; each bit of these bytes indicate when a sprite has overlapped the reset point
.ResetHigh
defb 0
.ResetLow
defb 0

; score display for screen writing
.ScoreASC
defb 0,0,0,0,0,0
; copy of ScoreH/M/L do not want score altering through partial update
.ScoreDisplay
defs 3

; 3 bytes in range 0-99 for score
.ScoreH
defb 0
.ScoreM
defb 0
.ScoreL
defb 0
; each game frame, this is added to ScoreM/L
.ScoreFrame
defb 0
defb 0

.Lives
defb 3
.Shield ; represents both invulnerable and end game states
defb 0
.ExplosionSet ; used to trigger player explosion
defb 0

.ReturnToMenu
defb 0

.WaveDelay ; wait to create next sprite
defb 1
.WavePointer ; pointer to next sprites data
defw wave_data

; following variables used in display message for game won
.EndCharPtr
defb 0
.MegaPtr
defw HeroText
.MegaByte
defb 0
.HeroPtr
defw HeroText+47
.HeroByte
defb 0
.CompleteWait
defb 0

.ScorePtr ; used to regulate score display update
defb 0

.CurrentBank ; used to store current memory bank state for when altered under interrupt
defb &c0

.GrindState ; set when player 'grinds' the background
defb 0

.LivesUpdPtr ; used to regulate update of lives and high score display
defb 0
; next two used to regulate the 5000 point bonus awarded at game won
.MegaBonus
defb 0
.BonusWait
defb 0

; end of replace section

; high score display for screen writing
.HiScoreASC
defb 0,1,2,3,4,5

; 3 bytes in range 0-99 for high score
.HiScoreH
defb 1
.HiScoreM
defb 23
.HiScoreL
defb 45

start:

    di ; want to set up the screen split under interupts
    ld sp,&38 ; put stack pointer out of the way

    ld bc,&7F8c
    out (c),c ; set mode 0

    ld a,15 ; set up the 16 inks
    ld hl,Mode0Pal
    call SetColours

    ld de,&29c3 ; initialise the main sound track
    call Ply_INIT

;; standard screen is 39 chars tall and vsync at 30
;; with 25 chars displayed

;; we want to change this to 26 chars displayed with vsync at 32

;; set new vsync we want
ld bc,&bc07
out (c),c
ld bc,&bd00+32
out (c),c

;; wait for 2 vsyncs to allow it to stabalise and so that we can sync with that
ld e,2
wait_two_vsyncs:
ld b,&f5
wait_vsync_end:
in a,(c)
rra
jr c,wait_vsync_end
wait_vsync_start:
in a,(c)
rra
jr nc,wait_vsync_start
dec e
jp nz,wait_two_vsyncs

;; synchronised with start of vsync and we are synchronised with CRTC too, and we have the 
;; same number of lines to next screen as we want.

;; set initial interrupt routine 
ld hl,int_rout1title
ld (int_rout_ptr+1),hl

;; set interrupt
ld a,&c3
ld hl,int_start
ld (&0038),a
ld (&0039),hl
;; enable
ei

; now begin using interupt 5 as frame start
call wait_int

; setup for title screen
.next_int_title_setup
; set border colour black
ld bc,&7f10
out (c),c
ld bc,&7f54
out (c),c
; reset r3 to default for title screen, could have been &85 or &86 during last game frame
ld hl,#0386
ld b,#bc
out (c),h
inc b
out (c),l

; write the credits to the centre part of the title screen, uses bank &4000
    call PrintCredits

; clear both 'high' and 'low' screens. Title screen uses them for the zoom scrolls
    ld a,&c0
    call ClearScr
    ld a,&80
    call ClearScr

; title screen loop
.next_int_title
    call wait_int ; wait for int5

; check if fire pressed on joystick
    ld a,(KBmatrixbuf+9)
    bit 4,a
    jr nz,Exit_Title
; check if space pressed
    ld a,(KBmatrixbuf+5)
    bit 7,a
    jr nz,Exit_Title

; after two screens have been cleared above, title screen should 'just appear', so have
; only set colours after waiting for new frame.  Only required once, but have included
; in main loop as it saves an extra wait_int and there is no harm in repeating
    ld hl,TitlePal
    ld (TitlePalPointer),hl
    ld hl,RasterPal
    ld (TitleRasterPtr),hl
; draw a 'pixel' column for each zoomed scroll
    call WriteZSColumn
; randomise seed by incrementing at 50hz on title screen
    ld hl,SSRandSeed+1
    inc (hl)
; repeat title loop until fire or space pressed
    jr next_int_title

.Exit_Title
; write blank pal to the title screen area while the two game screens are cleared
    ld hl,BlankPal
    ld (TitlePalPointer),hl
    ld (TitleRasterPtr),hl
; clear the two game screens
    ld a,&c0
    call ClearScr
    ld a,&80
    call ClearScr
; clear both 'high' and 'low' sprite background buffers. Title screen uses same
; area for title text
    xor a
    ld hl,SpriteBufHigh
    ld (hl),a
    ld de,SpriteBufHigh+1
    ld bc,&3ff
    ldir
    ld hl,SpriteBufHigh
    ld de,SpriteBufLow
    ld bc,&400
    ldir
; copy the sprite data reset values
    ld hl,SpritesYXReset
    ld de,SpritesYX
    ld bc,32+48+40
    ldir
; fill the sprite address tables with a dummy value
; first action of each game frame is to clear the sprite data, so
; addresses need to be valid
    ld hl,&cf00 ; dummy address
    ld (SpriteAddrHigh),hl
    ld hl,SpriteAddrHigh
    ld de,SpriteAddrHigh+2
    ld bc,174
    ldir
    ld hl,SpriteAddrHigh
    ld de,SpriteAddrLow
    ld bc,176
    ldir
; swap in level data bank
    ld a,&c7
    ld (CurrentBank),a
    ld b,&7f
    out (c),a
; write start of map to map pointer
    ld hl,Map+40
    ld (MapPointer),hl
;clear the column buffer for writing to right side of screen
    ld hl,&4f60
    ld de,&4f61
    ld (hl),0
    ld bc,159
    ldir
; swap back to main memory
    ld a,&c0
    ld (CurrentBank),a
    ld b,&7f
    out (c),a

; copy the defaults to the game variables
    ld hl,SetupVariables
    ld de,base_addr ; first variable to be set
    ld bc,EndEG-SetupVariables
    ldir

; set up some variables in the interrupt code (see EG_interrupts2.asm)
    ld hl,#2000
    ld (base_main),hl
    ld a,&85
    ld (reg3),a
    ld hl,#c04f
    ld (clr_addr),hl
    xor a
    ld (col_inc),a

; game setup is complete, exit title screen interrupts
; wait for int 5
    call wait_int
; and int 6
    halt
; next int would int_rout1title, replace with in game int_rout1
    ld hl,int_rout1
    ld (int_rout_ptr+1),hl
; screen is now arranged with in game screen split code
; begin main game loop
.next_int
; wait for next int 5
    call wait_int

; first check game exit conditions
ld a,(ReturnToMenu)
or a ; a non zero value indicates game loop is done
jr z,ContinueGameLoop
; exiting main game loop needs to happen after int 6 as well
halt
; set interrupts to those used for title screen
ld hl,int_rout1title
ld (int_rout_ptr+1),hl
; and return to title set up. Colours for title screen will still be blank
; until entry to main loop, so at the next interrupt the title screen will be blanked
jp next_int_title_setup

.ContinueGameLoop
; this must be called before int6
    call do_scroll ; move screen left 1 pixel, change screen pointers

; restore the backgrounds saved for sprites from last frame, or fill dummy
; addresses if first game frame
    call RestoreSpriteBG ; 119 scan lines

    call ClearStars

; first up bank in the map data
    ld a,&c7
    ld (CurrentBank),a
    ld b,&7f
    out (c),a

; check to see if the tile column has changed
    call ProcessMapPointer
; for every byte in the buffer, move the right pixel to the left of the byte
; and put a new pixel in the right side according to the map data
    call Fill_Buffer ; 49 scan lines

; copy the buffer to the screen to the current screen right side
    ld hl,(paint_addr)
    call Copy_Buffer ; 11 scan lines

; swap back to main memory
    ld a,&c0
    ld (CurrentBank),a
    ld b,&7f
    out (c),a

    call MoveSprites
; animate sprites is only required every other frame
    ld a,(base_addr+1)
    bit 6,a
    call z,AnimateSprites ; is opposite to UpdateLivesHS to level out CPU use

; Player bullet moves at 12 pixels per frame at 50Hz in C64 version.  Therefore at
; 25Hz in CPC version, bullet must move 24 pixels, or 12 bytes.  Doing this  in one
; setp creates issue in that player shot moves too far in one frame and hit box
; requires to long a tail, so it becomes possible for bullet to pass through
; background objects or occasionally hit enemies behind other enemies.
; To prevent this, the player bullet is moved 12 pixels, or 6 bytes, and collsion
; detection performed on it, TWICE per frame.  The following 3 calls perform these
; 'secondary' move & collision checks.

call BulletCollision ; check player shot against sprites
call InterimBulletCollision ; check player shot against background
call InterimBulletMove ; move player shot a second time
call BulletCollision ; check player shot against sprites a second time
call PlayerCollision ; check player against sprites

; check to see if enemy sprites should be converted to explosion for player
ld a,(ExplosionSet)
or a
call nz,SetExplosion
; check to see if new enemy sprite should be created
call ProcessWave
; check all sprites against current screen address reset position
call CheckScreenReset

; generate address list for all sprites
call CalcSprites ; 28 scan lines
; use address list to check player and shot against background
call CheckBackgrounds2

; sum the score for this frame as result of collisions
call UpdateScoreText
; update the lives and high score part of the score panel, only every other frame
ld a,(base_addr+1)
bit 6,a
call nz,UpdateLivesHS ; opposite to animate, up to 4 scan lines

; save the background behind sprites
call SaveSpriteBG ; 130 scan lines
; and then display the sprites
call PrintSprites ; 184 scan lines
; show the stars where nothing would obscure them
call PrintStars
; check for one of two game ending states (no lives or won)
call CheckGameState

; return to beginning of game loop
jp next_int

; wait until int_flag is zeroed by interrupt 5
.wait_int
ld a,1
ld (int_flag),a
.wait_int_lp
.int_flag equ $ + 1
ld a,0
or a
jr nz,wait_int_lp
ret

.do_scroll
; move screen base address along
ld hl,(base_addr)
bit 6,h
set 6,h
jr z,no_base_adj
inc hl
res 6,h
res 3,h
.no_base_adj
ld (base_addr),hl
; and find column to write new background to
ld de,#4d
add hl,de
res 3,h
ld (paint_addr),hl
; indicate to interrupt routine that it can display the next frame
ld a,1
ld (scroll),a		; Non-zero
ret

; delay for hl/8 scan lines
.delay
    dec hl
    nop
    ld a,h
    or l
    jr nz,delay
    ret

.CheckGameState
    ld hl,ReturnToMenu ; preload hl with pointer to marker for indicating game loop exit
; if escape not pressed, check if game ended
    ld a,(KBmatrixbuf+8)
    bit 2,a
    jr z,CheckGSGameEnd
; escape pressed, begin pause by first waiting for esc to cease being pressed
.PauseWaitReleaseEsc1
    call wait_int
    ld a,(KBmatrixbuf+8)
    bit 2,a
    jr nz,PauseWaitReleaseEsc1
; escape now unpressed, wait for escape to be pressed again to either restart
; play or abort the game
.PauseWaitPress
    call wait_int
    ld a,(KBmatrixbuf+8)
    bit 2,a
    jr z,PauseWaitPress
; escape now pressed, last phase of pause or quit
    ld c,51 ; game will quit if escape held for 1 second, if released before will continue
.PauseWaitReleaseEsc2
    call wait_int
    dec c ; while escape held, decrement quit counter
    jr z,ExitGame ; if reached 0, have held escape for 1 second, so abort
    ld a,(KBmatrixbuf+8)
    bit 2,a
    jr nz,PauseWaitReleaseEsc2
; if escape released within 1 second, return to game loop where paused from
    ret
.ExitGame
    inc (hl) ; set game loop exit marker to non zero, and return to main loop
    ret
; escape not pressed, check state of shield bit 7, will indicate game over or won
.CheckGSGameEnd
    ld de,Shield
    ld a,(de)
    bit 7,a
    ret z ; if bit 7 not set, there is no game state exception to process
    cp a,&80 ; if only bit 7 set, game has been won, check progress
    jr z,GameCompleteWait
; if shield > &80, game is over, decrease delay timer (lower 7 bits)
    dec a
    cp a,&80 ; if lower 7 bits are zero
    jr z,ExitGame ; time to exit game loop
    ld (de),a ; otherwise continue delay
    ret ; and continue game loop for another frame
.GameCompleteWait
; game is complete, first stage is to wait for the enemy sprite disguised as the player
; to leave the screen
    ld a,(SpritesYX+1)
    rla
    ret nc ; sprite 1 x co-ord still not offscreen, so return to main loop
; the second phase is to wait a couple of extra frames so that both the
; high and low screen addresses for sprite 1 get set to dummies
.GameCompletePlyrClear
    ld a,0 ; was set non zero in EG_WaveList2.asm
    or a
    jr z,GCPCPauseDone ; when zero, enter end game sequence loop below
; otherwise, return to main loop for another frame
    dec a
    ld (GameCompletePlyrClear+1),a
    ret
; the third phase is to set up the end sequence
.GCPCPauseDone
    call wait_int
; show the last drawn screen frame
    call do_scroll
; set the music to the 'win' music
    ld a,2
    ld (ChangeMusic),a
; some frames the clear column will interfere with left side of visible screen
; when scrolling stops, so move the clr_addr back one byte
    ld hl,(clr_addr)
    ld de,&7ff
    add hl,de
    res 3,h
    ld (clr_addr),hl
; if R3 was changed last do_scroll, also move back one byte base_addr, as
; this stage of end sequence writes to the visible screen
    ld hl,(base_addr)
    bit 6,h
    jr nz,BuildWinMsgLoop
    ld de,&7ff
    add hl,de
    res 3,h
    ld (base_addr),hl
; writing to the visible screen, build 'mega hero' message, printing one
; character from each word per frame
.BuildWinMsgLoop
    call wait_int ; wait for int 5
    call Complete_WriteChar ; write a character from each word
; bonus points for lives remaining are added at this point, the points
; per life are staggered out
; check to see if time to add life bonus
    ld a,(BonusWait)
    or a
    jr z,NoEndBonusLeft ; if bonuswait is zero, have finished giving bonus points
    dec a
    jr nz,NotTimeForEndBonus
    ld a,50 ; if time to give bonus, add 5000 to score
    ld (ScoreFrame),a
    ld a,(MegaBonus) ; check to see if any more bonus points to give
    dec a
    ld (MegaBonus),a
    jr z,NotTimeForEndBonus ; no more to add, so zero the timer
    ld a,50 ; more points to give, so reset timer
.NotTimeForEndBonus
    ld (BonusWait),a
.NoEndBonusLeft
    call UpdateScoreText ; add score frame to score
    call UpdateLivesHS ; update high score & lives
    ld a,(CompleteWait) ; completewait will be set non zero when message displayed fully
    or a
    jr z,BuildWinMsgLoop ; continue to build 'mega hero' message
; finished printing 'Mega Hero', copy visible screen to hidden one
    ld hl,&c000
    ld de,&8000
    ld a,(base_addr+1)
    bit 6,a
    jr z,EndScrnCopyHigh ; copy high to low
; else copy low screen high
    ex de,hl
.EndScrnCopyHigh
    ld bc,&4000
    ldir
; now the fourth and final stage of the end sequence
; wait for space or fire from player while setting off explosions
.CompleteWaitFireLp
    call wait_int
; want to display some sprites, but need to screen flip without scrolling
; so a little hack job here to do that to base_addr & base_main
    call dont_scroll
; check fire
    ld a,(KBmatrixbuf+9)
    bit 4,a
    jr nz,CWFWaitOver ; exit end sequence
; check space
    ld a,(KBmatrixbuf+5)
    bit 7,a
    jr nz,CWFWaitOver ; exit end sequence
; other execute routines to display and animate explosions only
    call RestoreSpriteBG ; 119 scan lines
    ld a,(base_addr+1)
    bit 6,a
    call z,AnimateSprites ; every other frame
; create a new explosion
    call EndSeqExplosion
; perform required calls from main loop to display the explosion sprites
    call CheckScreenReset
    call CalcSprites ; 28 scan lines
    call SaveSpriteBG ; 130 scan lines
    call PrintSprites ; 184 scan lines
; repeat until player exits with space or fire
    jr CompleteWaitFireLp
.CWFWaitOver ; when space or fire pressed
    ld a,1 ; set music back to main theme
    ld (ChangeMusic),a
    ld hl,ReturnToMenu ; and return to main game loop with exit indicated
    jp ExitGame

; perform screen flipping for the end sequence
.dont_scroll
    ld a,(base_main+1)
    xor a,&10
    ld (base_main+1),a
    ld a,(base_addr+1)
    xor a,&40
    ld (base_addr+1),a
    ret

.GenerateRandom
; random number generator - taken from wiki programming section
; only used in this game for random explosion placement in game won sequence
.SSRandSeed
; randomise
    ld bc,0
    ld a,b
    ld h,c
    ld l,253
    or a
    sbc hl,bc
    sbc a,0
    sbc hl,bc
    ld b,0
    sbc a,b
    ld c,a
    sbc hl,bc
    jr nc,SSRand
    inc hl
.SSRand
    ld (SSRandSeed+1),hl
    ret

.Mode0Pal ; in game palette
    defb &54,&5d,&57,&53,&5e,&59,&4b,&5f
    defb &58,&47,&4c,&56,&44,&43,&5c,&54
.TitlePal ; title screen palette
    defb &56,&45,&58,&53,&57,&55,&44,&59
    defb &52,&56,&43,&4a,&4e,&5c,&4b,&54
.BlankPal ; palette for showing blank screen
    defb &54,&54,&54,&54,&54,&54,&54,&54
    defb &54,&54,&54,&54,&54,&54,&54,&54
; extend raster text for when title screen is setting up
    defb &54,&54,&54,&54,&54,&54,&54,&54
    defb &54,&54,&54,&54,&54,&54,&54,&54
    defb &54,&54,&54,&54,&54,&54,&54,&54
    defb &54,&54,&54,&54,&54,&54,&54,&54
.RasterPal ; list of colours for the rolling colours on title screen text
    defb &5c,&54,&58,&54,&4c,&5c,&45,&5c
    defb &4e,&58,&47,&58,&4a,&4c,&43,&4c
    defb &4b,&4e,&43,&4c,&4a,&4c,&47,&58
    defb &4e,&58,&45,&5c,&4c,&5c,&58,&54
; repeat first two lines
    defb &5c,&54,&58,&54,&4c,&5c,&45,&5c
    defb &4e,&58,&47,&58,&4a,&4c,&43,&4c

; these additional variables dont require resetting

; indicator to interrupt to change music
.ChangeMusic
    defb 0

; palette pointers for raster coloured font on title screen
.TitlePalPointer
    defw BlankPal
.TitleRasterPtr
    defw BlankPal
.TitleRasterOS
    defb 0

; End sequuence explosion variables
.EndExpPtr
    defb 0
.EndExpDelay
    defb 0

; temp save current stack pointer
.SaveSP
    defw 0

; player sprite frame ptr = 0-6
.PlayerFrame
    defb 0

; these tables are copied to &40 as the default starting values
.SpritesYXReset
    defb 0,128
    defb 0,128
    defb 0,128
    defb 0,128
    defb 0,128
    defb 0,128
    defb 102,29
    defb 0,192
;.SpritesYXMv
    defb 0,0
    defb 0,0
    defb 0,0
    defb 0,0
    defb 0,0
    defb 0,0
    defb 0,0
    defb 0,0
;.SpriteData
    defs 48
;    defb rocker,timer,move1,move2,basespr,animtype,animdata,hits
;    defb 64+1,64+1,0,0,101,64,6,2 ; sprite 14
;    defb 64+1,64+1,0,0,107,64,6,2 ; sprite 15
;    defb 64+0,64+0,0,0,113,64,6,2 ; sprite 16
;    defb 64+1,64+1,0,0,52,64,6,2 ; sprite 7
;    defb 64+0,64+0,0,0,85,64,8,3 ; sprite 12
;    defb 64+1,64+1,0,0,93,64,8,3 ; sprite 13
;.StarsLow
    defw &10f*2+&8000-400
    defw &1a3*2+&8000-400
    defw &24d*2+&8000-400
    defw &2d9*2+&8000-400
    defw &375*2+&8000-400
    defw &144*2+&8000-400
    defw &1ee*2+&8000-400
    defw &2a1*2+&8000-400
    defw &336*2+&8000-400
    defw &3dc*2+&8000-400
;.StarsHigh
    defw &10f*2+&c000-400
    defw &1a3*2+&c000-400
    defw &24d*2+&c000-400
    defw &2d9*2+&c000-400
    defw &375*2+&c000-400
    defw &144*2+&c000-400
    defw &1ee*2+&c000-400
    defw &2a1*2+&c000-400
    defw &336*2+&c000-400
    defw &3dc*2+&c000-400

;    defb 0,0,0,0,19,192,1,0 ; sprite 1
;    defb 0,0,0,0,24,64,6,0 ; sprite 2
;    defb 0,0,0,0,30,64,4,0 ; sprite 3
;    defb 0,0,0,0,34,128,1,0 ; sprite 4
;    defb 0,0,0,0,40,64,6,0 ; sprite 5
;    defb 0,0,0,0,46,64,6,0 ; sprite 6
;    defb 0,0,0,0,52,64,6,0 ; sprite 7
;    defb 0,0,0,0,58,64,7,0 ; sprite 8
;    defb 0,0,0,0,65,64,6,0 ; sprite 9
;    defb 0,0,0,0,71,64,6,0 ; sprite 10
;    defb 0,0,0,0,77,64,8,0 ; sprite 11
;    defb 0,0,0,0,85,64,8,0 ; sprite 12
;    defb 0,0,0,0,93,64,8,0 ; sprite 13
;    defb 0,0,0,0,101,64,6,0 ; sprite 14
;    defb 0,0,0,0,107,64,6,0 ; sprite 15
;    defb 0,0,0,0,113,64,6,0 ; sprite 16

read "EG_Sprites10.asm"
read "EG_Sprites_Partial.asm"
read "EG_Display3.asm"
read "EG_Stars3.asm"
read "EG_Interrupts2.asm"
read "EG_Collision5.asm"
read "EG_Animate.asm"
read "EG_Zoom.asm"
read "EG_Move3.asm"
read "ArkosTrackerPlayer_CPC_MSX.asm"
read "EG_WaveList2.asm"

read "MegaHero.asm"

; more default starting values, copied to &118
.SetupVariables
;.base_addr
dw &c000

;.paint_addr
dw #c04d

;.scroll_step
db 0

;.scroll
db 0

;.ZSCharPtr
    defw ZoomScrollMsg-1

;.ZSCharCol
    defb 7

;.HighZoomScrlOffset
    defw 0
;.LowZoomScrlOffset
    defw 0

;.ResetYX
defb 232,16+48

;.ResetHigh
defb 0
;.ResetLow
defb 0

;.ScoreASC
defb 0,0,0,0,0,0

;.ScoreDisplay
defs 3

;.ScoreH
defb 0
;.ScoreM
defb 0
;.ScoreL
defb 0

;.ScoreFrame
defb 0
defb 0

;.Lives
defb 3
;.Shield
defb 0
;.ExplosionSet
defb 0

;.ReturnToMenu
defb 0
;.WaveDelay
defb 23
;.WavePointer
defw wave_data

;.EndCharPtr
defb 0
;.MegaPtr
defw HeroText
;.MegaByte
defb 0
;.HeroPtr
defw HeroText+111
;.HeroByte
defb 0
;.CompleteWait
defb 0

;.ScorePtr
defb 0
;.CurrentBank
defb &c0
;.GrindState
defb 0

;.LivesUpdPtr
defb 0
;.MegaBonus
defb 0
;.BonusWait
defb 0

list
.EndEG