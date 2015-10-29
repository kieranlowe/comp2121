.include "m2560def.inc"

.org INT0addr
	jmp EXT_INT0

.dseg
floor_register: .byte 10
tempCounter: .byte 2
secondCounter: .byte 1

.cseg
.org OVF0addr
	jmp Timer0OVF

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
	ldi temp2, number_w
	add r16, temp2
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

;	clears one byte address
.macro clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp1
	st Y, temp1
.endmacro

;	clears two byte tempCounter
.macro clear_timer
	ldi YL, low(@0) ; load the memory address to Y
	ldi YH, high(@0)
	clr temp1
	st Y+, temp1  ; clear the two bytes at @0 in SRAM
	st Y, temp1
.endmacro



;	Don't execute these instructions unless they are called

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; End Macros ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.def temp1 = r16
.def temp2 = r17
.def temp = r27

.def row = r18
.def col = r19
.def rmask = r20
.def cmask = r21

.def pushed = r22
.def dir = r23						; 0 means down, 1 means up
.def curr_floor = r24				; current floor of elevator
.def next_floor = r25				; next floor to move to
.def ele_status = r26				; 0 = idle, 1 = closed, 2 = opening doors, 3 = idle open, 4 = closing doors

.equ number_w = 0x30				; binary for 0011, used to write numbers (i.e. 0011 0001 is 1)

.equ PORTLDIR = 0xF0				; 1111 0000
.equ INITCOLMASK = 0xEF				; 1110 1111, scan from right most column
.equ INITROWMASK = 0x01				; 0000 0001, and top row
.equ ROWMASK = 0x0F					; 0000 1111, use to obtain input from portL


RESET:
	ldi temp1, low(RAMEND)			; initialise a stack
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

	do_lcd_command 0b00111000 		; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 		; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 		; 2x5x7
	do_lcd_command 0b00111000 		; 2x5x7
	do_lcd_command 0b00001000 		; display off, cursor off, bar off, blink off
	do_lcd_command 0b00000001 		; clear display
	do_lcd_command 0b00000110 		; increment, no display shift
	do_lcd_command 0b00001100 		; display on, cursor on, no blink

;	Setup timer and enable interrupt
	clear_timer tempCounter  				; Initialize the temporary counter to 0
	clear secondCounter  			; Initialize the second counter to 0
	ldi temp1, 0b00000000
	out TCCR0A, temp
	ldi temp1, 0b00000010
	out TCCR0B, temp 				; Prescaling value=8
	ldi temp1, 1<<TOIE0  				; = 128 microseconds
	sts TIMSK0, temp1 				; T/C0 interrupt enable

;;;;;	Experimental!!
;	Setup push button for door closing action
	ldi temp1, (2<<ISC00)
	sts EICRA, temp1
	
	in temp1, EIMSK
	ori temp1, (1 <<INT0)
	out EIMSK, temp1
;;;;;	Experimental!!
	
;	Setup pull up register
	ldi temp1, PORTLDIR				; load temp1 with 1111 0000
	sts DDRL, temp1					; store into pinL
	
;	Setup some global registers
	ldi pushed, 0
	ldi dir, 1
	ldi curr_floor, 0				; curr_floor is ground floor (0)
	ldi next_floor, 0				; next_floor by default is the ground floor
	ldi ele_status, 0				; start elevator idle
	
	
;	Start scanning the keyboard
MAIN:

;	Wait until something isn't being held
	cpi pushed, 1
	breq WAIT

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

;	if elevator is idle or moving, check what the next floor should be
	cpi ele_status, 2
	brlo FIND_NEXT_FLOOR
	
	rjmp SCAN

;	Wait until button isnt being held
;	Prevents multiple input
WAIT:
	sts PORTL, temp2
	lds temp1, PINL					; Obtain value from the keypad
	andi temp1, ROWMASK				; Isolate bottom 4 bits
	cpi temp1, 0xF					; check if row is high (i.e. nothing being pressed)
	breq READY
	rjmp WAIT
