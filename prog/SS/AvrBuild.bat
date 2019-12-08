@ECHO OFF
"D:\ProgramData\AVR_Studio\AvrAssembler2\avrasm2.exe" -S "D:\MPS\prog\SS\labels.tmp" -fI -W+ie -C V1 -o "D:\MPS\prog\SS\SS.hex" -d "D:\MPS\prog\SS\SS.obj" -e "D:\MPS\prog\SS\SS.eep" -m "D:\MPS\prog\SS\SS.map" "D:\MPS\prog\SS\SS.asm"
