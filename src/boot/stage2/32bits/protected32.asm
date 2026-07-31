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

    mov     esp, 0x7C00
    
    mov     esi, [boot_info.vbe_framebuffer]
    mov     dword [esi], 0x00FF00FF

    mov     esi, 200
    mov     edi, 200
    mov     ecx, 0x00FF00FF
    call    draw_pixel
    
    mov     esi, 1
    mov     edi, 1
    mov     edx, 'A'
    mov     ecx, 0x00FF00FF
    call    draw_char

    mov     esi, 1
    mov     edi, 2
    mov     edx, 'b'
    mov     ecx, 0x00FF00FF
    call    draw_char

    jmp     stop

    call    deconstruct_bios_cursor
    call    disable_cursor
    call    enable_cursor
    
    xor     eax, eax            ; normal mode
    call    move_cursor         ; move cursor to 0,0
    xor     edi, edi
    mov     ax, ((BG_GREEN | FG_RED) << 8) | 'B'
    call    vga_print_char32
    
    xor     ah, ah              ; arg for color
    mov     edi, msg_welcome32 
    call    vga_print_string32 

    mov     al, [VGA_flags]     ; setting mode
    and     al, 11111000b       ; wiping lower bit
    or      al, 110b            ; merge bits
    mov     [VGA_flags], al
    
    xor     eax, eax
    mov     al, 24
    call    move_cursor         ; move to row 24, col 0

    xor     ah, ah              ; defualt color
    mov     edi, msg_test_wrap
    call    vga_print_string32

    xor     ah, ah
    mov     edi, msg_esc_seq_test
    call    vga_print_string32


    xor     ah, ah
    mov     edi, msg_test_scroll
    call    vga_print_string32
        
    jmp     stop


msg_welcome32       db      "Successfully enter 32bits protected mode.", 13, 10, 0
msg_test_wrap       db      "Testing screen wrapping mechanism right now we need to fill in"
                    db      " alot of stuff blah blah balh blah blah skibidi 67 brain rotted"
                    db      " grr hola cowboy es1p 205 512 2301 actung, actung, actung"
                    db      " lingan guu lingan guu blah 91238123098", 13, 10, 0
msg_test_scroll     db      "11111111111111111111111111111111111111111111111111111111111111111111111111111111"
                    db      "22222222222222222222222222222222222222222222222222222222222222222222222222222222"
                    db      "33333333333333333333333333333333333333333333333333333333333333333333333333333333" 
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444"
                    db      "44444444444444444444444444444444444444444444444444444444444444444444444444444444", 13, 10, 0
msg_esc_seq_test    db      "\heyre\\sponsive?\\holycow\a4a\a6\b2haha", 13, 10, 0

%include "src/boot/stage2/32bits/helper/vga_driver.asm"
%include "src/boot/stage2/32bits/helper/graphic_driver.asm"
