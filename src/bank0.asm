\ ******************************************************************
\ *	bank0.asm
\ *	Sideways RAM bank 0 (slot SWRAM_DATA): the converted charset,
\ *	the C64 tiles, both maps, col_decode and the attack wave table. From
\ *	tools/export_tiles.py and tools/export_waves.py;
\ *	regenerate with the tool rather than editing src/data.
\ ******************************************************************

CLEAR 0,&FFFF
ORG &8000
GUARD &C000
.bank0_start

\\ Characters as four MODE 2 column planes: plane p at char_data + p*2048,
\\ char c row r at + c*8 + r, colour in the right-pixel bits (6,4,2,0).
\\ 256 chars x 8 rows x 4 planes = 8192 bytes.

.char_data
INCBIN "src/data/chars.bin"
ASSERT P% = char_data + 8192
PRINT "CHARACTER data =", ~char_data

\\ Each tile is 4x4 characters, row-major; 211 tiles x 16 bytes = 3376.

PAGE_ALIGN
.tile_data
INCBIN "src/data/tiles.bin"
PRINT "TILE data =", ~tile_data

\\ Map is 5 tiles high, column-major, 302 columns (tiles.map + tiles2.map) = 1510 bytes.

PAGE_ALIGN
.map_data
INCBIN "src/data/map.bin"
.map_end
PRINT "MAP data =", ~map_data

\\ The C64 col_decode table: low 3 bits per-char colour (already applied to
\\ the planes), bit 4 = fatal to the player (Layer 4 reads this).

PAGE_ALIGN
.col_decode
INCBIN "src/data/col_decode.bin"
PRINT "COL_DECODE =", ~col_decode

\ The attack wave table: 9 bytes a wave, read a byte at a time by
\ wave_read, terminated by an $ff in the x position. anim_decode is the
\ 19 start/end frame pairs a wave's object byte picks its animation from.
\ Both from tools/export_waves.py.

PAGE_ALIGN
.wave_data
INCBIN "src/data/waves.bin"
.wave_end
PRINT "WAVE data =", ~wave_data

.anim_decode
INCBIN "src/data/anim_decode.bin"
PRINT "ANIM_DECODE =", ~anim_decode

\ coll_map row bases. The map is 800 bytes and crosses pages, so the read
\ is (ptr),Y with the column in Y. They live up here rather than in main
\ RAM because their only reader is coll_read, which runs from game_tick
\ with bank 0 resting - and main RAM below &2000 has none to spare.
.coll_row_lo
FOR n,0,COLL_ROWS-1,1
    EQUB LO(coll_map + n*COLL_COLS)
NEXT
.coll_row_hi
FOR n,0,COLL_ROWS-1,1
    EQUB HI(coll_map + n*COLL_COLS)
NEXT

\ The frame meter lives up here, not in main RAM: it is a DEV-only
\ facility and main RAM below &2000 has no room for one. Bank 0 is the
\ resting SWRAM state, paged in whenever the main loop is running its
\ own code, so a plain JSR reaches it - the only routines that page it
\ out are spr_restore_all and spr_draw_all, and no mark is taken inside
\ either. See src/timing.asm.
INCLUDE "src/timing.asm"


\ ******************************************************************
\ *	Boot-time display setup, up here rather than in main RAM.
\ ******************************************************************
\ setup_display, clear_play and panel_init run once, from main, after
\ the banks are loaded and SWRAM_DATA is paged in, and nothing else
\ calls them. The IRQ handler and install_irq stay in main RAM, where
\ they must be: the handler fires with whatever bank the loop was using.

\ ******************************************************************
\ *	Display setup, after the mode change and the bank loads, before
\ *	install_irq. Starts the CRTC in cycle B's shape so the first VSync
\ *	arrives with C4 where the steady state expects it.
\ ******************************************************************

.setup_display
{
    \\ 16K hardware wrap: addressable latch lines 4 and 5 low
    lda #&0f : sta &fe42        ; DDRB: latch bits are outputs
    lda #4   : sta &fe40        ; C0 = 0
    lda #5   : sta &fe40        ; C1 = 0  -> 16K, &4000-&7FFF

    CRTC 4, PLAY_R4
    CRTC 5, 0
    CRTC 6, PLAY_ROWS
    CRTC 7, PLAY_R7
    CRTC 10, &20                ; cursor off
    CRTC 12, HI(screen_start/8)
    CRTC 13, LO(screen_start/8)

    \\ Palette: logical n -> physical n for 0-7; 8-15 -> 0-7 again, not
    \\ flashing, so logical 8 is a second black that sprites may use
    \\ (transparent is 0). &FE21 takes (logical << 4) OR (physical EOR 7).
    ldx #15
    .pal_loop
    txa
    and #7
    eor #7
    sta pal_tmp
    txa
    asl a : asl a : asl a : asl a
    ora pal_tmp
    sta VIDEO_ULA_PAL
    dex
    bpl pal_loop

    \\ The panel is in the shadow-switched region, so draw it into both
    \\ banks: X = 0 (main) then X = 1 (shadow). Leaves X = 1, which is the
    \\ boot state the caller sets anyway.
    lda &fe34
    and #255-4
    sta &fe34
    jsr clear_play
    jsr panel_init
    lda &fe34
    ora #4
    sta &fe34
    jsr clear_play
    jsr panel_init

    \\ Everything is clear: display on. R8 = 0 also means no interlace,
    \\ which keeps VSync at a fixed phase for the rupture timers.
    CRTC 8, 0

    lda #0
    sta field_count
    sta flip_field
    sta frame_ready
    sta rupt_state
    rts

    .pal_tmp EQUB 0
}

