; memorystick_low_level.asm
; Adapted to G80 computer from the Z80 Playground Project
; https://github.com/z80playground/cpm-fat/blob/main/README.md

;--------------------;
; LOW LEVEL ROUTINES ;
;--------------------;
    
configure_memorystick:
    ld b, 5                                 ; Have 5 attempts at configuring the module before giving up
configure_memorystick1:
    push bc
    call connect_to_usb_drive
    jr nz, failed_to_setup
    call connect_to_disk
    call mount_disk
    pop bc
    ret
failed_to_setup:
    call DELAY
    call DELAY
    call DELAY
    call DELAY
    pop bc
    djnz configure_memorystick1
    call message
    db 'CH376S error.',13,10,0
    ret

;----------------------------------------------------------------
; Call this once at startup
reset_ch376_module:
    ld a, RESET_ALL
    call send_command_byte
    call DELAY
    call DELAY
    call DELAY
    call DELAY
    ret

;-----------------------------------------------------------------
check_module_exists:
    ld a, CHECK_EXIST
    Call send_command_byte

    ld a, 123               ; We send an arbitrary number
    Call send_data_byte

    call read_data_byte

    cp 255-123      ; The result is 255 minus what we sent in
    ret z
    call message
    db 'ERROR: CH376S module not found.',13,10,0
    ret

;-----------------------------------------------------------------
get_module_version:
    call message
    db 'Found CH376S v',0 ; Mine is v3!!!
    
    ld a, GET_IC_VER
    call send_command_byte
    
    call read_data_byte
    and %00011111
    
    call show_a_as_hex
    call newline
    ret

;-----------------------------------------------------------------
set_usb_host_mode:
    ld a, SET_USB_MODE
    call send_command_byte
    ld a, 6
    call send_data_byte
    call read_status_byte
    cp USB_INT_CONNECT
    ret z
    call message
    db 'ERROR: No USB Disk?',13,10,0
    ret

;-----------------------------------------------------------------
connect_to_disk:
    ld a, DISK_CONNECT
    call send_command_byte
    ld a, GET_STATUS
    call read_status_byte
    ret z
    call message
    db 'ERROR connecting to USB Disk.',13,10,0
    ret

;-----------------------------------------------------------------
mount_disk:
    ld a, DISK_MOUNT
    call send_command_byte
    ld a, GET_STATUS
    call read_status_byte
    ret z
    call message
    db 'ERROR mounting USB Disk.',13,10,0
    ret

;-----------------------------------------------------------------
read_disk_signature:
    ld a, RD_USB_DATA0
    call send_command_byte
    call read_data_byte                 ; A = length of bytes to now read
    cp 36
    jr nz, could_not_read_disk_sig

    ; Ignore the first 8 bytes
    ld b, 8
read_disk_signature1:
    push bc
    call read_data_byte_silent
    pop bc
    djnz read_disk_signature1   

    ; Display the next 8 bytes (Manufacturer)
    ld b, 8
read_disk_signature2:
    push bc
    call read_data_byte_silent
    call PRINT_CHAR
    pop bc
    djnz read_disk_signature2   
    call newline

    ; Display the next 16 bytes (Model)
    ld b, 16
read_disk_signature3:
    push bc
    call read_data_byte_silent
    call PRINT_CHAR
    pop bc
    djnz read_disk_signature3

    ld a, ' '
    call PRINT_CHAR

    ; Display the next 4 bytes (Version)
    ld b, 4
read_disk_signature4:
    push bc
    call read_data_byte_silent
    call PRINT_CHAR
    pop bc
    djnz read_disk_signature4   
    call newline
    ret

could_not_read_disk_sig:
    call message
    db 'ERROR reading disk sig.',13,10,0
    ret

connect_to_usb_drive:
    ; Connects us up to the USB Drive.
    ; Returns Zero flag = true if we can connect ok.
    call reset_ch376_module 
    call set_usb_host_mode
    cp USB_INT_CONNECT
    ret

create_file:
    ; pass in DE = pointer to filename
    push de
    ld a, SET_FILE_NAME
    call send_command_byte
    pop hl
    call send_data_string

    ld a, FILE_CREATE
    call send_command_byte

    call read_status_byte
    cp USB_INT_SUCCESS
    ret

