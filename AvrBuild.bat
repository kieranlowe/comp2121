@ECHO OFF
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "C:\Users\matvign\Documents\comp2121_ass\labels.tmp" -fI -W+ie -C V3 -o "C:\Users\matvign\Documents\comp2121_ass\project.hex" -d "C:\Users\matvign\Documents\comp2121_ass\project.obj" -e "C:\Users\matvign\Documents\comp2121_ass\project.eep" -m "C:\Users\matvign\Documents\comp2121_ass\project.map" "C:\Users\matvign\Documents\comp2121_ass\project.asm"
