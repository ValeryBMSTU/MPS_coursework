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
.def counter2 = R26 ;�������������� ������� ��� ������

.def a_status = R1 ;������� �������� �������� ��������� �� ����� A


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
	

	rjmp 	main


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
	rcall 	set_bit_temp2
	or 		actual_device_statuses, temp2	;������ �������� �������������


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
	ldi 	counter2, 1
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

	



