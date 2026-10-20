[bits 32]

; boot-time page table for 64 bits, throw away later when kernel load
; page need alignment

PML4    equ     0x80000
PDPT    equ     0x81000
PD_BASE equ     0x82000
PD_SIZE equ     0x1000

; Higher-half mapping: MUST be reserved physical memory.
HIGH_PD         equ     0x5F000
HIGH_PT_POOL    equ     0x60000
HIGH_PT_COUNT   equ     32              ; 32 * 2 MiB = 64 MiB
; Bootloader shoudnt be big enought to reach this i think

KERNEL_HIGH_BASE        equ     0xFFFFFFFF80000000
KERNEL_HIGH_FLAG        equ     1 << 4  ; EXAMPLE: use your real header bit

page_link_higher_half:
    ; running under assumption that kernel addr & sizes < 32 bits limit
    ; call me the best programmer ever cause I make my addr & sizes field unnessary big
    ; I kinda regret it now

    cmp     dword [boot_info.effective_load_address + 4], 0
    jne     .bad

    cmp     dword [boot_info.effective_loaded_bytes + 4], 0
    jne     .bad

    ; Reject an empty image or one exceeding 64 MiB.
    mov     eax, [boot_info.effective_loaded_bytes]
    test    eax, eax
    jz      .bad

    cmp     eax, HIGH_PT_COUNT * 512 * 0x1000
    ja      .bad

    ; Require a page-aligned physical load address.
    mov     eax, [boot_info.effective_load_address]
    test    eax, 0xFFF
    jnz     .bad

    ; Reject physical ranges that reach or cross 4 GiB.
    mov     edx, eax
    add     edx, [boot_info.effective_loaded_bytes]
    jc      .bad
    jz      .bad

    ; Number of 4 KiB pages = ceil(size / 4096).
    mov     eax, [boot_info.effective_loaded_bytes]
    add     eax, 0xFFF
    shr     eax, 12
    mov     esi, eax

    ; Number of PT pages = ceil(page_count / 512).
    add     eax, 511
    shr     eax, 9
    cmp     eax, HIGH_PT_COUNT
    ja      .bad
    mov     ebx, eax             ; EBX = number of PT pages

    ; Clear the higher-half page directory.
    mov     edi, HIGH_PD
    call    clear_page

    ; Clear the PT pages that will be used.
    mov     edi, HIGH_PT_POOL
    mov     ecx, ebx

.clear_pt:
    push    ecx
    push    edi
    call    clear_page
    pop     edi
    pop     ecx

    add     edi, 0x1000
    dec     ecx
    jnz     .clear_pt

    ; PML4[511] -> PDPT
    mov     eax, PDPT
    or      eax, 0x03
    mov     [PML4 + 511 * 8], eax
    mov     dword [PML4 + 511 * 8 + 4], 0

    ; PDPT[510] -> HIGH_PD
    mov     eax, HIGH_PD
    or      eax, 0x03
    mov     [PDPT + 510 * 8], eax
    mov     dword [PDPT + 510 * 8 + 4], 0

    ; Link each PDE to one 4 KiB page table.
    ; PS remains zero: these are NOT 2 MiB pages.
    mov     edi, HIGH_PD
    mov     eax, HIGH_PT_POOL
    mov     ecx, ebx

.link_pt:
    mov     edx, eax
    or      edx, 0x03             ; Present | Writable
    mov     [edi], edx
    mov     dword [edi + 4], 0

    add     eax, 0x1000
    add     edi, 8
    dec     ecx
    jnz     .link_pt

    ; Fill PTEs with consecutive physical pages.
    ; The PT pool is contiguous, so the PTEs are contiguous too.
    mov     edi, HIGH_PT_POOL
    mov     eax, [boot_info.effective_load_address]
    mov     ecx, esi

.map_kernel_page:
    mov     edx, eax
    or      edx, 0x03             ; Present | Writable
    mov     [edi], edx
    mov     dword [edi + 4], 0

    add     eax, 0x1000
    add     edi, 8
    dec     ecx
    jnz     .map_kernel_page

    clc
    ret

.bad:
    stc
    ret

;align 4096
;PML4:
;    times   512     dq      0
;align 4096
;PDPT:
;    times   512     dq      0
;align 4096
;PD:
;    times   512     dq      0

