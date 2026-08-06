[bits 64]

extern null_descriptor
extern kernelcode_32bits_descriptor
extern kernelcode_64bits_descriptor
extern kerneldata_32bits_descriptor
extern bios_cursor

long64_entry:
    mov rax, 0x123456789ABCDEF0

    ; print something
    mov     edi, msg_entry_64
    mov     esi, 0x0
    mov     edx, 0xf
    call    terminal_print_string32
msg_entry_64        db      "hery je", 13, 10, 0
;    cli
;    mov     ax, kerneldata_32bits_descriptor
;    mov     ds, ax
;    mov     ss, ax
;    mov     es, ax 
;    mov     fs, ax
;    mov     gs, ax
;
;    mov     esp, 0x7C00

