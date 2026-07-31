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

calculate_grid:
    ; input: font width in edi; font height in esi 
    ; output: NA
    ; clobbered: eflags ; eax ; edx
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
    ; input: row coordinate in edi ; col coordinate in esi ; ASCII char in edx ; color in ecx
    ; output: NA
    ; clobbered:
    ; note: [ASCII_lookup_table + ascii char #] = pointer to char bit map
    mov     edx, [ASCII_lookup_table + edx * 4]
    ; convert grid offset to pixel offset
    shl     edi, 3
    shl     esi, 3
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
    add     edi, ebx        ; x - col 
    add     esi, ecx        ; y - row
    mov     edx, 0x00FF00FF
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

%include "src/boot/stage2/32bits/helper/font_table.asm"
