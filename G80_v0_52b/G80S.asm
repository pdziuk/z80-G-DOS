;-------------------------------------------------------------------------------
;                   G-DOS (Prototype) Operating System
;
;  A firmware OS designed specifically for the G80-S, G80-USB, and G80-UVK
;   z80 Computers.
;
;  By:  Doug Gabbard ( 2017 - 20XX )
;  Dev-Team:    Mike Veit
;               Amardeep Chana
;
;-------------------------------------------------------------------------------



;-------------------------------------------------------------------------------
;       BOARD SETTINGS
;-------------------------------------------------------------------------------
;  Due to the growing design of this computer project, it has become necessary
;   to begin conditional assembly for specific boards.  This can be done easily
;   in code to allow for different sets of code to be compiled depending on the
;   specific board.  The 'BOARD' equate is the key.  Depending on the value
;   given, the board will either compile for either the G80-S/USB variants, or
;   the G80-UVK (and G80-S/USB with add-on cards for compatibility).  To specify
;   which board is to be used, please set 'BOARD' to one of the following
;   settings:
;
;       0 = G80-S or G80-USB
;       1 = G80-UVK (or G80-S/USB with add-on card)
;
;  A second setting is available to allow serial communication for the G80-S/USB
;   over either Port A or B.  On the G80-USB the USB Serial Port is Port A, and
;   the RS-232 port is Port B. To enable serial over a specific serial port
;   choose one of the following settings for 'SERIAL':
;
;       0 = Serial Port A
;       1 = Serial Port B
;
;  Option 3 is the BAUD Rate settings for both Port A, and Port B.  These can be
;   mixed however the user chooses:  115200 Baud, 57600 Baud, and 28800 Baud.
;   This allows for a greater window of communication options.  Changing the
;   frequency oscillator for Serial Communication can allow for other varieties
;   of combinations.  The settings for SIOA_BAUD and SIOB_BAUD are:
;
;       DEFAULT = X32 - MOST RELIABLE
;       0 = Divide by 16
;       1 = Divide by 32
;       2 = Divide by 64
;-------------------------------------------------------------------------------

BOARD           EQU     0
SERIAL          EQU     0
SIOA_BAUD       EQU     1
SIOB_BAUD       EQU     1

INCLUDE "equates.asm"         ;DEFINITIONS OF VALUES

;-------------------------------------------------------------------------------
; PICK YOUR PROGRAMMING LANGUAGES
;
;       0 = NOT INCLUDED
;       1 = INCLUDED
;
;       IF MS_BASIC is enabled, you cannot have BASIC or CFORTH Enabled
;-------------------------------------------------------------------------------

BASIC           EQU     0
MS_BASIC        EQU     1             ; if enabled, cannot have BASIC and CFORTH = 1
CFORTH          EQU     0

;-------------------------------------------------------------------------------
; BEGINNING OF CODE
;-------------------------------------------------------------------------------
                ORG     0000h
BOOT:
        DI
        LD SP,STACK                     ;STACK OCCUPIES FBFF AND BELOW.
        JP INIT                         ;GO INITIALIZE THE SYSTEM.

;-------------------------------------------------------------------------------
; ZERO PAGE FOR BASIC IF INCLUDED
;-------------------------------------------------------------------------------

        IF (BASIC = 1)
INCLUDE "basic_pg0.asm"         ;ZERO PAGE FOR TINY BASIC
        ENDIF

        IF (MS_BASIC = 1)
INCLUDE "msbasic_pg0.asm"
        ENDIF

;-------------------------------------------------------------------------------
; DOS CALLS
;-------------------------------------------------------------------------------
                ORG     0100h
DCALL0:                         ;CALL 00100h
        JP RAM_CLR
DCALL1:                         ;CALL 0103h
        JP DELAY
DCALL2:                         ;CALL 0106h
        JP MILLI_DLY
DCALL3:                         ;CALL 0109h
        JP BUF_CLR
DCALL4:                         ;CALL 010Ch
        JP BUF_WRITE
DCALL5:                         ;CALL 010Fh
        JP PRINT_CHAR
DCALL6:                         ;CALL 0112h
        JP PRINT_HEX
DCALL7:                         ;CALL 0115h
        JP PRINT_STRING
DCALL8:                         ;CALL 0118h
        JP TXA_RDY
DCALL9:                         ;CALL 011Bh
        JP RXA_RDY
DCALL10:                        ;CALL 011Eh
        JP TXB_RDY
DCALL11:                        ;CALL 0121h
        JP RXB_RDY
DCALL12:                        ;CALL 0124h
        JP GET_KEY
DCALL13:                        ;CALL 0127h
        JP ASCIIHEX_TO_BYTE
DCALL14:                        ;CALL 012Ah
        JP CONVERT_HEX_VAL

;DCALL15 .. DCALL24

;-------------------------------------------------------------------------------
; MONITOR/OS
;-------------------------------------------------------------------------------
                ORG     0200H
; INIT IS THE ROUTINE THAT SETS UP, OR INITIALIZES, THE PERIPHERALS.
INIT:
        CALL SERIAL_INIT

        IF (BOARD = 1)
        CALL PIO_INIT                   ;G80-UVK Only
        CALL DELAY
        CALL DELAY
        CALL DELAY
        CALL DELAY
        ENDIF

        LD HL,CS_MSG
        CALL PRINT_STRING
        LD HL,SIGNON_MSG
        CALL PRINT_STRING

        CALL configure_memorystick
        CALL get_module_version

        CALL PRINT_PROMPT

; SERMAIN_LOOP, THE MAIN LOOP FOR THE SERIAL MONITOR.
MAIN_LOOP:
        CALL GET_KEY                    ;IF SET, GET THE KEY.
        CALL BUF_WRITE                  ;WRITE TO BUFFER
        LD C,CR                         ;CHECK IF CARRAGE RETURN
        SUB C
        JR NZ,MAIN_LOOP                 ;IF NOT LINE FEED, RESTART LOOP
        CALL IN_CMD_CHK                 ;CHECK IF COMMAND
        JR MAIN_LOOP


INCLUDE "sys_routines.asm"
INCLUDE "mon_opt.asm"
INCLUDE "sys_msg.asm"
INCLUDE "cmd_recogn.asm"
INCLUDE "hex_load.asm"
INCLUDE "message.asm"
INCLUDE "memorystick_low_level.asm"

        IF (BASIC = 1)
INCLUDE "basic.asm"
        ENDIF

        IF (MS_BASIC = 1)
INCLUDE "bas32K.asm"
        ENDIF

        IF (CFORTH = 1)
INCLUDE "camel80.asm"
        ENDIF


;-------------------------------------------------------------------------------
; MEMORY LOCATIONS FOR TinyBASIC
;-------------------------------------------------------------------------------
        IF (BASIC = 1)
LSTROM:                                 ;ALL ABOVE CAN BE ROM
;       ORG  08000H                     ;HERE DOWN MUST BE RAM
        ORG  0FF00H
VARBGN: DS   55                         ;VARIABLE @(0)
BUFFER: DS   64                         ;INPUT BUFFER
BUFEND: DS   1                          ;BUFFER ENDS
STKLMT: DS   1                          ;TOP LIMIT FOR STACKB
        ENDIF
        END
