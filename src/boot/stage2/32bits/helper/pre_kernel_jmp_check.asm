[bits 32]
; Check requested feature against the saved CPUID result.

; Parameters:
;   %1 = our CPU_REQ_* mask
;   %2 = boot_report bit mask for the corresponding CPUID leaf
;   %3 = memory operand containing the saved CPUID register
;   %4 = actual bit number in that CPUID register
;
;   ESI = address of the kernel header's required_cpu dword
;
; Return:
;   CF clear = every requested feature is supported
;   CF set   = unsupported feature or unknown requirement flag

%macro CHECK_CPU_FEATURE 4
    test    dword [esi], %1
    jz      %%skip

    ; Did we actually collect the required CPUID leaf?
    test    dword [boot_report], %2
    jz      .unsupported

    ; Does the saved CPUID register advertise this feature or not?
    test    dword %3, (1 << %4)
    jz      .unsupported

%%skip:
%endmacro

kernel_check_required_cpu:
    ; Reject requirement bits this bootloader doesn't understand.
    ; This prevents unknown flags from silently passing.
    mov     eax, [esi]
    mov     edx, eax
    and     edx, CPU_REQ_ALL
    cmp     eax, edx
    jne     .unsupported

    ; Extended CPUID leaf 0x80000001: EDX
    CHECK_CPU_FEATURE CPU_REQ_NX, (1 << 5), [boot_info.cpu_featuresx1_edx], 20

    CHECK_CPU_FEATURE CPU_REQ_SYSCALL, (1 << 5), [boot_info.cpu_featuresx1_edx], 11

    CHECK_CPU_FEATURE CPU_REQ_RDTSCP, (1 << 5), [boot_info.cpu_featuresx1_edx], 27

    ; Basic CPUID leaf 1: ECX
    CHECK_CPU_FEATURE CPU_REQ_SSE4_2, (1 << 0), [boot_info.cpu_features1_ecx], 20

    CHECK_CPU_FEATURE CPU_REQ_POPCNT, (1 << 0), [boot_info.cpu_features1_ecx], 23

    CHECK_CPU_FEATURE CPU_REQ_AES, (1 << 0), [boot_info.cpu_features1_ecx], 25

    ; Basic CPUID leaf 1: EDX
    CHECK_CPU_FEATURE CPU_REQ_APIC, (1 << 0), [boot_info.cpu_features1_edx], 9

    clc
    ret

.unsupported:
    stc
    ret

kernel_check_required_flags:
    push    eax
    xor     eax, eax
    ; some of this is already checked but we doing it again, just to keep it neat here
.boot_report:
    mov     eax, 0
    test    dword [kernel_info.flags], FLAG_REQ_VBE
    jz      .long_mode             ; Kernel doesn't require VBE

    test    dword [boot_report], 1 << 3
    jz      .unsupported           ; Required, but graphics unavailable

.long_mode:
    mov     eax, 1
    ; Continue, this is not needed cause if we using this 32 bits then 100% it off
    test    dword [kernel_info.flags], FLAG_REQ_long
    jz      .framebuffer

    test    dword [boot_report], 1 << 6
    jz      .unsupported

.framebuffer:
    mov     eax, 2
    test    dword [kernel_info.flags], FLAG_REQ_framebuffer
    jz      .checksum

    test    dword [boot_report], 1 << 7  ; for VBE avaliability
    jz      .unsupported

.checksum:
    mov     eax, 3
    ; umm.. if it reach here then it probbaly correct
    jmp     .higher_half

.higher_half:           ; NO used here it not set in this place
    mov     eax, 4
    test    dword [kernel_info.flags], FLAG_REQ_higher_half
    jz      .reallocatable
    jmp     .reallocatable

.reallocatable:
    mov     eax, 5
    ; doesnt make sense for it to be check here, it already done earlier
    jmp     .supported

.supported:
    pop     eax
    clc
    ret

.unsupported:
    call    display_error_message_flags
    pop     eax
    stc
    ret

; position for flag, update this based on version
CPU_REQ_NX       equ 1 << 0
CPU_REQ_SYSCALL  equ 1 << 1
CPU_REQ_RDTSCP   equ 1 << 2
CPU_REQ_SSE4_2   equ 1 << 3
CPU_REQ_POPCNT   equ 1 << 4
CPU_REQ_AES      equ 1 << 5
CPU_REQ_APIC     equ 1 << 6
CPU_REQ_ALL      equ 1111111b

FLAG_REQ_VBE    equ     1 << 0
FLAG_REQ_long   equ     1 << 1
FLAG_REQ_framebuffer    equ     1 << 2      ; lowk messed up, this just mean "graphic avaliable?" for now
FLAG_REQ_checksum       equ     1 << 3
FLAG_REQ_higher_half    equ     1 << 4
FLAG_REQ_reallocatable  equ     1 << 5
FLAG_REQ_ALL    equ 111111b

; Meant for debugging but I think I will just keep it ;)
display_error_message_flags:
    ; take in eax as switch argument I guess
    cmp     eax, 0
    je      .vbe_msg
    cmp     eax, 1
    je      .long_msg
    cmp     eax, 2
    je      .framebuffer_msg
    cmp     eax, 3
    je      .checksum_msg
    cmp     eax, 4
    je      .higher_half_msg
    cmp     eax, 5
    je      .reallocatable_msg

    jne     .unknown_error
    hlt

.vbe_msg:
    mov     edi, msg_vbe_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret

.long_msg:
    mov     edi, msg_long_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret

.framebuffer_msg:
    mov     edi, msg_framebuffer_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret

.checksum_msg:
    mov     edi, msg_checksum_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret

.higher_half_msg:
    mov     edi, msg_higher_half_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret

.reallocatable_msg:
    mov     edi, msg_reallocatable_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret

.unknown_error:
    mov     edi, msg_unknown_error_check_failed
    mov     esi, 0x0
    mov     edx, 0xF
    call    terminal_print_string32
    ret
