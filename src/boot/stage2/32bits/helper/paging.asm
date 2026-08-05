[bits 32]

; boot-time page table for 64 bits, throw away later when kernel load
; page need alignment
align 4096
PML4:
times 512 dq 0

align 4096
PDPT:
times 512 dq 0

align 4096
PD:
times 512 dq 0

check_long_mode_paging:
    call    kernel_analyze_long_mode
    jc      .not_request
    call    check_long_mode_paging_avaliable
    jc      .unavaliable

    call    page_link
    call    page_load
.not_request:

    ret
.unavaliable:
    ret

check_long_mode_paging_avaliable:
    call    leaf_analysis_long_mode
    jc      .not_support
    call    leaf_analysis_pae
    jc      .not_support
    call    leaf_analysis_msr
    jc      .not_support
    clc
    ret
.not_support:
    stc
    ret

page_link:
    mov     eax, PDPT
    or      eax, 11b            ; Present | Writable
    mov     [PML4], eax
    mov     dword [PML4 + 4], 0 ; next entry is 0

    mov     eax, PD
    or      eax, 11b
    mov     [PDPT], eax
    mov     dword [PDPT + 4], 0 ; PDPT now have entry 1 PD

    mov     edi, PD             ; location for page table
    xor     eax, eax            ; pointer counter
    mov     ecx, 16             ; fill first 32 MiB

.page_table_loop:
    mov     edx, eax
    or      edx, 10000011b      ; Present | Writable | PS <- stop cpu from tranversing page table 
                                ; and treat this pointer as the page entires
    mov     [edi], edx
    mov     dword [edi + 4], 0
    add     eax, 0x200000       ; next 2 MiB
    add     edi, 8              ; Next PDE

    dec     ecx
    test    ecx, ecx
    jne     .page_table_loop

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
    mov     eax, PML4
    mov     cr3, eax            ; cr3 hold root page table (page directory) address

    mov     eax, cr4            ; bits 5 PAE bits (extend 32 bits physical address bus to 36 bit)
    or      eax, 32             ; because it address is now 36 it cant fit inside 32 bit page entries
    mov     cr4, eax            ; so page entries is double to 64 bits ; page table remain 4kb in size so instead
                                ; another stucture, PDPT is introduced to allow full address coverage 
    ret