\\ Clear the 16K play buffer in whichever bank the X bit selects. The MOS
\\ only clears the main bank at the mode change; the shadow bank would show
\\ whatever it held until the scroll had covered it.
.clear_play
{
    lda #LO(screen_start) : sta write_ptr
    lda #HI(screen_start) : sta write_ptr+1
    ldx #HI(screen_size)
    lda #0
    tay
    .page_loop
    sta (write_ptr), y
    iny
    bne page_loop
    inc write_ptr+1
    dex
    bne page_loop
    rts
}

\\ Clear the panel in whichever bank the X bit selects, then the DEV
\\ placeholder. Anything that draws on the panel must do it for both banks.
.panel_init
{
    lda #LO(PANEL_ADDR) : sta write_ptr
    lda #HI(PANEL_ADDR) : sta write_ptr+1
    ldx #HI(PANEL_BYTES)
    lda #0
    tay
    .clear_page
    sta (write_ptr), y
    iny
    bne clear_page
    inc write_ptr+1
    dex
    bne clear_page
    .clear_tail
    sta (write_ptr), y
    iny
    cpy #LO(PANEL_BYTES)
    bne clear_tail

IF DEV
    jmp fill_panel_test
ELSE
    rts
ENDIF
}

\ ******************************************************************
\ *	TEMPORARY, DEV only: a placeholder in the panel so the rupture can
\ *	be seen. White line on the panel's top and bottom scanlines, and
\ *	sixteen 5-column bars of logical colours 0-15 across rows 1-3
\ *	(8-15 must look like 0-7 and must not flash). Layer 6 replaces it.
\ ******************************************************************

IF DEV
.fill_panel_test
{
    \\ Top scanline of row 0 and bottom scanline of row 4
    lda #LO(PANEL_ADDR) : sta write_ptr
    lda #HI(PANEL_ADDR) : sta write_ptr+1
    lda #LO(PANEL_ADDR + 4*row_stride) : sta read_ptr
    lda #HI(PANEL_ADDR + 4*row_stride) : sta read_ptr+1
    ldx #80
    .edge_loop
    ldy #0
    lda #&ff
    sta (write_ptr), y
    ldy #7
    sta (read_ptr), y
    clc
    lda write_ptr : adc #8 : sta write_ptr
    bcc no_c1
    inc write_ptr+1
    .no_c1
    clc
    lda read_ptr : adc #8 : sta read_ptr
    bcc no_c2
    inc read_ptr+1
    .no_c2
    dex
    bne edge_loop

    \\ Colour bars: rows 1-3, column c shows logical colour c DIV 5
    lda #LO(PANEL_ADDR + row_stride) : sta write_ptr
    lda #HI(PANEL_ADDR + row_stride) : sta write_ptr+1
    lda #3 : sta y_count            ; rows
    .row_loop
    lda #0 : sta sprite_idx         ; bar number
    lda #5 : sta x_count            ; columns left in this bar
    ldx #80
    .col_loop
    ldy sprite_idx
    lda bar_bytes, y
    ldy #7
    .byte_loop
    sta (write_ptr), y
    dey
    bpl byte_loop
    clc
    lda write_ptr : adc #8 : sta write_ptr
    bcc no_c3
    inc write_ptr+1
    .no_c3
    dec x_count
    bne same_bar
    lda #5 : sta x_count
    inc sprite_idx
    .same_bar
    dex
    bne col_loop
    dec y_count
    bne row_loop
    rts

    \\ Solid MODE 2 byte for logical colour n: bit i of n -> bits 2i+1 and 2i
    .bar_bytes
    FOR n, 0, 15, 1
        EQUB ((n AND 1) * 3) OR ((n AND 2) * 6) OR ((n AND 4) * 12) OR ((n AND 8) * 24)
    NEXT
}
ENDIF

.bank0_end

SAVE "BANK0", bank0_start, bank0_end

PRINT "------"
PRINT "BANK 0"
PRINT "------"
PRINT "DATA size =",~bank0_end-bank0_start
PRINT "------"
PRINT "HIGH WATERMARK =", ~P%
PRINT "FREE =", ~&C000-P%
PRINT "------"
