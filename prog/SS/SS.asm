.include "8515def.inc" ;���� ����������� AT90S8515

.def temp = R16	;��������� �����

.def time_extra = R20	;�������������� ������� ������� 1
.def time_seconds = R21 ;�������������� ������� ������� 2
.def time_minutes = R22 ;�������������� ������� ������� 3 
.def time_hours = R23 	;�������������� ������� ������� 4 

.def XTALL = 1000000 ;�������� ������� � ������
.def BAUD = 9600 ;�������� ������ ������� � ���/���
.def SPEED = (XTALL/(16*BAUD))-1 ;����������� ������� ��� ���������
								 ;������� �������� ������



.org $000
	rjmp INIT
.org $007
	rjmp TIME0_OVER


.org $020
INIT:
	ldi temp,$5F ;���������
	out SPL,temp ;��������� �����
	ldi temp,$02 ;�� ���������
	out SPH,temp ;������ ���

	ldi temp, hight(SPEED)
	out UBRRH, temp
	ldi temp, low(SPEED)
	out UB


	ser temp			;������������� ����� A �� �����
	out DDRA, temp
	clr temp
	out PORTA, temp
	
	ldi temp, (1<<TOIE0) ;��������� ���������� �� ������������ �������� T0
	out TIMSK, temp
	
	ldi temp, 131	;��������� ����������
	out TCNT0, temp ;�������� �������� T0
	ldi time_extra, 131 ;��������� ���������� � �������������� ������� �������

	ldi time_seconds, 0
	ldi time_minutes, 0
	ldi time_hours, 0


	ldi temp, (0<<CS02|0<<CS01|1<<CS00) ;������������ ������� T0 ����� 64 (�� ������ 1)
	out TCCR0, temp						;������ �������� T0
	
	sei	;���������� ����������

MAIN:
	rjmp MAIN
	
TIME0_OVER:
	ldi temp, 131	;��������� ������ ������ 
	out TCNT0, temp ;��� �������� T0

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

	



