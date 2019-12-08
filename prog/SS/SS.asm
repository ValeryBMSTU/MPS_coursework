;.include "8515def.inc" ;���� ����������� AT90S8515
.include "m8515def.inc" ;���� ����������� ATmega8515

.def temp = R16	;��������� �����

.def time_extra = R20	;�������������� ������� ������� 1
.def time_seconds = R21 ;�������������� ������� ������� 2
.def time_minutes = R22 ;�������������� ������� ������� 3 
.def time_hours = R23 	;�������������� ������� ������� 4 

.equ	XTALL	=8000000				;�������� ������� � ������
.equ	BAUD	=9600					;�������� ������ ������� � ���/�
.equ	SPEED	=(XTALL/(16*BAUD))-1	;���������� ������� ��� ��������� 
										;������� �������� ������



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

	ldi temp, (1<<CS02|0<<CS01|1<<CS00) ;������������ ������� T0 ����� 64 (������ 1)
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
	mov		temp, R1
	out 	PORTA, temp
	rjmp 	main


		
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

recieve_schedule:
	rcall	in_com		;��������� ������
	mov 	R1, temp	;��������� ����� ���������� (���� ����� 1 ��� = 1 ����������) 
	rcall 	in_com
	mov 	R2, temp	;��������� ���� ������ ������
	rcall 	in_com
	mov		R3, temp	;��������� ������ ������ ������
	rcall 	in_com
	mov 	R4, temp	;��������� ������� ������ ������
	ret

;#### �������� ����� ����� UART ####
out_com:	
	sbis	UCSRA,UDRE	;��������, ����� ��� UDRE 
	rjmp	out_com		;����� ���������� � 1 (���������� ���� ���������) 
	out		UDR,temp	;���������� ����
	ret

;#### ����� ����� ����� UART ####
in_com:		
	sbis	UCSRA,RXC	;��������, ����� ��� RXC ����� ���������� � 1 
	rjmp	in_com		;(� �������� ������ ���� �������� ������������� ����) 
	in		temp,UDR	;��������� �������� ����
	ret

	rjmp MAIN
	
TIME0_OVER:
	ldi temp, 6	;��������� ������ ������ 
	out TCNT0, temp ;��� �������� T0 (��� 9 ���)

	inc time_extra
	cpi time_extra, 0
	brne time0_continue

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

	



