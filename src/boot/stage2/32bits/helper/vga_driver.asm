[bits 32]
; THIS IS GOING TO BE THE LEAST CLEAN REGISTER USAGE YOU WILL EVER SEEN
; it a hobby OS and functions is is not uses by other process so... it doesnt matter that much
; the problem is for my future self to fix ;)

; also I just realize after i done wiht stuff why the fuck am i writing this shit in 32 bits mode
; i have to rewrite this code anyway when I am in 64 bits no???? FUCK

; ---------- VGA functions ----------  
; 2000 slot of 80 col and 25 rows, each slot is 2 bytes
; 0xB8000 + (row * 80 + col) * 2 <= position logic

deconstruct_bios_cursor:
    ; purpose: it get row and col information from when we are still in 16 bits real mode
    ; input: NA
    ; out: [current_row], [current_col]
    ; clobbered: eax, edx, ecx, flags
    ; note: we doesnt care what it clobbered, it call at the start anyway
    xor     edi, edi
    mov     eax, [scratchpad]
    call    vga_position_translate  ; return row and col in al ah respectively
    mov     [current_row], al
    mov     [current_col], ah
    ret

vga_clear_screen:
    ; purpose: clear the screen
    ; input: ah <- color
    push    edi
    push    ecx
    push    ax
    mov     edi, VGA_buffer_base
    mov     al, 0x20            ; white space
    mov     ecx, 2000           ; 2k cells
    cld
    rep     stosw
    mov     [current_row], 0
    mov     [current_col], 0
    pop     ax
    pop     ecx
    pop     edi
    ret                         ; es:edi

vga_position_translate:
    ; purpose: translate between linear and col/row address
    ;        : max input for linear is 2000! and col/row is 25*80!
    ; input: linear input -> edi = 0, eax = linear (or ax is fine)
    ;      : col/row input -> edi != 0, al = row, ah = col
    ; output: linear input -> al =  row, ah = col
    ;       : col/row input -> eax = linear address
    push    ecx
    push    edx
    
    movzx   eax, ax

    test    edi, edi
    je      .linear_input

.col_row_input:
    ; fall here
    movzx   ecx, ah
    movzx   eax, al
    imul    eax, 80
    add     eax, ecx            ; (al[row] * 80) + ah[col] in eax
    pop     edx
    pop     ecx
    ret
    
.linear_input:
    ; div cx will divide ax (16 bits)
    xor     edx, edx
    mov     cx, 80
    div     cx                  ; div 8 bits is actually perfect for this job :D
                                ; ax is row and dx is col now   
    mov     ah, dl              ; ax alway lower than 1 byte, so this is possible!
    pop     edx
    pop     ecx
    ret

move_cursor:
    ; purpose: well, its move cursor, what more there is to say...
    ;        : edit: it still move cursor, but with more swag :)
    ;        : edit: I take it back, it more like 'more nightmare'
    ; input: al = row, ah = col | upper 16 bit eax = mode
    ; output: NA
    ; clobbered: flagsS
    ; if upper 16 bits is all 0, it absolute move
    ; if upper 16 bits is not 0, then we do incremental mode by al, ah
    push    edx
    push    edi
    push    ecx
    push    eax

    mov     edi, eax

    shr     edi, 16             ; shift logical (zero extend) 16 bits
    test    edi, edi
    jz      .skip
    add     al, byte [current_row]      ; eh, dumb logic but it work, sorry man ;-;
    add     ah, byte [current_col]
    call    vga_grid_normalization 

.skip:
    mov     byte [current_row], al
    mov     byte [current_col], ah

    mov     edi, 1
    call    vga_position_translate  ; return linear address in eax
    mov     ecx, eax

    ; work in 16 bits, VGA card cant understand 32 bits, alledgedly...
    mov     dx, 0x3D4           ; VGA port
    mov     al, 0x0E            ; register 14 select (high)
    out     dx, al

    mov     dx, 0x3D5           ; writing data to VGA
    mov     al, ch              ; write high byte first
    out     dx, al

    mov     dx, 0x3D4
    mov     al, 0x0F            ; register 15 is low byte
    out     dx, al

    mov     dx, 0x3D5
    mov     al, cl
    out     dx, al

    pop     eax
    pop     ecx
    pop     edi
    pop     edx
    ret

disable_cursor:
    mov     dx, 0x3D4           ; write to port 0x3D4
    mov     al, 0x0A            ; write to 0A regs (cursor start)
    out     dx, al

    mov     dx, 0x3D5           ; port 0x3D5, data send here
    mov     al, 00100000b       ; bit 5 = 1, VGA stop render cursor
    out     dx, al
    ret

