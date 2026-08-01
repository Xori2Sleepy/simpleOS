[bits 32]

terminal_print_char32:

terminal_print_string32:

terminal_clear_screen:
    ; input: colors in edi (as 0 - f)
    ; output: NA
    ; clobbered: 
    ; note: got lucky here i already have system to translate 1 hex digit color code to vbe color
    mov     al, [boot_report]
    and     al, 8               ; isolate 3rd bit
    test    al, al
    jz      .vga

.vbe:
    mov     eax, dword [vbe_info.bg_color32]
    push    eax
    mov     eax, vbe_color_preset_table
    shl     edi, 2
    mov     edi, dword [eax + edi]
    mov     [vbe_info.bg_color32], edi
    call    vbe_clear_screen
    pop     eax
    mov     [vbe_info.bg_color32], eax
    ret

.vga:
    mov     eax, edi
    shl     eax, 1              ; convert to background color
    mov     ah, al
    call    vga_clear_screen    ; take one argument clobbered none
    ret

terminal_move_cursor:

