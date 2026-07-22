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

    ; dint uses 7c00 cause old 16bits stack live there 
    ; dint uses 9fbff because apprently EBDA can grow into those area...
    mov     esp, 0x95000
    call    deconstruct_bios_cursor
    call    disable_cursor
    call    enable_cursor
    
    xor     al, al
    xor     ah, ah
    call    move_cursor
    mov     ah, 0x20
        
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
    mov     edi, [VGA_buffer_base]
    mov     al, 0x20            ; white space
    mov     ecx, 2000           ; 2k cells
    cld
    rep     stosw
    mov     [current_row], 0
    mov     [current_col], 0
    ret                         ; es:edi

position_translate:
    ; purpose: translate between linear and col/row address
    ;        : max input for linear is 2000! and col/row is 25*80!
    ; input: linear input -> edi = 0, eax = linear (strictly EAX!)
    ;      : col/row input -> edi != 0, al = row, ah = col
    ; output: linear input -> al =  row, ah = col
    ;       : col/row input -> eax = linear address
    push    ecx                 ; no point in saving eax and edi
    test    edi, edi
    je      .linear_input

.col_row_input:
    ; fall here
    movzx   ecx, ah
    movzx   eax, al
    imul    eax, 80
    add     eax, ecx            ; (al[row] * 80) + ah[col] in eax
    pop     ecx
    ret
    
.linear_input:
    ; div cl will divide al (16 bits)
    mov     cx, 80
    div     cl                  ; div 8 bits is actually perfect for this job :D
                                ; al is row and ah is col now
    pop     ecx
    ret

move_cursor:
    ; purpose: well, its move cursor, what more there is to say...
    ; input: al = row, ah = col
    ; output: NA
    ; clobbered: flags
    push    edi
    push    ecx

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
        
; ---------- Print functions ----------  
print_char
stop:
    ; function for debugging 
    .loop:
    jmp     .loop

VGA_buffer_base     dd      0xb8000
current_row         dd      0x00000
current_col         dd      0x00000
