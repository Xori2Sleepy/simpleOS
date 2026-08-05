[bits 16]

; FATAL ERROR IN THIS FILE IF FAIL, NO REPORT WILL BE RETURN TO BOOT_REPORT

; -------------------- disk check ---------------------
disk_check_extensions:
    ; need dl as input drive
    mov     ah, 41h
    mov     bx, 55AAh
    int     0x13
    jc      .failed
    
    cmp     bx, 55AAh       ; compare signature
    jne     .failed
    
    test    cx, 1           ; bit 0 is the extended disk access
    jz      .failed

    clc
    ret
.failed:
    stc
    ret

; -------------------- kernel load -------------------- 
kernel_load:
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
    jmp     kernel_load
.chs:
    mov     ah, 02h
    mov     al, [kernel_dap.sector2read]
    mov     bx, [kernel_dap.destination]
    mov     ch, 0
    mov     cl, [kernel_dap.sector_ad]
    mov     dh, 0
    mov     dl, [boot_info.boot_drive]
    int     13h
    jnc     .success
    call    disk_error
    jmp     kernel_load

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
; -------------------- header analysis -------------------- 
kernel_analyze_graphic:
    ; input: NA
    ; output: carry (on = request graphic, off = no request for graphic)
    ; clobbered: eflags ; eax
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1      ; isolate bits 0 : graphic
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret

kernel_analyze_long_mode:
    ; input: NA
    ; output: carry (on = request graphic, off = no request for graphic)
    ; clobbered: eflags ; eax
    mov     eax, [kernel_info.header_version] ; version 
    shr     eax, 24     ; checking major version
    test    eax, eax    ; unreleased major 0
    je      .major0
.major0:
    mov     eax, [kernel_info.flags]
    and     eax, 1 << 1 ; isolate bits 1 : long_mode
    test    eax, eax
    je      .m0_gOFF
.m0_gON:
    stc
    ret
.m0_gOFF:
    clc
    ret
