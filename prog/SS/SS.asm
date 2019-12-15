;.include "8515def.inc" ;Файл определений AT90S8515
.include "m8515def.inc" ;файл определений ATmega8515

.def temp = R16		;Временный буфер
.def counter = R17 	;Счетчик для циклов
.def on_off = R18 	;Признак того, что нужно выключить (1)
				  	;или выключить (0) устройство 
.def device_number = R19 ;Номер устройства, которое
						 ;необзодимо включить/выключить
.def actual_device_statuses = R24 ;Отображает устройства, для
							;которых уже выведено актуально состояние
.def temp2 = R25	;Дополнительный временный буфер

.def a_status = R1 ;Регистр хранения статусов устройств на порте A
.def counter2 = R2 ;Дополнительный счетчик для циклов
.def flag = R3 ;Вспомогательынй флаг для различных признаков
.def force_devices = R4 ;Регистр устройств, запущенных в принудительном режиме
.def ascii_numbers_start = R5


.def time_extra = R20	;Дополнительный регистр времени 1
.def time_seconds = R21 ;Дополнительный регистр времени 2
.def time_minutes = R22 ;Дополнительный регистр времени 3 
.def time_hours = R23 	;Дополнительный регистр времени 4 

.equ	XTALL	=8000000				;Тактовая частота в ГЕРЦАХ
.equ	BAUD	=9600					;Скорость обмена данными в бит/с
.equ	SPEED	=(XTALL/(16*BAUD))-1	;Коэфициент деления для получения 
										;заданой скорости обмена

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

	ser temp			;Инициализация порта B на выход
	out DDRB, temp
	clr temp
	out PORTB, temp

	ldi temp, 28		;Инизиализация выводов PD2,PD3,PD4 на выход
	out	DDRD, temp
	

	;Настройка дисплея
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

	;Тестовая запись "0"
	;sbi PORTD, 2
	;rcall DELAY
	;ldi temp, 0b00110000
	;out PORTB, temp
	;cbi PORTD, 4
	;rcall DELAY
	;sbi PORTD, 4



	ldi temp, 0b11110000
	out DDRC, temp ;Инициализируем PC0-3 на вход, PC4-7 на выход
	ldi temp, 0b00001111
	out PORTC, temp ;Ставим 0 на пинах PC4-7 и
					;подключаем подтягивающие резисторы на порты PC0-3
	
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

	ldi temp, (1<<CS02|0<<CS01|0<<CS00) ;Предделитель частоты T0 равен 256
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
	;mov	temp, R1
	;out 	PORTA, temp
	rcall 	out_schedule
	rcall 	check_klava
	rcall   display
	rcall 	DELAY

	rjmp 	main	




DELAY:
; Delay 800 000 cycles (0.1 секунды задержка
; для уменьшение нагрузки на симуляцию в
; протеусе при 8.0 MHz)

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