open_file:
    ; Tells the module to use the filename from the filename_buffer.
    ; Returns z=true if ok to proceed.
    ; Pass in hl -> directory string, e.g. "/folder"
    ld a, SET_FILE_NAME
    call send_command_byte
    call send_data_string
    ld a, FILE_OPEN
    call send_command_byte
    call read_status_byte
    cp USB_INT_SUCCESS
    ret

close_file:
    ld a, FILE_CLOSE
    call send_command_byte
    ld a, 1                             ; 1 = update file size if necessary
    call send_data_byte
    call read_status_byte
    ret

create_directory:
    ; Tells the module to use the filename from the filename_buffer to create a directory of that name.
    ; Returns z=true if ok to proceed.
    ld hl, filename_buffer

create_directory2:

    ld a, SET_FILE_NAME
    call send_command_byte
    ld hl, filename_buffer
    call send_data_string
    ld a, DIR_CREATE
    call send_command_byte
    call read_status_byte
    cp USB_INT_SUCCESS
    ret

read_from_file:
    ; Ask to read 128 bytes from the current file into the dma_address area pointed to by DE.
    ; Returns Zero flag set for success, clear for fail.
    push de
    ld a, BYTE_READ
    call send_command_byte
    ld a, 128                           ; Request 128 bytes
    call send_data_byte
    ld a, 0
    call send_data_byte

    call read_status_byte
read_from_file1:
    cp USB_INT_DISK_READ                    ; This means "go ahead and read"
    jr z, read_from_file3
    cp USB_INT_SUCCESS                      ; Bizarrely this means we are finished
    jp z, read_from_file_cannot
    jr read_from_file_cannot

read_from_file3:
    ld a, RD_USB_DATA0                      ; Find out how many bytes are available to read
    call send_command_byte
    call read_data_byte                     ; A = number of bytes available to read

    ; If there are less than 128 bytes to read, fill the buffer with 0s first
    cp 128
    jr nc, read_from_file_128
    pop hl
    push hl
    push af
    ld b, 128
read_from_file_padding:
    ld (hl), 0
    inc hl
    djnz read_from_file_padding
    pop af

read_from_file_128:
    pop hl
    call read_data_bytes_into_hl        ; Read this block of data
    push hl
    ld a, BYTE_RD_GO
    call send_command_byte
    ld a, GET_STATUS
    call send_command_byte
    call read_data_byte
    pop hl
    ; All done, so return ZERO for success
    cp a                                ; set zero flag for success
    ret

read_from_file_cannot:
    pop de
    or 1                                ; clear zero flag
    ret

copy_filename_to_buffer:
    ; Enter with hl->zero-terminated-filename-string
    ; Copies this to filename_buffer
    ld de, filename_buffer
copy_filename_to_buffer1:
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    cp 0
    ret z
    jr copy_filename_to_buffer1

send_data_byte:
    out (mem_stick_data_port), a
    call wait_til_not_busy
    ret
    
send_data_string:
    ; The string is pointed to by HL
    ld a, (hl)
    cp 0
    jr z, send_data_string_done
    push af
    push hl
    call send_data_byte
    pop hl
    pop af
    inc hl
    jp send_data_string
send_data_string_done:
    ld a, 0
    call send_data_byte
    ret

send_command_byte:
    out (mem_stick_command_port), a
    call wait_til_not_busy
    ret
    
read_command_byte:
    in a, (mem_stick_command_port)
    ret
    
read_data_byte:
    in a, (mem_stick_data_port)
    ret
    
read_data_byte_silent:
    in a, (mem_stick_data_port)
    ret

read_data_bytes_into_buffer:
    ; The number of bytes should be in A.
    ; Read that many bytes into the buffer.
    ; The value of A is retained.
    ld hl, disk_buffer
read_data_bytes_into_hl:
    ; This entry point will read A bytes into the area pointed to by HL.
    ; On exit HL will point to the location after where the bytes were added.
    push af
    ld b, a
    ld c, mem_stick_data_port
read_data_bytes_into_buffer1:
    inir                    ; A rare use of In, Increase & Repeat!!!
    pop af
    ret
    
wait_til_not_busy:
    ld bc, 60000            ; retry max 60000 times!!!
