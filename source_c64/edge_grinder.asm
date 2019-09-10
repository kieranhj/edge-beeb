;
; EDGE GRINDER
;

; Code by Jason "T.M.R" Kelk
; Graphics by Trevor "Smila" Storey
; Music by Sean "Odie" Connolly


; Developed by Cosine :: http://Cosine.org.uk/
; For Format War :: http://FormatWar.net/


; Select an output filename
		!to "edge_grinder.prg",cbm


; Include binary data
		* = $2e00
		!binary "data/music.prg",,2

		* = $4000
		!binary "data/tiles.chr",,2
		* = $4800
		!binary "data/status.chr",,2
		* = $5800
		!binary "data/sprites.spr",,2


		* = $8000
		!binary "data/tiles.til",,2
		* = $9000
		!binary "data/tiles.map",,2
		* = $9500
		!binary "data/tiles2.map",,2


; Constants: raster split positions
rstr1p		= $00
rstr2p		= $52


; Constants: movement commands and objects for the wave data
stop		= $00
up_1		= $01
up_2		= $11
down_1		= $02
down_2		= $22
left_1		= $04
left_2		= $44
right_1		= $08
right_2		= $88

enemy_1		= $03		; grey rocker
enemy_2		= $04		; blue flipping disc
enemy_3		= $05		; green spindly
enemy_4		= $06		; cyan Zynaps-alike rocker
enemy_5		= $07		; grey 3 shape
enemy_6		= $08		; cyan rotator with thrusty bit
enemy_7		= $09		; pink flipping disc
enemy_8		= $0a		; yellow spinner with nacelles
enemy_9		= $0b		; blue rotator
enemy_10	= $0c		; green rotator
enemy_11	= $0d		; grey 3 shaped rotator - Armalyte-ish
enemy_12	= $0e		; cyan tumbler
enemy_13	= $0f		; yellow tumbler
enemy_14	= $10		; pink Delta spinny thing
enemy_15	= $11		; grey flat spinny thing
enemy_16	= $12		; cyan bubble in a ring


; Label assignments (using the tape buffer to stash stuff)
rn		= $0340
sync		= $0341
rt_store	= $0342
rt_store_2	= $0343
comp_flag	= $0344

anim_tmr	= $0345
wave_tmr	= $0346

scroll_x	= $0347
tile_cnt	= $0348

player_shield	= $0349
lives		= $034a
fire_latch	= $034b

coll_grind	= $0350		; two bytes
coll_flag	= $0352
coll_temp	= $0354		; four bytes


sprite_pos	= $0360		; 16 bytes
sprite_dp	= $0370		; 8 bytes
sprite_pls_tmr	= $0378		; 8 bytes

anim_starts	= $0380		; 8 bytes
anim_ends	= $0388		; 8 bytes

enemy_spds	= $0390		; 16 bytes
enemy_shields	= $03a0		; 8 bytes
enemy_rockers	= $03a8		; 8 bytes
enemy_resets	= $03b0		; 8 bytes
enemy_tmrs	= $03b8		; 8 bytes

zoom_buffer	= $03c0		; 8 bytes
ttl_pulse_tmr	= $03c8		; 1 byte


buffer_1	= $5000		; screen buffer 1
buffer_2	= $5400		; screen buffer 2


; Add a BASIC startline
		* = $0801
		!word entry-2
		!byte $00,$00,$9e
		!text "2066"
		!byte $00,$00,$00


; Entry point at $0812
		* = $0812
entry		jsr irq_init
master_loop	jsr nuke_labels
		lda #$ff
		sta scroll_x


; TITLES PAGE INIT
		ldx #$00
ttl_clear	lda #$00
		sta buffer_1+$0c8,x
		sta buffer_1+$1c8,x
		sta buffer_1+$2c8,x
		sta buffer_1+$2e8,x

		lda #$0d
		sta $d8c8,x
		sta $d9c8,x
		sta $dac8,x
		sta $dae8,x
		inx
		bne ttl_clear


; Set titles page credits
		ldx #$00
ttl_init	ldy ttl_credits+$000,x
		lda scroll_decode,y
		sta buffer_1+$1e0,x
		lda #$00
		sta $d9e0,x

		ldy ttl_credits+$026,x
		lda scroll_decode,y
		sta buffer_1+$230,x
		lda #$0f
		sta $da30,x

		ldy ttl_credits+$04c,x
		lda scroll_decode,y
		sta buffer_1+$258,x
		lda #$0b
		sta $da58,x

		ldy ttl_credits+$072,x
		lda scroll_decode,y
		sta buffer_1+$280,x
		lda #$0d
		sta $da80,x

		ldy ttl_credits+$098,x
		lda scroll_decode,y
		sta buffer_1+$2a8,x
		lda #$00
		sta $daa8,x

		inx
		cpx #$26
		bne ttl_init


; Pause before starting
		ldy #$32
ttl_wait	jsr sync_wait
		dey
		bne ttl_wait

		lda #$1b
		sta $d011
		jsr mess_reset


; TITLES PAGE MAIN LOOP
ttl_loop	jsr sync_wait
		jsr zoom_mover

		lda $dc00
		and #$10
		bne ttl_loop


; GAME INIT
main_init	lda #$0b
		sta $d011
		jsr nuke_labels
		jsr map_read_rst
		jsr wave_read_rst
		jsr sprite_reset
		jsr score_reset
		lda #$03
		sta lives
		lda #$1b
		sta $d011


;  GAME MAIN LOOP
main_dropin	lda #$32
		sta player_shield
		lda #$00
		sta coll_flag


; Pause mode key check
main_loop	lda $dc01
		cmp #$7f
		bne main_loop_2

; Game pause loop
main_pause	jsr sync_wait

; Check for Q key to abort game
		lda $dc01
		cmp #$bf
		bne *+$05
		jmp main_abort

; Check for fire button to exit pause
		lda $dc00
		and #$10
		bne main_pause

main_pause_db	jsr sync_wait
		lda $dc00
		and #$10
		beq main_pause_db


; Main game loop - part 2
main_loop_2	jsr sync_wait
		jsr player_manage
		jsr enemy_manage
		jsr scroll_manage

; Check player shield to see if collisions should be ignored
		ldx player_shield
		beq no_shield
		lda #$00
		sta coll_flag
no_shield	dex
		cpx #$ff
		bne shield_xb
		ldx #$00
shield_xb	stx player_shield

; Check collision flag
		lda coll_flag
		beq no_coll
		jmp life_lost_init	; patch me out to disable collisions!


; Check completion flag
no_coll		lda comp_flag
		beq main_loop
		jmp comp_init


; Abort game (called if Q is pressed from pause)
main_abort	lda #$01
		sta lives


; LIFE LOST INIT
life_lost_init	ldx #$00
lli_loop	lda sprite_pos+$00
		sta sprite_pos+$04,x
		lda sprite_pos+$01
		sta sprite_pos+$05,x
		inx
		inx
		cpx #$0c
		bne lli_loop

		ldx #$00
lli_loop_2	lda explosion_dirs+$04,x
		sta enemy_spds+$04,x
		inx
		cpx #$0c
		bne lli_loop_2


; LIFE LOST LOOP
		ldx #$00
life_lost_loop	lda #$00
		sta sprite_dp+$02,x
		lda #$0a
		sta anim_starts+$02,x
		lda #$0b
		sta anim_ends+$02,x
		inx
		cpx #$06
		bne life_lost_loop

		dec lives
		lda lives
		beq game_over_init
		jmp main_dropin


; GAME OVER INIT
game_over_init	lda #$00
		sta sprite_pos+$00
		sta sprite_pos+$01
		sta sprite_pos+$02
		sta sprite_pos+$03
		lda #$c8
		sta coll_flag


; GAME OVER LOOP
game_over_loop	jsr sync_wait
		jsr enemy_manage
		jsr scroll_manage
		dec coll_flag
		bne game_over_loop
		lda #$0b
		sta $d011
		jmp master_loop


; COMPLETION INIT
comp_init	nop


; COMPLETION MAIN LOOP
comp_loop	jsr sync_wait
		jsr enemy_manage
		jsr scroll_manage
		lda sprite_pos+$00
		clc
		adc #$01
		cmp #$c0
		bcc cl_over

		lda scroll_x
		cmp #$0c
		beq comp_mess

		lda #$c0
cl_over		sta sprite_pos+$00

		jmp comp_loop


; Zero the sprite positions, then display the "mega hero" message
; over the play area
comp_mess	ldx #$00
		txa
cm_hide_sprs	sta sprite_pos,x
		inx
		cpx #$10
		bne cm_hide_sprs


		ldx #$00
		ldy #$ef
cm_loop		jsr sync_wait

		lda mega_hero_txt+$000,x
		beq cm_over_1
		lda #$80
		sta buffer_2+$140,x
		lda #$0d
		sta $d940,x
		lda #$00
		sta buffer_2+$169,x

cm_over_1	lda mega_hero_txt+$100,y
		beq cm_over_2
		lda #$80
		sta buffer_2+$280,y
		lda #$0d
		sta $da80,y

		lda buffer_2+$2a9,y
		cmp #$80
		beq cm_over_2
		lda #$00
		sta buffer_2+$2a9,y

cm_over_2	dey
		inx
		cpx #$f0
		bne cm_loop


; Add the completion bonus - 5,000 points * remaining lives
		ldy lives

cm_bonus_loop	jsr bump_score_1000
		jsr bump_score_1000
		jsr bump_score_1000
		jsr bump_score_1000
		jsr bump_score_1000

		ldx #$32
cmbl_wait	jsr sync_wait
		dex
		bne cmbl_wait

		dey
		bne cm_bonus_loop


