\ ******************************************************************
\ *	EDGE GRINDER
\ ******************************************************************

\ RELEASE is a beebasm command-line symbol (-D RELEASE=0 or 1); build.ps1
\ passes it on every build. beebasm has no IFDEF, so there is no default here.
ASSERT RELEASE=0 OR RELEASE=1
DEV = 1-RELEASE

\ Debug flags. Each must be off under RELEASE; add new ones to DEBUG_ANY and
\ to the !BOOT stamp at the bottom of this file so a build says what it is.
\ MUSIC_AKL is stamped there too, but it is not one of these: it is legal
\ under RELEASE and so is deliberately not in DEBUG_ANY.
DEBUG_COLL = 0              ; collisions never take a life (the C64 source's
                            ; own "patch me out to disable collisions!").
                            ; OFF in DEV too: dying is the normal case
DEBUG_TIMING = DEV          ; the frame meter: see src/timing.asm
DEBUG_ANY = DEBUG_COLL OR DEBUG_TIMING
IF RELEASE
    ASSERT DEBUG_ANY=0
ENDIF

_DOUBLE_BUFFER = TRUE

\ ******************************************************************
\ *	OS defines
\ ******************************************************************

osfile = &FFDD
oswrch = &FFEE
osasci = &FFE3
osbyte = &FFF4
osword = &FFF1
osfind = &FFCE
osgbpb = &FFD1
osargs = &FFDA
osrdch = &FFE0

\\ Palette values for ULA
PAL_black	= (0 EOR 7)
PAL_blue	= (4 EOR 7)
PAL_red		= (1 EOR 7)
PAL_magenta = (5 EOR 7)
PAL_green	= (2 EOR 7)
PAL_cyan	= (6 EOR 7)
PAL_yellow	= (3 EOR 7)
PAL_white	= (7 EOR 7)

MODE2_PIXEL_00  = &00
MODE2_PIXEL_01  = &01
MODE2_PIXEL_02  = &04
MODE2_PIXEL_03  = &05
MODE2_PIXEL_04  = &10
MODE2_PIXEL_05  = &11
MODE2_PIXEL_06  = &14
MODE2_PIXEL_07  = &15

MODE2_PIXEL_10  = MODE2_PIXEL_01<<1
MODE2_PIXEL_20  = MODE2_PIXEL_02<<1
MODE2_PIXEL_30  = MODE2_PIXEL_03<<1
MODE2_PIXEL_40  = MODE2_PIXEL_04<<1
MODE2_PIXEL_50  = MODE2_PIXEL_05<<1
MODE2_PIXEL_60  = MODE2_PIXEL_06<<1
MODE2_PIXEL_70  = MODE2_PIXEL_07<<1

MODE2_PIXEL_LEFT_MASK = &AA
MODE2_PIXEL_RIGHT_MASK = &55

\ Internal key numbers, every one MEASURED with OSBYTE 121 in a BASIC
\ session holding the key, never recalled: they are hardware facts and
\ getting one wrong is silent.
IKN_z = 97
IKN_x = 66
IKN_k = 70
IKN_m = 101
IKN_l = 86
IKN_p = 55
IKN_q = 16
IKN_escape = 112            ; the MOS interrupt is gone, so it is just a key
IKN_space = 98              ; measured 2026-09-04, alongside L to prove the
                            ; method: INKEY(-n) gave 86 for L, which is what
                            ; IKN_l already said

\ Layer 9h's two, measured the same way on 2026-09-06 (docs/layer-9h-keyredef.md):
\ CTRL and R are the redefine screen's trigger. CTRL is BELOW the OSBYTE 121
\ scan's floor - the MOS scan will not report keys 0-2 - so it was measured
\ through INKEY instead and calibrated on Z: SHIFT is INKEY -1, CTRL is INKEY
\ -2 and Z is INKEY -98, and Z's internal number is 97, so internal = the
\ INKEY index less one. That makes SHIFT 0 and CTRL 1.
IKN_ctrl = 1
IKN_r = 51

\ And Layer 9i's, which is not a new measurement: A is kr_keys' first entry
\ (src/panel.asm), measured in the same OSBYTE 121 run as the other
\ thirty-four on 2026-09-06. It is written out here because CTRL+A is read
\ in src/bank1.asm and a reader of that wants the number, not a table index.
IKN_a = 65                  ; CTRL+A on the titles toggles auto-fire

\ Which control is which, in read_joystick's order - which is the C64's own
\ $dc00 bit order, so player_manage's LSR/BCS chain stays the original's.
JOY_UP = 0
JOY_DOWN = 1
JOY_LEFT = 2
JOY_RIGHT = 3
JOY_FIRE = 4
JOY_COUNT = 5

\ ******************************************************************
\ *	GAME defines
\ ******************************************************************

BG_COL_0 = PAL_black
BG_COL_1 = PAL_blue
BG_COL_2 = PAL_white
BG_COL_3 = PAL_green          ; PAL_red or PAL_cyan also look OK

BG_PIX_0 = MODE2_PIXEL_00
BG_PIX_1 = MODE2_PIXEL_04
BG_PIX_2 = MODE2_PIXEL_07
BG_PIX_3 = MODE2_PIXEL_02

SPRITE_PIX_0 = MODE2_PIXEL_00   ; actually transparent
SPRITE_PIX_1 = MODE2_PIXEL_05 OR MODE2_PIXEL_50 ; magenta (black on C64)
SPRITE_PIX_2 = MODE2_PIXEL_01 OR MODE2_PIXEL_10 ; red
SPRITE_PIX_3 = MODE2_PIXEL_03 OR MODE2_PIXEL_30 ; yellow (white on C64)

GAME_LIVES = 3                  ; the C64's main_init

\ The five play controls are DEFAULTS now, not constants the code tests
\ (Layer 9h, decision 71): key_init copies them into joy_keys in zero page at
\ boot and CTRL+R on the titles writes them. Everything that reads a control
\ goes through joy_keys - in zero page precisely so that `ldx joy_keys +
\ JOY_FIRE` is the same two bytes `ldx #KEY_FIRE` was, and bank 0, which has
\ nine of them left, does not grow.
KEY_LEFT = IKN_z
KEY_RIGHT = IKN_x
KEY_UP = IKN_k
KEY_DOWN = IKN_m
KEY_FIRE = IKN_l
KEY_START = IKN_space       ; SPACE starts a game as well as fire (KC). Only
                            ; on the titles: it does not unpause
KEY_PAUSE = IKN_p           ; decision 32, and CTRL+P since decision 72 - see
                            ; key_pause in src/bank0.asm for why the CTRL is
                            ; tested first and what it costs (nothing)
KEY_ABORT = IKN_escape      ; and only while paused, as the C64 has it.
                            ; Tried at any time and reverted (KC): it is
                            ; polled every frame, so holding it re-entered
                            ; life_lost and rebuilt the player's explosion
                            ; pieces on the spot. It would need a debounce
KEY_MUTE = IKN_q            ; decision 39. Read in the VSync handler, so it
                            ; works wherever the foreground happens to be.
                            ; CTRL+Q since decision 72, tested in that handler
                            ; the same way pause_check tests CTRL+P
\ ---- the auto-fire message, and the one build that cannot show it -------
\ It is 174 bytes of BANK 3 - three 38-glyph lines and the plotter entry that
\ draws them - and a VGI -Cpc build has 24: bank 3's tail is region A of the
\ tune (decision 48), the Amstrad's compiled sprite bodies are bigger than the
\ C64's, and the whole VGI music layout has 32 bytes of slack in it, measured
\ across all four of its regions. There is nothing to reclaim.
\
\ VGI IS RETIRED FROM THE CONFIGURATION SET (KC, 2026-09-06), so rather than
\ hold the feature back for it, the MESSAGE is built wherever bank 3 has the
\ room and THE TOGGLE ITSELF IS IN EVERY BUILD: af_latch is in zero page and
\ player.asm never sees this switch. Only the words on the titles are missing,
\ and only in the one retired combination. HERE rather than in bank3.asm
\ because bank 2 tests it too and this file is assembled first.
TTL_AUTO_SHOW = MUSIC_AKL OR (1 - GFX_CPC)

\ How long the message holds, in FIELDS: three seconds at 50 Hz. Counted down
\ by ttl_auto_key in bank 2, which runs once a field while the titles are up,
\ and read by title_auto in bank 3, for which 0 means "draw the blank line".
TTL_AUTO_HOLD = 150

\ ---- and what af_latch holds, which is what fire_bullet writes into --------
\ fire_latch. AF_OFF is NEGATIVE and is the C64's latch exactly: only seeing
\ the button released clears it. AF_ON is a COUNTDOWN in game ticks, decremented
\ once a tick while the button is held, so auto-fire has a floor on how often
\ it can shoot and a tap still gets the next shot the moment the bullet slot
\ is free (decision 74).
\
\ TEN TICKS IS 0.2 SECONDS - a tick is 1/50 s, game_tick running twice per
\ 25 Hz frame - and it is KC's number, played rather than calculated: 30 was
\ "a bit long", 20 was tried, and 10 "feels better".
\
\ WHAT THE FLOOR IS AGAINST, all MEASURED in jsbeeb 2026-09-06: the bullet
\ moves 12 a tick and dies at ENEMY_X_KILL = &d0, so from the drop-in x = &28
\ its flight is 14 ticks and a held button shot every 15 - but at the
\ right-hand edge every 6, and a bullet that HITS something dies where it hit,
\ so point blank it was faster still. The rate climbing the closer you got is
\ what made the game too easy (KC).
\
\ SO TEN BINDS WHERE THE FLIGHT IS SHORT AND NOWHERE ELSE, which is the point
\ of it: at normal range the flight is longer than the floor and nothing
\ changes, while close in - the right-hand edge, or an enemy's face - a held
\ button is capped at five shots a second instead of running away with it.
\ An earlier ASSERT here demanded AF_ON > 16, the LONGEST flight, on the
\ reasoning that a floor which does not bind everywhere does not bind at all;
\ KC's ear says otherwise and the assert is gone. THIS IS THE ONE NUMBER TO
\ TURN, and turning it up slows normal range too.
AF_OFF  = &80
AF_ON   = 10
AF_FLIP = AF_OFF EOR AF_ON   ; what ttl_auto_key toggles af_latch with
ASSERT AF_ON > 0 AND AF_ON < &80    ; positive, so the held path can tell it
                                    ; from AF_OFF by its sign

KEY_AUTO = IKN_a            ; decision 73. CTRL+A on the TITLES, not in play:
                            ; ttl_frame_titles in bank 1 already tests CTRL
                            ; once a field for R, so the test is free of both
                            ; main RAM and bank 0, neither of which had the
                            ; room - and the titles are where the state can
                            ; be SHOWN. See ttl_frame_titles in src/bank1.asm

\ ******************************************************************
\ *	MACROS
\ ******************************************************************

MACRO BG_PIXEL c
IF c=1
    EQUB BG_PIX_1
ELIF c=2
    EQUB BG_PIX_2
ELIF c=3
    EQUB BG_PIX_3
ELSE    
    EQUB BG_PIX_0
ENDIF
ENDMACRO


MACRO CRTC r, v
    lda #r : sta CRTC_ADDR
    lda #v : sta CRTC_DATA
ENDMACRO

MACRO PAGE_ALIGN
H%=P%
ALIGN &100
PRINT "Skipping ", P%-H%, "bytes"
ENDMACRO

\ Close off one phase of the main loop into the TIM_ slot named. Four
\ bytes and ~80 cycles here, and nothing at all without DEBUG_TIMING;
\ the work is in bank 0. See src/timing.asm.
MACRO TIMMARK slot
IF DEBUG_TIMING
    lda #slot
    jsr tim_mark
ENDIF
ENDMACRO

\ ******************************************************************
\ *	GLOBAL constants
\ ******************************************************************

screen_start = &4000
screen_size = &4000
screen_top = screen_start + screen_size
row_stride = 640

column_buffer = &400        ; 160 bytes for right hand column
column_size = 160

