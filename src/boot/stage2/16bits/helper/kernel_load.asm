[bits 16]

; FATAL ERROR IN THIS FILE IF MAJOR FUNCTIONS FAIL, NO REPORT WILL BE RETURN TO BOOT_REPORT. CPU WILL BE HALT
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

    mov     byte [boot_info.read_mode], 1
    clc
    ret
.failed:
    mov     byte [boot_info.read_mode], 0
    stc
    ret

; -------------------- header load -------------------- 
kernel_header_load:
    dec     byte [disk_trial_counter]
    jz      .kernel_load_failed

    mov     dl, [boot_info.boot_drive]
    call    disk_check_extensions       ; first time calling
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
    mov     si, msg_header_load_success
    call    print_loop

    ret

.kernel_load_failed:
    mov     si, msg_header_load_failed
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

; -------------------- valid memory? -------------------- 
valid_address_check:
    ; input: address in edi:esi
    ; output: carry flag
    xor     eax, eax
    xor     edx, edx
    xor     ecx, ecx

    mov     ebx, [boot_info.entry_count]
    mov     eax, ebx    ; I can use lea ik
    shl     ebx, 1      ; but I changed it for some reason
    add     ebx, eax    ; must have been a bug, dont remember thought
    shl     ebx, 3      ; might be a problem with NASM

.search_loop:
    cmp     ecx, ebx
    jae     .invalid

    cmp     dword [ecx + boot_info.memory_map + 16], 1  ; type (usable RAM)
    jne     .next_entry

    mov     eax, [ecx + boot_info.memory_map]
    mov     edx, [ecx + boot_info.memory_map + 4]

    cmp     edi, edx    ; higher half
    jb      .next_entry
    ja      .base_ok

    cmp     esi, eax    ; lower half
    jb      .next_entry

.base_ok:
    add     eax, [ecx + boot_info.memory_map + 8]
    adc     edx, [ecx + boot_info.memory_map + 12]

    cmp     edi, edx
    ja      .next_entry
    jb      .end_ok

    cmp     esi, eax
    jae     .next_entry

.end_ok:
    ; if reach we know that this is our entry
    sub     eax, esi    ; give different
    sbb     edx, edi

    mov     esi, [kernel_info.image_size]
    mov     edi, [kernel_info.image_size + 4]

    ; compare different to image size
    cmp     edx, edi    ; eax and edx carry size
    jb      .invalid
    ja      .valid

    cmp     eax, esi
    jb      .invalid    ; allow equal

.valid:
    mov     si, msg_valid_memory
    call    print_loop
    clc     ; all passed 
    ret

.next_entry:
    add     ecx, 24
    jmp     .search_loop

.invalid:
    mov     si, msg_kernel_load_err_invalid_addr
    call    print_loop
    stc
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

    push    esi
    push    edi

    cmp     dword [ecx + boot_info.memory_map + 16], 1  ; type 1 usable ram
    jne     .next_entry

    mov     edx, [ecx + boot_info.memory_map + 12]
    mov     eax, [ecx + boot_info.memory_map + 8]

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
    xor     esi, esi
    mov     edi, 0x00100000
    sub     edi, eax        ; give different between pointer and 1mb

    pop     edx             ; now those have size
    pop     eax

    cmp     eax, edi
    jb      .next_entry     ; size < adjustment -> entire region is below 1mb, skip

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
    cmp     edx, edi        ; edi is upper
    jb      .next_entry_skip_pop
    cmp     eax, esi        ; esi is lower
    jbe     .next_entry_skip_pop

    ; fall here if found
    mov     si, msg_valid_memory
    call    print_loop
    
    mov     eax, [ecx + boot_info.memory_map]
    mov     edx, [ecx + boot_info.memory_map + 4]

    cmp     edx, 0x00000000
    ja      .skip_1mb
    cmp     eax, 0x00100000
    jae     .skip_1mb

    mov     eax, 0x00100000
    mov     edx, 0x00000000
