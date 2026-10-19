[bits 32]

; idea: must have function, we first check perfered address, then chekc if it avaliable or not and how much size
; if not then we call another function to search for the address that work with the size we want
; if sizes is too big and we were unable to search, then we halt
; memory map need to be sanitized for this

kernel_stack_compute:
    mov     eax, [kernel_info.preferred_stack_top]
    
    cmp     eax, 0x00100000
    jb      .below_1mb
    
    push    eax
    ;mov     edi, eax
    call    valid_stack_address_check 
    jc      .search
    pop     eax

    ; passed, so we note down
    mov     [boot_info.actual_stack_addr], eax     
    mov     eax, [kernel_info.stack_size]
    mov     [boot_info.actual_stack_size], eax
    ret

.below_1mb:
    mov     edi, msg_stack_addr_below_1mb
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    jmp     .search

.search:
    push    edi
    push    esi
    push    edx
    mov     edi, msg_stack_search
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    pop    edi
    pop    esi
    pop    edx

    pop     eax
    mov     edi, [kernel_info.stack_size]
    call    search_stack_avaliable
    jc      .no_valid
        
    mov     edi, msg_stack_addr_found
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     eax, [kernel_info.preferred_stack_top]
    mov     [boot_info.actual_stack_addr], eax     
    mov     eax, [kernel_info.stack_size]
    mov     [boot_info.actual_stack_size], eax
    ret

.no_valid:
    mov     edi, msg_stack_no_valid
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    mov     dword [boot_info.actual_stack_addr], 0
    mov     dword [boot_info.actual_stack_size], 0

    call    halt32

valid_stack_address_check:
    ; Output: CF = 0 valid, CF = 1 invalid
    ; Clobbers EAX, EBX, ECX, EDX, ESI, EDI

    ; Calculate stack bottom = top - size.
    mov     eax, [kernel_info.stack_size]
    test    eax, eax
    jz      .invalid

    cmp     edi, eax
    jb      .invalid

    mov     esi, edi
    sub     esi, eax                    ; ESI = stack bottom

    cmp     esi, 0x00100000
    jb      .invalid                    ; keep stack above 1 MiB

    xor     ecx, ecx
    mov     eax, [boot_info.entry_count]
    lea     ebx, [eax + eax * 2]
    shl     ebx, 3                      ; * 24

.search_loop:
    cmp     ecx, ebx
    jae     .invalid

    cmp     dword [ecx + boot_info.memory_map + 16], 1
    jne     .next_entry

    ; This checker only supports entries with a base below 4 GiB.
    cmp     dword [ecx + boot_info.memory_map + 4], 0
    jne     .next_entry

    mov     eax, [ecx + boot_info.memory_map]   ; entry base
    cmp     esi, eax                            ; stack bottom >= base?
    jb      .next_entry

    ; Calculate 64-bit entry end = base + length.
    mov     edx, [ecx + boot_info.memory_map + 8]
    add     edx, eax
    mov     edi, [ecx + boot_info.memory_map + 12]
    adc     edi, 0

    ; If the entry end exceeds 4 GiB, allow a 32-bit stack
    ; top only if it remains within the representable range.
    test    edi, edi
    jnz     .entry_end_above_4gb

    ; Require stack top <= entry end.
    cmp     [kernel_info.preferred_stack_top], edx
    ja      .next_entry
    jmp     .check_kernel

.entry_end_above_4gb:
    ; Entry extends beyond 4 GiB, so any 32-bit stack top
    ; is below the entry end. Continue checking the kernel.

.check_kernel:
    ; Reject overlap with the loaded kernel.
    ; Kernel base is 64-bit; a base >= 4 GiB cannot overlap
    ; this 32-bit stack interval.
    cmp     dword [boot_info.effective_load_address + 4], 0
    jne     .valid

    mov     eax, [boot_info.effective_load_address] ; kernel base

    ; If kernel base >= stack top, no overlap.
    cmp     eax, [kernel_info.preferred_stack_top]
    jae     .valid

    ; Calculate kernel end = base + loaded bytes (64-bit).
    mov     edx, eax
    add     edx, [boot_info.effective_loaded_bytes]
    mov     edi, [boot_info.effective_loaded_bytes + 4]
    adc     edi, 0

    ; If kernel end is above 4 GiB, it overlaps when its
    ; base is below stack top and the stack bottom is < 4 GiB.
    test    edi, edi
    jnz     .invalid

    ; No overlap if stack bottom >= kernel end.
    cmp     esi, edx
    jae     .valid

    ; Otherwise the stack overlaps the kernel.
    jmp     .invalid

