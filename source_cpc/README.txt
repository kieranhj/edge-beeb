
EDGE GRINDER

128K CPC Version

Developed by Cosine for Format War

Code by Paul Kooistra
Graphics by Trevor "Smila" Storey
Music by Tom & Jerry

Additionally:
the interrupt code is based on source posted by Arnoldemu
the register 3 scroll code is based on source posted by Executioner


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
SOURCE
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

The source code is built from 4 different files:

Compiled_main3.asm
EG_Panel.asm
Backgroundbank.asm
Compiledspritebank2.asm


Compiled_main3.asm - is the main code block which begins at &d0, and includes the files:
EG_Sprites10.asm
EG_Sprites_Partial.asm
EG_Display3.asm
EG_Stars3.asm
EG_Interrupts2.asm
EG_Collision5.asm
EG_Animate.asm
EG_Zoom.asm
EG_Move3.asm
ArkosTrackerPlayer_CPC_MSX.asm
EG_WaveList2.asm
MegaHero.asm

These are all found in the source directory with the exception of ArkosTrackerPlayer_CPC_MSX.asm
This file is included with Arkos Tracker which can be downloaded from

http://www.grimware.org/doku.php/documentations/software/arkos.tracker/start


EG_Panel.asm - is general data block that is located at &4000 in main memory, it contains some code,
tables, fonts and text.  It includes the files:
YTable.asm
EG_Gamefont.asm
zsfont.asm
EG_small_font.asm
fntmask.asm


Backgroundbank.asm - includes the tile writer code, level data, tiles & characters.  In game it lives
 in the 4th bank of extended memory. It includes the files:
Block_Writer4.asm
EG_Map_Formatted.asm
EG_Tiles_Formatted.asm
char_graphic5.asm


Compiledspritebank2.asm includes the compiled sprite frames for the player and player bullet, as well
as the enemy wave data.  It is kept at the 2nd bank of extended memory and includes the files:
EG_sprites_player.asm
EG_sprites_laser.asm
EG_sprites_player_grind.asm
eg_wave_data_converted.asm


Bank 3 stores the 'normal' sprite bank for all other frames, and bank 1 stores the strobed versions.
I have also included the source for the test loader (Loader128k.asm) and the final loader which
decompresses everything from a single file (Loaderpack2.asm)  You will need to download z80 source
for bitbuster yourself if you wish to compile that last one.


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
MUSIC
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

I have included the Starkos files for the two pieces of music composed by Tom & Jerry in the Music folder.
You can use these with Starkos or Arkos Tracker, downloadble from the link in the Source section.

+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
WORK DISKS
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

Here you will find 3 of my work disks which I have included as they may shed a little more light on
how some things go together.

Edge_build.dsk contains the file "Combcode.bas" which combines the music in with the code and panel
files.

Edge_sprites2.dsk contains a couple of BASIC files starting with "save" that show the byte order the
sprites have been saved in.

Edge_BG.dsk contains BASIC files used to reformat the tile and character & map data.
"Savetile.bas" & "savemap.bas" simply take the original C64 data and convert it for use to the CPC tile
writer.  "Savechrs.bas" converts the character data from the art studio screen into 'interim' data.
This is formatted for use by subsequently running "savechra.bas".


+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
FINALLY....
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

I have included both a tape and disk version of the final game.  Note that both versions of the game
are 128K only!  I have only provided a tape version for those who might have a 6128 without
a 3.5" drive or HxC attached.