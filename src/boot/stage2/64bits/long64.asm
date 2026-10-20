[bits 64]
default abs

kerneldata_32bits_descriptor        equ     0x18

long64_entry:
    mov     ax, 0
    mov     ds, ax
    mov     ss, ax
    mov     es, ax 
    mov     fs, ax
    mov     gs, ax
    mov     esp, 0x7C00
    call    terminal_initialize_64

    mov     eax, [boot_report]
    or      eax, 1 << 6         ; set bits 6 to 1 (long mode)
    mov     [boot_report], eax

    mov     edi, msg_entry_64           ; take eax as argument still
    mov     esi, 0x0
    mov     edx, 0xf
    call    terminal_print_string64

    mov     edi, msg_kernel_jump
    mov     esi, 0x0
    mov     edx, 0xf
    call    terminal_print_string64

    mov     rax, boot_info
    mov     di, kerneldata_32bits_descriptor

    mov     rcx, [boot_info.effective_load_address]
    movzx   rdx, dword [kernel_info.entry64]
    add     rcx, rdx
    jmp     rcx             ; no need for 64 bit code descriptor
    call    halt64          ; in case it dint work out

msg_entry_64        db      "Succesfully enter long mode!", 13, 10, 0
msg_kernel_jump     db      "\b2Jumping to kernel...", 13, 10, 0

halt64:
    mov     edi, msg_cpu_halted
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string64
.halt_loop:
    cli
    hlt
    jmp     .halt_loop

%include "src/boot/stage2/64bits/helper/graphic_driver_64.asm"
%include "src/boot/stage2/64bits/helper/vga_driver_64.asm"
%include "src/boot/stage2/64bits/helper/terminal_interface_64.asm"