.valid:
    mov     edi, msg_valid_stack
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    clc
    ret

.next_entry:
    add     ecx, 24
    jmp     .search_loop

.invalid:
    mov     edi, msg_invalid_stack
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    stc
    ret

; --------------------------------------------------
search_stack_avaliable:
    ; Input:  EDI = stack size
    ; Output: EAX = stack top; CF = 0 success, 1 failure
    ; Clobbers EAX, EBX, ECX, EDX, ESI

    test    edi, edi                ; edge case
    jz      .none_found

    xor     ecx, ecx
    mov     eax, [boot_info.entry_count]
    lea     ebx, [eax + eax * 2]
    shl     ebx, 3                  ; entry_count * 24

.search_loop:
    cmp     ecx, ebx
    jae     .none_found

    cmp     dword [ecx + boot_info.memory_map + 16], 1
    jne     .next_entry

    cmp     dword [ecx + boot_info.memory_map + 4], 0       ; addr < 4gb
    jne     .next_entry

    mov     esi, [ecx + boot_info.memory_map]       ; base low
    mov     eax, [ecx + boot_info.memory_map + 8]   ; length low
    mov     edx, [ecx + boot_info.memory_map + 12]  ; length high

    add     eax, esi
    adc     edx, 0                                  ; base addr is zero anywaym no need for adding

    test    edx, edx
    jnz     .cap_end

    ; Reject a region whose end wrapped around or
    ; does not extend above the 1 MiB boundary.
    cmp     eax, esi
    jbe     .next_entry                             ; mean wrap happen
    jmp     .end_ready

.cap_end:
    mov     eax, 0xFFFFF000                         ; about 4gb - 0xFFF

.end_ready:
    ; Clamp the beginning to 1 MiB.
    cmp     esi, 0x00100000
    jae     .base_ready                             ; base above 1 Mib
    mov     esi, 0x00100000                         ; limiting the base

.base_ready:
    ; Candidate stack top = end, aligned down to 16 bytes.
    and     eax, 0xFFFFFFF0                         ; alignment stuff :D

    ; Need top > base & top - base >= stack size.
    cmp     eax, esi
    jbe     .next_entry

    sub     eax, esi
    cmp     eax, edi
    jb      .next_entry

    add     eax, esi                                ; got top entry back

    ; Check overlap with the loaded KENREL / IMPORTANT CHECK CODE CAREFULLY 
    pushad

    mov     ebp, eax
    sub     ebp, edi             ; EBP = stack bottom

    ; A kernel starting at >= 4 GiB cannot
    ; overlap this 32-bit stack.
    cmp     dword [boot_info.effective_load_address + 4], 0
    jne     .kernel_no_overlap

    mov     ebx, [boot_info.effective_load_address]

    ; Calculate kernel end = base + loaded_bytes.
    mov     ecx, ebx
    add     ecx, [boot_info.effective_loaded_bytes]

    mov     edx, [boot_info.effective_loaded_bytes + 4]
    adc     edx, 0

    ; If kernel end is above 4 GiB, then the
    ; stack bottom is necessarily below kernel end.
    test    edx, edx
    jnz     .check_kernel_start

    ; No overlap if stack bottom >= kernel end.
    cmp     ebp, ecx
    jae     .kernel_no_overlap

.check_kernel_start:
    ; No overlap if kernel base >= stack top.
    cmp     ebx, eax
    jae     .kernel_no_overlap

    ; Both overlap conditions are true.
    popad
    jmp     .next_entry

.kernel_no_overlap:
    popad
    clc
    ret

.next_entry:
    add     ecx, 24
    jmp     .search_loop

.none_found:
    stc
    ret