.skip_1mb:
    clc
    ret

.next_entry:
    pop     edi
    pop     esi
.next_entry_skip_pop:
    add     ecx, 24
    jmp     .search_loop

.none_found:
    mov     eax, -1
    mov     edx, -1
    stc
    ret
    
; -------------------- sector load -------------------- 

load_sector_16:
    ; input: edi <- load address
    ; This is the most sublime piece of code I have ever written
    ; Oh, the beauty of undocumented CPU behavior
    ; load dap to scratchpad
    push    edi
    mov     esi, kernel_dap
    mov     edi, scratchpad
    xor     ecx, ecx
    mov     cl, byte [kernel_dap.dap_size]
    rep     movsb
    pop     edi

;    push    si
;    mov     si, msg_kernel_load_success
;    call    print_loop
;    pop     si


    ; load to bounce buffer
    mov     word [scratchpad + 2], 32      ; load 32 sector at a time
    mov     word [scratchpad + 4], 0       ; load at load address directly
    mov     word [scratchpad + 6], 0x8000  ; hard coded buffer up to 0x84000 (16 kib)


    mov     al, [boot_info.read_mode]
    test    al, al
    je      .chs


.lba:
    ; compute sector to load to eax
    mov     eax, [kernel_info.image_size]  ; this unfortunately mean that kernel max out at 4 gb, any way if my kernel ever exceed
                                           ; that number I am probbaly doing something very very wrong, window is only 11 mb
    mov     ecx, eax
    shr     eax, 9          ; 2^9 = 512
    test    ecx, 0x1ff      ; bit shifted
    jz      .exact          ; no remainder
    inc     eax             ; if nz mean remainder, so add 1 sector

.exact:
    ; compute chuck (32 sector for lba) to load in eax
    ; remainding chuck in ecx
    mov     ecx, eax
    shr     eax, 5          ; 2^5 = 32
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

  ;  jc      .error_stop
    pop     ecx
    pop     edi
    pop     eax

    ; I gave up on the initial unreal mode idea here
    ; the bios call destroy my ES register I need, which kinda make unreal useless here ;-;
    ; how did LILO even make use of this thing?
    o16     call    trigger_unreal                 ; I'on think there any crushon if this shit crash

    ; need address in edi ; sector in esi
    mov     esi, 32
    add     [boot_info.effective_loaded_bytes], esi
    call    load_chuck_to_higher_memory      ; perseve eax, edi, and ecx
    dec     eax
    call    exit_unreal

    add     edi, 0x4000     ; 32 * 512 = 0x4000
    add     word [scratchpad + 8], 32        ; sector_ad, in qword but doesnt matter
    jmp     .chuck_loop

.lba_done: 
    test    ecx, ecx
    jz      .done

    push    eax
    push    edi
    push    ecx

    mov     word [scratchpad + 2], cx        ; load extra sectors
    mov     ah, 42h
    mov     dl, [boot_info.boot_drive]
    mov     si, scratchpad 
    int     13h

    pop     ecx
    pop     edi
    pop     eax

    o16     call    trigger_unreal

    ; edi should be in here
    mov     esi, ecx
    add     [boot_info.effective_loaded_bytes], esi
    call    load_chuck_to_higher_memory
    call    exit_unreal

.done:
    mov     si, msg_kernel_load_success
    call    print_loop
    ret

.chs:
    mov     si, msg_kernel_load_CHS
    call    print_loop
    jmp     .crash_em_up
    hlt     ; just in case it failed the jmp, somehow...

.crash_em_up:
    mov     si, msg_kernel_load_failed
    call    print_loop
    call    halt
    ret

   

trigger_unreal:
    cli
    lgdt    [gdt_descriptor]    ; loading gdt to gdtr
    mov     eax, cr0
    or      eax, 1
    mov     cr0, eax
    jmp     0x08:.entry         ; 32 bits code segment

