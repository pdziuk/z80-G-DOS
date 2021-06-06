;-------------------------------------------------------------------------------
;COMMANDS
;-------------------------------------------------------------------------------
; TEST IS A TEST ROUTINE TO SEE IF THE COMMAND RECOGINITION ROUTINES WORK.
;  IT SHOULD JUST PRINT SOME VERY BASIC STUFF TO THE SCREEN.
TEST:
        LD HL,TEST_MSG
        CALL PRINT_STRING
        CALL PRINT_PROMPT
        RET

CALL_CMD:

        LD A,(BUF_BOT+5)        ;GET THE BYTES, CONVERT TO BINARY ADDRESS
        LD D,A
        LD A,(BUF_BOT+6)
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD H,A                  ;PLACE UPPER BYTE IN H
        LD A,(BUF_BOT+7)
        LD D,A
        LD A,(BUF_BOT+8)        ;FOR NICE ROUND-NUMBER DUMP.
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD L,A                  ;PLACE LOWER BYTE IN L
        LD DE,RETLOC            ;SIMULATE A CALL FUNCTION BY GETTING RETURN ADDRESS
        PUSH DE                 ;AND PUSHING ONTO THE STACK...
CLOC:   JP (HL)                 ;GO TO MEMORY ADDRESS TO EXECUTE
RETLOC  CALL BUF_CLR            ;RET IN THE CALLED CODE WILL COME BACK HERE
        CALL PRINT_PROMPT       ;WHERE WE CLEAR BUFFER AND PRINT COMMAND PROMPT
        RET                     ;RETURN TO MONITOR MAIN LOOP WITH CLEARED BUFFER AND PROMPT READY TO DO IT AGAIN

CLS:
        LD HL,CS_MSG
        CALL PRINT_STRING
        CALL PRINT_PROMPT
        RET

MON_DIR:
        CALL directory          ;Directory
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

MON_DEL:
        LD DE,filename_buffer   ;Pointer to filename buffer
        LD HL,BUF_BOT+4         ;Point to start of filename
EFNAME: LD A,(HL)               ;GET THE CHAR FROM BUFFER
        LD C,00H                ;CHECK IF END OF LINE
        CP C
        JR Z,DO_ERASE           ;IF END OF WORD TRY TO ERASE
        LD (DE),A               ;STORE IN FILENAME BUFFER
        INC DE
        INC HL
        JP EFNAME              ;GET NEXT CHARACTER
DO_ERASE:
        LD A,00H
        LD (DE),A
        CALL ERASE
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

MON_LOAD:
        LD DE,filename_buffer   ;Pointer to filename buffer
        LD HL,BUF_BOT+5         ;Point to start of filename
LFNAME: LD A,(HL)               ;GET THE CHAR FROM BUFFER
        LD C,00H                ;CHECK IF END OF LINE
        CP C
        JR Z,DO_LOAD            ;IF END OF WORD TRY TO LOAD
        LD (DE),A               ;STORE IN FILENAME BUFFER
        INC DE
        INC HL
        JP LFNAME              ;GET NEXT CHARACTER
DO_LOAD:
        LD A,00H
        LD (DE),A
        CALL load
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

MON_SAVE:
        LD DE,filename_buffer   ;Pointer to filename buffer
        LD HL,BUF_BOT+5         ;Point to start of filename
SFNAME: LD A,(HL)               ;GET THE CHAR FROM BUFFER
        LD C,00H                ;CHECK IF END OF LINE
        CP C
        JR Z,DO_SAVE            ;IF END OF WORD TRY TO SAVE
        LD (DE),A               ;STORE IN FILENAME BUFFER
        INC DE
        INC HL
        JP SFNAME              ;GET NEXT CHARACTER
DO_SAVE:
        LD A,00H
        LD (DE),A
        CALL save
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

;DUMP COMMAND
;-------------------------
DUMP:
        LD HL,CS_MSG
        CALL PRINT_STRING
        LD HL,DUMP_HEADER_MSG
        CALL PRINT_STRING
        LD A,(BUF_BOT+5)          ;GET THE BYTES, CONVERT TO BINARY ADDRESS
        LD D,A
        LD A,(BUF_BOT+6)
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD H,A                  ;PLACE UPPER BYTE IN H
        LD A,(BUF_BOT+7)
        LD D,A
        LD A,030H                ;FOR NICE ROUND-NUMBER DUMP.
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD L,A                  ;PLACE LOWER BYTE IN L
        LD B,0FH                ;LOAD ROW COUNTER BYTE
        LD C,010H                ;LOAD COLUMN COUNTER BYTE
        LD A, SPACE
        CALL PRINT_CHAR
        LD A,'|'
        CALL PRINT_CHAR
        CALL DUMP_ADDR
        LD A,SPACE
        CALL PRINT_CHAR
        CALL PRINT_CHAR
DUMP2:
        LD A,C
        CP 00H
        JR Z,DUMP4
        LD C,A
DUMP3:
        LD A,(HL)
        CALL PRINT_HEX
        INC HL
        LD A,C
        DEC A
        LD C,A
        LD A,SPACE
        CALL PRINT_CHAR
        JR DUMP2
