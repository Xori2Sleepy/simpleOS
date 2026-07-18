[bits 16]   
[org 0x7c00]
; basic stage one bootloader, really small and basic
start:
    cli
    cld            ; we uses lodsb to print stuff so we need to clear direction. Just to make sure!
    mov [BootDrive], bl
    xor ax, ax
    ; clear segment data to zero!
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00 ; Set stack pointer below the code

    ; printing message, here for testing
    mov si, msg
print_loop:
    lodsb           ; Load next byte from SI into AL
    cmp al, 0
    je hang
    mov ah, 0x0E    ; BIOS teletype function
    int 0x10        ; Call video service
    jmp print_loop

hang:
    jmp $           ; $ is the current location

BootDrive   db      0 ; we dont got no bss section so 0 is just dummy value
msg         db      'Hello from my custom bootloader!', 0

; Fill the rest of the 512 bytes with zeros
times 510-($-$$) db 0

dw 0xaa55
