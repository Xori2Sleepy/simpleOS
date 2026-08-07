[bits 64]
default abs
; duplicated code for 64 bits stuff
draw_pixel_64:
    ; currently only 32 bpp supported
    ; input: x in edi ; input y in esi ; edx = color
    ; off set calculation 
    mov     al, byte [boot_info.vbe_bpp]
    shr     al, 3

    movzx   eax, al
    imul    eax, edi        ; edi useless now
    movzx   edi, word [boot_info.vbe_pitch]
    imul    esi, edi
    add     eax, esi
    ; address calculation
    mov     edi, [boot_info.vbe_framebuffer]
    lea     eax, [rdi + rax]
    ; move color into address
    mov     [rax], edx
    ret

calculate_grid_data_64:
    ; input: font width in edi; font height in esi ; letters spacing in edx ; lines spacing in ecx
    ; output: NA
    ; clobbered: eflags ; eax ; edx
    mov     [vbe_info.bitmap_width], edi
    mov     [vbe_info.bitmap_height], esi

    add     edi, edx
    mov     [vbe_info.true_grid_width], edi
    add     esi, ecx
    mov     [vbe_info.true_grid_height], esi

    movzx   eax, word [boot_info.vbe_width]
    xor     edx, edx
    div     edi             ; EDX:EAX / EDI
    mov     [vbe_info.max_col], eax
    mov     [vbe_info.rem_x], edx    ; remnent pixel

    movzx   eax, word [boot_info.vbe_height]
    xor     edx, edx
    div     esi
    mov     [vbe_info.max_row], eax
    mov     [vbe_info.rem_y], edx

    ret