wait_til_not_busy1:
    push bc
    call read_command_byte
    and %00010000
    jp nz, wait_til_not_busy2
    pop bc
    ret
wait_til_not_busy2:
    call MILLI_DLY
    pop bc
    dec bc
    ld a, b
    or c
    jr nz, wait_til_not_busy1
    call message
    db '[USB TIMEOUT]', 13, 10, 0
    ret

read_status_byte:
    ld a, GET_STATUS
    call send_command_byte
    call read_data_byte
    ret

directory:                                    ; This does a directory listing.
    ; Clear files counter
    ld a, 0
    ld (tb_dir_count), a
    
    ; Open ROOT folder
    ld hl, SLASHSTR
    call open_file
    
    ; Then open *
    ld hl, STAR_DOT_STAR
    call open_file
    
    ; Loop through, printing the file names, one per line
tb_dir_loop:
    cp USB_INT_DISK_READ
    jr z, tbasic_dir_loop_good
    
    ld a, (tb_dir_count)
    cp 0
    jp nz, dir_end
    
    call message
    db 'No files found.',13,10,0

dir_end:
    ret
    
tbasic_dir_loop_good:
    ld a, RD_USB_DATA0
    call send_command_byte
    call read_data_byte                 ; Find out how many bytes there are to read
    
    call read_data_bytes_into_buffer    ; read them into disk_buffer
    cp 32                               ; Did we read at least 32 bytes?
    jr nc, tb_dir_good_length
tb_dir_next:
    ld a, FILE_ENUM_GO                  ; Go to next entry in the directory
    call send_command_byte
    call read_status_byte
    jp tb_dir_loop
    
tb_dir_good_length:
    ld a, (disk_buffer+11)
    and $16                             ; Check for hidden or system files, or directories
    jp nz, tb_dir_next                  ; and skip accordingly.
    
tb_it_is_not_system:
    ld hl, tb_dir_count
    inc (hl)
    
    ; Show filename from diskbuffer
    ld b, 8
    ld hl, disk_buffer
tb_dir_show_name_loop:
    ld a, (hl)
    call PRINT_CHAR
    inc hl
    djnz tb_dir_show_name_loop
    
    ld a, '.'
    call PRINT_CHAR
    
    ld b, 3
tb_dir_show_extension_loop:
    ld a, (hl)
    call PRINT_CHAR
    inc hl
    djnz tb_dir_show_extension_loop
    call newline
    jp tb_dir_next

save:                    ; This Saves the current program to USB Drive with the given name.
    push de
    call get_program_size
    pop de
    ld a, h
    or l
    cp 0
    jr nz, save_continue
    call message
    db 'No program yet to save!',13,10,0
    ret
save_continue:
    ;call READ_QUOTED_FILENAME
    call does_file_exist
    call z, tb_erase_file
    
    call close_file
    
    call message
    db 'Creating file...',13,10,0
    
    ld hl, SLASHSTR
    call open_file
    ld de, filename_buffer
    call create_file
    jr z, tb_save_continue
    call message
    db 'Could not create file.',13,10,0
    ret
    
get_program_size:
    ; Gets the total size of the program, in bytes, into hl
    ld hl, 7DFFH
    ret
    
tb_save_continue:
    call close_file
    ld hl, SLASHSTR
    call open_file
    ld hl, filename_buffer
    call open_file
    
    ld a, BYTE_WRITE
    call send_command_byte
    
    ; Send number of bytes we are about to write, as 16 bit number, low first
    call get_program_size
    ld a, l
    call send_data_byte
    ld a, h
    call send_data_byte
    
    ld hl, 8000H
    call write_loop
    call close_file
    ret
    
load:                                   ; *** LOAD "filename" *** 
    ;call READ_QUOTED_FILENAME
    call does_file_exist
    jr z, load_can_do
tb_file_not_found
    call message
    db 'File not found.',13,10,0
    ret
    
load_can_do:
    ld hl, SLASHSTR
    call open_file
    ld hl, filename_buffer
    call open_file
    
    ld a, BYTE_READ
    call send_command_byte
    ld a, 255                           ; Request all of the file
    call send_data_byte
    ld a, 255                           ; Yes, all!
    call send_data_byte
    
    ld a, GET_STATUS
    call send_command_byte
    call read_data_byte
    ld hl, 8000H                       ; Get back the target address