check_long_mode_paging:

    call    kernel_analyze_long_mode_32
    jnc     .not_request

    mov     edi, msg_attempt_long_mode
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    call    check_long_mode_paging_avaliable
    jc      .unavaliable

    xor     eax, eax

    mov     edi, msg_page_buffer_clear
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    call    page_link

    mov     edi, msg_page_link
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    call    kernel_analyze_higher_half_32
    jnc     .loading_page

    call    page_link_higher_half
    jc      .higher_half_failed

    mov     edi, msg_higher_half_success
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

.loading_page:
    call    page_load

    mov     edi, msg_page_load
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    stc     ; indicate that we do want to enter 64 bits long mode
    ret

.not_request:
    clc
    ret 

.unavaliable:
    mov     edi, msg_long_mode_unavaliable
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    clc
    ret

.higher_half_failed:
    mov     edi, msg_higher_half_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    call    halt32
    hlt

clear_page:
    push    eax
    push    ecx
    cld
    ; input: page pointer in EDI
    xor     eax, eax
    mov     ecx, 1024       ; 4096/4
    rep     stosd
    pop     ecx
    pop     eax
    ret

check_long_mode_paging_avaliable:
    call    leaf_analysis_long_mode_32
    jc      .not_support
    call    leaf_analysis_pae_32
    jc      .not_support
    call    leaf_analysis_msr_32
    jc      .not_support
    clc
    ret
.not_support:
    stc
    ret


page_link:
    cld

    pushad
    mov     edi, PML4
    call    clear_page
    mov     edi, PDPT
    call    clear_page
    popad

    ; Default: map the first 1 GiB.
    mov     ebx, 1
    mov     esi, 512

    test    dword [boot_report], 1000b
    jz      .counts_ready

    ; framebuffer
    movzx   eax, word [boot_info.vbe_pitch]
    movzx   ecx, word [boot_info.vbe_height]
    imul    eax, ecx

    xor     edx, edx
    add     eax, [boot_info.vbe_framebuffer]
    adc     edx, 0

    ; If the end is below 4 GiB, calculate both counts.
    test    edx, edx
    jnz     .end_at_or_above_4g

    test    eax, eax
    jz      .counts_ready

    ; PD count = ((end - 1) >> 30) + 1
    mov     ecx, eax
    dec     ecx
    shr     ecx, 30
    inc     ecx
    mov     ebx, ecx

    ; PDE count = ((end - 1) >> 21) + 1
    mov     ecx, eax
    dec     ecx
    shr     ecx, 21
    inc     ecx
    mov     esi, ecx
    jmp     .counts_ready

.end_at_or_above_4g:
    ; EDX:EAX == 4 GiB exactly if EAX == 0.
    test    eax, eax
    jz      .map_4g

    ; beyond 4gb
    pushad
    mov     edi, msg_framebuffer_addr_too_high
    xor     esi, esi
    mov     edx, 0xF
    call    terminal_print_string32
    popad

.map_4g:
    ; Map the entire first 4 GiB.
    mov     ebx, 4
    mov     esi, 2048

.counts_ready:
    ; PML4[0] -> PDPT
    mov     eax, PDPT
    or      eax, 0x03
    mov     [PML4], eax
    mov     dword [PML4 + 4], 0

    ; Link and clear the required PDs.
    mov     edi, PDPT
    mov     eax, PD_BASE
    mov     ecx, ebx

.link_directories:
    mov     edx, eax
    or      edx, 0x03
    mov     [edi], edx
    mov     dword [edi + 4], 0

    ; Clear this 4 KiB page directory.
    pushad
    mov     edi, eax
    call    clear_page
    popad

    add     eax, 0x1000
    add     edi, 8
    dec     ecx
    jnz     .link_directories

    ; Fill the PDEs with 2 MiB identity mappings.
    mov     edi, PD_BASE
    xor     eax, eax
    mov     ecx, esi

.page_table_loop:
    mov     edx, eax
    or      edx, 0x83        ; Present | Writable | PS
    mov     [edi], edx
    mov     dword [edi + 4], 0

    add     eax, 0x200000
    add     edi, 8
    dec     ecx
    jnz     .page_table_loop

    ret

; bit 0 <- Present?
; bit 1 <- Read/Write? 0 = RO ; 1 = RW
; bit 2 <- User/Supervisor (US) ; 0 = ring 0 Kernel ; 1 = ring '4' user
; bit 3 <- Page Write Throught (PWT) <- Cache Policy
; bit 4 <- Page Cache Disable (PDC) <- disable caching ; sometime this is wanted for framebuffer etc to avoid weird bug
; bit 5 <- Accessed (A) <- CPU set when page is access
; bit 6 <- Dirty (D) <- CPU set when page is written
; bit 7 <- PAT/Large Page <- Depend on Level
; bit 8 <- Global? <- 1 = dont flush when CR3 Change
; bit 63 <- NX (No execute) <- 1 = cannot execute instructions ; for permission management