DUMP4:
        CALL DUMP_ASCII
        LD A,B
        CP 00H
        JR Z,DUMP_EXIT
        DEC A
        LD B,A
        LD C,010H
        LD A,CR
        CALL PRINT_CHAR
        LD A,LF
        CALL PRINT_CHAR
        LD A,SPACE
        CALL PRINT_CHAR
        LD A,'|'
        CALL PRINT_CHAR
        CALL DUMP_ADDR
        LD A,SPACE
        CALL PRINT_CHAR
        CALL PRINT_CHAR
        JR DUMP2
DUMP_ASCII:
        PUSH AF
        PUSH BC
        PUSH DE
        PUSH HL
        LD A,SPACE
        CALL PRINT_CHAR
        CALL PRINT_CHAR
        LD DE,0010H
        SBC HL,DE
        LD B,010H
DUMP_ASCII2:
        LD A,B
        CP 00H
        JR Z,DUMP_ASCII3
        DEC A
        LD B,A
        LD A,(HL)
        CALL DUMP_ASCII_CONVERT
        CALL PRINT_CHAR
        INC HL
        JR DUMP_ASCII2
DUMP_ASCII3:
        LD A,'|'
        CALL PRINT_CHAR
        POP HL
        POP DE
        POP BC
        POP AF
        RET
DUMP_ASCII_CONVERT:
        CP 07FH
        JP P,DUMP_ASCII_CONVERT2
        CP 0FFH
        JR Z,DUMP_ASCII_CONVERT2
        AND 07FH
        CP 020H
        JP M,DUMP_ASCII_CONVERT2
        JR DUMP_ASCII_CONVERT3
DUMP_ASCII_CONVERT2:
        LD A,'.'
DUMP_ASCII_CONVERT3:
        RET
DUMP_ADDR:
        LD A,H
        CALL PRINT_HEX
        LD A,L
        CALL PRINT_HEX
        RET
DUMP_EXIT:
        LD HL,DUMP_FOOTER_MSG
        CALL PRINT_STRING
        CALL BUF_CLR
        LD A,CR
        CALL PRINT_CHAR
        LD A,LF
        CALL PRINT_CHAR
        CALL PRINT_PROMPT
        RET
DUMP_NEXT_BUF:
        INC HL
        LD A,(HL)
        CALL PRINT_CHAR
        RET
;--------------------------

HELP:
        LD HL,HELP_MSG
        CALL PRINT_STRING
        CALL PRINT_PROMPT
        RET

IN_CMD:
        LD HL,IN_MSG
        CALL PRINT_STRING
        LD A,(BUF_BOT+3)          ;GET THE BYTES, CONVERT TO BINARY ADDRESS
        LD D,A
        LD A,(BUF_BOT+4)
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD C,A
        IN A,(C)
        CALL PRINT_HEX
        LD A,'h'
        CALL PRINT_CHAR
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

MODMEM:
        LD HL,MODMEM_MSG
        CALL PRINT_STRING
        LD A,(BUF_BOT+7)          ;GET THE BYTES, CONVERT TO BINARY ADDRESS
        LD D,A
        LD A,(BUF_BOT+8)
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD H,A                  ;PLACE UPPER BYTE IN H
        LD A,(BUF_BOT+9)
        LD D,A
        LD A,(BUF_BOT+10)        ;FOR NICE ROUND-NUMBER DUMP.
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD L,A                  ;PLACE LOWER BYTE IN L
        CALL MODMEM_DUMP_ADDR
        LD A,'>'
        CALL PRINT_CHAR
MODMEM2:
        CALL MODMEM_GET
        CP 'X'
        JR Z,MODMEM_EXIT
        CP 'x'
        JR Z,MODMEM_EXIT
        LD D,A
        CALL MODMEM_GET
        CP 'X'
        JR Z,MODMEM_EXIT
        CP 'x'
        JR Z,MODMEM_EXIT
        LD E,A
MODMEM3:
        CALL ASCIIHEX_TO_BYTE
        CP 0FEH                 ; Added to fix 'Enter Bug'
        CALL Z,MODMEM_ERROR     ;
        CP 0F6H                 ;
        CALL Z,MODMEM_ERROR     ;
        LD (HL),A
        INC HL
        LD A,CR
        CALL PRINT_CHAR
        LD A,LF
        CALL PRINT_CHAR
        CALL MODMEM_DUMP_ADDR
        LD A,'>'
        CALL PRINT_CHAR
        JR MODMEM2
MODMEM_GET:
        CALL GET_KEY
        CALL PRINT_CHAR         ;ECHO
        RET
MODMEM_DUMP_ADDR:
        LD A,H
        CALL PRINT_HEX
        LD A,L
        CALL PRINT_HEX
        LD A, " "
        CALL PRINT_CHAR
        LD A,(HL)
        CALL PRINT_HEX
        RET
MODMEM_EXIT:
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

MODMEM_ERROR:                   ;Added to fix 'Enter Bug'
        LD A,(HL)               ;
        RET                     ;

OUT_CMD:
        LD A,(BUF_BOT+4)
        LD D,A
        LD A,(BUF_BOT+5)
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        LD C,A
        LD A,(BUF_BOT+7)
        LD D,A
        LD A,(BUF_BOT+8)
        LD E,A
        CALL ASCIIHEX_TO_BYTE
        OUT (C),A
        CALL BUF_CLR
        CALL PRINT_PROMPT
        RET

RESTART:
        JP BOOT

HEXLOAD:
        CALL IH_LOAD
        CALL PRINT_PROMPT
        RET