enable_cursor:
    mov     dx, 0x3D4
    mov     al, 0x0A
    out     dx, al

    mov     dx, 0x3D5
    mov     al, 0x00            ; reset bit 5 to 0
    out     dx, al
    ret

enable_escape_sequence:
    mov     al, [VGA_flags]     ; setting mode
    and     al, 11111011b       ; wiping esc seq bit
    or      al, 00000100b       ; merge bits
    mov     [VGA_flags], al

disable_escape_sequence:
    mov     al, [VGA_flags]     ; setting mode
    and     al, 11111011b       ; wiping esc seq bit
    mov     [VGA_flags], al

vga_grid_normalization:
    ; I KNOW I KNOW THIS CODE IS HORRIBLE BUT I DONT GOT NO TIME TO WORK ON THIS!
    ; purpose: normalized grid input (row and col) to make it actually make sense. (basically wrapping logic)
    ; input: al = row, ah = col
    ; output: al = row, ah = col ; but normalized! (why am i writing a comment inside a comment???)
    ;     : edi mode select - 00 (wrap top) 01 (wrap top clear) 10 (scroll wrap) 11 (scroll wrap buffer history)
    ; every 80 colums become one row
    mov     bl, [VGA_flags]
    and     bl, 00000011b  ; only the first 2 bit respond to normalization mode

    .normalize_col:
    cmp     ah, col_limit + 1
    jb      .normalize_row
    sub     ah, col_limit + 1   ; if ah>limit, fall here
    inc     al
    jmp     .normalize_col

    .normalize_row:
    ; row wrapped?
    cmp     al, row_limit + 1   ; only come here if we confirm that col is within limit
    jb      .done

    cmp     bl, 10b
    jae     .scroll_wrap

    .wrap_top:
    cmp     bl, 01b
    jne     .skip_clear

    push    ax
    mov     ah, BG_BLACK
    call    vga_clear_screen
    pop     ax

    .skip_clear:
    sub     al, row_limit + 1
    jmp     .normalize_row

    .scroll_wrap:
    cmp     al, row_limit + 1
    jb      .done

    mov     al, 1
    xor     ah, ah              ; history function is not implement! it take too much memory
    call    shift_VGA_buffer
    xor     eax, eax            ; absolute
    mov     al, 24
    mov     ah, 0

    jmp     .scroll_wrap
    .done:
    ret

shift_VGA_buffer:
    ; purpose: shift stuff from vga buffer up by one
    ; input: al <- amount to shift | ah <- save or not (this is not implement, 2 much buffer need)
    push    esi
    push    edi
    push    ecx
    push    eax

    cld
    mov     esi, (VGA_buffer_base + 160)    ; second row
    mov     edi, (VGA_buffer_base)          ; first row
    mov     ecx, 24 * 80                    ; 1920 words
    rep     movsw

    ; clear last row
    mov     edi, (VGA_buffer_base + (24 * 160))
    mov     ax, BG_BLACK | FG_WHITE
    shl     eax, 8
    mov     al, ' '
    mov     ecx, 80
    rep     stosw
    
    pop     eax
    pop     ecx
    pop     edi
    pop     esi
    ret

; ---------- Print functions ----------  
vga_print_char32:
    ; purpose: print a single character, in absolute mode a row/col is needed 
    ;          but relative will print to cursor
    ; input: edi <- mode, ax <- char, if (abs mode)  = row, dh = col, 
    ; output: NA
    ; clobbered: NA
    ; note: ((BG | FG ) << 8 ) | char   should be your format for ax
    ;     : for simplicity this thing only write! no incrimental features!
    push    edi
    push    ax
    push    dx
    test    edi, edi
    je      .relative           ; print relative to cursor position

    .absolute:
    ; natually fall here, print to col/row 
    push    eax
    mov     ax, dx
    mov     edi, 1              ; this is mode argument for functions!
    call    vga_position_translate  ; linear in eax
    shl     eax, 1
    lea     edi, [eax + VGA_buffer_base]
    pop     eax
    jmp     .exit

    .relative:
    push    eax
    xor     eax, eax
    mov     al, [current_row]
    mov     ah, [current_col]
    mov     edi, 1              ; row/col input mode
    call    vga_position_translate  ; linear in eax
    shl     eax, 1
    lea     edi, [eax + VGA_buffer_base]    ; VGA_buffer_base is a constant so it treated as a imm!
    pop     eax
    jmp     .exit

    .exit:
    mov     word [edi], ax
    pop     dx
    pop     ax
    pop     esi
    ret
    
