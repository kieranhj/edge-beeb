# Build Edge Grinder (BBC Master 128) -> build/EDGE.SSD
#
#   .\build.ps1            assemble into build/
#   .\build.ps1 -Run       assemble and launch in b-em as a Master 128
#   .\build.ps1 -Release   the build for other people: every DEBUG_ flag off
#
# make.bat is a thin wrapper over this file (`make`, `make run`, `make -Release`).
param([switch]$Run, [switch]$Release, [switch]$Akl)

$ErrorActionPreference = 'Stop'

# RELEASE is a command-line symbol because beebasm has no IFDEF and refuses a
# symbol defined twice, so main.asm cannot carry a default of its own. It is
# passed on EVERY build; a bare beebasm invocation must pass it too.
$relDef = if ($Release) { 'RELEASE=1' } else { 'RELEASE=0' }
$aklDef = if ($Akl) { 'MUSIC_AKL=1' } else { 'MUSIC_AKL=0' }
# The disc title says which music build it is, so *CAT tells you without
# booting it; !BOOT stamps the same thing where you cannot miss it.
$discTitle = if ($Akl) { 'EDGEAKL' } else { 'EDGE' }

$root    = $PSScriptRoot
$build   = Join-Path $root 'build'
# The Arkos build gets its own filenames so the two discs can sit side by side
# and be compared; without that -Akl would quietly overwrite the normal one.
$stem    = if ($Akl) { 'EDGE-AKL' } else { 'EDGE' }
$raw     = Join-Path $build "$stem-RAW.SSD"
$ssd     = Join-Path $build "$stem.SSD"
$padded  = Join-Path $build "$stem-200K.SSD"
$listing = Join-Path $build "$stem.lst"

# beebasm lives in the shared BEEB\Bin folder two levels up; a local bin\
# copy wins if one is present.
$beebasm = Join-Path $root 'bin\beebasm.exe'
if (-not (Test-Path $beebasm)) { $beebasm = Join-Path $root '..\..\Bin\beebasm.exe' }
if (-not (Test-Path $beebasm)) { throw "beebasm.exe not found at $beebasm" }

$bem = 'C:\Users\khcon\OneDrive\BEEB\B-Em\b-em-42f6597-w64\b-em.exe'

if (-not (Test-Path $build)) { New-Item -ItemType Directory -Path $build | Out-Null }

# beebasm resolves INCLUDE and INCBIN relative to the working directory, so it
# runs from the project root. -v (the listing) goes to STDOUT and is captured;
# the progress messages go to STDERR and are deliberately NOT redirected -
# in PowerShell that wraps each line in an ErrorRecord and trips
# $ErrorActionPreference even when the assembly succeeded. Check the exit code.
# -opt 3 makes the disc *EXEC !BOOT on SHIFT+BREAK; main.asm assembles its own
# !BOOT (with the build kind stamped in it) rather than using -boot.
Push-Location $root
try {
    & $beebasm -i 'src\main.asm' -do $raw -opt 3 -title $discTitle -D $relDef -D $aklDef -v |
        Out-File -FilePath $listing -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "beebasm failed ($LASTEXITCODE) - see $listing" }
} finally { Pop-Location }

# beebasm's image is NOT bootable. The boot loader runs the ZX0 depacker over
# every file it loads, and make_disc.py is what compresses them - it also
# moves each catalogue load address to the staging address main.asm expects,
# and lays the files out in boot access order so the head never seeks back.
# It writes the padded 200K copy too (80 tracks x 10 sectors x 256 B): jsbeeb
# boots an unpadded image, but the padded one is the convention for anything
# handed to an emulator or published.
Push-Location $root
try {
    & python 'tools\make_disc.py' $raw $ssd $padded
    if ($LASTEXITCODE -ne 0) { throw "make_disc.py failed ($LASTEXITCODE)" }
} finally { Pop-Location }

if ($Release) { "RELEASE build: every DEBUG_ flag off" }
if ($Akl)     { "ARKOS music build: src/aklplayer.asm + src/ay2sn.asm, whole tune" }
"Built  $ssd"
"       $padded   padded, for jsbeeb"
"       $raw   beebasm's own output, uncompressed and NOT bootable"
"       $listing   assembly listing"

if ($Run) { & $bem -m3 $ssd }
