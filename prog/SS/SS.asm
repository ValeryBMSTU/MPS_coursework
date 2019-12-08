;.include "8515def.inc" ;Файл определений AT90S8515
.include "m8515def.inc" ;файл определений ATmega8515

.def temp = R16	;Временный буфер

.def time_extra = R20	;Дополнительный регистр времени 1
.def time_seconds = R21 ;Дополнительный регистр времени 2
.def time_minutes = R22 ;Дополнительный регистр времени 3 
.def time_hours = R23 	;Дополнительный регистр времени 4 

.equ	XTALL	=8000000				;Тактовая частота в ГЕРЦАХ
.equ	BAUD	=9600					;Скорость обмена данными в бит/с
.equ	SPEED	=(XTALL/(16*BAUD))-1	;Коэфициент деления для получения 
										;заданой скорости обмена



.org $000
	rjmp INIT
.org $007
	rjmp TIME0_OVER


.org $020
INIT:
	;Настройка стека
	ldi temp,$5F ;Установка
	out SPL,temp ;указателя стека
	ldi temp,$02 ;на последнюю
	out SPH,temp ;ячейку ОЗУ

	;Настройка UART
	ldi temp, high(SPEED)	;Записть делителя
	out UBRRH, temp			;для задания
	ldi temp, low(SPEED)	;желаемой
	out UBRRL, temp			;скорости обмена

	ldi temp, (1<<UCSZ1|1<<UCSZ0) ;Выбор желаемого
	out UCSRC, temp				  ;размера слова данных 8 бит

	ldi temp, (1<<RXEN|1<<TXEN)	  ;Разрешение приема
	out UCSRB, temp				  ;и передачи

	;Настройка портов
	ser temp			;Инициализация порта A на выход
	out DDRA, temp
	clr temp
	out PORTA, temp
	
	;Настройка таймеров и прерываний
	cli	;Запрещаем прерывания

	ldi temp, (1<<TOIE0) ;Разрешить прерывание по переполнению счетчика T0
	out TIMSK, temp
	
	ldi temp, 6	;Установка начального
	out TCNT0, temp ;значения счетчика T0 (при 9 МГц)
	ldi time_extra, 131 ;Установка начального в дополнительный регистр времени

	ldi time_seconds, 0
	ldi time_minutes, 0
	ldi time_hours, 0

	ldi temp, (1<<CS02|0<<CS01|1<<CS00) ;Предделитель частоты T0 равен 64 (сейчас 1)
	out TCCR0, temp						;Запуск счетчика T0
	
	sei	;Разрешение прерываний

MAIN:
	sbis	UCSRA,RXC	;Ожидание, когда бит RXC будет установлен в 1 
	rjmp	skip_in		;(в регистре данных есть принятый непрочитанный байт) 

	cli		;Временно запрещаем прерывания
	in		temp, UDR	;Считываем принятый байт
	cpi 	temp, 0b00000000 ;Признак начала передачи нового расписания
	rcall 	recieve_schedule ;Начинаем принимать новое расписание
	rcall	ok_msg		;Говорим в ответ, что всё успешно приняли
	sei		;Вновь вкючаем все прерывания
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
	ldi		temp,0x0A	;"ПЕРЕВОД СТРОКИ" Перевод курсора на строку ниже
	rcall	out_com
	ldi		temp,0x0D	;"ВОЗВРАТ КАРЕТКИ" Переход на начало текущей строки
	rcall	out_com
	ret

recieve_schedule:
	rcall	in_com		;Считываем данные
	mov 	R1, temp	;Считываем номер устройства (Пока пусть 1 бит = 1 устройство) 
	rcall 	in_com
	mov 	R2, temp	;Считываем часы начала работы
	rcall 	in_com
	mov		R3, temp	;Считываем минуты начала работы
	rcall 	in_com
	mov 	R4, temp	;Считываем секунды начала работы
	ret

;#### ОТПРАВКА БАЙТА ЧЕРЕЗ UART ####
out_com:	
	sbis	UCSRA,UDRE	;Ожидание, когда бит UDRE 
	rjmp	out_com		;будет установлен в 1 (предыдущий байт отправлен) 
	out		UDR,temp	;Отправляем байт
	ret

;#### ПРИЕМ БАЙТА ЧЕРЕЗ UART ####
in_com:		
	sbis	UCSRA,RXC	;Ожидание, когда бит RXC будет установлен в 1 
	rjmp	in_com		;(в регистре данных есть принятый непрочитанный байт) 
	in		temp,UDR	;Считываем принятый байт
	ret

	rjmp MAIN
	
TIME0_OVER:
	ldi temp, 6	;Установка начала отчета 
	out TCNT0, temp ;для счетчика T0 (при 9 МГц)

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

	