[bits 32]
.entry:
    mov     ax, 0x18            ; 32 bits data entry
    mov     es, ax              ; only extra segment is need for es:di on movsX 

    jmp     0x20:.explicit_real

[bits 16]
.explicit_real:
    mov     eax, cr0
    and     eax, ~1
    mov     cr0, eax
    jmp     0x0:.exit

.exit:
    sti
    pop     ax
    jmp     ax

exit_unreal:
    xor     ax, ax
    mov     es, ax
    ret

load_chuck_to_higher_memory:
    ; input: destination in edi ; sector in esi
    ; need ping pong ing 

    push    edi
    push    ecx
    push    eax
    push    ds

    shl     esi, 7      ; times 512 and divide 4 ( X << 9 >> 2)
    mov     ecx, esi    ; about of double word to move

    mov     ax, 0x8000  ; source
    mov     ds, ax      ; represent 0x80000
    xor     esi, esi

.move:
    cld
    a32 o32 rep     movsd
    pop     ds
    pop     eax
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

; -------------------- kernel load -------------------- 
kernel_load_16:
    mov     byte [disk_trial_counter], 3        ; counter

.load:
    call    kernel_analyze_kernel_reallocatable
    jc      .search
    
    ; if it not reallocatable, we try loading given address
    mov     eax, [kernel_info.load_address]
    mov     edx, [kernel_info.load_address + 4]
    
    cmp     edx, 0x00000000
    ja      .cant_load_above_limit    ; it is above 1mb but it hit limit
    cmp     eax, 0x00100000
    jb      .below_1mb

    mov     edi, edx
    mov     esi, eax
    call    valid_address_check
    jc      .cant_load_fatal_error

    xor     esi, esi
    mov     edi, [kernel_info.load_address]
    mov     [boot_info.effective_load_address], edi
    call    load_sector_16
    jmp     .load_done

.below_1mb:
    mov     si, msg_kernel_load_err_addr_below
    call    print_loop
    call    halt

.search:
    mov     esi, [kernel_info.image_size]
    mov     edi, [kernel_info.image_size + 4]
    call    search_avaliable        ; return in edx:eax
    jc      .cant_load_fatal_error  ; carry mean fatal
    
    mov     [boot_info.effective_load_address], eax
    mov     [boot_info.effective_load_address + 4], edx

    test    edx, edx
    jnz     .cant_load_above_limit  ; if not zero it mean this thing is more than 4gib, dont accept

.can_load:
    xor     esi, esi
    mov     edi, eax        ; if it reach here it meant it must be below 32 limits, so we good
    call    load_sector_16
    jmp     .load_done

.load_done:
    call    kernel_analyze_check_sum
    jnc     .ret

    mov     esi, [boot_info.effective_load_address]
    mov     ecx, [boot_info.effective_loaded_bytes]
    call    crc_32
    mov     esi, [kernel_info.check_sum]
    cmp     esi, eax
    jne     .check_failed

    mov     si, msg_kernel_load_check_success
    call    print_loop
.ret:
    ret

.check_failed:
    mov     si, msg_kernel_load_check_failed_retry
    call    print_loop
    dec     byte [disk_trial_counter]
    cmp     byte [disk_trial_counter], 0
    jz      .fatal_err
    jmp     .load

.fatal_err:
    mov     si, msg_kernel_load_check_failed_fatal
    call    print_loop
    call    halt

.cant_load_fatal_error:
    mov     si, msg_kernel_load_err_no_mem
    call    print_loop
    call    halt
.cant_load_above_limit:
    mov     si, msg_kernel_load_err_above_lim
    call    print_loop
    ; add some mechanicsm later
    ; or not cause this need some 64 bit stuff, and well i cant be bother right now
    ; i think unreal mode trick might not work because we also need paging? damn it
    call    halt

%include "src/boot/stage2/16bits/helper/CRC32.asm"
