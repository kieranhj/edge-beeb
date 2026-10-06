# Static analysis of the shipping code (2026-10-06)

**Edge Grinder's linked 6502 has about 105 bytes that static analysis says could go at no cycle
cost.** 50 of them are in the main code image, which has 447 bytes free anyway. 56 are spread
across the sideways banks and HAZEL, which are nearly full: BANK0 has 29 bytes free, BANK1 and
BANK2 16 each, BANK3 none, and HAZEL 38. So the banks are where these bytes would matter. These
are leads, not edits. Edge has shipped, so claim them only when something needs the room. Each
one is checked against the source, and the shipping variants are rebuilt and checked, before it
lands.

The analyses are Eben Upton's (`tools/dataflow` in
[beebgame](https://github.com/ebenupton/beebgame), MIT). They were written for his engine and used
on Commando to take out about 400 bytes behind a replay gate. They run here unmodified, through
beeb-port-kit's vendored and hash-checked copy, and nothing of them is copied into this repo.
`tools/beebasm_dataflow.py` is the same file Paradroid has.

## Running it

```powershell
.\build.ps1                          # a fresh build/EDGE.lst (the default variant)
python tools/beebasm_dataflow.py     # report, ~2 s -> build/dataflow/
```

It needs Python 3 and beeb-port-kit at `../beeb-port-kit`, or wherever `$BEEB_PORT_KIT` points.
It reads the listing only and never reassembles. `build/` is gitignored, so everything it writes
is too.

| Output | What it is |
| --- | --- |
| `build/dataflow/report.md` | Findings ranked by bytes: address, routine, instruction, why, and the evidence (registers live after it, values known before it) |
| `build/dataflow/report.json` | The same, plus per-line liveness and known values for every instruction |
| `build/dataflow/abi.md` | Every routine reached by `JSR`: registers and flags read on entry, what it defines, what callers read after the return, and register values known at the call sites |
| `build/dataflow/annotated/src/listing.s.txt` | The whole program, every instruction prefixed with live-in, live-out and known values |
| `build/dataflow-in/src/listing.s` | The listing-shaped file the findings point into |

`tools/dataflow_config.py` names the listing (`build/EDGE.lst`), the source folders (`src`,
`lib`) and the interrupt. That's `irq_handler`, the only thing ever stored in `IRQ1V`; it
reaches `rupt_vsync`, `rupt_timer` and the VGI player in HAZEL. **To analyse another variant**
(`-Akl`, `-Cpc`, `-Nula`), build it and point `LISTING` at its `.lst`. The AKL build swaps the
whole music subsystem, so its HAZEL findings differ.

### What a beebasm build can't tell it

The kit's own converter works from Baron builds; this is the beebasm equivalent, and the tool's
header gives the details. Four limits matter when reading the results:

- **No source lines.** beebasm's `-v` listing prints resolved operands (`LDX &086A`), so a
  finding gives an **address and the nearest label**. Search `src/` and `lib/` by that label,
  or open `build/EDGE.lst` at the address.
- **"Address taken" is guessed from the sources.** Any label named other than as a
  `JSR`/`JMP`/branch target counts as possibly reached through a table (338 of 815). That errs
  on the safe side: it hides some findings rather than inventing any.
- **This beebasm shortens long data** (`00 00 00 ... INCBIN`). Each such line is taken to run to
  the next listed address and left as zeros. The report decodes instruction bytes only, so
  nothing reads them.
- **Sections come from the listing's `Saving file` lines and address jumps.** The 10 found
  match the files: code `&0E00-&2241`, `!BOOT`, the two loading screens, `PANEL`, `ANDY`,
  `BANK0`-`BANK3` at `&8000`, and HAZEL `&C000-&D4DA`.

### The range analysis: it finishes on Edge

```powershell
python tools/beebasm_dataflow.py annotate   # ~1 min -> build/annotated/src/listing.s, summary.md
python tools/beebasm_dataflow.py patterns   # ~1 min, printed
```

**Measured 2026-10-06: it converged.** All 4,051 instructions were reached, in 314,279 steps
against the 3,000,000 budget, in 56 s, with no NOT-sound warning. Edge is the first full game it
has finished on: puzzle-beeble (9,380 instructions) ran out of steps
([beebgame#2](https://github.com/ebenupton/beebgame/issues/2)), and Paradroid is larger still.

`build/annotated/src/listing.s` is the whole program with the state before every instruction:
each register's range or value, which register equals which memory byte, the flags, the
operand's range, branches marked never or always taken, and liveness. It's what a reviewer
reads when hunting for smaller code by hand. beebgame's README, "The annotations" and "a
suggested farm", explains the notation and the method; it's in
`../beeb-port-kit/template/tools/dataflow/README.md`. `summary.md` lists what the ranges assume.
Read it before believing a `never`:

- **One instruction is self-modified but analysed as written:** an `asl` on a byte at `&B382`
  in bank code.
- **Three exits are unresolved** and the analysis stops there: `bank_call_t`'s patched
  `jmp &FFFF`, and the `jmp (&26)` dispatches in `spr_rest_row_split` and
  `spr_draw_row_split`.
- **39 stores through pointers it could not bound** are assumed not to hit a tracked variable.
  Most are sprite and screen writes.

`patterns` found two things, and neither is a saving to take:

| Find | What it is |
| --- | --- |
| `main.asm:1043` `lda char_col : and #SPR_PHASE_MASK : sta spr_phase`: A is always 0 | `SPR_PHASE_MASK = 0` is a setting, so `spr_phase` is always 0 in this build. Leave it, or make the knob conditional |
| `and #&7f` in the VGI player (HAZEL): A is already 0-127 | Library code in the interrupt: leave it |

## What it found

4,051 instructions in the default build, 83 findings, **up to 106 bytes**. The total is an
upper bound, because findings overlap.

| Where | Range | Free now | Findings | Bytes |
| --- | --- | ---: | ---: | ---: |
| Main code | `&0E00-&2241` | 447 | 39 | 50 |
| BANK1 | `&8000-&BFF0` | 16 | 14 | 17 |
| BANK0 | `&8000-&BFE3` | 29 | 9 | 13 |
| HAZEL (the VGI player) | `&C000-&D4DA` | 38 | 8 | 10 |
| BANK3 | `&8000-&9103` (code; music regions above) | 0 | 6 | 10 |
| BANK2 | `&8000-&BFF0` | 16 | 7 | 6 |

| Category | Count | Bytes | What it is |
| --- | ---: | ---: | --- |
| `imm_load` | 24 | 48 | `LDr #v` when the register already holds `v` |
| `jmp_to_branch` | 17 | 17 | A `JMP` where a flag is known, which can be a branch |
| `reg_xfer` | 14 | 14 | `LDA m` when X or Y already holds it (`TXA`/`TYA`), and the reverse |
| `dead_insn` | 4 | 9 | An instruction whose every result is unused |
| `branch_over_jmp` | 3 | 9 | `Bxx skip : JMP T`, which can be the inverted branch to `T` |
| `clc_sec` | 7 | 7 | `CLC`/`SEC` when the carry is already known |
| `tail_call` | 6 | 2 | `JSR x : RTS` that can be `JMP x`. Only 2 save a byte |
| `branch_always` | 8 | 0 | Information only: mostly deliberate always-taken branches |

### Checked by hand

| Finding | Verdict |
| --- | --- |
| `enemy.asm` `enemy_init`: `lda #0` before `.loop` | **Correct, 2 bytes.** The loop's first instruction is `lda #SPR_DP_BLANK`, so the value is never used |
| `bank0.asm` `finale_tick`: `ldx finale_slot` | **Correct, 3 bytes, in BANK0.** X is reloaded with `comp_flag` four instructions later, and nothing reads it in between (the next lines use A and Y) |
| `lib/vgiplayer.asm`: `lda #0 : rts` (`dec_no_borrow`) and `lda #&ff : rts` (`finished_exit`) | **Correct for Edge's callers, but leave them.** `vgm_update` returns "still playing" or "finished" in A, and Edge never reads it. It's the player's documented API, shared with `vgcplayer.asm`, and it runs in the interrupt |
| `rupture.asm` `install_irq`: the second `lda #&7F` | **Correct, 2 bytes, boot-time only.** The same pattern the kit's template and Paradroid have: `lda #&7F : sta` one VIA's IER, then again for the other |

None of the four is a bug.

## The review of BANK0 and BANK1 (2026-10-06)

**A review of the annotated code found 129 bytes in the two tightest banks, more than four
times what the quick report lists for them (30).** It's the method beebgame's README describes
for Commando. A reviewer agent read each bank's annotations and source and proposed rewrites.
A separate skeptic agent was told to refute any proposal with a reachable path that changes
behaviour, in any variant, and to default to refuting when unsure. I then audited six of the
accepted ones by hand and agreed with all six. **Nothing has been applied.** Each proposal
still goes through the gate below.

| Bank | Free now | Accepted | Accepted after measurement | Refuted | Detail |
| --- | ---: | --- | --- | --- | --- |
| BANK0 | 29 | 17 proposals, **28 bytes** in the release build (34 in DEV, where `DEBUG_TIMING` adds three in `timing.asm`) | none | none | `docs/dataflow-review-bank0.md` |
| BANK1 below the tune (`&B900`) | 23 (17 CPC) | P7-P13, **46 bytes** | P1-P6, **35 bytes** | none | `docs/dataflow-review-bank1.md` |
| BANK1 after the tune | 16 | P14-P18, **20 bytes** | none | none | the same |

**BANK1's P1-P6 change the credits raster's timing.** The code they rewrite is exactly
equivalent, but it sits ahead of `ttl_raster` and `ttl_rupt_timer`, which then move down by up
to 29 bytes. The skeptic found that the source comment saying the `&FE21` writes realign the
loop to the 1 MHz bus is wrong: in jsbeeb, as on the real Video ULA, `&FE20-&FE3F` is a 2 MHz
access. So the palette writes on later scanlines of a credit row would land up to 16 cycles
earlier, because today's `ttl_pal` loads cross a page and the moved ones don't. NuLA builds are
unaffected. Each subset of P1-P6 moves the code by a different amount.

So either measure the exact set that ships (the fire-4 and fire-5 interrupts to each of the 16
`&FE21` writes on credit rows 0 and 5, over all 16 pulse steps, default and `-Cpc` builds) and
have KC accept how the bars look, or keep today's layout by filling the freed bytes ahead of
`ttl_pal` with code that sits after `ttl_rupt_timer` now, plus an `ASSERT` that holds it there.

**The comment itself is a finding.** `bank1.asm`'s claim that the `&FE21` writes are on the
1 MHz bus is worth correcting whether or not any bytes are ever claimed.

Corrections the skeptic made to the reviewer, recorded in the review files: `kr_field` has three
callers, not two; `bank_call` passes the carry through (harmless where it matters); P16's
star-offset invariant is verified from `star_init` and `star_frame`, the only writers.

## Claiming the bytes

### First, the rules

1. **Never touch interrupt or raster code for bytes.** That's `irq_handler`, `rupt_vsync`,
   `rupt_timer`, `game_rupture`, the VGI player and everything they call. Most rewrites here
   change cycle counts on some path, and those cycles are where the CRTC writes land. The
   `game_rupture` `imm_load` and the HAZEL findings stay as they are.
2. **Build every variant that ships.** A finding comes from the default build, but most code is
   shared with `-Akl`, `-Cpc`, `-Nula` and `-Release`, where conditional assembly can make the
   same instruction necessary. Each change must build, and still assert its memory ceilings, in
   all of them. Then rerun the tool on at least one other variant's listing.
3. **One routine, or one category in one bank, per batch.** Findings overlap, so rebuild and
   rerun the analysis after every batch.
4. **Read every finding against the source before editing.** Discard it if:
   - it rests on a **constant** whose value is a coincidence (an `imm_load` where the value comes
     from an equate), unless you add an `ASSERT` that makes it a rule;
   - it relies on a **register contract a comment documents**, where it holds only for today's
     callers. Update the comment as part of the change;
   - it is in a **delay loop or a timed write sequence**;
   - it rewrites code transliterated from the C64 or CPC original where keeping the original's
     shape is the point, unless the bytes are actually needed.
5. **Every edit is a decision.** Record it in `docs/decisions.md` with its byte count.

### The gate, for every batch

Edge has no buffer oracle; the kit's `PORTING.md` §6 records that it was promised and never
built. So the gate is narrower than Paradroid's, and play matters more:

1. **Compare per file:** extract each catalogue file from the old and new SSD and compare. Only
   the files holding the changed code may differ. That's the method in `CLAUDE.md` and
   `docs/layer-0-toolchain.md`.
2. **Compare instruction streams:** reduce both listings to one entry per emitted instruction and
   diff them (Paradroid's `tools/listing_stream.py` reads beebasm listings). Only the intended
   instructions may change.
3. **Check frame timing** (`beeb-frame-drops`, and the frame meters `CLAUDE.md` describes) for
   anything in the main loop.
4. **Check the music** (`tools/verify_vgi.py`) for anything HAZEL or the tune's data placement
   touches, and `tools/verify_compiled.py` for anything near the compiled bullet.
5. **Play it:** every level, a death, the finale, the titles with their crossfade, CTRL+R key
   redefinition, auto-fire on and off, and pause, on the default and `-Release` builds. Then
   say in the commit how many bytes were freed and in which region, with the build's `FREE`
   figure before and after.

### Where to start, if the room is needed

| Order | Batch | Bytes | Why |
| ---: | --- | ---: | --- |
| 1 | Whichever of BANK1 and BANK0 is short: the review's accepted proposals (BANK0 28 bytes; BANK1 46 below the tune, 20 after it), which include and supersede the quick report's 30 | up to 94 | The banks have 0-29 bytes free, so a byte there is worth far more than one in main code. BANK1's P1-P6 (35 more) only after the raster measurement above |
| 2 | BANK3 and BANK2 `imm_load` and `reg_xfer` | up to 14 | BANK3 has nothing free |
| 3 | Main code `imm_load` | 22 | Only if main code ever runs short (447 free today). Leave out `game_rupture`, and `install_irq` unless boot-time bytes are wanted |
| 4 | Main code: the rest (dead instructions, branch rewrites, `reg_xfer`, `clc_sec`, `tail_call`) | 28 | `enemy_init` is checked above. Each branch rewrite changes a path's cycles, so the frame check matters |

The HAZEL findings (10 bytes) are left out on purpose: they're in the interrupt-driven player
and its library API.

## Appendix: every finding with a byte to save

Generated 2026-10-06 from the default build of `0000aec`. Addresses move with every build, so
rerun the tool rather than trusting these. "Routine" is the nearest label above the instruction,
often a local one.

| Region | Address | Routine | Instruction | Category | Bytes | Why |
| --- | --- | --- | --- | --- | ---: | --- |
| Main code | `$1881` | `shield_xb` | `beq no_coll` | branch_over_jmp | 3 | beq no_coll / jmp life_lost -> bne to the jmp's target (+49 from here; the targe |
| Main code | `$1BE9` | `assign` | `bne assign_2` | branch_over_jmp | 3 | bne assign_2 / jmp wm_comp -> beq to the jmp's target (+76 from here; the target |
| Main code | `$1C42` | `fail` | `bne fail_2` | branch_over_jmp | 3 | bne fail_2 / jmp wm_comp -> beq to the jmp's target (-13 from here; the target i |
| Main code | `$1777` | `spr_draw_row1` | `ldy #$00` | imm_load | 2 | Y is already $00 |
| Main code | `$1819` | `clear_pos` | `lda #$00` | imm_load | 2 | A is already $00 |
| Main code | `$190F` | `player_dropin` | `lda #$00` | imm_load | 2 | A is already $00 |
| Main code | `$19BF` | `player_s_colls` | `ldy #$00` | imm_load | 2 | Y is already $00 |
| Main code | `$1B9D` | `sprite_reset` | `lda #$12` | imm_load | 2 | A is already $12 |
| Main code | `$1BB7` | `wave_read_rst` | `lda #$00` | imm_load | 2 | A is already $00 |
| Main code | `$1BD1` | `new_enemy` | `ldx #$00` | imm_load | 2 | X is already $00 |
| Main code | `$1D14` | `loop` | `lda #$00` | imm_load | 2 | A is already $00 |
| Main code | `$1D93` | `enemy_init` | `lda #$00` | dead_insn | 2 | its results (ANZ) are all dead |
| Main code | `$1DB3` | `loop` | `lda #$00` | imm_load | 2 | A is already $00 |
| Main code | `$1EE1` | `game_rupture` | `lda #$04` | imm_load | 2 | A is already $04 |
| Main code | `$1F52` | `install_irq` | `lda #$7F` | imm_load | 2 | A is already $7F |
| Main code | `$0E20` | `y_count` | `lda #$00` | reg_xfer | 1 | X already holds this value: txa |
| Main code | `$1079` | `scroll_frame` | `jsr copy_column_buffer` | tail_call | 1 | jsr/rts -> jmp |
| Main code | `$111A` | `map_read_rst` | `jmp tile_update` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+1, same page) |
| Main code | `$123E` | `coll_init` | `ldx #$00` | reg_xfer | 1 | A already holds this value: tax |
| Main code | `$124C` | `page_loop` | `jmp coll_advance` | jmp_to_branch | 1 | Z is 1 here: beq reaches the target (-43, same page) |
| Main code | `$153D` | `last_ok` | `clc` | clc_sec | 1 | C is already 0 |
| Main code | `$1546` | `last_ok` | `sec` | clc_sec | 1 | C is already 1 |
| Main code | `$154E` | `above` | `clc` | clc_sec | 1 | C is already 0 |
| Main code | `$1556` | `above` | `clc` | clc_sec | 1 | C is already 0 |
| Main code | `$1989` | `fire_bullet` | `lda #$00` | reg_xfer | 1 | Y already holds this value: tya |
| Main code | `$1B14` | `bump_score_1` | `jmp loop` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+13, same page) |
| Main code | `$1B19` | `bump_score_10` | `jmp loop` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+8, same page) |
| Main code | `$1B1E` | `bump_score_100` | `jmp loop` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+3, same page) |
| Main code | `$1B30` | `loop` | `jmp bs_out` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+11, same page) |
| Main code | `$1C6B` | `move_loop` | `jmp apply` | jmp_to_branch | 1 | C is 1 here: bcs reaches the target (+4, same page) |
| Main code | `$2099` | `load_bank` | `jmp unpack_to` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (-45, same page) |
| Main code | `$21A4` | `zn_2` | `lda #$00` | reg_xfer | 1 | Y already holds this value: tya |
| BANK0 | `$BEC5` | `finale_tick` | `ldx $086A` | dead_insn | 3 | its results (XNZ) are all dead |
| BANK0 | `$BD8E` | `pal_loop` | `lda #$00` | imm_load | 2 | A is already $00 |
| BANK0 | `$BEEF` | `finale_tick` | `lda #$00` | imm_load | 2 | A is already $00 |
| BANK0 | `$BD5B` | `setup_display` | `ldx #$00` | reg_xfer | 1 | A already holds this value: tax |
| BANK0 | `$BDA1` | `clear_play` | `ldx #$40` | reg_xfer | 1 | A already holds this value: tax |
| BANK0 | `$BDF5` | `game_init` | `lda #$00` | reg_xfer | 1 | X already holds this value: txa |
| BANK0 | `$BDFF` | `col_loop` | `ldx #$00` | reg_xfer | 1 | A already holds this value: tax |
| BANK0 | `$BE5C` | `f_release` | `jmp resume` | jmp_to_branch | 1 | N is 0 here: bpl reaches the target (+9, same page) |
| BANK0 | `$BEAD` | `no_bonus` | `lda #$00` | reg_xfer | 1 | Y already holds this value: tya |
| BANK1 | `$B552` | `ttl_rupt_timer` | `lda #$04` | imm_load | 2 | A is already $04 |
| BANK1 | `$B55C` | `ttl_rupt_timer` | `lda #$06` | imm_load | 2 | A is already $06 |
| BANK1 | `$B592` | `ttl_rt_not1` | `lda #$06` | imm_load | 2 | A is already $06 |
| BANK1 | `$B597` | `ttl_rt_not1` | `lda #$06` | imm_load | 2 | A is already $06 |
| BANK1 | `$B5E8` | `ttl_rt_not3` | `lda #$06` | imm_load | 2 | A is already $06 |
| BANK1 | `$B854` | `save` | `lda #$06` | imm_load | 2 | A is already $06 |
| BANK1 | `$B3EA` | `ttl_c_shift` | `ldx #$00` | reg_xfer | 1 | A already holds this value: tax |
| BANK1 | `$B7D9` | `kr_draw` | `jmp kr_bank` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (-39, same page) |
| BANK1 | `$B8C0` | `take` | `jmp ask` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (-88, same page) |
| BANK1 | `$BE2D` | `named` | `sec` | clc_sec | 1 | C is already 1 |
| BANK1 | `$BE3C` | `named` | `jmp loop` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (-56, same page) |
| BANK2 | `$B8DA` | `not_hold` | `lda #$00` | imm_load | 2 | A is already $00 |
| BANK2 | `$B8CB` | `expired` | `ldx #$00` | reg_xfer | 1 | A already holds this value: tax |
| BANK2 | `$B8D4` | `expired` | `ldx #$00` | reg_xfer | 1 | A already holds this value: tax |
| BANK2 | `$B8F9` | `fading` | `sec` | clc_sec | 1 | C is already 1 |
| BANK2 | `$B901` | `fading` | `jmp pal` | jmp_to_branch | 1 | Z is 1 here: beq reaches the target (+27, same page) |
| BANK3 | `$8DCA` | `row_done` | `ldy #$00` | imm_load | 2 | Y is already $00 |
| BANK3 | `$8E5A` | `title_auto` | `ldy #$8D` | imm_load | 2 | Y is already $8D |
| BANK3 | `$8E62` | `title_auto` | `ldy #$8D` | imm_load | 2 | Y is already $8D |
| BANK3 | `$8ECD` | `pages` | `ldx #$00` | imm_load | 2 | X is already $00 |
| BANK3 | `$8DF1` | `char_loop` | `lda #$00` | reg_xfer | 1 | Y already holds this value: tya |
| BANK3 | `$8EB9` | `mem_page` | `ldy #$00` | reg_xfer | 1 | A already holds this value: tay |
| HAZEL | `$D348` | `dec_no_borrow` | `lda #$00` | dead_insn | 2 | its results (ANZ) are all dead |
| HAZEL | `$D35E` | `finished_exit` | `lda #$FF` | dead_insn | 2 | its results (ANZ) are all dead |
| HAZEL | `$D35B` | `stop` | `jmp sn_reset` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+25, same page) |
| HAZEL | `$D387` | `sn_reset` | `jmp sn_write` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (-40, same page) |
| HAZEL | `$D41A` | `m_off` | `jmp produce` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+52, same page) |
| HAZEL | `$D440` | `r_set` | `jmp produce` | jmp_to_branch | 1 | Z is 0 here: bne reaches the target (+14, same page) |
| HAZEL | `$D445` | `lit` | `clc` | clc_sec | 1 | C is already 0 |
| HAZEL | `$D4D6` | `nonoise` | `jsr sn_write` | tail_call | 1 | jsr/rts -> jmp |
