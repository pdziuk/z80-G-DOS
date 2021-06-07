;==============================================================================
; G80-USB/S Driver for Grant Searle's version of Microsoft Basic 4.7b
;
;  Changes are Copyright Doug Gabbard 2019, retrodepot.net
;
;  You have permission to distribute and use this for NON COMMERCIAL USE.
;
;  Portions of this code were adapted or copied from Grant Searle's original
;   works.  His copyright applies.
;
;==============================================================================
; Contents of this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==============================================================================

SER_BUFSIZE     EQU     3FH
SER_FULLSIZE    EQU     30H
SER_EMPTYSIZE   EQU     5

; Note that I hard coded both SIOA's to the second RS-232 port since I don't have the USB chip yet
; and this file was not properly setup to use the SERIAL define from what I could tell (Pat Dziuk)
; I may come back later and fix this

;SIOA_D          EQU     01H     ;SIO CHANNEL A DATA REGISTER
;SIOA_C          EQU     03H     ;SIO CHANNEL A CONTROL REGISTER
;SIOB_D          EQU     01H     ;SIO CHANNEL B DATA REGISTER
;SIOB_C          EQU     03H     ;SIO CHANNEL B CONTROL REGISTER

serBuf          EQU     8000H
serInPtr        EQU     serBuf+SER_BUFSIZE
serRdPtr        EQU     serInPtr+2
serBufUsed      EQU     serRdPtr+2
basicStarted    EQU     serBufUsed+1
TEMPSTACK       EQU     80EDH   ;Top of BASIC line input buffer
                                 ;so is "free ram" when BASIC resets

;CR              EQU     0DH
;LF              EQU     0AH
;CS              EQU     0CH             ; Clear screen

;                .ORG 0000H
;------------------------------------------------------------------------------
; Reset
;RST00:
;        DI                       ;Disable interrupts
;        JP       INITG80            ;Initialize Hardware and go
;------------------------------------------------------------------------------
;TX a character over RS232
                ORG     0008H
RST08:
        JP TXDOS
;------------------------------------------------------------------------------
;RX a character over RS232 Channel A [Console], hold here until char ready.
                ORG 0010H
RST10:
        JP GET_KEYB
;------------------------------------------------------------------------------
;Check serial status
                ORG 0018H
RST18:
        PUSH BC
        
        IF (SERIAL = 0)
        CALL RXA_RDY
        ENDIF
        
        IF (SERIAL = 1)
        CALL RXB_RDY
        ENDIF
        
        JP Z,HASCHR             ; If character on port RXB_RDY is zero otherwise it will be non zero
        LD A,00H                ; No Character on port set A=00H
        JP RST18DONE
HASCHR: LD A,01H                ; Character on port set A=01H
        
RST18DONE:
        CP 00H
        POP BC
        RET

;------------------------------------------------------------------------------
;RST 38 - INTERRUPT VECTOR [ for IM 1 ]
                ORG     0038H
RST38:
        LD HL,(IRQ_VECTOR)      ;LOAD INTERRUPT VECTOR AT ADDRESS FF00H
        JP (HL)                 ;AND JUMP TO THE MODE 1 INTERRUPT HANDLER
        ;RETI
        

BASSETUP:
        LD HL,TEMPSTACK         ;TEMP STACK
        LD SP,HL                ;SETUP TEMP STACK

        LD HL,CLSBASMSG         ;CLEAR SCREEN
        CALL PRINT_STRING       ;OUTPUT STRING
        LD HL,SIGNONBAS1           ;SIGN-ON MESSAGE
        CALL PRINT_STRING       ;OUTPUT STRING
        LD A,(basicStarted)     ;CHECK BASIC FLAG
        CP 'Y'                  ;TO SEE IF THIS IS POWER-UP
        JR NZ,COLDSTART         ;IF COLD, COLD START
        LD HL,SIGNONBAS2           ;COLD/WARM MESSAGE
        CALL PRINT_STRING
        
COLD_OR_WARM:
        CALL GET_KEYB
        AND 0DFH                ;LOWER TO UPPER CASE
        CP 'C'
        JR NZ,CHECKWARM
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
COLDSTART:
        LD A,'Y'                ;SET BASIC STARTED FLAG
        LD (basicStarted),A
        JP COLD          ;START BASIC COLD
CHECKWARM:
        CP 'W'
        JR NZ,COLD_OR_WARM
        RST 08H
        LD A,CR
        RST 08H
        LD A,LF
        RST 08H
        JP COLD+3        ;START BASIC WARM

SIGNONBAS1:
        DB      CS
        DB      "G80-USB/S - Pat Dziuk, 2021",CR,LF,0
SIGNONBAS2:
        DB      CR,LF
        DB      "Cold or Warm Start (C or W)? ",0
CLSBASMSG: 
        DB      ESC,"[2J",ESC,"[H",00H

TXDOS:  PUSH HL
        PUSH AF
        PUSH BC
TXDOS_RDY:			;CHECK IF SIO IS READY TO TRANSMIT.
        LD A,00H
        
        IF (SERIAL = 0)
        OUT (SIOA_C),A          ;SELECT REGISTER 0
        IN A,(SIOA_C)           ;READ REGISTER 0
        ENDIF
        
        IF (SERIAL = 1)
        OUT (SIOB_C),A          ;SELECT REGISTER 0
        IN A,(SIOB_C)           ;READ REGISTER 0
        ENDIF
        
        RRC A
        RRC A
        LD C,01H                ;ROTATE, AND, THEN SUB
        AND C
        SUB C
        JR NZ,TXDOS_RDY           ;TRY AGAIN IF NOT READY
        POP BC
        POP AF
        POP HL
        
        IF (SERIAL = 0)
        OUT (SIOA_D),A
        ENDIF
        
        IF (SERIAL = 1)
        OUT (SIOB_D),A
        ENDIF
        
        RET

GET_KEYB:
        PUSH BC
RXDOS_RDY:
        LD A,00H                ;SETUP THE STATUS REGISTER
        
        IF (SERIAL = 0)
        OUT (SIOA_C),A
        IN A,(SIOA_C)           ;LOAD THE STATUS BYTE
        ENDIF
        
        IF (SERIAL = 1)
        OUT (SIOB_C),A
        IN A,(SIOB_C)           ;LOAD THE STATUS BYTE
        ENDIF
        
        LD C,01H                ;LOAD BYTE TO COMPARE THE BIT, AND COMPARE
        AND C
        SUB C
        JR NZ, RXDOS_RDY
        
        IF (SERIAL = 0)
        IN A,(SIOA_D)
        ENDIF
        
        IF (SERIAL = 1)
        IN A,(SIOB_D)
        ENDIF
        
        POP BC
        RET