vga_print_string32:
    ; input regs: edi <- pointer, ah <- 0 (deafult) else uses ah as color
    ;           : also have string parsing function, \ trigger escape sequence
    ;           : \\ will print '\', while \a# where # is a number from 0-F will change background color
    ;           : for foreground use \b#. More escape sequence might be added in the future
    ; clobbered regs: edi, ah, 
    pushf
    cld
    mov     esi, edi    ; esi is used by lodsb

    mov     bl, [VGA_flags]
    shr     bl, 2      ; now 3rd bit is the LSB
    and     bl, 1      ; isolate third

    mov     dh, ah      ; use provide color, overwrite if needed
    test    ah, ah
    jnz     .loop
    ; if eax = 0, use default
    mov     ah, (BG_BLACK | FG_WHITE) 
    mov     dh, ah

    .loop:
    lodsb                       ; Load next word from [esi] into AL
    cmp     al, 0
    je      .done
       
    cmp     bl, 0
    je      .skip_esc
    cmp     al, 92
    je      .escape_sequence

    .skip_esc:
    cmp     al, 10
    je      .line_feed

    cmp     al, 13
    je      .carriage_return    ; some type writer stuff, aint born in this period
    
    push    dx                  ; we tecnically dont have to do this cause i write my function to be respondsible for perserving
    push    esi                 ; this mistake cost me 3 hours of my life
    push    edi

    mov     ah, dh              ; moving color into ah
    xor     edi, edi            ; I actually should make a documentation...
    call    vga_print_char32        ; if even the author is confused by his own function
                                ; i cant begin to imagine the nightmare other potential contributor will have


    mov     eax, -1             ; it basically just 0xFFFFFFFF
    xor     al, al              ; this is preparing confusing argument for move_cursor...
    mov     ah, 1
    call    move_cursor

    pop     edi
    pop     esi
    pop     dx
    jmp     .loop

    .escape_sequence:
    mov     cl, byte [esi]      ; read character currently pointed by pointer | lodsb inc after mov

    cmp     cl, 92
    je      .backslash_handling
    cmp     cl, 'a'
    je      .bg_color
    cmp     cl, 'b'
    je      .fg_color
    jmp     .loop               ; auto skip

    .backslash_handling:
    ; print backslash
    push    dx
    push    esi
    mov     al, 92
    mov     ah, dh
    xor     edi, edi
    call    vga_print_char32
    mov     eax, -1
    xor     al, al
    mov     ah, 1
    call    move_cursor
    pop     esi
    pop     dx

    add     esi, 1              ; incriment our char pointer to skip "\\"
    jmp     .loop

    .bg_color:
    mov     cl, byte [esi+1]
    mov     al, cl
    call    convert_ascii2int   ; int in ax
    shl     ax, 4               ; shift 4 bit (mul 16) 
    and     dh, 0x0F            ; clear upper bit of ah, atp only upper 4 bits exist in cl
    or      dh, al              ; merge them
    add     esi, 2
    jmp     .loop
    
    .fg_color:
    mov     cl, byte [esi+1]
    mov     al, cl
    call    convert_ascii2int
    and     dh, 0xF0           ; clear lower bits
    or      dh, al             ; merge higher ah and lower cl 
    add     esi, 2
    jmp     .loop

    .line_feed:
    mov     eax, -1
    mov     al, 1
    xor     ah, ah
    call    move_cursor
    jmp     .loop
    
    .carriage_return:
    xor     eax, eax            ; absolute mode
    mov     al, [current_row] 
    mov     ah, 0
    call    move_cursor         ; current row, col = 0
    jmp     .loop

    .done: 
    popf
    ret

convert_ascii2int:
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

stop:
    ; function for debugging 
.loop:
    jmp     .loop


VGA_buffer_base     equ     0xb8000
row_limit           equ     24
col_limit           equ     79

current_row         db      0x00000
current_col         db      0x00000
VGA_flags           db      0

; Foreground Colors
FG_BLACK            equ     0x00
FG_BLUE             equ     0x01
FG_GREEN            equ     0x02
FG_CYAN             equ     0x03
FG_RED              equ     0x04
FG_MAGENTA          equ     0x05
FG_BROWN            equ     0x06
FG_LIGHT_GRAY       equ     0x07
FG_DARK_GRAY        equ     0x08
FG_LIGHT_BLUE       equ     0x09
FG_LIGHT_GREEN      equ     0x0A
FG_LIGHT_CYAN       equ     0x0B
FG_LIGHT_RED        equ     0x0C
FG_LIGHT_MAGENTA    equ     0x0D
FG_YELLOW           equ     0x0E
FG_WHITE            equ     0x0F

; Background Colors
BG_BLACK            equ     0x00
BG_BLUE             equ     0x10
BG_GREEN            equ     0x20
BG_CYAN             equ     0x30
BG_RED              equ     0x40
BG_MAGENTA          equ     0x50
BG_BROWN            equ     0x60
BG_LIGHT_GRAY       equ     0x70
BG_BLINKING         equ     0x80 ; this add blinking, need to do a ADD
