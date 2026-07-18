[bits 16]       ; Tell assembler we are in 16-bit Real Mode
[org 0x7c00]

start:
    cli
    mov [bootdevice], dl
    ; 1. Set up Segment Registers
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ; 2. Print a message using BIOS INT 0x10
    mov si, msg
print_loop:
    cld
    lodsb           ; Load next byte from SI into AL
    cmp al, 0       ; Check for null terminator
    je hang         ; If 0, we are done
    mov ah, 0x0E    ; BIOS teletype function
    int 0x10        ; Call BIOS
    jmp print_loop

hang:
    jmp $           ; Infinite loop to keep the CPU busy

msg db 'Hello from my custom bootloader!', 0

; 3. Fill the rest of the 512 bytes with zeros
times 510-($-$$) db 0

; 4. Add the magic boot signature
dw 0xaa55
