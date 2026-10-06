# BANK0: a reviewer-then-skeptic review of the annotated code (2026-10-06)

Proposals only: nothing here has been applied, assembled or run. Written by a reviewer agent from the converged range analysis (`python tools/beebasm_dataflow.py annotate`) and the source, then checked by a separate skeptic agent told to refute anything with a reachable path that changes behaviour. `docs/dataflow-report.md` has the summary and the gate every change must pass. The skeptic's verdicts come first, the proposals after.

---

# BANK0 verdicts (skeptic stage)

P1: ACCEPTED, 3 bytes. X from `ldx finale_slot` is overwritten by `ldx comp_flag` 4 instructions later; lda/asl/tay don't read X, and lda sets its own N/Z. No IF blocks before no_bang.
P2: ACCEPTED, 2 bytes. A=0 from line 530 survives sta, sta, inc abs, ldx; the next instruction is a store, then `lda #EXPL_LAST`. Works with P1 applied too.
P3: ACCEPTED, 1 byte, 0 cycles. asl/lsr gives A = v AND &7F and C = 0 (bit 0 of v<<1) for every v; adc rewrites N/Z/C/V. No variant code nearby.
P4: ACCEPTED, 3 bytes. finale_slot (&086A) is written only at bank0.asm:488 (0) and :548 (grep of src+lib). game_mode becomes MODE_FINALE only after that 0, so the value is always 0-7. SPR_SLOTS = 8 unconditionally (sprite.asm:61). anim_step (player.asm:471) starts `ldx anim_tmr` and reads neither A nor X, and `lda #FINALE_GAP` overwrites flags. The local label slot_ok has no other referents.
P5: ACCEPTED, 2 bytes. LO(&4000) = LO(&800) = 0, constant in every variant. corner_addr and crtc_addr have no IRQ reader: rupt_vsync/rupt_timer use only crtc_park/crtc_live, and the bank1 readers are star_frame/mega_mess (main line). It only swaps the order of two stores.
P6: ACCEPTED, 4 bytes. It zeroes the same &400-&49F, and the loop exits with A=0 and X=0 (same N/Z as `ldx #0`). C differs (old C=1 from cpx), but map_read_rst->tile_update->map_read starts lda/inc/cpy and never reads C. column_buffer has no IRQ user. No IF blocks.
P7: ACCEPTED, 2 bytes. The CRTC macro (main.asm:230) ends with `lda #0 : sta CRTC_DATA`, so A=0 and Z=1/N=0 are identical. No variant code.
P8: ACCEPTED, 1 byte. A = LO(screen_start/8) = 0 after the CRTC 13 macro. The only code between is the GFX_NULA block (lda#/sta NULA_CTRL), which leaves X alone. pal_loop's first `lda` resets the flags. Hardware write order is unchanged.
P9: ACCEPTED, 3 bytes (write_ptr is zero page, main.asm:697). Both halves are written before the first `sta (write_ptr),y`. Exit A=X=Y=0 and C is untouched in both. No IRQ code (rupture.asm, music, lib) touches write_ptr. Both ASSERTs hold (&4000/&4000).
P10: ACCEPTED, 1 byte. The same 16 bytes are zeroed. X and A are rewritten by `lda #SWRAM_SPRITES0 / ldx / ldy`. Old C=1 vs new C=entry C: bank_call (main.asm:1164) has no php and mega_mess starts with lda/sta and never reads C before overwriting it (no bvc/bvs/clv anywhere, so V is dead too). sprite_pos has no IRQ reader. Note: the reviewer's "bank_call php/plp" remark is wrong, but the conclusion holds.
P11: ACCEPTED, 1 byte. Y=0 on `beq no_bonus` (ldy lives = 0) and on the dey/bne fall-through. The loop's own correctness already needs bump_score_1000 and field_wait to keep Y. MUSIC_AKL's lda/sta music_change leaves Y alone. tya sets the same Z=1/N=0.
P12: ACCEPTED, 1 byte. Falling through `bmi f_release` means N=0, so `bpl` is always taken. The target is +8 (jsr, jsr, bmi), which is in range. No IF blocks.
P13: ACCEPTED, 1 byte. life_lost (player.asm:207) starts `ldx #0 : lda sprite_pos ... cpx`, so A, C, N and Z are dead. `lives` has no IRQ reader: its readers are bank3.asm:535 (status_decode, main line), player.asm:243 and bank0. music_pause is read only by rupt_vsync, and its clear moves 6 cycles later; that is a timing shift of the kind every cycle change makes, and the set of possible IRQ outcomes is the same. lsr leaves A=0.
P14: ACCEPTED, 3 bytes. At title_page entry frame_ready = 0 (setup_display clears it, and frame_wait spins until the IRQ clears it), so the VSync eor #5 flip cannot fire. ttl_active = 0 (cleared at the end of title_page, initialised 0, set only at bank0:628), so neither the `and #&fe` nor ttl_rupt_timer runs. The music call does pha/.../pla:sta &fe34, which restores the value it found. Nothing else in the IRQ writes &FE34, so it is stable between the two reads. No IF blocks.
P15: ACCEPTED, 1 byte (DEV). After the first sec, `#&FF - x` never borrows twice over, and sta keeps C, so C=1 at the second sec.
P16: ACCEPTED, 2 bytes (DEV). lda/sta change only N/Z, and C/V/I reach `bcs` unchanged. N/Z on the rts path differ (lda tim_val+1 vs sbc result), but every TIMMARK site continues with lda/jsr/inc (main.asm:1040, 1065, 1067, 1089), and the TIMMARK macro's own `lda #slot` means no caller could rely on its flags anyway. tim_keep rewrites them with cmp.
P17: ACCEPTED, 3 bytes (DEV). The only callers are tim_mark (A = TIM_RESTORE..TIM_LOGIC = 0..3 via TIMMARK) and tim_handover (TIM_TOTAL = 4). asl of A<128 gives C=0. tim_slots_start = &0A79 in every variant: the GAME_STATE block from &0800 has no IF before it except DEBUG_TIMING itself, so &79+8 = &81 < 256 and the ASSERT holds. Exit C=0, N=0 and Z=0 are the same. V differs: it is 1 for A=4 (&79+8 overflows signed) where the old adc #0 gave 0, and that V leaks out of tim_handover via tim_keep's rts. But there is no bvc, bvs or clv in src, lib or EDGE.lst, and the php/plp pairs only restore. So V is dead.

Totals: release 28 bytes (P1-P14); DEV 34 bytes (+P15-P17 = 6). Refuted: none.


---

# BANK0 proposals (reviewer stage)

Analysed build: DEV (DEBUG_TIMING on, so src/timing.asm is present), MUSIC_AKL=0, GFX_NULA=0.
The other variants were checked by reading the IF blocks around each site. All new code is plain NMOS 6502.
Release-build total: 28 bytes (P1-P14). DEV-only extra: 6 bytes (P15-P17), 34 in the DEV build.
Every-frame code: finale_tick (every frame in MODE_FINALE) and the timing routines (DEV, every frame). All of their proposals SAVE cycles on every path.

---

## P1: finale_tick - drop the dead `ldx finale_slot`
- src/bank0.asm:517
- original
```
    ldx finale_slot
    lda finale_slot
```
- proposal
```
    lda finale_slot
```
- 3 bytes, 4 cycles saved on the bang path. Every frame (finale), cycles only go down.
- argument: `ldx &086a ;| ... | in:- out:-`. X is overwritten at line 522 (`ldx comp_flag`) before anything reads it, and the following `lda` sets N/Z itself. This is the report's dead_insn finding, confirmed. MUSIC_AKL only adds code after `no_bang`.

## P2: finale_tick - A is already 0 before `sta sprite_dp, x`
- src/bank0.asm:536
- original
```
    ldx finale_slot
    lda #0
    sta sprite_dp, x
```
- proposal
```
    ldx finale_slot
    sta sprite_dp, x            ; A is still 0 from the enemy_spds stores
```
- 2 bytes, 2 cycles saved (bang path). Every frame (finale), cycles only go down.
- argument: `lda #&00 ;| A=$00 X=?≡finale_slot ...`. A was set by `lda #0` (line 530) and then used only by `sta` x2, `inc comp_flag` (memory) and `ldx` (X), none of which write A. Z/N afterwards are not live: the next instruction is `sta`, then `lda #EXPL_LAST`. Confirms the report's imm_load finding.

## P3: finale_tick - `asl a : lsr a` in place of `and #&7f : clc`
- src/bank0.asm:526-527
- original
```
    and #&7f
    clc
```
- proposal
```
    asl a                       ; bit 7 out...
    lsr a                       ; ...A = v AND &7F, C = 0
```
- 1 byte saved, cycles unchanged (2+2 = 2+2). Every frame (finale), no cycle increase.
- argument: `asl` then `lsr` leaves A = v AND &7F, and C = bit 0 of (v<<1), which is always 0. So `adc #&5e` gets the same A and C, and gives the same result and flags. The listing shows `clc ;| A=0..127 ... C=?` and `adc #&5e ;| A=0..127 ... C=0`, and the rewrite gives the same pair. No variant code is nearby.

## P4: finale_tick - wrap the slot with AND instead of compare-and-reset
- src/bank0.asm:543-548
- original
```
    inx
    cpx #SPR_SLOTS
    bne slot_ok
    ldx #0
    .slot_ok
    stx finale_slot
```
- proposal
```
    ASSERT SPR_SLOTS = 8        ; a power of two, for the AND
    inx
    txa
    and #SPR_SLOTS-1
    sta finale_slot
```
- 3 bytes saved. Cycles: the old path took 11 (no wrap) or 12 (wrap); the new path takes 10 on both. Every frame (finale), cycles only go down.
- argument: finale_slot is written only by comp_mess (0, line 488) and here (the main.asm:2126/2122 comments say so, and grep agrees), so it is always 0-7. For x in 0..7, (x+1) AND 7 is the same as the inx/cpx/ldx #0 result. A and X are dead after the store: `slot_ok: stx ;| ... in:XV out:V`, the next line is `lda #FINALE_GAP`, and `jsr anim_step ;| ... in:V`. V is not touched by inx/txa/and/sta. Label `slot_ok` is local and has no other referents, so it can go.

## P5: game_init - one `lda #0` for both low address bytes
- src/bank0.asm:277-285
- original
```
    lda #LO(screen_start)
    sta corner_addr
    lda #HI(screen_start)
    sta corner_addr+1

    lda #LO(screen_start/8)
    sta crtc_addr
    lda #HI(screen_start/8)
    sta crtc_addr+1
```
- proposal
```
    ASSERT LO(screen_start/8) = LO(screen_start)
    lda #LO(screen_start)
    sta corner_addr
    sta crtc_addr
    lda #HI(screen_start)
    sta corner_addr+1
    lda #HI(screen_start/8)
    sta crtc_addr+1
```
- 2 bytes, 2 cycles saved. Runs once a game, not every frame.
- argument: screen_start = &4000 (main.asm:255), so both low bytes are 0. The listing shows both loads as `lda #&00`, with the second `;| A=$40`. The values stored are unchanged and only the order of two zero-page stores changes. No IRQ consumer reads crtc_addr: the IRQ reads crtc_live/crtc_park, frame_ready is 0 here, and game_init copies crtc_addr to crtc_live at its end. There are no IF blocks nearby.

## P6: game_init - count col_loop down; it leaves X = 0 for the tile readers
- src/bank0.asm:302-313
- original
```
    ldx #0
    lda #0
    .col_loop
    sta column_buffer, X
    inx
    cpx #column_size
    bcc col_loop

    \\ Initialise the tile readers. map_read_rst ends in tile_update.

    ldx #0
    stx tile_cnt
```
- proposal
```
    ASSERT column_size > 0 AND column_size < 256
    ldx #column_size
    lda #0
    .col_loop
    sta column_buffer-1, X
    dex
    bne col_loop

    \\ Initialise the tile readers (X = 0 from the loop). map_read_rst ends in tile_update.

    stx tile_cnt
```
- 4 bytes saved (`cpx #` and the second `ldx #0`). Cycles: 2 saved per iteration (320 over the loop), plus 2 for the dropped `ldx`. Runs once a game, not every frame.
- argument: the same 160 bytes, &0400-&049F, are zeroed. column_buffer = &400 and column_size = 160 (main.asm:260-261). `sta abs,x` is always 5 cycles, so the page crossing from &03FF costs nothing. The loop exits with X = 0 exactly, so the three `stx` still store 0. The old exit was `ldx #&00 ;| A=$00 X=160..255`. X's liveness is unchanged: `stx &02 ;| ... in:X out:-` and `jsr &1110 ;| ... in:- out:-`. The report's two reg_xfer findings here (txa, tax; 2 bytes) are superseded by this. There are no IF blocks nearby.

## P7: setup_display - A is already 0 after `CRTC 8, 0`
- src/bank0.asm:187-190
- original
```
    CRTC 8, 0

    lda #0
    sta field_count
```
- proposal
```
    CRTC 8, 0                   ; leaves A = 0

    sta field_count
```
- 2 bytes, 2 cycles saved. Boot only.
- argument: the macro ends `lda #v : sta CRTC_DATA` with v = 0 (main.asm:230-233). The listing shows `lda #&00 ;| A=$00 X=? Y=? C=? Z=1 N=0 V=?`. The flags are the same as after the load. This is the report's imm_load at $BD8E, confirmed. The macro's literal 0 is the same in every variant.

## P8: setup_display - `tax` for pal_loop's `ldx #0`, placed ahead of the NuLA block
- src/bank0.asm:120 and 159
- original (line 120, then line 159)
```
    CRTC 13, LO(screen_start/8)
```
```
    ldx #0
    .pal_loop
```
- proposal
```
    CRTC 13, LO(screen_start/8)
    ASSERT LO(screen_start/8) = 0
    tax                         ; X = 0 for pal_loop (the NuLA writes below leave X alone)
```
```
    .pal_loop
```
- 1 byte saved, 0 cycles (tax 2 = ldx# 2). Boot only.
- argument: the listing shows `ldx #&00 ;| A=$00 ...` (the report's reg_xfer at $BD5B). That holds only in the analysed variant: under GFX_NULA, `lda #&40 / lda #&11` (lines 153-158) sit between, and A = &11 at line 159. So the `tax` has to go straight after CRTC 13, where A = LO(screen_start/8) = 0 in every variant. The NuLA block is only `lda #/sta` and does not touch X. pal_loop's order is unchanged.

## P9: clear_play - one `lda #0` for the low pointer byte and the fill value; the page count from A
- src/bank0.asm:208-212
- original
```
    lda #LO(screen_start) : sta write_ptr
    lda #HI(screen_start) : sta write_ptr+1
    ldx #HI(screen_size)
    lda #0
    tay
```
- proposal
```
    ASSERT LO(screen_start) = 0
    ASSERT HI(screen_size) = HI(screen_start)
    lda #HI(screen_start) : sta write_ptr+1
    tax                         ; X = HI(screen_size) pages
    lda #0 : sta write_ptr      ; = LO(screen_start), and the fill value
    tay
```
- 3 bytes, 2 cycles saved. Runs at boot and at title_page entry, never in play.
- argument: screen_start = screen_size = &4000 (main.asm:255-256). The listing shows `ldx #&40 ;| A=$40` (the report's reg_xfer at $BDA1) and `lda #&00 ;| A=$40 X=$40`. It exits with the same A=0, X=0, Y=0 (`rts ;| A=$00 X=$00 Y=$00`). write_ptr is zero page and both halves are written before the first `sta (write_ptr),y`. The two zero-page stores just swap order.

## P10: comp_mess - count the hide loop down
- src/bank0.asm:442-448
- original
```
    ldx #0
    txa
    .hide
    sta sprite_pos, x
    inx
    cpx #2*SPR_SLOTS
    bne hide
```
- proposal
```
    ldx #2*SPR_SLOTS
    lda #0
    .hide
    sta sprite_pos-1, x
    dex
    bne hide
```
- 1 byte saved, 2 cycles per iteration (32 in all). Runs once (game won), not every frame.
- argument: the same 16 bytes, sprite_pos+0..15, are zeroed. It exits with A = 0 and X = 0 instead of X = 16. Both are dead: the next instruction is `lda #&05 ;| ... in:CV out:ACV`, followed by `ldx`/`ldy`. The one flag difference is that the old `cpx` left C=1. bank_call's `jsr &0f69 ;| ... in:AXYNZCV` lists C, but only through its php/plp, and C is dead after it (`ldy &0865 ;| ... in:V out:YZV`). In any case the entry state is `ldx #&00 ;| ... C=1`, and lda/sta/dex/bne do not touch C, so C=1 still reaches bank_call. sprite_pos-1 = &07FF is used only as a base. There are no IF blocks nearby.

## P11: comp_mess - `tya` for `lda #0` at no_bonus
- src/bank0.asm:486
- original
```
    lda #0
    sta comp_flag
```
- proposal
```
    tya                         ; Y = 0 on both ways in: lives = 0, or the dey loop's end
    sta comp_flag
```
- 1 byte saved, 0 cycles. Runs once, not every frame.
- argument: the listing shows `lda #&00 ;| A=? X=? Y=$00 C=? Z=1 N=0` at no_bonus. Both entries have Y=0: `beq no_bonus` on `ldy lives` = 0, and the fall-through from `dey : bne bonus_loop`. Under MUSIC_AKL, `lda #2 : sta music_change` sits between no_bonus and this line and does not touch Y. This is the report's reg_xfer at $BEAD, confirmed in both variants.

## P12: pause_check - `bpl resume` for `jmp resume`
- src/bank0.asm:392
- original
```
    bmi f_release
    jmp resume
```
- proposal
```
    bmi f_release
    bpl resume                  ; N is clear: bmi just fell through
```
- 1 byte saved, 0 cycles (taken branch 3 = jmp 3). Pause loop only.
- argument: `jmp &be67 ;| ... N=0` (the report's jmp_to_branch). Falling through `bmi` means N=0. The target is +8 bytes away (the p_out block: two `jsr` and a `bmi`). There are no IF blocks inside pause_check.

## P13: pause_check abort - `lsr a` makes the 0 after lives = 1
- src/bank0.asm:411-414
- original
```
    lda #0
    sta music_pause
    lda #1
    sta lives
```
- proposal
```
    lda #1
    sta lives
    lsr a                       ; A = 0
    sta music_pause
```
- 1 byte saved, 0 cycles (lsr 2 = lda# 2). One-off (ESCAPE abort).
- argument: `jmp &18b4 ;| ... | in:V out:V`, so A, C, N and Z are all dead into life_lost, and the `lsr`'s C=1 does no harm. The two stores swap order. lives has no IRQ reader: the readers are status_decode in bank 3 (main loop) and player.asm's `dec lives`. music_pause is still 0 well before life_lost runs. The skeptic may prefer to drop this one because it reorders stores.

## P14: title_page - drop the second read of &FE34
- src/bank0.asm:593-601
- original
```
    lda &fe34
    sta ttl_acccon
```
```
    lda &fe34 : and #&ff - 4 : sta &fe34        ; CPU sees MAIN
```
- proposal
```
    lda &fe34
    sta ttl_acccon
```
```
    and #&ff - 4 : sta &fe34                    ; CPU sees MAIN (A is still &FE34)
```
- 3 bytes, 4 cycles saved. Once per title page, not every frame.
- argument: the listing shows `lda &fe34 ;| A=?≡$FE34`. ACCCON is a plain latch. The only IRQ writes to it are: the VSync flip, gated on frame_ready, which is 0 everywhere outside the play loop (main.asm:1013-1014, and frame_wait spins until it clears); the titles' `and #&fe`, gated on ttl_active, which is 0 until later in title_page; and the music call's ora/pla restore, which puts back the value it found. So &FE34 cannot change between the two reads, and the existing read-modify-write already depends on this. There are no IF blocks nearby.

## P15 (DEV only): tim_mark - the second `sec` is dead
- src/timing.asm:113
- original
```
    sec
    lda tim_val   : sbc tim_prev   : sta tim_phase
```
- proposal
```
    lda tim_val   : sbc tim_prev   : sta tim_phase   ; C = 1 still: &FF - x never borrows
```
- 1 byte, 2 cycles saved. Every frame (DEV), cycles only go down.
- argument: the listing shows `sec ;| A=? X=? Y=? C=1 ...`. `lda #&ff : sbc &fe69` with C=1 cannot borrow, and `sta` keeps C. Inside `IF DEBUG_TIMING`, so it saves bytes only in the DEV build.

## P16 (DEV only): tim_mark - php/plp are not needed: lda/sta keep C
- src/timing.asm:117-120
- original
```
    php                          ; carry: clear = borrow = the clock ran
    lda tim_val   : sta tim_prev ; backwards between the two T2 byte reads
    lda tim_val+1 : sta tim_prev+1
    plp
```
- proposal
```
                                 ; carry: clear = borrow = the clock ran
    lda tim_val   : sta tim_prev ; backwards between the two T2 byte reads
    lda tim_val+1 : sta tim_prev+1  ; (lda/sta leave C alone)
```
- 2 bytes, 7 cycles saved. Every frame (DEV), cycles only go down.
- argument: the listing shows `plp ;| ... in:- out:CV` and `bcs &bcbb ;| ... in:CV`, so only C (and V) are wanted after it. lda sets only N/Z and sta sets nothing, so C and V reach `bcs` unchanged. N/Z from the plp are dead.

## P17 (DEV only): tim_setptr - drop `clc` and the `adc #0` high-byte carry
- src/timing.asm:89-95
- original
```
    asl a
    clc
    adc #LO(tim_slots_start)
    sta tim_ptr
    lda #HI(tim_slots_start)
    adc #0
    sta tim_ptr+1
```
- proposal
```
    ASSERT LO(tim_slots_start) + 2*TIM_TOTAL < 256    ; the slots don't cross a page
    asl a                       ; TIM_ < 128, so C = 0
    adc #LO(tim_slots_start)
    sta tim_ptr
    lda #HI(tim_slots_start)
    sta tim_ptr+1
```
- 3 bytes, 4 cycles saved. Every frame (DEV, five calls), cycles only go down.
- argument: `asl a ;| A=0..4` (TIMMARK's constants and `lda #TIM_TOTAL`) gives `clc ;| ... C=0`. `adc #&00 ;| A=$0A ... C=0` adds nothing, because &79+8 = &81 does not carry; the ASSERT keeps it so. V from that adc is no longer written. Nothing in the program branches on V: there is no bvc, bvs or clv in src/ or lib/. The only flag consumers are php/plp pairs, and those just restore. In tim_mark the next `sbc` rewrites V, and in tim_handover tim_keep only uses cmp/bcc/bne.

---

Looked at and rejected:
- Looping setup_display's and title_page's MAIN/SHADOW pairs: saves 4 bytes each but costs about 19 cycles each, over 2 cycles a byte.
- A shared `ldx joy_keys+JOY_FIRE : jmp keydown`: saves 1 byte net but adds 3 cycles to finale_tick every frame.
- Sharing title_page's exit CRTC writes with setup_display: it would add an R5 write and change the order of CRTC shape writes, which is too close to raster timing.
- `bcs tim_keep : rts` to `bcc <rts>`: +1 cycle on the throw-away path, every frame.
