vbe_4f01:
    push    es
    push    di

    ; finish the priority table
    mov     si, kernel_info.preferred_bpp
    mov     di, vbe_resolution_priority_table + 1   ; the empty entries locate in 1 byte away
    mov     ecx, 5                                  ; alway going to be 5 byte (bpp, w * h)
    rep     movsb

    ; rank of inital priority is less than the last entries
    mov     ax, [vbe_resolution_priority_table.entries_count]        ; start at dead last
    mov     cx, ax
    shl     ax, 2
    add     ax, cx                              ; this ensure our selected rank is alway beyond the lowest in table
    mov     [selected_priority_rank], ax

    ; es:di mode list pointer | di and es must be perserve
    mov     ax, [boot_info.vbe_video_mode_ptr + 2]
    mov     es, ax                              ; move to ax first beacuse it weird hardware stuff, cache thing ig?
    mov     di, [boot_info.vbe_video_mode_ptr]  ; mode_number pointer

.mode_number_loop:
    mov     cx, [es:di]                         ; load mode num
    cmp     cx, 0FFFFh                          ; last entries in mode list
    je      .done_search

    push    es
    push    di
    call    vbe_get_mode_info                   ; cx already have mode num
    pop     di
    pop     es
    jc      .mode_number_next

    ; if we can load mode_info into buffer, we start seeing if it match from bottom up
    mov     bx, vbe_resolution_priority_table.entries_count - 1 ; minus one because we counting backward
    mov     cx, bx
    shl     bx, 2
    add     bx, cx                              ; multiply by 5, this compute entries offset
.resolution_loop:
    mov     ax, vbe_resolution_priority_table + 1
    add     ax, bx
    
    mov     cx, [es:di]
    call    vbe_check_mode                      ; cmp stuff from buffer loaded by _get_mode_info and pointer in ax
    jc      .next_priority
    
    mov     ax, [selected_priority_rank]        ; first see if resolution found is higher priority or not
    cmp     bx, ax                              ; less than = higher priority
    jge     .next_priority
    
    ; this update our selected mode
    mov     cx, [es:di]
    mov     [selected_mode], cx
    mov     [selected_priority_rank], bx        ; lower = better, it a multiple of 5 btw
