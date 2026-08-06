[bits 32]

; boot-time page table for 64 bits, throw away later when kernel load
; page need alignment

PML4    equ      0x90000
PDPT    equ      0x91000
PD      equ      0x92000

check_long_mode_paging:
    call    kernel_analyze_long_mode_32
    jnc     .not_request

    mov     edi, msg_attempt_long_mode
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    call    check_long_mode_paging_avaliable
    jc      .unavaliable

    mov     edi, [PML4]
    call    clear_page
    mov     edi, [PDPT]
    call    clear_page
    mov     edi, [PD]
    call    clear_page

    mov     edi, msg_page_buffer_clear
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

    call    page_link

    mov     edi, msg_page_link
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32

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

clear_page:
    ; input: page pointer in EDI
    xor     eax, eax
    mov     ecx, 1024       ; 4096/4
    rep     stosd
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
