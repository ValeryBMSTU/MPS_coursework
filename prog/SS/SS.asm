;.include "8515def.inc" ;���� ����������� AT90S8515
.include "m8515def.inc" ;���� ����������� ATmega8515

.def temp = R16		;��������� �����
.def counter = R17 	;������� ��� ������
.def on_off = R18 	;������� ����, ��� ����� ��������� (1)
				  	;��� ��������� (0) ���������� 
.def device_number = R19 ;����� ����������, �������
						 ;���������� ��������/���������
.def actual_device_statuses = R24 ;���������� ����������, ���
							;������� ��� �������� ��������� ���������
.def temp2 = R25	;�������������� ��������� �����

.def a_status = R1 ;������� �������� �������� ��������� �� ����� A
.def counter2 = R2 ;�������������� ������� ��� ������
.def flag = R3 ;��������������� ���� ��� ��������� ���������
.def force_devices = R4 ;������� ���������, ���������� � �������������� ������
.def ascii_numbers_start = R5


.def time_extra = R20	;�������������� ������� ������� 1
.def time_seconds = R21 ;�������������� ������� ������� 2
.def time_minutes = R22 ;�������������� ������� ������� 3 
.def time_hours = R23 	;�������������� ������� ������� 4 

.equ	XTALL	=8000000				;�������� ������� � ������
.equ	BAUD	=9600					;�������� ������ ������� � ���/�
.equ	SPEED	=(XTALL/(16*BAUD))-1	;���������� ������� ��� ��������� 
										;������� �������� ������

.dseg
.org $060

schedule_count: .byte 1
schedule_start:	.byte 1

.cseg
.org $000
	rjmp INIT
.org $007
	rjmp TIME0_OVER


.org $020
INIT:
	;��������� �����
	ldi temp,$5F ;���������
	out SPL,temp ;��������� �����
	ldi temp,$02 ;�� ���������
	out SPH,temp ;������ ���

	;��������� UART
	ldi temp, high(SPEED)	;������� ��������
	out UBRRH, temp			;��� �������
	ldi temp, low(SPEED)	;��������
	out UBRRL, temp			;�������� ������

	ldi temp, (1<<UCSZ1|1<<UCSZ0) ;����� ���������
	out UCSRC, temp				  ;������� ����� ������ 8 ���

	ldi temp, (1<<RXEN|1<<TXEN)	  ;���������� ������
	out UCSRB, temp				  ;� ��������

	;��������� ������
	ser temp			;������������� ����� A �� �����
	out DDRA, temp
	clr temp
	out PORTA, temp

	ser temp			;������������� ����� B �� �����
	out DDRB, temp
	clr temp
	out PORTB, temp

	ldi temp, 28		;������������� ������� PD2,PD3,PD4 �� �����
	out	DDRD, temp
	

	;��������� �������
	cbi PORTD, 2
	cbi PORTD, 3
	sbi PORTD, 4
	rcall DELAY
	ldi temp, 0b00001100
	out PORTB, temp
	cbi PORTD, 4
	rcall DELAY
	sbi PORTD, 4
	rcall DELAY
	ldi temp, 0b00000001
	out PORTB, temp
	cbi PORTD, 4
	sbi PORTD, 4
	rcall DELAY

	;�������� ������ "0"
	;sbi PORTD, 2
	;rcall DELAY
	;ldi temp, 0b00110000
	;out PORTB, temp
	;cbi PORTD, 4
	;rcall DELAY
	;sbi PORTD, 4



	ldi temp, 0b11110000
	out DDRC, temp ;�������������� PC0-3 �� ����, PC4-7 �� �����
	ldi temp, 0b00001111
	out PORTC, temp ;������ 0 �� ����� PC4-7 �
					;���������� ������������� ��������� �� ����� PC0-3
	
	;��������� �������� � ����������
	cli	;��������� ����������

	ldi temp, (1<<TOIE0) ;��������� ���������� �� ������������ �������� T0
	out TIMSK, temp
	
	ldi temp, 6	;��������� ����������
	out TCNT0, temp ;�������� �������� T0 (��� 9 ���)
	ldi time_extra, 131 ;��������� ���������� � �������������� ������� �������

	ldi time_seconds, 0
	ldi time_minutes, 0
	ldi time_hours, 0

	ldi temp, (1<<CS02|0<<CS01|0<<CS00) ;������������ ������� T0 ����� 256
	out TCCR0, temp						;������ �������� T0
	
	sei	;���������� ����������

