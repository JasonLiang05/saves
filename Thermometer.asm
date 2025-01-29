
; 76E003 ADC test program: Reads channel 7 on P1.1, pin 14

$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------
;

CLK               EQU 16600000 ; Microcontroller system frequency in Hz
BAUD              EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD     EQU (0x100-(CLK/(16*BAUD)))
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000))
Overheat_button   equ P0.4

ORG 0x0000
	ljmp main

;                     1234567890123456    <- This helps determine the location of the counter
test_message:     db '* Thermo meter *', 0
value_message:    db 'Temp      ', 0
cseg
; These 'equ' must match the hardware wiring
LCD_RS equ P1.3
;LCD_RW equ PX.X ; Not used in this code, connect the pin to GND
LCD_E  equ P1.4
LCD_D4 equ P0.0
LCD_D5 equ P0.1
LCD_D6 equ P0.2
LCD_D7 equ P0.3

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5

BSEG
mf: dbit 1
signflag: dbit 1
overheatmod_onoff: dbit 1
overheat_trigger: dbit 1;0 OPEN, 1 OFF !!!

$NOLIST
$include(math32.inc)
$LIST

char_curr_temp: db 'Current Temperature(Celsius): ',0
char_next_line: db '\r','\n',0

Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0f ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1
	
	; Using timer 0 for delay functions.  Initialize here:
	clr	TR0 ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0 ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01 ; Timer 0 in Mode 1: 16-bit timer
	
	; Initialize the pin used by the ADC (P1.1) as input.
	orl	P1M1, #0b00000010
	anl	P1M2, #0b11111101
	
	; Initialize and start the ADC:
	anl ADCCON0, #0xF0
	orl ADCCON0, #0x07 ; Select channel 7
	; AINDIDS select if some pins are analog inputs or digital I/O:
	mov AINDIDS, #0x00 ; Disable all analog inputs
	orl AINDIDS, #0b10000000 ; P1.1 is analog input
	orl ADCCON1, #0x01 ; Enable ADC
	
	ret
	
wait_1ms:
	clr	TR0 ; Stop timer 0
	clr	TF0 ; Clear overflow flag
	mov	TH0, #high(TIMER0_RELOAD_1MS)
	mov	TL0,#low(TIMER0_RELOAD_1MS)
	setb TR0
	jnb	TF0, $ ; Wait for overflow
	ret

; Wait the number of miliseconds in R2
waitms:
	lcall wait_1ms
	djnz R2, waitms
	ret