READY:
	ldi pushed, 0
	jmp MAIN
	
;	Find the floor we need to go to
FIND_NEXT_FLOOR:
	ldi ZH, high(floor_register)
	ldi ZL, low(floor_register)

	ldi r27, 0							; store the floor we're at
	ldi temp1, 10
	ldi temp2, 0
	ldi col, 2							; borrow this register for a bit

CHECK_FLOOR:
	ld row, Z+							; borrow this register for a bit
	cpi row, 1
	breq floor_marked

	jmp TO_NEXT_FLOOR
	
floor_marked:
	cpi dir, 1
	breq check_up_a
	
	jmp check_down_a
	
check_up_a:
	cp r27, temp1
	brlt check_up_b
	
	jmp TO_NEXT_FLOOR
	
check_up_b:
	cp r27, curr_floor
	brge change_temp1
	
	cpi col, 1
	brne check_down_a
	
	jmp TO_NEXT_FLOOR

check_down_a:
	cp r27, temp2
	brge check_down_b
	
	jmp TO_NEXT_FLOOR	
	
check_down_b:
	cp r27, curr_floor
	brlo change_temp2
	
	cpi col, 0
	brne check_up_a
	
	jmp TO_NEXT_FLOOR
	
change_temp1:
	mov temp1, r27
	ldi col, 1
	jmp TO_NEXT_FLOOR
	
change_temp2:
	mov temp2, r27
	ldi col, 0
	jmp TO_NEXT_FLOOR

TO_NEXT_FLOOR:
	inc r27
	cpi r27, 10
	breq SEARCH_END
	
	jmp CHECK_FLOOR
		
SEARCH_END:
	cpi col, 0
	breq change_next_floor_d
	
	cpi col, 1
	breq change_next_floor_u
	
	jmp SCAN

change_next_floor_d:
	mov temp2, next_floor
	ldi dir, 0
	ldi ele_status, 1
	jmp SCAN
	
change_next_floor_u:
	mov temp1, next_floor
	ldi dir, 1
	ldi ele_status, 1
	jmp SCAN

	
;	Scan the keypad for input
SCAN:
	cpi ele_status, 0
	brne RUN_TIMER	

	ldi cmask, INITCOLMASK			; 1110 1111
	clr col

;	Scan the columns
	rjmp colloop

;	Activate the timer and then return to main
RUN_TIMER:
	sei
	rjmp MAIN
	
colloop:
	cpi col, 4
	breq AGAIN					; restart the scan

	sts PORTL, cmask
	ldi temp1, 0xFF				; load temp1 with 1111 1111
	
	jmp delay

AGAIN:
	rjmp MAIN

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

;	Mark a value to indicate we need to go to that value
; e.g. we pressed 4
; floor_register: 0 1 2 3 4 5 6 7 8 9, temp1 = 4
; floor register = 0, temp1 != 0 (4), dec temp1
; floor register = 1, temp1 != 0 (3), dec temp1
; floor register = 2, temp1 != 0 (2), dec temp1
; floor register = 3, temp1 != 0 (1), dec temp1
; floor register = 4, temp1 = 0, store register value here
add_to_register:
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
find_placement:
	cpi temp1, 0
	breq store_register_val

	adiw ZH:ZL, 1
	dec temp1
	jmp find_placement
store_register_val:
	st Z, temp1
	mov temp2, cmask
	ldi pushed, 1
	rjmp MAIN

;	Do nothing, return to main
letters:
	rjmp MAIN

;	Case for symbols
symbols:
;	Case for asterisk (*)
	cpi col, 0
	breq emergency

;	Case for zero
	cpi col, 1
	breq zero_case

;	Hash symbol, ignore it
	rjmp MAIN

