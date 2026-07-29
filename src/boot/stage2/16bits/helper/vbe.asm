[bits 16]

vbe_activate:
    call    vbe_4f00            ; load mode number list pointer and information into boot_info's vbe section
    call    vbe_4f01            ; return in selected_mode, carry on if it failed
    jc      .fallback_vga

    mov     cx, [selected_mode]
    call    vbe_get_mode_info   ; load info to buffer
    jc      .fallback_vga
    

.fallback_vga:
    
    
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
    ; The most inefficient code I will write in this project, i think... big O of O(n * m)
    ; I am so sorry for who ever will be reading this code (including future me)
    ; let me apologize in advance
    mov     si, kerneL_info.preferred_bpp
    mov     di, vbe_resolution_priority_table + 1   ; the empty entries locate in 1 byte away
    mov     ecx, 5                                  ; alway going to be 5 byte (bpp, w * h)
    rep     movsb

    push    es
    push    di

    mov     ax, [vbe_resolution_priority_table.entries_count]        ; start at dead last
    lea     ax, [ax + ax * 4]                   ; this ensure our selected rank is alway beyond the lowest in table
    mov     [selected_priority_rank], ax
    
    ; es:di mode list pointer
    mov     ax, [boot_info.vbe_video_mode_ptr + 2]
    mov     es, ax                              ; move to ax first beacuse it weird hardware stuff, cache thing ig?
    mov     dx, [boot_info.vbe_video_mode_ptr]  ; mode_number pointer
    
.mode_number_loop:
    mov     cx, [es:di]                         ; load mode num
    
    cmp     cx, 0FFFFh                          ; last entries in mode list
    je      .done_search

    call    vbe_get_mode_info                   ; cx already have mode num
    jc      .mode_number_next

    ; start from lowest priority
    mov     bx, vbe_resolution_priority_table.entries_count - 1 ; minus one because we counting backward
    lea     bx, [bx + bx * 4]                   ; multiply by 5, this compute entries offset

.resolution_loop:
    lea     ax, [bx + vbe_resolution_priority_table + 1]    ; compute actual pointer

    call    vbe_check_mode                      ; cmp stuff from buffer loaded by _get_mode_info and pointer in ax
    jc      .next_priority
    
    mov     ax, [selected_priority_rank]        ; first see if resolution found is higher priority or not
    cmp     bx, ax                              ; less than = higher priority
    jge     .next_priority
    
    ; this update our selected mode
    mov     cx, [es:dx]
    mov     [selected_mode], cx
    mov     [selected_priority_rank], bx        ; lower = better, it a multiple of 5 btw

.next_priority:
    test    bx, bx
    jz      .next_mode

    sub     bx, 5
    jmp     .priority_loop

.done_search:
    mov     ax, [selected_priority_rank]
    mov     bx, vbe_resolution_priority_table.entries_count
    lea     bx, [bx + bx * 4]
    cmp     ax, bx
    je      .not_found

    pop     di
    pop     es
    clc
    ret

.not_found
    pop     di
    pop     es
    stc
    ret


vbe_get_mode_info:
    ; helper function
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
    ; helper function
    ; need mode info in buffer, and need pointer to structure in ax
    mov     si, [scratchpad]
    
    ; this is a must have for sure, auto for graphic flags
    test    si, 1               ; supported?
    jz      .failed
    test    si, 1 << 4          ; graphic?
    jz      .failed
    test    si, 1 << 7          ; linear fream buffer
    jz      .failed
    cmp     byte [scratchpad + 27], 6      ; direct color
    jne     .failed

    mov     sil, [scratchpad + 25]
    cmp     al, [ax]            ; bpp
    jne     .failed

    mov     sil, [scratchpad + 18]
    cmp     al, [ax + 1]        ; width
    jne     .failed

    mov     sil, [scratchpad + 19]
    cmp     al, [ax + 3]        ; height
    jne     .failed

    clc
    ret

.failed:
    stc
    ret
