[bits 64]
default rel

kernel_start:
kernel_header:
    .magic              dd      "QADB"
    .header_version     dd      0           ; unused right now / reserved
    .header_size        dw      kernel_header_end - kernel_header

    .kernel_version     dw      0
    .kernel_name        dd      0
    .load_address       dq      0x100000
    .image_size         dq      kernel_end - kernel_start

    .check_sum          dd      0xce6e8eef

    .alignment          dd      0           ; no used for now
    .entry32            dd      0           ; off set from image start
    .entry64            dd      kernel_enter_64
    .stack_size         dd      0x4000      ; 16 kib apparrently, more than enought for my use
    .stack_top          dd      0x300000    ; perffered stack top

    .required_cpu       dd      0001b       ; NX and SSE4.2
    ; flag: 0 NX ; 1 SYSCALL ; 2 RDTSCP ; 3 SSE4_2 ; 4 POPCNT ; 5 AES ; 6 APIC
    .flags              dd      111111b     ; backward btw
    ; flag: 0 vbe_graphic ; 1 long mode ; 2 framebuffer require ; 3 check sum ; 
    ; flag: 4 higher half ; 5 kernel reallocatable
    .minimum_memory     dq      0           ; these are for VBE stuff
    .preferred_bpp      dd      32          ; (,,> u <,,) aint this cute?
    .preferred_width    dd      1024
    .preferred_height   dd      768

    ; HOW WILL ARGUMENT BE PAST
    ; If kernel choose to enter as 64 bits: RAX <- Boot info pointer ; DI <- Data descriptor value
    ; If kernel choose to enter as 32 bits: EAX <- Boot info pointer ; DI <- Data descriptor value

kernel_header_end:
kernel_enter_64:
    ; STRICT SYSTEM V ABI, I HAVENT TOUCH C in 3 MONTHS. I love x86 and all but it time to go back to civilization;
    ; entry point
    mov     ds, di
    mov     ss, di
    mov     es, di
    mov     fs, di
    mov     gs, di
    
    ; take RDI <- Boot info pointer as input
    mov     rdi, rax
    call    kernel_setup

    hlt

%include "src/kernel/helpers/kernel_setup.asm"
%include "src/kernel/helpers/data_structure.asm"
times   (512 - (($ - kernel_start) % 512)) % 512    db   0x67
kernel_end:
