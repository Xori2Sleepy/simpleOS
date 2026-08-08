[bits 16]

print_handling:
    call    kernel_analyze_graphic
    jnc     .graphic_not_requested

.graphic_requested:
    mov     si, msg_attempt_vbe
    call    print_loop
    call    vbe_activate
    stc
    ret
.graphic_not_requested:
    call    get_bios_cursor     ; need before jumping, make sure no write to buffer after this!
    clc
    ret

vbe_activate:
    call    vbe_4f00            ; load mode number list pointer and information into boot_info's vbe section
    call    vbe_4f01            ; return in selected_mode, carry on if it failed
    jc      .fallback_vga

    mov     cx, [selected_mode]
    call    vbe_get_mode_info   ; load info to buffer
    jc      .fallback_vga
    mov     bx, scratchpad + 512

    mov     cx, [selected_mode]
    mov     [boot_info.vbe_selected_mode], cx

    mov     cx, [bx + 16]
    mov     [boot_info.vbe_pitch], cx
    mov     cx, [bx + 18]
    mov     [boot_info.vbe_width], cx
    mov     cx, [bx + 20]
    mov     [boot_info.vbe_height], cx

    mov     cl, [bx + 25]
    mov     [boot_info.vbe_bpp], cl
    mov     cl, [bx + 27]
    mov     [boot_info.vbe_memory_model], cl

    mov     cl, [bx + 31]
    mov     [boot_info.vbe_red_mask], cl
    mov     cl, [bx + 32]
    mov     [boot_info.vbe_red_shift], cl

    mov     cl, [bx + 33]
    mov     [boot_info.vbe_green_mask], cl
    mov     cl, [bx + 34]
    mov     [boot_info.vbe_green_shift], cl

    mov     cl, [bx + 35]
    mov     [boot_info.vbe_blue_mask], cl
    mov     cl, [bx + 36]
    mov     [boot_info.vbe_blue_shift], cl

    mov     eax, [bx + 40]
    mov     [boot_info.vbe_framebuffer], eax

    mov     si, msg_vbe_info_loaded
    call    print_loop

    call    vbe_4f02
    jc      .fallback_vga
    
    mov     al, [boot_report]
    or      al, 8               ; on = graphic on
    mov     [boot_report], al

    ret
    
.fallback_vga:
    mov     si, msg_vbe_info_failed
    call    print_loop
    
    mov     al, [boot_report]
    and     al, -9              ; off = graphic off
    mov     [boot_report], al

    ret
    
vbe_4f00:
    ; if we dont have VBE2, then default to vga
    ; this decision have to be made, sadly, because I do not want to write 2 driver for old an new vbe
    push    es
    push    di

    xor     ax, ax
    mov     es, ax
    mov     di, scratchpad

    mov     dword [es:di], "VBE2"
    
    mov     ax, 4F00h
    int     10h

    cmp     ax, 004Fh       ; success? did it even run?
    jne     .vbe_failed
    
    cmp     dword [es:di], "VESA"
    jne     .vbe_failed
    
    mov     si, msg_vbe_4f00_detected
    call    print_loop
    
    mov     ax, [es:di + 2]
    mov     [boot_info.vbe_version], ax
    mov     eax, [es:di + 6]
    mov     [boot_info.vbe_OEM_string], eax
    mov     eax, [es:di + 10]
    mov     [boot_info.vbe_capabilities], eax
    mov     eax, [es:di + 14]
    mov     [boot_info.vbe_video_mode_ptr], eax
    mov     ax, [es:di + 18]
    mov     [boot_info.vbe_total_memory], ax
    
    mov     si, msg_populate_4f00
    call    print_loop

    mov     ax, [boot_info.vbe_version]    ; hold version info
    cmp     ah, 2
    jb      .old_vbe

    pop     di
    pop     es
    clc
    ret

.old_vbe:
    mov     si, msg_unsupport_vbe
    call    print_loop
    pop     di
    pop     es
    stc
    ret

.vbe_failed:
    mov     si, msg_vbe_4f00_failed
    call    print_loop
    pop     di
    pop     es  
    stc
    ret

