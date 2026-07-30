[bits 32]
; This file is using system V ABI

vbe_draw_pixel:
    ; input x in edi ; input y in esi ; edx = color
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