\\ The background collision character map (decision 24). The C64 reads the
\\ character codes back out of its own screen; we draw pixels, so scroll.asm
\\ writes them here as it plots and player.asm reads them. 40 columns as a
\\ ring, 20 rows of the play area, the same grid the C64's screen has.
\\ &04A0-&07FF is the language workspace: BASIC's, and ours once *RUN has
\\ handed over. Verified in jsbeeb - a sentinel across the whole of it
\\ survives 3,000 fields of the running game untouched.
COLL_COLS = 40
COLL_ROWS = 20
coll_map = &04A0
ASSERT coll_map >= column_buffer + column_size
ASSERT coll_map + COLL_COLS * COLL_ROWS <= &0800

SCORE_DIGITS = 6

\\ Game state lives at &0800, not in the code image. The C64 keeps the
\\ same block in its tape buffer at $0340 for the same reason: it is RAM
\\ that needs no initial value, so it costs nothing to put it where the
\\ image is not. &0800-&0BFF is the MOS's sound, serial and soft-key
\\ workspace, which is ours with the MOS interrupt gone - verified in
\\ jsbeeb, a sentinel across all four pages surviving 1,500 fields of
\\ the running game. Declared at the bottom of this file, outside the
\\ SAVE, so none of it is written to the disc.
GAME_STATE = &0800
GAME_STATE_TOP = &0C00

SWRAM_DATA = 4              ; bank 0: chars, tiles, map, col_decode (resting state)
SWRAM_SPRITES0 = 5          ; bank 1: sprite data, pixel shift 0
SWRAM_SPRITES1 = 6          ; bank 2: the same, shift 1. The engine adds the
                            ; shift to SWRAM_SPRITES0, so these must be adjacent.
SWRAM_COMPILED = 7          ; bank 3: compiled sprite bodies, both shifts together
ASSERT SWRAM_SPRITES1 = SWRAM_SPRITES0 + 1
\ Slots 4-7 are the Master's 64K of sideways RAM; 8-F hold the MOS ROMs and
\ 0-3 are the cartridge slots, empty on a stock machine. Measured in jsbeeb:
\ a pattern written to slot 7 survives a page out and back, and the same
\ write to slot 3 vanishes.
ASSERT SWRAM_COMPILED <= 7

SPR_SAVE = &2000            ; 8 slots x 256 B x 2 banks, saved background

\ HAZEL: the Master's 8K of filing-system RAM at &C000-&DFFF, paged in by
\ ACCCON bit 3 (Y). Layer 7 puts the music player and the tune there - it is
\ the only RAM left, and unlike a sideways bank it does not collide with the
\ window the sprite engine is paging while the IRQ fires. See src/music.asm.
HAZEL_BIT   = 8
HAZEL_BASE  = &C000
HAZEL_WORK  = &D500         ; the VGI player's 11 x 256 ring, exactly to &DFFF
ASSERT HAZEL_WORK + 11 * 256 = &E000

\ THE TUNE, IN FOUR PLACES (decision 48)
\
\ EDGEA packs to 23,514 bytes of .vgi and there is no hole that size on this
\ machine. But a .vgi is not one blob: it is ELEVEN INDEPENDENT STREAMS, one
\ per SN76489 register, and the player reads exactly one byte from each per
\ frame through its own pointer. So each stream has to be contiguous and the
\ tune does not, and the whole 349 seconds goes in four regions:
\
\   A     &9100-&D2FF   the tail of bank 3 running on into HAZEL. Both are
\                       VISIBLE AT THE SAME TIME - they are paged by
\                       different registers over different windows - so a
\                       stream may cross &C000 and the player never learns
\                       the join is there. It ships as two files: below
\                       &C000 in BANK3 (music_lo, padded to meet the join
\                       exactly) and above it in MUSIC (music_hi).
\   ANDY  &8000-&8FFF   the Master's own 4K, ROMSEL bit 7 - measured in
\                       jsbeeb, 2026-09-04: it overlays the LOW 4K of
\                       whichever sideways bank is selected and leaves the
\                       rest of the window alone. That is the busiest ground
\                       we have, so nothing an inner loop walks could live
\                       here; a music stream read a few times a frame from
\                       an interrupt is exactly the right tenant.
\   B1    &B900-&BFFF   the tail of sideways bank 1, above the sprite
\   B2    &BA00-&BFFF   data, and the same for bank 2 a page higher - the
\                       CPC artwork's sprite bank 2 reaches &B941.
\
\ tools/export_music.py does the placement and writes src/data/music_map.asm
\ - eleven addresses and eleven ROMSEL bytes - which ASSERTs these constants
\ against its own. lib/vgiplayer.asm reads that map under VGI_SPLIT and pages
\ each stream's region in before every raw byte it fetches.
MUSIC_A_BASE    = &9100     ; region A: bank 3's tail, ...
MUSIC_A_JOIN    = HAZEL_BASE                    ; ... across this join, ...
MUSIC_A_TOP     = &D300     ; ... to here, where the player's code starts
MUSIC_ANDY_BASE = &8000
MUSIC_ANDY_TOP  = &9000
MUSIC_B1_BASE   = &B900
MUSIC_B2_BASE   = &BA00     ; higher than B1's: the CPC artwork's
                            ; sprite bank 2 reaches &B941
MUSIC_LO_SIZE   = MUSIC_A_JOIN - MUSIC_A_BASE   ; what BANK3 carries
MUSIC_PLAYER    = MUSIC_A_TOP
ASSERT MUSIC_A_BASE >= &8000
ASSERT MUSIC_ANDY_TOP - MUSIC_ANDY_BASE = &1000

\ ANDY's ROMSEL byte. Bit 7 is what selects it; the bank number underneath is
\ irrelevant while it is set, and bank 3 is what the music update has paged
\ anyway.
ANDY_ROM = &80 OR SWRAM_COMPILED

\ The VGI player's own state - 96 bytes - in the MOS user-font page, which
\ this game never writes. It is there rather than in HAZEL beside the code
\ because HAZEL is the scarce thing and main RAM at &0C00 is not, and because
\ fetchbyte reads it with the sideways window pointed at a music stream.
VGI_STATE = &0C00
VGI_SPLIT = 1

\ MUSIC_AKL picks the OTHER music subsystem, for the comparison Layer 7 left
\ open: src/aklplayer.asm replays the Arkos tracker data directly and
\ src/ay2sn.asm converts AY registers to the SN76489 every frame, instead of
\ lib/vgiplayer.asm decoding a pre-converted register log. It is passed on the
\ command line beside RELEASE, because beebasm has no IFDEF and refuses a
\ symbol defined twice, so main.asm cannot carry a default.
\
\ The whole subsystem then fits inside HAZEL - player, converter, tables and
\ the WHOLE 349-second tune - so bank 3's music_lo disappears and its 8,960
\ bytes come free. The tune is not truncated in this build.
\ BOTH TUNES ARE IN BANK 3, and HAZEL holds nothing but the player. That is
\ forced arithmetic rather than taste: the current library - the write-through
\ SN cache and the periodic-noise bass, neither of which the first copy had -
\ is 3,468 bytes, and 3,468 + the in-game tune's 4,741 is 8,209 against
\ HAZEL's 8,192. Seventeen bytes over, so the tune moved rather than the
\ library being held back.
\
\ Bank 3 costs nothing to reach: rupt_vsync pages it in for the music every
\ field already. The addresses are absolute because AKL data is;
\ tools/export_music_akl.py exports each tune at the one named here.
MUSIC_AKL_SONG = &9200      ; the in-game tune, 4,741 bytes
MUSIC_AKL_WIN  = &A500      ; the finale's, 695
\ BOTH MOVED UP A PAGE IN LAYER 9i, from &9100 and &A400: the auto-fire
\ indicator is 136 bytes of this bank's code and data and a -Cpc build had
\ not got them below &9100. There are 6,217 bytes above the two tunes, so
\ the page came from there. AKL DATA IS ABSOLUTE, so the tunes have to be
\ RE-EXPORTED at the new addresses - tools/export_music_akl.py carries the
\ same two numbers and its --check proves them.
ASSERT MUSIC_AKL_SONG >= &9200
ASSERT MUSIC_AKL_WIN > MUSIC_AKL_SONG
ASSERT MUSIC_AKL_WIN < &C000

\ ENV_BASE and BASS_MODE are the HOST'S to define and neither is defaulted by
\ the library - a default is a choice this file did not make, and BeebASM
\ cannot ask whether a symbol exists. See lib/ay2sn.asm's header.
\
\ ENV_BASE: AKL stores one BIT of envelope shape, meaning ENV_BASE or
\ ENV_BASE + 2. Both Edge Grinder tunes are envelope 12 throughout - measured
\ with arkos-player-bbc's tools/survey_envelopes.py, not assumed - so one
\ constant serves the pair. Had they differed, no single build could play both.
ENV_BASE = 12

\ BASS_MODE 2: the periodic-noise bass, and nothing else assembled. The
\ SN76489's lowest note is 122 Hz and a third of EDGEA is below it; mode 2
\ synthesises those notes on the noise generator clocked by tone 3, which is
\ what ym2sn.py does offline for the VGI build. It needs no timer and no
\ interrupt of its own, which is why it and not the software voice: this
\ game has no spare VIA and its worst frame is already at 108%.
BASS_MODE = 2

\ THE SECOND TUNE. The CPC has two - EDGEA in game and WON4 for the finale -
\ and re-inits the replay with the other address when the end sequence starts
\ (`ld (ChangeMusic),a` in Compiled_Main3.asm, acted on in EG_Interrupts2).
\ This port does the same thing with music_change, acted on in rupt_vsync.
\
\ It does NOT go in HAZEL: 379 bytes are left there and the tune is 695. It
\ goes in sideways bank 3, which has 11,337 bytes free in this build and
\ which rupt_vsync already pages in for the music every single field - so
\ the replay reads it with no paging change at all. The address is absolute
\ because AKL data is: tools/export_music_akl.py exports it there.
\ AKL's linker encodes a transposition only when it CHANGES and the player
\ starts at zero, so a song whose FIRST position is transposed depends on
\ AT2's exporter writing it there - and for WON4 it does not. Without these
\ the finale plays 216 frames in the wrong key, in tune with itself, with
\ nothing to say so. akl_init clears t_transp and does not read the linker,
\ so setting them straight after it is the whole fix. export_music_akl.py
\ --check reads the true triple out of Arkos's own AKM export and fails if
\ this disagrees. See ../arkos-player-bbc/docs/format-akl.md.
WIN_TRANSP0 = 0
WIN_TRANSP1 = -3
WIN_TRANSP2 = -7

\ GFX_CPC builds the game from the Amstrad CPC port's artwork instead of the
\ C64's - every sprite frame, every character - for the comparison decision 41
\ left open. Smila redrew the lot in mode 0's sixteen colours, and the CPC's
\ frame, character and tile NUMBERS are the C64's exactly, so nothing but the
\ pixels changes: the tile table, the map, col_decode, the wave table and
\ dp_dcd are shared. Passed on the command line beside RELEASE for the same
\ reason: beebasm has no IFDEF and refuses a symbol defined twice.
\
\ tools/export_tiles.py --cpc and tools/export_sprites.py --cpc write the
\ data; tools/render_bbc.py --cpc renders it back for checking.
ASSERT GFX_CPC=0 OR GFX_CPC=1

\ Build flag for lib/vgiplayer.asm, which the library expects on the command
\ line; set here instead so a bare beebasm invocation cannot get it wrong.
\ 0 is the compact looped decoder, 1 the unrolled one - half a K more code
\ for about 300 cycles a field.
VGI_UNROLL = 0

\ Sprites are SCREEN space and do not take the scroll's half-byte bank
\ phase, so this is 0. Both banks are drawn at the same origin
\ (corner_addr + 8) and displayed at the same CRTC address - the
\ picture's one-pixel offset is in the map content, not in the window -
\ so the same sprite bytes at the same address stand still under both.
\ Set it to 1 if that turns out to be the wrong way round: a sprite
\ that should be still would then shimmer one pixel at 50 Hz.
SPR_PHASE_MASK = 0