vbe_4f01:
    ; The most inefficient code I will write in this project, i think... big O of O(n * m)
    ; I am so sorry for who ever will be reading this code (including future me)
    ; let me apologize in advance
    cld
    mov     si, kernel_info.preferred_bpp
    mov     di, vbe_resolution_priority_table + 1   ; the empty entries locate in 1 byte away
    mov     ecx, 5                                  ; alway going to be 5 byte (bpp, w * h)
    rep     movsb

    push    es
    push    di
    
    xor     eax, eax
    mov     al, [vbe_resolution_priority_table.entries_count]        ; start at dead last
    mov     cx, ax
    shl     ax, 2
    add     ax, cx                              ; this ensure our selected rank is alway beyond the lowest in table
    mov     [selected_priority_rank], ax
    
    ; es:di mode list pointer
    mov     ax, [boot_info.vbe_video_mode_ptr + 2]
    mov     es, ax                              ; move to ax first beacuse it weird hardware stuff, cache thing ig?
    mov     di, [boot_info.vbe_video_mode_ptr]  ; mode_number pointer

.mode_number_loop:
    mov     cx, [es:di]                         ; load mode num
    
    cmp     cx, 0xFFFF                          ; last entries in mode list
    je      .done_search

    push    es
    push    di
    call    vbe_get_mode_info                   ; cx already have mode num
    pop     di
    pop     es

    jc      .mode_number_next

    ; start from lowest priority
    xor     ebx, ebx
    mov     bl, [vbe_resolution_priority_table.entries_count]
    dec     bx                                  ; minus one because we counting backward
    mov     cx, bx
    shl     bx, 2
    add     bx, cx                              ; multiply by 5, this compute entries offset

.resolution_loop:
    mov     ax, vbe_resolution_priority_table + 1
    add     ax, bx
    
    push    es
    push    di
    push    bx
    mov     cx, ax                              ; Worst bug - 8 hours, I should really make a bug log
    call    vbe_check_mode                      ; cmp stuff from buffer loaded by _get_mode_info and pointer in ax
    pop     bx
    pop     di
    pop     es
    jc      .next_priority
    
    mov     ax, [selected_priority_rank]        ; first see if resolution found is higher priority or not
    cmp     bx, ax                              ; less than = higher priority
    jae     .next_priority
    
    ; this update our selected mode
    mov     cx, [es:di]
    mov     [selected_mode], cx
    mov     [selected_priority_rank], bx        ; lower = better, it a multiple of 5 btw

.next_priority:
    test    bx, bx
    jz      .mode_number_next

    sub     bx, 5
    jmp     .resolution_loop

.mode_number_next:
    add     di, 2
    jmp     .mode_number_loop

.done_search:
    xor     ebx, ebx
    mov     ax, [selected_priority_rank]
    mov     bl, [vbe_resolution_priority_table.entries_count]
    mov     cx, bx
    shl     bx, 2
    add     bx, cx
    cmp     ax, bx
    je      .not_found
    
    mov     si, msg_vbe_4f01_mode_found
    call    print_loop

    pop     di
    pop     es
    clc
    ret

.not_found:
    mov     si, msg_vbe_4f01_mode_not_found
    call    print_loop

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
    mov     di, (scratchpad + 512)    ; THIS HAVE CAUSE ME 5 hours of pain and suffering

    mov     ax, 0x4F01
    int     10h

    cmp     ax, 004Fh
    jne     .error
    
.success:
    pop     di
    pop     es
    clc
    ret
.error:
    pop     di
    pop     es
    stc
    ret

vbe_check_mode:
    ; helper function
    ; need mode info in buffer, and need pointer to structure in ax
    mov     bx, ax
    mov     si, [scratchpad + 512]
    
    ; this is a must have for sure, auto for graphic flags
    test    si, 1               ; supported?
    jz      .failed
    test    si, 1 << 4          ; graphic?
    jz      .failed
    test    si, 1 << 7          ; linear fream buffer
    jz      .failed
    cmp     byte [scratchpad + 512 + 27], 6      ; direct color
    jne     .failed

    mov     al, byte [scratchpad + 512 + 25]
    cmp     al, byte [bx]      ; bpp
    jne     .failed

    mov     ax, [scratchpad + 512 + 18]
    cmp     ax, [bx + 1]        ; width
    jne     .failed

    mov     ax, [scratchpad + 512 + 20]
    cmp     ax, [bx + 3]        ; height
    jne     .failed

    clc
    ret

.failed:
    stc
    ret

vbe_4f02:
    mov     ax, 4F02h
    mov     bx, [boot_info.vbe_selected_mode]
    or      bx, 0x4000      ; linear frame buffer
    int     0x10

    cmp     ax, 004Fh
    jne     .error

    clc
    ret
.error:
    stc
    ret