; Explosions whilst waiting for the fire button before exiting to titles
		lda #$00
		sta rt_store
		sta rt_store_2

cm_splode_wait	jsr sync_wait

		ldx rt_store
		dex
		bpl cm_sw_over

; Produce the actual bang
		lda rt_store_2
		asl
		tax

		ldy comp_flag
		lda $0900,y
		sta sprite_pos+$00,x
		lda $0a00,y
		and #$7f
		clc
		adc #$5e
		sta sprite_pos+$01,x
		lda #$00
		sta enemy_spds+$00,x
		sta enemy_spds+$01,x

		inc comp_flag

		ldy rt_store_2
		lda #$00
		sta sprite_dp,y
		lda #$0a
		sta anim_starts,y
		lda #$0b
		sta anim_ends,y

		iny
		cpy #$08
		bne *+$04
		ldy #$00
		sty rt_store_2

		ldx #$04
cm_sw_over	stx rt_store


; Shortened version of multimate to animate the explosions
		ldx anim_tmr
		inx
		cpx #$04
		bne mmc_out

		ldx #$00
mmc_loop	lda sprite_dp+$00,x
		clc
		adc #$01
		cmp anim_ends+$00,x
		bne mmc_over
		lda anim_starts+$00,x
mmc_over	sta sprite_dp+$00,x
		inx
		cpx #$08
		bne mmc_loop

		ldx #$00
mmc_out		stx anim_tmr


; Check the fire button and drop to titles if it's pressed
		lda $dc00
		and #$10
		beq *+$05
		jmp cm_splode_wait

		lda #$0b
		sta $d011
		jsr sync_wait
		jmp master_loop


; Titles page zoom scroll mover
zoom_mover	ldx #$00
zm_loop		lda buffer_1+$2f9,x
		sta buffer_1+$2f8,x
		lda buffer_1+$321,x
		sta buffer_1+$320,x
		lda buffer_1+$349,x
		sta buffer_1+$348,x
		lda buffer_1+$371,x
		sta buffer_1+$370,x
		lda buffer_1+$399,x
		sta buffer_1+$398,x
		lda buffer_1+$3c1,x
		sta buffer_1+$3c0,x
		inx
		cpx #$25
		bne zm_loop
		jsr ttl_pulse

		ldy #$00
		asl zoom_buffer+$01
		bcc zs_write_1
		ldy #$8e
zs_write_1	sty buffer_1+$31d

		ldy #$00
		asl zoom_buffer+$02
		bcc zs_write_2
		ldy #$8e
zs_write_2	sty buffer_1+$345

		ldy #$00
		asl zoom_buffer+$03
		bcc zs_write_3
		ldy #$8e
zs_write_3	sty buffer_1+$36d

		ldy #$00
		asl zoom_buffer+$04
		bcc zs_write_4
		ldy #$8e
zs_write_4	sty buffer_1+$395

		ldy #$00
		asl zoom_buffer+$05
		bcc zs_write_5
		ldy #$8e
zs_write_5	sty buffer_1+$3bd

		ldy #$00
		asl zoom_buffer+$06
		bcc zs_write_6
		ldy #$8e
zs_write_6	sty buffer_1+$3e5


; Zoom scroll character decoder
		ldx tile_cnt
		inx
		cpx #$08
		bne zd_over

mess_read	ldy scrolltext
		bne mr_okay
		jsr mess_reset
		jmp mess_read

mr_okay		lda scroll_decode,y
		sta zoom_copy+$01
		asl zoom_copy+$01
		asl zoom_copy+$01
		asl zoom_copy+$01
		lsr
		lsr
		lsr
		lsr
		lsr
		clc
		adc #$4d
		sta zoom_copy+$02

		ldx #$00
zoom_copy	lda $6464,x
		sta zoom_buffer+$00,x
		inx
		cpx #$08
		bne zoom_copy

		inc mess_read+$01
		bne zd_nohi
		inc mess_read+$02

zd_nohi		ldx #$00
zd_over		stx tile_cnt


; Mirror zoom scroll
		ldx #$00
		ldy #$25
zoom_mirror	lda buffer_1+$3c0,y
		sta buffer_1+$0c8,x
		lda buffer_1+$398,y
		sta buffer_1+$0f0,x
		lda buffer_1+$370,y
		sta buffer_1+$118,x
		lda buffer_1+$348,y
		sta buffer_1+$140,x
		lda buffer_1+$320,y
		sta buffer_1+$168,x
		lda buffer_1+$2f8,y
		sta buffer_1+$190,x
		dey
		inx
		cpx #$26
		bne zoom_mirror
		rts


; Zoom scroll self mod reset
mess_reset	lda #<scrolltext
		sta mess_read+$01
		lda #>scrolltext
		sta mess_read+$02
		rts


; Pulse effect on titles page
ttl_pulse	ldx #$26
		ldy #$00
tp_loop		lda $daa8,x
		sta $daa9,x
		sta $d9e0,y
		iny
		dex
		cpx #$ff
		bne tp_loop
		lda ttl_pulse_tmr
		clc
		adc #$01
		and #$1f
		sta ttl_pulse_tmr
		lsr
		tax
		lda status_pulse,x
		sta $daa8
		rts


; Raster synchronisation
sync_wait	lda #$00
		sta sync

sw_loop		cmp sync
		beq sw_loop
		rts


; Wipe out all of the labels
nuke_labels	ldx #$00
		txa
nl_loop		sta $0341,x
		inx
		cpx #$bf
		bne nl_loop
		rts


; Initialise the IRQ interrupt
irq_init	sei
		lda #$35
		sta $01

		lda #<nmi
		sta $fffa
		lda #>nmi
		sta $fffb

		lda #<int
		sta $fffe
		lda #>int
		sta $ffff

		lda #$7f
		sta $dc0d
		sta $dd0d
		lda #$00
		sta $d012
		lda #$0b
		sta $d011
		lda #$01
		sta $d019
		sta $d01a
		sta rn

		ldx #$00
		txa
		tay
		jsr $2e00	; init music

		cli


; Set up the colour data for the status bar
		ldx #$00
status_init	lda status_cols,x
		sta $d800,x
		inx
		cpx #$c8
		bne status_init
		rts


; IRQ interrupt handling
int		pha
		tya
		pha
		txa
		pha

		lda $d019
		and #$01
		sta $d019
		bne ya
		jmp ea31


; Check which routine needs calling
ya		lda rn
		cmp #$01
		bne ya_over
		jmp rout1
ya_over		jmp rout2


; Generic interrupt exit point (shares the RTI with the NMI)
ea31		pla
		tax
		pla
		tay
		pla
nmi		rti


; Raster split 1
rout1		lda #$02
		sta rn
		lda #rstr2p
		sta $d012

		lda #$00
		sta $d020
		sta $d021
		lda #$06
		sta $d022
		lda #$01
		sta $d023

		lda #$17
		sta $d016
		lda #$42
		sta $d018
		lda #$c6
		sta $dd00

		lda #$ff
		sta $d015
		sta $d01c

; sprite data copiers
		ldx #$00
xploder_1	lda sprite_pos+$00,x
		asl
		ror $d010
		sta $d000,x
		lda sprite_pos+$01,x
		sta $d001,x
		inx
		inx
		cpx #$10
		bne xploder_1

		ldx #$00
xploder_2	lda #$6a
		sta $53f8,x

		ldy sprite_dp+$00,x
		lda sprite_dp_dcd,y
		sta $57f8,x

		lda sprite_col_dcd,y
		ldy sprite_pls_tmr,x
		beq xp_2a

		lsr
		lsr
		lsr
		lsr

xp_2a		sta $d027,x

		inx
		cpx #$08
		bne xploder_2


		lda #$06
		sta $d025
		lda #$01
		sta $d026


		jsr status_decode

		jsr $2e03	; play music

		jmp ea31


; Raster split 2
rout2		lda #$01
		sta rn
		lda #rstr1p
		sta $d012

		lda scroll_x
		cmp #$ff
		beq rout2_titles

		and #$08
		asl
		eor #$40
		tax

		lda scroll_x
		and #$07
		tay
		eor #$17
		sta $d016

		lda star_decode,y
		sta $47f8


		lda #$59
		cmp $d012
		bcs *-$03

		lda #$09
		sta $d022
		lda #$01
		sta $d023
		stx $d018

		ldx #$00
xploder_3	ldy sprite_dp+$00,x
		lda sprite_dp_dcd,y
		sta $53f8,x
		inx
		cpx #$08
		bne xploder_3

		lda #$01
		sta sync
		jmp ea31


; The back end of rout2 if the titles page is on
rout2_titles	lda #$00
		sta $d021
		lda #$09
		sta $d022
		lda #$01
		sta $d023

		lda #$01
		sta sync
		jmp ea31


; Player control routines
player_manage	lda $dc00

player_up	lsr
		bcs player_down
		ldx sprite_pos+$01
		dex
		dex
		cpx #$5a
		bcs p_up_out
		ldx #$5a
p_up_out	stx sprite_pos+$01

player_down	lsr
		bcs player_left
		ldx sprite_pos+$01
		inx
		inx
		cpx #$e6
		bcc p_down_out
		ldx #$e5
p_down_out	stx sprite_pos+$01

player_left	lsr
		bcs player_right
		ldx sprite_pos+$00
		dex
		cpx #$10
		bcs p_left_out
		ldx #$10
p_left_out	stx sprite_pos+$00

player_right	lsr
		bcs player_fire
		ldx sprite_pos+$00
		inx
		cpx #$9c
		bcc p_right_out
		ldx #$9b
p_right_out	stx sprite_pos+$00

player_fire	ldy fire_latch
		beq fire_bullet
		lsr
		bcc fire_out
		lda #$00
		sta fire_latch