\ Hardware
CRTC_ADDR     = &FE00
CRTC_DATA     = &FE01
VIDEO_ULA_PAL = &FE21
NULA_CTRL     = &FE22       ; VideoNuLA control; &40 resets its state
NULA_PAL      = &FE23       ; VideoNuLA palette, TWO bytes an entry
IRQ1V         = &0204
SYS_VIA_T1CL  = &FE44
SYS_VIA_T1CH  = &FE45
SYS_VIA_T1LL  = &FE46
SYS_VIA_T1LH  = &FE47       ; latch only - does not reload the counter
SYS_VIA_ACR   = &FE4B
SYS_VIA_IFR   = &FE4D
SYS_VIA_IER   = &FE4E
USR_VIA_IER   = &FE6E
KBD_PORTB     = &FE40       ; addressable latch: (value << 3) | line
KBD_DDRA      = &FE43
KBD_ORA       = &FE4F       ; port A, no handshake
KBD_LATCH_OFF = &03         ; line 3 = 0: stop the free-run scan
KBD_LATCH_ON  = &0B         ; line 3 = 1: hand it back
KBD_DDRA_SCAN = &7F         ; PA0-PA6 out (key number), PA7 in

\ Frame geometry: 39 rows = 312 scanlines, the MODE 2 shape.
\ Cycle A = the panel, cycle B = play area + everything down to VSync.
PANEL_ROWS  = 5             ; C64 status bar: rows 0-4
PLAY_ROWS   = 20            ; C64 playfield: rows 5-24
PANEL_R4    = PANEL_ROWS - 1
PLAY_R4     = 39 - PANEL_ROWS - 1          ; 33
PLAY_R7     = 34 - PANEL_ROWS              ; VSync at absolute row 34, as MODE 2
\ The panel lives INSIDE the shadow-switched region and is drawn into both
\ banks (decision 17). It was at &2000 first, which jsbeeb displayed under
\ both shadow states and b-em showed as garbage every other frame: what the
\ video circuit fetches below &3000 with the D bit set is emulator-dependent,
\ so nothing displayed may live there. Every write to the panel goes to both
\ banks: see panel_init.
PANEL_ADDR  = &3000
PANEL_BYTES = PANEL_ROWS * row_stride      ; 3200, to &3C7F
ASSERT PANEL_ADDR + PANEL_BYTES <= screen_start

\ &3C80-&3FFF: 896 bytes in EACH bank, above the panel and below the play
\ buffer, fetched by NEITHER rupture cycle. It was listed in
\ docs/memory-map.md as room going spare and Layer 9e is what spends the
\ first of it: the titles' second credit set, carried there by the PANEL
\ disc file, which is unpacked into both banks at boot anyway (decision 53).
TTL_EXTRA      = PANEL_ADDR + PANEL_BYTES   ; &3C80
TITLE_GLYPH_BYTES = 16              ; 2 byte columns x 8 scanlines, one cell
TITLE_LINE_LEN = 38                 ; the C64's own cpx #$26
TITLE_LINES   = 5
\ And after the second credit set, the redefine screen's text (Layer 9h,
\ decision 71) - the five labels, the eight key names and the three messages,
\ as GLYPH NUMBERS, written by tools/export_title.py. Here rather than in
\ bank 1 with the code that reads them for the reason decision 53 put the
\ credits here: it is data, it is loaded, it rides into both banks on the
\ PANEL file for nothing, and bank 1's hole is where the code has to go.
\
\ EVERY RECORD IS A FIXED WIDTH, which is what makes the composer three
\ straight copies with no length arithmetic and no terminators. A screen line
\ is built by filling 38 blanks, copying an 8-byte label to column 1 and
\ copying the value to column 26 - eight bytes if it is a key name, twelve if
\ it is a message. The longest name is RETURN at six and the longest message
\ is ALREADY USED at twelve; export_title.py asserts both.
KR_REC         = 8                  ; a label or a key name
KR_LABELS      = 5                  ; LEFT RIGHT UP DOWN FIRE, in ASK order
KR_NAMES       = 9                  ; the nine keys that are not letters
KR_MSG_REC     = 16                 ; a message, of which twelve are drawn
KR_MSGS        = 2                  ; PRESS A KEY / ALREADY USED. There is no
                                    ; RESERVED any more: pause and mute are
                                    ; CTRL+P and CTRL+Q, so nothing a player
                                    ; can press on that screen is refused
KR_HEAD_REC    = 16                 ; REDEFINE KEYS, the heading line
KR_MSG_OFF     = (KR_LABELS + KR_NAMES) * KR_REC
KR_HEAD_OFF    = KR_MSG_OFF + KR_MSGS * KR_MSG_REC
KR_TEXT_BYTES  = KR_HEAD_OFF + KR_HEAD_REC
TTL_KRTEXT     = TTL_EXTRA + TITLE_LINE_LEN * TITLE_LINES

\ And its three tables, which are here rather than in bank 1 beside the code
\ that reads them for one reason: the code came in 69 bytes over what bank
\ 1's hole has, and these are 44 of them. They are assembled here, not
\ generated, because the key numbers are MEASURED HARDWARE FACTS and belong
\ in the source a person reads, not in a .bin.
KR_CANDS       = 35                 ; bindable keys: 26 letters and nine more
KR_LINES       = TITLE_LINES + 1     ; the heading, then the five controls
KR_TAB_BYTES   = KR_CANDS + KR_LABELS + KR_LABELS

TTL_SCROLL     = TTL_KRTEXT + KR_TEXT_BYTES + KR_TAB_BYTES
                                    ; and after them the zoom scroller's
                                    ; message, from assets/scrolltext.txt.
                                    ; It was behind the font in bank 1,
                                    ; which had ELEVEN bytes of headroom -
                                    ; no use for a file meant to be edited
TTL_CRED_C64   = 0                  ; which set: an index, not a pointer
TTL_CRED_BBC   = 1
ASSERT TTL_SCROLL <= screen_start

\ The starfield (Layer 9c): ten stars standing still on the screen while
\ the level scrolls under them. The code and the tables are in bank 1;
\ what is here is the per-bank record of which of them are on screen, one
\ byte a star, the banks STAR_BANK apart so that &FE34's X bit shifts
\ twice into the index. The stars are the CPC port's, not the C64's -
\ see src/bank1.asm.
STAR_COUNT = 10
STAR_BANK  = 16             ; stride between the two banks' flags
ASSERT STAR_BANK >= STAR_COUNT
\ The loading screen (Layer 9a): a full MODE 2 picture in main RAM, shown
\ while the banks load. It is the MOS's own screen address, because the
\ mode change now happens FIRST and the picture is simply what MODE 2 is
\ displaying. Two halves, because of where their streams have to sit.
LOADSCR_ADDR  = &3000
LOADSCR_ADDR2 = &5800       ; halfway: 16 of the 32 character rows
ASSERT LOADSCR_ADDR2 - LOADSCR_ADDR = 16 * row_stride

\ Where a ZX0 stream is staged before it is unpacked (decision 38).
\ LOAD_STREAM is main RAM below the screen, the only ground the loading
\ screen's own stream can use: ZX0 unpacks forwards, so a stream may not be
\ overtaken by its own output, and one covering the whole 20K screen would
\ have to start above &8000 to stay ahead of it. It is also the ceiling of
\ the code image - the depacker is boot code and is allowed to run past
\ SPR_SAVE's base, which nothing reads until the game starts.
\ DEPK_STREAM is the SHADOW screen, free the whole time the picture is up in
\ main, and roomy: the four bank streams and the music's go there.
\ It moved from &2200 to &2400 in Layer 9d: the code image had nine bytes
\ left and the memorial needed twenty. What it costs is the loading
\ screen's own headroom - LOADSC2's stream is 2,820 bytes and the gap to
\ &3000 is now 3,072 - and tools/make_disc.py refuses to write an image
\ where that has been overrun, so it cannot go wrong quietly.
LOAD_STREAM = &2400
DEPK_STREAM = &3000
\ ANDY's stream needs a staging address of its own, because it is the one
\ file that cannot be unpacked when it is loaded: the depacker would be
\ writing into ANDY while the filing system was still running, and nothing
\ says the filing system does not use ANDY itself. So it is loaded before
\ MUSIC, sits here through MUSIC's load, and is unpacked afterwards, when
\ the disc is finished with for good. It shares the shadow screen with
\ DEPK_STREAM, above everything that stages there.
ANDY_STREAM = &6800
\ And where !BOOT is ASSEMBLED - it is never loaded anywhere, it is a disc
\ file the MOS *EXECs. Inside the sprite saves, which do not exist at
\ assembly time and are not written until the first sprite is drawn.
BOOT_STAGE  = &2600
CODE_TOP    = LOAD_STREAM   ; and &2000-&2FFF is the Layer 3 sprite saves,
                            ; which boot code may sit in and boot streams fill

\ T1 runs at 1 MHz: one scanline = 64 ticks. Fire 1 lands on A row 2,
\ fire 2 on B row 2 (see rupture.asm). -4 scanlines for the CA1 service
\ latency measured in Paradroid; the windows are 4 and 33 rows wide.
SL      = 64
T1_TUNE = -4 * SL
T1_I1   = (5 + 2) * 8 * SL - 2 + T1_TUNE   ; VSync (row 34) -> A row 2
T1_I2   = 5 * 8 * SL - 2                   ; A row 2 -> B row 2
T1_I3   = 250 * SL                         ; B row 2 -> never (VSync restarts T1 first)
ASSERT T1_I3 > (PLAY_R7 - 2) * 8 * SL
ASSERT T1_I3 < 65536

FRAME_LOCK = 2              ; fields per game frame: 25 Hz


\ ******************************************************************
\ *	The titles page (Layer 6e): four CRTC cycles, two hardware
\ *	scrolled zoom bands, one in each shadow bank
\ ******************************************************************
\ *	The C64's 5-row status bar and 20 rows of titles are our panel and
\ *	our play area, so its rows 5-24 are our play rows 0-19 and the page
\ *	transcribes 1:1 with nothing re-centred:
\ *
\ *	  cycle A  abs  0-4    5 rows, all shown    panel, &3000, MAIN
\ *	  cycle B  abs  5-11   7 rows, 6 shown      top band, ring in MAIN
\ *	  cycle C  abs 12-18   7 rows, 6 shown      credits, &4000, SHADOW
\ *	  cycle D  abs 19-38  20 rows, 6 shown      bottom band, ring in SHADOW
\ *
\ *	The blank 7th row of B and C is the C64's own blank row either side
\ *	of the credits, and B's is where the display bank is switched: it is
\ *	fetched by nobody, so the write has a whole row of slack.
\ *
\ *	The bands are hardware-scrolled by R12/R13, which needs a ring, and
\ *	the display wrap gives exactly one per bank: at 8K it is &6000-&7FFF,
\ *	1,024 byte columns against the 480 a six-row band shows. Measured in
\ *	jsbeeb 2026-09-04 - the four sizes are 20K, 16K, 10K and 8K, and 8K
\ *	is latch line 4 high, line 5 low. See CLAUDE.md.
TTL_RING      = &6000
TTL_RING_SIZE = &2000
TTL_CRED      = screen_start        ; the credits block, 6 rows, SHADOW
TTL_BAND_ROWS = 6                   ; zoom cells high, and CRTC rows displayed
TTL_BAND_CELLS = 40                 ; 80 byte columns: the band is full width
TTL_CELL      = 16                  ; 2 byte columns x 8 scanlines
TTL_CYC_ROWS  = 7                   ; cycles B and C: 6 shown, 1 blank
TTL_PANEL_R4  = PANEL_ROWS - 1
TTL_BAND_R4   = TTL_CYC_ROWS - 1
TTL_LAST_R4   = 39 - PANEL_ROWS - 2 * TTL_CYC_ROWS - 1      ; cycle D: 19
TTL_R7        = 34 - PANEL_ROWS - 2 * TTL_CYC_ROWS          ; VSync, abs row 34
ASSERT TTL_R7 > TTL_BAND_R4         ; so R7 is a constant: it cannot fall in A, B or C
ASSERT TTL_R7 < TTL_LAST_R4
ASSERT TTL_RING + TTL_BAND_ROWS * row_stride <= TTL_RING + TTL_RING_SIZE
ASSERT TTL_CRED + TTL_BAND_ROWS * row_stride <= TTL_RING

