.include "m2560def.inc"
.def curr_floor = r15				; 0-9 indicates floor
.def next_floor = r14				; 0-9 indicates next floor to move to
.def temp1 = r16
.def temp2 = r17

.def row = r18
.def col = r19
.def rmask = r20
.def cmask = r21

.def pushed = r22
.def dir = r23
.def ele_status = r24				; elevator status, 0 = idle, 1 = moving, 2 = doors opening, 3 = doors idle, 4 = doors closing

.equ number_w = 0x30

.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F

.equ led_up = 0x01
.equ led_down = 0x10

.macro do_lcd_command
	ldi temp1, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	ldi temp1, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro do_lcd_data_alt
	mov temp1, @0
	ldi temp2, number_w
	add temp1, temp2
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro clear_floor_array
	ldi YL, low(floor_array)
	ldi YH, high(floor_array)
	clr temp1
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y+, r16
	st Y, r16
.endmacro

;	Clear tempCounter
.macro clear_tempCounter
	ldi YL, low(tempCounter)
	ldi YH, high(tempCounter)
	clr temp1
	st Y+, temp1
	st Y, temp1
.endmacro

;	Clear one byte values (secondCounter and store_pushed)
.macro clear
	ldi YL, low(@0)
	ldi YH, high(@0)
	clr temp1
	st Y, temp1
.endmacro

.macro print_stats
	do_lcd_command 0b00000001 	; clear display
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
	do_lcd_data 'N'
	do_lcd_data 'e'
	do_lcd_data 'x'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'F'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ':'
	do_lcd_data ' '
	do_lcd_data_alt next_floor
;	do_lcd_data ' '
;	do_lcd_data 'E'
;	do_lcd_data_alt ele_status
;	do_lcd_data 'D'
;	do_lcd_data_alt dir
.endmacro

.dseg
floor_array: .byte 10						; floor array, represents floors 0-9, one byte each
store_pushed: .byte 1						; stores cmask value to check if a button is being held
tempCounter: .byte 2						; tempCounter, counts to one second, does not exceed one second
secondCounter: .byte 1						; secondCounter, counts seconds tempCounter has done
led_pattern: .byte 1

.cseg
.org 0
	jmp RESET
.org INT0addr
	jmp EXT_INT0
.org OVF0addr
	jmp Timer0OVF
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;

RESET:
	ldi temp1, low(RAMEND)						; set up stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	
	clear_tempCounter 			; clear timers
	clear secondCounter

	clear_floor_array			; clears floor array
	clear store_pushed			; clears store_pushed
	
	ldi pushed, 0
	ldi dir, 1
	clr curr_floor
	clr next_floor
	clr ele_status 
	
;	Setup LCD, use portf, porta as output
	ser temp1
	out DDRC, temp1
	out DDRF, temp1
	out DDRA, temp1
	clr temp1
	out PORTF, temp1
	out PORTA, temp1

	ldi temp1, led_up
	sts led_pattern, temp1
	out PORTC, temp1
	
;	Setup LCD...
	do_lcd_command 0b00111000 ; matrix of 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; matrix of 2x5x7
	rcall sleep_1ms

	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001100 ; Cursor on, bar, no blink

	print_stats
		
;	Setup pull up register
	ldi temp1, PORTLDIR			; load temp1 with 1111 0000
	sts DDRL, temp1				; store into pinL
	
;	Setup external interrupt
	ldi temp1, (2 << ISC00)
	sts EICRA, temp1
	in temp1, EIMSK
	ori temp1, (1<<INT0)
	out EIMSK, temp1	

;	Setup timer interrupt	
	ldi temp1, 0b00000000
	out TCCR0A, temp1
	ldi temp1, 0b00000010
	out TCCR0B, temp1
	ldi temp1, 1 << TOIE0
	sts TIMSK0, temp1
	sei
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;	
	
MAIN:
	cpi dir, 2
	breq START_EMERGENCY
	cpi ele_status, 2
	brlt FIND_NEXT_FLOOR
	jmp CHECK_ELEVATOR

;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;	

START_EMERGENCY:
	ldi temp1, 0
	cp curr_floor, temp1
	breq ALREADY_EMERGENCY_FLOOR
	jmp EMERGENCY_MAIN	

ALREADY_EMERGENCY_FLOOR:
	ldi ele_status, 2
	jmp CHECK_ELEVATOR	

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
		
FIND_NEXT_FLOOR:
	ldi ZH, high(floor_array)
	ldi ZL, low(floor_array)
	
	ldi r27, 0						; store current floor iteration
	ldi temp1, 10
	ldi temp2, 0
	ldi col, 2						; borrow this register, use to indicate elevator direction change
	
