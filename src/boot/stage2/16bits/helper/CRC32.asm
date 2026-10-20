[bits 16]
; crc32

; input regs: ESI = payload address ; ECX = payload size in bytes
; output regs: EAX = calculated CRC-32

crc_32:
    mov     dword [esi + 10], 0x0

    push    ebx
    push    edx
    push    esi
    push    ecx

    mov     eax, 0xFFFFFFFF     ; initial CRC

.byte_loop:
    ; ending condition
    test    ecx, ecx
    jz      .finish

    ; Feed the next payload byte into the CRC.
    movzx   edx, byte [esi]
    xor     eax, edx

    mov     ebx, 8              ; counter

.bit_loop:
    shr     eax, 1
    jnc     .no_xor

    xor     eax, 0xEDB88320

.no_xor:
    dec     ebx
    jnz     .bit_loop

    inc     esi                 ; inc payload address by 1 byte
    dec     ecx                 ; dec sizes until it reach 0
    jmp     .byte_loop

.finish:
    not     eax

    pop     ecx
    pop     esi
    pop     edx
    pop     ebx
    ret
