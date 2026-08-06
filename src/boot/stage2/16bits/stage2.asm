[bits 16]
[org 0x7E00]
; --------------- MAIN FUCNTION (basically) --------------- 
stage2_entry:
    ; environmental setup, already did this in stage 1, but JUST TO MAKE SURE!
    cli
    xor     ax, ax
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, 0x7c00
    sti
    
    mov     [boot_info.boot_drive], dl

    mov     si, msg_stage2_entry
    call    print_loop

    mov     si, msg_attempt_cpuid   
    call    print_loop
    call    get_cpuid

    mov     si, msg_attempt_a20
    call    print_loop
    call    enable_a20

    mov     si, msg_attempt_e820
    call    print_loop
    call    detect_memory_e820

    mov     si, msg_attempt_sanitation
    call    print_loop
    call    memory_map_sanitation

    mov     si, msg_attempt_kernel_load
    call    print_loop
    call    kernel_load

    mov     si, msg_attempt_header_read
    call    print_loop
    call    kernel_header_read

    ; coming for 32 mode. finally, I have escape the shackle of 16 bits programing!
    cli
    in      al, 0x70            ; Read current CMOS state
    or      al, 0x80            ; Set bit 7 to mask NMIs
    out     0x70, al            ; Send to port 0x70 (cmos)
    in      al, 0x71            ; just a dummy read to clear bus, dangling 0x70 port is dangerous, or so I was told

    lgdt    [gdt_descriptor]    ; loading gdt to gdtr
    mov     eax, cr0            ; I just discover that I can use 32 bits regs in real mode...
    or      eax, 1              ; turn the first bits of cr0 on (Protection Enable, PE bits)
    push    eax

    call    print_handling
    jc      .jmp32

    mov     si, msg_gdt
    call    print_loop
    mov     si, msg_far_jump    ; print stuff before interupt cant be call!
    call    print_loop

.jmp32:
    pop     eax
    mov     cr0, eax            ; protected mode officially on
    jmp     kernelcode_32bits_descriptor:protected32_entry

; ---------- functions ---------- 
%include "src/boot/stage2/16bits/helper/a20.asm"
%include "src/boot/stage2/16bits/helper/e820.asm"
%include "src/boot/stage2/16bits/helper/cpuid.asm"
%include "src/boot/stage2/16bits/helper/basic_print.asm"
%include "src/boot/stage2/16bits/helper/kernel_load.asm"
%include "src/boot/stage2/16bits/helper/structure_and_table.asm"
%include "src/boot/stage2/16bits/helper/16bits_message.asm"
%include "src/boot/stage2/16bits/helper/vbe.asm"

; --------------- small halt functions ---------------
halt:
    ; halt the cpu
    mov     si, msg_cpu_halted
    call    print_loop
.halt_loop:
    cli
    hlt
    jmp     .halt_loop

; --------------- bios cursor functions --------------
get_bios_cursor:
    ; need it because I dont want to clear screen in 32 protected mode
    ; it save cursors location as flat index
    xor     ebx, ebx
    mov     ah, 0x03        ; BIOS function 0x03: Read Cursor Position
    mov     bh, 0           ; Page number 0
    int     0x10            ; Call BIOS video interrupt
    
    ; return: 
    ; DH = Row (0-24)
    ; DL = Column (0-79)

    ; Convert Row and Column into a single flat index: (Row * 80) + Column
    movzx   eax, dh         ; EAX = Row
    imul    eax, 80         ; EAX = Row * 80
    movzx   ebx, dl         ; EBX = Column
    add     eax, ebx        ; EAX = (Row * 80) + Column

    mov     [scratchpad], eax 
    ret

; ---------- just other stuff ----------
    scratchpad      equ     0x1000
%include "src/boot/stage2/32bits/protected32.asm"  ; we seperate the 32bit code, look cleaner. It already a mess here.
times 36864-($-$$)   db      0