MAIN:
	sbis	UCSRA,RXC	;��������, ����� ��� RXC ����� ���������� � 1 
	rjmp	skip_in		;(� �������� ������ ���� �������� ������������� ����) 

	cli		;�������� ��������� ����������
	in		temp, UDR	;��������� �������� ����
	cpi 	temp, 0b00000000 ;������� ������ �������� ������ ����������
	rcall 	recieve_schedule ;�������� ��������� ����� ����������
	rcall	ok_msg		;������� � �����, ��� �� ������� �������
	sei		;����� ������� ��� ����������
	rjmp	main

skip_in:
	;mov	temp, R1
	;out 	PORTA, temp
	rcall 	out_schedule
	rcall 	check_klava
	rcall   display
	rcall 	DELAY

	rjmp 	main	




DELAY:
; Delay 800 000 cycles (0.1 ������� ��������
; ��� ���������� �������� �� ��������� �
; �������� ��� 8.0 MHz)

    ldi  	r18, 5
    ldi  	r19, 15
    ldi  	r17, 242
L1: dec  	r17
    brne 	L1
    dec  	r19
    brne 	L1
    dec  	r18
    brne 	L1
	ret

LOW_DELAY:
    ldi  	r17, 250
L2: dec  	r17
    brne 	L2
	ret

display:
	cli

	cbi PORTD, 2
	rcall LOW_DELAY
	ldi temp,0b00000001
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	sbi	PORTD, 2
	rcall LOW_DELAY

	cbi PORTD, 2
	rcall LOW_DELAY
	ldi temp,0b00010100
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	sbi	PORTD, 2

	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	
	ldi temp, 0x30
	mov ascii_numbers_start, temp

	clr temp2
	mov temp, time_hours

hours_cicle:
	cpi temp, 10.
	brlo out_hours
	inc temp2
	subi temp, 10
	rjmp hours_cicle

out_hours:
	add temp2, ascii_numbers_start
	out PORTB, temp2
	rcall LOW_DELAY
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	rcall LOW_DELAY

