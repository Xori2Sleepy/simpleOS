bits 64
default abs
; duplicated code for 64 bits stuff
; actually I did change a few thing, bc of bugs of course...
draw_pixel64:
    ; currently only 32 bpp supported
    ; input: x in edi ; y in esi ; color in edx
    ; clobbered: eflags only
    push    rax
    push    rcx

    movzx   eax, byte [boot_info.vbe_bpp]
    shr     eax, 3                  ; bytes per pixel

    imul    eax, edi                ; x * bytes per pixel
    movzx   ecx, word [boot_info.vbe_pitch]
    imul    ecx, esi                ; y * pitch
    add     eax, ecx

    mov     ecx, [boot_info.vbe_framebuffer]    ; zero-extended into rcx
    mov     [rcx + rax], edx

    pop     rcx
    pop     rax
    ret

calculate_grid_data64:
    ; input: font width in edi; font height in esi ; letters spacing in edx ; lines spacing in ecx
    ; output: NA
    ; clobbered: eflags ; eax ; edx ; edi ; esi
    mov     [vbe_info.bitmap_width], edi
    mov     [vbe_info.bitmap_height], esi

    add     edi, edx
    mov     [vbe_info.true_grid_width], edi
    add     esi, ecx
    mov     [vbe_info.true_grid_height], esi

    movzx   eax, word [boot_info.vbe_width]
    xor     edx, edx
    div     edi                     ; EDX:EAX / EDI
    mov     [vbe_info.max_col], eax
    mov     [vbe_info.rem_x], edx   ; remnant pixels

    movzx   eax, word [boot_info.vbe_height]
    xor     edx, edx
    div     esi
    mov     [vbe_info.max_row], eax
    mov     [vbe_info.rem_y], edx

    ret

draw_char64:
    ; currently only 32 bpp
    ; input: row in edi ; col in esi ; ASCII char in dl ; colors in vbe_info ; control flag
    ; output: NA
    ; clobbered: eflags only
    ; note: [ASCII_lookup_table + ascii * 4] = pointer to char bitmap (dd entries, so the
    ;       font must live below 4 GiB; if convert the table to dq, see marked line)
    ;     : control bit 0 on -> absolute position (edi/esi) ; off -> use cursor
    ;     : control bit 4 on -> also paint background pixels
    push    rax
    push    rbx
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    push    r8
    push    r9
    push    r10

    test    word [vbe_info.control_flag], 1
    jnz     .absolute
    mov     edi, [vbe_info.cursor_row]
    mov     esi, [vbe_info.cursor_col]

.absolute:
    ; grid offset -> pixel offset
    mov     r8d, [vbe_info.true_grid_height]
    imul    r8d, edi                ; r8d = pixel Y of the cell
    mov     r9d, [vbe_info.true_grid_width]
    imul    r9d, esi                ; r9d = pixel X of the cell

    movzx   edx, dl
    lea     rax, [ASCII_lookup_table]
    mov     r10d, [rax + rdx * 4]   ; r10 = bitmap pointer (use "mov r10, [rax + rdx*8]" for dq table)

    xor     ecx, ecx                ; row counter
.row_loop:
    mov     al, [r10 + rcx]         ; one bitmap row
    xor     ebx, ebx                ; column counter

.col_loop:
    shl     al, 1                   ; MSB first, bit goes to carry
    jc      .fg

    test    word [vbe_info.control_flag], 16
    jz      .next_pixel             ; background disabled
    mov     edx, [vbe_info.bg_color32]
    jmp     .plot

.fg:
    mov     edx, [vbe_info.fg_color32]

.plot:
    lea     edi, [r9 + rbx]         ; x = cell X + col
    lea     esi, [r8 + rcx]         ; y = cell Y + row
    call    draw_pixel64

.next_pixel:
    inc     ebx
    cmp     ebx, 8
    jb      .col_loop

    inc     ecx
    cmp     ecx, 8
    jb      .row_loop

    pop     r10
    pop     r9
    pop     r8
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rbx
    pop     rax
    ret

draw_string64:
    ; input: pointer in rdi (NUL terminated)
    ;        no mode -> if you want abs string print, move the cursor first with vbe_move_cursor
    ; output: NA
    ; clobbered: eflags only (colors and control flag are restored on exit)
    ; escape sequences (only when control bit 3 is on):
    ;     \\   -> literal backslash
    ;     \aX  -> background color = preset X (hex digit)
    ;     \bX  -> foreground color = preset X (hex digit)
    push    rax
    push    rbx
    push    rdx
    push    rsi
    push    rdi

    mov     eax, [vbe_info.bg_color32]
    push    rax
    mov     eax, [vbe_info.fg_color32]
    push    rax
    movzx   eax, word [vbe_info.control_flag]
    push    rax                     ; functions are responsible for control flag preservation

    mov     ebx, eax
    and     ebx, 8                  ; ebx != 0 -> escape sequences enabled
    and     eax, 0xFFFC             ; turn bit 0 and 1 off (relative char, incremental cursor)
    mov     [vbe_info.control_flag], ax

    mov     rsi, rdi

.loop:
    lodsb                           ; al = [rsi++]
    movzx   edx, al

    test    edx, edx
    jz      .done
    test    ebx, ebx
    jz      .skip_esc

    cmp     edx, 92                 ; '\'
    je      .esc_seq

.skip_esc:
    cmp     edx, 10
    je      .line_feed
    cmp     edx, 13
    je      .carriage_return

    call    draw_char64              ; ASCII -> pixels at the cursor

    push    rsi
    xor     edi, edi
    mov     esi, 1
    call    vbe_move_cursor64
    pop     rsi
    jmp     .loop

