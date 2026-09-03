"""export_waves.py - the C64's attack wave table -> src/data/waves.bin.

wave_data is 9 bytes per wave, read one byte at a time by wave_read:

  x, y            start position
  move 1, move 2  movement commands, two nibble pairs each (see emove_up)
  rocker          the timer value the enemy switches from move 1 to move 2 at
  reset           the timer value it wraps at
  object          enemy_1..enemy_16, an index into anim_decode
  shielding       hits needed to destroy it
  time            ticks until the next wave

It is written with symbolic constants - `left_1`, `left_1+up_1`, `enemy_10` -
so this resolves them out of the source rather than hand-copying 1,400 bytes.
A record whose first byte is $ff ends the table and sets the completion flag.

anim_decode goes with it: 19 start/end frame pairs - explosion, player ship,
player bullet, then enemy_1 to enemy_16 - indexed by the object byte, which is
how a wave picks its animation. enemy_1 is 3, so the object byte indexes it
directly and the C64's `asl : tax` doubles it into the pair.

Run from the project root: python tools/export_waves.py
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))

OUT = "src/data"
C64_ASM = "source_c64/edge_grinder.asm"
RECORD = 9
TERMINATOR = 0xFF
ANIM_PAIRS = 19             # explosion, player, bullet, then enemy_1..16


def source_constants(text):
    """The `name = $xx` assignments at the top of the source."""
    consts = {}
    for name, value in re.findall(r"^(\w+)\s*=\s*\$([0-9a-fA-F]+)", text, re.M):
        consts[name] = int(value, 16)
    return consts


def byte_values(text, label, consts):
    """Every !byte operand under `label`, until the next top-level label."""
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if re.match(rf"^{label}\b", l))
    out = []
    for i in range(start, len(lines)):
        line = lines[i]
        if i > start and re.match(r"^\w+", line):
            break                # a new top-level label, even one with !byte
                                 # on the same line, as spr_defaults has
        m = re.search(r"!byte\s+([^;]*)", line)
        if not m:
            continue
        for term in m.group(1).split(","):
            term = term.strip()
            if not term:
                continue
            total = 0
            for part in term.split("+"):
                part = part.strip()
                if part.startswith("$"):
                    total += int(part[1:], 16)
                elif part.isdigit():
                    total += int(part)
                else:
                    total += consts[part]
            out.append(total & 0xFF)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    text = open(C64_ASM, encoding="latin-1").read()
    consts = source_constants(text)

    waves = byte_values(text, "wave_data", consts)
    # Trim to the terminator: the first record whose x byte is $ff ends it.
    end = None
    for i in range(0, len(waves) - RECORD + 1, RECORD):
        if waves[i] == TERMINATOR:
            end = i + 1          # keep the $ff itself; wave_read tests it
            break
    assert end is not None, "no $ff terminator found in wave_data"
    waves = waves[:end]
    count = (end - 1) // RECORD
    assert (end - 1) % RECORD == 0, end

    anim = byte_values(text, "anim_decode", consts)
    assert len(anim) == ANIM_PAIRS * 2, len(anim)

    open(f"{OUT}/waves.bin", "wb").write(bytes(waves))
    open(f"{OUT}/anim_decode.bin", "wb").write(bytes(anim))
    print(f"waves.bin {len(waves)} B: {count} waves of {RECORD} bytes + terminator")
    print(f"anim_decode.bin {len(anim)} B: {ANIM_PAIRS} start/end pairs")


if __name__ == "__main__":
    main()
