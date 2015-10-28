.include "m2560def.inc"

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_alt
	mov r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

;	Clear the floor_register when the parameter given is
;	the address of floor_register
.macro clear_floor_reg
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y+, temp1
	st Y, temp1
.endmacro

.macro clear_timer
	ldi YL, low(@0) ; load the memory address to Y
	ldi YH, high(@0)
	clr temp1
	st Y+, temp1  ; clear the two bytes at @0 in SRAM
	st Y, temp1
.endmacro

.macro clear_sec_timer
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp1
	st Y, temp1
.endmacro

.def temp1 = r16
.def temp2 = r17

.def row = r18
.def col = r19
.def rmask = r20
.def cmask = r21

.def pushed = r22
.def dir = r23					; 0 means down, 1 means up
.def curr_floor = r24
.def next_floor = r25

.equ number_w = 0x30			; binary for 0011, used to write numbers (i.e. 0011 0001 is 1)

.equ PORTLDIR = 0xF0			; 1111 0000
.equ INITCOLMASK = 0xEF			; 1110 1111, right most column
.equ INITROWMASK = 0x01			; 0000 0001, scan from top row
.equ ROWMASK = 0x0F				; 0000 1111, use to obtain input from portL

.dseg
floor_register:
	.byte 10
tempCounter:
	.byte 2
secondCounter:
	.byte 1

.cseg
.org OVF0addr
	jmp Timer0OVF


RESET:
	ldi temp1, low(RAMEND)		; initialise a stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1

;	Setup lcd
	ser temp2
	out DDRF, temp2
	out DDRA, temp2
	clr temp2
	out PORTF, temp2
	out PORTA, temp2

	do_lcd_command 0b00111000 	; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 	; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 	; 2x5x7
	do_lcd_command 0b00111000 	; 2x5x7
	do_lcd_command 0b00001000 	; display off, cursor off, bar off, blink off
	do_lcd_command 0b00000001 		; clear display
	do_lcd_command 0b00000110 		; increment, no display shift
	do_lcd_command 0b00001100 		; display on, cursor on, no blink

;	Setup timer and enable interrupt (do not activate yet)
	clear TempCounter  				; Initialize the temporary counter to 0
	clear SecondCounter  			; Initialize the second counter to 0
	ldi temp1, 0b00000000
	out TCCR0A, temp
	ldi temp1, 0b00000010
	out TCCR0B, temp 				; Prescaling value=8
	ldi temp1, 1<<TOIE0  			; = 128 microseconds
	sts TIMSK0, temp1 				; T/C0 interrupt enable

;	Setup pull up register
	ldi temp1, PORTLDIR				; load temp1 with 1111 0000
	sts DDRL, temp1					; store into pinL
	
;	Setup some global registers
	ldi pushed, 0
	ldi curr_floor, 0				; curr_floor is ground floor (0)
	ldi dir, 1						; starting direction is up


;	Start scanning the keyboard
MAIN:
	ldi cmask, INITCOLMASK			; 1110 1111
	clr col

	;	Print to the lcd.	
	do_lcd_command 0b00000001 		; clear display
	do_lcd_data 'C'
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'F'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ':'
	do_lcd_data ' '
	do_lcd_data_alt curr_floor
	do_lcd_command 0b11000000 	; set address to second line

	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	ldi temp1, 0
PRINT_ITERATE:
	cpi Z, 1
	breq PRINT_FLOOR

	adiw ZL:ZH, 1
	inc temp1
	do_lcd_data ' '
	do_lcd_data ' '

	cpi temp1, 10
	breq PRINT_END
	
	adiw ZL:ZH, 1
	inc temp1
	cpi temp1, 10
	breq PRINT_END
	
	jmp PRINT_ITERATE

PRINT_END:
;	If something was pressed, wait
	cpi pushed, 1
	breq WAIT

;	Start the timer
	sei
	
;	Scan the columns
	rjmp colloop
	
;	Wait until button isnt being held
WAIT:
	sts PORTL, temp2
	nop
	nop
	lds temp1, PINL				; Obtain value from the keypad
	andi temp1, ROWMASK			; Isolate bottom 4 bits
	cpi temp1, 0xF				; check if row is high (i.e. something being pressed)
	breq READY
	rjmp WAIT
READY:
	ldi pushed, 0
	jmp main


colloop:
	cpi col, 4
	breq main					; restart the scan

	sts PORTL, cmask
	ldi temp1, 0xFF				; load temp1 with 1111 1111
	
	jmp delay

;	Debounce
delay:
	dec temp1
	brne delay

	lds temp1, PINL				; read port L
	andi temp1, ROWMASK
	cpi temp1, 0xF				; check if row is high (i.e. nothing pressed)
	breq nextcol

	ldi temp2, 0xFF

