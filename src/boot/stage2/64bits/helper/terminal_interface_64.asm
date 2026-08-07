[bits 64]
default abs

terminal_initialize_64:
    ; hard coded function to prepare some random stuff
    mov     al, [boot_report]
    and     al, 8               ; isolate 3rd bit
    test    al, al
    jz      .vga

.vbe:
    mov     edi, 8
    mov     esi, 8
    mov     edx, 3
    mov     ecx, 5
    call    calculate_grid_data_64
    mov     dword [vbe_info.fg_color32], 0x00FFFFFF
    mov     dword [vbe_info.bg_color32], 0x00000000
    ret

.vga:
    call    deconstruct_bios_cursor_64
    call    disable_cursor_64
    ret

terminal_print_char64:
    ; input: char in edi ; bg color in esi (0 - f) ; fg color in edx
    mov     al, [boot_report]
    and     al, 8           ; isolate 3rd bit
    test    al, al
    jz      .vga

.vbe:
    ; no color saving stuff yet idk if i should implement or not
    mov     ax, word [vbe_info.control_flag]
    push    rax
    and     ax, -2          ; bits 0 is off for relative
    or      ax, 16          ; turn bits 4 on for bg_color print
    mov     [vbe_info.control_flag], ax

    mov     eax, dword [vbe_info.bg_color32]
    push    rax
    mov     eax, dword [vbe_info.fg_color32]
    push    rax

    mov     eax, vbe_color_preset_table
    shl     esi, 2
    mov     eax, dword [eax + esi]
    mov     [vbe_info.bg_color32], eax
    mov     eax, vbe_color_preset_table
    shl     edx, 2
    mov     eax, dword [eax + edx]
    mov     [vbe_info.fg_color32], eax
    
    mov     edx, edi
    call    draw_char_64

    pop     rax
    mov     [vbe_info.fg_color32], eax
    pop     rax
    mov     [vbe_info.bg_color32], eax
    pop     rax
    mov     [vbe_info.control_flag], ax
    ret

.vga:
    shl     esi, 4
    or      edx, esi            ; edx contain color formated for vga
    mov     eax, edi            ; al now have char
    mov     ah, dl              ; ax ready (ah + al is complete)
    xor     edi, edi            ; relative mode
    call    vga_print_char64
    ret

terminal_print_string64:
    ; input: pointer in edi ; bg color in esi (0 - f) ; fg color in edx
    ; note : esc seq is on by default, for simplicity this is unconfigurable unless we call function directly
    mov     al, [boot_report]
    and     al, 8               ; isolate 3rd bit
    test    al, al
    jz      .vga

.vbe:
    ; vbe draw string is a more abstract - modeless functions 
    ; make sure we enable clear screen top wrap as default graphic behavior
    mov     ax, [vbe_info.control_flag]
    push    rax                     ; bits 3 for esc seq (on = on) and bits 2 on for wrap top clear
    or      ax, 28                  ; turn bits 2 3 and 4 on (inc mov, esc seq act, and bg_color act)
    mov     [vbe_info.control_flag], ax

    mov     eax, dword [vbe_info.bg_color32]
    push    rax
    mov     eax, dword [vbe_info.fg_color32]
    push    rax
    
    mov     eax, vbe_color_preset_table
    shl     esi, 2
    mov     eax, dword [eax + esi]
    mov     [vbe_info.bg_color32], eax
    mov     eax, vbe_color_preset_table
    shl     edx, 2
    mov     eax, dword [eax + edx]
    mov     [vbe_info.fg_color32], eax

    ; edi already contain pointer
    call    draw_string_64
    pop     rax
    mov     [vbe_info.fg_color32], eax
    pop     rax
    mov     [vbe_info.bg_color32], eax
    pop     rax
    mov     [vbe_info.control_flag], ax
    ret

.vga:
    ; perserve esc seq flag
    ; default behavior is scroll wrap
    mov     al, [vga_control_flag]  ; my naming is inconsistent ik 
    push    rax
    mov     ah, 10b                 ; 10b scroll wrap as default vga behavior
    and     al, -4                  ; clear first 2 bits (bits 0 and 1)
    or      al, ah                  ; merge bits to turn first 2 bits into (10b)
    mov     [vga_control_flag], al
    call    enable_escape_sequence_64 ; al is clobbered

    shl     esi, 4
    or      edx, esi
    mov     ah, dl              ; dl to ah
    call    vga_print_string64  ; we already have pointer in edi
    
    pop     rax
    mov     [vga_control_flag], al     ; my naming is inconsistent ik 
    ret

terminal_clear_screen_64:
    ; input: colors in edi (as 0 - f)
    ; output: NA
    ; clobbered: 
    ; note: got lucky here i already have system to translate 1 hex digit color code to vbe color
    ;     : ALSO THIS THING DOES NOT MOVE CURSOR YOU HAVE TO DO IT YOURSELF
    mov     al, [boot_report]
    and     al, 8               ; isolate 3rd bit
    test    al, al
    jz      .vga

.vbe:
    mov     eax, dword [vbe_info.bg_color32]
    push    rax
    mov     eax, vbe_color_preset_table
    shl     edi, 2
    mov     edi, dword [eax + edi]
    mov     [vbe_info.bg_color32], edi
    call    vbe_clear_screen_64
    pop     rax
    mov     [vbe_info.bg_color32], eax
    ret

.vga:
    mov     eax, edi
    shl     eax, 4              ; convert to background color
    mov     ah, al
    call    vga_clear_screen_64 ; take one argument clobbered none
    ret

terminal_move_cursor_64:
    ; input: row in edi ; col in esi 
    ; output: NA
    ; clobbered: 
    ; note: This function is purely incrimental (we dont trust user with abs move
    ;     : as that mode does not have safeguard if users went out of bound
    mov     al, [boot_report]
    and     al, 8               ; isolate 3rd bit
    test    al, al
    jz      .vga

.vbe:
    mov     ax, [vbe_info.control_flag]
    push    rax
    and     ax, -3              ; clear bits 1
    mov     [vbe_info.control_flag], ax
    call    vbe_move_cursor_64
    pop     rax
    mov     [vbe_info.control_flag], ax
    ret

.vga:
    ; in vga mode max value for row and col is 255!
    mov     eax, -1             ; fill upper eax for incrimental move
    mov     edx, edi
    xor     al, al
    or      al, dl              ; merge the 2, also mean you cant have large edi (max 8 bits)
    mov     edx, esi
    xor     ah, ah
    or      ah, dl
    call    vga_move_cursor_64
    ret
