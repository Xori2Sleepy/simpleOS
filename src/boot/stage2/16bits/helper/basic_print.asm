[bits 16]

hex_map                             db      "0123456789ABCDEF"
; ---------- functions ----------
; general purpose function | CRITICAL: USE ONLY IN REAL MODE! 
; IT WILL CRASH IF TRY ON PROTECTED MODE!
; same function as in stage 1 -
; we dont want dependencies at bare metal level! redundent is the safest!

print_char:
    ; input regs: need ASCII # in al
    ; clobbered regs: NA
    push    ax
    mov     ah, 0x0E
    int     0x10
    pop     ax
    ret

print_loop:
    ; input regs: need pointer in si
    ; clobbered regs: NA
    pushf
    push    ax
    cld
.loop:
    lodsb
    cmp     al, 0
    je      .done
    call    print_char
    jmp     .loop
.done: 
    pop     ax
    popf
    ret

print_error:
    ; input regs: pointer to error string in si
    ;           : byte size error (hex) in ah
    ; clobbered regs: NA
    ; I completly forgot i got this function, actually some how come in handy
    push    ax
    push    bx

    push    ax
    xor     ax, ax
    mov     ds, ax
    pop     ax

    call    print_loop
    
    ; print first
    mov     al, ah
    shr     al, 4
    mov     bx, hex_map
    xlat
    call    print_char
    ; print second 
    mov     al, ah
    and     al, 0Fh
    mov     bx, hex_map
    xlat
    call    print_char
    ; print line feed and NL
    mov     al, 13
    call    print_char
    mov     al, 10
    call    print_char
    
    pop     bx
    pop     ax
    ret

print_error16:
    push    ax
    push    bx
    push    cx
    push    dx

    call    print_loop

    mov     dx, ax          ; preserve original value
    mov     cx, 4

.hex_loop:
    mov     ax, dx
    shr     ax, 12          ; highest nibble
    mov     bx, hex_map
    and     al, 0Fh
    xlat
    call    print_char

    shl     dx, 4           ; bring next nibble up
    loop    .hex_loop

    mov     al, 13
    call    print_char
    mov     al, 10
    call    print_char

    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret
