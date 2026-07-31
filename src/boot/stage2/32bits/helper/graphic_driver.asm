[bits 32]
; This file is using system V ABI (it meant to be reused in kernel code which I plan to do cross compliling)

draw_pixel:
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
    call   draw_pixel
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
    ; ecx = width * height * (bpp/8) = total byte to write to buffer
    xor     edx, edx
    mov     eax, [boot_info.vbe_bpp]
    shr     eax, 3          ; bpp / 8
    mov     edi, [boot_info.vbe_width]
    mul     edi             ; (bpp/8) * width -> eax
    mov     edi, [boot_info.vbe_height]
    xor     edx, edx
    mul     edi             ; (bpp/8) * width -> eax

    mov     ecx, eax
    mov     esi, eax

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
    mov     ax, [vbe_info.bg_color24]
    shr     ecx, 1          ; div by 2 for word
    and     esi, 
    cld
    rep     stosw
    mov     ecx, esi
    rep     stosb
    ret
.clear16:
    mov     ax, [vbe_info.bg_color16]
    shr     ecx, 1          ; div by 2 for word
    cld
    rep     stosb
    ret

vbe_clear_screen2:
    mov     eax, [boot_info.vbe_width]
    imul    eax, [boot_info.vbe_height]
    mov eax, [boot_info.vbe_width]
    imul eax, [boot_info.vbe_height]
    mov ecx, eax                    ; number of pixels

    mov edi, [boot_info.vbe_framebuffer]
    mov eax, [vbe_info.bg_color]
    cld

    mov edx, [boot_info.vbe_bpp]
    cmp edx, 32
    je .clear32
    cmp edx, 24
    je .clear24
    cmp edx, 16
    je .clear16
    cmp edx, 8
    je .clear8
    ret

.clear32:
    rep stosd
    ret

.clear16:
    rep stosw
    ret

.clear8:
    rep stosb
    ret

.clear24:
    ; write 3 bytes per pixel
    push ecx
.loop:
    mov [edi], ax
    shr eax, 16
    mov [edi+2], al
    ; restore eax if needed
    ; ...
    add edi, 3
    loop .loop
    pop ecx
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
    call    vbe_normalized
    mov     [vbe_info.cursor_row], edi
    mov     [vbe_info.cursor_col], esi

vbe_normalized:
    ; input: row in edi ; col in esi ; control bits 2 and 3 for mode
    ; output: row in edi ; col in esi
    ; clobbered: 
    mov     ax, [vbe_info.control_flag]
    and     ax, 12          ; isolate bits 2 and 3 ( value 4 + 8)
    
    
%include "src/boot/stage2/32bits/helper/font_table.asm"
