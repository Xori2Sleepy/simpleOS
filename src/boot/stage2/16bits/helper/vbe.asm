[bits 16]

vbe_4f00:
    ; if we dont have VBE2, then default to vga
    ; this decision have to be made, sadly, because I do not want to write 2 driver for old an new vbe
    mov     dword [scratchpad], "VBE2"

    mov     ax, 4F00h
    int     10h

    cmp     ax, 004Fh       ; success? did it even run?
    jne     .vbe_failed
    
    cmp     dword [scratchpad], "VESA"
    jne     .vbe_failed
    
    mov     si, msg_vbe_4f00_detected
    call    print_loop

    mov     ah, [scratchpad + 4]    ; hold version info
    cmp     ah, 2
    jl      .old_vbe

.vbe_setup
    ; vbe set up code here
    mov     ax, [scratchpad + 2]
    mov     [bios_info.vbe_version], ax
    mov     eax, [scratchpad + 6]
    mov     [bios_info.OEM_string], eax
    mov     eax, [scartchpad + 10]
    mov     [bios_info.vbe_capabilities], eax
    mov     eax, [scratchpad + 14]
    mov     [bios_info.vbe_video_mode_ptr], eax
    mov     ax, [scratchpad + 18]
    mov     [bios_info.vbe_total_memory], ax
    
    mov     si, msg_populate_4f00
    call    print_loop

    clc
    ret

.vbe_failed
    mov     si, msg_vbe_4f00_failed
    call    print_loop
    stc
    ret

vbe_4f01:

    mov     si, kerneL_info.preferred_bpp
    mov     di, vbe_resolution_priority_table + 1   ; the empty entries locate in 1 byte away
    mov     ecx, 5                                  ; alway going to be 5 byte (bpp, w * h)
    rep     movsb

    push    es
    push    bx

    mov     ax, [boot_info.vbe_video_mode_ptr + 2]
    mov     es, ax                                  ; move to ax first beacuse it weird hardware stuff, cache thing ig?
    mov     bx, [boot_info.vbe_video_mode_ptr]
    
    mov     cx, vbe_resolution_priority_table.entries_count
.loop:
    mov     cx, [es:di]
    
    cmp     cx, 0FFFFh          ; last entries in mode list
    je      .not_found


    call    vbe_get_mode_info   ; cx already have mode num
    jc      .next

    
    call    vbe_check_mode      ; perform check
    jc      .next

    mov     cx, [es:di]         ; mode #
    call    vbe_evaluate        ; came here after it pass basic check

.next:
    add     bx, 2
    jmp     .loop

.not_found:
    stc
    ret 

vbe_get_mode_info:
    ; input: mode number in cx
    push    es
    push    di
    
    mov     ax, 0               ;segment for mode buffer,
    mov     es, ax
    mov     di, scartchpad

    mov     ax, 0x4F01
    int     10h

    cmp     ax, 004Fh
    jne     .error
    
.success
    pop     di
    pop     es
    clc
    ret
.error
    pop     di
    pop     es
    stc
    ret

vbe_check_mode:
    ; basic checking
    ; need mode info in buffer, and need pointer to structure in ax
    mov     ax, [scratchpad]
    
    ; this is a must have for sure, auto for graphic flags
    test    ax, 1               ; supported?
    jz      .failed
    test    ax, 1 << 4          ; graphic?
    jz      .failed
    test    ax, 1 << 7          ; linear fream buffer
    jz      .failed
    cmp     byte [scratchpad + 27], 6      ; direct color
    jne     .failed

    mov     al, [scratchpad + 25]
    cmp     al, [ax]            ; bpp
    jne     .failed

    mov     al, [scratchpad + 18]
    cmp     al, [ax + 1]        ; width
    jne     .failed

    mov     al, [scratchpad + 19]
    cmp     al, [ax + 3]        ; height
    jne     .failed

    clc
    ret

.failed:
    stc
    ret
