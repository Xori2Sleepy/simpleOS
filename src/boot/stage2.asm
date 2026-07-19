[bits 16]
[org 0x7E00]

start:
    mov si, msg

.loop:
    lodsb
    or al, al
    jz $

    mov ah, 0x0E
    int 0x10
    jmp .loop

msg db "Hello from stage 2!",0