\ Five T1 fires instead of the game's two. The first two intervals are the
\ game's own - cycle A is the same 5 rows and B starts in the same place.
\   fire 1  abs  2   A row 2   R4 for A, R6 and R12/13 for B
\   fire 2  abs  7   B row 2   R4 for B (C inherits it), R6 and R12/13 for C
\   fire 3  abs 11   B row 6   display bank -> SHADOW, in a blank row
\   fire 4  abs 12   C row 0   R6 and R12/13 for D, then the first raster
\   fire 5  abs 17   C row 5   the second raster
\   fire 6  abs 20   D row 1   R4 for D
\
\ Fire 6 exists because R4 must be written INSIDE its own cycle and every
\ other candidate is outside D. Fire 5 is still in C, where R4 = 19 would
\ stretch C to twenty rows; and the VSync handler is too late in a worse
\ way - with R4 still 6 from cycle C, D would never reach R7 = 15, so
\ VSync would never happen and the handler that was to fix it would never
\ run. Measured the hard way: the first build hung in field_wait.
TTL_T1_I3 = 4 * 8 * SL - 2          ; fire 2 -> fire 3
TTL_T1_I4 = 1 * 8 * SL - 2          ; fire 3 -> fire 4
TTL_T1_I5 = 5 * 8 * SL - 2          ; fire 4 -> fire 5
TTL_T1_I6 = 3 * 8 * SL - 2          ; fire 5 -> fire 6


\ ******************************************************************
\ *	ZERO PAGE
\ ******************************************************************

ORG &00
GUARD &9F

.tile_cnt       skip 1      ; which column within a tile
.tile_total     skip 1      ; how many tiles have we covered?

.char_col       skip 1      ; incremented per pixel / tick - NEED BETTER NAME!

.corner_addr    skip 2      ; address of top left corner of screen buffer
.crtc_addr      skip 2      ; start address of visible screen in CRTC chars

.read_ptr       skip 2      ; generic read ptr
.write_ptr      skip 2      ; generic write ptr

.sprite_idx     skip 1      ; temp for the panel test pattern

.x_count        skip 1      ; temp for sprite_plot
.y_count        skip 1      ; temp for sprite_plot

\\ Sprite engine (src/sprite.asm). bufp/svp/src are the blitter's three
\\ pointers; the rest is one sprite's working state, live only inside
\\ spr_draw_slot.
.bufp           skip 2      ; the screen byte being drawn
.svp            skip 2      ; the matching byte of the slot's save page
.src            skip 2      ; the frame's data, in the paged-in sprite bank
.spr_slot       skip 1      ; 0-7
.spr_idx        skip 1      ; spr_bank8 + spr_slot: the per-bank state index
.spr_bank8      skip 1      ; 8 while the CPU writes the shadow bank, else 0
.spr_phase      skip 1      ; 1 while the bank being drawn is the odd pixel
.spr_frame      skip 1      ; 0-118, from sprite_dp through sprite_dp_dcd
.spr_y          skip 1      ; the C64 y of the sprite in hand
.spr_c          skip 1      ; signed byte column, while it is being worked out
.spr_c0         skip 1      ; first byte column drawn, 0-79
.spr_r0         skip 1      ; first scanline drawn, 0-159
.spr_cols       skip 1      ; the frame's box width = its data row stride
.spr_rows       skip 1      ; rows left to draw
.spr_count      skip 1      ; byte columns actually drawn, 1-7
.spr_skip_c     skip 1      ; columns and rows clipped off the left and top
.spr_skip_r     skip 1
.spr_scan       skip 1      ; scanline within the first character row
.spr_wrap       skip 1      ; one of this sprite's character rows crosses the end
.spr_split      skip 1      ; byte columns of THIS character row before it, 0 = whole
.spr_bias       skip 1      ; spr_split * 8: the same step along screen and save
.spr_entry      skip 2      ; the whole-row body, for the split body to tail into
.spr_tmp        skip 2      ; scratch: the bufp arithmetic and the straddle walk

\\ Player and collisions (src/player.asm)
.joy            skip 1      ; the C64's joystick byte: a CLEAR bit is pressed
.joy_idx        skip 1      ; which key read_joystick is asking about

\\ The five bindings, UP DOWN LEFT RIGHT FIRE, and IN ZERO PAGE ON PURPOSE
\\ (Layer 9h, decision 71). Three things follow from it and the third is the
\\ reason: read_joystick's `ldx joy_keys, y` becomes zero-page,Y, which is a
\\ legal mode for LDX and one byte shorter than it was; every `ldx #KEY_FIRE`
\\ becomes `ldx joy_keys + JOY_FIRE` at the SAME two bytes, so bank 0 - which
\\ has nine bytes left - does not grow; and zero page is wiped once at boot
\\ and never again, so a redefinition survives a game, the finale and the
\\ return to the titles for nothing. key_init fills it, after the wipe.
.joy_keys       skip JOY_COUNT

\\ Auto-fire (Layer 9i, decisions 73 and 74), and it is IN ZERO PAGE FOR THE
\\ SAME REASON joy_keys is: this byte is what fire_bullet writes into
\\ fire_latch, so `lda af_latch` stands where the C64's `lda #1` stood at the
\\ same two bytes and the same two cycles.
\\
\\ AF_OFF is the C64's own latch: negative, and only a release clears it.
\\ AF_ON is a countdown that the held path decrements once a game tick, so
\\ holding fire has a floor on its rate while a TAP still gets the next shot
\\ as early as the bullet slot allows (decision 74). key_init sets AF_OFF,
\\ and zero page is wiped once at boot and never again, so the choice
\\ survives a game, the finale and the titles.
.af_latch       skip 1

\\ And auto-fire's other two bytes, HERE rather than in the &0800 block
\\ beside mute_was, which is what they otherwise look like. Bank 2's tail is
\\ the tightest ground in the build - 43 bytes in a DEV -Nula one and
\\ ttl_auto_key wanted 45 of them - and zero page had 66 going spare, so
\\ each `sta`, `eor` and `dec` being a byte shorter here is what made the
\\ routine fit. Both are wiped to 0 at boot, which is the right start for
\\ each: no key held, and no message on the clock.
.fire_latch     skip 1      ; set while fire is held, so it does not repeat: AF_OFF
                            ; until a release, or AF_ON counting down. IN ZERO PAGE
                            ; and not in the &0800 block with the rest of the C64's
                            ; $0340 (decision 74) - six references in player_manage,
                            ; a byte each, which is most of what the held path cost
.auto_was       skip 1      ; CTRL+A's edge state: &80 both down, else 0
.ttl_auto_tmr   skip 1      ; fields the message has left, TTL_AUTO_HOLD down
                            ; to 0; bank 3's title_auto reads 0 as "blank"
.coll_row       skip 1      ; play-area character row being sampled
.coll_col       skip 1      ; and screen character column, 0-39
.coll_base      skip 1      ; coll_map slot holding screen column 0
.coll_wr        skip 1      ; and the slot the entering character goes in

.plane_hi       skip 1      ; HI(char_data) + 8 * (char_col AND 3): this frame's column plane

.frame_count    skip 1      ; game frames (25 Hz), for animation timing
.field_count    skip 1      ; fields (50 Hz), incremented by the VSync IRQ
.flip_field     skip 1      ; field_count at the last bank flip
.frame_ready    skip 1      ; main loop -> IRQ: hidden bank is drawn, flip at next VSync
.crtc_park      skip 2      ; scroll address for the bank being drawn (main loop writes)
.crtc_live      skip 2      ; scroll address the IRQ programs at fire 1
.rupt_state     skip 1      ; 0 = fire 1 pending, 1 = fire 2 pending, 2 = done

IF MUSIC_AKL
\ The player's working pointers, 22 bytes, from the library's own header -
\ this file is a VERBATIM copy of arkos-player-bbc's lib/aklplayer.h.asm and
\ is never edited here (decision 4 there, decision 70 here). Everything else
\ the player keeps - the per-channel state, the tables, the register file -
\ is absolute, up in HAZEL with the code, so only the indirect reads are down
\ here.
INCLUDE "lib/aklplayer.h.asm"
ELSE
\ The VGI music player's four bytes (lib/vgiplayer.h.asm): two indirect
\ pointers. Everything else it keeps is absolute, up in HAZEL with the code.
INCLUDE "lib/vgiplayer.h.asm"
ENDIF

\ The ZX0 depacker (src/zx0depack.asm) borrows six of the above. It runs
\ only at boot, before any of them is live, and it is over before the
\ first sprite is drawn. Declared HERE rather than in the depacker so
\ beebasm sees them before the loader's first zero-page reference: an
\ undefined symbol in pass 1 assembles as an absolute address and the
\ pass-2 size change is an error.
zxsrc = read_ptr            ; -> the compressed stream
zxdst = write_ptr           ; -> the output
zxofs = bufp                ; the current offset
zxlen = svp                 ; gamma accumulator / count
zxbit = spr_slot            ; the bit buffer, sentinel-marked
zxwrk = spr_tmp             ; -> the copy source

IF DEBUG_TIMING
.tim_ptr        skip 2      ; the maximum slot the next mark writes
.tim_val        skip 2      ; us since tim_start, at the last mark
.tim_prev       skip 2      ; and what it was at the mark before that
.tim_phase      skip 2      ; the difference: one phase of the loop
ENDIF

\ joy_keys HAS to be in zero page and not merely happen to be: every
\ `ldx joy_keys + JOY_FIRE` is sized on the first pass, and if one ever
\ assembled as absolute it would grow bank 0 - which has nine bytes - by a
\ byte a site, silently, in a build that still looked right here.
ASSERT joy_keys + JOY_COUNT <= &100

\ ******************************************************************
\ *	CODE START
\ ******************************************************************
ORG &E00
GUARD CODE_TOP

.start

\ ******************************************************************
\ *	Code entry
\ ******************************************************************

.code_start

