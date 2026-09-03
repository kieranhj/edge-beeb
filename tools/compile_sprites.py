"""compile_sprites.py - turn bounding-boxed sprite frames into straight-line 6502.

Called by export_sprites.py. Writes src/data/compiled.bin, the image for sideways
slot 7 (SWRAM_COMPILED), and src/data/compiled_zp.asm, the assertions that keep
the zero-page addresses baked in here honest.

WHY A WHOLE BANK OF ITS OWN. A compiled body reads no sprite data - every pixel
is an immediate - so it does not have to live in the bank of its own pixel shift.
Both shifts go in slot 7 together, and the restore, which pages no bank today,
has one bank to page rather than two and nothing to remember about which.

WHAT IT EMITS, per frame and shift, a draw body and a restore body:

    draw, per opaque byte      ldy #n*8            2 cycles
                               lda (bufp), y       5   the background
                               sta (svp), y        6   saved for the restore
                               and #mask           2   omitted when nothing shows
                               ora #data           2   lda #data when nothing does
                               sta (bufp), y       6
                                                  23, or 21 for a solid byte

    restore, per opaque byte   ldy #n*8 : lda (svp), y : sta (bufp), y   13

against 36 and 13 interpreted, and the transparent bytes of the box - 56% of the
bullet at shift 0 and 64% at shift 1 - cost nothing at all rather than full price.

Between rows it emits SCANSTEP inline, and each body carries its own copy of the
character-row crossing tail so that it needs no address from the assembler: the
only things it has to agree with src/ about are the zero page addresses of bufp
and svp and a handful of geometry constants, and compiled_zp.asm asserts those.

ONLY FRAMES THAT NEVER HIT-FLASH CAN BE COMPILED, because the colours are baked
in where the interpreted path reads them through a swappable table. The caller
passes the set of frames that qualify.
"""

BANK = 0x8000
GUARD = 0xC000
DESC_START = 0x8000       # four bytes a compiled frame: draw lo/hi, restore lo/hi
CODE_START = 0x8200

# Zero page, from the map at the top of src/main.asm. compiled_zp.asm asserts them.
ZP_BUFP = 0x0E
ZP_SVP = 0x10

# Geometry, from src/main.asm and src/sprite.asm.
ROW_STRIDE = 640
SCREEN_SIZE = 0x4000
SPR_BLOCK = 56            # SPR_W * 8: one character row of save area


def mask_of(b):
    """The AND mask the engine's SPR_MASK table gives for this data byte:
    the background bits that still show through."""
    m = 0
    if b & 0xAA == 0:
        m |= 0xAA
    if b & 0x55 == 0:
        m |= 0x55
    return m


def _crossing_tail():
    """spr_scan_row, inlined into the body so no assembler address is needed.
    bufp is on what would be scanline 8, so both pointers move on by stride - 8;
    it finishes the INC that SCANSTEP left half done, and wraps the 16K buffer."""
    return bytes([
        0x18,                                   # clc
        0xA5, ZP_SVP,                           # lda svp
        0x69, (SPR_BLOCK - 8) & 0xFF,           # adc #SPR_BLOCK-8
        0x85, ZP_SVP,                           # sta svp
        0x18,                                   # clc
        0xA5, ZP_BUFP,                          # lda bufp
        0xD0, 0x02,                             # bne +2 (over the inc)
        0xE6, ZP_BUFP + 1,                      # inc bufp+1
        0x69, (ROW_STRIDE - 8) & 0xFF,          # adc #LO(row_stride-8)
        0x85, ZP_BUFP,                          # sta bufp
        0xA5, ZP_BUFP + 1,                      # lda bufp+1
        0x69, (ROW_STRIDE - 8) >> 8,            # adc #HI(row_stride-8)
        0x10, 0x02,                             # bpl +2 (over the sbc)
        0xE9, (SCREEN_SIZE >> 8) - 1,           # sbc #HI(screen_size)-1, carry clear
        0x85, ZP_BUFP + 1,                      # sta bufp+1
        0x60,                                   # rts
    ])


