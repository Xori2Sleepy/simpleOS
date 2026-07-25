[bits 32]

; ---------- VGA functions ----------  
; 2000 slot of 80 col and 25 rows, each slot is 2 bytes
; 0xB8000 + (row * 80 + col) * 2 <= position logic

deconstruct_bios_cursor:
    ; purpose: it get row and col information from when we are still in 16 bits real mode
    ; input: NA
    ; out: [current_row], [current_col]
    ; clobbered: eax, edx, ecx, flags
    xor     edi, edi
    mov     eax, [bios_cursor]
    call    position_translate  ; return row and col in al ah respectively
    mov     [current_row], al
    mov     [current_col], ah
    ret


