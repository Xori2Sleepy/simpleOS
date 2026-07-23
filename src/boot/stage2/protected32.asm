[bits 32]

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

    ; dint uses 7c00 cause old 16 bits stack live there 
    ; dint uses 9fbff because apprently EBDA can grow into those area...
    mov     esp, 0x95000
    call    deconstruct_bios_cursor
    call    disable_cursor
    ;call    enable_cursor
    
    xor     eax, eax
    call    move_cursor         ; move cursor to 0,0
    xor     esi, esi
    mov     ax, ((BG_GREEN | FG_RED) << 8) | 'B'
    call    print_char32
    jmp     stop
    mov     esi, msg_welcome32
    call    print_string32
        
    jmp     stop


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
    mov     eax, [bios_cursor]
    call    position_translate  ; return row and col in al ah respectively
    mov     [current_row], al
    mov     [current_col], ah
    ret

clear_screen:
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

position_translate:
    ; purpose: translate between linear and col/row address
    ;        : max input for linear is 2000! and col/row is 25*80!
    ; input: linear input -> edi = 0, eax = linear (or ax is fine)
    ;      : col/row input -> edi != 0, al = row, ah = col
    ; output: linear input -> al =  row, ah = col
    ;       : col/row input -> eax = linear address
    push    ecx
    push    edi
    
    movzx   eax, ax

    test    edi, edi
    je      .linear_input

.col_row_input:
    ; fall here
    movzx   ecx, ah
    movzx   eax, al
    imul    eax, 80
    add     eax, ecx            ; (al[row] * 80) + ah[col] in eax
    pop     edi
    pop     ecx
    ret
    
.linear_input:
    ; div cx will divide ax (16 bits)
    xor     edx, edx
    mov     cx, 80
    div     cx                  ; div 8 bits is actually perfect for this job :D
                                ; ax is row and dx is col now   
    mov     ah, dl              ; ax alway lower than 1 byte, so this is possible!
    pop     edi
    pop     ecx
    ret

move_cursor:
    ; purpose: well, its move cursor, what more there is to say...
    ;        : edit: it still move cursor, but with more swag :)
    ; input: al = row, ah = col | upper 16 bit eax = mode
    ; output: NA
    ; clobbered: flagsS
    ; if upper 16 bits is all 0000, nothing happen
    ; if upper 16 bits is not 0, then we do incremental mode by al, ah
    push    edi
    push    ecx
    push    eax

    mov     edi, eax


    shr     edi, 16             ; shift logical (zero extend) 16 bits
    test    edi, edi
    jz      .skip
    add     al, byte [current_row]      ; eh, dumb logic but it work, sorry man ;^;
    add     ah, byte [current_col]
    call    grid_normalization

.skip
    mov     byte [current_row], al
    mov     byte [current_col], ah

    mov     edi, 1
    call    position_translate  ; eax contain linear address
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

    pop     ax
    pop     ecx
    pop     edi
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

grid_normalization:
    ; purpose: normalized grid input (row and col) to make it actually make sense
    ; input: al = row, ah = col
    ; output: al = row, ah = col ; but normalized! (why am i writing a comment inside a comment???)
    cmp     ah, 80
    je      .normalize_col
    cmp     al, 25
    je      .normalize_row
    ret

.normalize_col
    xor     ah, ah
    add     al, 1
    jmp     grid_normalization
.normalize_row
    xor     al, al
    jmp     grid_normalization

; ---------- Print functions ----------  
print_char32:
    ; purpose: print a single character, in absolute mode a row/col is needed 
    ;          but relative will print to cursor
    ; input: esi <- mode, ax <- char, if (abs mode) dl = row, dh = col, 
    ; output: NA
    ; clobbered: NA
    ; note: ((BG | FG ) << 8 ) | char   should be your format for ax
    ;     : for simplicity this thing only write! no incrimental features!
    push    esi
    push    ax
    push    dx
    test    esi, esi
    je      .relative           ; print relative to cursor position

.absolute:
    ; natually fall here, print to col/row 
    push    eax
    mov     ax, dx
    mov     edi, 1              ; this is mode argument for functions!
    call    position_translate  ; linear in eax
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
    call    position_translate  ; linear in eax
    shl     eax, 1
    lea     edi, [eax + VGA_buffer_base]    ; VGA_buffer_base is a constant so it treated as a imm!
    pop     eax
    jmp     .exit

.exit
    mov     word [edi], ax
    pop     dx
    pop     ax
    pop     esi
    ret
    
print_string32:
    ; input regs: esi <- pointer, ah <- 0 (deafult) else uses ah as color
    ; clobbered regs: NA
    pushf
    cld
    test    ax, ax
    jnz     .loop
    ; if eax = 0, use default
    mov     ah, ((BG_BLACK | FG_WHITE)) 
    xor     esi, esi            ; we can do this cause print_char32 clobbed nothing at all!
.loop:
    lodsb                       ; Load next word from ESI into AL
    cmp     al, 0
    je      .done
    call    print_char32        ; writing relative
    jmp     .loop
.done: 
    popf
    ret

stop:
    ; function for debugging 
    .loop:
    jmp     .loop

msg_welcome32       db      "Successfully enter 32bits protected mode.", 13, 10, 0

VGA_buffer_base     equ     0xb8000
row_limit           equ     25
col_limit           equ     80
current_row         db      0x00000
current_col         db      0x00000

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
