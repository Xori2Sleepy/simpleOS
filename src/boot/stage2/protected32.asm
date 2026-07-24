[bits 32]
; writing this file make me relize I been taking bios interrupt for granted
; thought icl it kinda fun writing my own stuff

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

    ; dint uses 7c00 cause old 16 bits stack live there 
    ; dint uses 9fbff because apprently EBDA can grow into those area...
    mov     esp, 0x95000
    call    deconstruct_bios_cursor
    call    disable_cursor
    call    enable_cursor
    
    xor     eax, eax            ; normal mode
    call    move_cursor         ; move cursor to 0,0
    xor     esi, esi
    mov     ax, ((BG_GREEN | FG_RED) << 8) | 'B'
    call    print_char32
    
;   jmp    stop
    xor     ah, ah
    mov     esi, msg_welcome32
    call    print_string32 


    xor     eax, eax
    mov     al, 24
    call    move_cursor         ; move to row 24, col 0

    xor     ah, ah              ; defualt color
    mov     esi, msg_test_wrap
    call    print_string32
        
    jmp     stop

%include "src/boot/stage2/vga_driver.asm"