tb_load_loop1:
    cp USB_INT_DISK_READ
    jr nz, tb_load_finished
    
    push hl
    ld a, RD_USB_DATA0
    call send_command_byte
    call read_data_byte
    ;push af
    ;ld a,"."
    ;call PRINT_CHAR
    ;pop af
    pop hl
    call read_data_bytes_into_hl
    push hl
    ld a, BYTE_RD_GO
    call send_command_byte
    ld a, GET_STATUS
    call send_command_byte
    call read_data_byte
    pop hl
    jp tb_load_loop1
tb_load_finished:
    ;ld (TXTUNF), hl
    call close_file
    ret

ERASE:              ; *** ERASE "filename" *** 
    ;call READ_QUOTED_FILENAME
    ; need to set filename_buffer
    call does_file_exist
    jr nz, tb_file_not_found
    call tb_erase_file
    ret
    
tb_erase_file:
    call message
    db 'Erasing file...',13,10,0
    ld a, SET_FILE_NAME
    call send_command_byte
    ld hl, filename_buffer
    call send_data_string
    ld a, FILE_ERASE
    call send_command_byte
    call read_status_byte
    ret
    
does_file_exist:
    ; Looks on disk for a file. Returns Z if file exists.
    ld hl, SLASHSTR
    call open_file
    ld hl, filename_buffer
    jp open_file
    
write_loop
    ;ld a,"."
    ;call PRINT_CHAR
    call read_status_byte
    cp USB_INT_DISK_WRITE
    jr nz, write_finished
    
    push hl
    ; Ask if we can send some bytes
    ld a, WR_REQ_DATA
    call send_command_byte
    call read_data_byte
    pop hl
    cp 0
    jr z, write_finished
    ld b, a
block_loop:
    ld a, (hl)
    push hl
    push bc
    call send_data_byte
    pop bc
    pop hl
    inc hl
    djnz block_loop
    
    push hl
    ld a, BYTE_WR_GO
    call send_command_byte
    pop hl
    jp write_loop
    
write_finished:
    ret

mem_stick_data_port equ 04
mem_stick_command_port equ 05

GET_IC_VER equ $01
SET_BAUDRATE equ $02
RESET_ALL equ $05
CHECK_EXIST equ $06
GET_FILE_SIZE equ $0C
SET_USB_MODE equ $15
GET_STATUS equ $22
RD_USB_DATA0 equ $27
WR_USB_DATA equ $2C
WR_REQ_DATA equ $2D
WR_OFS_DATA equ $2E
SET_FILE_NAME equ $2F
DISK_CONNECT equ $30
DISK_MOUNT equ $31
FILE_OPEN equ $32
FILE_ENUM_GO equ $33
FILE_CREATE equ $34
FILE_ERASE equ $35
FILE_CLOSE equ $36
DIR_INFO_READ equ $37
DIR_INFO_SAVE equ $38
BYTE_LOCATE equ $39
BYTE_READ equ $3A
BYTE_RD_GO equ $3B
BYTE_WRITE equ $3C
BYTE_WR_GO equ $3D
DISK_CAPACITY equ $3E
DISK_QUERY equ $3F
DIR_CREATE equ $40

; Statuses
USB_INT_SUCCESS equ $14
USB_INT_CONNECT equ $15
USB_INT_DISCONNECT equ $16
USB_INT_BUF_OVER equ $17
USB_INT_USB_READY equ $18
USB_INT_DISK_READ equ $1D
USB_INT_DISK_WRITE equ $1E
USB_INT_DISK_ERR equ $1F
YES_OPEN_DIR equ $41
ERR_MISS_FILE equ $42
ERR_FOUND_NAME equ $43
ERR_DISK_DISCON equ $82
ERR_LARGE_SECTOR equ $84
ERR_TYPE_ERROR equ $92
ERR_BPB_ERROR equ $A1
ERR_DISK_FULL equ $B1
ERR_FDT_OVER equ $B2
ERR_FILE_CLOSE equ $B4

ROOT_DIRECTORY:
    db '*',0

SLASHSTR:
    db '/',0
    
STAR_DOT_STAR:
    db '*.*',0
    