page_load:
    mov     eax, cr4            ; bits 5 PAE bits (extend 32 bits physical address bus to 36 bit)
    or      eax, 1 << 5         ; because it address is now 36 it cant fit inside 32 bit page entries
    mov     cr4, eax            ; so page entries is double to 64 bits ; page table remain 4kb in size so instead
                                ; another stucture, PDPT is introduced to allow full address coverage 
    mov     eax, PML4
    mov     cr3, eax            ; cr3 hold root page table (page directory) address

    ret

;; static, legacy function
;page_link_LEGACY2:
;    ; PML4[0] -> PDPT
;    mov     eax, PDPT
;    or      eax, 11b              ; Present | Writable
;    mov     [PML4], eax
;    mov     dword [PML4 + 4], 0
;
;    mov     edi, PDPT
;    mov     eax, PD_BASE
;    mov     ecx, 4
;
;.link_directories:
;    mov     edx, eax
;    or      edx, 11b              ; Present | Writable
;    mov     [edi], edx
;    mov     dword [edi + 4], 0
;
;    add     eax, 0x1000            ; Next page directory
;    add     edi, 8                 ; Next PDPT entry
;
;    loop    .link_directories
;
;    mov     edi, PD_BASE
;    xor     eax, eax               ; Physical address = 0
;    mov     ecx, 2048
;
;.page_table_loop:
;    mov     edx, eax
;    or      edx, 10000011b         ; Present | Writable | PS
;    mov     [edi], edx
;    mov     dword [edi + 4], 0
;
;    add     eax, 0x200000           ; Next 2 MiB page
;    add     edi, 8                  ; Next PDE
;
;    dec     ecx
;    test    ecx, ecx
;    jne     .page_table_loop
;    ret
;
;; trying dynamic shit but it dint work,sad
;page_link_LEGACY:
;    cld
;    mov     eax, PDPT
;    or      eax, 11b
;    mov     [PML4], eax             ; put PDPT1 to PML4 entries
;    mov     dword [PML4 + 4], 0     ; second half is 0
;
;
;    test    dword [boot_report], 1000b
;    jz      .default
;    ; if graphic on it have to be based on framebuffer address
;
;    movzx   eax, word [boot_info.vbe_pitch]
;    movzx   ecx, word [boot_info.vbe_height]
;    imul    eax, ecx
;    add     eax, [boot_info.vbe_framebuffer]
;    jc      .address_too_high
;
;    dec     eax             ; exclusive end -> last byte used
;    shr     eax, 30         ; highest PD index
;    inc     eax             ; convert index -> PD count
;
;    push    eax
;    mov     ecx, eax
;
;    mov     edi, PDPT
;    mov     eax, PD_BASE
;    jmp     .link_directories
;
;.default:
;    push    eax
;    mov     ecx, 1
;    mov     edi, PDPT
;    mov     eax, PD_BASE
;
;.link_directories:
;    mov     edx, eax                ; PD BASE
;    or      edx, 11b
;    mov     [edi], edx
;    mov     dword [edi + 4], 0
;
;    push    edi
;    mov     edi, eax
;    call    clear_page              ; should perserve eax, and ecx
;    pop     edi
;
;    add     eax, 0x1000
;    add     edi, 8
;
;    dec     ecx
;    jnz     .link_directories
;
;    pop     eax
;    add     eax, 0x1FFFFF           ; should give actual entries number
;    shr     eax, 21
;    mov     ecx, eax
;
;    mov     edi, PD_BASE
;    xor     eax, eax
;
;.page_table_loop:
;    mov     edx, eax
;    or      edx, 10000011b         ; Present | Writable | PS
;    mov     [edi], edx
;    mov     dword [edi + 4], 0
;
;    add     eax, 0x200000           ; Next 2 MiB page
;    add     edi, 8                  ; Next PDE
;
;    dec     ecx
;    test    ecx, ecx
;    jne     .page_table_loop
;    ret
;
;.address_too_high:
;    mov     edi, msg_framebuffer_addr_too_high
;    mov     esi, 0x0
;    mov     edx, 0xF
;    call    terminal_print_string32
;    jmp     .default                ; do default and hope it work out :) good luck
;
