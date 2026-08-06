[bits 32]

extern null_descriptor
extern kernelcode_32bits_descriptor
extern kernelcode_64bits_descriptor
extern kerneldata_32bits_descriptor
extern bios_cursor

protected32_entry:
    cli
    mov     ax, kerneldata_32bits_descriptor
    mov     ds, ax
    mov     ss, ax
    mov     es, ax 
    mov     fs, ax
    mov     gs, ax

    mov     esp, 0x7C00

    call    terminal_initialize

    mov     edi, msg_welcome32
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    call    check_long_mode_paging

    call    halt32

; ---------------------------------------- 

halt32:
    mov     edi, msg_cpu_halted
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
.halt_loop:
    cli
    hlt
    jmp     .halt_loop

%include "src/boot/stage2/32bits/helper/analysis_functions.asm"
%include "src/boot/stage2/32bits/helper/vga_driver.asm"
%include "src/boot/stage2/32bits/helper/graphic_driver.asm"
%include "src/boot/stage2/32bits/helper/terminal_interface.asm"
%include "src/boot/stage2/32bits/helper/32bits_message.asm"
%include "src/boot/stage2/32bits/helper/paging.asm"