draw_char_64:
    ; currently only 32
    ; input: row coordinate in edi ; col coordinate in esi ; ASCII char in edx ; color in structure ; control bits 0 for mode
    ; output: NA
    ; clobbered:
    ; note: [ASCII_lookup_table + ascii char #] = pointer to char bit map
    ;     : control bits 0 = on -> absolute move ; off -> relative to cursor
    ;     : bits 4 -> background color 1 = actiave

    ; convert grid offset to pixel offset
    mov     ax, [vbe_info.control_flag]
    and     ax, 1           ; isolate LSB
    test    ax, ax          ; if bits on = absolute ; off = relative cursor
    jnz     .absolute       ; on abs
    mov     edi, [vbe_info.cursor_row]
    mov     esi, [vbe_info.cursor_col]

.absolute:
    push    rdx
    mov     eax, [vbe_info.true_grid_height]
    xor     edx, edx
    mul     edi
    mov     edi, eax

    mov     eax, [vbe_info.true_grid_width]
    xor     edx, edx
    mul     esi
    mov     esi, eax
    pop     rdx

    mov     edx, [ASCII_lookup_table + rdx * 4]
    ; write to grid logic
    xor     ecx, ecx        ; row counter
.char_loop:
    mov     al, [rdx + rcx] ; first row (byte) into al
    xor     ebx, ebx        ; col counter

.draw_row_loop:
    shl     al, 1           ; extract bit into carry (this is a MSB and LSB bs)
    jc      .draw
 
    push    rax
    push    rdi
    push    rsi
    ; we need to move edi + ecx to esi and esi + edx to edi, confusing I know!
    mov     ax, word [vbe_info.control_flag]
    and     ax, 16          ; 4th bits isolated 
    test    ax, ax
    jz      .skip_background
    mov     eax, esi
    add     edi, ecx
    mov     esi, edi        ; esi = edi + ecx <- row address + row counter
    add     eax, ebx
    mov     edi, eax        ; edi = esi + edx <- col address + col counter

    mov     edx, [vbe_info.bg_color32]
    call    draw_pixel_64
.skip_background:
    pop     rsi
    pop     rdi
    pop     rax

    inc     ebx
    cmp     ebx, 8          ; too much
    je      .next_row
    jmp     .draw_row_loop
    
.draw:
    push    rax
    push    rdi
    push    rsi

    ; we need to move edi + ecx to esi and esi + edx to edi, confusing I know!
    mov     eax, esi
    add     edi, ecx
    mov     esi, edi        ; esi = edi + ecx <- row address + row counter
    add     eax, ebx
    mov     edi, eax        ; edi = esi + edx <- col address + col counter

    mov     edx, [vbe_info.fg_color32]
    call    draw_pixel_64

    pop     rsi
    pop     rdi
    pop     rax

    inc     ebx             ; next pixel in the row (col inc)
    cmp     ebx, 8          ; too much
    je      .next_row
    jmp     .draw_row_loop

.next_row:
    inc     ecx             ; row counter
    cmp     ecx, 8          ; too much
    je      .done
    jmp     .char_loop

.done:
    ret

draw_string_64:
    ; input: pointer in edi ; no mode -> if user want abs string print, remember old address and uses mov_cursor 
    ; output: NA
    ; clobbered:
    push    rbx
    mov     ebx, [vbe_info.bg_color32]
    push    rbx
    mov     ebx, [vbe_info.fg_color32]
    push    rbx
    
    mov     bx, [vbe_info.control_flag]
    and     bx, 8           ; on = esc ; off = disable

    mov     esi, edi
    mov     ax, [vbe_info.control_flag]
    push    rax             ; function are responsible for control flag perservation
    and     ax, -4          ; turn bit 0 and 1 off (selecte relative print char and incrimental cursor move)
    mov     [vbe_info.control_flag], ax
    xor     eax, eax

.loop:
    lodsb                   ; load char from [esi] into AL
    movzx   edx, al

    cmp     edx, 0
    je      .done
    test    bx, bx          ; esc seq bit
    jz      .skip_esc

    cmp     edx, 92         ; if bit on esc seq can be detected
    je      .esc_seq

.skip_esc:
    cmp     edx, 10
    je      .line_feed
    cmp     edx, 13
    je      .carriage_return

    push    rsi 
    call    draw_char_64       ; auto translate ASCII to printable pixel

    xor     edi, edi
    mov     esi, 1
    call    vbe_move_cursor_64

    pop     rsi
    jmp     .loop

.done:
    pop     rax              ; we return og flags to memory
    mov     [vbe_info.control_flag], ax
    pop     rbx
    mov     [vbe_info.fg_color32], ebx
    pop     rbx
    mov     [vbe_info.bg_color32], ebx      ; perserving og color so esc seq doesnt change it
    pop     rbx
    ret

.line_feed:
    push    rsi
    mov     edi, 1
    xor     esi, esi
    call    vbe_move_cursor_64
    pop     rsi
    jmp     .loop

.carriage_return:
    push    rsi
    mov     ax, [vbe_info.control_flag]
    push    rax
    or      ax, 2          ; absolute
    mov     [vbe_info.control_flag], ax

    mov     edi, [vbe_info.cursor_row]
    xor     esi, esi
    call    vbe_move_cursor_64

    pop     rax
    mov     [vbe_info.control_flag], ax
    pop     rsi
    jmp     .loop

.esc_seq:
    mov     al, byte [esi]   
    movzx   edx, al

    cmp     edx, 92
    je      .backslash_handling
    cmp     edx, 'a'
    je      .bg_color_handling
    cmp     edx, 'b'
    je      .fg_color_handling

    jmp     .loop           ; nothing found? return

.backslash_handling:
    push    rsi

    mov     edx, 92
    call    draw_char_64
    xor     edi, edi
    mov     esi, 1
    call    vbe_move_cursor_64
    pop     rsi
    add     esi, 1
    jmp     .loop

.bg_color_handling:
    xor     eax, eax
    mov     al, [rsi + 1]
    call    vbe_convert_ascii2int
    shl     eax, 2
    mov     edx, vbe_color_preset_table
    mov     edx, dword [rdx + rax]
    mov     [vbe_info.bg_color32], edx
    add     esi, 2
    jmp     .loop

.fg_color_handling:
    mov     al, [rsi + 1]
    call    vbe_convert_ascii2int
    shl     eax, 2
    mov     edx, vbe_color_preset_table
    mov     edx, dword [rdx + rax]
    mov     [vbe_info.fg_color32], edx
    add     esi, 2
    jmp     .loop

vbe_clear_screen_64:
    ; no input
    ; ecx = width * height * (bpp/8) = total byte to write to buffer

    xor     edi, edi

    movzx   eax, word [boot_info.vbe_pitch]
    movzx   edx, word [boot_info.vbe_height]
    imul    eax, edx
    mov     ecx, eax        ; total byte in ecx

    mov     edi, [boot_info.vbe_framebuffer]
    cld                     ; eax, edi, ecx ready
    
    mov     al, [boot_info.vbe_bpp]
    cmp     al, 32
    je      .clear32
    cmp     al, 24
    je      .clear24
    cmp     al, 16
    je      .clear16

.clear32:
    mov     eax, [vbe_info.bg_color32]
    ; calculate left over and how many time to do stosd
    shr     ecx, 2          ; div by 4 to get instance of word size
    cld
    rep     stosd           ; ecx, eax and edi ready
    ret

.clear24:
    ; write repeating BGR bytes
    mov     al, [vbe_info.bg_color24]
    mov     ah, [vbe_info.bg_color24 + 1]
    mov     dl, [vbe_info.bg_color24 + 2]

.loop24:
    cmp     ecx, 3
    jb      .done24

    stosw
    mov     [rdi], dl
    inc     edi

    sub     ecx, 3
    jmp     .loop24

.done24:
    ret

.clear16:
    mov     ax, [vbe_info.bg_color16]
    shr     ecx, 1          ; div by 2 for word
    cld
    rep     stosw
    ret

vbe_move_cursor_64:
    ; input: row in edi ; col in esi ; control bits 1 for mode
    ; output: NA
    ; clobbered: 
    mov     ax, [vbe_info.control_flag]
    and     ax, 2           ; isolate bits 1
    test    ax, ax          ; if bits off = incrimental move ; on = absolute move
    jnz     .absolute

    mov     eax, [vbe_info.cursor_row]
    add     edi, eax
    mov     eax, [vbe_info.cursor_col]
    add     esi, eax

.absolute:
    call    vbe_normalized_64
    mov     [vbe_info.cursor_row], edi
    mov     [vbe_info.cursor_col], esi
    ret

vbe_normalized_64:
    ; input: row in edi ; col in esi ; control bits 2 for mode
    ; output: row in edi ; col in esi
    ; clobbered: 
    ; note: bit 2 on = clear 
    mov     dx, [vbe_info.control_flag]
    and     dx, 4           ; isolate bits 2 (value 4)
    mov     ecx, [vbe_info.max_row]
    mov     ebx, [vbe_info.max_col]

.normalize_col:
    cmp     esi, ebx
    jb      .normalize_row
    sub     esi, ebx        ; if esi >= limit, fall here
    inc     edi             ; inc row
    jmp     .normalize_col

.normalize_row:
    cmp     edi, ecx
    jb      .done

.wrap_top:
    cmp     dx, 4
    jne     .skip_clear

    push    rax
    push    rcx
    push    rdx
    push    rdi
    push    rsi
    call    vbe_clear_screen_64
    pop     rsi
    pop     rdi
    pop     rdx
    pop     rcx
    pop     rax

.skip_clear:
    sub     edi, ecx
    jmp     .normalize_row
.done:
    ret
    
vbe_convert_ascii2int_64:
    ; purpose: convert ascii (0 to 9 & a to z & A to Z) to raw integer based on hex
    ; input: al <- ASCII
    ; output: al
    ; clobered: flags, al
    cmp     al, '9'
    jbe     .is_digit           ; # come before letter, if it doesnt jmp it lettert
    
    or      al, 0x20            ; convert capital to lower
    sub     al, 0x57            
    ret
.is_digit:
    sub     al, 0x30
    ret