;#### ПРОЦЕДУРА ОПРОСА МАТРИЧНОЙ КЛАВИАТУРЫ ####
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
	ldi		temp, 16	;16 записей по умолчанию
	st		X, temp		;(по 2 для каждого устройтсва

	ldi		temp, 129	;1
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы

	ldi		temp, 130	;2
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 131	;3
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 132	;4
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 133	;5
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 134	;6
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы	
		
	ldi		temp, 135	;7
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 136	;8
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 12
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы


	ldi		temp, 1		;1
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы

	ldi		temp, 2		;2
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 3		;3
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 4		;4
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 5		;5
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 6		;6
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы	
		
	ldi		temp, 7		;7
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы
	
	ldi		temp, 8		;8
	st 		Y+, temp	;заголовок, определяющий устройства
	ldi		temp, 18
	st 		Y+, temp	;часы начала работы
	ldi		temp, 0
	st		Y+, temp	;минуты начала работы
	ldi		temp, 0
	st 		Y+, temp	;секунды начала работы

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
	ldi		temp,0x0A	;"ПЕРЕВОД СТРОКИ" Перевод курсора на строку ниже
	rcall	out_com
	ldi		temp,0x0D	;"ВОЗВРАТ КАРЕТКИ" Переход на начало текущей строки
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
	ldi		temp,0x0A	;"ПЕРЕВОД СТРОКИ" Перевод курсора на строку ниже
	rcall	out_com
	ldi		temp,0x0D	;"ВОЗВРАТ КАРЕТКИ" Переход на начало текущей строки
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
	ldi		temp,0x0A	;"ПЕРЕВОД СТРОКИ" Перевод курсора на строку ниже
	rcall	out_com
	ldi		temp,0x0D	;"ВОЗВРАТ КАРЕТКИ" Переход на начало текущей строки
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
	ldi		temp,0x0A	;"ПЕРЕВОД СТРОКИ" Перевод курсора на строку ниже
	rcall	out_com
	ldi		temp,0x0D	;"ВОЗВРАТ КАРЕТКИ" Переход на начало текущей строки
	rcall	out_com
	sei
	ret


;#### ПРОЦЕДУРА ОБНОВЛЕНИЯ СТАТУСА УСТРОЙСТВ ####
out_schedule:
	cli 	;Временно запрещаем прерывания
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
	
	ldi		on_off, 0 	;По умолчанию устройство нужно выключить
	ld		temp, Y+
	sbrc	temp, 7 	;Если необходимо включить устройство  
	ldi 	on_off, 1	;то устанавливаем соотв. значение в on_off

	andi	temp, 0b00001111	;Определяем номер устройства
	mov		device_number, temp	;которое включаем/выключаем
	
	;mov 	temp, device_number ;Получаем нужный бит
	;rcall 	set_bit_temp2		;устройства в temp2
	;and		temp2, actual_device_statuses ;Проверяем актуален ли
										  ;статус устройства
	;cpi		temp2, 0  ;Если не равно нулю, то 
	;brne	skip_time ;статус устройства актуален

	ld		temp, Y+
	cp		temp, time_hours ;Сравнение по часам
	breq	next_minutes	 ;Если часы равны, то проверяем минуты
	brsh	skip_MS		 	 ;Если temp больше hours то
							 ;прпускаем минуты и секунды и не обновляем статус
	inc YL					 ;Увеличиваем значеие Y на 2, чтобы
	inc YL					 ;указатель стоял на следующей записи
	rjmp	execute_device_status
	
next_minutes:
	ld		temp, Y+
	cp		temp, time_minutes ;Сравнение по минутам
	breq	next_seconds	 ;Если минуты равны, то проверяем минуты
	brsh	skip_S		 	 ;Если temp больше minutes то
							 ;прпускаем секунды и не обновляем статус
	inc YL					 ;Увеличиваем значеие Y на 1
	rjmp	execute_device_status

next_seconds:
	ld		temp, Y+
	cp		temp, time_seconds ;Сравнение по секундам
	breq	execute_device_status
	brsh	next_time		;Если temp больше seconds, то
							;то переходим к следующей записи и не обновляем статус
	rjmp	execute_device_status ;иначе выводим статус устройства

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
	rcall 	set_bit_temp2                   ;выставляем номер бита устройства,
	or 		actual_device_statuses, temp2	;статус которого актуализируем

	and		temp2, force_devices ;Если выбранное устройство находится в принудительном режиме
	cpi		temp2, 0				 ;то пропускаем это устройство и переходим к
	brne	next_time			 ;следующему сообщению

	cpi 	on_off, 1 ;Проверяем нужно ли включить устройстов
	brne	SET_OFF ;Если не равно, то идем выключать
	mov		temp, device_number ;Заносим в temp номер текущего устройства
	rcall 	set_bit_temp2 ;Устанавливаем нужный бит в temp2
	mov		temp, a_status ;Заносим в temp актуальное состояние порта A	
	or		temp, temp2 ;Устанавливаем 1 в нужный бит
	mov		a_status, temp ;Заносим значение temp обратно в порт A
	rjmp	next_time
SET_OFF:
	rcall 	set_bit_temp2 ;Устанавливаем нужный бит в temp2
	mov		temp, a_status ;Заносим в temp актуальное состояние порта A	
	com		temp2		;Инвертируем значения в регистре temp2
	and		temp, temp2	;Устанавливаем 0 в нужный бит
	mov		a_status, temp	;Заносим значение temp обратно в порт A
	rjmp	next_time

end_out_schedule:
	mov		temp, a_status
	out		PORTA, temp
	sei		;Вновь разрешаем прерывания
	ret


;#### ПРОЦЕДУРА УСТАНОВКИ БИТА В ПЕРЕМЕННОЙ temp2 ####
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

;#### ПРОЦЕДУРА ОТПРАВКИ СООБЩЕНИЯ OK ####
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

;#### ПРОЦЕДУРА ПРИЕМА РАСПИСАНИЯ ####
recieve_schedule:
	ldi		XL, low(schedule_count)
	ldi		XH, high(schedule_count)
	ldi 	YL, low(schedule_start)
	ldi 	YH, high(schedule_start)
	
	ldi		temp, 0		;Устанавливаем количество записей
	st		X, temp		;в нуль

recieve_cicle:
	rcall	in_com		;Считываем данные
	cpi 	temp, 0b11111111 ;Признак окончания
	breq	end_recieve 	 ;передачи расписания
	
	st 		Y+, temp	;Считываем заголовок, определяющий
	rcall 	in_com		;номер устройства и включение/отключение его
	st 		Y+, temp	;Считываем часы начала работы
	rcall 	in_com
	st		Y+, temp	;Считываем минуты начала работы
	rcall 	in_com
	st 		Y+, temp	;Считываем секунды начала работы
	
	ldi		XL, low(schedule_count)
	ldi		XH, high(schedule_count)
	ld		temp, X		;Вытаскиваем количество записей на данный момент
	inc		temp		;Увеличиваем количество записей
	st		X, temp		;Записываем кол-во записей по адресу X

	rjmp recieve_cicle

end_recieve:
	ret

;#### ПРОЦЕДУРА ОТПРАВКА БАЙТА ЧЕРЕЗ UART ####
out_com:	
	sbis	UCSRA,UDRE	;Ожидание, когда бит UDRE 
	rjmp	out_com		;будет установлен в 1 (предыдущий байт отправлен) 
	out		UDR,temp	;Отправляем байт
	ret

;#### ПРОЦЕДУРА ПРИЕМ БАЙТА ЧЕРЕЗ UART ####
in_com:		
	sbis	UCSRA,RXC	;Ожидание, когда бит RXC будет установлен в 1 
	rjmp	in_com		;(в регистре данных есть принятый непрочитанный байт) 
	in		temp,UDR	;Считываем принятый байт
	ret
	


;#### РАЗЛИЧНЫЕ ПРЕРЫВАНИЯ ####

TIME0_OVER:
	ldi temp, 6	;Установка начала отчета 
	out TCNT0, temp ;для счетчика T0 (при 9 МГц)

	inc time_extra
	cpi time_extra, 0
	brne time0_continue

	ldi time_extra, 131 ;Установка начального в дополнительный регистр времени
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

	