def _scanstep(code, fixups):
    """One scanline on, with the crossing out of line in this body's own tail."""
    code += bytes([0xE6, ZP_SVP,                # inc svp
                   0xE6, ZP_BUFP,               # inc bufp
                   0xA5, ZP_BUFP,               # lda bufp
                   0x29, 0x07,                  # and #7
                   0xD0, 0x03,                  # bne +3 (over the jsr)
                   0x20])                       # jsr <tail>
    fixups.append(len(code))
    code += b'\0\0'


def _body(rows, draw):
    """Straight-line code for one frame. rows is the box, row-major, 0 = clear."""
    code = bytearray()
    fixups = []
    for r, row in enumerate(rows):
        for n, v in enumerate(row):
            if not v:
                continue
            y = n * 8
            if draw:
                m = mask_of(v)
                code += bytes([0xA0, y,                 # ldy #n*8
                               0xB1, ZP_BUFP,           # lda (bufp), y
                               0x91, ZP_SVP])           # sta (svp), y
                if m:
                    code += bytes([0x29, m,             # and #mask
                                   0x09, v])            # ora #data
                else:
                    code += bytes([0xA9, v])            # lda #data - nothing shows
                code += bytes([0x91, ZP_BUFP])          # sta (bufp), y
            else:
                code += bytes([0xA0, y,                 # ldy #n*8
                               0xB1, ZP_SVP,            # lda (svp), y
                               0x91, ZP_BUFP])          # sta (bufp), y
        if r != len(rows) - 1:                          # the caller does not want
            _scanstep(code, fixups)                     # the last row's step
    code += b'\x60'                                     # rts
    tail = len(code)
    code += _crossing_tail()
    return bytes(code), fixups, tail


def build(frames, out_bin, out_asm):
    """frames: {(shift, frame): rows}. Lays out slot 7 and writes both files."""
    desc = bytearray(CODE_START - DESC_START)
    code = bytearray()

    def emit(rows, draw):
        body, fixups, tail = _body(rows, draw)
        base = CODE_START + len(code)
        body = bytearray(body)
        for f in fixups:
            body[f] = (base + tail) & 0xFF
            body[f + 1] = (base + tail) >> 8
        code.extend(body)
        return base

    table = {}
    for key in sorted(frames):
        rows = frames[key]
        d = emit(rows, True)
        r = emit(rows, False)
        table[key] = (d, r)

    # Descriptors, four bytes each, in the order the frames were laid out.
    slot = {}
    for i, key in enumerate(sorted(table)):
        a = i * 4
        d, r = table[key]
        desc[a:a + 4] = bytes([d & 0xFF, d >> 8, r & 0xFF, r >> 8])
        slot[key] = DESC_START + a
    assert CODE_START - DESC_START >= 4 * len(table), "too many compiled frames"

    image = bytes(desc) + bytes(code)
    assert BANK + len(image) <= GUARD, f"compiled bank overflows: {len(image)} B"
    open(out_bin, 'wb').write(image)

    with open(out_asm, 'w', newline='') as f:
        f.write("\\ Generated by tools/compile_sprites.py - do not edit.\n"
                "\\ The compiled sprite bodies have these baked into them; if the zero\n"
                "\\ page moves under them they must be regenerated, so fail the build.\n")
        f.write(f"ASSERT bufp = &{ZP_BUFP:02X}\n")
        f.write(f"ASSERT svp = &{ZP_SVP:02X}\n")
        f.write(f"ASSERT row_stride = {ROW_STRIDE}\n")
        f.write(f"ASSERT screen_size = &{SCREEN_SIZE:04X}\n")
        f.write(f"ASSERT SPR_BLOCK = {SPR_BLOCK}\n")
        f.write(f"COMPILED_FRAMES = {len(table)}\n")

    return slot, len(image)
