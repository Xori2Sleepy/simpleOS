[bits 16]

; FATAL ERROR IN THIS FILE IF FAIL, NO REPORT WILL BE RETURN TO BOOT_REPORT

; -------------------- disk check ---------------------
disk_check_extensions:
    ; need dl as input drive
    mov     ah, 41h
    mov     bx, 55AAh
    int     0x13
    jc      .failed
    
    cmp     bx, 0xAA55      ; compare signature
    jne     .failed
    
    test    cx, 1           ; bit 0 is the extended disk access
    jz      .failed

    clc
    ret
.failed:
    stc
    ret

; -------------------- kernel load -------------------- 
kernel_header_load:
    dec     byte [disk_trial_counter]
    jz      .kernel_load_failed

    mov     dl, [boot_info.boot_drive]
    call    disk_check_extensions
    jc      .chs

.lba:
    mov     ah, 42h         ; extended read, uses lba
    mov     dl, [boot_info.boot_drive]
    mov     si, kernel_dap  ; load only the first sector for header
    int     13h
    jnc     .success
    call    disk_error
    jmp     kernel_header_load

.chs:
    mov     ah, [kernel_dap.sector_ad]
    inc     ah
    mov     cl, ah
    mov     ah, 02h
    mov     al, [kernel_dap.sector2read]
    mov     bx, [kernel_dap.destination]
    mov     ch, 0
    mov     dh, 0
    mov     dl, [boot_info.boot_drive]
    int     13h
    jnc     .success
    call    disk_error
    jmp     kernel_header_load

.success:
    mov     si, msg_disk_success
    call    print_loop
    mov     si, msg_kernel_load_success
    call    print_loop

    ret

.kernel_load_failed:
    mov     si, msg_kernel_load_failed
    call    print_loop

    call    halt            ; fatal error
    ret

; --------------------- disk error -------------------- 
disk_error:
    mov     si, msg_disk_failed
    call    print_error     ; ah already have error
    xor     ax, ax
    mov     dl, [boot_info.boot_drive]
    int     0x13
    jnc     .rs_success
    mov     si, msg_rs_failed
    call    print_loop
    ret
.rs_success:
    mov     si, msg_rs_success
    call    print_loop
    ret

; -------------------- header read -------------------- 
kernel_header_read:
    ; this assume magic, header ver, and header size is alway consistent across version
    mov     di, [kernel_dap.destination]   ; magic is loaded
    mov     eax, dword [di]
    cmp     eax, kernel_magic
    jne     .unrecognized_header

    mov     si, msg_recognized_magic
    call    print_loop
    
    xor     ecx, ecx
    xor     esi, esi
    xor     edi, edi
    mov     si, [kernel_dap.destination]   ; scratch pad
    mov     cx, word [si + 8]; header size

    mov     si, word [kernel_dap.destination]   ; scratch pad
    mov     di, kernel_info

    cld 
    rep     movsb
    ret

.unrecognized_header:
    mov     si, msg_unrecognized_magic
    call    print_loop
    call    halt        ; fatal error
    ret

; -------------------- search memory -------------------- 
search_avaliable:
    ; input: sizes in edi:esi
    ; output: entry offset in eax (or all 1s if no valid zone is found)
    xor     eax, eax
    xor     edx, edx
    xor     ecx, ecx

    mov     ebx, [boot_info.entry_count]
    mov     eax, ebx
    shl     ebx, 1
    add     ebx, eax
    shl     ebx, 3

.search_loop:
    cmp     ecx, ebx
    jae     .none_found

    cmp     [ecx + boot_info.memory_map + 16], 1  ; type 1 usable ram
    jne     .next_entry

    mov     edx, [ecx + boot_info.memory_map +  12]
    mov     eax, [ecx + boot_info.memory_map +  8]

    push    esi
    push    edi
    push    eax
    push    edx

    mov     edx, [ecx + boot_info.memory_map + 4]
    mov     eax, [ecx + boot_info.memory_map]

    cmp     edx, 0x00000000
    ja      .skip_sub
    cmp     edx, 0x00000000
    jne     .do_adjustment
    cmp     eax, 0x00100000
    jae     .skip_sub

.do_adjustment:

    mov     edi, 0x00100000
    mov     esi, 0x00000000

    sub     edi, eax        ; give different between pointer and 1mb
    sbb     esi, edx
    
    pop     edx             ; now those have size
    pop     eax

    sub     eax, edi
    sbb     edx, esi
    jmp     .check_size_ready

.skip_sub:
    pop     edx
    pop     eax

.check_size_ready:
    pop     edi
    pop     esi
    ; fall here if more than 1mb
    cmp     edx, edi
    jbe     .next_entry     ; if it equal exactly then it too dangerous to use
    cmp     eax, esi
    jbe     .next_entry

    ; fall here if found
    mov     si, msg_valid_memory
    call    print_loop
    mov     eax, ecx        ; return in eax
    ret

.next_entry:
    add     ecx, 24
    jmp     .search_loop

.none_found:
    mov     eax, -1
    ret
    
; -------------------- header load -------------------- 
kernel_load:
    call    kernel_analyze_kernel_reallocatable
    jc      .search

.search:
    mov     esi, 
    call    search_avaliable