CHECK_FLOOR:
	ld row, Z+
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
	breq check_next_floor_d
	
	cpi col, 1
	breq check_next_floor_u
	
	jmp CHECK_ELEVATOR

check_next_floor_u:
	cp next_floor, temp1
	breq CHECK_ELEVATOR

	jmp change_next_floor_u

check_next_floor_d:
	cp next_floor, temp2
	breq CHECK_ELEVATOR
	
	jmp change_next_floor_d

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
CHECK_ELEVATOR:
	lds r28, secondCounter
			
	cpi ele_status, 2
	breq DOOR_OPENING
	
	cpi ele_status, 3
	breq DOOR_IDLE
	
	cpi ele_status, 4
	breq DOOR_CLOSING
	
	cpi ele_status, 1
	breq MOVE_ELEVATOR
	
	jmp END_THIS
	
DOOR_OPENING:
	cpi r28, 1
	breq to_door_idle
	jmp END_THIS

to_door_idle:
	ldi ele_status, 3
	clear secondCounter
	jmp END_THIS	

DOOR_IDLE:
	cpi r28, 3
	breq to_door_closing
	jmp END_THIS	

to_door_closing:
	ldi ele_status, 4
	clear secondCounter
	jmp END_THIS
	
DOOR_CLOSING:
	cpi r28, 1
	breq to_elevator_idle
	jmp END_THIS

to_elevator_idle:
	ldi ele_status, 0
	clear secondCounter

	cpi dir, 2
	breq emergency_state
	jmp drop_floor
emergency_state:
	jmp END_THIS


MOVE_ELEVATOR:
	cpi r28, 2
	breq change_floor
	jmp END_THIS
	
change_floor:
	clear secondCounter
	cpi dir, 1
	breq change_floor_u
	jmp change_floor_d

;	Increment/Decrement curr floor
change_floor_u:
	inc curr_floor
	cp curr_floor, next_floor
	breq to_open_doors
	jmp END_THIS_ALT
		
change_floor_d:
	dec curr_floor
	cp curr_floor, next_floor
	breq to_open_doors
	JMP END_THIS_ALT

to_open_doors:
	ldi ele_status, 2
	jmp END_THIS_ALT

drop_floor:
	ldi ZL, low(floor_array)
	ldi ZH, high(floor_array)
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
	jmp END_THIS
	
END_THIS_ALT:
	print_stats

END_THIS:	
	cpi dir, 2
	breq back_to_emergency
	
	cpi pushed, 1
	breq HOLD
	
	jmp SCAN
	
back_to_emergency:
	jmp EMERGENCY_MAIN	

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;	Put this here to avoid branch out of reach
HOLD:
	lds temp2, store_pushed
	sts PORTL, temp2
	lds temp1, PINL
	andi temp1, ROWMASK
	cpi temp1, 0xF
	breq RELEASE
	jmp MAIN
RELEASE:
	clear store_pushed
	ldi pushed, 0
	jmp MAIN	

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;


;	Put this here to avoid branch out of reach...
change_next_floor_u:
	mov next_floor, temp1
	ldi dir, 1
	ldi ele_status, 1
	print_stats
	jmp CHECK_ELEVATOR

change_next_floor_d:
	mov next_floor, temp2
	ldi dir, 0
	ldi ele_status, 1
	print_stats
	jmp CHECK_ELEVATOR

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;


EMERGENCY_MAIN:
	ldi temp1, 0
	cp curr_floor, temp1
	breq EMERGENCY_STOP
	
	cpi ele_status, 2
	brlt EMERGENCY_MOVE

	ldi ele_status, 4
	jmp CHECK_ELEVATOR

EMERGENCY_MOVE:
	ldi ele_status, 1
	jmp CHECK_ELEVATOR	
	
EMERGENCY_STOP:
	cpi ele_status, 0
	breq EMERGENCY_IDLE
	
	jmp CHECK_ELEVATOR	
	
EMERGENCY_IDLE:
	do_lcd_command 0b00000001 ; clear display
	do_lcd_data 'E'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'c'
	do_lcd_data 'y'
	do_lcd_command 0b11000000 	; set address to second line
	do_lcd_data 'C'
	do_lcd_data 'a'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data ' '
	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'
