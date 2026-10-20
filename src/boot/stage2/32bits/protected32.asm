[bits 32]

null_descriptor                     equ     0x00
kernelcode_32bits_descriptor        equ     0x08
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

    call    kernel_stack_compute

    ; if not long mode, we check and jump to kernel here!
    mov     esi, kernel_info.required_cpu       ; take ADDR as arg btw
    call    kernel_check_required_cpu
    jc      .stop
    call    kernel_check_required_flags
    jc      .stop

    call    check_long_mode_paging              ; ret carry if long is needed
    jc      jmp_long_mode

    ; JUMPING TO KERNEL. AFTER 8k lines of code, finally launching the rocket!
    mov     eax, boot_info
    mov     di, kerneldata_32bits_descriptor

    mov     ecx, dword [boot_info.effective_load_address]   ; design said it should be belwo 32 bit, so dword is safe
    mov     edx, dword [kernel_info.entry32]
    add     ecx, edx

    mov     dword [far_ptr], ecx
    mov     word  [far_ptr + 4], kernelcode_32bits_descriptor

    jmp     far [far_ptr]      ; dint even know you can do shit like this in NASM

    hlt     ; if jump fail halt

.stop:
    mov     edi, msg_requirement_not_met
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    call    halt32

jmp_long_mode:
    ; turning paging on
    mov     ecx, 0xC0000080
    rdmsr   ; read
    or      eax, 1 << 8 ; long mode enable
    wrmsr   ; write

    mov     eax, cr0
    or      eax, 1 << 31
    mov     cr0, eax
    
    jmp     kernelcode_64bits_descriptor:long64_entry ; misleading name change later
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

far_ptr:
    dd 0                       ; 32-bit offset
    dw 0                       ; 16-bit selector


%include "src/boot/stage2/32bits/helper/analysis_functions_32.asm"
%include "src/boot/stage2/32bits/helper/vga_driver.asm"
%include "src/boot/stage2/32bits/helper/graphic_driver.asm"
%include "src/boot/stage2/32bits/helper/terminal_interface.asm"
%include "src/boot/stage2/32bits/helper/32bits_message.asm"
%include "src/boot/stage2/32bits/helper/paging.asm"
%include "src/boot/stage2/32bits/helper/pre_kernel_jmp_check.asm"
%include "src/boot/stage2/32bits/helper/stack_configuration.asm"

%include "src/boot/stage2/64bits/long64.asm"
