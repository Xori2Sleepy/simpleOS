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
    cmp     eax, 0x00100000
    jae     .skip_sub

.do_adjustment:
    ; eax is below 1mb
    mov     edi, 0x00100000
    sub     edi, eax        ; give different between pointer and 1mb

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
    
    ; edx and eax should contain the pointer
    ret

.next_entry:
    add     ecx, 24
    jmp     .search_loop

.none_found:
    mov     eax, -1
    ret
    
; -------------------- sector load -------------------- 

load_sector:
    ; input: edi <- load address
    ; load stuff in a loop
    push    edi
    mov     esi, kernel_dap
    mov     edi, scratchpad ; copy to scratch pad
    xor     ecx, ecx
    mov     cl, byte [kernel_dap.dap_size]
    rep     movsb
    pop     edi

    mov     word [scratchpad + 2], 32      ; load 32 sector at a time
    mov     word [scratchpad + 4], 0       ; hard coded buffer - to 0x84000 (16 kib)
    mov     word [scratchpad + 6], 0x8000  ; hard coded buffer - to 0x84000 (16 kib)

    call    disk_check_extensions
    jc      .chs

.lba:
    ; compute sector to load to eax
    mov     eax, [kernel_info.image_size]
    mov     ecx, eax
    shr     eax, 9          ; 2 ^ 9 = 512
    test    ecx, 0x1ff      ; bit shifted
    jz      .exact          ; no remainder
    inc     eax             ; if nz mean remainder, so add 1 sector

.exact:
    ; compute chuck (32 sector for lba) to load in eax
    ; remainding chuck in ecx
    mov     ecx, eax
    shr     eax, 5
    and     ecx, 31         ; for extra load

.chuck_loop:
    test     eax, eax
    jz      .lba_done

    push    eax
    push    edi
    push    ecx
    mov     ah, 42h
    mov     dl, [boot_info.boot_drive]
    mov     si, scratchpad 
    int     13h
 ;   jc      .error_stop
    pop     ecx
    pop     edi
    pop     eax

    ; need address in edi ; sector in esi
    mov     esi, 32
    call    load_chuck_to_higher_memory

    dec     eax
    add     edi, 0x4000     ; 32 * 512 = 0x4000
    add     word [scratchpad + 8], 32        ; sector ad, in qword but doesnt matter
    jmp     .chuck_loop

.lba_done: 
    test    ecx, ecx
    jz      .done
    mov     word [scratchpad + 2], ax        ; load extra sectors
    mov     ah, 42h
    mov     dl, [boot_info.boot_drive]
    mov     si, scratchpad 
    int     13h
 ;  jc      .error_stop
    mov     esi, ecx
    call    load_chuck_to_higher_memory

.done:
    mov     si, msg_kernel_sector_load_success
    call    print_loop
    ret

.chs:
    ret
    

load_chuck_to_higher_memory:
    ; input: destination in edi ; sector in esi
    push    edi
    push    ecx
    shl     esi, 7      ; times 512 and divide 4 (<< 9 >> 2)
    mov     ecx, esi    ; about of double word to move
    mov     esi, 0x80000
    rep     movsd
    pop     ecx
    pop     edi
    ret
    

;load_sector:
;    ; input: edi <- load address ; input esi <- buffer
;    ; load stuff in a loop
;    push    edi
;    mov     esi, kernel_dap
;    mov     edi, scratchpad ; copy to scratch pad
;    mov     ecx, [kenrel_dap.dap_size]
;    rep     movsb
;    pop     edi
;
;    mov     word [scratchpad + 2], 32    ; load 32 sector at a time
;    mov     word [scratchpad + 4], edi   ; dest
;
;    call    disk_check_extensions
;    jc      .chs
;
;.lba:
;    ; compute sector to eax
;    mov     eax, [kernel_info.image_size]
;    mov     ecx, eax
;    shr     eax, 9          ; 2 ^ 9 = 512
;    test    ecx, 0x1ff      ; bit shifted
;    jz      .exact          ; no remainder
;    inc     eax             ; if nz mean remainder, so add 1 sector
;    
;.exact:
;    ; compute chuck (32 sector for lba) to load in eax
;    mov     ecx, eax
;    shr     eax, 5
;    and     ecx, 31         ; for extra load
;
;.perfect_chuck:
;    test     eax, eax
;    jz      .lba_done
;
;    push    eax
;    mov     ah, 42h
;    mov     dl, [boot_info.boot_drive]
;    mov     si, scratcpad 
;    int     13h
; ;   jc      .error_stop
;    pop     eax
;
;    dec     eax
;
;    add     word [scratchpad + 6], 0x400     ; 32 * 512 / 16 = 0x400
;    add     dword [scratchpad + 8], 32        ; sector ad, in qword but doesnt really matter
;
;    jmp     .perfect_chuck
;
;.lba_done: 
;    test    ecx, ecx
;    jz      .done
;    mov     word [scratchpad + 2], ecx    ; load extra sectors
;    mov     ah, 42h
;    mov     dl, [boot_info.boot_drive]
;    mov     si, scratcpad 
;    int     13h
; ;  jc      .error_stop
;.done
;    mov     si, msg_kernel_sector_load_success
;    call    print_loop
;.chs:

; -------------------- header load -------------------- 
kernel_load:
    call    kernel_analyze_kernel_reallocatable
    jc      .search

.search:
    mov     esi, [kernel_info.image_size]
    mov     edi, [kernel_info.image_size + 4]
    call    search_avaliable
    cmp     eax, -1
    je      .cant_load_fatal_error
    
    mov     edi, [eax + boot_info.memory_map + 4]
    test    edi, edi
    jz      .can_load   ; if not zero it mean this thing is more than 4gib, dont accept
    ret
.can_load:
    mov     edi, [eax + boot_info.memory_map]
    call    load_sector
    ret
    
.cant_load_fatal_error:
    mov     si, msg_load_failed
    call    print_loop
    call    halt
    hlt     ; here just in case