; We can display a number any way we want.  In this case with
; four decimal places.
Display_formated_BCD:
	Set_Cursor(2, 8)
	lcall print_sign
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_char(#'.')
	Display_BCD(bcd+0)
	Display_char(#'C')
	Set_Cursor(2, 6)
	Display_char(#'=')
	ret

print_sign:
	jb signflag, negetive
	Display_char(#'+')
	sjmp print_sign_end
negetive:
	Display_char(#'-')
	print_sign_end:
	ret



convert_abs_negval:
	push acc
	jb signflag, negetive_val
	sjmp convertposneg_end
negetive_val:
	mov   A, x+0
    mov   y+0, A
    mov   A, x+1
    mov   y+1, A
    mov   A, x+2
    mov   y+2, A
    mov   A, x+3
    mov   y+3, A ;put each byt of x to y
	;    1,000,000 dec --> 0x000F4240 hex
    mov   x+0, #0x40    ; 0x40
    mov   x+1, #0x42    ; 0x42
    mov   x+2, #0x0f    ; 0x0f
    mov   x+3, #0x00    ; 0x00
	;x=1000000-x!!!!!
	lcall sub32
	convertposneg_end:
	pop acc
	ret

detect_posneg:
	push acc
	mov a, x+3
    jnb acc.7, msb0  
    setb signflag
    sjmp  detect_posneg_end
msb0:
    clr signflag
detect_posneg_end:
    pop acc
	ret

get_temp_val_to_x:
	push acc
	push AR0
	push AR1

	mov a, ADCRH   ;high 8 bit
    swap a ;low 4bit swap high 4 bit
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R0, A
    ;put 4 high bit of ADC ADCRH read to r1, r0 for rest 8 bit ADCRL (low)
    ;store to x
	mov x+0, R0;
	mov x+1, R1;byte 1 and 0 of x store ADC value
	mov x+2, #0
	mov x+3, #0

	pop AR1
	pop AR0
	pop acc
	ret

mov_temp_val_to_y:
	push acc
	push AR0
	push AR1

	mov a, ADCRH   ;high 8 bit
    swap a ;low 4bit swap high 4 bit
    push acc
    anl a, #0x0f
    mov R1, a
    pop acc
    anl a, #0xf0
    orl a, ADCRL
    mov R0, A
    ;put 4 high bit of ADC ADCRH read to r1, r0 for rest 8 bit ADCRL (low)
    ;store to x
	mov y+0, R0;
	mov y+1, R1;byte 1 and 0 of x store ADC value
	mov y+2, #0
	mov y+3, #0

	pop AR1
	pop AR0
	pop acc
	ret

; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret
; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret

Convert_to_temp:
	Load_y(51290) ; VCC voltage measured; give this value to y; 5.xxxxV * 10000; (10^-1mV)
	lcall mul32; ;1.ADCch*Vcc(10^-1mV)
	;temp_c = 100*ADC_ch-273 ; ADC_ch * Vcc / 4095
	;convert to temperature
	Load_y(4095) ; 2^12-1 ;(small units of ADC)
	lcall div32 ;2. /4095
	Load_y(27315)
	lcall sub32; 3. -27315(cK)
	;4.convert (10^-1mV) to (10mV),(cK) to (K) (C) in cel, /100, In display_function
	ret

main:
	mov sp, #0x7f
	lcall Init_All
    lcall LCD_4BIT
	clr overheatmod_onoff
	setb overheat_trigger ;0 OPEN, 1 OFF !!!
    
    ; initial messages in LCD
	Set_Cursor(1, 1)
    Send_Constant_String(#test_message)
	Set_Cursor(2, 1)
    Send_Constant_String(#value_message)
	
Forever:
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
    
    ; Read the ADC result and store in [R1, R0]
    lcall get_temp_val_to_x
    ;store to x

	;Average val calculation
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
	mov R2, #80
	lcall waitms
	lcall mov_temp_val_to_y
	lcall add32
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
	mov R2, #80
	lcall waitms
	lcall mov_temp_val_to_y
	lcall add32
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
	mov R2, #80
	lcall waitms
	lcall mov_temp_val_to_y
	lcall add32
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
	mov R2, #80
	lcall waitms
	lcall mov_temp_val_to_y
	lcall add32
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
	mov R2, #80
	lcall waitms
	lcall mov_temp_val_to_y
	lcall add32
	clr ADCF;ADC trans flag 0
	setb ADCS ;  ADC start trigger signal
    jnb ADCF, $ ; Wait for conversion complete
	mov R2, #80
	lcall waitms
	lcall mov_temp_val_to_y
	lcall add32
	;dividing to avgval
	Load_y(7)
	lcall div32


	lcall Convert_to_temp

	lcall detect_posneg
	lcall convert_abs_negval
	; Convert to BCD and display
	lcall hex2bcd
	lcall Display_formated_BCD

	mov DPTR, #char_curr_temp
	lcall SendString
	;put value of x in screen
	mov DPTR, #char_next_line
	lcall SendString
	
	; Wait 125ms between conversions
	mov R2, #20
	lcall waitms
	;mov R2, #250
	;lcall waitms
	
	mov  C, overheat_trigger ; put 1 bit value into carry reg
    mov  P1.7, C              ; Blinking LED...

	ljmp Forever
	
END
	