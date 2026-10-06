# BANK1: a reviewer-then-skeptic review of the annotated code (2026-10-06)

Proposals only: nothing here has been applied, assembled or run. Written by a reviewer agent from the converged range analysis (`python tools/beebasm_dataflow.py annotate`) and the source, then checked by a separate skeptic agent told to refute anything with a reachable path that changes behaviour. `docs/dataflow-report.md` has the summary and the gate every change must pass. The skeptic's verdicts come first, the proposals after.

---

# BANK1 shrink proposals - skeptic verdicts

Listings used: build/EDGE.lst (2026-10-06) for the default build. EDGE-CPC, -NULA, -AKL and -AKL-CPC.lst are dated 2026-09-06 19:11-19:16. That is after the last change to src/bank1.asm (b155652, 17:30 the same day), and their non-CPC bank 1 addresses match EDGE.lst byte for byte, so I relied on them for the other variants' addresses. There is no RELEASE listing. bank1.asm has no RELEASE or DEBUG_ IF blocks, and the zero-page block that holds read_ptr/write_ptr/rupt_state has no IFs, so the instruction sizes in bank 1 should be the same under RELEASE.

## The raster hazard behind P1-P6 (it changes timing; it is not about equivalence)

The proposals and the source comment both assume that the `sta &FE21` writes in ttl_raster are on the 1 MHz bus, so that each write lines the loop back up to the 1 MHz clock. They are not. jsbeeb's `is1MHzAccess` (FEslowdown = [T,F,T,T,F,F,T,F]) makes &FE20-&FE3F a 2 MHz access, on the Master as well, which matches the real Video ULA.

- **Nothing absorbs a cycle.** One pass of ttl_r_line is 120 cycles with no page crossing (4+4+4+4+6+89+6+3), and every extra cycle carries forward into every later palette write on that credit line.
- **Default and NuLA builds:** today ttl_pal is at $B4EA, and both indexed loads cross $B500 for X >= 22. Each such pass costs 122 cycles. After -29, ttl_pal is at $B4CD and nothing crosses. For pulse steps p >= 8 on fire 4, and the matching steps on fire 5, the writes on later scanlines therefore move earlier by up to 16 cycles (8 µs) by the 8th scanline.
- **CPC builds:** today the loads cross for X >= 16. After -29, ttl_pal is at $B4D3 and only `ttl_pal+1,x` crosses, at X = 44.
- **Dispatch chain:** fire 5's path through `bne ttl_rt_not4` stops crossing a page, so the fire-5 raster starts 1 cycle earlier. Fire 6 is unchanged, because the crossing moves to `bne ttl_rt_not5`. This holds in the CPC builds too: not3 is at $B5DC today and $B5BF after.
- **The padded loops are safe:** after -29 they stay inside one page (ttl_r_line at $B509 or $B50F, loop end at $B51F or $B525). The bank has no ALIGN, SKIPTO or other ASSERT apart from the two music ones.
- **NuLA builds are immune:** they ignore &FE21 (bank0.asm:144-151).
- **Every subset of P1-P6 gives a different shift.** P6 on its own moves ttl_raster UP by 3. So whatever is measured must be the exact set that ships.

What to measure, in jsbeeb, before and after, for a default build and a -Cpc build: the cycle offset from the fire-4 and fire-5 T1 IRQs to each of the 16 &FE21 writes on credit rows 0 and 5, over all 16 pulse steps. Or compare screenshots of those two rows through one 32-field pulse cycle. Accept the shift only if KC accepts the new bar shape. Alternatively, keep today's timing exactly by keeping LO(ttl_pal) and the page of ttl_rt_not3/not4 where they are (fill the freed bytes ahead of ttl_pal with code that sits after ttl_rupt_timer today), and ASSERT it.

## Verdicts

- P1: ACCEPTED-AFTER-MEASUREMENT, 6 bytes. The logic is exact. ttl_bit is read and written only in ttl_init and ttl_cell. 0 -> $FF -> fetch -> 7, so the period is 8 and the first call still fetches. A/X/Y/flags are dead after it, and 19 -> 13 bytes is right. It moves ttl_raster, so the hazard above applies.
- P2: ACCEPTED-AFTER-MEASUREMENT, 5 bytes. The six ROLs rewrite bits 0-5. The top band's six LSRs read bits 0-5, and the bottom band's `<<2` then six ASLs read bits 5-0, so bits 6-7 are never seen. ttl_bits_t has no other reader, and A is dead. The raster hazard applies.
- P3: ACCEPTED-AFTER-MEASUREMENT, 7 bytes. ttl_bits_t is written only by ttl_cell's ROL, and neither zm_write_band nor the IRQ touches it between the two bands. ttl_bits_b has no other user. 8 + 1 - 2 = 7 is right. The raster hazard applies.
- P4: ACCEPTED-AFTER-MEASUREMENT, 7 bytes. ttl_cell's only caller is ttl_frame. ttl_frame's callers (`jsr` from ttl_frame_titles, and kr_field) enter at the same instruction. zm_write_band's only callers are ttl_frame's jsr and its tail jmp, and zm_shift is patched by label. Removing the jsr changes no state. The raster hazard applies.
- P5: ACCEPTED-AFTER-MEASUREMENT, 7 bytes (32 -> 25 is right).
  - LDY leaves C alone, X (the row counter) is untouched, and both loops exit with Y=$FF and N=1, so the BMI is always taken.
  - ttl_blank+15 and ttl_block+15 do not cross a page in either artwork, and no page assumption is made.
  - read_ptr has no reader that relies on the value zm_write_band left there: bank3:197/582, player:527, mega_plot's ptrs and zx0 all set it first.
  - It is never slower per byte or per row, so it cannot break the "top band done by row 5" deadline.
  - The raster hazard applies.
