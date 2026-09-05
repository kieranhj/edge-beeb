#!/bin/sh
# Bash wrapper round build.ps1's beebasm invocation, for agent use: PowerShell
# turns beebasm's progress on stderr into a terminating error under some
# profiles, and this does not. Same names and disc titles as build.ps1.
# Flags come from the environment: RELEASE, MUSIC_AKL, GFX_CPC, GFX_NULA, 0 or 1.
set -e
R=${RELEASE:-0}; A=${MUSIC_AKL:-0}; C=${GFX_CPC:-0}; N=${GFX_NULA:-0}
BEEB=../../Bin/beebasm.exe
[ -x bin/beebasm.exe ] && BEEB=bin/beebasm.exe
STEM=EDGE; TITLE=EDGE
[ "$A" = 1 ] && { STEM=$STEM-AKL; TITLE=${TITLE}A; }
[ "$C" = 1 ] && { STEM=$STEM-CPC; TITLE=${TITLE}C; }
[ "$N" = 1 ] && { STEM=$STEM-NULA; TITLE=${TITLE}N; }
mkdir -p build
"$BEEB" -i src/main.asm -do build/$STEM-RAW.SSD -opt 3 -title "$TITLE" \
    -D RELEASE=$R -D MUSIC_AKL=$A -D GFX_CPC=$C -D GFX_NULA=$N -v > build/$STEM.lst
python tools/make_disc.py build/$STEM-RAW.SSD build/$STEM.SSD build/$STEM-200K.SSD