EMERGENCY_WAIT:
	lds temp2, store_pushed
	sts PORTL, temp2
	lds temp1, PINL
	andi temp1, ROWMASK
	cpi temp1, 0xF
	breq EMERGENCY_WAIT				; if column not pushed, repeat above code

	ldi rmask, 0b00001000
	mov temp2, temp1
	and temp2, rmask				; if column and row being pushed, end
	breq EMERGENCY_FINISH

	jmp EMERGENCY_WAIT
EMERGENCY_FINISH:
	ldi dir, 1
	clr curr_floor
	clr next_floor
	clr ele_status
	clear_tempCounter
	clear secondCounter

	print_stats
	jmp HOLD

;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;		

SCAN:
	ldi cmask, INITCOLMASK
	clr col
		
	jmp colloop
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;	


BACK_TO_MAIN:
	jmp MAIN

colloop:
	cpi col, 4
	breq BACK_TO_MAIN
	
	sts PORTL, cmask
	ldi temp1, 0xFF
	
delay:
	dec temp1
	brne delay

	lds temp1, PINL				; read port L
	andi temp1, ROWMASK
	cpi temp1, 0xF				; check if row is high (i.e. nothing pressed)
	breq nextcol

	ldi temp2, 0xFF

delay2:							; slow scan operation
	dec temp2
	nop
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
	cpi col, 3
	breq letters

	cpi row, 3
	breq symbols

	mov temp1, row
	lsl temp1					; number pressed = row*3 + col + 1
	add temp1, row
	add temp1, col
	inc temp1
	
	ldi ZH, high(floor_array)
	ldi ZL, low(floor_array)
find_placement:
	cpi temp1, 0
	breq store_val
	
	dec temp1
	adiw ZH:ZL, 1
	jmp find_placement
store_val:
	ldi temp1, 1
	st Z, temp1
	
	sts store_pushed, cmask
	ldi pushed, 1
	jmp MAIN
	
letters:
	jmp MAIN
	
symbols:
	cpi col, 0
	breq emergency_case

	cpi col, 1
	breq zero_case
	
	jmp MAIN

emergency_case:
	clr next_floor
	ldi dir, 2
	ldi pushed, 1
	clear_floor_array
	clear secondCounter
	sts store_pushed, cmask
	mov temp2, cmask
	do_lcd_data '*'
	jmp EMERGENCY_HOLD

EMERGENCY_HOLD:
;	do_lcd_data 'A'
	sts PORTL, temp2
	nop
	nop
	lds temp1, PINL
	andi temp1, ROWMASK
	cpi temp1, 0xF
	breq EMERGENCY_RELEASE
	jmp EMERGENCY_HOLD
EMERGENCY_RELEASE:
	jmp START_EMERGENCY

zero_case:
	ldi ZH, high(floor_array)
	ldi ZL, low(floor_array)
	ldi temp1, 1
	st Z, temp1
	
	sts store_pushed, cmask
	ldi pushed, 1
	rjmp MAIN
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
Timer0OVF:
	push temp1
	in temp1, SREG
	push temp1
	push ele_status
	push r24
	push r25
	push r28
	push r29

	cpi ele_status, 0
	breq ENDIF
	
	lds r28, tempCounter
	lds r29, tempCounter+1
	adiw r29:r28, 1

	cpi r28, low(7812)
	ldi temp1, high(7812)
	cpc r29, temp1
	breq ONESECOND

	jmp NOTSECOND

ONESECOND:
	clear_tempCounter
	lds r28, secondCounter
	inc r28
	sts secondCounter, r28
	rjmp ENDIF
	
NOTSECOND:
	sts tempCounter, r28
	sts tempCounter+1, r29

ENDIF:
	pop r29
	pop r28
	pop r25
	pop r24
	pop ele_status
	pop temp1
	out SREG, temp1
	pop temp1
	reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;

EXT_INT0:
	push temp1
	in temp1, SREG
	push temp1

	cpi ele_status, 3
	breq interrupt_door_idle

	jmp END_EXT_INT0

interrupt_door_idle:
	clear_tempCounter
	clear secondCounter
	ldi ele_status, 4
	
END_EXT_INT0:
	pop temp1
	out SREG, temp1
	pop temp1
	reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
end:
	rjmp end	

	
;Don't run this code
;------------------------------------------

	
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
	out PORTF, temp1
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret
	
lcd_data:
	out PORTF, temp1
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret
	
lcd_wait:
	push temp1
	clr temp1
	out DDRF, temp1
	out PORTF, temp1
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in temp1, PINF
	lcd_clr LCD_E
	sbrc temp1, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser temp1
	out DDRF, temp1
	pop temp1
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

	
	
