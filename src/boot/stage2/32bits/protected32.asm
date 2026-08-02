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
    ; ------------------------
    mov     edi, 8
    mov     esi, 8
    mov     edx, 3
    mov     ecx, 5
    call    calculate_grid_data

    mov     dword [vbe_info.fg_color32], 0x00FFFFFF
    mov     dword [vbe_info.bg_color32], 0x00000000

    mov     ax, [vbe_info.control_flag]
    and     ax, -2              ; turn LSB (print char control) off for relative print
    mov     [vbe_info.control_flag], ax

    call    vbe_clear_screen

    mov     ax, [vbe_info.control_flag]
    or      ax, 1             ; turn LSB (print char control) on for absolute
    mov     [vbe_info.control_flag], ax

    mov     ax, [vbe_info.control_flag]
    or      ax, 2             ; turn bit 1 (move abs) on for absolute cursor move
    mov     [vbe_info.control_flag], ax

    mov     ax, [vbe_info.control_flag]
    or      ax, 16            ; background write on
    mov     [vbe_info.control_flag], ax

    mov     edi, 20
    mov     esi, 2
    call    vbe_move_cursor

    mov     edi, msg_test_scroll
    call    draw_string
    mov     edi, msg_testabc
    call    draw_string
    mov     edi, msg_esc_seq_test
    call    draw_string

    mov     edi, 10
    mov     esi, 0
    mov     edx, 'A'
    call    draw_char

    mov     edi, 10
    mov     esi, 1
    mov     edx, 'b'
    call    draw_char
;----------------------------------------------------------
    mov     edi, 0x4
    call    terminal_clear_screen

    mov     edi, 'a'
    mov     esi, 0xF
    mov     edx, 0x0
    call    terminal_print_char32
    
    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, 40
    mov     esi, 50
    call    terminal_move_cursor

    mov     edi, msg_esc_seq_test
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    jmp     stop
    ; ---------------------------------------
    call    deconstruct_bios_cursor
    call    disable_cursor
    
    xor     eax, eax            ; normal mode
    call    vga_move_cursor     ; move cursor to 0,0
    xor     edi, edi
    mov     ax, ((BG_GREEN | FG_RED) << 8) | 'B'
    call    vga_print_char32
    
    xor     ah, ah              ; arg for color
    mov     edi, msg_welcome32 
    call    vga_print_string32 

    mov     al, [vga_control_flag]     ; setting mode
    and     al, 11111000b       ; wiping lower bit
    or      al, 110b            ; merge bits
    mov     [vga_control_flag], al
    
    xor     eax, eax
    mov     al, 24
    call    vga_move_cursor     ; move to row 24, col 0

    xor     ah, ah              ; defualt color
    mov     edi, msg_test_wrap
    call    vga_print_string32

    xor     ah, ah
    mov     edi, msg_esc_seq_test
    call    vga_print_string32


    xor     ah, ah
    mov     edi, msg_test_scroll
    call    vga_print_string32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ; -------------------------------------       

    mov     edi, 0x4
    call    terminal_clear_screen

    mov     edi, 'a'
    mov     esi, 0xF
    mov     edx, 0x0
    call    terminal_print_char32

    mov     edi, msg_test_scroll
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ; ------------------------------------
    xor     ah, ah
    mov     edi, msg_test_scroll
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
msg_esc_seq_test    db      "\hey\\\a1sponsive?\\holycow\a2a\a4\b6haha", 13, 10, 0
msg_test            db      "hello", 0
msg_testabc         db      "abcdefhijklmnopqrstuvwxyz1234567890()*%?<>|", 13, 10, 0
msg_test_msg        db      "What sup man this is most likely some of the ugliest font you seen ever", 0

%include "src/boot/stage2/32bits/helper/vga_driver.asm"
%include "src/boot/stage2/32bits/helper/graphic_driver.asm"
%include "src/boot/stage2/32bits/helper/terminal_interface.asm"
