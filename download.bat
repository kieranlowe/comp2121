"c:\Program Files (x86)\Arduino\hardware\tools\avr\bin\avrdude.exe" -C "c:\Program Files (x86)\Arduino\hardware\tools\avr\etc\avrdude.conf" -c wiring -p m2560 -P %1 -b 115200 -U flash:w:%2:i -D 