emergency:
	clear_floor_reg floor_register
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	mov temp2, cmask
	ldi pushed, 1

	ldi temp1, 1
	st Z, temp1
	rjmp MAIN 

zero_case:
	ldi temp1, 1
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	st Z, temp1

	mov temp2, cmask
	ldi pushed, 1
	rjmp MAIN

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
	
;	Increment tempCounter
INCREMENT_TIMER:
;	increment tempCounter
	lds r24, tempCounter
	lds r25, tempCounter+1
	adiw r25:r24, 1

;	If it has been one second, inc secondCounter, clear tempCounter, store value of secondCounter
;	Otherwise store tempCounter value
	cpi r24, low(7812)
	ldi temp1, high(7812)
	cpc r25, temp1
	brne NOTSECOND
	
	clear_timer tempCounter
	lds r24, secondCounter
	inc r24
	sts secondCounter, r24

;	If elevator is opening doors	
	cpi ele_status, 2
	breq opening_doors
	
;	If elevator doors are open
	cpi ele_status, 3
	breq door_idle
	
;	If elevator doors are closing
	cpi ele_status, 4
	breq door_closing
	
;	If elevator is moving, we change the floor
	cpi ele_status, 1
	breq moving_elevator	

NOTSECOND:
	sts tempCounter, r24
	sts tempCounter+1, r25
	rjmp ENDIF		
	
;	If opening doors, check if it has been one second
;	If so, change ele_status to 3 (leave door open for three seconds)
opening_doors:
	cpi r24, 2
	breq to_idle
	rjmp ENDIF
	
to_idle:
	ldi ele_status, 2
	clear secondCounter
	rjmp ENDIF

;	If waiting for people to get in/out, check if it has been 3 seconds
;	If so, change ele_status to 4 (start closing the door)
door_idle:
	cpi r24, 3
	breq to_close
	rjmp ENDIF

to_close:
	ldi ele_status, 4
	clear secondCounter
	rjmp ENDIF

;	If closing doors, check if it has been one second
;	If so, change ele_status to 0 (elevator idle) and drop the current floor from the floor_register	
door_closing:
	cpi r24, 1
	breq door_closed
	rjmp ENDIF
	
door_closed:
	ldi ele_status, 0
	clear secondCounter
	jmp drop_floor
	
;	If it has been two seconds, we change the floor
;	Otherwise we end the timer
moving_elevator:
	cpi r24, 2
	breq change_floor
	rjmp ENDIF
change_floor:
	cpi dir, 1
	breq change_floor_u
	rjmp change_floor_d
change_floor_u:
	inc curr_floor
	clear secondCounter
	cp curr_floor, next_floor
	breq set_to_open
	rjmp ENDIF
change_floor_d:
	dec curr_floor
	clear secondCounter
	cp curr_floor, next_floor
	breq set_to_open
	rjmp ENDIF

set_to_open:
	ldi ele_status, 2
	rjmp ENDIF
	
;	If we have closed the doors, we want to drop the floor we stopped at
;	from the floor_register
drop_floor:
	ldi ZL, low(floor_register)
	ldi ZH, high(floor_register)
	ldi temp1, 0
iterate_drop:
	cp temp1, curr_floor
	breq drop_me
	
	inc temp1
	adiw ZH:ZL, 1
	jmp iterate_drop
drop_me:
	ldi temp2, 0
	st Z, temp2
	
	
;	return from timer	
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
	
;;;;;;	Experimental!!
;	Interrupt triggered by push button
;	Changes elevator door from waiting while open to closing
EXT_INT0:
	push temp1
	in temp1, SREG
	push temp1
	
	cpi ele_status, 2
	breq skip_idle
	
	jmp EXIT_THIS

skip_idle:
	ldi ele_status, 3
	rjmp EXIT_THIS

EXIT_THIS:
	pop temp1
	out SREG, temp1
	pop temp1
	reti
;;;;;;	Experimental!!
	

