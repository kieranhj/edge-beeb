python bin\convert_sprites.py --quiet -o build/sprites.mode2.bin --160 --transparent-output 0 --transparent-rgb 96 96 96 --total-sprites 119 ./assets/sprite-sheet.png 2 12 21

..\..\Bin\beebasm.exe -i edge-beeb.asm -do edge-beeb.ssd -boot Edge -v > compile.txt