.main
{
    txs

    \\ BREAK must clear memory from here on (KC). We take HAZEL, which is the
    \\ filing system's own workspace, so once MUSIC is copied up there the DFS
    \\ workspace is gone. A SOFT break leaves it that way and the machine comes
    \\ back with no filing system at all - measured: no DFS banner and *CAT
    \\ returns nothing. OSBYTE 200 bit 1 makes BREAK behave as a power-on reset,
    \\ which re-initialises it; bit 0 disables ESCAPE with it, which is welcome
    \\ anyway - it cannot abort the bank loads, and we read the ESCAPE key
    \\ straight off the VIA matrix rather than through the MOS.
    \\
    \\ First thing done, before anything can be interrupted or broken into.
    lda #200
    ldx #3
    ldy #0
    jsr osbyte

    \\ Blank the display until the loading screen is unpacked: whatever
    \\ mode the machine booted in, its screen is about to be walked over.
    \\ R8 skew bits (Paradroid's R8_BLANK); VDU 22 resets R8, so the mode
    \\ change writes it again, and so does setup_display after the clears.
    CRTC 8, &30
    CRTC 10, &20                ; and the MOS cursor, which R8 does not hide

    \\ Wipe ZP

    ldx #0
    lda #0
    .zp_loop
    sta &00,x
    inx
    cpx #&a0
    bcc zp_loop

    \\ And the five key bindings, which live in the zero page just wiped
    \\ (Layer 9h, decision 71). Key 0 is SHIFT, so a wiped joy_keys is not
    \\ merely wrong, it is five controls all bound to the same key.
    jsr key_init


    \\ Mode change FIRST now, not last: the loading screen is a MODE 2
    \\ picture and it has to be up before the banks come in. The old
    \\ ordering was there because the banks staged through &4000, which
    \\ MODE 2 puts on screen; they stage in the SHADOW screen now, so
    \\ there is nothing left to hide.
    lda #22
    jsr oswrch
    lda #2
    jsr oswrch
    CRTC 8, &30                 ; VDU 22 turned the display back on
    CRTC 10, &20                ; and put the cursor back

    \\ The loading screen: two halves into main &3000-&7FFF, each from a
    \\ stream staged at LOAD_STREAM below it.
    lda #LO(loadsc1_filename)
    ldy #HI(loadsc1_filename)
    ldx #HI(LOAD_STREAM)
    jsr load_stream
    lda #LO(LOADSCR_ADDR)
    ldx #HI(LOADSCR_ADDR)
    jsr unpack_to

    lda #LO(loadsc2_filename)
    ldy #HI(loadsc2_filename)
    ldx #HI(LOAD_STREAM)
    jsr load_stream
    lda #LO(LOADSCR_ADDR2)
    ldx #HI(LOADSCR_ADDR2)
    jsr unpack_to

    CRTC 8, 0                   ; and there it is

    \\ Display MAIN (D=0), CPU sees SHADOW (X=1). That is the state the
    \\ game itself runs in, and here it is what keeps the picture up:
    \\ every stream from now on stages in the shadow screen at
    \\ DEPK_STREAM, which is 20K of RAM nobody is looking at.
    lda &fe34
    and #255-1
    ora #4
    sta &fe34

    \\ Load the SWRAM banks: 0 = chars/tiles/map (slot 4), 1 = sprites (slot 5).
    \\ Bank 0 is the resting state; only plot_sprite pages bank 1 in.

    lda #LO(bank0_filename)
    ldy #HI(bank0_filename)
    ldx #SWRAM_DATA
    jsr load_bank

    lda #LO(bank1_filename)
    ldy #HI(bank1_filename)
    ldx #SWRAM_SPRITES0
    jsr load_bank

    lda #LO(bank2_filename)
    ldy #HI(bank2_filename)
    ldx #SWRAM_SPRITES1
    jsr load_bank

    lda #LO(bank3_filename)
    ldy #HI(bank3_filename)
    ldx #SWRAM_COMPILED
    jsr load_bank

    \\ The panel image: loaded, not unpacked. Its stream sits at
    \\ LOAD_STREAM until setup_display asks for it, and panel_init then
    \\ unpacks it straight into &3000 in each bank - the only two places
    \\ it is ever wanted. Nothing else touches LOAD_STREAM from here on.
    lda #LO(panel_filename)
    ldy #HI(panel_filename)
    ldx #HI(LOAD_STREAM)
    jsr load_stream

IF MUSIC_AKL = 0
    \\ ANDY's share of the tune: loaded here, unpacked below. See
    \\ ANDY_STREAM for why the two are not together.
    lda #LO(andy_filename)
    ldy #HI(andy_filename)
    ldx #HI(ANDY_STREAM)
    jsr load_stream
ENDIF

    \\ MUSIC goes into HAZEL, and HAZEL is the filing system's own
    \\ workspace, so it must be the LAST file loaded. Nothing may touch
    \\ the disc after this.
    lda #LO(music_filename)
    ldy #HI(music_filename)
    jsr load_hazel

IF MUSIC_AKL = 0
    jsr unpack_andy             \\ and now the disc is finished with
ENDIF

    \\ The memorial (Layer 9d, decision 52): the loading picture fades
    \\ out on the palette, "IN MEMORY OF T.M.R." fades up in the
    \\ credits' own font, and it fades out again into the titles. It
    \\ takes the interrupts down with it and leaves them down;
    \\ install_irq is the next CLI.
    jsr memorial

    lda #SWRAM_DATA
    sta &f4
    sta &fe30

    CRTC 8, &30                 ; the loading screen has done its job
    jsr setup_display           ; blanked until the buffers and panel are drawn
    jsr score_boot              ; the C64's initialised score, lives and 012345
    ldx #LO(music_init)         ; the tune starts before the titles and loops
    ldy #HI(music_init)
    jsr bank3_call

    \\ Initialise variables

IF DEBUG_TIMING
    jsr tim_init
ENDIF
    jsr install_irq

    \\ ---- the state machine, the C64's master_loop --------------------
    \\
    \\ Titles -> game_init -> the play loop -> life lost -> game over or
    \\ completion -> titles. Only the titles are a loop of their own,
    \\ because only they hold a still picture. Playing, game over and
    \\ completion all differ in what the TICK does and not in what the
    \\ frame does, so they share this loop and are told apart by
    \\ game_mode, which says which of the original's loops the tick is
    \\ standing in for.
    \\
    \\ game_init is called HERE, at the top, and the loop leaves through
    \\ the bottom: scroll_prewind flips &FE34 itself, and frame_ready has
    \\ to be 0 while it does, which it is everywhere outside the loop.

    .master_loop
    jsr title_page              \\ static credits, returns when fire is hit
    jsr game_init

    \\ No star is on screen: game_init has just wound a fresh screen in
    \\ under them, and a flag left set from the last game would have the
    \\ wipe punch a black byte into it that nothing repaints for six
    \\ seconds. After game_init, because the wind is what clears them.
    lda #SWRAM_SPRITES0
    ldx #LO(star_init)
    ldy #HI(star_init)
    jsr bank_call

    .loop

IF DEBUG_TIMING
    jsr tim_start
ENDIF

    \\ Every sprite's background comes back before anything is drawn:
    \\ a draw between another slot's restore and its draw would be
    \\ captured into that slot's save. The new scroll column is not.

    jsr spr_restore_all
    TIMMARK TIM_RESTORE

    lda char_col
    and #SPR_PHASE_MASK
    sta spr_phase

    \\ The finale's background stands still: the C64's cm_splode_wait
    \\ calls neither scroll_manage nor anything that plots, so the level
    \\ stops where the player left it and only the bangs move.
    lda game_mode
    cmp #MODE_FINALE
    beq no_scroll
    jsr scroll_frame            \\ plots this frame's byte column

    \\ The stars go on after the scroll and before the sprites: over the
    \\ scenery, under everything that flies. In the finale, with the
    \\ level standing still, they stand still with it - which is why they
    \\ are inside this test and not below it. corner_addr does not move
    \\ there, so the wipe's "one byte column back" would be the star's
    \\ own byte and it would rub itself out.
    lda #SWRAM_SPRITES0
    ldx #LO(star_frame)
    ldy #HI(star_frame)
    jsr bank_call
    .no_scroll
    TIMMARK TIM_SCROLL
    jsr spr_draw_all
    TIMMARK TIM_DRAW

    \\ Game logic. Two ticks a frame: one pass of this loop is two of the
    \\ C64's, so its per-frame constants transcribe unchanged (decision 23).
    \\ The joystick is read once - it cannot change between the two.

    jsr read_joystick
    jsr pause_check
    jsr game_tick
    jsr game_tick

    lda game_mode
    cmp #MODE_FINALE
    beq no_advance
    jsr scroll_advance          \\ AFTER the draw - see scroll_advance
    .no_advance

    \\ The panel last: the C64 runs status_decode from its raster interrupt
    \\ and nothing else this frame touches &3000. It writes only the cells
    \\ that have changed in the bank the CPU owns, so a still frame costs
    \\ eighteen compares and nothing else.
    jsr status_call
    TIMMARK TIM_LOGIC

    inc frame_count
    jsr frame_wait

    \\ The game-over count and the completion sequence both end by asking
    \\ for the titles again; nothing else leaves this loop.
    lda to_titles
    beq loop
    jmp master_loop

    .done

    rts
}

\ ******************************************************************
\ *	frame_wait - hand the frame over and wait for the flip
\ ******************************************************************
\ *	The bottom of every playing frame. The loop has drawn into the
\ *	hidden bank; this parks that bank's scroll address, sets the ready
\ *	flag and spins until the VSync handler has flipped and taken it.

.frame_wait
{
    sei
IF DEBUG_TIMING
    \\ Inside the SEI so field_count cannot move under the subtraction.
    jsr tim_handover
ENDIF
    lda crtc_addr
    sta crtc_park
    lda crtc_addr+1
    sta crtc_park+1
    lda #1
    sta frame_ready
    cli
    .wait_flip
    lda frame_ready
    bne wait_flip
    rts
}

\ ******************************************************************
\ *	bank3_call - page bank 3 in, call X/Y, page SWRAM_DATA back
\ ******************************************************************
\ *	In main RAM because it has to be: nothing in a sideways bank can
\ *	page its own bank out from under itself, and bank 0 - where every
\ *	caller sits - is a sideways bank too. Bank 3 holds the titles' font
\ *	and text, the panel image and the HUD, because it is the only bank
\ *	with room; SWRAM_DATA is the resting state everything else assumes.
\ *
\ *	X = LO, Y = HI of the routine in bank 3. Self-modifying rather than
\ *	one entry a routine: main RAM has tens of bytes left, not hundreds.
\ *	Not re-entrant, and nothing calls it from an interrupt.
\ *
\ *	WHAT IT PAGES BACK IS bank_restore, NOT A CONSTANT (Layer 9h,
\ *	decision 71). SWRAM_DATA is the resting state and stays the
\ *	default; the one caller that changes it is the redefine screen,
\ *	which lives in bank 1 and calls this to have its block painted
\ *	out of bank 3. The narrow rule that makes that legal is worth
\ *	stating, because the wide one in CLAUDE.md is not quite it: a
\ *	sideways bank may jsr main-RAM code freely - field_wait and
\ *	keydown touch no bank and are called from bank 1 all day - and
\ *	what it may not do is call main-RAM code that pages a DIFFERENT
\ *	bank in and then restores somebody else's. With bank_restore that
\ *	is exactly what this no longer does.
\ *
\ *	One byte of state, so this is still not re-entrant and still not
\ *	callable from an interrupt. Both were already true.

.bank3_call
    lda #SWRAM_COMPILED
\ A = the bank, X = LO, Y = HI. The titles' zoom scroller lives in bank 1,
\ whose sprite data nothing on that page reads.
.bank_call
    stx bank_call_t+1
    sty bank_call_t+2
    sta &f4
    sta &fe30
    jsr bank_call_t
    lda bank_restore
    sta &f4
    sta &fe30
    rts
.bank_call_t
    jmp &ffff                   ; written above
.bank_restore
    EQUB SWRAM_DATA             ; the resting state, and what every caller
                                ; but kr_run leaves it at

\ ******************************************************************
\ *	field_wait - one field, WITHOUT handing a frame over
\ ******************************************************************
\ *	What a frozen screen waits on: the pause loop and the titles. The
\ *	flip only happens when frame_ready is set, so leaving it alone
\ *	keeps the displayed bank displayed - a paused picture that is
\ *	genuinely still, rather than the last two frames alternating at
\ *	25 Hz, which is what handing frames over would give.

.field_wait
{
    lda field_count
    .same
    cmp field_count
    beq same
    rts
}

\ ******************************************************************
\ *	scroll_frame - plot one byte column and advance the scroll
\ ******************************************************************
\ *	The whole of a frame's scroll work, lifted out of the main loop so
\ *	that scroll_prewind can run it before the game starts. It reads
\ *	char_col, draws that pixel column of the incoming characters, and
\ *	leaves char_col, tile_cnt, the collision ring, crtc_addr and
\ *	corner_addr on the next frame's values.
\ ******************************************************************

.scroll_frame
{
    \\ Start column plot

    jsr set_corner_addr
    jsr coll_frame_start        ; where plot_char_y files this column's codes

    \\ Select this frame's column plane (2K per plane, pixel column = char_col AND 3)

    lda char_col
    and #3
    asl a: asl a: asl a
    clc
    adc #HI(char_data)
    sta plane_hi

    \\ The right-hand column is NOT shifted here any more. copy_column_buffer
    \\ does it on the way out at the bottom of the frame, which is the same
    \\ shift one frame earlier and saves a whole 160-byte pass.

    \\ Column reader for tile 1

    ldx tile_cnt
    jsr tile_read_1

    \\ Gives character value in y - C64 can store this in character map, we need to plot to screen
    jsr plot_char_y

    \\ Add 4 to index as each tile has stride of 4
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_1
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_1
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_1
    jsr plot_char_y

    \\ Tile 2

    ldx tile_cnt
    jsr tile_read_2
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_2
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_2
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_2
    jsr plot_char_y

    \\ Tile 3

    ldx tile_cnt
    jsr tile_read_3
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_3
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_3
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_3
    jsr plot_char_y

    \\ Tile 4

    ldx tile_cnt
    jsr tile_read_4
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_4
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_4
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_4
    jsr plot_char_y

    \\ Tile 5

    ldx tile_cnt
    jsr tile_read_5
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$04
    tax

    jsr tile_read_5
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$08
    tax

    jsr tile_read_5
    jsr plot_char_y
    lda tile_cnt
    clc
    adc #$0c
    tax

    jsr tile_read_5
    jsr plot_char_y

    \\ Now copy new right hand column to screen buffer

    jsr copy_column_buffer
    rts
}

\ ******************************************************************
\ *	scroll_advance - move the scroll on by one pixel
\ ******************************************************************
\ *	SEPARATE FROM scroll_frame, AND CALLED AFTER THE SPRITES ARE DRAWN.
\ *	Sprites are placed from corner_addr, so advancing it before the draw
\ *	puts them one byte column - two pixels - further right on the frames
\ *	where it moves and not on the others. A stationary ship then rocks
\ *	back and forth in step with the scroll, which is exactly what KC saw
\ *	when these two were one routine (BUGS.md #7). The order here is the
\ *	loop's original one: plot, draw, then advance.
\ ******************************************************************

.scroll_advance
{
    \\ Scrolling

    \\ Increment column

    ldx char_col
    inx

    \\ Two columns per character

    txa
    and #3
    bne no_bump

    \\ Bump the tile_cnt

    jsr tile_cnt_bump
    jsr coll_advance

    .no_bump

    \\ Increment scroll every other column

    txa
    and #1
    beq no_scroll

    clc
    lda crtc_addr
    adc #1
    sta crtc_addr
    lda crtc_addr+1
    adc #0
    cmp #HI(screen_top/8)
    bcc scroll_ok
    sbc #HI(screen_size/8)
    .scroll_ok
    sta crtc_addr+1
IF _DOUBLE_BUFFER
    .no_scroll

    txa
    and #1
    bne no_column
ENDIF

    clc
    lda corner_addr
    adc #8
    sta corner_addr
    lda corner_addr+1
    adc #0
    cmp #HI(screen_top)
    bcc col_ok
    sbc #HI(screen_size)
    .col_ok
    sta corner_addr+1

IF _DOUBLE_BUFFER
    .no_column
ELSE
    .no_scroll
ENDIF

    stx char_col
    rts
}

\ ******************************************************************
\ *	scroll_prewind - fill the play area before the first frame
\ ******************************************************************
\ *	THE C64 DOES THIS AND WE HAVE TO AS WELL. map_read_rst ends in what
\ *	its author calls a "Scroll fast winder for the start of game": the
\ *	whole buffer-swap cycle run 20 times, which is 40 characters, which
\ *	is exactly the width of the screen. Without it the game opens on an
\ *	empty playfield that takes a screen's worth of scrolling to fill,
\ *	and - far worse - the wave table, whose timings were authored
\ *	against a full screen, spawns its first enemies a screen ahead of
\ *	the scenery they were drawn to fly through. KC saw both: a long
\ *	blank start, and enemies that did not line up with the level.
\ *
\ *	40 characters is 160 of our frames: a character is 4 pixels wide and
\ *	we move one pixel a frame. Each frame writes one byte column into
\ *	the bank the X bit selects, so the flip has to happen here too -
\ *	the VSync handler that normally does it is not installed yet. Each
\ *	bank then gets its own 80 columns, one pixel out of phase with the
\ *	other, exactly as the running loop leaves them.
\ ******************************************************************

\ COLL_COLS is the width in CHARACTERS (40), not byte columns: a
\ character is 4 pixels wide and we move one pixel a frame, so a screen
\ is 160 frames. It is also defined above, which PLAY_COLS is not -
\ sprite.asm is included after this point and beebasm takes constant
\ assignments in file order.
SCROLL_PREWIND = 4 * COLL_COLS

.scroll_prewind
{
    lda #LO(SCROLL_PREWIND)
    sta prewind_count
    lda #HI(SCROLL_PREWIND)
    sta prewind_count+1
    .loop
    jsr scroll_frame
    jsr scroll_advance
    lda &fe34                   ; the CPU's bank, as the VSync flip does it
    eor #5
    sta &fe34
    lda prewind_count
    bne no_borrow
    dec prewind_count+1
    .no_borrow
    dec prewind_count
    lda prewind_count
    ora prewind_count+1
    bne loop
    rts
    .prewind_count EQUW 0
}

INCLUDE "src/scroll.asm"


INCLUDE "src/sprite.asm"
INCLUDE "src/player.asm"
INCLUDE "src/enemy.asm"
INCLUDE "src/keyboard.asm"
INCLUDE "src/rupture.asm"
IF GFX_NULA
IF GFX_CPC
    INCLUDE "src/data/compiled_zp-nula-cpc.asm"
ELSE
    INCLUDE "src/data/compiled_zp-nula.asm"
ENDIF
ELIF GFX_CPC
    INCLUDE "src/data/compiled_zp-cpc.asm"  \ what the compiled bodies assume
ELSE
    INCLUDE "src/data/compiled_zp.asm"      \ what the compiled bodies assume
ENDIF


\ ******************************************************************
\ *	The titles' credit crossfade - the main-RAM half (Layer 9e)
\ ******************************************************************
\ *	The state machine and the fade itself are in bank 2, which has the
\ *	room; these three are here because they are the parts that have to
\ *	reach two banks in one breath, and only main RAM can (decision
\ *	53). Called from title_page, which is in bank 0 and may therefore
\ *	call back down here and be returned to.
\ *
\ *	BELOW code_end, unlike the memorial's own half: the titles run
\ *	after a game has been played, so none of this may sit in
\ *	SPR_SAVE, where the blitter would have walked over it
\ *	(BUGS.md #13).
\ ******************************************************************

\ The C64's set is up and the clock starts. title_page has just drawn it.
\ THE BODY IS IN BANK 2 NOW (decision 72), beside the state machine it
\ starts, and only this nine-byte shim is here. It was written in main RAM
\ because bank 2's HOLE had 191 bytes in a -Cpc build and this wanted 195 of
\ them; what it has gone into is bank 2's TAIL, which had 106. The move gave
\ 26 bytes back to the ground below SPR_SAVE, which is what CTRL+Q's seven
\ and CTRL+P's thirteen are paid for out of - that region was ONE BYTE over
\ in a DEV -Akl build before it.
.ttl_cred_start
{
    lda #SWRAM_SPRITES1
    ldx #LO(ttl_cred_init)
    ldy #HI(ttl_cred_init)
    jmp bank_call               ; its rts
}


\ One field. Bank 2 does the work; if it asks for the other set, the
\ bank 3 call that paints it is ours, because bank 2 cannot make one.
.ttl_cred_tick
{
    lda #SWRAM_SPRITES1
    ldx #LO(ttl_cred_step)
    ldy #HI(ttl_cred_step)
    jsr bank_call
    lda ttl_redraw
    beq out
    lda #0
    sta ttl_redraw

    \ Which set: bank 3's own copy of the C64's, or this port's, which
    \ rides on the end of the PANEL file at TTL_EXTRA. title_text reads
    \ through the pointer either way - &3C80 is main RAM and readable
    \ with bank 3 paged in, and the CPU is looking at SHADOW here,
    \ which is the bank the credits are displayed from.
    ldx #LO(title_lines_data)
    ldy #HI(title_lines_data)
    lda ttl_c_set
    beq c64
    ldx #LO(TTL_EXTRA)
    ldy #HI(TTL_EXTRA)
    .c64
    stx ttl_cred_ptr
    sty ttl_cred_ptr+1
    ldx #LO(title_text)
    ldy #HI(title_text)
    jmp bank3_call
    .out
    rts
}

\ ******************************************************************
\ *	key_start - fire OR space, and why it is down here
\ ******************************************************************
\ *	title_page reads it and title_page is in bank 0, which had SEVEN
\ *	bytes left - so it is down here, where there are fifty. Below
\ *	code_end, because the titles run after a game has been played.
\ ******************************************************************

\ Fire OR space starts a game. Returns with N set if either is down.
\ CTRL is not tested here, and does not need to be: ttl_frame_titles in bank 1
\ runs first in the same field and takes CTRL+R away to the redefine screen,
\ which does not come back until the keyboard is clear. So a fire bound to R
\ cannot also start a game on the way in.
.key_start
{
    ldx joy_keys + JOY_FIRE
    jsr keydown
    bmi down
    ldx #KEY_START
    jmp keydown
    .down
    rts
}

\ And on the way out, whether the crossfade had finished or not:
\ logical 8 is the second black the sprite engine draws with.
\ ******************************************************************
\ *	key_pause - CTRL+P, and why the CTRL is tested first
\ ******************************************************************
\ *	Pause is CTRL+P, not P (decision 72), which is what freed P to be
\ *	a bindable control on the redefine screen: it was refused there
\ *	because a control bound to it would have paused the game every
\ *	time it was used.
\ *
\ *	CTRL FIRST, AND THAT MAKES IT FREE. This is called once a game
\ *	frame and CTRL is up in all but a handful of them, so the common
\ *	path is one keydown - exactly what the single P test used to
\ *	cost. Only the frame someone is actually pausing pays for two.
\ *
\ *	IN MAIN RAM, not in bank 0 beside pause_check, and that is the
\ *	way round that is cheaper for BOTH: bank 0 has four sites, and
\ *	each drops from `ldx #KEY_PAUSE : jsr keydown` to `jsr key_pause`,
\ *	so bank 0 GAINS eight bytes - which the DEV -Akl -Nula build had
\ *	overrun by two - while main RAM pays thirteen out of the
\ *	twenty-six ttl_cred_start's move to bank 2 gave back.
\ *
\ *	Returns N set if both are down. keydown clobbers X and Y and none
\ *	of the callers wants either.
\ ******************************************************************

.key_pause
{
    ldx #IKN_ctrl
    jsr keydown
    bpl up                      ; CTRL up: A = 0, so N is clear already
    ldx #KEY_PAUSE
    jmp keydown                 ; its N, and its rts
    .up
    rts
}

.ttl_cred_end
{
    lda #SWRAM_SPRITES1
    ldx #LO(ttl_cred_off)
    ldy #HI(ttl_cred_off)
    jmp bank_call
}

INCLUDE "src/tables.asm"

IF GFX_NULA
IF GFX_CPC
INCLUDE "src/data/palette-nula-cpc.asm"   \\ the Amstrad's own sixteen pens
ELSE
INCLUDE "src/data/palette-nula.asm"       \\ the C64's own sixteen colours
ENDIF
ELSE
INCLUDE "src/data/palette.asm"      \\ the palette setup_display writes,
                                    \\ generated from assets/art/palette.png
ENDIF

\ ******************************************************************
\ *	The loader - BOOT CODE, and therefore above code_end
\ ******************************************************************
\ *	Here, after tables.asm, for the same reason the depacker it drives
\ *	is: none of it is ever called once the game is running, so none of
\ *	it has to fit under SPR_SAVE. It used to sit with the play code,
\ *	where it was spending the tightest region in the build on routines
\ *	that are dead before the first sprite is drawn - and Layer 9d, all
\ *	twenty-odd bytes of it, was what would not fit beside them.
\ *	panel_init comes with it: setup_display calls it, and
\ *	setup_display runs once.
\ ******************************************************************

\\ ---- key_init: the five bindings, after the zero-page wipe ----------
\\
\\ BOOT CODE, up here for the same reason as the rest of it: `main` calls it
\\ once, immediately after the wipe that would otherwise leave every binding
\\ as key 0 - which is SHIFT, and would have moved the player left, right, up,
\\ down and fired all at once. joy_defaults is beside joy_mask in
\\ src/keyboard.asm, where the other four bytes of that table already are.
.key_init
{
    ldx #JOY_COUNT-1
    .copy
    lda joy_defaults, x
    sta joy_keys, x
    dex
    bpl copy

    \\ Auto-fire defaults OFF (KC, decision 73). AF_OFF is what fire_bullet
    \\ then writes into fire_latch, and it behaves as the C64's own `lda #1`
    \\ did: a latch that only seeing the button released will clear.
    lda #AF_OFF
    sta af_latch
    rts
}

\\ ---- the loader: OSFILE a ZX0 stream in, unpack it out --------------
\\
\\ Every file on the disc but Edge and !BOOT ships ZX0-compressed, with a
\\ catalogue load address tools/make_disc.py writes (decision 38). None of
\\ them could be loaded straight to where they belong even uncompressed:
\\ the filing system has the DFS ROM paged in at &8000 while it works, so
\\ a bank's bytes would land in the ROM socket, and HAZEL is the filing
\\ system's own workspace. So each stages in RAM and is unpacked from
\\ there. All of it must run before any IRQ takeover.

\\ A/Y = filename, X = the page the stream loads at. Leaves zxsrc pointing
\\ at it, ready for unpack_to.
.load_stream
{
    stx stream_page
    sta osfile_nameaddr
    sty osfile_nameaddr+1

    \\ OSFILE writes the file's catalogue addresses back into the block
    \\ after a load, so the next call would honour the last file's load
    \\ address and land wherever that was. Reset load and exec = 0 (exec
    \\ low byte 0 = "use the block's load address") every call.
    \ The load address's high word is &FFFF, not 0: to OSFILE a high
    \ word of 0 means the second processor, and with a Tube attached every
    \ file went over it instead of into the host (jsbeeb, 2026-09-11).
    lda #0
    sta osfile_loadaddr
    sta osfile_execaddr
    lda #&FF
    sta osfile_loadaddr+2
    sta osfile_loadaddr+3
    lda stream_page
    sta osfile_loadaddr+1

    ldx #LO(osfile_params)
    ldy #HI(osfile_params)
    lda #&FF
    jsr osfile

    \\ AFTER the call, not before: the depacker's zero page is borrowed
    \\ from the game's, and there is nothing to gain by setting it up
    \\ while the filing system is still running in it.
    lda #0
    sta zxsrc
    lda stream_page
    sta zxsrc+1
    rts
    .stream_page EQUB 0
}

\\ Unpack the stream at zxsrc to X:A.
.unpack_to
{
    sta zxdst
    stx zxdst+1
    jmp zx0_unpack
}

\\ The status panel into whichever bank the X bit selects. The image is
\\ not resident anywhere: it is a disc file whose ZX0 stream is still
\\ sitting at LOAD_STREAM from boot, and this unpacks it straight into
\\ the screen. Called once per bank, so the stream is read twice and
\\ zxsrc has to be pointed at it again each time - zx0_unpack walks it.
\\ Anything that draws on the panel must do it for both banks.
\\
\\ The depacker is boot code living in SPR_SAVE, which nothing reads
\\ until the first sprite is drawn; this is the last call it gets.
.panel_init
{
    lda #0
    sta zxsrc
    lda #HI(LOAD_STREAM)
    sta zxsrc+1
    lda #LO(PANEL_ADDR)
    ldx #HI(PANEL_ADDR)
    jsr unpack_to

    \\ Nothing of the HUD survives a repaint, in either bank, and the
    \\ cache that says so is in bank 3 with status_decode.
    ldx #LO(panel_dirty)
    ldy #HI(panel_dirty)
    jmp bank3_call
}

\\ A 16K bank: A/Y = filename ptr, X = SWRAM slot. The stream stages in the
\\ shadow screen, which the loading screen is not using, and unpacks
\\ straight into the paged-in bank.
.load_bank
{
    stx &f4
    stx &fe30
    ldx #HI(DEPK_STREAM)
    jsr load_stream
    lda #LO(&8000)
    ldx #HI(&8000)
    jmp unpack_to
}

IF MUSIC_AKL = 0
\\ ANDY's share of the tune, from the stream left at ANDY_STREAM. Called
\\ after MUSIC, so no disc access can follow it.
\\
\\ With interrupts off and &F4 set as well as &FE30: the MOS's own IRQ
\\ handler is still installed here, and anything that pages a ROM restores
\\ &FE30 from &F4 - which would drop ANDY out from under the depacker half
\\ way through and put the rest of the stream into bank 3. The SEI alone
\\ would do; both is cheaper than reasoning about it again.
\\
\\ It does NOT put the bank back: the caller's next three instructions
\\ select SWRAM_DATA, and main RAM has tens of bytes left.
.unpack_andy
{
    sei
    lda #ANDY_ROM
    sta &f4
    sta &fe30
    lda #0
    sta zxsrc
    lda #HI(ANDY_STREAM)
    sta zxsrc+1
    lda #LO(MUSIC_ANDY_BASE)
    ldx #HI(MUSIC_ANDY_BASE)
    jsr unpack_to
    cli
    rts                         \\ ANDY still selected: boot's next three
}                               \\ instructions put SWRAM_DATA back anyway
ENDIF

\\ MUSIC into HAZEL, the same way, with the Y bit set over the unpack.
\\ Nothing may use the disc afterwards.
.load_hazel
{
    ldx #HI(DEPK_STREAM)
    jsr load_stream
    lda &fe34
    ora #HAZEL_BIT
    sta &fe34
    lda #LO(HAZEL_BASE)
    ldx #HI(HAZEL_BASE)
    jsr unpack_to
    lda &fe34
    and #255-HAZEL_BIT
    sta &fe34
    rts
}


\ ******************************************************************
\ *	The memorial - the fade, and the sequence (Layer 9d)
\ ******************************************************************
\ *	BOOT CODE, and up here above code_end with the loader for the same
\ *	reason: it runs once, between the last file off the disc and
\ *	setup_display, and is dead before the first sprite is drawn.
\ *
\ *	THE FADE IS THE PALETTE AND NOTHING ELSE. MODE 2's eight colours
\ *	sit on one brightness ladder - black, blue, red, magenta, green,
\ *	cyan, yellow, white - and a step down the ladder is the whole
\ *	picture one step darker: white -> yellow -> cyan -> green ->
\ *	magenta -> red -> blue -> black, which is KC's own sequence.
\ *	Sixteen writes to &FE21 a step, and not one byte of the picture is
\ *	touched. Decision 52.
\ *
\ *	Fading DOWN subtracts the step from every colour's rung and clamps
\ *	at black. Fading UP caps every colour's rung at the step instead,
\ *	so each colour stops when it reaches the one it is meant to be:
\ *	the credits font's blue arrives at step 1, its cyan at 5 and its
\ *	white at 7, and the message assembles itself rather than
\ *	dissolving in.
\ *
\ *	Here rather than beside the message in bank 3 because the CPC
\ *	build's bank 3 has 162 bytes below the tune and the whole thing is
\ *	275 - and because only the drawing needs the font. mem_page in
\ *	src/bank3.asm is the other half.
\ ******************************************************************

MEM_STEP = 6                    ; fields a rung: eight of them is ~1s
MEM_HOLD = 150                  ; and three seconds to read it in

\ One field, polled. Interrupts are off, so nothing else has taken the
\ VSync flag before we get to look at it.
.mem_field
{
    lda #2
    sta SYS_VIA_IFR
    .w
    lda SYS_VIA_IFR
    and #2
    beq w
    rts
}

\ One whole fade, MEM_STEP fields a rung. fade_dir says which way; the
\ step runs 0 to 7 either way, because "down by 0" and "up capped at 7"
\ are both the untouched picture, so the beat lands at the end of the
\ movement rather than in the middle of it.
.mem_ramp
{
    ldx #0
    .rung
    stx mr_x
    stx fade_step               ; fade_pal is in BANK 2 (decision 53): main
    lda #SWRAM_SPRITES1         ; RAM had no room below SPR_SAVE for it and
    ldx #LO(fade_pal)           ; the titles need it after a game has run
    ldy #HI(fade_pal)
    jsr bank_call
    ldy #MEM_STEP
    .hold
    jsr mem_field
    dey
    bne hold
    ldx mr_x
    inx
    cpx #8
    bne rung
    rts

    .mr_x EQUB 0
}

\ The whole sequence. SEI, and interrupts stay off until install_irq's
\ CLI: the timing is the System VIA's own VSync flag and the MOS's
\ handler would take that flag before a poll could see it. Nothing
\ between here and install_irq wants an interrupt.
.memorial
{
    sei
    lda &fe34 : and #&ff - 4 : sta &fe34    ; CPU sees MAIN: the picture
    lda #0
    sta fade_low                ; all sixteen: the whole picture goes

    lda #&ff                    ; the loading picture goes out
    sta fade_dir
    jsr mem_ramp

    ldx #LO(mem_page)           ; and with the palette black, is replaced
    ldy #HI(mem_page)
    jsr bank3_call

    lda #0                      ; the message comes up in its place
    sta fade_dir
    jsr mem_ramp

    ldy #MEM_HOLD
    .sit
    jsr mem_field
    dey
    bne sit

    lda #&ff                    ; and out again, into the titles
    sta fade_dir
    jsr mem_ramp

    lda &fe34 : ora #4 : sta &fe34          ; and back to shadow
    rts
}

\ The ZX0 depacker LAST, after the tables: it is boot code and nothing
\ else calls it, so it is the one thing in the image that may sit above
\ SPR_SAVE's base and be walked over once the game starts.
INCLUDE "src/zx0depack.asm"

\ ******************************************************************
\ *	End address to be saved
\ ******************************************************************

.end

\ ******************************************************************
\ *	Save the code
\ ******************************************************************

SAVE "Edge", start, end

\ ******************************************************************
\ *	!BOOT - assembled here so the build stamps what it is
\ ******************************************************************
\ *	It is a disc file, not code, and it was costing the code image
\ *	its own length in address space - two hundred bytes of the
\ *	tightest region in the build, for text nothing ever executes.
\ *	So it is assembled in the sprite saves instead, the way
\ *	src/panel.asm and src/loading.asm assemble theirs: somewhere
\ *	that exists, that nothing has claimed at assembly time, and that
\ *	it is never loaded to. P% goes back afterwards.
\ ******************************************************************

code_p% = P%
CLEAR BOOT_STAGE, BOOT_STAGE + 256
ORG BOOT_STAGE

.bootfile
IF RELEASE
    EQUS "REM Edge Grinder", 13
ELSE
    EQUS "REM Edge Grinder DEV build", 13
IF DEBUG_COLL
    EQUS "REM DEBUG_COLL: collisions do not kill", 13
ENDIF
IF DEBUG_TIMING
    EQUS "REM DEBUG_TIMING: the frame meter is running", 13
ENDIF
ENDIF
\ MUSIC_AKL is NOT a DEBUG_ flag: it is legal under RELEASE and it changes
\ what the disc contains, so it is stamped outside the RELEASE test. Saying
\ nothing means the default - lib/vgiplayer.asm and the tune cut to 203 s.
IF MUSIC_AKL
    EQUS "REM MUSIC_AKL: Arkos replay, whole 349s tune", 13
ELSE
    EQUS "REM MUSIC: VGI player, whole 349s tune, 4 regions", 13
ENDIF
\ GFX_CPC is not a DEBUG_ flag either, and it changes every pixel on the
\ disc, so it is stamped outside the RELEASE test too.
IF GFX_CPC
    EQUS "REM GFX_CPC: the Amstrad CPC artwork", 13
ENDIF
IF GFX_NULA
IF GFX_CPC
    EQUS "REM GFX_NULA: CPC 16 pens, needs NuLA", 13
ELSE
    EQUS "REM GFX_NULA: C64 16 cols, needs NuLA", 13
ENDIF
ENDIF
EQUS "REM BUILD ", TIME$("%d %b %Y %H:%M:%S"), 13
EQUS "*RUN Edge", 13
.bootfile_end

SAVE "!BOOT", bootfile, bootfile_end
ASSERT bootfile_end < BOOT_STAGE + 256

ORG code_p%


\ ******************************************************************
\ *	Space reserved for runtime buffers not preinitialised
\ ******************************************************************

.bss_start
.bss_end

\ ******************************************************************
\ *	Memory Info
\ ******************************************************************

PRINT "------"
PRINT "EDGE GRINDER"
PRINT "------"
PRINT "CODE size =", ~code_end-code_start
PRINT "DATA size =",~data_end-data_start
PRINT "BSS size =",~bss_end-bss_start
PRINT "------"
\ ******************************************************************
\ *	THE REAL CEILING IS SPR_SAVE, NOT LOAD_STREAM
\ ******************************************************************
\ *	&2000-&2FFF is the sprite save area, rewritten every frame from
\ *	the moment the first sprite is drawn. Boot code and boot data may
\ *	sit in it - src/zx0depack.asm and the OSFILE block do, and !BOOT
\ *	is assembled there - because they are dead before anything reads
\ *	there. ANYTHING READ OR EXECUTED IN PLAY MAY NOT.
\ *
\ *	This is the guard that was missing: explosion_dirs drifted above
\ *	&2000 unnoticed and the player's pieces stopped flying, because
\ *	the blitter was writing the player's saved background over their
\ *	movement vectors. The FREE figure below is measured to
\ *	LOAD_STREAM and OVERSTATES the room for anything permanent - the
\ *	number that matters is this one.
\ ******************************************************************

ASSERT code_end <= SPR_SAVE
PRINT "CODE CEILING: code_end", ~code_end, "-", ~SPR_SAVE-code_end, "under SPR_SAVE"

PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~CODE_TOP-P%     \ to LOAD_STREAM: the depacker sits in SPR_SAVE
PRINT "------"

\ ******************************************************************
\ *	GAME STATE at &0800 - see GAME_STATE above. None of it is saved:
\ *	it is declared after the SAVEs and outside them, and every routine
\ *	that reads it writes it first. The first four blocks are the C64's
\ *	own $0340-$039F labels, same names, same meanings.
\ ******************************************************************

CLEAR GAME_STATE, GAME_STATE_TOP
ORG GAME_STATE
.game_state_start

.sprite_pos     skip 2*SPR_SLOTS    ; x,y a slot: 0 player, 1 bullet, 2-7 pool
.sprite_dp      skip SPR_SLOTS      ; the sprite_dp_dcd index = the frame
.sprite_pls_tmr skip SPR_SLOTS      ; hit-flash countdown
.anim_starts    skip SPR_SLOTS
.anim_ends      skip SPR_SLOTS
.anim_tmr       skip 1              ; multimate steps every fourth tick

.enemy_spds     skip 2*SPR_SLOTS    ; movement commands; slot 1 is the bullet's speed
.enemy_shields  skip SPR_SLOTS      ; hits left before it explodes
.enemy_rockers  skip SPR_SLOTS      ; timer value it switches command at
.enemy_resets   skip SPR_SLOTS      ; and wraps at
.enemy_tmrs     skip SPR_SLOTS

.scroll_x       skip 1              ; the C64's 16-step fine-scroll counter
.wave_tmr       skip 1              ; ticks until the next wave is spawned
.coll_flag      skip 1              ; a fatal hit; doubles as the game-over
                                    ; countdown once the player is gone
.comp_flag      skip 1              ; the wave table ran out; Layer 6c reads it
.lives          skip 1              ; three at main_init, one taken per hit
.player_shield  skip 1              ; ticks of invulnerability after a drop-in
.game_mode      skip 1              ; MODE_PLAY / OVER / COMP / FINALE: which of
                                    ; the C64's loops the tick is standing in for
.to_titles      skip 1              ; game over or completion has finished:
                                    ; the loop drops back to master_loop
.music_change   skip 1              ; MUSIC_AKL: 0 = play on, 1 = restart the
                                    ; in-game tune, 2 = start the finale's.
                                    ; Written by comp_mess and finale_tick,
                                    ; acted on in rupt_vsync where HAZEL and
                                    ; bank 3 are already paged - the CPC's
                                    ; ChangeMusic, whole
.finale_slot    skip 1              ; which slot the next bang takes, 0-7
.finale_tmr     skip 1              ; ticks until it goes off
.coll_grind     skip 2              ; the two grind cells, above and below the ship
.coll_temp      skip 4              ; the collision box being tested
.rt_store       skip 1              ; X across a bump_score call

.score          skip SCORE_DIGITS   ; one decimal digit a byte, biggest first
.hi_score       skip SCORE_DIGITS

\ What each bank's last sprite draw did, for the restore: bank*8 + slot.
.spr_sv_on      skip 2*SPR_SLOTS
.spr_sv_lo      skip 2*SPR_SLOTS
.spr_sv_hi      skip 2*SPR_SLOTS
.spr_sv_scan    skip 2*SPR_SLOTS
.spr_sv_rows    skip 2*SPR_SLOTS
.spr_sv_cols    skip 2*SPR_SLOTS
.spr_sv_wrap    skip 2*SPR_SLOTS    ; 0 plain, 1 split, 2 compiled
.spr_sv_clo     skip 2*SPR_SLOTS    ; and the compiled restore body, if 2
.spr_sv_chi     skip 2*SPR_SLOTS

\ The starfield (Layer 9c). The first four are the star itself, shared
\ by both banks because a star is at one place on the screen whichever
\ bank is being drawn; the last two are per bank, because a bank is
\ only redrawn every other frame and what has to be put back is
\ wherever THAT bank last left it.
.star_ofs_lo    skip STAR_COUNT     ; screen offset from corner_addr, 16-bit:
.star_ofs_hi    skip STAR_COUNT     ; 8 + row * 640 + column * 8
.star_col       skip STAR_COUNT     ; column 0-79, kept for the wrap test alone
.star_pix       skip STAR_COUNT     ; the byte to write: the colour in whichever
                                    ; half of it the star is standing in
\ Where this bank last plotted each star, or 0 in the high byte for "it
\ did not". A star is only ever plotted into a blank byte, so what goes
\ back is always zero and there is nothing else to remember.
.star_lo        skip STAR_BANK + STAR_COUNT
.star_hi        skip STAR_BANK + STAR_COUNT

\ The "mega hero" message's state (Layer 9c). Here rather than in bank 1
\ beside its code and its bitmaps, because that bank has tens of bytes
\ left and this block has hundreds. mega_o and mega_m are indexed by 0
\ for the "MEGA" block and 2 for the "HERO" one, as mega_gd is.
.mega_o         skip 4      ; where in the buffer each block has got to
.mega_m         skip 3      ; the eight cells each is working through
.mega_j         skip 1      ; which byte of the two bitmaps, 0-29
.mega_n         skip 1      ; which of its eight cells
.mega_b         skip 1      ; the block mega_one is doing
.mega_ofs       skip 2      ; the cell mega_plot is to write
.mega_src       skip 2      ; and the sixteen bytes to write into it
.mega_guard     skip 1      ; 0 = a letter, anything else the shadow

\ The palette fade (Layer 9d) and the titles' credit crossfade (Layer 9e).
\ fade_pal and the state machine are in BANK 2 - main RAM had no room below
\ SPR_SAVE - and a bank_call takes A, X and Y, so every argument comes
\ through here. ttl_redraw is the one thing bank 2 cannot do for itself:
\ the bank 3 call that repaints the credits with the other set.
.fade_step      skip 1      ; 0-7, the rung
.fade_dir       skip 1      ; 0 = up (cap), &ff = down (subtract)
.fade_low       skip 1      ; lowest logical colour: 0 memorial, 8 titles
.ttl_c_step     skip 1      ; 0-7 down, 8 swap, 9-15 up, 16 done, 17 holding
.ttl_c_tmr      skip 2      ; fields to the next step; 250 needs two bytes
.ttl_c_set      skip 1      ; 0 the C64's credits, 1 this port's
.ttl_fade_on    skip 1      ; the credit raster stands down while this is set
.ttl_redraw     skip 1      ; bank 2 asks main RAM for a bank 3 call

.ttl_cred_ptr   skip 2      ; where title_text reads its five lines from

\ The redefine screen (Layer 9h, decision 71). Its code, its text and its
\ tables are all elsewhere - bank 1's hole and the PANEL file - but the
\ block it composes has to be main RAM that bank 3 can read with itself
\ paged in, which is what ttl_cred_ptr points at, and this block is the
\ only ground in the machine with hundreds of bytes going spare.
\
\ THE SCREEN IS A THIRD CREDIT SET and that is the whole design: five lines
\ of 38 glyphs, the same shape title_text already draws through the same
\ pointer, so bank 3 - which has 43 bytes left in a -Cpc build - is not
\ touched at all, and neither is the rupture, so the page cannot pick up
\ another switch flicker (BUGS.md #14).
.ttl_rows_ofs   skip 1      ; which row list title_text reads: 0 for the
                            ; credits' 0/2/3/4/5, TITLE_LINES for the redefine
                            ; screen's 0/1/2/3/4/5 (decision 72)
.ttl_lines      skip 1      ; and how many of them - 5 or 6
.kr_block       skip TITLE_LINE_LEN * KR_LINES
.kr_save        skip JOY_COUNT      ; what ESCAPE puts back
.kr_cur         skip 1              ; which control is being asked for, 0-4;
                                    ; 5 means "none", and no line shows a prompt
.kr_msg         skip 1              ; message index, or &ff for the binding
.kr_key         skip 1              ; the internal number of the answer
.kr_line        skip 1              ; kr_build's counter
.kr_base        skip 1              ; and its offset to that line in kr_block
.kr_cnt         skip 1              ; bytes left in a field copy
.kr_dst         skip 1              ; where kr_showkey writes
.kr_i           skip 1              ; kr_scan's counter, because keydown owns Y
.kr_hold        skip 1              ; fields a message has left to stand

\ The frame meter (src/timing.asm). Microseconds, worst case since boot;
\ double them for 2 MHz cycles. tim_over is the one that matters.
IF DEBUG_TIMING
\ The five maxima are addressed by the TIM_ index, so they must stay
\ in this order and adjacent.
.tim_slots_start
.tim_max_restore skip 2         ; TIM_RESTORE: spr_restore_all
.tim_max_scroll  skip 2         ; TIM_SCROLL:  scroll_frame
.tim_max_draw    skip 2         ; TIM_DRAW:    spr_draw_all
.tim_max_logic   skip 2         ; TIM_LOGIC:   read_joystick, 2 x game_tick, scroll_advance
.tim_max_total   skip 2         ; TIM_TOTAL:   the lot, tim_start to handover
.tim_fields      skip 1         ; worst fields a frame took; FRAME_LOCK is late
.tim_over        skip 1         ; frames that missed their flip, saturating
.tim_slots_end
ASSERT tim_max_restore = tim_slots_start + 2 * TIM_RESTORE
ASSERT tim_max_scroll  = tim_slots_start + 2 * TIM_SCROLL
ASSERT tim_max_draw    = tim_slots_start + 2 * TIM_DRAW
ASSERT tim_max_logic   = tim_slots_start + 2 * TIM_LOGIC
ASSERT tim_max_total   = tim_slots_start + 2 * TIM_TOTAL
ENDIF

.game_state_end
ASSERT game_state_end <= GAME_STATE_TOP
PRINT "GAME STATE =", ~game_state_start, "to", ~game_state_end

\ The loading screen is FIRST: it is the first thing off the disc, and
\ tools/make_disc.py lays the image out in the order the boot reads it.
INCLUDE "src/loading.asm"
INCLUDE "src/panel.asm"
INCLUDE "src/andy.asm"
INCLUDE "src/bank0.asm"
INCLUDE "src/bank1.asm"
INCLUDE "src/bank2.asm"
INCLUDE "src/bank3.asm"
INCLUDE "src/music.asm"