`	add temp, ascii_numbers_start
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	rcall LOW_DELAY
	

	sei
	nop
	nop
	nop
	cli

	cbi PORTD, 2
	rcall LOW_DELAY
	ldi temp,0b00010100
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	sbi	PORTD, 2


	clr temp2
	mov temp, time_minutes

minutes_cicle:
	cpi temp, 10.
	brlo out_minutes
	inc temp2
	subi temp, 10
	rjmp minutes_cicle

out_minutes:
	add temp2, ascii_numbers_start
	out PORTB, temp2
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	rcall LOW_DELAY

	add temp, ascii_numbers_start
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	rcall LOW_DELAY

	sei
	nop
	nop
	nop
	cli

	cbi PORTD, 2
	rcall LOW_DELAY
	ldi temp,0b00010100
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	sbi	PORTD, 2

	clr temp2
	mov temp, time_seconds

seconds_cicle:
	cpi temp, 10.
	brlo out_seconds
	inc temp2
	subi temp, 10
	rjmp seconds_cicle

out_seconds:
	add temp2, ascii_numbers_start
	out PORTB, temp2
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	rcall LOW_DELAY

	add temp, ascii_numbers_start
	out PORTB, temp
	cbi PORTD, 4
	rcall LOW_DELAY
	sbi PORTD, 4
	rcall LOW_DELAY

	sei
	ret



;#### ��������� ������ ��������� ���������� ####
check_klava:
	ldi temp, 0
	ldi temp, 0b00011111
	out PORTC, temp

	sbic PINC, 3
	rcall RESTART

	ldi temp, (1<<5)
	out PORTC, temp

	sbic PINC, 3
	rcall SDS

	ldi temp, (1<<6)
	out PORTC, temp

	sbic PINC, 3
	rcall SDT

	ldi temp, (1<<7)
	out PORTC, temp

	sbic PINC, 0
	rcall FON
	sbic PINC, 1
	rcall FOFF
	sbic PINC, 2
	rcall GSS
	sbic PINC, 3
	rcall GST

	ret

RESTART:
	sbic PINC, 3
	rjmp RESTART
	ldi	temp, 0
	mov force_devices, temp
	ret

SDS:
	cli
	sbic PINC, 3
	rjmp SDS

	ldi		XL, low(schedule_count)
	ldi		XH, high(schedule_count)
	ldi		temp, 16	;16 ������� �� ���������
	st		X, temp		;(�� 2 ��� ������� ����������

	ldi		temp, 129	;1
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������

	ldi		temp, 130	;2
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 131	;3
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 132	;4
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 133	;5
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 134	;6
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������	
		
	ldi		temp, 135	;7
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 136	;8
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 12
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������


	ldi		temp, 1		;1
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������

	ldi		temp, 2		;2
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 3		;3
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 4		;4
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 5		;5
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 6		;6
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������	
		
	ldi		temp, 7		;7
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������
	
	ldi		temp, 8		;8
	st 		Y+, temp	;���������, ������������ ����������
	ldi		temp, 18
	st 		Y+, temp	;���� ������ ������
	ldi		temp, 0
	st		Y+, temp	;������ ������ ������
	ldi		temp, 0
	st 		Y+, temp	;������� ������ ������

	ldi		temp,'O'
	rcall	out_com
	ldi		temp,'N'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'i'
	rcall	out_com
	ldi		temp,'n'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'1'
	rcall	out_com
	ldi		temp,'2'
	rcall	out_com
	ldi		temp,':'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'a'
	rcall	out_com
	ldi		temp,'n'
	rcall	out_com
	ldi		temp,'d'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'o'
	rcall	out_com
	ldi		temp,'f'
	rcall	out_com
	ldi		temp,'f'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'i'
	rcall	out_com
	ldi		temp,'n'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'1'
	rcall	out_com
	ldi		temp,'8'
	rcall	out_com
	ldi		temp,':'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,0x0A	;"������� ������" ������� ������� �� ������ ����
	rcall	out_com
	ldi		temp,0x0D	;"������� �������" ������� �� ������ ������� ������
	rcall	out_com

	sei
	ret

SDT:
	cli
	sbic PINC, 3
	rjmp SDT

	ldi time_seconds, 0
	ldi time_minutes, 30
	ldi time_hours, 12

	ldi		temp,'S'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'t'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'d'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'d'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'f'
	rcall	out_com
	ldi		temp,'a'
	rcall	out_com
	ldi		temp,'u'
	rcall	out_com
	ldi		temp,'t'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'t'
	rcall	out_com
	ldi		temp,'i'
	rcall	out_com
	ldi		temp,'m'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,':'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'1'
	rcall	out_com
	ldi		temp,'2'
	rcall	out_com
	ldi		temp,':'
	rcall	out_com
	ldi		temp,'3'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,':'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,'0'
	rcall	out_com
	ldi		temp,0x0A	;"������� ������" ������� ������� �� ������ ����
	rcall	out_com
	ldi		temp,0x0D	;"������� �������" ������� �� ������ ������� ������
	rcall	out_com

	sei
	ret

FON:
	cli

	ldi temp, 0
	mov flag, temp

fon_cicle:
	ldi temp, (1<<4)
	out PORTC, temp

	sbic PINC, 0
	rcall ON_SEVEN
	sbic PINC, 1
	rcall ON_FOUR
	sbic PINC, 2
	rcall ON_ONE
	sbic PINC, 3
	rcall CANSEL

	ldi temp, (1<<5)
	out PORTC, temp

	sbic PINC, 0
	rcall ON_EIGHT
	sbic PINC, 1
	rcall ON_FIVE
	sbic PINC, 2
	rcall ON_TWO

	ldi temp, (1<<6)
	out PORTC, temp

	sbic PINC, 0
	rcall ON_ALL
	sbic PINC, 1
	rcall ON_SIX
	sbic PINC, 2
	rcall ON_THREE

	rcall 	DELAY

	mov	temp, flag
	cpi temp, 0
	breq fon_cicle

	sei
	ret

ON_ONE:
	sbic PINC, 2
	rjmp ON_ONE

	ldi temp, (1<<0)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_TWO:
	sbic PINC, 2
	rjmp ON_TWO

	ldi temp, (1<<1)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_THREE:
	sbic PINC, 2
	rjmp ON_THREE

	ldi temp, (1<<2)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_FOUR:
	sbic PINC, 1
	rjmp ON_FOUR

	ldi temp, (1<<3)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_FIVE:
	sbic PINC, 1
	rjmp ON_FIVE
	ldi temp, (1<<4)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_SIX:
	sbic PINC, 1
	rjmp ON_SIX

	ldi temp, (1<<5)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_SEVEN:
	sbic PINC, 0
	rjmp ON_SEVEN

	ldi temp, (1<<6)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_EIGHT:
	sbic PINC, 0
	rjmp ON_EIGHT

	ldi temp, (1<<7)
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret
ON_ALL:
	sbic PINC, 0
	rjmp ON_ALL

	ldi temp, 255
	or	a_status, temp
	or  force_devices, temp
	out PORTA, a_status
	mov	flag, temp
	ret

CANSEL:
	sbic PINC, 3
	rjmp CANSEL
	ldi temp, 255
	mov flag, temp
	ret


FOFF:
	cli


	ldi temp, 0
	mov flag, temp

foff_cicle:
	ldi temp, (1<<4)
	out PORTC, temp

	sbic PINC, 0
	rcall OFF_SEVEN
	sbic PINC, 1
	rcall OFF_FOUR
	sbic PINC, 2
	rcall OFF_ONE
	sbic PINC, 3
	rcall CANSEL

	ldi temp, (1<<5)
	out PORTC, temp

	sbic PINC, 0
	rcall OFF_EIGHT
	sbic PINC, 1
	rcall OFF_FIVE
	sbic PINC, 2
	rcall OFF_TWO

	ldi temp, (1<<6)
	out PORTC, temp

	sbic PINC, 0
	rcall OFF_ALL
	sbic PINC, 1
	rcall OFF_SIX
	sbic PINC, 2
	rcall OFF_THREE

	rcall 	DELAY

	mov	temp, flag
	cpi temp, 0
	breq foff_cicle

	rcall 	DELAY

	sei
	ret

OFF_ONE:
	sbic PINC, 2
	rjmp OFF_ONE

	ldi temp, (1<<0)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_TWO:
	sbic PINC, 2
	rjmp OFF_TWO

	ldi temp, (1<<1)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_THREE:
	sbic PINC, 2
	rjmp OFF_THREE

	ldi temp, (1<<2)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_FOUR:
	sbic PINC, 1
	rjmp OFF_FOUR

	ldi temp, (1<<3)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_FIVE:
	sbic PINC, 1
	rjmp OFF_FIVE

	ldi temp, (1<<4)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_SIX:
	sbic PINC, 1
	rjmp OFF_SIX

	ldi temp, (1<<5)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_SEVEN:
	sbic PINC, 0
	rjmp OFF_SEVEN

	ldi temp, (1<<6)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_EIGHT:
	sbic PINC, 0
	rjmp OFF_EIGHT

	ldi temp, (1<<7)
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	mov	flag, temp
	ret
OFF_ALL:
	sbic PINC, 0
	rjmp OFF_ALL

	ldi temp, 255
	or  force_devices, temp
	com	temp
	and	a_status, temp
	out PORTA, a_status
	ldi temp, 1
	mov	flag, temp
	ret


GSS:
	cli
	sbic PINC, 2
	rjmp GSS

	ldi		temp,'N'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'d'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'n'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'w'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'s'
	rcall	out_com
	ldi		temp,'c'
	rcall	out_com
	ldi		temp,'h'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'d'
	rcall	out_com
	ldi		temp,'u'
	rcall	out_com
	ldi		temp,'l'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,0x0A	;"������� ������" ������� ������� �� ������ ����
	rcall	out_com
	ldi		temp,0x0D	;"������� �������" ������� �� ������ ������� ������
	rcall	out_com
	sei
	ret
GST:
	cli
	sbic PINC, 3
	rjmp GST

	ldi		temp,'N'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,'d'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'a'
	rcall	out_com
	ldi		temp,'c'
	rcall	out_com
	ldi		temp,'t'
	rcall	out_com
	ldi		temp,'u'
	rcall	out_com
	ldi		temp,'a'
	rcall	out_com
	ldi		temp,'l'
	rcall	out_com
	ldi		temp,' '
	rcall	out_com
	ldi		temp,'t'
	rcall	out_com
	ldi		temp,'i'
	rcall	out_com
	ldi		temp,'m'
	rcall	out_com
	ldi		temp,'e'
	rcall	out_com
	ldi		temp,0x0A	;"������� ������" ������� ������� �� ������ ����
	rcall	out_com
	ldi		temp,0x0D	;"������� �������" ������� �� ������ ������� ������
	rcall	out_com
	sei
	ret


;#### ��������� ���������� ������� ��������� ####
out_schedule:
	cli 	;�������� ��������� ����������
	ldi 	YL, low(schedule_start)
	ldi 	YH, high(schedule_start)
	ldi 	counter, 0
	in		temp, PORTA
	mov		a_status, temp	

next_time:	
	ldi		XL, low(schedule_count)
	ldi		XH, high(schedule_count)
	ld		temp, X
	cp		counter, temp
	breq 	end_out_schedule
	brsh	end_out_schedule
	inc		counter
	
	ldi		on_off, 0 	;�� ��������� ���������� ����� ���������
	ld		temp, Y+
	sbrc	temp, 7 	;���� ���������� �������� ����������  
	ldi 	on_off, 1	;�� ������������� �����. �������� � on_off

	andi	temp, 0b00001111	;���������� ����� ����������
	mov		device_number, temp	;������� ��������/���������
	
	;mov 	temp, device_number ;�������� ������ ���
	;rcall 	set_bit_temp2		;���������� � temp2
	;and		temp2, actual_device_statuses ;��������� �������� ��
										  ;������ ����������
	;cpi		temp2, 0  ;���� �� ����� ����, �� 
	;brne	skip_time ;������ ���������� ��������

	ld		temp, Y+
	cp		temp, time_hours ;��������� �� �����
	breq	next_minutes	 ;���� ���� �����, �� ��������� ������
	brsh	skip_MS		 	 ;���� temp ������ hours ��
							 ;��������� ������ � ������� � �� ��������� ������
	inc YL					 ;����������� ������� Y �� 2, �����
	inc YL					 ;��������� ����� �� ��������� ������
	rjmp	execute_device_status
	
next_minutes:
	ld		temp, Y+
	cp		temp, time_minutes ;��������� �� �������
	breq	next_seconds	 ;���� ������ �����, �� ��������� ������
	brsh	skip_S		 	 ;���� temp ������ minutes ��
							 ;��������� ������� � �� ��������� ������
	inc YL					 ;����������� ������� Y �� 1
	rjmp	execute_device_status

next_seconds:
	ld		temp, Y+
	cp		temp, time_seconds ;��������� �� ��������
	breq	execute_device_status
	brsh	next_time		;���� temp ������ seconds, ��
							;�� ��������� � ��������� ������ � �� ��������� ������
	rjmp	execute_device_status ;����� ������� ������ ����������

skip_time:
	inc		YL
`	inc 	YL
	inc 	YL
	rjmp 	next_time

