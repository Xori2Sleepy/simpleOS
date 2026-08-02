[bits 16]

; CPUID AVALIABLITY IS FATAL ERROR, OTHER WISE LEAF 1, 7, x2to4 IS NON FATAL, report to 0, 1, 2 respectively
; ---------------- CPUID functions -------------------
get_cpuid:
    pushfd
    pushfd
    xor     dword [esp], 0x00200000
    popfd                   ; flags updated
    pushfd
    pop     eax             ; save flags in eax
    xor     eax, [esp]      ; compare it with original flags
    popfd                   ; restore original flags
    and     eax, 0x00200000 ; now compare eax with 0x00200000. also we do this to isolate that bit
                            ; if zero mean our change did not apply
                            ; so cpuid is not avaliable
    jz      .unavailable
    jnz     .avaliable

.unavailable:
    mov     di, msg_cpuid_unavailable
    call    print_loop
    call    halt
    ret

.avaliable:
    call    cpu_leaf0_detection
    call    max_extended_detection
    call    cpu_leaf1_detection
    call    cpu_leaf7_detection
    call    cpu_xleaf2to4_detection        ; xleaf for extended leaf (0x80000000+)
    ret
    
; -------------------- leaf 0 --------------------  
cpu_leaf0_detection:
    xor     eax, eax
    cpuid                   ; vendor id in EBX EDX ECX
    mov     dword [boot_info.cpu_max_leaf], eax     ; store max leaf, uses later
    mov     [CPUID_VENDOR_BUFFER], ebx
    mov     [CPUID_VENDOR_BUFFER + 4], edx
    mov     [CPUID_VENDOR_BUFFER + 8], ecx
    xor     edi, edi
.loop:
    mov     ebx, [CPUID_VENDOR_TABLE + edi]
    mov     edx, [CPUID_VENDOR_TABLE + edi + 4]
    mov     ecx, [CPUID_VENDOR_TABLE + edi + 8]     ; load first entry

    cmp     ebx, [CPUID_VENDOR_BUFFER] 
    jne     .cont
    cmp     edx, [CPUID_VENDOR_BUFFER + 4]
    jne     .cont
    cmp     ecx, [CPUID_VENDOR_BUFFER + 8]
    jne     .cont

    ; if equal fall here
.equal:

    mov     [boot_info.vendor_name], ebx
    mov     [boot_info.vendor_name + 4], edx
    mov     [boot_info.vendor_name + 8], ecx

    mov     ax, di
    xor     dx, dx
    mov     cx, 12
    div     cx         ; divide DX:AX by 12. AX hold answer

    mov     di, ax
    xor     ax, ax
    mov     al, [CPUID_VENDOR_CATEGORY + di]
    mov     [boot_info.vendor_category], al
    ret

.cont:
    add     edi, 12     ; add 12 byte to base pointer, next entries
    cmp     edi, CPUID_VENDOR_TABLE_SIZE
    jae     .unknown_vendor
    jmp     .loop

.unknown_vendor:
    ; we store 0 if it just unknown
    mov     [boot_info.vendor_name], 0
    mov     [boot_info.vendor_name + 4], 0
    mov     [boot_info.vendor_name + 8], 0
    mov     [boot_info.vendor_category], 0
    mov     si, msg_cpuid_unknown_vendor
    call    print_loop
    ret

; ------------------- max leaf -------------------  
max_extended_detection:
    mov     eax, 0x80000000
    cpuid
    mov     dword [boot_info.cpu_max_x_leaf], eax
    ret

; -------------------- leaf 1 --------------------  
cpu_leaf1_detection:
    cmp     dword [boot_info.cpu_max_leaf], 1
    jb      .failed
    mov     eax, 1
    cpuid
    mov     [boot_info.cpu_signature], eax
    mov     [boot_info.cpu_features1_ecx], ecx
    mov     [boot_info.cpu_features1_edx], edx
.done:
    mov     si, msg_cpuid_leaf1_success
    call    print_loop

    mov     al, [boot_report]
    or      al, 1          ; turn first bit on
    mov     [boot_report], al

    ret
.failed:
    mov     si, msg_cpuid_leaf1_failed
    call    print_loop

    mov     al, [boot_report]
    and     al, -2           ; clear first bit
    mov     [boot_report], al

    ret

; -------------------- leaf 7 --------------------  
cpu_leaf7_detection:
    cmp     dword [boot_info.cpu_max_leaf], 7
    jb      .failed
    mov     eax, 7
    xor     ecx, ecx
    cpuid
    mov     [boot_info.cpu_features7_ebx], ebx
    mov     [boot_info.cpu_features7_ecx], ecx
    mov     [boot_info.cpu_features7_edx], edx
.done:
    mov     si, msg_cpuid_leaf7_success
    call    print_loop

    mov     al, [boot_report]
    or      al, 2
    mov     [boot_report], al

    ret
.failed:
    mov     si, msg_cpuid_leaf7_failed
    call    print_loop

    mov     al, [boot_report]
    and     al, -3
    mov     [boot_report], al

    ret

; ----------------- xleaf 2 to 4 -----------------  
cpu_xleaf2to4_detection:
    mov     eax, [boot_info.cpu_max_x_leaf]
    cmp     eax, 0x80000004
    jb      .failed

    mov     eax, 0x80000002         ; copy eax, ebx, ecx, edx
    cpuid
    mov     [boot_info.brand_string], eax
    mov     [boot_info.brand_string + 4], ebx
    mov     [boot_info.brand_string + 8], ecx
    mov     [boot_info.brand_string + 12], edx
    mov     eax, 0x80000003
    mov     [boot_info.brand_string + 16], eax
    mov     [boot_info.brand_string + 20], ebx
    mov     [boot_info.brand_string + 24], ecx
    mov     [boot_info.brand_string + 28], edx
    mov     eax, 0x80000004
    mov     [boot_info.brand_string + 32], eax
    mov     [boot_info.brand_string + 36], ebx
    mov     [boot_info.brand_string + 40], ecx
    mov     [boot_info.brand_string + 44], edx
.done:
    mov     si, msg_cpuid_xleaf2to4_success
    call    print_loop

    mov     al, [boot_report]
    or      al, 4
    mov     [boot_report], al

    ret
.failed:
    mov     si, msg_cpuid_xleaf2to4_failed
    call    print_loop

    mov     al, [boot_report]
    and     al, -5
    mov     [boot_report], al

    ret

; ------------------------------------------------
;               constant space
; ------------------------------------------------
CPUID_AMD_CATEGORY                  equ     1
CPUID_INTEL_CATEGORY                equ     2
CPUID_INTEL_COMPATIBLE              equ     3
CPUID_OTHER_CATEGORY                equ     4
CPUID_HYPERVISOR                    equ     5
CPUID_VENDOR_COUNT                  equ     29
CPUID_VENDOR_TABLE_SIZE             equ     CPUID_VENDOR_COUNT * 12