fire_out	jsr player_colls
		rts


; The latch says it's okay, time to fire a bullet if it's ready
fire_bullet	lsr
		bcs player_s_colls

		lda sprite_pos+$03
		bne player_s_colls
		lda sprite_pos+$00
		sta sprite_pos+$02
		lda sprite_pos+$01
		sta sprite_pos+$03
		lda #$0c
		sta enemy_spds+$02
		lda #$00
		sta enemy_spds+$03
		lda #$01
		sta fire_latch

		lda #$12
		sta sprite_dp+$01
		sta anim_starts+$01
		lda #$13
		sta anim_ends+$01


; Player to enemy collisions
player_s_colls	lda sprite_pos+$00
		sec
		sbc #$06
		sta coll_temp+$00
		clc
		adc #$0d
		sta coll_temp+$01
		lda sprite_pos+$01
		sec
		sbc #$0b
		sta coll_temp+$02
		clc
		adc #$18
		sta coll_temp+$03

		ldx #$00
		ldy #$00
psc_loop	lda sprite_dp+$02,y
		cmp #$0b
		bcc psc_over

		lda sprite_pos+$04,x
		cmp coll_temp+$00
		bcc psc_over
		cmp coll_temp+$01
		bcs psc_over

		lda sprite_pos+$05,x
		cmp coll_temp+$02
		bcc psc_over
		cmp coll_temp+$03
		bcs psc_over

		inc coll_flag

psc_over	iny
		inx
		inx
		cpx #$0c
		bne psc_loop
		jsr player_colls
		rts


; Enemy control routines
enemy_manage	lda sprite_pos+$02
		clc
		adc enemy_spds+$02
		sta sprite_pos+$02


; Enemy movement code
		ldx #$00
		ldy #$00
emove_loop	lda enemy_tmrs+$02,y
		clc
		adc #$01
		sta enemy_tmrs+$02,y

		lda enemy_rockers+$02,y
		cmp enemy_tmrs+$02,y
		bcc emove_2
		lda enemy_spds+$04,x
		jmp emove_proc

emove_2		lda enemy_spds+$05,x

emove_proc	jsr emove_up
		jsr emove_up

		lda enemy_tmrs+$02,y
		cmp enemy_resets+$02,y
		bcc *+$04
		lda #$00
		sta enemy_tmrs+$02,y

		inx
		inx
		iny
		cpy #$06
		bne emove_loop


; Check if enemies are out of bounds and decommission them
		ldx #$00
enemy_bounds	lda sprite_pos+$02,x
		cmp #$d0
		bcs eb_kill_enemy
		lda sprite_pos+$03,x
		cmp #$40
		bcs eb_cnt

eb_kill_enemy	lda #$00
		sta sprite_pos+$02,x
		sta sprite_pos+$03,x
		sta enemy_spds+$02,x
		sta enemy_spds+$03,x

eb_cnt		inx
		inx
		cpx #$0e
		bne enemy_bounds


; Player bullet to enemy colision check
		lda sprite_pos+$02
		sec
		sbc #$08
		sta coll_temp+$00
		clc
		adc #$11
		sta coll_temp+$01
		lda sprite_pos+$03
		bne enemy_colls

		jmp multimate


enemy_colls	sec
		sbc #$10
		sta coll_temp+$02
		clc
		adc #$22
		sta coll_temp+$03


		ldx #$00
		ldy #$00
ec_loop		lda sprite_dp+$02,y
		cmp #$0b
		bcc ec_over

		lda sprite_pos+$04,x
		cmp coll_temp+$00
		bcc ec_over
		cmp coll_temp+$01
		bcs ec_over
		lda sprite_pos+$05,x
		cmp coll_temp+$02
		bcc ec_over
		cmp coll_temp+$03
		bcs ec_over


; Enemy collision detected, so deal with it
		lda #$00
		sta sprite_pos+$02
		sta sprite_pos+$03
		sta enemy_spds+$02
		sta enemy_spds+$03


; Enemy collision processing (what happens when a collision occurs)
		lda enemy_shields+$02,y
		sec
		sbc #$01
		sta enemy_shields+$02,y
		bne ec_no_kill


; Turn an enemy into an explosion and add 400 points
		sta enemy_spds+$04,x
		sta enemy_spds+$05,x
		lda #$00
		sta sprite_dp+$02,y
		lda #$0a
		sta anim_starts+$02,y
		lda #$0b
		sta anim_ends+$02,y

		jsr bump_score_400

		jmp ec_over


; Make the enemy flash if chipped and add 40 points to the score
ec_no_kill	lda #$04
		sta sprite_pls_tmr+$02,y

		stx rt_store
		jsr bump_score_10
		jsr bump_score_10
		jsr bump_score_10
		jsr bump_score_10
		ldx rt_store

ec_over		iny
		inx
		inx
		cpx #$0c
		bne ec_loop


; Simple sprite animation drivers
multimate	ldx anim_tmr
		inx
		cpx #$04
		bne mm_out

		ldx #$00
mm_loop		lda sprite_dp+$00,x
		clc
		adc #$01
		cmp anim_ends+$00,x
		bne mm_over
		lda anim_starts+$00,x
mm_over		sta sprite_dp+$00,x
		inx
		cpx #$08
		bne mm_loop

		ldx #$00
mm_out		stx anim_tmr


; Check for end of explosion animations
		ldx #$00
		ldy #$00
explosion_chk	lda sprite_dp+$02,x
		cmp #$0a
		bne exc_over


; Decommission a finished explosion
		lda #$00
		sta sprite_pos+$05,y

exc_over	iny
		iny
		inx
		cpx #$06
		bne explosion_chk


; Decrement the pulse timers
		ldx #$00
pt_loop		lda sprite_pls_tmr,x
		sec
		sbc #$01
		cmp #$ff
		bne *+$04
		lda #$00
		sta sprite_pls_tmr,x
		inx
		cpx #$08
		bne pt_loop


; Call the attack wave manager
		jsr wave_manager

		rts


; Reset the sprites to defaults
sprite_reset	ldx #$00
sr_loop_1	lda spr_defaults,x
		sta sprite_pos+$00,x
		inx
		cpx #$18
		bne sr_loop_1

		ldx #$00
sr_loop_2	lda anim_defaults,x
		sta anim_starts+$00,x
		inx
		cpx #$10
		bne sr_loop_2

		rts


; Individual enemy movement routines
emove_up	lsr
		bcc emove_down
		dec sprite_pos+$05,x
		dec sprite_pos+$05,x

emove_down	lsr
		bcc emove_left
		inc sprite_pos+$05,x
		inc sprite_pos+$05,x

emove_left	lsr
		bcc emove_right
		dec sprite_pos+$04,x

emove_right	lsr
		bcc emove_out
		inc sprite_pos+$04,x

emove_out	rts


; Wave reader self mod reset
wave_read_rst	lda #<wave_data
		sta wave_read+$01
		lda #>wave_data
		sta wave_read+02

		lda #$10	; initial wait before starting waves
		sta wave_tmr
		rts


; Attack wave manager
wave_manager	ldx wave_tmr
		beq wm_new_enemy

		dex
		stx wave_tmr
		rts


; An enemy is approaching... find it an object!
wm_new_enemy	ldx #$00
wm_find		lda sprite_pos+$05,x
		beq wm_assign
		inx
		inx
		cpx #$0c
		bne wm_find
		jmp wm_fail


; Assign enemy to the found object
wm_assign	txa
		lsr
		tay
		jsr wave_read
		cmp #$ff
		bne wm_assign_2
		jmp wm_comp_flag


wm_assign_2	sta sprite_pos+$04,x

		jsr wave_read
		sta sprite_pos+$05,x

		jsr wave_read
		sta enemy_spds+$04,x

		jsr wave_read
		sta enemy_spds+$05,x

		jsr wave_read
		sta enemy_rockers+$02,y

		jsr wave_read
		sta enemy_resets+$02,y
		lda #$ff
		sta enemy_tmrs+$02,y

		jsr wave_read
		asl
		tax
		lda anim_decode+$00,x
		sta sprite_dp+$02,y
		sta anim_starts+$02,y
		lda anim_decode+$01,x
		sta anim_ends+$02,y

		jsr wave_read
		sta enemy_shields+$02,y

		jsr wave_read
		sta wave_tmr


; This is a little messy, but it forces the wave manager to loop back
; for those situations when there should be multiple enemies spawned
; in the same frame
		jmp wave_manager


; End of game reached, set the completion flag and bail
wm_comp_flag	lda #$01
		sta comp_flag
		rts


