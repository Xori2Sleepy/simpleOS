[bits 64]
default abs
long64_entry:

    mov rax, 0x123456789ABCDEF0


    ; print something
    mov     edi, msg_entry_64
    mov     esi, 0x0
    mov     edx, 0xf
    call    terminal_print_string64

.halt:
    hlt
    jmp     .halt
    hlt

msg_entry_64        db      "hery je YO", 13, 10, 0
;    cli
;    mov     ax, kerneldata_32bits_descriptor
;    mov     ds, ax
;    mov     ss, ax
;    mov     es, ax 
;    mov     fs, ax
;    mov     gs, ax
;
;    mov     esp, 0x7C00

%include "src/boot/stage2/64bits/helper/graphic_driver_64.asm"
%include "src/boot/stage2/64bits/helper/vga_driver_64.asm"
%include "src/boot/stage2/64bits/helper/terminal_interface_64.asm"
