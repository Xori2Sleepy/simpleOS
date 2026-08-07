[bits 32]

null_descriptor                     equ     0x00
kernelcode_32bits_descriptor        equ     0x08
kernelcode_64bits_descriptor        equ     0x10
kerneldata_32bits_descriptor        equ     0x18

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
    jc      jmp_long_mode

    call    halt32

jmp_long_mode:
   ; mov     edi, msg_long_mode_jump
    mov     esi, 0x0
    mov     edx, 0xF
 ;  call    terminal_print_string32
    
    ; turning paging on
    mov     ecx, 0xC0000080
    rdmsr   ; read
    or      eax, 1 << 8 ; long mode enable
    wrmsr   ; write

    mov     eax, cr0
    or      eax, 1 << 31
    mov     cr0, eax
    
    jmp     kernelcode_64bits_descriptor:long64_entry
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

%include "src/boot/stage2/64bits/long64.asm"

%include "src/boot/stage2/32bits/helper/analysis_functions.asm"
%include "src/boot/stage2/32bits/helper/vga_driver.asm"
%include "src/boot/stage2/32bits/helper/graphic_driver.asm"
%include "src/boot/stage2/32bits/helper/terminal_interface.asm"
%include "src/boot/stage2/32bits/helper/32bits_message.asm"
%include "src/boot/stage2/32bits/helper/paging.asm"

%include "src/boot/stage2/64bits/try.asm"