.done:
    pop     rax
    mov     [vbe_info.control_flag], ax
    pop     rax
    mov     [vbe_info.fg_color32], eax
    pop     rax
    mov     [vbe_info.bg_color32], eax  ; restore colors so esc seq doesn't leak out
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rbx
    pop     rax
    ret

.line_feed:
    push    rsi
    mov     edi, 1
    xor     esi, esi
    call    vbe_move_cursor64
    pop     rsi
    jmp     .loop

.carriage_return:
    push    rsi
    movzx   eax, word [vbe_info.control_flag]
    push    rax
    or      ax, 2                   ; absolute move
    mov     [vbe_info.control_flag], ax

    mov     edi, [vbe_info.cursor_row]
    xor     esi, esi
    call    vbe_move_cursor64

    pop     rax
    mov     [vbe_info.control_flag], ax
    pop     rsi
    jmp     .loop

.esc_seq:
    movzx   edx, byte [rsi]

    cmp     edx, 92
    je      .backslash_handling
    cmp     edx, 'a'
    je      .bg_color_handling
    cmp     edx, 'b'
    je      .fg_color_handling

    jmp     .loop                   ; unknown sequence, ignore the backslash

.backslash_handling:
    push    rsi
    mov     edx, 92
    call    draw_char64
    xor     edi, edi
    mov     esi, 1
    call    vbe_move_cursor64
    pop     rsi
    inc     rsi
    jmp     .loop

.bg_color_handling:
    movzx   eax, byte [rsi + 1]
    call    vbe_convert_ascii2int64
    and     eax, 0xF
    lea     rdx, [vbe_color_preset_table]
    mov     edx, [rdx + rax * 4]
    mov     [vbe_info.bg_color32], edx
    add     rsi, 2
    jmp     .loop

.fg_color_handling:
    movzx   eax, byte [rsi + 1]
    call    vbe_convert_ascii2int64
    and     eax, 0xF
    lea     rdx, [vbe_color_preset_table]
    mov     edx, [rdx + rax * 4]
    mov     [vbe_info.fg_color32], edx
    add     rsi, 2
    jmp     .loop

vbe_clear_screen64:
    ; no input
    ; fills the whole framebuffer with the background color
    ; clobbered: eflags only
    push    rax
    push    rcx
    push    rdx
    push    rdi

    movzx   eax, word [boot_info.vbe_pitch]
    movzx   edx, word [boot_info.vbe_height]
    imul    eax, edx
    mov     ecx, eax                ; total bytes in ecx (rcx zero-extended)

    mov     edi, [boot_info.vbe_framebuffer]    ; rdi zero-extended
    cld

    movzx   eax, byte [boot_info.vbe_bpp]
    cmp     eax, 32
    je      .clear32
    cmp     eax, 24
    je      .clear24
    cmp     eax, 16
    je      .clear16
    cmp     eax, 8
    je      .clear8
    jmp     .exit                   ; unsupported depth

.clear32:
    mov     eax, [vbe_info.bg_color32]
    shr     ecx, 2                  ; bytes -> dwords
    rep     stosd
    jmp     .exit

.clear24:
    ; write repeating BGR bytes
    mov     al, [vbe_info.bg_color24]
    mov     ah, [vbe_info.bg_color24 + 1]
    mov     dl, [vbe_info.bg_color24 + 2]
.loop24:
    cmp     ecx, 3
    jb      .exit

    stosw
    mov     [rdi], dl
    inc     rdi

    sub     ecx, 3
    jmp     .loop24

.clear16:
    mov     ax, [vbe_info.bg_color16]
    shr     ecx, 1                  ; bytes -> words
    rep     stosw
    jmp     .exit

.clear8:
    mov     al, [vbe_info.bg_color8]
    rep     stosb

.exit:
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rax
    ret

vbe_move_cursor64:
    ; input: row in edi ; col in esi ; control bit 1: off = relative move ; on = absolute move
    ; output: NA
    ; clobbered: eflags ; edi ; esi
    test    word [vbe_info.control_flag], 2
    jnz     .absolute

    add     edi, [vbe_info.cursor_row]
    add     esi, [vbe_info.cursor_col]

.absolute:
    call    vbe_normalized64
    mov     [vbe_info.cursor_row], edi
    mov     [vbe_info.cursor_col], esi
    ret

vbe_normalized64:
    ; input: row in edi ; col in esi ; control bit 2: on = clear screen when wrapping past bottom
    ; output: row in edi ; col in esi
    ; clobbered: eflags ; edi ; esi
    push    rbx
    push    rcx
    push    rdx

    movzx   edx, word [vbe_info.control_flag]
    and     edx, 4                  ; isolate bit 2
    mov     ecx, [vbe_info.max_row]
    mov     ebx, [vbe_info.max_col]

    ; grid not calculated yet -> avoid an endless loop
    test    ebx, ebx
    jz      .done
    test    ecx, ecx
    jz      .done

.normalize_col:
    cmp     esi, ebx
    jb      .normalize_row
    sub     esi, ebx                ; col >= limit: wrap to next row
    inc     edi
    jmp     .normalize_col

.normalize_row:
    cmp     edi, ecx
    jb      .done

    test    edx, edx
    jz      .skip_clear
    call    vbe_clear_screen64        ; preserves all registers

.skip_clear:
    sub     edi, ecx
    jmp     .normalize_row

.done:
    pop     rdx
    pop     rcx
    pop     rbx
    ret

vbe_convert_ascii2int64:
    ; purpose: convert ascii (0-9 & a-f & A-F) to its hex value
    ; input: al <- ASCII
    ; output: al
    ; clobbered: eflags, al
    cmp     al, '9'
    jbe     .is_digit               ; digits come before letters

    or      al, 0x20                ; capital -> lower
    sub     al, 0x57
    ret
.is_digit:
    sub     al, 0x30
    ret