delay2:							; wait?
	dec temp2
	nop
	nop
	brne delay2

	lds temp1, PINL
	andi temp1, ROWMASK
	cpi temp1, 0xF
	breq nextcol				; check if row is high (i.e. nothing pressed)

	ldi rmask, INITROWMASK  	; 0000 0001
	clr row

rowloop:
	cpi row, 4					; next col if end of row
	breq nextcol

	mov temp2, temp1
	and temp2, rmask			; check if this row was pressed
	breq convert				; convert if so

	inc row						; next row
	lsl rmask					; shift rmask 0000 0001 -> 0000 0010
	jmp rowloop

nextcol:
	lsl cmask					; 1101 1110
	inc cmask					; 1101 1111
	inc col
	jmp colloop

convert:
;	Do nothing for letters
	cpi col, 3
	breq letters

;	Interpret symbols
	cpi row, 3
	breq symbols

;	Interpret numbers 1-9
	mov temp1, row
	lsl temp1					; number pressed = row*3 + col + 1
	add temp1, row
	add temp1, col
	inc temp1
	jmp add_to_register

;	Load the register values from data memory
add_to_register:
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
find_placement:
	cpi temp1, 0
	breq store_register_val

	adiw ZH:ZL, 1
	subi temp1, 1
	jmp find_placement
store_register_val:
	st Z, temp1
	rjmp main

;	Do nothing, return to main
letters:
	rjmp main

;	Case for symbols
symbols:
;	Case for asterisk (*)
	cpi col, 0
	breq emergency

;	Case for zero
	cpi col, 1
	breq zero_case

;	Hash symbol, ignore it
	rjmp main

emergency:
	clear_floor_reg floor_register
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	ldi pushed, 1
	
	ldi temp1, 1
	st Z, temp1
	rjmp main

zero_case:
	ldi temp2, 1
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	st Z, temp2
	ldi pushed, 1
	rjmp main

;	Timer that counts two seconds
Timer0OVF:
	in temp1, SREG
	push temp1
	push temp2
	push ZH
	push ZL
	push YH
	push YL
	push r25
	push r24

;	Check what direction to go depending on what dir is defined
CHECK_DIR:
	cpi dir, 1
	breq ITERATE_UP

	jmp ITERATE_DOWN

;	Lift is moving up, scan floors from the bottom.
;	Check if the floor register is checked. If it is, we check if we are on that floor at the moment. If so, then we wait one second instead of two seconds for the door.

ITERATE_UP:
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	ldi temp1, 0
CHECK_FLOOR_U:
	cpi Z, 1
	breq CHECK_IF_U

	adiw ZL:ZH, 1
	inc temp1
	jmp CHECK_FLOOR_U

;	If you are currently on this floor, then wait for one second instead of the usual two. If push buttom is pushed, or wait period is over, we change the value of the current thingy
CHECK_IF_U:
	cpi temp1, curr_floor
	breq stop_here
	
	do_something_else
	
stop_here:
	...

ITERATE_DOWN:
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	adiw ZL:ZH, 10
	ldi temp1, 10
CHECK_FLOOR_D:
	cpi Z, 1
	breq CHECK_IF_D
	
	subi ZL:ZH, 1
	dec temp1
	jmp CHECK_FLOOR_D
	
CHECK_IF_D:
	cpi temp1, curr_floor
	brlt do_something_d
	
	do_something_else
	

;	Increment the tempCounter, when tempCounter hits 1 second, add 1 second to secondCounter. When secondCounter has hit 2, increment curr_floor
INCREMENT_TIMER:
;	increment tempCounter
	lds r24, tempCounter
	lds r25, tempCounter+1
	adiw r25:r24, 1

;	Check if it has been one second, if it hasnt,
;	store the tempCounter value
	cpi r24, low(7812)
	ldi temp1, high(7812)
	cpc r25, temp1
	brne NOTSECOND
	
;	Otherwise it has been a second, reset tempCounter
;	and increment secondCounter
	clear_timer tempCounter
	lds r24, secondCounter
	inc r24
	sts secondCounter, r24
	
	cpi r24, 2
	breq CHANGE_FLOOR
	
	rjmp ENDIF

CHANGE_FLOOR:
	cpi dir, 1
	breq CHANGE_FLOOR_U
	rjmp CHANGE_FLOOR_D
CHANGE_FLOOR_U:
	inc curr_floor
	clear_sec_timer secondCounter
	rjmp ENDIF
CHANGE_FLOOR_D:
	dec curr_floor
	clear_sec_timer secondCounter
	rjmp ENDIF
	
NOTSECOND:
	sts tempCounter, r24
	sts tempCounter+1, r24
	rjmp ENDIF

ENDIF:
	pop r24 					; Epilogue starts;
	pop r25 					; Restore all conflict registers from the stack.
	pop YL
	pop YH
	pop ZL
	pop ZH
	pop temp2
	pop temp1
	out SREG, temp
	reti

