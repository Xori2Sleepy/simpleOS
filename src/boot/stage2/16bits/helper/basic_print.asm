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



