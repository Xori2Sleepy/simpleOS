[bits 32]
; Using system V ABI (it meant to be reused in kernel code which I plan to do cross compliling)

draw_pixel:
    ; currently only 32 bpp supported
    ; input: x in edi ; input y in esi ; edx = color
    ; off set calculation 
    mov     al, [boot_info.vbe_bpp]
    shr     al, 3

    movzx   eax, al
    imul    eax, edi        ; edi useless now
    movzx   edi, word [boot_info.vbe_pitch]
    imul    esi, edi
    add     eax, esi
    ; address calculation
    mov     edi, [boot_info.vbe_framebuffer]
    lea     eax, [edi + eax]
    ; move color into address
    mov     [eax], edx
    ret

calculate_grid_data:
    ; input: font width in edi; font height in esi ; letters spacing in edx ; lines spacing in ecx
    ; output: NA
    ; clobbered: eflags ; eax ; edx
    mov     [vbe_info.bitmap_width], edi
    mov     [vbe_info.bitmap_height], esi

    add     edi, edx
    mov     [vbe_info.true_grid_width], edi
    add     esi, ecx
    mov     [vbe_info.true_grid_height], esi

    mov     eax, [boot_info.vbe_width]
    xor     edx, edx
    div     edi             ; EDX:EAX / EDI
    mov     [vbe_info.max_col], eax
    mov     [vbe_info.rem_x], edx    ; remnent pixel

    mov     eax, [boot_info.vbe_height]
    xor     edx, edx
    div     esi
    mov     [vbe_info.max_row], eax
    mov     [vbe_info.rem_y], edx

    ret

draw_char:
    ; currently only 32
    ; input: row coordinate in edi ; col coordinate in esi ; ASCII char in edx ; color in structure ; control bits 1 for mode
    ; output: NA
    ; clobbered:
    ; note: [ASCII_lookup_table + ascii char #] = pointer to char bit map
    ;     : control bits 0 = on -> absolute move ; off -> relative to cursor

    ; convert grid offset to pixel offset
    mov     ax, [vbe_info.control_flag]
    and     ax, 1           ; isolate LSB
    test    ax, ax          ; if bits on = absolute ; off = relative cursor
    jnz     .absolute       ; on abs
    mov     edi, [vbe_info.cursor_row]
    mov     esi, [vbe_info.cursor_col]

.absolute:
    push    edx
    mov     eax, [vbe_info.true_grid_height]
    xor     edx, edx
    mul     edi
    mov     edi, eax

    mov     eax, [vbe_info.true_grid_width]
    xor     edx, edx
    mul     esi
    mov     esi, eax
    pop     edx

    mov     edx, [ASCII_lookup_table + edx * 4]
    ; write to grid logic
    xor     ecx, ecx        ; row counter
.char_loop:
    
    mov     al, [edx + ecx] ; first row (byte) into al
    xor     ebx, ebx        ; col counter

.draw_row_loop:
    shl     al, 1           ; extract bit into carry (this is a MSB and LSB bs)
    jc      .draw

    inc     ebx
    cmp     ebx, 8          ; too much
    je      .next_row
    jmp     .draw_row_loop
    
.draw:
    pushad
    ; we need to move edi + ecx to esi and esi + edx to edi, confusing I know!
    mov     eax, esi
    add     edi, ecx
    mov     esi, edi        ; esi = edi + ecx <- row address + row counter
    add     eax, ebx
    mov     edi, eax        ; edi = esi + edx <- col address + col counter

    mov     edx, [vbe_info.fg_color]
    call    draw_pixel

    popad

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

vbe_clear_screen:
    ; no input
    ; ecx = width * height * (bpp/8) = total byte to write to buffer
    xor     eax, eax
    mov     al, [boot_info.vbe_bpp]
    shr     al, 3          ; bpp / 8

    xor     edi, edi

    movzx   eax, word [boot_info.vbe_pitch]
    movzx   edx, word [boot_info.vbe_height]
    imul    eax, edx
    mov     ecx, eax

    mov     edi, [boot_info.vbe_framebuffer]
    cld                     ; eax, edi, ecx ready
    
    mov     edx, [boot_info.vbe_bpp]
    cmp     edx, 32
    je      .clear32
    cmp     edx, 24
    je      .clear24
    cmp     edx, 16
    je      .clear16

.clear32:
    mov     eax, [vbe_info.bg_color32]
    ; calculate left over and how many time to do stosd
    shr     ecx, 2          ; div by 4 to get instance of word size
    cld
    rep     stosd
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
    mov     [edi], dl
    inc     edi

    sub     ecx, 3
    jmp     .loop24

.done24:
    ret

.clear16:
    mov     ax, [vbe_info.bg_color16]
    shr     ecx, 1          ; div by 2 for word
    cld
    rep     stosb
    ret

vbe_move_cursor:
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
    push    edi
    push    esi
    call    vbe_normalized
    pop     esi
    pop    edi
    mov     [vbe_info.cursor_row], edi
    mov     [vbe_info.cursor_col], esi

vbe_normalized:
    ; input: row in edi ; col in esi ; control bits 2 for mode
    ; output: row in edi ; col in esi
    ; clobbered: 
    mov     dx, [vbe_info.control_flag]
    and     dx, 4           ; isolate bits 2 (value 4)

.normalize_col:
    mov     ecx, [vbe_info.max_row]
    mov     ebx, [vbe_info.max_col]
    inc     ecx
    inc     ebx

    cmp     esi, ebx
    jb      .normalize_row
    sub     esi, ebx        ; if esi > limit, fall here
    inc     edi             ; inc row
    jmp     .normalize_col

.normalize_row:
    cmp     edi, ecx
    jb      .done

.wrap_top:
    cmp     dx, 1b
    jne     .skip_clear

    push    eax
    push    ecx
    push    edx
    call    vbe_clear_screen
    push    eax
    push    ecx
    push    edx

.skip_clear:
    sub     edi, ecx
    jmp     .normalize_row

.done:
    ret
    
%include "src/boot/stage2/32bits/helper/font_table.asm"
