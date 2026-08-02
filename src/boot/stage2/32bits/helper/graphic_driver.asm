[bits 32]
; Using system V ABI (it meant to be reused in kernel code which I plan to do cross compliling)
; NOTE: Code is not consistent here, some function support modular bpp, some dont. Also bits map print is not consistent
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

draw_char:
    ; currently only 32
    ; input: row coordinate in edi ; col coordinate in esi ; ASCII char in edx ; color in structure ; control bits 0 for mode
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
 
    pushad
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
    call    draw_pixel
.skip_background:
    popad

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

    mov     edx, [vbe_info.fg_color32]
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

draw_string:
    ; input: pointer in edi ; no mode -> if user want abs string print, remember old address and uses mov_cursor 
    ; output: NA
    ; clobbered:
    push    ebx
    mov     ebx, [vbe_info.bg_color32]
    push    ebx
    mov     ebx, [vbe_info.fg_color32]
    push    ebx
    
    mov     bx, [vbe_info.control_flag]
    and     bx, 8           ; on = esc ; off = disable

    mov     esi, edi
    mov     ax, [vbe_info.control_flag]
    push    eax             ; function are responsible for control flag perservation
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

    push    esi 
    call    draw_char       ; auto translate ASCII to printable pixel

    xor     edi, edi
    mov     esi, 1
    call    vbe_move_cursor

    pop     esi
    jmp     .loop

.done:
    pop     eax              ; we return og flags to memory
    mov     [vbe_info.control_flag], ax
    pop     ebx
    mov     [vbe_info.fg_color32], ebx
    pop     ebx
    mov     [vbe_info.bg_color32], ebx      ; perserving og color so esc seq doesnt change it
    pop     ebx
    ret

.line_feed:
    push    esi
    mov     edi, 1
    xor     esi, esi
    call    vbe_move_cursor
    pop     esi
    jmp     .loop

.carriage_return:
    push    esi
    mov     ax, [vbe_info.control_flag]
    push    eax
    or      ax, 2          ; absolute
    mov     [vbe_info.control_flag], ax

    mov     edi, [vbe_info.cursor_row]
    xor     esi, esi
    call    vbe_move_cursor

    pop     eax
    mov     [vbe_info.control_flag], ax
    pop     esi
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
    push    esi

    mov     edx, 92
    call    draw_char
    xor     edi, edi
    mov     esi, 1
    call    vbe_move_cursor
    pop     esi
    add     esi, 1
    jmp     .loop

.bg_color_handling:
    xor     eax, eax
    mov     al, [esi + 1]
    call    vbe_convert_ascii2int
    shl     eax, 2
    mov     edx, vbe_color_preset_table
    mov     edx, dword [edx + eax]
    mov     [vbe_info.bg_color32], edx
    add     esi, 2
    jmp     .loop

.fg_color_handling:
    mov     al, [esi + 1]
    call    vbe_convert_ascii2int
    shl     eax, 2
    mov     edx, vbe_color_preset_table
    mov     edx, dword [edx + eax]
    mov     [vbe_info.fg_color32], edx
    add     esi, 2
    jmp     .loop

vbe_clear_screen:
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
    rep     stosw
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
    ret

vbe_normalized:
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

    pushad
    call    vbe_clear_screen
    popad

.skip_clear:
    sub     edi, ecx
    jmp     .normalize_row
.done:
    ret
    
vbe_convert_ascii2int:
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

vbe_color_preset_table:
    dd      0x00000000    ; 0  Black
    dd      0x000000AA    ; 1  Blue
    dd      0x0000AA00    ; 2  Green
    dd      0x0000AAAA    ; 3  Cyan
    dd      0x00AA0000    ; 4  Red
    dd      0x00AA00AA    ; 5  Magenta
    dd      0x00AA5500    ; 6  Brown
    dd      0x00AAAAAA    ; 7  Light Gray
    dd      0x00555555    ; 8  Dark Gray
    dd      0x005555FF    ; 9  Light Blue
    dd      0x0055FF55    ; A  Light Green
    dd      0x0055FFFF    ; B  Light Cyan
    dd      0x00FF5555    ; C  Light Red
    dd      0x00FF55FF    ; D  Light Magenta
    dd      0x00FFFF55    ; E  Yellow
    dd      0x00FFFFFF    ; F  White

; -------------------- VBE information table --------------------
; uses only at bootloading stage
vbe_info:
    ; bits 0 -> write char mode, 1 -> cursor move ; 2 -> normalized mode ; 3 -> esc-seq 
    ; bits 4 -> write char background?
    .control_flag   dw      0
    .cursor_row     dd      0
    .cursor_col     dd      0
    .bitmap_width   dd      8           ; default
    .bitmap_height  dd      8           ; default
    .max_row        dd      0
    .max_col        dd      0
    .rem_x          dd      0
    .rem_y          dd      0
    .fg_color32     dd      0
    .fg_color24     dd      0
    .fg_color16     dw      0
    .fg_color8      db      0
    .bg_color32     dd      0
    .bg_color24     dd      0
    .bg_color16     dw      0
    .bg_color8      db      0
    .true_grid_height   dd      0       ; height/width with spacing/margin
    .true_grid_width    dd      0

%include "src/boot/stage2/32bits/helper/font_table.asm"
