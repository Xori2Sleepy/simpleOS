[bits 64]
; input: RDI <- Pointer to boot info
; output: NA
; clobbered: rcx, rdi, rsi
kernel_setup:
    cld
    mov     rcx, [rdi]              ; by convention first 8 bytes is alway size
    mov     rsi, rdi
    mov     rdi, boot_info          ; kernel time boot info
    rep     movsb
    ret