skip_MS:
	inc 	YL
	inc 	YL
	rjmp 	next_time

skip_S:
	inc 	YL
	rjmp 	next_time

execute_device_status:
	mov 	temp, device_number
	rcall 	set_bit_temp2                   ;���������� ����� ���� ����������,
	or 		actual_device_statuses, temp2	;������ �������� �������������

	and		temp2, force_devices ;���� ��������� ���������� ��������� � �������������� ������
	cpi		temp2, 0				 ;�� ���������� ��� ���������� � ��������� �
	brne	next_time			 ;���������� ���������

	cpi 	on_off, 1 ;��������� ����� �� �������� ����������
	brne	SET_OFF ;���� �� �����, �� ���� ���������
	mov		temp, device_number ;������� � temp ����� �������� ����������
	rcall 	set_bit_temp2 ;������������� ������ ��� � temp2
	mov		temp, a_status ;������� � temp ���������� ��������� ����� A	
	or		temp, temp2 ;������������� 1 � ������ ���
	mov		a_status, temp ;������� �������� temp ������� � ���� A
	rjmp	next_time
SET_OFF:
	rcall 	set_bit_temp2 ;������������� ������ ��� � temp2
	mov		temp, a_status ;������� � temp ���������� ��������� ����� A	
	com		temp2		;����������� �������� � �������� temp2
	and		temp, temp2	;������������� 0 � ������ ���
	mov		a_status, temp	;������� �������� temp ������� � ���� A
	rjmp	next_time