; Object trasher (used if there isn't a slot available for a new object)
wm_fail		jsr wave_read
		cmp #$ff
		bne wm_fail_2
		jmp wm_comp_flag


wm_fail_2	jsr wave_read
		jsr wave_read
		jsr wave_read
		jsr wave_read
		jsr wave_read
		jsr wave_read
		jsr wave_read
		jsr wave_read
		sta wave_tmr
		rts


; Self modifying code for wave reader
wave_read	lda wave_data
		inc wave_read+$01
		bne wr_out
		inc wave_read+$02
wr_out		rts


; Background scroll handlers
scroll_manage	ldx scroll_x
		inx
		cpx #$10
		bne sm_xb
		ldx #$00
sm_xb		stx scroll_x

		cpx #$03
		bne sm_chk_1
		jsr buffer_swap_1a
		rts

sm_chk_1	cpx #$05
		bne sm_chk_2
		jsr buffer_swap_1b
		rts

sm_chk_2	cpx #$00
		bne sm_chk_3
		jsr colour_shunt
		rts

sm_chk_3	cpx #$0b
		bne sm_chk_4
		jsr buffer_swap_2a
		rts

sm_chk_4	cpx #$0d
		bne sm_chk_5
		jsr buffer_swap_2b
		rts

sm_chk_5	cpx #$08
		bne sm_out
		jsr colour_shunt

sm_out		rts


; Specific case checks for scrolling
tile_cnt_bump	ldx tile_cnt
		inx
		cpx #$04
		bne tcb_out
		jsr tile_update
		ldx #$00
tcb_out		stx tile_cnt
		rts


; Scroll buffer swap 1
buffer_swap_1a	ldx #$00

bs1a_loop	lda buffer_1+$0c9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$0c8,x

		lda buffer_1+$0f1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$0f0,x

		lda buffer_1+$119,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$118,x

		lda buffer_1+$141,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$140,x


		lda buffer_1+$169,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$168,x

		lda buffer_1+$191,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$190,x

		lda buffer_1+$1b9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$1b8,x

		lda buffer_1+$1e1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$1e0,x


		lda buffer_1+$209,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$208,x

		lda buffer_1+$231,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$230,x

		lda buffer_1+$259,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$258,x

		lda buffer_1+$281,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$280,x

		inx
		cpx #$26
		beq bs1a_out
		jmp bs1a_loop

bs1a_out	rts


buffer_swap_1b	ldx #$00

bs1b_loop	lda buffer_1+$2a9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$2a8,x

		lda buffer_1+$2d1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$2d0,x

		lda buffer_1+$2f9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$2f8,x

		lda buffer_1+$321,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$320,x


		lda buffer_1+$349,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$348,x

		lda buffer_1+$371,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$370,x

		lda buffer_1+$399,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$398,x

		lda buffer_1+$3c1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_2+$3c0,x

		inx
		cpx #$26
		beq bs1b_out
		jmp bs1b_loop

bs1b_out	jsr buffer_write_1
		jsr tile_cnt_bump
		rts


; Scroll buffer swap 2
buffer_swap_2a	ldx #$00

bs2a_loop	lda buffer_2+$0c9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$0c8,x

		lda buffer_2+$0f1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$0f0,x

		lda buffer_2+$119,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$118,x

		lda buffer_2+$141,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$140,x


		lda buffer_2+$169,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$168,x

		lda buffer_2+$191,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$190,x

		lda buffer_2+$1b9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$1b8,x

		lda buffer_2+$1e1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$1e0,x


		lda buffer_2+$209,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$208,x

		lda buffer_2+$231,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$230,x

		lda buffer_2+$259,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$258,x

		lda buffer_2+$281,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$280,x

		inx
		cpx #$26
		beq bs2a_out
		jmp bs2a_loop

bs2a_out	rts


buffer_swap_2b	ldx #$00

bs2b_loop	lda buffer_2+$2a9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$2a8,x

		lda buffer_2+$2d1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$2d0,x

		lda buffer_2+$2f9,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$2f8,x

		lda buffer_2+$321,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$320,x


		lda buffer_2+$349,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$348,x

		lda buffer_2+$371,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$370,x

		lda buffer_2+$399,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$398,x

		lda buffer_2+$3c1,x
		cmp #$ff
		bcc *+$04
		lda #$00
		sta buffer_1+$3c0,x

		inx
		cpx #$26
		beq bs2b_out
		jmp bs2b_loop

bs2b_out	jsr buffer_write_2
		jsr tile_cnt_bump
		rts


; Self modifying code for the tile readers
tile_read_1	ldy $8000,x
		rts

tile_read_2	ldy $8000,x
		rts

tile_read_3	ldy $8000,x
		rts

tile_read_4	ldy $8000,x
		rts

tile_read_5	ldy $8000,x
		rts


; Colour RAM shunt
colour_shunt	lda #$80
cs_wait		cmp $d012
		bcs cs_wait

		ldx #$00
cs_loop_1	lda $d8c9,x
		sta $d8c8,x
		lda $d8f1,x
		sta $d8f0,x
		lda $d919,x
		sta $d918,x
		lda $d941,x
		sta $d940,x
		inx
		cpx #$27
		bne cs_loop_1

		ldx #$00
cs_loop_2	lda $d969,x
		sta $d968,x
		lda $d991,x
		sta $d990,x
		lda $d9b9,x
		sta $d9b8,x
		lda $d9e1,x
		sta $d9e0,x
		inx
		cpx #$27
		bne cs_loop_2

		ldx #$00
cs_loop_3	lda $da09,x
		sta $da08,x
		lda $da31,x
		sta $da30,x
		lda $da59,x
		sta $da58,x
		lda $da81,x
		sta $da80,x
		inx
		cpx #$27
		bne cs_loop_3

		ldx #$00
cs_loop_4	lda $daa9,x
		sta $daa8,x
		lda $dad1,x
		sta $dad0,x
		lda $daf9,x
		sta $daf8,x
		lda $db21,x
		sta $db20,x
		inx
		cpx #$27
		bne cs_loop_4

		ldx #$00
cs_loop_5	lda $db49,x
		sta $db48,x
		lda $db71,x
		sta $db70,x
		lda $db99,x
		sta $db98,x
		lda $dbc1,x
		sta $dbc0,x
		inx
		cpx #$27
		bne cs_loop_5
		rts


; Self modifying code for the map reader
map_read	lda $9000
		inc map_read+$01
		bne mr_out
		inc map_read+$02
mr_out		rts


; Column readers for buffer 2
buffer_write_1	ldx tile_cnt
		jsr tile_read_1
		sty buffer_2+$0ee
		lda col_decode,y
		sta $d8ef

		txa
		clc
		adc #$04
		tax
		jsr tile_read_1
		sty buffer_2+$116
		lda col_decode,y
		sta $d917

		txa
		clc
		adc #$04
		tax
		jsr tile_read_1
		sty buffer_2+$13e
		lda col_decode,y
		sta $d93f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_1
		sty buffer_2+$166
		lda col_decode,y
		sta $d967


		ldx tile_cnt
		jsr tile_read_2
		sty buffer_2+$18e
		lda col_decode,y
		sta $d98f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_2
		sty buffer_2+$1b6
		lda col_decode,y
		sta $d9b7

		txa
		clc
		adc #$04
		tax
		jsr tile_read_2
		sty buffer_2+$1de
		lda col_decode,y
		sta $d9df

		txa
		clc
		adc #$04
		tax
		jsr tile_read_2
		sty buffer_2+$206
		lda col_decode,y
		sta $da07


		ldx tile_cnt
		jsr tile_read_3
		sty buffer_2+$22e
		lda col_decode,y
		sta $da2f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_3
		sty buffer_2+$256
		lda col_decode,y
		sta $da57

		txa
		clc
		adc #$04
		tax
		jsr tile_read_3
		sty buffer_2+$27e
		lda col_decode,y
		sta $da7f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_3
		sty buffer_2+$2a6
		lda col_decode,y
		sta $daa7


		ldx tile_cnt
		jsr tile_read_4
		sty buffer_2+$2ce
		lda col_decode,y
		sta $dacf

		txa
		clc
		adc #$04
		tax
		jsr tile_read_4
		sty buffer_2+$2f6
		lda col_decode,y
		sta $daf7

		txa
		clc
		adc #$04
		tax
		jsr tile_read_4
		sty buffer_2+$31e
		lda col_decode,y
		sta $db1f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_4
		sty buffer_2+$346
		lda col_decode,y
		sta $db47


		ldx tile_cnt
		jsr tile_read_5
		sty buffer_2+$36e
		lda col_decode,y
		sta $db6f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_5
		sty buffer_2+$396
		lda col_decode,y
		sta $db97

		txa
		clc
		adc #$04
		tax
		jsr tile_read_5
		sty buffer_2+$3be
		lda col_decode,y
		sta $dbbf

		txa
		clc
		adc #$04
		tax
		jsr tile_read_5
		sty buffer_2+$3e6
		lda col_decode,y
		sta $dbe7


; Write in starfield for buffer 2
		lda #$ff

		ldy buffer_2+$10f
		bne *+$05
		sta buffer_2+$10f

		ldy buffer_2+$144
		bne *+$05
		sta buffer_2+$144

		ldy buffer_2+$1a3
		bne *+$05
		sta buffer_2+$1a3

		ldy buffer_2+$1ee
		bne *+$05
		sta buffer_2+$1ee

		ldy buffer_2+$24d
		bne *+$05
		sta buffer_2+$24d

		ldy buffer_2+$2a1
		bne *+$05
		sta buffer_2+$2a1

		ldy buffer_2+$2d9
		bne *+$05
		sta buffer_2+$2d9

		ldy buffer_2+$336
		bne *+$05
		sta buffer_2+$336

		ldy buffer_2+$375
		bne *+$05
		sta buffer_2+$375

		ldy buffer_2+$3dc
		bne *+$05
		sta buffer_2+$3dc

		rts


; Map reader self modifying code reset
map_read_rst	lda #$00
		sta map_read+$01
		lda #$90
		sta map_read+$02
		jsr tile_update


; Scroll fast winder for the start of game
		ldy #$00
buffer_fwind	sty coll_temp+$00
		jsr buffer_swap_1a
		jsr buffer_swap_1b
		jsr colour_shunt
		jsr buffer_swap_2a
		jsr buffer_swap_2b
		jsr colour_shunt

		ldy coll_temp+$00
		iny
		cpy #$14
		bne buffer_fwind
		rts


; column readers for buffer 1
buffer_write_2	ldx tile_cnt
		jsr tile_read_1
		sty buffer_1+$0ee
		lda col_decode,y
		sta $d8ef

		txa
		clc
		adc #$04
		tax
		jsr tile_read_1
		sty buffer_1+$116
		lda col_decode,y
		sta $d917

		txa
		clc
		adc #$04
		tax
		jsr tile_read_1
		sty buffer_1+$13e
		lda col_decode,y
		sta $d93f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_1
		sty buffer_1+$166
		lda col_decode,y
		sta $d967


		ldx tile_cnt
		jsr tile_read_2
		sty buffer_1+$18e
		lda col_decode,y
		sta $d98f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_2
		sty buffer_1+$1b6
		lda col_decode,y
		sta $d9b7

		txa
		clc
		adc #$04
		tax
		jsr tile_read_2
		sty buffer_1+$1de
		lda col_decode,y
		sta $d9df

		txa
		clc
		adc #$04
		tax
		jsr tile_read_2
		sty buffer_1+$206
		lda col_decode,y
		sta $da07


		ldx tile_cnt
		jsr tile_read_3
		sty buffer_1+$22e
		lda col_decode,y
		sta $da2f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_3
		sty buffer_1+$256
		lda col_decode,y
		sta $da57

		txa
		clc
		adc #$04
		tax
		jsr tile_read_3
		sty buffer_1+$27e
		lda col_decode,y
		sta $da7f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_3
		sty buffer_1+$2a6
		lda col_decode,y
		sta $daa7


		ldx tile_cnt
		jsr tile_read_4
		sty buffer_1+$2ce
		lda col_decode,y
		sta $dacf

		txa
		clc
		adc #$04
		tax
		jsr tile_read_4
		sty buffer_1+$2f6
		lda col_decode,y
		sta $daf7

		txa
		clc
		adc #$04
		tax
		jsr tile_read_4
		sty buffer_1+$31e
		lda col_decode,y
		sta $db1f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_4
		sty buffer_1+$346
		lda col_decode,y
		sta $db47


		ldx tile_cnt
		jsr tile_read_5
		sty buffer_1+$36e
		lda col_decode,y
		sta $db6f

		txa
		clc
		adc #$04
		tax
		jsr tile_read_5
		sty buffer_1+$396
		lda col_decode,y
		sta $db97

		txa
		clc
		adc #$04
		tax
		jsr tile_read_5
		sty buffer_1+$3be
		lda col_decode,y
		sta $dbbf

		txa
		clc
		adc #$04
		tax
		jsr tile_read_5
		sty buffer_1+$3e6
		lda col_decode,y
		sta $dbe7


; Write in starfield for buffer 1
		lda #$ff

		ldy buffer_1+$10f
		bne *+$05
		sta buffer_1+$10f

		ldy buffer_1+$144
		bne *+$05
		sta buffer_1+$144

		ldy buffer_1+$1a3
		bne *+$05
		sta buffer_1+$1a3

		ldy buffer_1+$1ee
		bne *+$05
		sta buffer_1+$1ee

		ldy buffer_1+$24d
		bne *+$05
		sta buffer_1+$24d

		ldy buffer_1+$2a1
		bne *+$05
		sta buffer_1+$2a1

		ldy buffer_1+$2d9
		bne *+$05
		sta buffer_1+$2d9

		ldy buffer_1+$336
		bne *+$05
		sta buffer_1+$336

		ldy buffer_1+$375
		bne *+$05
		sta buffer_1+$375

		ldy buffer_1+$3dc
		bne *+$05
		sta buffer_1+$3dc

		rts


; Tile self modifying code updaters
tile_update	jsr map_read
		sta tile_read_1+$01
		asl tile_read_1+$01
		asl tile_read_1+$01
		asl tile_read_1+$01
		asl tile_read_1+$01
		lsr
		lsr
		lsr
		lsr
		clc
		adc #$80
		sta tile_read_1+$02

		jsr map_read
		sta tile_read_2+$01
		asl tile_read_2+$01
		asl tile_read_2+$01
		asl tile_read_2+$01
		asl tile_read_2+$01
		lsr
		lsr
		lsr
		lsr
		clc
		adc #$80
		sta tile_read_2+$02

		jsr map_read
		sta tile_read_3+$01
		asl tile_read_3+$01
		asl tile_read_3+$01
		asl tile_read_3+$01
		asl tile_read_3+$01
		lsr
		lsr
		lsr
		lsr
		clc
		adc #$80
		sta tile_read_3+$02

		jsr map_read
		sta tile_read_4+$01
		asl tile_read_4+$01
		asl tile_read_4+$01
		asl tile_read_4+$01
		asl tile_read_4+$01
		lsr
		lsr
		lsr
		lsr
		clc
		adc #$80
		sta tile_read_4+$02

		jsr map_read
		sta tile_read_5+$01
		asl tile_read_5+$01
		asl tile_read_5+$01
		asl tile_read_5+$01
		asl tile_read_5+$01
		lsr
		lsr
		lsr
		lsr
		clc
		adc #$80
		sta tile_read_5+$02
		rts


; Decode the status bar
status_decode	lda lives
		asl
		asl
		asl
		tay
		ldx #$00
sd_loop		lda lives_display,y
		sta buffer_1+$060,x

		lda score,x
		clc
		adc #$21
		sta buffer_1+$02e,x

		lda hi_score,x
		clc
		adc #$21
		sta buffer_1+$042,x
		iny
		inx
		cpx #$06
		bne sd_loop

		rts


; Bump the score (1 point)
bump_score_1	ldx #$05
		jmp bs_loop


; Bump the score (10 points)
bump_score_10	ldx #$04
		jmp bs_loop


; Bump the score (1000 points)
bump_score_1000	ldx #$02
		jmp bs_loop


; Bump the score (100 points)
bump_score_100	ldx #$03
bs_loop		lda score,x
		clc
		adc #$01
		cmp #$0a
		beq bs_cnt
		sta score,x
		jmp bs_out

bs_cnt		lda #$00
		sta score,x
		dex
		cpx #$ff
		bne bs_loop


; Score to high score comparison
bs_out		ldx #$00
score_scan	lda score,x
		cmp hi_score,x
		beq ss_cnt
		bcc ss_out
		bcs hiscore_update
ss_cnt		inx
		cpx #$06
		bne score_scan
ss_out		rts


; Score to high score copy
hiscore_update	ldx #$00
hsu_loop	lda score,x
		sta hi_score,x
		inx
		cpx #$06
		bne hsu_loop
		rts


; Call bump score four times for 400 points
bump_score_400	stx rt_store
		jsr bump_score_100
		jsr bump_score_100
		jsr bump_score_100
		jsr bump_score_100
		ldx rt_store
		rts


; Score reset loop
score_reset	ldx #$00
		txa
sr_loop		sta score,x
		inx
		cpx #$06
		bne sr_loop
		rts


; Player to background collision checks
player_colls	lda sprite_pos+$01
		sec
		sbc #$30
		lsr
		lsr
		lsr
		tax

		lda scrn_low,x
		sta coll_read+$01
		lda scrn_high,x
		ldy scroll_x
		cpy #$08
		bcc pc_okay
		clc
		adc #$04
pc_okay		sta coll_read+$02

		lda sprite_pos+$00
		sec
		sbc #$08
		lsr
		lsr
		tax
		jsr coll_read
		sta coll_grind+$00
		txa
		clc
		adc #$50
		tax
		jsr coll_read
		sta coll_grind+$01
		txa
		sec
		sbc #$28
		tax
		jsr coll_read
		beq pc_no_coll


; Collision occurred, so flag it
		inc coll_flag

pc_no_coll	jsr bullet_colls
		lda scroll_x
		and #$03
		cmp #$03
		beq player_grinds
		rts


; Player grind collision checks
player_grinds	lda coll_grind+$00
		beq pg_chk_2

		lda #$04
		sta sprite_pls_tmr

		jsr bump_score_10
		jsr bump_score_10
		jsr bump_score_1
		jsr bump_score_1
		jsr bump_score_1
		jsr bump_score_1
		jsr bump_score_1


pg_chk_2	lda coll_grind+$01
		beq pg_out

		lda #$04
		sta sprite_pls_tmr

		jsr bump_score_10
		jsr bump_score_10
		jsr bump_score_1
		jsr bump_score_1
		jsr bump_score_1
		jsr bump_score_1
		jsr bump_score_1

pg_out		rts


; Bullet to background checks
bullet_colls	lda sprite_pos+$03
		sec
		sbc #$28
		lsr
		lsr
		lsr
		tax
		lda scrn_low,x
		sta coll_read+$01
		lda scrn_high,x
		ldy scroll_x
		cpy #$08
		bcc bc_okay
		clc
		adc #$04
bc_okay		sta coll_read+$02

		lda sprite_pos+$02
		sec
		sbc #$04
		lsr
		lsr
		tax
		jsr coll_read
		bne bullet_reset
		inx
		jsr coll_read
		bne bullet_reset
		dex
		dex
		jsr coll_read
		bne bullet_reset
		rts


; Reset the bullet
bullet_reset	lda #$00
		sta sprite_pos+$02
		sta sprite_pos+$03
		sta enemy_spds+$02
		sta enemy_spds+$03
		rts


; Background collision self modifying code
coll_read	ldy $6464,x
		lda col_decode,y
		and #$f0
		rts


; Titles page text
ttl_credits	!scr "edge grinder     by     cosine systems"

		!scr "coding                jason t.m.r kelk"
		!scr "graphics           trevor smila storey"
		!scr "music by            sean odie connolly"

		!scr "released by        format war and rgcd"


; Titles page scroll text
scrolltext	!scr "edge grinder    "
		!scr "developed by cosine "
		!scr "for format war   "
		!scr "published on cartridge by rgcd    "
		!scr "code by jason   "
		!scr "graphics by smila   "
		!scr "music by sean    "

		!scr "quick hellos to the cosine inmates,"
		!scr "the forum regulars at oldschool gaming and "
		!scr "format war,"
		!scr "smila and the ovine boys,"
		!scr "james and everyone at rgcd,"
		!scr "kenz and co. at psytronik "
		!scr "and anyone out there actually writing eight bit "
		!scr "code rather than just talking about how to!    "

		!scr "why not visit   "
		!scr "cosine.org.uk   formatwar.net   "
		!scr "rgcd.co.uk        "

		!byte $00


; Character decoding for the zoom scroller
scroll_decode	!byte $00,$01,$02,$03,$04,$05,$06,$07	; @ to G
		!byte $08,$09,$0a,$0b,$0c,$0d,$0e,$0f	; H to O
		!byte $10,$11,$12,$13,$14,$15,$16,$17	; P to W
		!byte $18,$19,$1a,$00,$00,$00,$00,$00	; X to back arrow
		!byte $00,$1b,$00,$00,$00,$00,$00,$00	; space to apostrophe
		!byte $00,$00,$00,$00,$1d,$1e,$1c,$00	; ( to /
		!byte $00,$00,$00,$00,$00,$00,$00,$00	; 0 to 7
		!byte $00,$00,$00,$00,$00,$00,$00,$1f	; 8 to ?


; Score and high score - eight bytes each
score		!byte $00,$00,$00,$00,$00,$00,$00,$00
hi_score	!byte $00,$01,$02,$03,$04,$05,$00,$00


; Lives indicator bars (eight byte runs)
lives_display	!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$8f,$90,$00,$00,$00,$00
		!byte $00,$8f,$90,$8f,$90,$00,$00,$00
		!byte $8f,$90,$8f,$90,$8f,$90,$00,$00


; Status bar colour data
status_cols	!byte $0b,$0b,$0b,$0b,$0b,$0b,$0d,$0f
		!byte $0f,$0f,$0f,$0d,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0d,$0f,$0f,$0f,$0f,$0d
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$00,$00

		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0d,$0f,$0f,$0f,$0f,$0d,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$00,$00

		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0d,$0b
		!byte $0f,$0f,$0b,$0d,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0d,$0b,$0f,$0f,$0b,$0d
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$00,$00

		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0d,$0f,$0f,$0f,$0f,$0d,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$0b,$0b
		!byte $0b,$0b,$0b,$0b,$0b,$0b,$00,$00

		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00


; status bar pulse data
status_pulse	!byte $0e,$0a,$0c,$0d,$0b,$0f,$09,$09
		!byte $0f,$0b,$0d,$0c,$0a,$0e,$08,$08
		!byte $0e,$0a,$0c,$0d,$0b,$0f,$09,$09
		!byte $0f,$0b,$0d,$0c,$0a,$0e,$08,$08


; Mega Hero text for the completion sequence
mega_hero_txt	!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$00,$20,$20,$20
		!byte $20,$20,$00,$00,$00,$20,$20,$20

		!byte $20,$20,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$20,$00
		!byte $20,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00

		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$20,$20,$20,$20

		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$20

		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$00,$00,$00,$00

		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$00,$00

		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$00,$20,$20,$20

		!byte $20,$20,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00

		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$20,$20,$20,$20
		!byte $20,$20,$00,$00,$00,$20,$20,$20

		!byte $20,$20,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00

		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$20,$20,$20,$20

		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00

		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$20,$20
		!byte $20,$20,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$00,$00,$00,$00

		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$00,$00

		!byte $00,$20,$20,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$20,$20,$00,$00
		!byte $00,$20,$20,$00,$20,$20,$20,$20
		!byte $20,$20,$20,$00,$20,$20,$00,$00

		!byte $00,$20,$20,$00,$00,$20,$20,$20
		!byte $20,$20,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00


; Collision and character colour decoding table
; The lower nybble is the character colour, the upper tells the
; collision system if a character is fatal or not
col_decode	!byte $05,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1a,$1a,$1a
		!byte $1c,$1c,$1a,$1b,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b

		!byte $1c,$1c,$1c,$1b,$1b,$1b,$1b,$1b
		!byte $1f,$1b,$1b,$1d,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1f,$1b,$1b,$1d,$1b,$1b,$1b,$1b

		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$1b


		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1d,$1d
		!byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1b

		!byte $1c,$1c,$1c,$1d,$1d,$1d,$1d,$1d
		!byte $1d,$1d,$1d,$1d,$1d,$1d,$1d,$1d

		!byte $1b,$1b,$1b,$1d,$1d,$1d,$1b,$1b
		!byte $1b,$1b,$1b,$1b,$1b,$1b,$1b,$03


; Screen co-ordinates for collisions, low bytes first then high
scrn_low	!byte $00,$28,$50,$78,$a0,$c8,$f0,$18
		!byte $40,$68,$90,$b8,$e0,$08,$30,$58
		!byte $80,$a8,$d0,$f8,$20,$48,$70,$98

scrn_high	!byte $50,$50,$50,$50,$50,$50,$50,$51
		!byte $51,$51,$51,$51,$51,$52,$52,$52
		!byte $52,$52,$52,$52,$53,$53,$53,$53


; Starfield decoder - just the bits moving through the star char
star_decode	!byte $80,$40,$20,$10,$08,$04,$02,$01


; Player explosion direction vectors
explosion_dirs	!byte $00,$00,$02,$03,$19,$09,$44,$44
		!byte $22,$22,$8a,$8a,$45,$45,$26,$26


; Sprite data pointer decoders
sprite_dp_dcd	!byte $60,$61,$62,$63,$64,$65,$66,$67	; $00 to $0a	explosion
		!byte $68,$69,$6a

		!byte $6b,$6c,$6d,$6e,$6f,$70,$71	; $0b to $11	player ship

		!byte $72				; $12		player bullet

		!byte $73,$74,$75,$76,$77,$76,$75,$74	; $13 to $1a	enemy_1
		!byte $78,$79,$7a,$7b,$7c,$7d		; $1b to $20	enemy_2
		!byte $7e,$7f,$80,$81			; $21 to $24	enemy_3
		!byte $82,$83,$84,$85,$86,$87,$86,$85	; $25 to $2e	enemy_4
		!byte $84,$83
		!byte $88,$89,$8a,$8b,$8c,$8d		; $2f to $34	enemy_5
		!byte $8e,$8f,$90,$91,$92,$93		; $35 to $3a	enemy_6
		!byte $94,$95,$96,$97,$98,$99		; $3b to $40	enemy_7
		!byte $9a,$9b,$9c,$9d,$9e,$9f,$a0	; $41 to $47	enemy_8

		!byte $a1,$a2,$a3,$a4,$a5,$a6		; $48 to $4d	enemy_9
		!byte $a7,$a8,$a9,$aa,$ab,$ac		; $4e to $53	enemy_10
		!byte $ad,$ae,$af,$b0,$b1,$b2,$b3,$b4	; $54 to $5b	enemy_11
		!byte $b5,$b6,$b7,$b8,$b9,$ba,$bb,$bc	; $5c to $63	enemy_12

		!byte $bd,$be,$bf,$c0,$c1,$c2,$c3,$c4	; $64 to $6b	enemy_13
		!byte $c5,$c6,$c7,$c8,$c9,$ca		; $6c to $71	enemy_14
		!byte $cb,$cc,$cd,$ce,$cf,$d0		; $72 to $77	enemy_15
		!byte $d1,$d2,$d3,$d4,$d5,$d6		; $78 to $7d	enemy_16


; Sprite colour decoders
sprite_col_dcd	!byte $77,$77,$77,$aa,$aa,$aa,$aa,$22	; $00 to $0a	explosion
		!byte $22,$22,$22

		!byte $43,$43,$43,$43,$43,$43,$43	; $0b to $11	player ship

		!byte $77				; $12		player bullet

		!byte $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f	; $13 to $1a	enemy_1
		!byte $1e,$1e,$1e,$1e,$1e,$1e		; $1b to $20	enemy_2
		!byte $15,$15,$15,$15			; $21 to $24	enemy_3
		!byte $13,$13,$13,$13,$13,$13,$13,$13	; $25 to $2e	enemy_4
		!byte $13,$13

		!byte $1f,$1f,$1f,$1f,$1f,$1f		; $2f to $34	enemy_5
		!byte $13,$13,$13,$13,$13,$13		; $35 to $3a	enemy_6
		!byte $1a,$1a,$1a,$1a,$1a,$1a		; $3b to $40	enemy_7
		!byte $17,$17,$17,$17,$17,$17,$17	; $41 to $47	enemy_8

		!byte $1e,$1e,$1e,$1e,$1e,$1e		; $48 to $4d	enemy_9
		!byte $15,$15,$15,$15,$15,$15		; $4e to $53	enemy_10
		!byte $1f,$1f,$1f,$1f,$1f,$1f,$1f,$1f	; $54 to $5b	enemy_11
		!byte $13,$13,$13,$13,$13,$13,$13,$13	; $5c to $63	enemy_12

		!byte $17,$17,$17,$17,$17,$17,$17,$17	; $64 to $6b	enemy_13
		!byte $1a,$1a,$1a,$1a,$1a,$1a		; $6c to $71	enemy_14
		!byte $1f,$1f,$1f,$1f,$1f,$1f		; $72 to $77	enemy_15
		!byte $13,$13,$13,$13,$13,$13		; $78 to $7d	enemy_16


; Animation start and end pairs
anim_decode	!byte $00,$0b		; explosion

		!byte $0b,$12		; player ship
		!byte $12,$13		; player bullet

		!byte $13,$1b		; enemy_1
		!byte $1b,$21		; enemy_2
		!byte $21,$25		; enemy_3
		!byte $25,$2f		; enemy_4

		!byte $2f,$35		; enemy_5
		!byte $35,$3b		; enemy_6
		!byte $3b,$41		; enemy_7
		!byte $41,$48		; enemy_8

		!byte $48,$4e		; enemy_9
		!byte $4e,$54		; enemy_10
		!byte $54,$5c		; enemy_11
		!byte $5c,$64		; enemy_12

		!byte $64,$6c		; enemy_13
		!byte $6c,$72		; enemy_14
		!byte $72,$78		; enemy_15
		!byte $78,$7e		; enemy_16


; Sprite position, data pointer and colour defaults
spr_defaults	!byte $28,$a0,$00,$00,$00,$00,$00,$00
		!byte $00,$00,$00,$00,$00,$00,$00,$00
		!byte $0b,$13,$00,$00,$00,$00,$00,$00

; sprite animation defaults
anim_defaults	!byte $0b,$12,$00,$00,$00,$00,$00,$00
		!byte $12,$13,$00,$00,$00,$00,$00,$00


; Enemy movement control data, 9 bytes per object
; X start co-ordinate, Y start co-ordinate
; Movement command 1
; Movement command 2
; "Rocker" value for movement commands
; Timer stop value for movement commands
; Object to use
; Shielding value (hits required to destroy)
; The time to next object

; Wave 1
wave_data	!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $00		; timer reset point
		!byte enemy_10		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_5		; object
		!byte $03		; shielding
		!byte $00		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_5		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $00		; timer reset point
		!byte enemy_10		; object
		!byte $03		; shielding
		!byte $90		; time to next


; Wave 2 - two slow movers and two fast movers
		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_2		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_2		; object
		!byte $05		; shielding
		!byte $40		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $20		; time to next


; Wave 3 - moving wall
		!byte $ac,$88		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $80		; movement rocker
		!byte $00		; timer reset point
		!byte enemy_6		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $80		; movement rocker
		!byte $00		; timer reset point
		!byte enemy_6		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $ac,$b8		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $80		; movement rocker
		!byte $00		; timer reset point
		!byte enemy_6		; object
		!byte $05		; shielding
		!byte $40		; time to next


; Wave 4 - zig-zag up
		!byte $ac,$bc		; X and Y
		!byte left_1		; move 1
		!byte up_1		; move 2
		!byte $60		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_13		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$bc		; X and Y
		!byte left_1		; move 1
		!byte up_1		; move 2
		!byte $60		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_16		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$bc		; X and Y
		!byte left_1		; move 1
		!byte up_1		; move 2
		!byte $60		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_13		; object
		!byte $04		; shielding
		!byte $90		; time to next


; Wave 5 - whizzing on
		!byte $ac,$c0		; X and Y
		!byte left_2		; move 1
		!byte left_1		; move 2
		!byte $18		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_1		; move 2
		!byte $18		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$b0		; X and Y
		!byte left_2		; move 1
		!byte left_1		; move 2
		!byte $18		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $70		; time to next


; Wave 6
		!byte $ac,$90		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_2		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$b0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_2		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_14		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_14		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $80		; movement rocker
		!byte $00		; timer reset point
		!byte enemy_15		; object
		!byte $03		; shielding
		!byte $a0		; time to next


; Wave 7 - fast greens
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $30		; time to next


; Wave 8 - moving towards centre
		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $70		; time to next


; Wave 9 - convenient gap at the top
		!byte $9c,$40		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_8		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $9c,$40		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_1		; move 2
		!byte $30		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_8		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $9c,$40		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_1		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_8		; object
		!byte $03		; shielding
		!byte $50		; time to next


; Wave 10 - fast greens through a tight gap
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $20		; time to next


; Wave 11 - combining wave around central landscape detail
		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $04		; shielding
		!byte $90		; time to next


; Wave 12 - splitting wave around central landscape detail
		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $04		; shielding
		!byte $88		; time to next


; Wave 13 - Zynaps-like ships that speed up
		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $02		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $02		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $02		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $02		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $02		; shielding
		!byte $78		; time to next


; Wave 14 - four lining up to use the landscape gap
		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $90		; time to next


; Wave 15 - swapping pairs
		!byte $ac,$b8		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1+down_1	; move 2
		!byte $12		; movement rocker
		!byte $24		; timer reset point
		!byte enemy_9		; object
		!byte $05		; shielding
		!byte $0e		; time to next

		!byte $ac,$b8		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1+down_1	; move 2
		!byte $12		; movement rocker
		!byte $24		; timer reset point
		!byte enemy_9		; object
		!byte $05		; shielding
		!byte $52		; time to next

		!byte $ac,$b8		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1+down_1	; move 2
		!byte $12		; movement rocker
		!byte $24		; timer reset point
		!byte enemy_7		; object
		!byte $05		; shielding
		!byte $0e		; time to next

		!byte $ac,$b8		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1+down_1	; move 2
		!byte $12		; movement rocker
		!byte $24		; timer reset point
		!byte enemy_7		; object
		!byte $05		; shielding
		!byte $62		; time to next


; Wave 16 - zig zag up
		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $04		; shielding
		!byte $78		; time to next


; Wave 17 - zig zag down
		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $74		; timer reset point
		!byte enemy_5		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $74		; timer reset point
		!byte enemy_5		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $74		; timer reset point
		!byte enemy_5		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $74		; timer reset point
		!byte enemy_5		; object
		!byte $03		; shielding
		!byte $60		; time to next


; Wave 18 - three speeding up
		!byte $ac,$90		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_10		; object
		!byte $03		; shielding
		!byte $00		; time to next

		!byte $ac,$b0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_10		; object
		!byte $03		; shielding
		!byte $20		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_10		; object
		!byte $03		; shielding
		!byte $60		; time to next


; Wave 19 - fast greens through a tight gap again
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $20		; time to next


; Wave 20 - two moving together, then two apart
		!byte $ac,$90		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $58		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$b0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $58		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $40		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $58		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $58		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $70		; time to next


; Wave 21 - aiming for another landscape gap
		!byte $ac,$7c		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_1		; move 2
		!byte $11		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$c4		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1		; move 2
		!byte $11		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$7c		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_1		; move 2
		!byte $11		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $40		; time to next


; Wave 21 - blocker
		!byte $bc,$a0		; X and Y
		!byte left_1		; move 1
		!byte stop		; move 2
		!byte $60		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_13		; object
		!byte $18		; shielding
		!byte $e0		; time to next


; Wave 22 - this enemy doesn't appear and is here as a "spacer"!
		!byte $00,$00		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $10		; movement rocker
		!byte $20		; timer reset point
		!byte enemy_1		; object
		!byte $20		; shielding
		!byte $30		; time to next


; Wave 22 - down/left then left
		!byte $bc,$60		; X and Y
		!byte left_2+down_1	; move 1
		!byte left_2		; move 2
		!byte $20		; movement rocker
		!byte $e0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $bc,$60		; X and Y
		!byte left_2+down_1	; move 1
		!byte left_2		; move 2
		!byte $20		; movement rocker
		!byte $e0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $bc,$60		; X and Y
		!byte left_2+down_1	; move 1
		!byte left_2		; move 2
		!byte $20		; movement rocker
		!byte $e0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $bc,$60		; X and Y
		!byte left_2+down_1	; move 1
		!byte left_2		; move 2
		!byte $20		; movement rocker
		!byte $e0		; timer reset point
		!byte enemy_1		; object
		!byte $03		; shielding
		!byte $50		; time to next


; Wave 23 - down/left then left
		!byte $bc,$70		; X and Y
		!byte left_2		; move 1
		!byte left_2+down_1	; move 2
		!byte $30		; movement rocker
		!byte $50		; timer reset point
		!byte enemy_5		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $bc,$70		; X and Y
		!byte left_2		; move 1
		!byte left_2+down_1	; move 2
		!byte $30		; movement rocker
		!byte $50		; timer reset point
		!byte enemy_5		; object
		!byte $02		; shielding
		!byte $10		; time to next


; Wave 24 - stopper
		!byte $bc,$70		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $80		; timer reset point
		!byte enemy_8		; object
		!byte $05		; shielding
		!byte $50		; time to next


; Wave 25
		!byte $bc,$6c		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $30		; movement rocker
		!byte $80		; timer reset point
		!byte enemy_6		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $bc,$78		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $30		; movement rocker
		!byte $80		; timer reset point
		!byte enemy_6		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $bc,$60		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $30		; movement rocker
		!byte $80		; timer reset point
		!byte enemy_6		; object
		!byte $05		; shielding
		!byte $20		; time to next


; Wave 26 - 'nother stopper
		!byte $bc,$6c		; X and Y
		!byte left_1		; move 1
		!byte stop		; move 2
		!byte $60		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_13		; object
		!byte $0c		; shielding
		!byte $d0		; time to next


; Wave 27 - pairs going up/left and then left
		!byte $bc,$c0		; X and Y
		!byte left_2+up_1	; move 1
		!byte left_2		; move 2
		!byte $30		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_10		; object
		!byte $02		; shielding
		!byte $00		; time to next

		!byte $bc,$e0		; X and Y
		!byte left_2+up_1	; move 1
		!byte left_2		; move 2
		!byte $30		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_10		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $bc,$c0		; X and Y
		!byte left_2+up_1	; move 1
		!byte left_2		; move 2
		!byte $28		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_11		; object
		!byte $02		; shielding
		!byte $00		; time to next

		!byte $bc,$e0		; X and Y
		!byte left_2+up_1	; move 1
		!byte left_2		; move 2
		!byte $28		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_11		; object
		!byte $02		; shielding
		!byte $68		; time to next


; Wave 28 - train of five, left then up/left
		!byte $bc,$d0		; X and Y
		!byte left_2		; move 1
		!byte left_2+up_1	; move 2
		!byte $20		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_5		; object
		!byte $01		; shielding
		!byte $08		; time to next

		!byte $bc,$d0		; X and Y
		!byte left_2		; move 1
		!byte left_2+up_1	; move 2
		!byte $20		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_8		; object
		!byte $01		; shielding
		!byte $08		; time to next

		!byte $bc,$d0		; X and Y
		!byte left_2		; move 1
		!byte left_2+up_1	; move 2
		!byte $20		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_5		; object
		!byte $01		; shielding
		!byte $08		; time to next

		!byte $bc,$d0		; X and Y
		!byte left_2		; move 1
		!byte left_2+up_1	; move 2
		!byte $20		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_8		; object
		!byte $01		; shielding
		!byte $08		; time to next

		!byte $bc,$d0		; X and Y
		!byte left_2		; move 1
		!byte left_2+up_1	; move 2
		!byte $20		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_5		; object
		!byte $01		; shielding
		!byte $70		; time to next


; Wave 29 - Zynaps-like ships that speed up
		!byte $ac,$d0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$dc		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$c4		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$d6		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$ca		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $60		; time to next


; Wave 30
		!byte $bc,$60		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $40		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_10		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $bc,$60		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $40		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_14		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $bc,$60		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $40		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_10		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $bc,$d0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $40		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_14		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $bc,$d0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $40		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_10		; object
		!byte $04		; shielding
		!byte $68		; time to next


; Wave 31 - splitting around landscape feature
		!byte $bc,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $60		; time to next


; Wave 32 - five flappy fings
		!byte $bc,$70		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $10		; timer reset point
		!byte enemy_6		; object
		!byte $06		; shielding
		!byte $18		; time to next

		!byte $bc,$60		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $10		; timer reset point
		!byte enemy_6		; object
		!byte $06		; shielding
		!byte $18		; time to next

		!byte $bc,$90		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $10		; timer reset point
		!byte enemy_6		; object
		!byte $06		; shielding
		!byte $60		; time to next

		!byte $bc,$90		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $10		; timer reset point
		!byte enemy_6		; object
		!byte $06		; shielding
		!byte $18		; time to next

		!byte $bc,$70		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $20		; movement rocker
		!byte $10		; timer reset point
		!byte enemy_6		; object
		!byte $06		; shielding
		!byte $e0		; time to next


; Wave 33
		!byte $bc,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_5		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $78		; timer reset point
		!byte enemy_5		; object
		!byte $05		; shielding
		!byte $50		; time to next


; Wave 34 - swappers
		!byte $bc,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_8		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_8		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_8		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $bc,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_8		; object
		!byte $05		; shielding
		!byte $b0		; time to next


; Wave 35 - fast greens
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $18		; time to next


; Wave 36 - blockers
		!byte $bc,$a0		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_13		; object
		!byte $10		; shielding
		!byte $a0		; time to next

		!byte $bc,$90		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_16		; object
		!byte $0c		; shielding
		!byte $10		; time to next

		!byte $bc,$b0		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_16		; object
		!byte $0c		; shielding
		!byte $90		; time to next


; Wave 37 - combiners
		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $58		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $58		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $60		; time to next


; Wave 38 - more combiners
		!byte $ac,$78		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $58		; movement rocker
		!byte $6c		; timer reset point
		!byte enemy_5		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $58		; movement rocker
		!byte $6c		; timer reset point
		!byte enemy_5		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$c8		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $6c		; timer reset point
		!byte enemy_5		; object
		!byte $04		; shielding
		!byte $60		; time to next


; Wave 39 - even more combiners
		!byte $ac,$d0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1		; move 2
		!byte $58		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$70		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $58		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_1		; object
		!byte $04		; shielding
		!byte $90		; time to next


; Wave 40 - combining around a landscape feature
		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $06		; shielding
		!byte $18		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $58		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $06		; shielding
		!byte $18		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $58		; movement rocker
		!byte $68		; timer reset point
		!byte enemy_11		; object
		!byte $06		; shielding
		!byte $50		; time to next


; Wave 41 - combining around a landscape feature
		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $06		; shielding
		!byte $18		; time to next

		!byte $ac,$60		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $60		; movement rocker
		!byte $70		; timer reset point
		!byte enemy_3		; object
		!byte $06		; shielding
		!byte $a0		; time to next


; Wave 42 - Zynaps-like ships that speed up
		!byte $ac,$a8		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$98		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $50		; time to next


; Wave 43 - blockers
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $2c		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_16		; object
		!byte $10		; shielding
		!byte $50		; time to next

		!byte $cc,$a0		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $34		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_16		; object
		!byte $10		; shielding
		!byte $80		; time to next


; Wave 44 - combining wave around central landscape detail
		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $06		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $06		; shielding
		!byte $10		; time to next

		!byte $ac,$80		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $06		; shielding
		!byte $10		; time to next

		!byte $ac,$c0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_13		; object
		!byte $06		; shielding
		!byte $70		; time to next


; Wave 45 - splitting wave around central landscape detail
		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+up_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_12		; object
		!byte $05		; shielding
		!byte $68		; time to next


; Wave 46 - wibblers
		!byte $ac,$a8		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1+down_1	; move 2
		!byte $14		; movement rocker
		!byte $28		; timer reset point
		!byte enemy_15		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $ac,$a8		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_1+down_1	; move 2
		!byte $14		; movement rocker
		!byte $28		; timer reset point
		!byte enemy_14		; object
		!byte $05		; shielding
		!byte $50		; time to next


; Wave 47 - zig zag down
		!byte $ac,$70		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $6c		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $ac,$70		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $6c		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $ac,$70		; X and Y
		!byte left_1		; move 1
		!byte left_1+down_1	; move 2
		!byte $50		; movement rocker
		!byte $6c		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $40		; time to next



; Wave 48 - zig zag up
		!byte $ac,$fc		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_2		; move 2
		!byte $44		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_5		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$fc		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_2		; move 2
		!byte $44		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_5		; object
		!byte $04		; shielding
		!byte $48		; time to next


; Wave 49 - fast greens
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$90		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $10		; time to next

		!byte $ac,$b0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $04		; shielding
		!byte $28		; time to next


; Wave 50 - move in for gap
		!byte $ac,$60		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_2		; move 2
		!byte $18		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $00		; time to next

		!byte $ac,$e0		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_2		; move 2
		!byte $18		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $18		; time to next

		!byte $ac,$60		; X and Y
		!byte left_1+down_1	; move 1
		!byte left_2		; move 2
		!byte $18		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $00		; time to next

		!byte $ac,$e0		; X and Y
		!byte left_1+up_1	; move 1
		!byte left_2		; move 2
		!byte $18		; movement rocker
		!byte $c0		; timer reset point
		!byte enemy_1		; object
		!byte $05		; shielding
		!byte $40		; time to next


; Wave 51 - Zynaps-like ships that speed up
		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $18		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_1		; move 1
		!byte left_2		; move 2
		!byte $40		; movement rocker
		!byte $f0		; timer reset point
		!byte enemy_4		; object
		!byte $04		; shielding
		!byte $40		; time to next


; Wave 52 - blockers
		!byte $c0,$b0		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_16		; object
		!byte $0c		; shielding
		!byte $10		; time to next

		!byte $c0,$90		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_16		; object
		!byte $0c		; shielding
		!byte $c0		; time to next


; Wave 53 - fast greens
		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $02		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

		!byte $ac,$a0		; X and Y
		!byte left_2		; move 1
		!byte left_2		; move 2
		!byte $50		; movement rocker
		!byte $60		; timer reset point
		!byte enemy_3		; object
		!byte $03		; shielding
		!byte $10		; time to next

; Wave 54 - blocker
		!byte $c0,$a0		; X and Y
		!byte left_2		; move 1
		!byte stop		; move 2
		!byte $30		; movement rocker
		!byte $a0		; timer reset point
		!byte enemy_13		; object
		!byte $0e		; shielding
		!byte $c8		; time to next


; Wave data end marker (a little bit overkill but it's for the best!)
		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$07
		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$07


; Add in the status bar character data
		* = buffer_1

		!byte $2b,$2c,$2d,$2e,$2f,$30,$31,$32
		!byte $33,$34,$35,$36,$37,$38,$39,$3a
		!byte $3b,$3c,$00,$00,$2b,$2c,$3d,$3e
		!byte $3f,$30,$40,$41,$42,$43,$44,$45
		!byte $37,$46,$47,$48,$3b,$3c,$00,$00

		!byte $49,$4a,$4b,$4c,$4d,$4e,$00,$00
		!byte $00,$00,$00,$00,$4f,$50,$51,$52
		!byte $53,$32,$33,$43,$44,$54,$55,$56
		!byte $57,$4e,$00,$00,$00,$00,$00,$00
		!byte $4f,$58,$59,$5a,$5b,$5c,$00,$00

		!byte $00,$5d,$5e,$5f,$60,$61,$62,$63
		!byte $64,$65,$66,$67,$68,$69,$6a,$4e
		!byte $00,$00,$00,$00,$00,$00,$4f,$6b
		!byte $6c,$6d,$6e,$63,$6f,$70,$66,$71
		!byte $72,$73,$74,$5e,$75,$00,$00,$00

		!byte $00,$00,$00,$00,$00,$00,$76,$77
		!byte $00,$78,$79,$7a,$7b,$7c,$7d,$7e
		!byte $7f,$80,$81,$82,$83,$84,$85,$86
		!byte $87,$88,$89,$8a,$8b,$00,$8c,$8d
		!byte $00,$00,$00,$00,$00,$00,$00,$00

		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff
		!byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff