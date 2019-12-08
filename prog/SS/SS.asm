.include "8515def.inc" ;Файл определений AT90S8515

.def temp = R16	;Временный буфер

.def time_extra = R20	;Дополнительный регистр времени 1
.def time_seconds = R21 ;Дополнительный регистр времени 2
.def time_minutes = R22 ;Дополнительный регистр времени 3 
.def time_hours = R23 	;Дополнительный регистр времени 4 

.def XTALL = 1000000 ;Тактовая частота в герцах
.def BAUD = 9600 ;Скорость обмена данными в бит/сек
.def SPEED = (XTALL/(16*BAUD))-1 ;Коэффициент деления для получения
								 ;заданой скорости обмена



.org $000
	rjmp INIT
.org $007
	rjmp TIME0_OVER


.org $020
INIT:
	ldi temp,$5F ;Установка
	out SPL,temp ;указателя стека
	ldi temp,$02 ;на последнюю
	out SPH,temp ;ячейку ОЗУ

	ldi temp, hight(SPEED)
	out UBRRH, temp
	ldi temp, low(SPEED)
	out UB


	ser temp			;Инициализация порта A на выход
	out DDRA, temp
	clr temp
	out PORTA, temp
	
	ldi temp, (1<<TOIE0) ;Разрешить прерывание по переполнению счетчика T0
	out TIMSK, temp
	
	ldi temp, 131	;Установка начального
	out TCNT0, temp ;значения счетчика T0
	ldi time_extra, 131 ;Установка начального в дополнительный регистр времени

	ldi time_seconds, 0
	ldi time_minutes, 0
	ldi time_hours, 0


	ldi temp, (0<<CS02|0<<CS01|1<<CS00) ;Предделитель частоты T0 равен 64 (но сейчас 1)
	out TCCR0, temp						;Запуск счетчика T0
	
	sei	;Разрешение прерываний

MAIN:
	rjmp MAIN
	
TIME0_OVER:
	ldi temp, 131	;Установка начала отчета 
	out TCNT0, temp ;для счетчика T0

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

	