- P6: ACCEPTED-AFTER-MEASUREMENT, 3 bytes. kr_field has three callers, not two (kr_wait_up, kr_hold_msg and kr_run .wait), all `jsr` by label. ttl_next_glyph ends in RTS, so nothing falls into it. ttl_frame reads none of field_wait's A or flags. It adds 3 bytes in front of ttl_raster (the hazard above). Both sites are in the hole.
- P7: ACCEPTED, 13 bytes.
  - (a) The clear loop exits with A=0, and kr_copy writes only kr_cnt and kr_block+12..27, never kr_line ($0A73).
  - (b) Gives the same Y (kr_line*8), X (kr_rows+1, with no wrap since the maximum is 191), kr_dst and kr_cnt as before. kr_base has no other reader. C is dead before the next CMP. Nothing in src or lib reads V (no BVC/BVS; only a local PHP/PLP and RTI). 37 -> 27 bytes.
  - (c) kr_copy always exits through a not-taken BNE after DEC, so Z=1 and BEQ is always taken.
- P8: ACCEPTED, 10 bytes. kr_build's only caller is kr_show. The other entries are all by label: kr_paint (kr_blank's `jmp`, in the tail), kr_draw (kr_cred_back's `jmp`) and kr_bank (`jsr` from kr_run and kr_cred_back). kr_build's exit state goes into `lda #` and is dead. One less stack level during kr_build matters to nothing. Everything stays in the hole.
- P9: ACCEPTED, 5 bytes. PHA/PLA balance before `jsr bank_call`, so bank_call sees the same stack depth. PLA sets N/Z exactly as `lda bnk` did, and X/Y are untouched. bnk is local to the braces.
- P10: ACCEPTED, 4 bytes. kr_scan returns kr_i in 0..34 (KR_CANDS = 35 < 128, a fixed constant asserted in panel.asm) or $FF, so N=1 exactly when A=$FF.
  - C on the not-found path is 1 from kr_scan's CMP, and keydown's PLP keeps it.
  - On the found path, every later C reader in kr_run follows a CMP, CPX or CLC.
  - Z is redone by TAY.
- P11: ACCEPTED, 3 bytes. kr_hold_msg has exactly two callers, and both do `jsr kr_show` immediately before it, so the side effects happen in the same order.
- P12: ACCEPTED, 9 bytes.
  - (a) SWRAM_SPRITES1 = 6 = KR_LINES (TITLE_LINES + 1), both defined before the INCLUDE at main.asm:2250, and the IF guards any future change.
  - (b) kr_wait_up only leaves after keydown's `and #&80` (preceded by PLP) gives N=0, so A=0.
  - (c) The branch follows a not-taken BEQ, so Z=0. The distance is -88.
  - (d) kr_hold_msg exits on a not-taken BNE, so Z=1, with or without P11. The distance is -102.
  - (e) kr_cred_back's only reference is that JMP, and it stays in the hole ahead of `IF MUSIC_AKL = 0`.
- P13: ACCEPTED, 2 bytes.
  - The copy goes from the bank to $0835, with no overlap and no IRQ reader, and X <= 11 so BPL is valid.
  - bank_call passes C through (it ends `lda bank_restore / sta / sta / rts`). life_lost then does LDX/LDA/STA and finishes the anim_loop with `cpx #ENEMY_COUNT` before any C reader. X and A are reloaded.
- P14: ACCEPTED, 7 bytes. The C used by `sbc` is 1, from `bcs named`. LDX sets only N/Z ahead of CPY. X is untouched by TYA/SBC/ASL/TAY/LDA/STA. The flags at the letter path's RTS differ (N/Z now from TYA, not LDX), but kr_build's `.next: inc kr_line` overwrites them. kr_copy's other callers are `jsr` by label, and kr_blank ends in a JMP, so nothing falls into the moved code. Everything stays in the tail.
- P15: ACCEPTED, 1 byte. After `and #4` A is in {0,4}, so both ASLs shift out 0 and C=0. That does not depend on what &FE34 holds.
- P16: ACCEPTED, 2 bytes. The invariant is star_ofs = k + col*8 with k = 8 + row*640, and row is 1..19.
  - It is set only by star_init. star_frame is the only other writer (main.asm declares the arrays, and grep finds no other writer). Both of star_frame's steps preserve it, and star_init always runs, at master_loop, before any star_frame.
  - Wrap: ofs is at most 8 + 19*640 + 632 = $3200, so there is no carry and C=0. Even with k=0 (never-initialised RAM) it is still C=0.
  - back_one: ofs >= 656, so no borrow and C=1.
  - The ASSERT holds in every variant: the AKL builds have back_one/no_step at $B9A9/$B9C0, and even all 101 bytes of savings keep them on one page. The `bcs` falls through to to_left, which is between them.
  - Cycles are equal, 3 for 3.
- P17: ACCEPTED, 6 bytes. The arithmetic is the same. The C and A left behind are dead: `dec mega_n`, then `.cell` starts with LDA/CMP, and the other exit is LDA/CMP. fwd and back are new names inside mega_mess's braces.
- P18: ACCEPTED, 4 bytes. `beq out` lands on an RTS with the same registers and flags. The fall-through runs copy8 with the X, Y and pointers that `jsr copy8` gave it, and returns the same state, one stack level shallower. ptrs/copy8/pass are local to the braces and reached by `jsr`. The moved ptrs is entered only by `jsr`, sitting between two RTSs. The branch is about 17 bytes, well in range.

## Totals
- ACCEPTED: P7-P18, 13+10+5+4+3+9+2+7+1+2+6+4 = 66 bytes (46 in the hole, 20 in the tail).
- ACCEPTED-AFTER-MEASUREMENT: P1-P6, 6+5+7+7+7+3 = 35 bytes (hole), all for the ttl_raster/ttl_rupt_timer timing shift.
- REFUTED: none, 0 bytes.


---

# BANK1 shrink proposals (reviewer stage)

BANK1 has two regions that run out of room separately when MUSIC_AKL = 0:
- the **hole** below the tune at MUSIC_B1_BASE = &B900, which holds ttl_init through kr_run. It has 23 bytes free (&17) in non-CPC builds and 17 (&11) in CPC builds. This is from `BANK 1 HOLE BELOW THE TUNE` in build/EDGE.lst and build/EDGE-CPC.lst.
- the **tail** after music_b1, which holds kr_blank through mega_plot. It has 16 bytes free (&10) in every non-AKL build.

In AKL builds the two regions are one, with about 1.3K free. Each proposal says which region it saves in.

Every proposal is plain NMOS. None of them touches irq_handler, rupt_*, ttl_rupt_timer or ttl_raster.

**Report findings deliberately NOT proposed:** six imm_load findings at $B552, $B55C, $B592, $B597 and $B5E8 are in ttl_rupt_timer / ttl_rt_not*. That is interrupt code inside the CRTC macro and is off-limits. The finding at `zm_shift` (`bne zm_draw` always taken) is superseded by P5. The `tail_call` findings at `jsr mega_plot` and `jsr copy8` save 0 bytes, and copy8 is improved instead by P20.

## HAZARD that applies to P1-P6 (read before applying any of them)

P1-P6 shrink code that sits *before* `ttl_raster` and `ttl_rupt_timer`, so those routines move down in the bank. With P1-P6 all applied the shift is -29 bytes (6+5+7+7+7, minus the 3 bytes kr_field adds in front, which is P6).

- **ttl_raster's padded loops** (`ttl_r_pad`: dey/bne; `ttl_r_line`) must not straddle a page, or each iteration gains a cycle.
  - Today `ttl_r_line` is at $B526 (non-CPC) and $B52C (CPC), in every current listing (EDGE, -CPC, -NULA, -AKL*).
  - After -29 it is at $B509 / $B50F and the loops end around $B528 / $B52E. That is safe.
  - Suggested guard, added after `.ttl_r_out`: `ASSERT HI(ttl_r_line) = HI(ttl_r_out)`.
- **`lda ttl_pal, x` page crossing** (+1 cycle before the 1 MHz `sta VIDEO_ULA_PAL`):
  - Today ttl_pal is at $B4EA (non-CPC) or $B4F0 (CPC), and it crosses $B500 for the high X values. After the shift it does not cross, or crosses for X = 45 only.
  - The crossing pattern already differs between the shipped CPC and non-CPC builds, so the design evidently tolerates it.
  - Still: check the credit raster by eye in jsbeeb once.
- **ttl_rupt_timer's dispatch chain:** today `bne ttl_rt_not4` crosses $B600. After the shift it does not, so fire 5's path gets 1 cycle shorter.
  - That is far inside the IRQ-entry jitter (up to 7 cycles), so nothing new.
  - It is still a change to interrupt timing, so the skeptic should weigh it.

P7 onwards (kr_*, expl_dirs_load, and everything in the tail) sit after ttl_rupt_timer and move none of this.

---

## P1: ttl_cell - count ttl_bit down, so the glyph fetch is a dec/bpl
- src/bank1.asm:146-154 (ttl_cell), in the hole
- original
```
.ttl_cell
    lda ttl_bit
    bne ttl_c_shift
    jsr ttl_next_glyph
.ttl_c_shift
    inc ttl_bit
    lda ttl_bit
    and #7
    sta ttl_bit
```
- proposal (and `.ttl_bit`'s comment, line 79, becomes "cells left of the glyph in ttl_zbuf, minus one")
```
.ttl_cell
    dec ttl_bit                 ; 7 down to 0, then the next glyph
    bpl ttl_c_shift
    jsr ttl_next_glyph
    lda #7
    sta ttl_bit
.ttl_c_shift
```
- **Bytes saved:** 6 (19 -> 13).
- **Cycles:** about -14 on the 7-in-8 frames with no fetch (23 -> 9) and about -6 on the fetch frame. Nothing is added on any path.
- **Runs:** every field on the titles and on the redefine screen. Not raster code.
- **Argument:**
  - Nothing else reads ttl_bit (grep: bank1.asm lines 79, 94, 147-154 only).
  - Its only job is to make the fetch happen every eighth call, starting with the first after ttl_init. ttl_init stores 0 (`sta &b37f ;| A=$00`).
  - New schedule: 0 -> dec gives $FF -> fetch, then 7. The next seven calls see 6..0 and do not fetch, and the eighth sees $FF and fetches. That is period 8, fetching on the first call, exactly as before.
  - The glyph's columns are consumed by `asl ttl_zbuf+1,x`, which is independent of ttl_bit.
  - A, X and Y are dead at ttl_c_shift: `inc &b37f ;| ... in:YV`, and Y is never written on the new path. ttl_next_glyph itself still clobbers them as before.
- **Variants:** no IF blocks are involved.

## P2: ttl_cell - ttl_bits_t needs no clearing
- src/bank1.asm:156-158, in the hole
- original
```
    lda #0
    sta ttl_bits_t
    ldx #0
```
- proposal
```
    ldx #0                      ; ttl_bits_t needs no clear: six ROLs replace
                                ; bits 0-5, and nobody reads 6-7
```
- **Bytes saved:** 5. **Cycles:** -6 every field (titles). Not raster code.
- **Argument:**
  - The six `rol ttl_bits_t` replace bits 0-5 entirely, so bits 6-7 are left holding stale bits.
  - Readers of ttl_bits_t:
    - The top band copies it to zm_bits and does six `lsr zm_bits` (`ldx #&06` at zm_write_band, with zm_shift patched to LSR = &4E). That reads bits 0..5 only.
    - `ttl_bits_b = ttl_bits_t << 2` (`asl a : asl a`, or P3's equivalent) pushes bits 6-7 out to the carry. The bottom band's six ASLs then read bits 7..2 of bits_b, which are bits 5..0 of bits_t.
    - So bits 6-7 are never observed.
  - A is dead after the sta (`sta &b380 ;| ... in:AYV out:YV`). X is still loaded by `ldx #0`.
- If this is rejected, the report's own finding still applies: `ldx #0` -> `tax` for 1 byte (`ldx #&00 ;| A=$00`).
- **Variants:** none.

## P3: ttl_cell/ttl_frame - drop ttl_bits_b; shift ttl_bits_t where it is used
- src/bank1.asm:81 (`.ttl_bits_b EQUB 0`), 166-169 (end of ttl_cell), and 257 (ttl_frame). All in the hole.
- original (ttl_cell tail, and the start of the bottom band in ttl_frame)
```
    lda ttl_bits_t
    asl a
    asl a
    sta ttl_bits_b
    rts
```
```
    lda ttl_bits_b : sta zm_bits
```
- proposal: delete line 81 `.ttl_bits_b EQUB 0`, and also
```
    rts
```
```
    lda ttl_bits_t : asl a : asl a : sta zm_bits     ; rows 0 down, for ASL
```
- **Bytes saved:** 7. That is 8 bytes of code plus 1 byte of variable, less 2 bytes for the asl pair moved into ttl_frame.
- **Cycles:** -8 every field (12 + 8 replaced by 12).
- **Argument:**
  - ttl_bits_t is written only by the `rol` in ttl_cell (grep). zm_write_band shifts zm_bits, a different byte.
  - So ttl_bits_t is unchanged between the top band's read and the bottom band's: `lda &b380 ;| ...` at the top, with nothing writing $B380 in between.
  - ttl_bits_b has no other reader or writer (grep: bank1.asm lines 81, 169, 257).
- **Variants:** none.

## P4: ttl_frame - absorb ttl_cell, and fall into zm_write_band
- src/bank1.asm:146-285, in the hole. Layout only: no instruction changes apart from the ones removed.
- original
  - ttl_cell (146-170) ends `rts`.
  - zm_write_band (183-213) sits between ttl_cell and ttl_frame.
  - ttl_frame (228) starts `jsr ttl_cell`, and its last line (285) is `jmp zm_write_band`.
- proposal
  - Put the `.ttl_frame` label on ttl_cell's first instruction and delete ttl_cell's `rts` and ttl_frame's `jsr ttl_cell`. ttl_cell's body runs straight into the top band.
  - Move the zm_write_band block (its header comment and lines 183-213) to just after ttl_frame.
  - Delete `jmp zm_write_band             ; X = 1...` (line 285), so the bottom band falls into it.
  - The resulting order is: ttl_next_glyph, ttl_frame (with ttl_cell's body inside), zm_write_band, then ttl_frame_titles.
  - Keep the `.ttl_cell` label if you like, as a comment anchor; nothing jumps to it.
- **Bytes saved:** 7 (jsr 3 + rts 1 + jmp 3). **Cycles:** -15 every field.
- **Argument:**
  - ttl_cell's only caller is ttl_frame (grep: bank1.asm:229).
  - ttl_frame's callers (`jsr ttl_frame` in ttl_frame_titles, `jmp ttl_frame` in kr_field) still enter at the same first instruction.
  - zm_write_band's callers are the `jsr` at line 253 and the tail jump (grep), and its labels zm_row/zm_shift/zm_solid/zm_draw/zm_copy are referenced nowhere else.
  - zm_shift is self-modified by `sta zm_shift`, by label, so moving it is safe.
  - Register and flag state at every point is unchanged: the code between is the same code, minus calls.
- **Variants:** none. No data addresses are relied on.

## P5: zm_write_band - two absolute-indexed copy loops instead of building read_ptr
- src/bank1.asm:185-201, in the hole
- original
```
.zm_row
.zm_shift
    asl zm_bits                 ; SELF-MODIFIED: LSR for the top band
    bcs zm_solid
    lda #LO(ttl_blank) : sta read_ptr
    lda #HI(ttl_blank) : sta read_ptr+1
    bne zm_draw                 ; a bank address: the high byte is never 0
.zm_solid
    lda #LO(ttl_block) : sta read_ptr
    lda #HI(ttl_block) : sta read_ptr+1
.zm_draw
    ldy #TTL_CELL-1
.zm_copy
    lda (read_ptr), y
    sta (write_ptr), y
    dey
    bpl zm_copy
```
- proposal
```
.zm_row
.zm_shift
    asl zm_bits                 ; SELF-MODIFIED: LSR for the top band
    ldy #TTL_CELL-1             ; leaves C alone
    bcs zm_solid
.zm_blank
    lda ttl_blank, y
    sta (write_ptr), y
    dey
    bpl zm_blank
    bmi zm_drawn                ; always: Y = &FF
.zm_solid
    lda ttl_block, y
    sta (write_ptr), y
    dey
    bpl zm_solid
.zm_drawn
```
- **Bytes saved:** 7 (32 -> 25).
- **Cycles:** never more on any path; this runs every field.
  - Per byte, `lda abs,y` is 4 against `lda (zp),y` at 5. Both pay the same +1 when crossing a page, because the base address is the same. So each byte is 1 cycle cheaper. Even if a new `bpl` crosses a page (+1), it only ties the old best case.
  - Per row overhead: the blank path goes from 17 to 7 cycles and the solid path from 15 to 5 (plus 1 if a branch crosses a page, on both sides).
  - Net: about -26 cycles per row, so about -150 per band.
- **Argument:**
  - Y on exit is $FF on both paths, as before (`clc ;| ... Y=$FF`). X, A and the flags after the loop are untouched, since the code after `.zm_drawn` is unchanged.
  - read_ptr is no longer written. It is generic scratch, and every reader sets it first: player.asm:527, bank3.asm:197 and :582, zx0 via zxsrc, and mega_plot's ptrs.
  - `bmi` is taken because the loop exits with Y = $FF (N=1).
  - This removes the report's always-taken `bne zm_draw` too.
- **Variants:** ttl_block/ttl_blank are used by label, with no page assumption.
  - The old code needed nothing, and the obvious smaller rewrite would assume HI(ttl_block) = HI(ttl_blank). That assumption is unsafe because the CPC artwork moves the font, so this proposal avoids it.

## P6: kr_field - fall into ttl_frame
- src/bank1.asm:881-885 (kr_field), moved into the hole right before `.ttl_frame`
- original
```
.kr_field
{
    jsr field_wait
    jmp ttl_frame               ; its rts
}
```
- proposal: delete it there, and put this immediately before `.ttl_frame` (after ttl_next_glyph's `rts`)
```
.kr_field                       ; one field, with the page still running
    jsr field_wait              ; and falls into ttl_frame
```
- **Bytes saved:** 3. **Cycles:** -3 per redefine-screen field. One-off screen, not raster code.
- **Argument:**
  - Callers are `jsr kr_field` in kr_wait_up and kr_hold_msg, by label.
  - field_wait (main.asm:1189) returns with A = field_count and the flags from `cmp`. Those are the same values ttl_frame received before; ttl_frame needs none of them anyway, starting with `dec`/`lda` (P1) or `lda`.
  - ttl_next_glyph ends in `rts`, so nothing falls into kr_field.
- **Variants:** none. This adds 3 bytes in front of ttl_raster; see the HAZARD section.

## P7: kr_build - shorter line setup, and kr_line zeroed while A is 0
- src/bank1.asm:783-801 and 815, in the hole
- original
```
    lda #0
    sta kr_line                 ; and the five controls, on rows 1 to 5
    .line
    ldx kr_line
    lda kr_rows, x
    sta kr_base
    clc                         ; and where this line's VALUE goes, worked
    adc #KR_COL_KEY             ; out once: both arms below want it
    sta kr_dst

    lda kr_line                 ; the label: record kr_line of kr_text
    asl a : asl a : asl a
    tay
    lda kr_base
    clc
    adc #KR_COL_LBL
    tax
    lda #KR_REC : sta kr_cnt
    jsr kr_copy
```
  and line 815: `    jmp next`
- proposal
  - (a) Move `sta kr_line` up to just after the clear loop's `bne clr`:
```
    bne clr
    sta kr_line                 ; A = 0: the five controls, on rows 1 to 5
```
  - and delete the `lda #0 / sta kr_line` pair before `.line`.
  - (b) Replace the line setup:
```
    .line
    ldx kr_line
    txa                         ; the label: record kr_line of kr_text
    asl a : asl a : asl a
    tay
    lda kr_rows, x
    tax
    inx                         ; + KR_COL_LBL
ASSERT KR_COL_LBL = 1
    clc                         ; and where this line's VALUE goes, worked
    adc #KR_COL_KEY             ; out once: both arms below want it
    sta kr_dst
    lda #KR_REC : sta kr_cnt
    jsr kr_copy
```
  - (c) Line 815 becomes `    beq next                    ; kr_copy leaves Z set`.
- **Bytes saved:** (a) 2, (b) 10, (c) 1, for 13 in all. **Cycles:** fewer on every path. One-off.
- **Argument:**
  - (a)
    - At `ldy #&90` after the loop the state is `A=$00 X=$00 ... Z=1`.
    - kr_copy writes only kr_cnt and kr_block, and kr_line (&0A73) is outside kr_block (&0987 + 228).
    - The heading copy in between does not read kr_line.
  - (b)
    - `lda kr_line` is a reload of X: `lda &0a73 ;| A=? X=?≡kr_line`.
    - kr_base is written and read only here (grep: bank1.asm:788, 796; main.asm:2213 is its `skip`). Keeping kr_rows,x in A and moving it to X removes the variable traffic.
    - `lda kr_base : clc : adc #1 : tax` becomes `tax : inx`, which gives the same X. C after differs, but it is dead: `tax ;| ... in:AYV out:XYV`, and kr_copy does not use C.
    - V is never read anywhere in src or lib (grep for bvc/bvs finds no hits), so the V left by the dropped adc is irrelevant.
    - kr_dst is still written before both kr_copy and the arms that read it.
  - (c) `jmp &b7a9 ;| ... Z=1`. kr_copy exits through `dec kr_cnt : bne` with Z=1, and `next` is a few bytes forward.
- **Variants:** none (KR_* constants are fixed; the ASSERT pins the one assumption).

## P8: kr_show = kr_build falling into kr_paint -> kr_draw -> kr_bank
- src/bank1.asm:767-876, in the hole. This is a reorder.
- original: kr_build (ends `rts`), kr_bank, kr_paint (falls into kr_draw), kr_draw (`jmp kr_bank`), then
```
.kr_show
{
    jsr kr_build
    jmp kr_paint                ; its rts
}
```
- proposal: order the blocks as
  - `.kr_show` (a bare label) + `.kr_build { ... }` with its final `rts` deleted
  - kr_paint
  - kr_draw with `jmp kr_bank` deleted
  - kr_bank
- The kr_show block is deleted.
```
.kr_show                        ; compose the block and put it on the screen
.kr_build
{
    ...as before...
    cmp #TITLE_LINES
    bne line
}                               ; and falls into kr_paint
.kr_paint
...
.kr_draw
{
    ldx #LO(title_text)
    ldy #HI(title_text)
    lda #SWRAM_COMPILED
}                               ; and falls into kr_bank
.kr_bank
...
```
- **Bytes saved:** 10 (kr_show's jsr 3 + jmp 3, kr_build's rts 1, kr_draw's jmp 3). **Cycles:** -15 per kr_show and -3 per kr_draw. One-off.
- **Argument:**
  - kr_build is called only by kr_show (grep: 767, 874), so its exit state (`rts ;| A=$05 ... C=1 Z=1`) was always consumed by kr_paint. kr_paint starts with `lda #&87`, which needs none of it.
  - kr_bank's callers are by label: kr_run's and kr_cred_back's `jsr`.
  - kr_draw's callers are `jmp kr_draw` (kr_cred_back) and kr_paint's fall-through.
- This supersedes the report's `jmp kr_bank` -> `bne` finding (1 byte).
- **Variants:** none.

## P9: kr_bank - hold the bank on the stack, not in bnk
- src/bank1.asm:832-843, in the hole
- original
```
.kr_bank
{
    sta bnk
    lda #SWRAM_SPRITES0
    sta bank_restore
    lda bnk                     ; X and Y are untouched: bank_call wants them
    jsr bank_call
    lda #SWRAM_DATA             ; and the resting state back, for everyone else
    sta bank_restore
    rts
    .bnk EQUB 0
}
```
- proposal
```
.kr_bank
{
    pha
    lda #SWRAM_SPRITES0
    sta bank_restore
    pla                         ; X and Y are untouched: bank_call wants them
    jsr bank_call
    lda #SWRAM_DATA             ; and the resting state back, for everyone else
    sta bank_restore
    rts
}
```
- **Bytes saved:** 5 (sta abs 3 + lda abs 3 + the bnk byte 1, against pha 1 + pla 1). **Cycles:** -1 (7 against 8). One-off.
- **Argument:**
  - `pla` sets N and Z from A exactly as `lda bnk` did (`lda &b7c8 ;| ... out:AXYNZCV`).
  - The stack is balanced before `jsr bank_call`, so bank_call sees the same stack depth.
  - bnk has no other user, because it is local to the braces.
  - Not interrupt code.
- **Variants:** none.

## P10: kr_scan's &FF is negative - callers test N, not cmp #&ff
- src/bank1.asm:900-901 (kr_wait_up) and 1027-1028 (kr_run .wait), in the hole
- original
```
    cmp #&ff
    bne again
```
```
    cmp #&ff
    beq wait
```
- proposal
```
    bpl again                   ; kr_scan: N set = nothing down
```
```
    bmi wait                    ; kr_scan: N set = nothing down
```
- The kr_scan header comment gains: "N is set exactly when A = &FF".
- **Bytes saved:** 4. **Cycles:** -2 per kr_scan call. One-off screen.
- **Argument:**
  - kr_scan's two exits both end in a load:
    - `lda #&ff ; rts` gives N=1 (`rts ;| A=$FF ... N=1`).
    - `lda kr_i ; rts` gives kr_i in 0..34, so N=0. kr_i is only ever 0..KR_CANDS-1: it starts at 0 and exits at `cmp #&23`.
  - The C left by `cmp #&ff` was 1 in the not-found case and 0 in the found case.
    - kr_wait_up's exit: kr_scan's not-found path already has C=1 from `cmp #KR_CANDS` (equal), and keydown preserves C (php/plp, and/no-C). So C=1 at kr_wait_up's rts is unchanged (`rts ;| ... C=1`).
    - The found path in .wait: the next C readers are all preceded by a C-setting cmp/cpx/clc (`tay ;| ... in:A out:Y`, so C is dead there).
- **Variants:** none.

## P11: kr_hold_msg does the kr_show its callers always do first
- src/bank1.asm:939-941, 1071-1072 and 1090-1091, in the hole
- original
```
.kr_hold_msg
{
    jsr kr_wait_up
```
```
    jsr kr_show
    jsr kr_hold_msg
```
  (twice: in `.used` and in `.done`)
- proposal
```
.kr_hold_msg                    ; paint, then hold
{
    jsr kr_show
    jsr kr_wait_up
```
  and at both call sites just `    jsr kr_hold_msg`.
- **Bytes saved:** 3. **Cycles:** 0 (the same two jsr, the same order). One-off.
- **Argument:** kr_hold_msg has exactly these two callers (grep: 1072, 1091), and both call kr_show immediately before it with nothing in between. The order of side effects is identical.
- **Variants:** none.

## P12: kr_run - small things the annotations decide
- src/bank1.asm:1004-1009, 1014-1015, 1066, 1073 and 1092, plus kr_cred_back (955-971). In the hole.
- (a) imm_load (report): `lda #SWRAM_SPRITES1` after `lda #KR_LINES : sta ttl_lines`.
  - original
```
    lda #KR_LINES
    sta ttl_lines
    lda #SWRAM_SPRITES1
```
  - proposal
```
    lda #KR_LINES
    sta ttl_lines
IF SWRAM_SPRITES1 <> KR_LINES   ; both are 6 today
    lda #SWRAM_SPRITES1
ENDIF
```
  - 2 bytes. Evidence: `lda #&06 ;| A=$06`, with KR_LINES = TITLE_LINES+1 = 6 and SWRAM_SPRITES1 = 6 (main.asm:291, 547). The IF keeps it right if either constant ever changes.
- (b) `lda #0` before `sta kr_cur`: A is already 0.
  - original
```
    jsr kr_wait_up

    lda #0
    sta kr_cur
```
  - proposal
```
    jsr kr_wait_up              ; returns A = 0: keydown's AND #&80, key up
    sta kr_cur
```
  - 2 bytes. Evidence: `lda #&00 ;| A=$00 X=$7F Y=$0B C=1`. kr_wait_up only leaves through `bmi again` not taken after `jsr keydown`, whose result is `and #&80` (keyboard.asm), so the result is 0.
- (c) take: `jmp ask` -> `bne ask` (report).
  - 1 byte. Evidence: `jmp &b86a ;| ... Z=0` (it follows `beq done`). The distance is -88 today and only shrinks.
- (d) used: `jmp ask` -> `beq ask`.
  - 1 byte. Evidence: `jmp &b86a ;| A=0..223 X=$00 Y=$FF C=? Z=1`. kr_hold_msg always leaves through `dec kr_hold : bne loop` falling through, so Z=1. The distance is -102 today and only shrinks.
- (e) kr_cred_back after kr_run: move the whole kr_cred_back block (955-971) to just after kr_run's closing `}` and before `IF MUSIC_AKL = 0`. Then delete `jmp kr_cred_back            ; its rts` (1092) so `.done` falls into it.
  - 3 bytes, -3 cycles. kr_cred_back's only caller is that jmp (grep).
- **Total:** 9 bytes, one-off screen, no cycles added.
- **Variants:** none. kr_cred_back stays inside the hole, ahead of the MUSIC_AKL block.

## P13: expl_dirs_load - count down
- src/bank1.asm:564-574, in the hole
- original
```
.expl_dirs_load
{
    ldx #0
    .loop
    lda explosion_dirs, x
    sta enemy_spds+2*ENEMY_FIRST, x
    inx
    cpx #2*ENEMY_COUNT
    bne loop
    rts
}
```
- proposal
```
.expl_dirs_load
{
    ldx #2*ENEMY_COUNT-1
    .loop
    lda explosion_dirs, x
    sta enemy_spds+2*ENEMY_FIRST, x
    dex
    bpl loop
    rts
}
```
- **Bytes saved:** 2. **Cycles:** -2 per byte copied. One-off, on a life lost.
- **Argument:**
  - The copy is from the bank to main RAM, with no overlap, so the order does not matter. 2*ENEMY_COUNT = 12 (`cpx #&0c`), so X stays below 128 and bpl is a valid test.
  - The exit state changes (X=$FF instead of $0C, A = the first byte, C unchanged rather than 1), but the only caller doesn't use it:
    - player.asm:227 does `jsr bank_call`, which clobbers A/N/Z itself.
    - It then does `ldx #0`, `lda #0`, and `cpx` before any read of C.
- **Variants:** none.

## P14: kr_showkey - sec is known, kr_dst loaded once, fall into kr_copy
- src/bank1.asm:1147-1192, in the TAIL
- original
```
.kr_copy
{
    .loop
    lda kr_text, y
    sta kr_block, x
    iny
    inx
    dec kr_cnt
    bne loop
    rts
}
```
```
    .got
    cpy #KR_LETTERS
    bcs named
    iny
    tya
    ldx kr_dst
    sta kr_block, x
    rts
    .named
    tya
    sec
    sbc #KR_LETTERS - KR_LABELS
    asl a : asl a : asl a       ; * KR_REC
    tay
    ldx kr_dst
    lda #KR_REC : sta kr_cnt
    jmp kr_copy                 ; its rts
}
```
- proposal: move the kr_copy block to just after kr_showkey's closing `}`, and
```
    .got
    ldx kr_dst                  ; both arms write at kr_dst
    cpy #KR_LETTERS
    bcs named
    iny
    tya
    sta kr_block, x
    rts
    .named
    tya
    sbc #KR_LETTERS - KR_LABELS ; carry is set: bcs
    asl a : asl a : asl a       ; * KR_REC
    tay
    lda #KR_REC : sta kr_cnt
}                               ; and falls into kr_copy
```
- **Bytes saved:** 7 (sec 1, the second `ldx kr_dst` 3, `jmp kr_copy` 3). **Cycles:** -2 and -3 on the named path, and 0 on the letter path. One-off.
- **Argument:**
  - `sec ;| ... C=1`: the report's clc_sec, confirmed. It is reached only by `bcs named`.
  - `ldx` sets N and Z but not C, and `cpy` follows it, so the branch is unchanged.
  - Both arms already did `ldx kr_dst` before using X. tya/sbc/asl/tay do not touch X.
  - kr_copy's other callers use `jsr kr_copy` by label (kr_build ×3), so moving it is safe.
  - This supersedes the report's `jmp loop` -> `bne` (1 byte).
- **Variants:** none. Both routines stay in the tail.

## P15: star_frame - the clc after asl/asl is known
- src/bank1.asm:1314, in the TAIL
- original
```
    asl a                       ; 0 for main, STAR_BANK for shadow
    clc
    adc #STAR_COUNT-1
```
- proposal
```
    asl a                       ; 0 for main, STAR_BANK for shadow; C = 0
    adc #STAR_COUNT-1
```
- **Bytes saved:** 1. **Cycles:** -2 every game frame.
- **Argument:**
  - `clc ;| A={0,$10} X=? Y=? C=0 Z=? N=0`.
  - `and #4` leaves A in {0,4}, so neither ASL shifts a 1 into C.
  - Holds whatever &FE34 reads.
- **Variants:** none.

## P16: star_frame - the two `jmp no_step` are branches whose carry is fixed
- src/bank1.asm:1356 and 1366, in the TAIL
- original
```
    adc #HI(PLAY_COLS * 8 - 8)
    sta star_ofs_hi, x
    jmp no_step
```
```
    sbc #0
    sta star_ofs_hi, x
    jmp no_step
```
- proposal
```
    adc #HI(PLAY_COLS * 8 - 8)
    sta star_ofs_hi, x
    bcc no_step                 ; always: an offset is below &3201
```
```
    sbc #0
    sta star_ofs_hi, x
    bcs no_step                 ; always: an offset is at least 648
```
  plus, after `.no_step`:
```
    ASSERT HI(back_one) = HI(no_step)   ; both branches stay inside a page
```
- **Bytes saved:** 2.
- **Cycles:** 0, because a taken branch costs 3 like jmp. The ASSERT forbids the +1 a page crossing would add. Runs every game frame.
- **Confidence:** medium. The annotations show `C=?` at both points (the analysis does not track star_ofs), so this rests on the code's own invariant, not on a `;|` fact:
  - For every star, `star_ofs = 8 + STAR_ROW*640 + star_col*8`, with STAR_ROW in 1..19 and star_col in 0..79.
  - star_init sets it from the tables, which are written exactly that way (lines 603-617).
  - The left step does col-1 / ofs-8, or at col -1 sets col=79 / ofs+632.
  - Nothing else writes either value (grep star_ofs_lo/hi, star_col: star_init and star_frame only).
- Hence:
  - On the wrap, ofs is at most 8 + 19*640 + 632 = 12800 = &3200, so the 16-bit add does not carry out: C=0.
  - On back_one, the column before the decrement was at least 1, so ofs is at least 656 and ofs-8 is at least 648. The high byte is at least 2, so there is no borrow: C=1.
- **Page check today:**
  - Non-AKL builds: no_step=$BED0 and back_one=$BEB9.
  - AKL builds: no_step=$B9C0 / $B9C6 and back_one=$B9A9 / $B9AF.
  - All are on the same page as the branches. With P14+P15 everything shifts by the same -8 bytes, so they stay together.
- **Variants:** none, and the star tables are the same in every variant.

## P17: mega_mess - inc/dec the high bytes instead of adc/sbc #0
- src/bank1.asm:1488-1493, in the TAIL
- original
```
    clc                         ; block 1 forwards, block 2 backwards
    lda mega_o   : adc #TTL_CELL : sta mega_o
    lda mega_o+1 : adc #0        : sta mega_o+1
    sec
    lda mega_o+2 : sbc #TTL_CELL : sta mega_o+2
    lda mega_o+3 : sbc #0        : sta mega_o+3
```
- proposal
```
    clc                         ; block 1 forwards, block 2 backwards
    lda mega_o   : adc #TTL_CELL : sta mega_o
    bcc fwd
    inc mega_o+1
    .fwd
    sec
    lda mega_o+2 : sbc #TTL_CELL : sta mega_o+2
    bcs back
    dec mega_o+3
    .back
```
- **Bytes saved:** 6.
- **Cycles:** fewer on every path: 15 or 20 against 22, and the same again for the other block.
- **Runs:** once a field during the completion message. That is not every game frame, and not interrupt code.
- **Argument:**
  - Same arithmetic.
  - The next instruction is `dec mega_n`, and C is set by `cmp` before anything reads it (`cmp #&1e`).
  - The A left behind differs, but it is dead: `dec &0973 ;| ... in:XYV`.
  - fwd/back are new local names inside mega_mess's braces. That scope already has group/cell/same, so there is no clash.
- **Variants:** none.

## P18: mega_plot - copy8 is the fall-through, and `out` is copy8's rts
- src/bank1.asm:1528-1584, in the TAIL. This is a reorder.
- original
```
    .pass
    sta &fe34
    ldx #0
    jsr ptrs
    lda mega_guard
    beq columns
    ldy mega_key
    lda (write_ptr), y
    cmp mega_block, y
    beq out                     ; a letter is there already: leave it alone
    .columns
    jsr copy8
    ldx #8
    jsr ptrs
    jsr copy8
    .out
    rts
```
  then .ptrs ... rts, then .copy8 ... rts.
- proposal: move the `.ptrs` block (1546-1575, with its comment) up to between mega_plot's top-level `rts` and `.pass`, and end .pass like this:
```
    .columns
    jsr copy8
    ldx #8
    jsr ptrs
                                ; and falls into copy8 for the second column
    .copy8
    ldy #7
    .cl
    lda (read_ptr), y
    sta (write_ptr), y
    dey
    bpl cl
    .out
    rts
```
  (The `jsr copy8 / .out rts` pair after the second `jsr ptrs` is deleted. `beq out` now reaches copy8's rts.)
- **Bytes saved:** 4 (jsr 3 + rts 1). **Cycles:** -12 per pass. Completion message only.
- **Argument:**
  - Branching to a different rts leaves the registers and flags exactly as the old `out: rts` did.
  - The final fall-through reaches the same copy8 body with the same X, Y and pointers that `jsr copy8` gave it.
  - copy8 and ptrs are local to mega_plot's braces, and their other uses are `jsr` by label.
  - `beq out` is a short forward branch (about 15 bytes).
- **Variants:** mega_block/mega_key are used by label only (the CPC mega data is the same size: mega_plot sits at $BF7B in both).

---

## Summary by region
- **Hole** (P1-P13): 6+5+7+7+7+3+13+10+5+4+3+9+2 = **81 bytes**. P1-P6 (35 of them) carry the ttl_raster / ttl_rupt_timer shift hazard above. P7-P13 (46) do not.
- **Tail** (P14-P18): 7+1+2+6+4 = **20 bytes**.
- **Total:** 101 bytes.
- Every proposal is independent of the others except where its text says so: P3 and P4 both touch ttl_frame, P5 and P4 both touch zm_write_band, and P12(e) relies on P11 for `.done`'s shape but works either way.
