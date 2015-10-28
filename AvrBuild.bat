@ECHO OFF
"C:\Program Files (x86)\Atmel\AVR Tools\AvrAssembler2\avrasm2.exe" -S "C:\Users\Kieran\comp2121\labels.tmp" -fI -W+ie -C V3 -o "C:\Users\Kieran\comp2121\project.hex" -d "C:\Users\Kieran\comp2121\project.obj" -e "C:\Users\Kieran\comp2121\project.eep" -m "C:\Users\Kieran\comp2121\project.map" "C:\Users\Kieran\comp2121\project.asm"