end_out_schedule:
	mov		temp, a_status
	out		PORTA, temp
	sei		;����� ��������� ����������
	ret


;#### ��������� ��������� ���� � ���������� temp2 ####
set_bit_temp2:	
	ldi 	temp2, 1
	mov 	counter2, temp2
	cp 		counter2, temp
	breq	set_bit_end	

set_bit_cicle:
	lsl 	temp2
	inc 	counter2
	cp  	counter2, temp
	brne	set_bit_cicle 

set_bit_end:
	ret

;#### ��������� �������� ��������� OK ####
ok_msg:
	ldi		temp,'O'
	rcall	out_com
	ldi		temp,'K'
	rcall	out_com
	ldi		temp,0x0A	;"������� ������" ������� ������� �� ������ ����
	rcall	out_com
	ldi		temp,0x0D	;"������� �������" ������� �� ������ ������� ������
	rcall	out_com
	ret

;#### ��������� ������ ���������� ####
recieve_schedule:
	ldi		XL, low(schedule_count)
	ldi		XH, high(schedule_count)
	ldi 	YL, low(schedule_start)
	ldi 	YH, high(schedule_start)
	
	ldi		temp, 0		;������������� ���������� �������
	st		X, temp		;� ����

recieve_cicle:
	rcall	in_com		;��������� ������
	cpi 	temp, 0b11111111 ;������� ���������
	breq	end_recieve 	 ;�������� ����������
	
	st 		Y+, temp	;��������� ���������, ������������
	rcall 	in_com		;����� ���������� � ���������/���������� ���
	st 		Y+, temp	;��������� ���� ������ ������
	rcall 	in_com
	st		Y+, temp	;��������� ������ ������ ������
	rcall 	in_com
	st 		Y+, temp	;��������� ������� ������ ������
	
	ldi		XL, low(schedule_count)
	ldi		XH, high(schedule_count)
	ld		temp, X		;����������� ���������� ������� �� ������ ������
	inc		temp		;����������� ���������� �������
	st		X, temp		;���������� ���-�� ������� �� ������ X

	rjmp recieve_cicle

end_recieve:
	ret

;#### ��������� �������� ����� ����� UART ####
out_com:	
	sbis	UCSRA,UDRE	;��������, ����� ��� UDRE 
	rjmp	out_com		;����� ���������� � 1 (���������� ���� ���������) 
	out		UDR,temp	;���������� ����
	ret

;#### ��������� ����� ����� ����� UART ####
in_com:		
	sbis	UCSRA,RXC	;��������, ����� ��� RXC ����� ���������� � 1 
	rjmp	in_com		;(� �������� ������ ���� �������� ������������� ����) 
	in		temp,UDR	;��������� �������� ����
	ret
	


;#### ��������� ���������� ####

TIME0_OVER:
	ldi temp, 6	;��������� ������ ������ 
	out TCNT0, temp ;��� �������� T0 (��� 9 ���)

	inc time_extra
	cpi time_extra, 0
	brne time0_continue

	ldi time_extra, 131 ;��������� ���������� � �������������� ������� �������
	inc time_seconds
	cpi time_seconds, 60
	brne time0_continue

	ldi time_seconds, 0
	inc time_minutes
	cpi time_minutes, 60
	brne time0_continue
	
	ldi time_minutes, 0
	inc time_hours
	cpi time_hours, 24
	brne time0_continue

	ldi time_hours, 0
time0_continue:
	reti

	



